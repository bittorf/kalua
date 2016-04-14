/*
 * mips32-dasm - Primitive MIPS32 disassembler.
 *
 *   Copyright (C) 2012 "Jo-Philipp Wich" <xm@subsignal.org>
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <byteswap.h>
#include <arpa/inet.h>
#include <sys/stat.h>
#include <sys/mman.h>


static int need_byteswap = 0;

static void check_endianess(unsigned char *elf_hdr)
{
	int self_is_be = (htonl(42) == 42);
	int elf_is_be  = (elf_hdr[5] == 2);

	if (self_is_be != elf_is_be)
	{
		need_byteswap = 1;
		printf("Byte swapping needed (utility %s endian, module %s endian)\n",
			   self_is_be ? "big" : "low",
			   elf_is_be  ? "big" : "low");
	}
}

#define S16(x) (need_byteswap ? bswap_16(x) : (x))
#define S32(x) (need_byteswap ? bswap_32(x) : (x))

struct elf_header
{
	unsigned char ident[16];
	uint16_t type;
	uint16_t machine;
	uint32_t version;
	uint32_t entry;
	uint32_t phoff;
	uint32_t shoff;
	uint32_t flags;
	uint16_t ehsize;
	uint16_t phentsize;
	uint16_t phnum;
	uint16_t shentsize;
	uint16_t shnum;
	uint16_t shtrndx;
};

struct elf_sh
{
	uint32_t name;
	uint32_t type;
	uint32_t flags;
	uint32_t addr;
	uint32_t offset;
	uint32_t size;
	uint32_t linke;
	uint32_t info;
	uint32_t addralign;
	uint32_t entsize;
};

struct elf_ph
{
	uint32_t type;
	uint32_t offset;
	uint32_t vaddr;
	uint32_t paddr;
	uint32_t filesz;
	uint32_t memsz;
	uint32_t flags;
	uint32_t align;
};


static struct elf_header * read_elf_header(const struct elf_header *p)
{
	static struct elf_header hdr;

	hdr = *p;

	if (need_byteswap)
	{
		hdr.type      = S16(hdr.type);
		hdr.machine   = S16(hdr.machine);
		hdr.version   = S32(hdr.version);
		hdr.entry     = S32(hdr.entry);
		hdr.phoff     = S32(hdr.phoff);
		hdr.shoff     = S32(hdr.shoff);
		hdr.flags     = S32(hdr.flags);
		hdr.ehsize    = S16(hdr.ehsize);
		hdr.phentsize = S16(hdr.phentsize);
		hdr.phnum     = S16(hdr.phnum);
		hdr.shentsize = S16(hdr.shentsize);
		hdr.shnum     = S16(hdr.shnum);
		hdr.shtrndx   = S16(hdr.shtrndx);
	}

	return &hdr;
}

static struct elf_ph * read_elf_ph(const struct elf_ph *p)
{
	static struct elf_ph hdr;

	hdr = *p;

	if (need_byteswap)
	{
		hdr.type   = S32(hdr.type);
		hdr.offset = S32(hdr.offset);
		hdr.vaddr  = S32(hdr.vaddr);
		hdr.paddr  = S32(hdr.paddr);
		hdr.filesz = S32(hdr.filesz);
		hdr.memsz  = S32(hdr.memsz);
		hdr.flags  = S32(hdr.flags);
		hdr.align  = S32(hdr.align);
	}

	return &hdr;
}

static struct elf_sh * read_elf_sh(const struct elf_sh *p)
{
	static struct elf_sh hdr;

	hdr = *p;

	if (need_byteswap)
	{
		hdr.name      = S32(hdr.name);
		hdr.type      = S32(hdr.type);
		hdr.flags     = S32(hdr.flags);
		hdr.addr      = S32(hdr.addr);
		hdr.offset    = S32(hdr.offset);
		hdr.size      = S32(hdr.size);
		hdr.linke     = S32(hdr.linke);
		hdr.info      = S32(hdr.info);
		hdr.addralign = S32(hdr.addralign);
		hdr.entsize   = S32(hdr.entsize);
	}

	return &hdr;
}

bool find_text_section_from_ph(void *map, const struct elf_header *ehdr,
							   uint32_t *off, uint32_t *len)
{
	int i, esz, en;
	void *eoff;
	struct elf_ph *eph;
	uint32_t vs, ve;

	if (!ehdr->phoff)
	{
		printf("No program header table found\n");
		return false;
	}

	if (!ehdr->entry)
	{
		printf("No entry point defined\n");
		return false;
	}

	en = ehdr->phnum;
	esz = ehdr->phentsize;
	eoff = map + ehdr->phoff;

	printf("Using program header table @ 0x%08x (%d bytes each), entry @ 0x%08x\n",
		   ehdr->phoff, ehdr->phentsize, ehdr->entry);

	for (i = 0; i < ehdr->phnum; i++)
	{
		eph = read_elf_ph(map + ehdr->phoff + i * ehdr->phentsize);
		vs = eph->vaddr;
		ve = eph->vaddr + eph->memsz;

		/* segment must be of type PT_LOAD */
		if (eph->type != 1)
			continue;

		/* segment must be readable and executable */
		if ((eph->flags & 0x05) != 0x05)
			continue;

		/* check if the entry address lies within the segment */
		if ((ehdr->entry >= vs) && (ehdr->entry < ve))
		{
			*off = ehdr->entry - vs;
			*len = eph->filesz;
			return true;
		}
	}

	return false;
}

