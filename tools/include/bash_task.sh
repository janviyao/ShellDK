#!/bin/bash
_GBL_BASE_DIR="/tmp/gbl"

GBL_CTRL_THIS_DIR="${_GBL_BASE_DIR}/ctrl/pid.$$"
GBL_CTRL_THIS_PIPE="${GBL_CTRL_THIS_DIR}/msg"
mkdir -p ${GBL_CTRL_THIS_DIR}

GBL_CTRL_THIS_FD=${GBL_CTRL_THIS_FD:-6}
mkfifo ${GBL_CTRL_THIS_PIPE}
access_ok "${GBL_CTRL_THIS_PIPE}" || echo_erro "mkfifo: ${GBL_CTRL_THIS_PIPE} fail"
exec {GBL_CTRL_THIS_FD}<>${GBL_CTRL_THIS_PIPE}

GBL_LOGR_THIS_DIR="${_GBL_BASE_DIR}/logr/pid.$$"
GBL_LOGR_THIS_PIPE="${GBL_LOGR_THIS_DIR}/log"
mkdir -p ${GBL_LOGR_THIS_DIR}

GBL_LOGR_THIS_FD=${GBL_LOGR_THIS_FD:-7}
mkfifo ${GBL_LOGR_THIS_PIPE}
access_ok "${GBL_LOGR_THIS_PIPE}" || echo_erro "mkfifo: ${GBL_LOGR_THIS_PIPE} fail"
exec {GBL_LOGR_THIS_FD}<>${GBL_LOGR_THIS_PIPE} # 自动分配FD 

GBL_ACK_SPF="#"
GBL_CTRL_SPF1="^"
GBL_CTRL_SPF2="|"
GBL_CTRL_SPF3="!"

GBL_SRV_IDNO=$$
GBL_SRV_ADDR="$(ssh_address)"
GBL_SRV_PORT=7888

function global_set_var
{
    local var_name="$1"
    local one_pipe="$2"
    echo_debug "global set: [$*]" 

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_THIS_PIPE}"
    fi
    access_ok "${one_pipe}" || echo_erro "pipe invalid: ${one_pipe}"

    local var_value="$(eval "echo \"\$${var_name}\"")"
    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}SET_ENV${GBL_CTRL_SPF1}${var_name}${GBL_CTRL_SPF2}${var_value}" > ${one_pipe}
}

function global_get_var
{
    local var_name="$1"
    local one_pipe="$2"
    echo_debug "global get: [$*]" 

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_THIS_PIPE}"
    fi
    access_ok "${one_pipe}" || echo_erro "pipe invalid: ${one_pipe}"

    local var_value=""

    local get_pipe="${GBL_CTRL_THIS_DIR}/get.$$"
    mkfifo ${get_pipe}
    access_ok "${get_pipe}" || echo_erro "mkfifo: ${get_pipe} fail"

    local get_fd=0
    exec {get_fd}<>${get_pipe}

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}GET_ENV${GBL_CTRL_SPF1}${var_name}${GBL_CTRL_SPF2}${get_pipe}" > ${one_pipe}
    read -t 10 var_value < ${get_pipe}

    eval "exec ${get_fd}>&-"
    rm -f ${get_pipe}

    eval "export ${var_name}=\"${var_value}\""
}

function global_unset_var
{
    local var_name="$1"
    local one_pipe="$2"
    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_THIS_PIPE}"
    fi
    access_ok "${one_pipe}" || echo_erro "pipe invalid: ${one_pipe}"

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}UNSET_ENV${GBL_CTRL_SPF1}${var_name}" > ${one_pipe}
}

function global_clear_var
{
    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}CLEAR_ENV${GBL_CTRL_SPF1}ALL" > ${GBL_CTRL_THIS_PIPE}
}

function global_print_var
{
    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}PRINT_ENV${GBL_CTRL_SPF1}ALL" > ${GBL_CTRL_THIS_PIPE}
}

