#!/bin/bash
_USR_BASE_DIR="/tmp/usr"
USR_CTRL_EXIT=0

function send_ctrl_to_self
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "ctrl to self: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    local sendctx="${GBL_ACK_SPF}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
    if [ -w ${USR_CTRL_THIS_PIPE} ];then
        echo "${sendctx}" > ${USR_CTRL_THIS_PIPE}
    else
        if [ -d ${USR_CTRL_THIS_DIR} ];then
            echo_erro "removed: ${USR_CTRL_THIS_PIPE}"
        fi
    fi
}

function send_ctrl_to_parent
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "ctrl to parent: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    local sendctx="${GBL_ACK_SPF}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
    if [ -w ${USR_CTRL_HIGH_PIPE} ];then
        echo "${sendctx}" > ${USR_CTRL_HIGH_PIPE}
    else
        if [ -d ${USR_CTRL_HIGH_DIR} ];then
            echo_erro "removed: ${USR_CTRL_HIGH_PIPE}"
        fi
    fi
}

function send_ctrl_to_self_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "ctrl ato self: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    if [ -w ${USR_CTRL_THIS_PIPE} ];then
        local self_pid=$(ppid | sed -n '1p')
        local ack_fd=$(make_ack "${self_pid}"; echo $?)
        local ack_pipe="${GBL_CTRL_THIS_DIR}/ack.${self_pid}"

        if [ -n "${ack_pipe}" ];then
            access_ok "${ack_pipe}" || echo_erro "ack pipe invalid: ${ack_pipe}"
        fi

        local sendctx="NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
        echo "${sendctx}" > ${USR_CTRL_THIS_PIPE}

        wait_ack "${self_pid}" "${ack_fd}"
    else
        if [ -d ${USR_CTRL_THIS_DIR} ];then
            echo_erro "removed: ${USR_CTRL_THIS_PIPE}"
        fi
    fi
}

function send_ctrl_to_parent_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "ctrl ato parent: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    if [ -w ${USR_CTRL_HIGH_PIPE} ];then
        local self_pid=$(ppid | sed -n '1p')
        local ack_fd=$(make_ack "${self_pid}"; echo $?)
        local ack_pipe="${GBL_CTRL_THIS_DIR}/ack.${self_pid}"

        if [ -n "${ack_pipe}" ];then
            access_ok "${ack_pipe}" || echo_erro "ack pipe invalid: ${ack_pipe}"
        fi

        local sendctx="NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
        echo "${sendctx}" > ${USR_CTRL_HIGH_PIPE}

        wait_ack "${self_pid}" "${ack_fd}"
    else
        if [ -d ${USR_CTRL_HIGH_DIR} ];then
            echo_erro "removed: ${USR_CTRL_HIGH_PIPE}"
        fi
    fi
}

function usr_ctrl_thread
{
    declare -Ax childMap

    while read line
    do
        echo_debug "ctrl: [${line}]" 

        declare -F ctrl_user_handler &>/dev/null
        if [ $? -eq 0 ];then
            ctrl_user_handler "${line}"
        fi

        local ack_ctrl=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)
        local ack_pipe=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)
        local  request=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)

        if [ -n "${ack_pipe}" ];then
            access_ok "${ack_pipe}" || echo_erro "ack pipe invalid: ${line}"
        fi

        local req_ctrl=$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)
        local req_mssg=$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)

        if [[ "${req_ctrl}" == "CTRL" ]];then
            local sub_ctrl=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
            if [[ "${sub_ctrl}" == "EXIT" ]];then
                USR_CTRL_EXIT=1
                if [ -n "${ack_pipe}" ];then
                    echo_debug "ack to [${ack_pipe}]"
                    echo "ACK" > ${ack_pipe}
                fi
                exit 0
            elif [[ "${sub_ctrl}" == "EXCEPTION" ]];then
                for pid in ${!childMap[@]};do
                    echo_debug "child: $(process_pid2name "${pid}")[${pid}] killed" 
                    process_signal KILL ${pid}
                done
                process_signal KILL $$
            fi
        elif [[ "${req_ctrl}" == "CHILD_FORK" ]];then
            local pid=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
            local pipe=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)

            echo_debug "child: $(process_pid2name "${pid}")[${pid}] fork" 
            childMap["${pid}"]="${pipe}"
        elif [[ "${req_ctrl}" == "CHILD_EXIT" ]];then
            local pid=${req_mssg}
            pipe="${childMap[${pid}]}"
            if [ -z "${pipe}" ];then
                echo_debug "child[${pid}] have exited" 
            else
                echo_debug "child[${pid}] exit" 
                unset childMap["${pid}"]
            fi
        fi

        if [ -n "${ack_pipe}" ];then
            echo_debug "ack to [${ack_pipe}]"
            echo "ACK" > ${ack_pipe}
        fi
    done < ${USR_CTRL_THIS_PIPE}
}

function usr_ctrl_signal
{
    echo_debug "ctrl signal"

    send_ctrl_to_parent "CTRL" "EXCEPTION"
    send_ctrl_to_parent "CTRL" "EXIT"
    send_ctrl_to_self "CTRL" "EXCEPTION"

    if access_ok "${USR_CTRL_THIS_DIR}";then
        usr_ctrl_exit
        usr_ctrl_clear
    fi
}

function usr_ctrl_init_parent
{
    export USR_CTRL_HIGH_DIR="${_USR_BASE_DIR}/ctrl/pid.$PPID"
    export USR_CTRL_HIGH_PIPE="${USR_CTRL_HIGH_DIR}/msg"
}

function usr_ctrl_init_self
{
    export USR_CTRL_THIS_DIR="${_USR_BASE_DIR}/ctrl/pid.$$"

    rm -fr ${USR_CTRL_THIS_DIR}
    mkdir -p ${USR_CTRL_THIS_DIR}

    export USR_CTRL_THIS_PIPE="${USR_CTRL_THIS_DIR}/msg"
    export USR_CTRL_THIS_FD=${USR_CTRL_THIS_FD:-6}

    rm -f ${USR_CTRL_THIS_PIPE}
    mkfifo ${USR_CTRL_THIS_PIPE}
    access_ok "${USR_CTRL_THIS_PIPE}" || echo_erro "mkfifo: ${USR_CTRL_THIS_PIPE} fail"
}

function usr_ctrl_launch
{
    usr_ctrl_init_parent
    usr_ctrl_init_self

    exec {USR_CTRL_THIS_FD}<>${USR_CTRL_THIS_PIPE} # 自动分配FD 
    export USR_CTRL_THIS_FD=${USR_CTRL_THIS_FD}

    #trap "usr_ctrl_signal" SIGINT SIGTERM SIGKILL EXIT
    trap "usr_ctrl_signal" SIGINT SIGTERM SIGKILL
    usr_ctrl_thread &

    send_ctrl_to_parent "CHILD_FORK" "$$${GBL_CTRL_SPF2}${USR_CTRL_THIS_PIPE}"
}

function usr_ctrl_exit
{
    USR_CTRL_EXIT=1
    send_ctrl_to_self "CTRL" "EXIT"
}

function usr_ctrl_clear
{
    send_ctrl_to_parent "CHILD_EXIT" "$$"

    eval "exec ${USR_CTRL_THIS_FD}>&-"
    rm -fr ${USR_CTRL_THIS_DIR}
}

function ctrl_exited
{
    if bool_v "${USR_CTRL_EXIT}"; then
        return 0
    else
        return 1
    fi
}
