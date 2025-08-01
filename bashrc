if declare -F __my_bash_exit &>/dev/null;then
    echo_file "${LOG_WARN}" "bashrc has loaded"
    if [ -z "${TMUX}" ];then
        return
    fi
fi

if ! declare -p MY_VIM_DIR &>/dev/null;then
    export MY_VIM_DIR=$(cd $(dirname ${BASH_SOURCE[0]});pwd)
fi

PRIVATE_VAR=${TERM%:*}
#echo "$$===${PRIVATE_VAR}"
if [[ ${PRIVATE_VAR} != ${TERM} ]];then
    export TERM=${TERM##*:}
    eval "${PRIVATE_VAR}"
fi

if [ -z "${BTASK_LIST}" ];then
    export BTASK_LIST="master,mdat,ncat,logr,ctrl,xfer"
fi

# all variables and functions exported
# only function exported: export -f function
# only variable exported: export var=val
# NOTE: if variables use declare define, allexport will have no effect to them
set -o allexport
shopt -s expand_aliases
#set -o errexit # when error, then exit
#set -o nounset # variable not exist, then exit
if [ -z "${MY_NAME}" ];then
    readonly MY_NAME=$(whoami)
    #if declare -p USERNAME &>/dev/null;then
    #    readonly MY_NAME=${USERNAME}
    #elif declare -p USER &>/dev/null;then
    #    readonly MY_NAME=${USER}
    #fi
fi

if [ -z "${MY_HOME}" ];then
    if declare -p HOME &>/dev/null;then
        readonly MY_HOME=${HOME}
    else
        readonly MY_HOME="/home/${MY_NAME}"
    fi
fi

function __bash_set
{
	local bash_opts="$-"
	eval "set +$1"
	eval "declare -g opts_${FUNCNAME[1]}$$='${bash_opts}'"
}

function __bash_unset
{
	if [[ $(eval "echo \${opts_${FUNCNAME[1]}$$}") =~ $1 ]];then
		eval "set -$1"
	fi
}

source $MY_VIM_DIR/include/common.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

source $MY_VIM_DIR/include/bashrc.api.sh
if [ $? -ne 0 ];then
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
		return 1
	else
		exit 1
	fi
fi

echo_file "${LOG_DEBUG}" "envir: ${PRIVATE_VAR}"
echo_file "${LOG_DEBUG}" "tasks: ${BTASK_LIST}"

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ];then
    if file_exist "${GBL_USER_DIR}/.${MY_NAME}";then
        account_check "${MY_NAME}" false
    fi

	if [ -z "${USR_NAME}" ];then
		USR_NAME="${MY_NAME}"
	fi
fi

echo "${ROOT_PID}" > ${BASH_MASTER}
if string_contain "${BTASK_LIST}" "mdat";then
    __MY_SOURCE "INCLUDED_MDAT" $MY_VIM_DIR/tools/task/mdat_task.sh
	if [ $? -ne 0 ];then
		if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
			return 1
		else
			exit 1
		fi
	fi

    old_spec=$(string_replace "$(string_gensub "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_mdat_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_mdat_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "ncat";then
    __MY_SOURCE "INCLUDED_NCAT" $MY_VIM_DIR/tools/task/ncat_task.sh
	if [ $? -ne 0 ];then
		if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
			return 1
		else
			exit 1
		fi
	fi

    old_spec=$(string_replace "$(string_gensub "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_ncat_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_ncat_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "logr";then
    __MY_SOURCE "INCLUDED_LOGR" $MY_VIM_DIR/tools/task/logr_task.sh
	if [ $? -ne 0 ];then
		if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
			return 1
		else
			exit 1
		fi
	fi

    old_spec=$(string_replace "$(string_gensub "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_logr_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_logr_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "xfer";then
    __MY_SOURCE "INCLUDED_XFER" $MY_VIM_DIR/tools/task/xfer_task.sh
	if [ $? -ne 0 ];then
		if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
			return 1
		else
			exit 1
		fi
	fi

    old_spec=$(string_replace "$(string_gensub "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_xfer_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_xfer_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "ctrl";then
    __MY_SOURCE "INCLUDED_CTRL" $MY_VIM_DIR/tools/task/ctrl_task.sh
	if [ $? -ne 0 ];then
		if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
			return 1
		else
			exit 1
		fi
	fi

    old_spec=$(string_replace "$(string_gensub "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_ctrl_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_ctrl_exit" EXIT
fi

old_spec=$(string_replace "$(string_gensub "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
[ -n "${old_spec}" ] && trap "trap - ERR; ${old_spec}; if __var_defined BASH_EXIT;then exit \${BASH_EXIT}; fi;" EXIT
[ -z "${old_spec}" ] && trap "trap - ERR; if __var_defined BASH_EXIT;then exit \${BASH_EXIT}; else exit 0; fi;" EXIT
unset old_spec
