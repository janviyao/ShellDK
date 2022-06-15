#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh

${SUDO} "mkdir -p ${ISCSI_LOG_DIR}; chmod -R 777 ${ISCSI_LOG_DIR}" 

LOCAL_CONF="${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/conf/istgt.conf"
can_access "${ISCSI_CONF_DIR}" || ${SUDO} "mkdir -p ${ISCSI_CONF_DIR}"
can_access "${LOCAL_CONF}" && ${SUDO} cp -f ${LOCAL_CONF} ${ISCSI_CONF_DIR}
${SUDO} chmod -R 777 ${ISCSI_CONF_DIR}

for ipaddr in ${ISCSI_TARGET_IP_ARRAY[*]}
do
    sed -i "s#Portal\s\+\(.*\)\s\+[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+:3260\+#Portal \1 ${ipaddr}:3260#g" ${ISCSI_CONF_DIR}/istgt.conf
    echo_info "update: Portal ${ipaddr}:3260"
done

for ipaddr in ${ISCSI_INITIATOR_IP_ARRAY[*]}
do
    match_ln=$(sed -n "\#Netmask\s\+[0-9]\+\.[0-9]\+\.[0-9]\+\.0/[0-9]\+#=" ${ISCSI_CONF_DIR}/istgt.conf | tail -n 1)
    if [ -n "${match_ln}" ];then
        netmask=$(string_regex "${ipaddr}" "^\d+\.\d+\.\d+")
        sed -i "${match_ln}a\  Netmask ${netmask}.0/24" ${ISCSI_CONF_DIR}/istgt.conf
        echo_info "   add: Netmask ${netmask}.0/24 @${match_ln}"
    fi
done

device_path=$(fname2path "${DEVICE_NAME}")
${SUDO} "mkdir -p ${device_path}; chmod -R 777 ${device_path}" 
${SUDO} fallocate -l ${DEVICE_SIZE} ${DEVICE_NAME}
sed -i "s#/dev/vdb#${DEVICE_NAME}#g" ${ISCSI_CONF_DIR}/istgt.conf

exit 0