function make_ack
{
    local self_pid=$1
    local ack_pipe="${GBL_CTRL_THIS_DIR}/ack.${self_pid}"
    
    access_ok "${ack_pipe}" && rm -f ${ack_pipe}
    mkfifo ${ack_pipe}
    access_ok "${ack_pipe}" || echo_erro "mkfifo: ${ack_pipe} fail"
    echo_debug "make ack: ${ack_pipe}"

    local ack_fd=0
    exec {ack_fd}<>${ack_pipe}
    
    return ${ack_fd}
}

function wait_ack
{
    local self_pid=$1
    local ack_fd=$2

    local ack_pipe="${GBL_CTRL_THIS_DIR}/ack.${self_pid}"
    echo_debug "wait ack: ${ack_pipe}"

    read ack_response < ${ack_pipe}

    eval "exec ${ack_fd}>&-"
    rm -f ${ack_pipe}
}

function global_wait_ack
{
    local msgctx="$1"
    
    # the first pid is shell where ppid run
    local self_pid=$(ppid | sed -n '1p')
    local ack_fd="$(make_ack "${self_pid}"; echo $?)"
    local ack_pipe="${GBL_CTRL_THIS_DIR}/ack.${self_pid}"

    echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${msgctx}" > ${GBL_CTRL_THIS_PIPE}

    wait_ack "${self_pid}" "${ack_fd}"
}

