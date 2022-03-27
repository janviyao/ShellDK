if declare -F INCLUDE &>/dev/null;then
    echo_debug "bashrc has loaded"
    return
fi

PRIVATE_VAR=${TERM%:*}
#echo "$$===${PRIVATE_VAR}"
if [[ ${PRIVATE_VAR} != $TERM ]];then
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

source $MY_VIM_DIR/tools/include/common.api.sh
source $MY_VIM_DIR/tools/include/bashrc.api.sh
echo_debug "env: ${PRIVATE_VAR}"

INCLUDE "GBL_MDAT_PIPE" $MY_VIM_DIR/tools/task/mdat_task.sh
INCLUDE "GBL_LOGR_PIPE" $MY_VIM_DIR/tools/task/logr_task.sh
INCLUDE "GBL_NCAT_PIPE" $MY_VIM_DIR/tools/task/ncat_task.sh
INCLUDE "GBL_XFER_PIPE" $MY_VIM_DIR/tools/task/xfer_task.sh
INCLUDE "GBL_CTRL_PIPE" $MY_VIM_DIR/tools/task/ctrl_task.sh

if contain_str "${BTASK_LIST}" "ctrl";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "${old_spec}; _bash_ctrl_exit" EXIT
    [ -z "${old_spec}" ] && trap "_bash_ctrl_exit" EXIT
fi

if contain_str "${BTASK_LIST}" "xfer";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "${old_spec}; _bash_xfer_exit" EXIT
    [ -z "${old_spec}" ] && trap "_bash_xfer_exit" EXIT
fi

if contain_str "${BTASK_LIST}" "ncat";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "${old_spec}; _bash_ncat_exit" EXIT
    [ -z "${old_spec}" ] && trap "_bash_ncat_exit" EXIT
fi

if contain_str "${BTASK_LIST}" "logr";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "${old_spec}; _bash_logr_exit" EXIT
    [ -z "${old_spec}" ] && trap "_bash_logr_exit" EXIT
fi

if contain_str "${BTASK_LIST}" "mdat";then
    old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
    [ -n "${old_spec}" ] && trap "${old_spec}; _bash_mdat_exit" EXIT
    [ -z "${old_spec}" ] && trap "_bash_mdat_exit" EXIT
fi

old_spec=$(replace_regex "$(string_regex "$(trap -p | grep EXIT)" "\'.+\'")" "'" "")
[ -n "${old_spec}" ] && trap "trap - ERR; ${old_spec}; exit 0" EXIT
[ -z "${old_spec}" ] && trap "trap - ERR; exit 0" EXIT
unset old_spec

global_kv_append "BASH_TASK" "${ROOT_PID}"
