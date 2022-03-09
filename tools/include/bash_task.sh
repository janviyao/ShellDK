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

GBL_SRV_ADDR=$(ssh_address)
GBL_SRV_PORT=7888
GBL_TRX_PORT=7889

function ncat_send_msg
{
    local ncat_addr="$1"
    local ncat_port="$2"
    local send_msg="$3"

    echo_debug "ncat send: [$*]" 
    if access_ok "nc";then
        (echo "${send_msg}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        while test $? -ne 0
        do
            (echo "${send_msg}" | nc ${ncat_addr} ${ncat_port}) &> /dev/null
        done
    fi
}

function ncat_recv_msg
{
    local ncat_port="$1"

    if access_ok "nc";then
        timeout ${OP_TIMEOUT} nc -l -4 ${ncat_port} | while read nc_msg
        do
            echo "${nc_msg}"
        done
    fi
}

function remote_push_result
{
    local srv_addr="$1"
    local res_file="$2"

    echo_debug "remote push: [$*]" 
    if access_ok "${res_file}";then
        ncat_send_msg ${srv_addr} ${GBL_SRV_PORT} "TRANSFER_FILE${GBL_CTRL_SPF1}${res_file}"

        (nc ${srv_addr} ${GBL_TRX_PORT} < ${res_file}) &> /dev/null
        while test $? -ne 0
        do
            (nc ${srv_addr} ${GBL_TRX_PORT} < ${res_file}) &> /dev/null
        done
    fi
}

function remote_set_var
{
    local srv_addr="$1"
    local var_name="$2"
    local var_value="$3"

    echo_debug "remote set: [$*]" 
    ncat_send_msg ${srv_addr} ${GBL_SRV_PORT} "REMOTE_SET${GBL_CTRL_SPF1}${var_name}=${var_value}"
}

function global_var_exist
{
    local var_name="$1"
    local one_pipe="$2"
    echo_debug "global check: [$*]" 

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_THIS_PIPE}"
    fi
    access_ok "${one_pipe}" || echo_erro "pipe invalid: ${one_pipe}"

    local check_ret=""

    local self_pid=$$
    if access_ok "ppid";then
        local self_pid=$(ppid | sed -n '1p')
    fi
    local check_pipe="${GBL_CTRL_THIS_DIR}/check.${self_pid}"

    mkfifo ${check_pipe}
    access_ok "${check_pipe}" || echo_erro "mkfifo: ${check_pipe} fail"

    local get_fd=0
    exec {get_fd}<>${check_pipe}

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}ENV_EXIST${GBL_CTRL_SPF1}${var_name}${GBL_CTRL_SPF2}${check_pipe}" > ${one_pipe}
    read check_ret < ${check_pipe}

    eval "exec ${get_fd}>&-"
    rm -f ${check_pipe}

    if bool_v "${check_ret}";then
        return 0
    else
        return 1
    fi
}

function global_set_var
{
    local var_name="$1"
    local one_pipe="$2"

    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_THIS_PIPE}"
    fi
    access_ok "${one_pipe}" || echo_erro "pipe invalid: ${one_pipe}"

    local var_value="$(eval "echo \"\$${var_name}\"")"

    echo_debug "global set: [$* = ${var_value}]" 
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

    local rand_pid=$$
    if access_ok "ppid";then
        local rand_pid=$(ppid | sed -n '1p')
    fi
    local get_pipe="${GBL_CTRL_THIS_DIR}/get.${rand_pid}"

    mkfifo ${get_pipe}
    access_ok "${get_pipe}" || echo_erro "mkfifo: ${get_pipe} fail"

    local get_fd=0
    exec {get_fd}<>${get_pipe}

    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}GET_ENV${GBL_CTRL_SPF1}${var_name}${GBL_CTRL_SPF2}${get_pipe}" > ${one_pipe}
    read var_value < ${get_pipe}

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

function global_ncat_ctrl
{
    local msgctx="$1"
    
    # the first pid is shell where ppid run
    local self_pid=$$
    if access_ok "ppid";then
        local self_pid=$(ppid | sed -n '2p')
    fi
    local ack_fd=$(make_ack "${self_pid}"; echo $?)
    local ack_pipe="${GBL_CTRL_THIS_DIR}/ack.${self_pid}"

    echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}NCAT${GBL_CTRL_SPF1}${msgctx}" > ${GBL_CTRL_THIS_PIPE}

    wait_ack "${self_pid}" "${ack_fd}"
}

