#!/bin/bash
_USR_BASE_DIR="/tmp/usr"

function send_ctrl_to_self
{
    local req_ctrl="$1"
    local req_mssg="$2"
    echo_debug "ctrl to self: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

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
    echo_debug "ctrl to parent: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

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
    echo_debug "ctrl ato self: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    if [ -w ${USR_CTRL_THIS_PIPE} ];then
        local ack_pipe="$(make_ack)"

        local sendctx="NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
        echo "${sendctx}" > ${USR_CTRL_THIS_PIPE}

        wait_ack "${ack_pipe}"
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
    echo_debug "ctrl ato parent: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    if [ -w ${USR_CTRL_HIGH_PIPE} ];then
        local ack_pipe="$(make_ack)"

        local sendctx="NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
        echo "${sendctx}" > ${USR_CTRL_HIGH_PIPE}

        wait_ack "${ack_pipe}"
    else
        if [ -d ${USR_CTRL_HIGH_DIR} ];then
            echo_erro "removed: ${USR_CTRL_HIGH_PIPE}"
        fi
    fi
}

function send_log_to_self
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "log to self: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    local sendctx="${GBL_ACK_SPF}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
    if [ -w ${USR_LOGR_THIS_PIPE} ];then
        echo "${sendctx}" > ${USR_LOGR_THIS_PIPE}
    else
        if [ -d ${USR_LOGR_THIS_DIR} ];then
            echo_erro "removed: ${USR_LOGR_THIS_PIPE}"
        fi
    fi
}

function send_log_to_parent
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "log to parent: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    local sendctx="${GBL_ACK_SPF}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
    if [ -w ${USR_LOGR_HIGH_PIPE} ];then
        echo "${sendctx}" > ${USR_LOGR_HIGH_PIPE}
    else
        if [ -d ${USR_LOGR_HIGH_DIR} ];then
            echo_erro "removed: ${USR_LOGR_HIGH_PIPE}"
        fi
    fi
}

function send_log_to_self_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "log ato self: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    if [ -w ${USR_LOGR_THIS_PIPE} ];then
        local ack_pipe="$(make_ack)"

        local sendctx="NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
        echo "${sendctx}" > ${USR_LOGR_THIS_PIPE}

        wait_ack "${ack_pipe}"
    else
        if [ -d ${USR_LOGR_THIS_DIR} ];then
            echo_erro "removed: ${USR_LOGR_THIS_PIPE}"
        fi
    fi
}

function send_log_to_parent_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "log ato parent: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    if [ -w ${USR_LOGR_HIGH_PIPE} ];then
        local ack_pipe="$(make_ack)"

        local sendctx="NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
        echo "${sendctx}" > ${USR_LOGR_HIGH_PIPE}

        wait_ack "${ack_pipe}"
    else
        if [ -d ${USR_LOGR_HIGH_DIR} ];then
            echo_erro "removed: ${USR_LOGR_HIGH_PIPE}"
        fi
    fi
}

function ctrl_default_handler
{
    line="$1"

    local ack_ctrl="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)"
    local ack_pipe="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)"
    local  request="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)"

    local req_ctrl="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)"
    local req_mssg="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)"

    if [[ "${req_ctrl}" == "CTRL" ]];then
        local sub_ctrl="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)"
        if [[ "${sub_ctrl}" == "EXIT" ]];then
            if [ -n "${ack_pipe}" ];then
                echo_debug "ack to ${ack_pipe}"
                echo "ACK" > ${ack_pipe}
            fi
            exit 0
        elif [[ "${sub_ctrl}" == "EXCEPTION" ]];then
            for pid in ${!childMap[@]};do
                echo_debug "child: $(process_name "${pid}")[${pid}] killed" 
                signal_process KILL ${pid}
            done
        fi
    elif [[ "${req_ctrl}" == "CHILD_FORK" ]];then
        local pid="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)"
        local pipe="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)"

        echo_debug "child: $(process_name "${pid}")[${pid}] fork" 
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
        echo_debug "ack to ${ack_pipe}"
        echo "ACK" > ${ack_pipe}
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

        ctrl_default_handler "${line}"
    done < ${USR_CTRL_THIS_PIPE}
}

