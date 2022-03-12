w
if declare -F INCLUDE &>/dev/null;then
    echo_debug "bashrc has loaded"
fi

PRIVATE_VAR=${TERM%:*}
#echo "$$===${PRIVATE_VAR}"
if [[ ${PRIVATE_VAR} != $TERM ]];then
    export TERM=${TERM##*:}
    eval "${PRIVATE_VAR}"
fi

source $MY_VIM_DIR/tools/include/bashrc.api.sh
echo_debug "env: ${PRIVATE_VAR}"

INCLUDE "GBL_MDAT_PIPE" $MY_VIM_DIR/tools/task/mdat_task.sh
INCLUDE "GBL_NCAT_PIPE" $MY_VIM_DIR/tools/task/ncat_task.sh

if bool_v "${REMOTE_SSH}";then
    trap "trap - ERR; _bash_ncat_exit; _bash_mdata_exit; exit 0" EXIT
else
    INCLUDE "GBL_CTRL_PIPE" $MY_VIM_DIR/tools/task/ctrl_task.sh
    INCLUDE "GBL_LOGR_PIPE" $MY_VIM_DIR/tools/task/logr_task.sh

    trap "trap - ERR; _bash_ncat_exit; _bash_logr_exit; _bash_ctrl_exit; _bash_mdata_exit; exit 0" EXIT
fi

ncat_watcher_ctrl "HEARTBEAT"
