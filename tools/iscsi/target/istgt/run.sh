#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

if ! math_bool "${KEEP_ENV_STATE}";then
    echo_info "kill and start: ${ISCSI_APP_NAME}"
else
    echo_info "keep exe: ${ISCSI_APP_NAME}"
    exit 0
fi

if ! file_exist "${ISCSI_APP_DIR}/${ISCSI_APP_NAME}";then
    if string_contain "${TEST_WORKGUIDE}" "deploy";then
        ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/build.sh
        if [ $? -ne 0 ];then
            echo_erro "build fail: ${ISCSI_APP_SRC}"
            exit 1
        fi
    else
        echo_erro "build fail: ${ISCSI_APP_SRC}"
        exit 1
    fi
fi

if string_contain "${TEST_WORKGUIDE}" "env-check";then
    ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/check_env.sh
    if [ $? -ne 0 ];then
        echo_erro "fail: ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/check_env.sh"
        exit 1
    fi
fi

${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/configure.sh
if [ $? -ne 0 ];then
    echo_erro "fail: ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/configure.sh"
    exit 1
fi

if math_bool "${TARGET_DEBUG_ON}";then
    if ! file_exist "${ISCSI_APP_LOG}";then
        ${SUDO} "touch ${ISCSI_APP_LOG}"
    fi

    if string_contain "${TEST_WORKGUIDE}" "app-log-clear";then
        ${SUDO} "echo > ${ISCSI_APP_LOG}"
    fi

    ${SUDO} "nohup ${ISCSI_APP_RUNTIME} &> ${ISCSI_APP_LOG} &"

    if file_exist "${ISCSI_APP_LOG}";then
        ${SUDO} "chmod 777 ${ISCSI_APP_LOG}"
    fi
else
    ${SUDO} "nohup ${ISCSI_APP_RUNTIME} &"
fi

if ! process_exist "${ISCSI_APP_NAME}";then
    echo_erro "${ISCSI_APP_NAME} launch failed."
    exit 1
else
    echo_info "${ISCSI_APP_NAME} launch success."
fi

iscsi_pids=($(process_name2pid "${ISCSI_APP_NAME}"))
for pid in "${iscsi_pids[@]}"
do
    sudo_it "echo 0x7b > /proc/${pid}/coredump_filter"
done

exit 0
