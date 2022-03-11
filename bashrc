if declare -F INCLUDE &>/dev/null;then
    echo_debug "bashrc has loaded"
fi

PRIVATE_VAR=${TERM%:*}
#echo "$$===${PRIVATE_VAR}"
if [[ ${PRIVATE_VAR} != $TERM ]];then
    export TERM=${TERM##*:}
    eval "${PRIVATE_VAR}"
fi
#echo "$$===TASK_RUNNING=${TASK_RUNNING}  REMOTE_SSH=${REMOTE_SSH}"

source $MY_VIM_DIR/tools/include/base_task.api.sh
INCLUDE "GBL_CTRL_PIPE" $MY_VIM_DIR/tools/task/ctrl_task.sh
INCLUDE "GBL_LOGR_PIPE" $MY_VIM_DIR/tools/task/logr_task.sh

if ! bool_v "${TASK_RUNNING}";then
    trap "trap - ERR; _bash_ncat_exit; _bash_logr_exit; _bash_ctrl_exit; _bash_mdata_exit; exit 0" EXIT
    ncat_watcher_ctrl "HEARTBEAT"
fi
