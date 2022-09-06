if declare -F _bash_exit &>/dev/null;then
    echo_file "${LOG_WARN}" "bashrc has loaded"
    return
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

if [ -z "${MY_NAME}" ];then
    readonly MY_NAME=$(whoami)
fi
if [ -z "${MY_HOME}" ];then
    readonly MY_HOME=${HOME}
fi

source $MY_VIM_DIR/tools/include/common.api.sh
source $MY_VIM_DIR/tools/include/bashrc.api.sh
echo_file "${LOG_DEBUG}" "envir: ${PRIVATE_VAR}"
echo_file "${LOG_DEBUG}" "tasks: ${BTASK_LIST}"

INCLUDE "GBL_MDAT_PIPE" $MY_VIM_DIR/tools/task/mdat_task.sh
INCLUDE "GBL_LOGR_PIPE" $MY_VIM_DIR/tools/task/logr_task.sh
INCLUDE "GBL_NCAT_PIPE" $MY_VIM_DIR/tools/task/ncat_task.sh
INCLUDE "GBL_XFER_PIPE" $MY_VIM_DIR/tools/task/xfer_task.sh
INCLUDE "GBL_CTRL_PIPE" $MY_VIM_DIR/tools/task/ctrl_task.sh

if string_contain "${BTASK_LIST}" "mdat";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "_bash_mdat_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_mdat_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "ncat";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "_bash_ncat_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_ncat_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "logr";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "_bash_logr_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_logr_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "xfer";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "_bash_xfer_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_xfer_exit" EXIT
fi

if string_contain "${BTASK_LIST}" "ctrl";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "_bash_ctrl_exit; ${old_spec}" EXIT
    [ -z "${old_spec}" ] && trap "_bash_ctrl_exit" EXIT
fi

old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
[ -n "${old_spec}" ] && trap "trap - ERR; ${old_spec}; exit 0" EXIT
[ -z "${old_spec}" ] && trap "trap - ERR; exit 0" EXIT
unset old_spec

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    if can_access "${GBL_BASE_DIR}/.userc";then
        account_check "${MY_NAME}" false
    fi
fi

mdata_kv_append "BASH_TASK" "${ROOT_PID}"
