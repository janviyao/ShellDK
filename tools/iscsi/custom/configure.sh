#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

# configure core-dump path
${SUDO} "echo '/core-%e-%p-%t' > /proc/sys/kernel/core_pattern"

if bool_v "${APPLY_SYSCTRL}";then
    can_access "${TEST_ROOT_DIR}/conf/sysctl.conf" && ${SUDO} cp -f ${TEST_ROOT_DIR}/conf/sysctl.conf /etc/
    ${SUDO} ${TOOL_ROOT_DIR}/log.sh sysctl -p
fi

if process_exist "iscsid";then
    ${SUDO} systemctl stop iscsid
    ${SUDO} systemctl stop iscsid.socket
    ${SUDO} systemctl stop iscsiuio
fi

LOCAL_CONF="${ISCSI_ROOT_DIR}/${TEST_TARGET}/conf/iscsi.conf.in"
can_access "${APP_CONF_DIR}" || ${SUDO} "mkdir -p ${APP_CONF_DIR}"
can_access "${LOCAL_CONF}" && ${SUDO} cp -f ${LOCAL_CONF} ${APP_CONF_DIR}

sed -i "s/${keystr}=.\+/${keystr}=${valstr}/g" ${APP_CONF_DIR}/iscsi.conf.in

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
do
    sed -i "s#Portal\s\+\(.*\)\s\+[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+:3260\+#Portal \1 ${ipaddr}:3260#g" ${APP_CONF_DIR}/iscsi.conf.in
done

for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    match_ln=$(sed -n "\#Netmask\s\+[0-9]\+\.[0-9]\+\.[0-9]\+\.0/[0-9]\+#=" ${APP_CONF_DIR}/iscsi.conf.in | tail -n 1)
    if [ -z "${match_ln}" ];then
        netmask=$(string_regex "${ipaddr}" "^\d+\.\d+\.\d+")
        sed -i "${match_ln}a\  Netmask ${netmask}.0/24" ${APP_CONF_DIR}/iscsi.conf.in
    fi
done

exit 0
