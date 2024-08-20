#!/bin/bash
: ${INCLUDED_COMPLETE:=1}

function _mygit_completion()
{
	local cur prev words cword

	_init_completion || return

	# don't complete past 2nd token
	[[ $cword -ge 2 ]] && return 0

	# define custom completions here
	COMPREPLY=($(compgen -W "$(sh $MY_VIM_DIR/tools/git.sh -l)" -- "$cur"))
} &&
complete -F _mygit_completion mygit

function _mygdb_completion()
{
	local cur prev words cword

	_init_completion || return

	# don't complete past 2nd token
	[[ $cword -ge 2 ]] && return 0

	# define custom completions here
	COMPREPLY=($(compgen -W "$(sh $MY_VIM_DIR/tools/gdb.sh -l)" -- "$cur"))
} &&
complete -F _mygdb_completion mygdb