function _global_ctrl_bg_thread
{
    declare -A _globalMap
    while read line
    do
        echo_debug "global ctrl: [${line}]" 
        local ack_ctrl="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)"
        local ack_pipe="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)"
        local  request="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)"

        if [ -n "${ack_pipe}" ];then
            access_ok "${ack_pipe}" || echo_erro "ack pipe invalid: ${ack_pipe}"
        fi

        local req_ctrl="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)"
        local req_mssg="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)"
        
        if [[ "${req_ctrl}" == "EXIT" ]];then
            exit 0 
        elif [[ "${req_ctrl}" == "SET_ENV" ]];then
            local var_name="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)"
            local var_value="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)"

            _globalMap[${var_name}]="${var_value}"
        elif [[ "${req_ctrl}" == "GET_ENV" ]];then
            local var_name="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)"
            local var_pipe="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)"

            echo "${_globalMap[${var_name}]}" > ${var_pipe}
        elif [[ "${req_ctrl}" == "UNSET_ENV" ]];then
            local var_name=${req_mssg}
            unset _globalMap[${var_name}]
        elif [[ "${req_ctrl}" == "CLEAR_ENV" ]];then
            if [ ${#_globalMap[@]} -ne 0 ];then
                for var_name in ${!_globalMap[@]};do
                    unset _globalMap[${var_name}]
                done
            fi
        elif [[ "${req_ctrl}" == "PRINT_ENV" ]];then
            if [ ${#_globalMap[@]} -ne 0 ];then
                echo "" > /dev/tty
                for var_name in ${!_globalMap[@]};do
                    echo "$(printf "[%15s]: %s" "${var_name}" "${_globalMap[${var_name}]}")" > /dev/tty
                done
                #echo "send \010" | expect 
            fi
        elif [[ "${req_ctrl}" == "RECV_MSG" ]];then
            if access_ok "nc";then
            {
                if [ -n "${ack_pipe}" ];then
                    echo "ACK" > ${ack_pipe}
                fi
                
                for pid in `pgrep nc`
                do
                    if is_number "${pid}";then
                        ${SUDO} kill -s INT ${pid}
                    fi
                done

                timeout ${OP_TIMEOUT} nc -l -4 ${GBL_SRV_PORT} | while read nc_msg
                do
                    #echo "ncat_msg: ${nc_msg}"
                    local srv_id="$(echo "${nc_msg}" | cut -d "${GBL_CTRL_SPF1}" -f 1)"
                    local srv_msg="$(echo "${nc_msg}" | cut -d "${GBL_CTRL_SPF1}" -f 2)"

                    if [ ${srv_id} -eq ${GBL_SRV_IDNO} ];then
                        if [ -n "${srv_msg}" ];then
                            local srv_ctrl="$(echo "${srv_msg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)"
                            local srv_act="$(echo "${srv_msg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)"

                            if [[ "${srv_ctrl}" == "RETURN_CODE" ]];then
                                local var_name="$(echo "${srv_act}" | cut -d "=" -f 1)"
                                local var_value="$(echo "${srv_act}" | cut -d "=" -f 2)"

                                eval "${var_name}=${var_value}"
                                global_set_var ${var_name}
                            fi
                        fi
                    fi
                done
            } &
            fi
        fi
    done < ${GBL_CTRL_THIS_PIPE}
}

function global_send_log
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "log to self: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    local sendctx="${GBL_ACK_SPF}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
    if [ -w ${GBL_LOGR_THIS_PIPE} ];then
        echo "${sendctx}" > ${GBL_LOGR_THIS_PIPE}
    else
        if [ -d ${GBL_LOGR_THIS_DIR} ];then
            echo_erro "removed: ${GBL_LOGR_THIS_PIPE}"
        fi
    fi
}

function global_send_log_sync
{
    local req_ctrl="$1"
    local req_mssg="$2"
    #echo_debug "log ato self: [ctrl: ${req_ctrl} msg: ${req_mssg}]" 

    if [ -w ${GBL_LOGR_THIS_PIPE} ];then
        local self_pid=$(ppid | sed -n '1p')
        local ack_fd="$(make_ack "${self_pid}"; echo $?)"
        local ack_pipe="${GBL_CTRL_THIS_DIR}/ack.${self_pid}"

        if [ -n "${ack_pipe}" ];then
            access_ok "${ack_pipe}" || echo_erro "ack pipe invalid: ${ack_pipe}"
        fi

        local sendctx="NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${req_ctrl}${GBL_CTRL_SPF1}${req_mssg}"
        echo "${sendctx}" > ${GBL_LOGR_THIS_PIPE}

        wait_ack "${self_pid}" "${ack_fd}"
    else
        if [ -d ${GBL_LOGR_THIS_DIR} ];then
            echo_erro "removed: ${GBL_LOGR_THIS_PIPE}"
        fi
    fi
}

function _global_logr_bg_thread
{
    while read line
    do
        echo_debug "global logr: [${line}]" 
        local ack_ctrl="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)"
        local ack_pipe="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)"
        local  request="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)"

        if [ -n "${ack_pipe}" ];then
            access_ok "${ack_pipe}" || echo_erro "ack pipe invalid: ${ack_pipe}"
        fi

        local req_ctrl="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)"
        local req_mssg="$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)"

        if [[ "${req_ctrl}" == "CTRL" ]];then
            local sub_ctrl="$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)"
            if [[ "${sub_ctrl}" == "EXIT" ]];then
                if [ -n "${ack_pipe}" ];then
                    echo_debug "ack to [${ack_pipe}]"
                    echo "ACK" > ${ack_pipe}
                fi
                exit 0
            elif [[ "${sub_ctrl}" == "EXCEPTION" ]];then
                echo_debug "NOP" 
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
        elif [[ "${req_ctrl}" == "PRINT_FROM_FILE" ]];then
            local file_log=$(cat ${req_mssg}) 
            printf "%s" "${file_log}" 
        fi

        if [ -n "${ack_pipe}" ];then
            echo_debug "ack to [${ack_pipe}]"
            echo "ACK" > ${ack_pipe}
        fi
    done < ${GBL_LOGR_THIS_PIPE}
}

function _bash_exit
{ 
    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi

    echo 'EXIT' > ${GBL_CTRL_THIS_PIPE}
    eval "exec ${GBL_CTRL_THIS_FD}>&-"

    echo 'EXIT' > ${GBL_LOGR_THIS_PIPE}
    eval "exec ${GBL_LOGR_THIS_FD}>&-"

    rm -fr ${GBL_CTRL_THIS_DIR}
    rm -fr ${GBL_LOGR_THIS_DIR}

    access_ok "${LOG_FILE}" && rm -f ${LOG_FILE}

    exit 0
}

trap "_bash_exit" EXIT

{
    trap "" SIGINT SIGTERM SIGKILL
    _global_ctrl_bg_thread
}&

{
    trap "" SIGINT SIGTERM SIGKILL
    _global_logr_bg_thread
}&

