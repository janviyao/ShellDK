if declare -F __my_bash_exit &>/dev/null;then
    echo_file "${LOG_WARN}" "bashrc has loaded"
    return
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
fi
if [ -z "${MY_HOME}" ];then
    readonly MY_HOME=${HOME}
fi

source $MY_VIM_DIR/include/common.api.sh
source $MY_VIM_DIR/include/bashrc.api.sh
echo_file "${LOG_DEBUG}" "envir: ${PRIVATE_VAR}"
echo_file "${LOG_DEBUG}" "tasks: ${BTASK_LIST}"

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    if can_access "${GBL_BASE_DIR}/.${MY_NAME}";then
        account_check "${MY_NAME}" false
    fi
fi

if string_contain "${BTASK_LIST}" "mdat";then
    __MY_SOURCE "INCLUDED_MDAT" $MY_VIM_DIR/tools/task/mdat_task.sh

    old_spec=$(string_replace "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_mdat_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_mdat_exit" EXIT

    mdat_kv_append "BASH_TASK" "${ROOT_PID}"
fi

if string_contain "${BTASK_LIST}" "ncat";then
    __MY_SOURCE "INCLUDED_NCAT" $MY_VIM_DIR/tools/task/ncat_task.sh

    old_spec=$(string_replace "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_ncat_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_ncat_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "logr";then
    __MY_SOURCE "INCLUDED_LOGR" $MY_VIM_DIR/tools/task/logr_task.sh

    old_spec=$(string_replace "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_logr_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_logr_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "xfer";then
    __MY_SOURCE "INCLUDED_XFER" $MY_VIM_DIR/tools/task/xfer_task.sh

    old_spec=$(string_replace "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_xfer_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_xfer_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "ctrl";then
    __MY_SOURCE "INCLUDED_CTRL" $MY_VIM_DIR/tools/task/ctrl_task.sh

    old_spec=$(string_replace "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
    [ -n "${old_spec}" ] && trap "_bash_ctrl_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_ctrl_exit" EXIT
fi

old_spec=$(string_replace "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "" true)
[ -n "${old_spec}" ] && trap "trap - ERR; ${old_spec}; if __var_defined BASH_EXIT;then exit \${BASH_EXIT}; else exit 0; fi;" EXIT
[ -z "${old_spec}" ] && trap "trap - ERR; if __var_defined BASH_EXIT;then exit \${BASH_EXIT}; else exit 0; fi;" EXIT
unset old_spec
