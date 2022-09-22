#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh
if [ $? -ne 0 ];then
    echo_erro "source { ${TEST_TARGET}/include/private.conf.sh } fail"
    exit 1
fi

op_mode="$1"
echo_info "uctrl: ${op_mode}"

do_success=false

declare -a create_target_node_array
declare -a create_portal_group_array
declare -a create_initiator_group_array
declare -a create_bdev_array

for map_key in ${!ISCSI_INFO_MAP[*]}
do
    ini_ip=$(string_regex "${map_key}" "\d+\.\d+\.\d+\.\d+")
    if [ -z "${ini_ip}" ];then
        continue
    fi

    if ! array_has "${ISCSI_INITIATOR_IP_ARRAY[*]}" "${ini_ip}";then
        echo_erro "initiator(${ini_ip}) not configed in custom/private.conf"
        exit 1
    fi

    map_value="${ISCSI_INFO_MAP[${map_key}]}"
    if [ -z "${map_value}" ];then
        continue
    fi

    tgt_ip=$(echo "${map_value}" | awk '{ print $1 }')
    if ! array_has "${ISCSI_TARGET_IP_ARRAY[*]}" "${tgt_ip}";then
        echo_erro "iscsi map { ${tgt_ip} } not in { ${ISCSI_TARGET_IP_ARRAY[*]} }, please check { custom/private.conf }"
        exit 1
    fi

    if [[ "${tgt_ip}" != "${LOCAL_IP}" ]];then
        continue
    fi

    if [[ "${op_mode}" == "create_portal_group" ]];then
        pg_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 1)
        combine_str="${pg_id}${GBL_SPF1}${tgt_ip}:3260"
        if ! array_has "${create_portal_group_array[*]}" "${combine_str}";then
            arr_idx=${#create_portal_group_array[*]}
            create_portal_group_array[${arr_idx}]="${combine_str}"
        fi
    fi

    if [[ "${op_mode}" == "create_initiator_group" ]];then
        ig_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 2)
        netmask=$(echo "${ini_ip}" | grep -P "\d+\.\d+\.\d+" -o)

        combine_str="${ig_id}${GBL_SPF1}ANY${GBL_SPF1}${netmask}.0/24"
        if ! array_has "${create_initiator_group_array[*]}" "${combine_str}";then
            arr_idx=${#create_initiator_group_array[*]}
            create_initiator_group_array[${arr_idx}]="${combine_str}"
        fi
    fi

    if [[ "${op_mode}" == "create_bdev" ]];then
        map_num=$(echo "${map_value}" | awk '{ print NF }')
        if [ ${map_num} -le 3 ];then
            echo_erro "config: { ${map_value} } error"
            exit 1
        fi

        for seq in $(seq 4 ${map_num})
        do
            bdev_lun_map=$(echo "${map_value}" | awk "{ print \$${seq} }")
            bdev_name=$(echo "${bdev_lun_map}" | cut -d ":" -f 1)
            if ! array_has "${create_bdev_array[*]}" "${bdev_name}";then
                arr_idx=${#create_bdev_array[*]}
                create_bdev_array[${arr_idx}]="${bdev_name}"
            fi
        done
    fi

    if [[ "${op_mode}" == "create_target_node" ]];then
        map_num=$(echo "${map_value}" | awk '{ print NF }')
        if [ ${map_num} -le 3 ];then
            echo_erro "config: { ${map_value} } error"
            exit 1
        fi

        bdev_name_id_pairs=($(echo))
        for seq in $(seq 4 ${map_num})
        do
            bdev_lun_map=$(echo "${map_value}" | awk "{ print \$${seq} }")
            bdev_name=$(echo "${bdev_lun_map}" | cut -d ":" -f 1)

            arr_idx=${#bdev_name_id_pairs[*]}
            bdev_name_id_pairs[${arr_idx}]="${bdev_lun_map}"
        done

        tgt_name=$(echo "${map_value}" | awk '{ print $2 }')
        pg_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 1)
        ig_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 2)

        combine_str="${ISCSI_NODE_BASE}:${tgt_name}${GBL_SPF1}${tgt_name}_alias${GBL_SPF1}\"${bdev_name_id_pairs[*]}\"${GBL_SPF1}${pg_id}:${ig_id}${GBL_SPF1}256${GBL_SPF1}-d"
        combine_str=$(replace_regex "${combine_str}" "\s*" "${GBL_SPF2}")
        if ! array_has "${create_target_node_array[*]}" "${combine_str}";then
            arr_idx=${#create_target_node_array[*]}
            create_target_node_array[${arr_idx}]="${combine_str}"
        fi
    fi
done

if [[ "${op_mode}" == "create_portal_group" ]];then
    for item in ${create_portal_group_array[*]} 
    do
        item=$(replace_str "${item}" "${GBL_SPF1}" " ")
        echo_info "${UCTRL_CMD_MAP[${op_mode}]} ${item}"
        eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}]} ${item}"
        if [ $? -ne 0 ];then
            echo_erro "create target group: ${tgt_ip}:3260 fail"
            exit 1
        fi
        do_success=true       
    done
fi

if [[ "${op_mode}" == "create_initiator_group" ]];then
    for item in ${create_initiator_group_array[*]} 
    do
        item=$(replace_str "${item}" "${GBL_SPF1}" " ")

        echo_info "${UCTRL_CMD_MAP[${op_mode}]} ${item}"
        eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}]} ${item}"
        if [ $? -ne 0 ];then
            echo_erro "create initiator group: ${netmask}.0/24 fail"
            exit 1
        fi
        do_success=true       
    done
fi

if [[ "${op_mode}" == "create_bdev" ]];then
    for item in ${create_bdev_array[*]} 
    do
        name_type=$(string_regex "${item,,}" "[a-z]+")
        if [[ ${name_type} == "malloc" ]];then
            echo_info "${UCTRL_CMD_MAP[${op_mode}_${name_type}]} -b ${item} ${BDEV_SIZE_MB} 4096"
            eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}_${name_type}]} -b ${item} ${BDEV_SIZE_MB} 4096"
        elif [[ ${name_type} == "null" ]];then
            echo_info "${UCTRL_CMD_MAP[${op_mode}_${name_type}]} ${item} ${BDEV_SIZE_MB} 4096"
            eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}_${name_type}]} ${item} ${BDEV_SIZE_MB} 4096"
        else
            echo_erro "bdev_type { ${name_type} } don't be identified"
            exit 1
        fi

        if [ $? -ne 0 ];then
            echo_erro "create ${name_type} bdev: ${item} fail"
            exit 1
        fi
        do_success=true
    done
fi

if [[ "${op_mode}" == "create_target_node" ]];then
    for item in ${create_target_node_array[*]} 
    do
        target_node=$(string_split "${item}" "${GBL_SPF1}" 1)
        item=$(replace_str "${item}" "${GBL_SPF1}" " ")
        item=$(replace_str "${item}" "${GBL_SPF2}" " ")

        echo_info "${UCTRL_CMD_MAP[${op_mode}]} ${item}"
        eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}]} ${item}"
        if [ $? -ne 0 ];then
            echo_erro "create target: ${item} fail"
            exit 1
        fi
        do_success=true
    done
fi

if bool_v "${do_success}";then
    exit 0
else
    echo_erro "fail. please check { "${op_mode}" } or { custom/private.conf }"
    exit 1
fi
