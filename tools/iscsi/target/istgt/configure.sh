#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh
if [ $? -ne 0 ];then
    echo_erro "source { ${TEST_TARGET}/include/private.conf.sh } fail"
    exit 1
fi

${SUDO} "mkdir -p ${ISCSI_LOG_DIR}; chmod -R 777 ${ISCSI_LOG_DIR}" 

LOCAL_CONF="${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/conf/istgt.conf"
can_access "${ISCSI_CONF_DIR}" || ${SUDO} "mkdir -p ${ISCSI_CONF_DIR}"
can_access "${LOCAL_CONF}" && ${SUDO} cp -f ${LOCAL_CONF} ${ISCSI_CONF_DIR}
${SUDO} chmod -R 777 ${ISCSI_CONF_DIR}

for map_key in ${!ISCSI_INFO_MAP[*]}
do
    ini_ip=$(string_regex "${map_key}" "\d+\.\d+\.\d+\.\d+")
    if [ -z "${ini_ip}" ];then
        continue
    fi

    if ! array_has "${ISCSI_INITIATOR_IP_ARRAY[*]}" "${ini_ip}";then
        echo_erro "target(${tgt_ip}) not configed in custom/private.conf"
        exit 1
    fi

    map_value="${ISCSI_INFO_MAP[${map_key}]}"
    if [ -z "${map_value}" ];then
        continue
    fi

    tgt_ip=$(echo "${map_value}" | awk '{ print $1 }')
    if ! array_has "${ISCSI_TARGET_IP_ARRAY[*]}" "${tgt_ip}";then
        echo_erro "target(${tgt_ip}) not configed in custom/private.conf"
        exit 1
    fi

    if [[ "${tgt_ip}" != "${LOCAL_IP}" ]];then
        continue
    fi

    pg_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 1)
    section_del "${ISCSI_CONF_DIR}/istgt.conf" "PortalGroup${pg_id}"
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "PortalGroup${pg_id}" "Comment" "\"SINGLE PORT TEST\""
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "PortalGroup${pg_id}" "Portal DA1" "${tgt_ip}:3260"

    ig_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 2)
    section_del "${ISCSI_CONF_DIR}/istgt.conf" "InitiatorGroup${ig_id}"
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "InitiatorGroup${ig_id}" "Comment" "\"Initiator Group${ig_id}\""
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "InitiatorGroup${ig_id}" "InitiatorName" "\"ALL\""
    netmask=$(echo "${ini_ip}" | grep -P "\d+\.\d+\.\d+" -o)
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "InitiatorGroup${ig_id}" "Netmask" "${netmask}.0/24"

    tgt_name=$(echo "${map_value}" | awk '{ print $2 }')
    tgt_id=$(string_regex "${tgt_name}" "\d+")
    section_del "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}"
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "Comment" "\"Hard Disk Sample\""
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "TargetName" "${tgt_name}"
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "TargetAlias" "\"Data ${tgt_name}\""
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "Mapping" "PortalGroup${pg_id} InitiatorGroup${ig_id}"
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "AuthMethod" "Auto"
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "AuthGroup" "AuthGroup1"
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "UseDigest" "Auto"
    section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "UnitType" "Disk"

    map_num=$(echo "${map_value}" | awk '{ print NF }')
    if [ ${map_num} -le 3 ];then
        echo_erro "config: { ${map_value} } error"
        exit 1
    fi

    for seq in $(seq 4 ${map_num})
    do
        file_lun_map=$(echo "${map_value}" | awk "{ print \$${seq} }")
        file_name=$(echo "${file_lun_map}" | awk -F: '{ print $1 }')
        lun_id=$(echo "${file_lun_map}" | awk -F: '{ print $2 }')

        file_path=$(fname2path "${file_name}")
        ${SUDO} "mkdir -p ${file_path}; chmod -R 777 ${file_path}" 
        ${SUDO} fallocate -l ${DEVICE_SIZE} ${file_name}

        section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "LUN${lun_id} Storage" "${file_name} Auto"
        section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "LUN${lun_id} Option ReadCache" "Disable"
        section_set "${ISCSI_CONF_DIR}/istgt.conf" "LogicalUnit${tgt_id}" "LUN${lun_id} Option WriteCache" "Disable"
    done
done

exit 0
