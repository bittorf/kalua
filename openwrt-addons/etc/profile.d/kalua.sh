#!/bin/sh

export PS1='\[\033[36m\]\u\[\033[m\]@\[\033[32m\]\h:\[\033[33;1m\]\w\[\033[m\] '

alias n='wget -qO - http://127.0.0.1:2006/neighbours'
alias n2='echo /nhdpinfo link | nc 127.0.0.1 2009'
alias ll='ls -la'
alias lr='logread'
alias flush='_system ram_free flush'
alias myssh='ssh -i $( _ssh key_public_fingerprint_get keyfilename )'
alias regen='/etc/kalua_init; _(){ false;}; . /tmp/loader'

case "$USER" in
	'root')
		grep -s ^"root:\$1\$b6usD77Q\$XPs6VECsQzFy9TUuQUAHW1:" '/etc/shadow' && {
			echo "[ERROR] change weak root-password ('admin') with 'passwd'"
		}

		grep -s ^'root:$' '/etc/shadow' || {
			echo "[ERROR] set root-password with 'passwd'"
		}
	;;
esac

_ t 2>/dev/null || {
	[ -e '/tmp/loader' ] && {
		. '/tmp/loader'
		echo
		echo 'for some hints type: _help overview'
	}
}
