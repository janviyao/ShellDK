#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

LOCAL_CONF="${ISCSI_ROOT_DIR}/${TEST_TARGET}/conf/istgt.conf"
APP_CONF_DIR="/usr/local/etc/istgt"
can_access "${LOCAL_CONF}" && ${SUDO} cp -f ${LOCAL_CONF} ${APP_CONF_DIR}

sed -i "s/${keystr}=.\+/${keystr}=${valstr}/g" ${APP_CONF_DIR}/istgt.conf

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
do
    netmask=$(string_regex "${ipaddr}" "^\d+\.\d+\.\d+")
    sed -i "s#Netmask\s\+[0-9]\+\.[0-9]\+\.[0-9]\+\.0/[0-9]\+#Netmask ${netmask}.0/24#g" ${APP_CONF_DIR}/istgt.conf
done

exit 0

