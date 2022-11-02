#!/bin/bash
function how_use
{
    local script_name=$(path2fname $0)
    echo "=================== Usage ==================="
    printf "%-15s [<ip-address>] <command>\n" "${script_name}"
    printf "%-15s @%s\n" "<ip-address>" "[optinal]ip address where it will do the <command>"
    printf "%-15s @%s\n" "<command>"    "shell command"
    echo "============================================="
}

if [ $# -lt 1 ];then
    how_use
    exit 1
fi

HOST_IP="$1"
shift
CMD_EXE="$@"

if [ -z "${USR_NAME}" -o -z "${USR_PASSWORD}" ]; then
    if ! account_check ${MY_NAME};then
        echo_erro "Username or Password check fail"
        exit 1
    fi
fi

echo_debug "paras: { ${HOST_IP} ${CMD_EXE} }"
echo_debug "Get { ${CMD_EXE} } from { ${HOST_IP} }"

if match_regex "${HOST_IP}" "\d+\.\d+\.\d+\.\d+";then
    if [[ ${HOST_IP} == ${LOCAL_IP} ]];then
        eval "${CMD_EXE}"
        exit $?
    elif ! check_net ${HOST_IP};then
        echo_erro "address { ${HOST_IP} } not arrived"
        exit 1
    fi
else
    if [[ ${HOST_IP} == $(hostname) ]];then
        eval "${CMD_EXE}"
        exit $?
    elif ! check_net ${HOST_IP};then
        eval "${HOST_IP} $@"
        exit $?
    fi
fi

if [ -z "${CMD_EXE}" ];then
    exit 0
fi

tmp_file="/tmp/get.${RANDOM}"
PKG_MSG="(${CMD_EXE}) &> ${tmp_file}; remote_send_file ${NCAT_MASTER_ADDR} ${NCAT_MASTER_PORT} ${tmp_file}; rm -f ${tmp_file}"

$MY_VIM_DIR/tools/sshlogin.sh "${HOST_IP}" "${PKG_MSG}" &> /dev/null
if [ $? -ne 0 ];then
    echo_erro "ssh fail: \"${CMD_EXE}\" @ ${HOST_IP}"
fi

if can_access "${tmp_file}";then
    cat ${tmp_file}
    rm -f ${tmp_file}
fi