function loger_default_handler
{
    line="$1"

    local ack_ctrl="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)"
    local ack_pipe="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)"
    local  request="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)"

    local req_ctrl="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)"
    local req_mssg="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)"
    
    if [[ "${req_ctrl}" == "CTRL" ]];then
        local sub_ctrl="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)"
        if [[ "${sub_ctrl}" == "EXIT" ]];then
            if [ -n "${ack_pipe}" ];then
                echo_debug "ack to ${ack_pipe}"
                echo "ACK" > ${ack_pipe}
            fi
            exit 0
        elif [[ "${sub_ctrl}" == "EXCEPTION" ]];then
            echo_debug "NULLLLLLLLLLLLLLLLLLL" 
        fi
    elif [[ "${req_ctrl}" == "CURSOR_MOVE" ]];then
        local x_val="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)"
        local y_val="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)"
        tput cup ${x_val} ${y_val}
    elif [[ "${req_ctrl}" == "CURSOR_HIDE" ]];then
        tput civis
    elif [[ "${req_ctrl}" == "CURSOR_SHOW" ]];then
        tput cnorm
    elif [[ "${req_ctrl}" == "CURSOR_SAVE" ]];then
        tput sc
    elif [[ "${req_ctrl}" == "CURSOR_RESTORE" ]];then
        tput rc
    elif [[ "${req_ctrl}" == "ERASE_LINE" ]];then
        tput el
    elif [[ "${req_ctrl}" == "ERASE_BEHIND" ]];then
        tput ed
    elif [[ "${req_ctrl}" == "ERASE_ALL" ]];then
        tput clear
    elif [[ "${req_ctrl}" == "RETURN" ]];then
        printf "\r"
    elif [[ "${req_ctrl}" == "NEWLINE" ]];then
        printf "\n"
    elif [[ "${req_ctrl}" == "BACKSPACE" ]];then
        printf "\b"
    elif [[ "${req_ctrl}" == "PRINT" ]];then
        printf "%s" "${req_mssg}" 
    fi

    if [ -n "${ack_pipe}" ];then
        echo_debug "ack to ${ack_pipe}"
        echo "ACK" > ${ack_pipe}
    fi
}

function usr_logr_thread
{
    while read line
    do
        echo_debug "logr: [${line}]" 

        declare -F loger_user_handler &>/dev/null
        if [ $? -eq 0 ];then
            loger_user_handler "${line}"
        fi

        loger_default_handler "${line}"
    done < ${USR_LOGR_THIS_PIPE}
}

function usr_ctrl_signal
{
    echo_debug "ctrl signal"

    send_ctrl_to_parent "CTRL" "EXCEPTION"
    send_ctrl_to_parent "CTRL" "EXIT"
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
}

function usr_ctrl_launch
{
    usr_ctrl_init_parent
    usr_ctrl_init_self

    exec {USR_CTRL_THIS_FD}<>${USR_CTRL_THIS_PIPE} # 自动分配FD 
    export USR_CTRL_THIS_FD=${USR_CTRL_THIS_FD}

    trap "usr_ctrl_signal" SIGINT SIGTERM SIGKILL EXIT
    usr_ctrl_thread &

    send_ctrl_to_parent "CHILD_FORK" "$$${GBL_CTRL_SPF2}${USR_CTRL_THIS_PIPE}"
}

function usr_ctrl_exit
{
    send_ctrl_to_self "CTRL" "EXIT"
}

function usr_ctrl_clear
{
    send_ctrl_to_parent "CHILD_EXIT" "$$"

    eval "exec ${USR_CTRL_THIS_FD}>&-"
    rm -fr ${USR_CTRL_THIS_DIR}
}

function usr_logr_signal
{
    echo_debug "logr signal"

    send_log_to_parent "CTRL" "EXCEPTION"
    send_log_to_parent "CTRL" "EXIT"
    if access_ok "${USR_LOGR_THIS_DIR}";then
        usr_logr_exit
        usr_logr_clear
    fi
}

function usr_logr_init_parent
{
    export USR_LOGR_HIGH_DIR="${_USR_BASE_DIR}/logr/pid.$PPID"
    export USR_LOGR_HIGH_PIPE="${USR_LOGR_HIGH_DIR}/log"
}

function usr_logr_init_self
{
    export USR_LOGR_THIS_DIR="${_USR_BASE_DIR}/logr/pid.$$"

    rm -fr ${USR_LOGR_THIS_DIR}
    mkdir -p ${USR_LOGR_THIS_DIR}

    export USR_LOGR_THIS_PIPE="${USR_LOGR_THIS_DIR}/log"
    export USR_LOGR_THIS_FD=${USR_LOGR_THIS_FD:-7}

    rm -f ${USR_LOGR_THIS_PIPE}
    mkfifo ${USR_LOGR_THIS_PIPE}
}

function usr_logr_launch
{ 
    usr_logr_init_parent
    usr_logr_init_self

    exec {USR_LOGR_THIS_FD}<>${USR_LOGR_THIS_PIPE} # 自动分配FD 
    export USR_LOGR_THIS_FD=${USR_LOGR_THIS_FD}

    trap "usr_logr_signal" SIGINT SIGTERM SIGKILL EXIT
    usr_logr_thread &

    send_ctrl_to_parent "CHILD_FORK" "$$${GBL_CTRL_SPF2}${USR_CTRL_THIS_PIPE}"
}

function usr_logr_exit
{
    send_log_to_self "CTRL" "EXIT"
}

function usr_logr_clear
{
    eval "exec ${USR_LOGR_THIS_FD}>&-"
    rm -fr ${USR_LOGR_THIS_DIR}
}
