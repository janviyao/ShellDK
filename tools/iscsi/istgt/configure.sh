#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

LOCAL_CONF="${ISCSI_ROOT_DIR}/${TEST_TARGET}/conf/istgt.conf"
can_access "${APP_CONF_DIR}" || ${SUDO} "mkdir -p ${APP_CONF_DIR}"
can_access "${LOCAL_CONF}" && ${SUDO} cp -f ${LOCAL_CONF} ${APP_CONF_DIR}

sed -i "s/${keystr}=.\+/${keystr}=${valstr}/g" ${APP_CONF_DIR}/istgt.conf

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
do
    sed -i "s#Portal\s\+\(.*\)\s\+[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+:3260\+#Portal \1 ${ipaddr}:3260#g" ${APP_CONF_DIR}/istgt.conf
done

for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    match_ln=$(sed -n "\#Netmask\s\+[0-9]\+\.[0-9]\+\.[0-9]\+\.0/[0-9]\+#=" ${APP_CONF_DIR}/istgt.conf | tail -n 1)
    if [ -z "${match_ln}" ];then
        netmask=$(string_regex "${ipaddr}" "^\d+\.\d+\.\d+")
        sed -i "${match_ln}a\  Netmask ${netmask}.0/24" ${APP_CONF_DIR}/istgt.conf
    fi
done

exit 0
