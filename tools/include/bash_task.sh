#!/bin/bash
_GLOBAL_CTRL_DIR="/tmp/ctrl/global.$$"
_GLOBAL_CTRL_PIPE="${_GLOBAL_CTRL_DIR}/msg.global"

_GLOBAL_ACK_SPF="@"
_GLOBAL_CTRL_SPF1="^"
_GLOBAL_CTRL_SPF2="|"
_GLOBAL_CTRL_SPF3="!"

rm -fr ${_GLOBAL_CTRL_DIR}
mkdir -p ${_GLOBAL_CTRL_DIR}
_GLOBAL_CTRL_FD=6
mkfifo ${_GLOBAL_CTRL_PIPE}
exec {_GLOBAL_CTRL_FD}<>${_GLOBAL_CTRL_PIPE}

_MSG_OWNER=$$
_SERVER_ADDR="$(ssh_address)"
_SERVER_PORT=7888

function global_set_pipe
{
    local var_name="$1"
    local one_pipe="$2"
    local var_value="$(eval "echo \"\$${var_name}\"")"

    echo "SET_ENV${_GLOBAL_CTRL_SPF1}${var_name}${_GLOBAL_CTRL_SPF2}${var_value}" > ${one_pipe}
}

function global_set
{
    local var_name="$1"
    local var_value="$(eval "echo \"\$${var_name}\"")"

    echo "SET_ENV${_GLOBAL_CTRL_SPF1}${var_name}${_GLOBAL_CTRL_SPF2}${var_value}" > ${_GLOBAL_CTRL_PIPE}
}

function global_get
{
    local var_name="$1"
    local var_value=""

    local TMP_PIPE=${_GLOBAL_CTRL_DIR}/msg.$$
    mkfifo ${TMP_PIPE}

    echo "GET_ENV${_GLOBAL_CTRL_SPF1}${var_name}${_GLOBAL_CTRL_SPF2}${TMP_PIPE}" > ${_GLOBAL_CTRL_PIPE}
    read var_value < ${TMP_PIPE}
    rm -f ${TMP_PIPE}

    eval "export ${var_name}=\"${var_value}\""
}

function global_unset
{
    local var_name="$1"
    echo "UNSET_ENV${_GLOBAL_CTRL_SPF1}${var_name}" > ${_GLOBAL_CTRL_PIPE}
}

function global_clear
{
    local var_name="$1"
    echo "CLEAR_ENV${_GLOBAL_CTRL_SPF1}ALL" > ${_GLOBAL_CTRL_PIPE}
}

function global_print
{
    echo "PRINT_ENV${_GLOBAL_CTRL_SPF1}ALL" > ${_GLOBAL_CTRL_PIPE}
}

function global_wait_ack
{
    local msgctx="$1"

    local ACK_PIPE=${_GLOBAL_CTRL_DIR}/ack.$$
    mkfifo ${ACK_PIPE}

    echo "NEED_ACK${_GLOBAL_ACK_SPF}${ACK_PIPE}${_GLOBAL_ACK_SPF}${msgctx}" > ${_GLOBAL_CTRL_PIPE}
    read ack_response < ${ACK_PIPE}
    rm -f ${ACK_PIPE}
}

function _global_ctrl_bg_thread
{
    declare -A _globalMap
    while read line
    do
        #echo "[$$]global recv: [${line}]" 
        local ack_ctrl="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 1)"
        local ack_pipe="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 2)"
        local ack_msgr="$(echo "${line}" | cut -d "${_GLOBAL_ACK_SPF}" -f 3)"

        if [[ "${ack_ctrl}" == "NEED_ACK" ]];then
            local ctrl="$(echo "${ack_msgr}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 1)"
            local msg="$(echo "${ack_msgr}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 2)"
        else
            local ctrl="$(echo "${line}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 1)"
            local msg="$(echo "${line}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 2)"
        fi

        if [[ "${ctrl}" == "EXIT" ]];then
            exit 0 
        elif [[ "${ctrl}" == "SET_ENV" ]];then
            local var_name="$(echo "${msg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 1)"
            local var_value="$(echo "${msg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 2)"

            _globalMap[${var_name}]="${var_value}"
        elif [[ "${ctrl}" == "GET_ENV" ]];then
            local var_name="$(echo "${msg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 1)"
            local var_pipe="$(echo "${msg}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 2)"

            echo "${_globalMap[${var_name}]}" > ${var_pipe}
        elif [[ "${ctrl}" == "UNSET_ENV" ]];then
            local var_name=${msg}
            unset _globalMap[${var_name}]
        elif [[ "${ctrl}" == "CLEAR_ENV" ]];then
            if [ ${#_globalMap[@]} -ne 0 ];then
                for var_name in ${!_globalMap[@]};do
                    unset _globalMap[${var_name}]
                done
            fi
        elif [[ "${ctrl}" == "PRINT_ENV" ]];then
            if [ ${#_globalMap[@]} -ne 0 ];then
                echo "" > /dev/tty
                for var_name in ${!_globalMap[@]};do
                    echo "$(printf "[%15s]: %s" "${var_name}" "${_globalMap[${var_name}]}")" > /dev/tty
                done
                #echo "send \010" | expect 
            fi
        elif [[ "${ctrl}" == "RECV_MSG" ]];then
            {
                if [ -n "${ack_pipe}" ];then
                    echo "ACK" > ${ack_pipe}
                fi

                nc -l ${_SERVER_PORT} | while read raw_msg
                do
                    #echo "raw_msg: ${raw_msg}"
                    local owner="$(echo "${raw_msg}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 1)"
                    if [ ${owner} -eq ${_MSG_OWNER} ];then
                        local msgctx="$(echo "${raw_msg}" | cut -d "${_GLOBAL_CTRL_SPF1}" -f 2)"
                        if [ -n "${msgctx}" ];then
                            local ctrl="$(echo "${msgctx}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 1)"
                            local msg="$(echo "${msgctx}" | cut -d "${_GLOBAL_CTRL_SPF2}" -f 2)"
                            if [[ "${ctrl}" == "RETURN_CODE" ]];then
                                local var_name="$(echo "${msg}" | cut -d "=" -f 1)"
                                local var_value="$(echo "${msg}" | cut -d "=" -f 2)"
                                eval "${var_name}=${var_value}"
                                global_set ${var_name}
                            fi
                        fi
                    fi
                done
            } &
        fi
    done < ${_GLOBAL_CTRL_PIPE}
}

trap "echo 'EXIT' > ${_GLOBAL_CTRL_PIPE}; exec ${_GLOBAL_CTRL_FD}>&-; rm -fr ${_GLOBAL_CTRL_DIR}; exit 0" EXIT
{
    trap "" SIGINT SIGTERM SIGKILL
    _global_ctrl_bg_thread
}&
