#!/bin/sh

for PS1 in /etc/dropbear/dropbear_dss_host_key /etc/dropbear/dropbear_rsa_host_key /etc/ssh/ssh_host_rsa_key.pub; do {
	[ -e "$PS1" ] && {
		alias myssh="echo 'executing: ssh -i $PS1'; ssh -i $PS1"
		break
	}
} done

export PS1='\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\] '

alias ll='ls -la'
alias flush='echo flushing_caches; echo 3 > /proc/sys/vm/drop_caches'
alias lr='logread'
alias regen='/etc/kalua_init; LODEV= . /tmp/loader'
alias n='wget -qO - http://127.0.0.1:2006/neighbours'
alias n2='echo /nhdpinfo link | nc 127.0.0.1 2009'

test -e '/tmp/loader' && . '/tmp/loader'
echo "for some hints type: _help overview"