bool find_text_section_from_sh(void *map, const struct elf_header *ehdr,
							   uint32_t *off, uint32_t *len)
{
	int i;
	struct elf_sh *esh;
	const char *strtab;

	if (!ehdr->shoff)
	{
		printf("No section header table found\n");
		return false;
	}

	if (ehdr->shtrndx >= ehdr->shnum)
	{
		printf("Invalid string table id\n");
		return false;
	}

	strtab = map + read_elf_sh(map + ehdr->shoff +
							   ehdr->shtrndx * ehdr->shentsize)->offset;

	printf("Using section header table @ 0x%08x (%d bytes each), strtab @ 0x%08x\n",
		   ehdr->shoff, ehdr->shentsize, (void *)strtab - map);

	for (i = 0, *off = 0, *len = 0; i < ehdr->shnum; i++)
	{
		esh = read_elf_sh(map + ehdr->shoff + i * ehdr->shentsize);

		/* section must be of type SHT_PROGBITS */
		if (esh->type != 0x01)
			continue;

		/* need size */
		if (esh->size < sizeof(uint32_t))
			continue;

		/* ignore non ".text" sections */
		if (strncmp(strtab + esh->name, ".text", 5))
			continue;

		if (!*off)
			*off = esh->offset;

		*len += esh->size;
	}

	return !!(*off);
}



enum mips_insn_arg_type
{
	NUM = 1, /* numeric argument */
	REG,     /* register index */
	ISN,     /* instruction index to lookup in mips_insn.lookup */
	IGN,     /* alwayss zero (ignore) */
};

enum mips_insn_flags {
	F_OFFSET = (1 << 0), /* is offset of base register */
};

struct mips_insn
{
	const char name[9];
	uint8_t args[12];
	uint8_t flags;
	struct mips_insn *lookup;
};


static struct mips_insn nop_opcodes[32] = {
	[0x00] = { "NOP",     {  } },
	[0x01] = { "SSNOP",   {  } },
	[0x03] = { "EHB",     {  } },
	[0x04] = { "SLLV",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x05] = { "PAUSE",   {  } },
};

static struct mips_insn sll_opcodes[32] = {
	[0x00] = { "*NOP",    { IGN, 21, ISN, 5 }, 0, nop_opcodes },
	[0x01] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x02] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x03] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x04] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x05] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x06] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x07] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x08] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x09] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x0A] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x0B] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x0C] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x0D] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x0E] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x0F] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x10] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x11] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x12] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x13] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x14] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x15] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x16] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x17] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x18] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x19] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x1A] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x1B] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x1C] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x1D] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x1E] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x1F] = { "SLL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
};

static struct mips_insn special_opcodes[64] = {
	[0x00] = { "*SLL",    { IGN, 11, ISN, 5 }, 0, sll_opcodes },