function _global_ctrl_bg_thread
{
    local ncat_work=true
    declare -A _globalMap

    while read line
    do
        echo_debug "global ctrl: [${line}]" 
        local ack_ctrl=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)
        local ack_pipe=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)
        local  request=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)

        if [ -n "${ack_pipe}" ];then
            access_ok "${ack_pipe}" || echo_erro "ack pipe invalid: ${ack_pipe}"
        fi

        local req_ctrl=$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)
        local req_mssg=$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)
        
        if [[ "${req_ctrl}" == "EXIT" ]];then
            exit 0 
        elif [[ "${req_ctrl}" == "SET_ENV" ]];then
            local var_name=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
            local var_value=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)

            _globalMap[${var_name}]="${var_value}"
        elif [[ "${req_ctrl}" == "GET_ENV" ]];then
            local var_name=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
            local var_pipe=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)
            
            echo_debug "write [${_globalMap[${var_name}]}] into [${var_pipe}]"
            echo "${_globalMap[${var_name}]}" > ${var_pipe}
        elif [[ "${req_ctrl}" == "ENV_EXIST" ]];then
            local var_name=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
            local var_pipe=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)
            
            if contain_str "${!_globalMap[*]}" "${var_name}";then
                echo_debug "check [${var_name}] exist for [${var_pipe}]"
                echo "true" > ${var_pipe}
            else
                echo_debug "check [${var_name}] absent for [${var_pipe}]"
                echo "false" > ${var_pipe}
            fi
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
        elif [[ "${req_ctrl}" == "NCAT" ]];then
            if [ -n "${ack_pipe}" ];then
                echo "ACK" > ${ack_pipe}
            fi

            if [[ "${req_mssg}" == "NCAT_START" ]];then 
                if access_ok "nc";then
                {
                    process_signal INT 'nc'
                    ncat_work=true
                    global_set_var "ncat_work"

                    while bool_v "${ncat_work}" 
                    do
                        echo_debug "ncat listening into ${GBL_SRV_PORT} ..."
                        local nc_msg=$(ncat_recv_msg "${GBL_SRV_PORT}")

                        echo_debug "ncat msg: [${nc_msg}]" 
                        local srv_ctrl=$(echo "${nc_msg}" | cut -d "${GBL_CTRL_SPF1}" -f 1)
                        local srv_act=$(echo "${nc_msg}" | cut -d "${GBL_CTRL_SPF1}" -f 2)

                        if [[ "${srv_ctrl}" == "REMOTE_SET" ]];then
                            local var_name=$(echo "${srv_act}" | cut -d "=" -f 1)
                            local var_value=$(echo "${srv_act}" | cut -d "=" -f 2)

                            eval "${var_name}=${var_value}"
                            global_set_var "${var_name}"
                        elif [[ "${srv_ctrl}" == "TRANSFER_FILE" ]];then
                            timeout ${OP_TIMEOUT} nc -l -4 ${GBL_TRX_PORT} > ${srv_act}
                        elif [[ "${srv_ctrl}" == "REQ_ACK" ]];then
                            local remote_addr=$(echo "${srv_act}" | cut -d "${GBL_CTRL_SPF3}" -f 1)
                            local remote_port=$(echo "${srv_act}" | cut -d "${GBL_CTRL_SPF3}" -f 2)
                            echo "ACK" | nc ${remote_addr} ${remote_port}
                        fi

                        global_get_var "ncat_work"
                    done
                } &
                fi
            elif [[ "${req_mssg}" == "NCAT_QUIT" ]];then
                if access_ok "nc";then
                    ncat_work=false
                    global_set_var "ncat_work"
                    process_signal INT 'nc'
                fi
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
        local self_pid=$$
        if access_ok "ppid";then
            local self_pid=$(ppid | sed -n '2p')
        fi
        local ack_fd=$(make_ack "${self_pid}"; echo $?)
        local ack_pipe=${GBL_CTRL_THIS_DIR}/ack.${self_pid}

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
        local ack_ctrl=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)
        local ack_pipe=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)
        local  request=$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)

        if [ -n "${ack_pipe}" ];then
            access_ok "${ack_pipe}" || echo_erro "ack pipe invalid: ${ack_pipe}"
        fi

        local req_ctrl=$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 1)
        local req_mssg=$(echo "${request}" | cut -d "${GBL_CTRL_SPF1}" -f 2)

        if [[ "${req_ctrl}" == "CTRL" ]];then
            local sub_ctrl=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
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
            local x_val=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 1)
            local y_val=$(echo "${req_mssg}" | cut -d "${GBL_CTRL_SPF2}" -f 2)
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
    echo 'EXIT' > ${GBL_CTRL_THIS_PIPE}
    eval "exec ${GBL_CTRL_THIS_FD}>&-"

    echo 'EXIT' > ${GBL_LOGR_THIS_PIPE}
    eval "exec ${GBL_LOGR_THIS_FD}>&-"

    rm -fr ${GBL_CTRL_THIS_DIR}
    rm -fr ${GBL_LOGR_THIS_DIR}

    access_ok "${LOG_FILE}" && rm -f ${LOG_FILE}
}

function _exit_signal
{ 
    trap - ERR

    if [ -f ${HOME}/.bash_exit ];then
        source ${HOME}/.bash_exit
    fi

    _bash_exit
    exit 0
}

trap "_exit_signal" EXIT

{
    trap "" SIGINT SIGTERM SIGKILL
    _global_ctrl_bg_thread
}&

{
    trap "" SIGINT SIGTERM SIGKILL
    _global_logr_bg_thread
}&

