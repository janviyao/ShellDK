#!/bin/bash
_GBL_BASE_DIR="/tmp/gbl"

GBL_CTRL_THIS_DIR="${_GBL_BASE_DIR}/ctrl/pid.$$"
GBL_CTRL_THIS_PIPE="${GBL_CTRL_THIS_DIR}/msg"

GBL_ACK_SPF="#"
GBL_CTRL_SPF1="^"
GBL_CTRL_SPF2="|"
GBL_CTRL_SPF3="!"

rm -fr ${GBL_CTRL_THIS_DIR}
mkdir -p ${GBL_CTRL_THIS_DIR}

GBL_CTRL_THIS_FD=${GBL_CTRL_THIS_FD:-6}
mkfifo ${GBL_CTRL_THIS_PIPE}
exec {GBL_CTRL_THIS_FD}<>${GBL_CTRL_THIS_PIPE}

GBL_SRV_IDNO=$$
GBL_SRV_ADDR="$(ssh_address)"
GBL_SRV_PORT=7888

function global_set_var
{
    local var_name="$1"
    local one_pipe="$2"
    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_THIS_PIPE}"
    fi

    local var_value="$(eval "echo \"\$${var_name}\"")"
    echo "${GBL_ACK_SPF}${GBL_ACK_SPF}SET_ENV${GBL_CTRL_SPF1}${var_name}${GBL_CTRL_SPF2}${var_value}" > ${one_pipe}
}

function global_get_var
{
    local var_name="$1"
    local one_pipe="$2"
    if [ -z "${one_pipe}" ];then
        one_pipe="${GBL_CTRL_THIS_PIPE}"
    fi

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
    local ack_pipe="${GBL_CTRL_THIS_DIR}/ack.$$"

    mkfifo ${ack_pipe}
    access_ok "${ack_pipe}" || echo_erro "mkfifo: ${ack_pipe} fail"

    local ack_fd=0
    exec {ack_fd}<>${ack_pipe}

    echo "${ack_pipe}${GBL_ACK_SPF}${ack_fd}"
}

function wait_ack
{
    local ack_str="$1"

    local ack_pipe="$(cut -d "${GBL_ACK_SPF}" -f 1 <<< "${ack_str}")"
    local ack_fd="$(cut -d "${GBL_ACK_SPF}" -f 2 <<< "${ack_str}")"

    read ack_response < ${ack_pipe}

    eval "exec ${ack_fd}>&-"
    rm -f ${ack_pipe}
}

function global_wait_ack
{
    local msgctx="$1"
    
    local ack_str="$(make_ack)"
    local ack_pipe="$(cut -d "${GBL_ACK_SPF}" -f 1 <<< "${ack_str}")"

    echo "NEED_ACK${GBL_ACK_SPF}${ack_pipe}${GBL_ACK_SPF}${msgctx}" > ${GBL_CTRL_THIS_PIPE}

    wait_ack "${ack_str}"
}

function _global_ctrl_bg_thread
{
    declare -A _globalMap
    while read line
    do
        echo_debug "[$$]global: [${line}]" 
        local ack_ctrl="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 1)"
        local ack_pipe="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 2)"
        local  request="$(echo "${line}" | cut -d "${GBL_ACK_SPF}" -f 3)"

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

trap "echo 'EXIT' > ${GBL_CTRL_THIS_PIPE}; exec ${GBL_CTRL_THIS_FD}>&-; rm -fr ${_GBL_BASE_DIR}; exit 0" EXIT
{
    trap "" SIGINT SIGTERM SIGKILL
    _global_ctrl_bg_thread
}&
