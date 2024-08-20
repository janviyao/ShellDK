#!/bin/bash
: ${INCLUDED_COMPLETE:=1}

function _mygit_completion()
{
	local cur prev words cword

	_init_completion || return

	# don't complete past 2nd token
	[[ $cword -gt 2 ]] && return 0
	
	# define custom completions here
	if [[ $cword -eq 2 ]]; then
		if [[ ${prev} == ?(*/)checkout ]]; then
			COMPREPLY=($(compgen -W "$(git branch --no-color | awk '{ print $NF }')" -- "$cur"))
			return 0
		fi
	fi

	COMPREPLY=($(compgen -W "$(sh $MY_VIM_DIR/tools/git.sh -l)" -- "$cur"))
} &&
complete -F _mygit_completion mygit

function _mygdb_completion()
{
	local cur prev words cword

	_init_completion || return

	#echo "<$cur | $prev | ${words[*]} | $cword>"
	# don't complete past 2nd token
	[[ $cword -gt 2 ]] && return 0

	# define custom completions here
	if [[ $cword -eq 2 ]]; then
		if [ -n "${cur}" ];then
			local key=${cur}
			if [[ "${key}" =~ "/" ]];then
				key=${key//\//\\/}
			fi
			COMPREPLY=($(compgen -W "$(pgrep -l ${cur} | awk "{ if (\$2 ~ /^${key}/ ) print \$2 }")" -- "$cur"))
		else
			COMPREPLY=( )
		fi
		return 0
	fi

	COMPREPLY=($(compgen -W "$(sh $MY_VIM_DIR/tools/gdb.sh -l)" -- "$cur"))
} &&
complete -F _mygdb_completion mygdb
