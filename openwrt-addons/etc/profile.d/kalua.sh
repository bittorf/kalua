#!/bin/sh

export PS1='\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\] '

alias n='wget -qO - http://127.0.0.1:2006/neighbours'
alias n2='echo /nhdpinfo link | nc 127.0.0.1 2009'
alias ll='ls -la'
alias lr='logread'
alias flush='_system ram_free flush'
alias myssh='ssh -i $( _ssh key_public_fingerprint_get keyfilename )'
alias regen='/etc/kalua_init; _(){ false;}; . /tmp/loader'

_ t 2>/dev/null || {
	[ -e '/tmp/loader' ] && {
		. '/tmp/loader'
		echo
		echo 'for some hints type: _help overview'
	}
}
