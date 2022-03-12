#!/bin/bash
GBL_MDAT_PIPE="${BASH_WORK_DIR}/mdat.pipe"
GBL_MDAT_FD=${GBL_MDAT_FD:-7}
mkfifo ${GBL_MDAT_PIPE}
can_access "${GBL_MDAT_PIPE}" || echo_erro "mkfifo: ${GBL_MDAT_PIPE} fail"
exec {GBL_MDAT_FD}<>${GBL_MDAT_PIPE}

function mdat_task_ctrl
{
    local mdat_body="$1"
    local one_pipe="$2"

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${one_pipe}";then
        echo_erro "pipe invalid: ${one_pipe}"
        return 1
    fi

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}${mdat_body}" > ${one_pipe}
}

function mdat_task_ctrl_sync
{
    local mdat_body="$1"
    local one_pipe="$2"

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${one_pipe}";then
        echo_erro "pipe invalid: ${one_pipe}"
        return 1
    fi

    # the first pid is shell where ppid run
    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    local ack_pipe="${BASH_WORK_DIR}/ack.${self_pid}"
    local ack_fhno=$(make_ack "${ack_pipe}"; echo $?)
    echo_debug "mdata fd[${ack_fhno}] for ${ack_pipe}"

    echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${mdat_body}" > ${one_pipe}

    wait_ack "${ack_pipe}" "${ack_fhno}"
}

function global_check_var
{
    local var_name="$1"
    local one_pipe="$2"
    echo_debug "mdata check: [$*]" 

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "mdata task donot run"
        return 1
    fi

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    local get_pipe="${BASH_WORK_DIR}/get.${self_pid}"

    mkfifo ${get_pipe}
    can_access "${get_pipe}" || echo_erro "mkfifo: ${get_pipe} fail"

    local get_fd=0
    exec {get_fd}<>${get_pipe}

    mdat_task_ctrl "VAR_EXIST${GBL_SPF1}${var_name}${GBL_SPF2}${get_pipe}" "${one_pipe}"
    read var_valu < ${get_pipe}

    eval "exec ${get_fd}>&-"
    rm -f ${get_pipe}

    if bool_v "${var_valu}";then
        return 0
    else
        return 1
    fi
}

function global_set_var
{
    local var_name="$1"
    local one_pipe="$2"
    local var_valu=""
     
    var_valu="$(eval "echo \"\$${var_name}\"")"
        
    echo_debug "mdata set: [$* = \"${var_valu}\"]" 
    mdat_task_ctrl "SET_VAR${GBL_SPF1}${var_name}${GBL_SPF2}${var_valu}" "${one_pipe}"
}

function global_get_var
{
    local var_name="$1"
    local one_pipe="$2"
    local var_valu=""
    echo_debug "mdata get: [$*]" 

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_MDAT_PIPE}"
    fi

    if ! can_access "${one_pipe}.run";then
        echo_erro "mdata task donot run"
        return 1
    fi

    local self_pid=$$
    if can_access "ppid";then
        local ppids=($(ppid))
        local self_pid=${ppids[1]}
    fi
    local get_pipe="${BASH_WORK_DIR}/get.${self_pid}"

    mkfifo ${get_pipe}
    can_access "${get_pipe}" || echo_erro "mkfifo: ${get_pipe} fail"

    local get_fd=0
    exec {get_fd}<>${get_pipe}

    mdat_task_ctrl "GET_VAR${GBL_SPF1}${var_name}${GBL_SPF2}${get_pipe}" "${one_pipe}"
    read var_valu < ${get_pipe}

    eval "exec ${get_fd}>&-"
    rm -f ${get_pipe}

    eval "export ${var_name}=\"${var_valu}\""
    echo_debug "mdata get: [${var_name} = \"${var_valu}\"]" 
}

function global_unset_var
{
    local var_name="$1"
    local one_pipe="$2"
    
    mdat_task_ctrl "UNSET_VAR${GBL_SPF1}${var_name}" "${one_pipe}"
}

function global_clear_var
{
    local var_name="$*"

    if [ -z "${var_name}" ];then
        mdat_task_ctrl "CLEAR_VAR${GBL_SPF1}ALL"
    else
        mdat_task_ctrl "CLEAR_VAR${GBL_SPF1}${var_name}"
    fi
}

function global_print_var
{
    local var_name="$*"

    if [ -z "${var_name}" ];then
        mdat_task_ctrl "PRINT_VAR${GBL_SPF1}ALL"
    else
        mdat_task_ctrl "PRINT_VAR${GBL_SPF1}${var_name}"
    fi
}

function _bash_mdata_exit
{ 
    echo_debug "mdata signal exit REMOTE_SSH=${REMOTE_SSH}" 

    mdat_task_ctrl_sync "EXIT"

    eval "exec ${GBL_MDAT_FD}>&-"
    rm -f ${GBL_MDAT_PIPE} 
}