	[0x01] = { "MOVCI",   { IGN, 6, REG, 5, NUM, 3, IGN, 1, NUM, 1, REG, 5 } },
	[0x02] = { "SRL",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x03] = { "SRA",     { IGN, 11, REG, 5, REG, 5, NUM, 5 } },
	[0x04] = { "SLLV",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x06] = { "SRLV",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x07] = { "SRAV",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x08] = { "JR",      { IGN, 6, REG, 5, IGN, 10, NUM, 5 } },
	[0x09] = { "JALR",    { IGN, 6, REG, 5, IGN, 5, REG, 5, NUM, 5 } },
	[0x0A] = { "MOVZ",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x0B] = { "MOVN",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x0C] = { "SYSCALL", { IGN, 6, NUM, 20 } },
	[0x0F] = { "SYNC",    { IGN, 21, NUM, 5 } },
	[0x10] = { "MFHI",    { IGN, 16, REG, 5 } },
	[0x11] = { "MTHI",    { IGN, 6, REG, 5 } },
	[0x12] = { "MFLO",    { IGN, 16, REG, 5 } },
	[0x13] = { "MTLO",    { IGN, 6, REG, 5 } },
	[0x18] = { "MULT",    { IGN, 6, REG, 5, REG, 5 } },
	[0x19] = { "MULTU",   { IGN, 6, REG, 5, REG, 5 } },
	[0x0D] = { "BREAK",   { IGN, 6, NUM, 20 } },
	[0x1A] = { "DIV",     { IGN, 6, REG, 5, REG, 5 } },
	[0x1B] = { "DIVU",    { IGN, 6, REG, 5, REG, 5 } },
	[0x20] = { "ADD",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x21] = { "ADDU",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x22] = { "SUB",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x23] = { "SUBU",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x24] = { "AND",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x25] = { "OR",      { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x26] = { "XOR",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x27] = { "NOR",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x2A] = { "SLT",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x2B] = { "SLTU",    { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x30] = { "TGE",     { IGN, 6, REG, 5, REG, 5, NUM, 10 } },
	[0x31] = { "TGEU",    { IGN, 6, REG, 5, REG, 5, NUM, 10 } },
	[0x32] = { "TLT",     { IGN, 6, REG, 5, REG, 5, NUM, 10 } },
	[0x33] = { "TLTU",    { IGN, 6, REG, 5, REG, 5, NUM, 10 } },
	[0x34] = { "TEQ",     { IGN, 6, REG, 5, REG, 5, NUM, 10 } },
	[0x36] = { "TNE",     { IGN, 6, REG, 5, REG, 5, NUM, 10 } },
};

static struct mips_insn special2_opcodes[64] = {
	[0x00] = { "MADD",    { IGN, 6, REG, 5, REG, 5 } },
	[0x01] = { "MADDU",   { IGN, 6, REG, 5, REG, 5 } },
	[0x02] = { "MUL",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x04] = { "MSUB",    { IGN, 6, REG, 5, REG, 5 } },
	[0x05] = { "MSUBU",   { IGN, 6, REG, 5, REG, 5 } },
	[0x20] = { "CLZ",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x21] = { "CLO",     { IGN, 6, REG, 5, REG, 5, REG, 5 } },
	[0x3F] = { "SDBBP",   { IGN, 6, NUM, 20 } },
};

static struct mips_insn bshfl_opcodes[32] = {
	[0x02] = { "WSBH",    { IGN, 11, REG, 5, REG, 5 } },
	[0x10] = { "SEB",     { IGN, 11, REG, 5, REG, 5 } },
	[0x18] = { "SEH",     { IGN, 11, REG, 5, REG, 5 } },
};

static struct mips_insn special3_opcodes[64] = {
	[0x00] = { "EXT",     { IGN, 6, REG, 5, REG, 5, NUM, 5, NUM, 5 } },
	[0x04] = { "INS",     { IGN, 6, REG, 5, REG, 5, NUM, 5, NUM, 5 } },
	[0x20] = { "*BSHFL",  { IGN, 21, ISN, 5 }, 0, bshfl_opcodes },
	[0x3B] = { "RDHWR",   { IGN, 11, REG, 5, REG, 5 } },
};

static struct mips_insn regimm_opcodes[32] = {
	[0x00] = { "BLTZ",    { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x01] = { "BGEZ",    { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x02] = { "BLTZL",   { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x03] = { "BGEZL",   { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x08] = { "TGEI",    { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x09] = { "TGEIU",   { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x0A] = { "TLTI",    { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x0B] = { "TLTIU",   { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x0C] = { "TEQI",    { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x0E] = { "TNEI",    { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x10] = { "BLTZAL",  { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x11] = { "BGEZAL",  { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x12] = { "BLTZALL", { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x13] = { "BGEZALL", { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x1F] = { "SYNCI",   { IGN, 6, REG, 5, IGN, 5, NUM, 16 }, F_OFFSET },
};

static struct mips_insn base_opcodes[64] = {
	[0x00] = { "*SPC",    { IGN, 26, ISN, 6 }, 0, special_opcodes },
	[0x01] = { "*REGIMM", { IGN, 11, ISN, 5 }, 0, regimm_opcodes },

	[0x02] = { "J",       { IGN, 6, NUM, 26 } },
	[0x03] = { "JAL",     { IGN, 6, NUM, 26 } },
	[0x04] = { "BEQ",     { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x05] = { "BNE",     { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x06] = { "BLEZ",    { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x07] = { "BGTZ",    { IGN, 6, REG, 5, IGN, 5, NUM, 16 } },
	[0x08] = { "ADDI",    { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x09] = { "ADDIU",   { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x0A] = { "SLTI",    { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x0B] = { "SLTIU",   { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x0C] = { "ANDI",    { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x0D] = { "ORI",     { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x0E] = { "XORI",    { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x0F] = { "LUI",     { IGN, 11, REG, 5, NUM, 16 } },

	[0x10] = { "COP0",    {  } }, // special
	[0x11] = { "COP1",    {  } }, // special
	[0x12] = { "COP2",    {  } }, // special
	[0x13] = { "COP1X",   {  } }, // special

	[0x14] = { "BEQL",    { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x15] = { "BNEL",    { IGN, 6, REG, 5, REG, 5, NUM, 16 } },
	[0x16] = { "BLEZL",   { IGN, 6, REG, 5, IGN, 0, NUM, 16 } },
	[0x17] = { "BGTZL",   { IGN, 6, REG, 5, IGN, 0, NUM, 16 } },

	[0x1C] = { "*SPC2",   { IGN, 26, ISN, 6 }, 0, special2_opcodes },
	[0x1F] = { "*SPC3",   { IGN, 26, ISN, 6 }, 0, special3_opcodes },

	[0x20] = { "LB",      { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x21] = { "LH",      { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x22] = { "LWL",     { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x23] = { "LW",      { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x24] = { "LBU",     { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x25] = { "LHU",     { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x26] = { "LWR",     { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },

	[0x28] = { "SB",      { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x29] = { "SH",      { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x2A] = { "SWL",     { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x2B] = { "SW",      { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },

	[0x2E] = { "SWR",     { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x2F] = { "CACHE",   { IGN, 6, NUM, 5, NUM, 5, NUM, 16 }, F_OFFSET },
	[0x30] = { "LL",      { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x31] = { "LWC1",    { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x32] = { "LWC2",    { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x33] = { "PREF",    { IGN, 6, NUM, 5, NUM, 5, NUM, 16 }, F_OFFSET },

	[0x35] = { "LDC1",    { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x36] = { "LDC2",    { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },

	[0x38] = { "SC",      { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x39] = { "SWC1",    { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x3a] = { "SWC2",    { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },

	[0x3d] = { "SDC1",    { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
	[0x3e] = { "SDC2",    { IGN, 6, NUM, 5, REG, 5, NUM, 16 }, F_OFFSET },
};

static struct mips_insn base_opcode = {
	"*BASE", { ISN, 6 }, 0, base_opcodes
};


static const char *regnames[32] = {
	[0x00] = "$zero",
	[0x01] = "$at",

	[0x02] = "$v0",
	[0x03] = "$v1",

	[0x04] = "$a0",
	[0x05] = "$a1",
	[0x06] = "$a2",
	[0x07] = "$a3",

	[0x08] = "$t0",
	[0x09] = "$t1",
	[0x0A] = "$t2",
	[0x0B] = "$t3",
	[0x0C] = "$t4",
	[0x0D] = "$t5",
	[0x0E] = "$t6",
	[0x0F] = "$t7",

	[0x10] = "$s0",
	[0x11] = "$s1",
	[0x12] = "$s2",
	[0x13] = "$s3",
	[0x14] = "$s4",
	[0x15] = "$s5",
	[0x16] = "$s6",
	[0x17] = "$s7",

	[0x18] = "$t8",
	[0x19] = "$t9",

	[0x1A] = "$k0",
	[0x1B] = "$k1",

	[0x1C] = "$gp",
	[0x1D] = "$sp",
	[0x1E] = "$fp",
	[0x1F] = "$ra",
};

static void print_field(uint32_t opcode, uint8_t off, uint8_t len,
                        enum mips_insn_arg_type type)
{
	uint32_t v = (opcode >> (32 - off - len)) & ((1 << len) - 1);

	switch (type)
	{
	case REG:
		printf(" %-5s", regnames[v]);
		break;

	case NUM:
		printf(" %-5x", v);
		break;

	default:
		break;
	}
}

static void print_opcode(void *op)
{
	uint8_t i, o;
	uint32_t v, opcode = S32(*(uint32_t *)op);
	struct mips_insn *insn = &base_opcode;

	while (insn->lookup)
	{
		for (i = 0, o = 0; i < sizeof(insn->args) && insn->args[i]; i += 2)
		{
			o += insn->args[i+1];
			v = (opcode >> (32 - o)) & ((1 << insn->args[i+1]) - 1);

			if (insn->args[i] == ISN)
			{
				insn = &insn->lookup[v];
				break;
			}
		}
	}

	if (insn->name[0])
		printf("%-9s", insn->name);
	else
		printf("unknown opcode (%02x %02x %02x %02x)",
			   (opcode >> 24) & 0xFF,
			   (opcode >> 16) & 0xFF,
			   (opcode >>  8) & 0xFF,
			   (opcode >>  0) & 0xFF);

	if (insn->flags & F_OFFSET)
	{
		print_field(opcode, 11, 5, insn->args[2]);
		printf(" %x(%s)",
			   (opcode & 0xFFFF),
			   regnames[((opcode >> 21) & 0x1F)]);
	}
	else
	{
		for (i = 0, o = 0;
		     i < sizeof(insn->args) && insn->args[i];
		     o += insn->args[i+1], i += 2)
		{
			print_field(opcode, o, insn->args[i+1], insn->args[i]);
		}
	}

	printf("\n");
}


int main(int argc, char **argv)
{
	int i, fd;
	void *map;
	struct stat s;
	struct elf_header *ehdr;
	uint32_t codeoff, codesz;

	if (argc < 2)
	{
		printf("Usage: %s module.ko\n", argv[0]);
		exit(1);
	}

	if (stat(argv[1], &s))
	{
		perror("stat()");
		exit(1);
	}

	if ((fd = open(argv[1], O_RDWR)) == -1)
	{
		perror("open()");
		exit(1);
	}

	map = mmap(NULL, s.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);

	if (map == MAP_FAILED)
	{
		perror("mmap()");
		exit(1);
	}

	check_endianess(map);

	ehdr = read_elf_header(map);

	if (!find_text_section_from_ph(map, ehdr, &codeoff, &codesz) &&
		!find_text_section_from_sh(map, ehdr, &codeoff, &codesz))
	{
		printf("Unable to determine begin of code section\n");
		exit(2);
	}

	for (i = 0; i < codesz; i += sizeof(uint32_t))
	{
		printf("%08x: ", codeoff + i);
		print_opcode(map + codeoff + i);
	}

	if (munmap(map, s.st_size))
	{
		perror("munmap()");
		exit(1);
	}

	close(fd);

	return 0;
}
