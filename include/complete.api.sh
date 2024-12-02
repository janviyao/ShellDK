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

	COMPREPLY=($(compgen -W "$(sh $MY_VIM_DIR/tools/git.sh --func-list)" -- "$cur"))
} &&
complete -F _mygit_completion mygit

function _mygit_pull_completion()
{
	local cur prev words cword

	_init_completion || return

	COMPREPLY=($(compgen -W "$(git branch --no-color | awk '{ print $NF }')" -- "$cur"))
} &&
complete -F _mygit_pull_completion gpull

function _mygit_checkout_completion()
{
	local cur prev words cword

	_init_completion || return

	COMPREPLY=($(compgen -W "$(git branch --no-color | awk '{ print $NF }')" -- "$cur"))
} &&
complete -F _mygit_checkout_completion gcheckout

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

	COMPREPLY=($(compgen -W "$(sh $MY_VIM_DIR/tools/gdb.sh --func-list)" -- "$cur"))
} &&
complete -F _mygdb_completion mygdb

function _mydocker_completion()
{
	local cur prev words cword

	_init_completion || return

	#echo "<$cur | $prev | ${words[*]} | $cword>"
	# don't complete past 2nd token
	[[ $cword -gt 2 ]] && return 0

	# define custom completions here
	if [[ $cword -eq 2 ]]; then
		if [[ ${prev} == ?(*/)enter ]] || [[ ${prev} == ?(*/)stop ]] || [[ ${prev} == ?(*/)copy_to ]] || [[ ${prev} == ?(*/)copy_from ]]; then
			COMPREPLY=($(compgen -W "$(docker ps | grep -v 'NAMES' | awk '{ print $NF }')" -- "$cur"))
		elif [[ ${prev} == ?(*/)start ]]; then
			COMPREPLY=($(compgen -W "$(docker ps -a | grep -v 'NAMES' | grep -E "Exited" | awk '{ print $NF }')" -- "$cur"))
		else
			COMPREPLY=($(compgen -W "$(docker ps -a | grep -v 'NAMES' | awk '{ print $NF }')" -- "$cur"))
		fi
		return 0
	fi

	COMPREPLY=($(compgen -W "$(sh $MY_VIM_DIR/tools/docker.sh --func-list)" -- "$cur"))
} &&
complete -F _mydocker_completion mydocker
