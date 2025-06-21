#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(file_fname_get $0) @${LOCAL_IP}"

source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh
if [ $? -ne 0 ];then
    echo_erro "source { ${TEST_TARGET}/include/private.conf.sh } fail"
    exit 1
fi

op_mode="$1"
echo_info "uctrl: ${op_mode}"

do_success=false

declare -A target_node_bl_map
declare -A target_node_pi_map

declare -a create_target_node_array
declare -a create_portal_group_array
declare -a create_initiator_group_array
declare -a create_bdev_array

for map_key in "${!ISCSI_INFO_MAP[@]}" 
do
    ini_ip=$(string_gensub "${map_key}" "\d+\.\d+\.\d+\.\d+")
    if [ -z "${ini_ip}" ];then
        continue
    fi

    if ! array_have ISCSI_INITIATOR_IP_ARRAY "${ini_ip}";then
        echo_erro "initiator(${ini_ip}) not configed in custom/private.conf"
        exit 1
    fi

    map_value="${ISCSI_INFO_MAP[${map_key}]}"
    if [ -z "${map_value}" ];then
        continue
    fi

    tgt_ip=$(echo "${map_value}" | awk '{ print $1 }')
    if ! array_have ISCSI_TARGET_IP_ARRAY "${tgt_ip}";then
        echo_erro "iscsi map { ${tgt_ip} } not in { ${ISCSI_TARGET_IP_ARRAY[*]} }, please check { custom/private.conf }"
        exit 1
    fi

    if [[ "${tgt_ip}" != "${LOCAL_IP}" ]];then
        continue
    fi

    if [[ "${op_mode}" == "create_portal_group" ]];then
        pg_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 1)
        combine_str="${pg_id}${GBL_SPF1}${tgt_ip}:3260"
        if ! array_have create_portal_group_array "${combine_str}";then
            arr_idx=${#create_portal_group_array[*]}
            create_portal_group_array[${arr_idx}]="${combine_str}"
        fi
    fi

    if [[ "${op_mode}" == "create_initiator_group" ]];then
        ig_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 2)
        netmask=$(echo "${ini_ip}" | grep -P "\d+\.\d+\.\d+" -o)

        combine_str="${ig_id}${GBL_SPF1}ANY${GBL_SPF1}${netmask}.0/24"
        if ! array_have create_initiator_group_array "${combine_str}";then
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
            if ! array_have create_bdev_array "${bdev_name}";then
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

        declare -a bdev_lun_pair_array
        for seq in $(seq 4 ${map_num})
        do
            bdev_lun_map=$(echo "${map_value}" | awk "{ print \$${seq} }")
            bdev_name=$(echo "${bdev_lun_map}" | cut -d ":" -f 1)

            arr_idx=${#bdev_lun_pair_array[*]}
            bdev_lun_pair_array[${arr_idx}]="${bdev_lun_map}"
        done

        tgt_name=$(echo "${map_value}" | awk '{ print $2 }')
        pg_ig_pair=$(echo "${map_value}" | awk '{ print $3 }')
        if ! array_have create_target_node_array "${tgt_name}";then
            arr_idx=${#create_target_node_array[*]}
            create_target_node_array[${arr_idx}]="${tgt_name}"
        fi

        tmp_list=(${target_node_pi_map[${tgt_name}]})
        if ! array_have tmp_list "${pg_ig_pair}";then
            if [ -n "${target_node_pi_map[${tgt_name}]}" ];then
                target_node_pi_map[${tgt_name}]="${target_node_pi_map[${tgt_name}]} ${pg_ig_pair}"
            else
                target_node_pi_map[${tgt_name}]="${pg_ig_pair}"
            fi
        fi

        for bl_item in "${bdev_lun_pair_array[@]}" 
        do
            tmp_list=(${target_node_bl_map[${tgt_name}]})
            if ! array_have tmp_list "${bl_item}";then
                if [ -n "${target_node_bl_map[${tgt_name}]}" ];then
                    target_node_bl_map[${tgt_name}]="${target_node_bl_map[${tgt_name}]} ${bl_item}"
                else
                    target_node_bl_map[${tgt_name}]="${bl_item}"
                fi
            fi
        done
    fi
done

if [[ "${op_mode}" == "create_portal_group" ]];then
    for item in "${create_portal_group_array[@]}"
    do
        item=$(string_replace "${item}" "${GBL_SPF1}" " ")
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
    for item in "${create_initiator_group_array[@]}"
    do
        item=$(string_replace "${item}" "${GBL_SPF1}" " ")

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
    for item in "${create_bdev_array[@]}"
    do
        name_type=$(string_gensub "${item,,}" "[a-z]+")
        if [[ ${name_type} == "malloc" ]];then
            echo_info "${UCTRL_CMD_MAP[${op_mode}_${name_type}]} -b ${item} ${BDEV_SIZE_MB} 4096"
            eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}_${name_type}]} -b ${item} ${BDEV_SIZE_MB} 4096"
        elif [[ ${name_type} == "null" ]];then
            echo_info "${UCTRL_CMD_MAP[${op_mode}_${name_type}]} ${item} ${BDEV_SIZE_MB} 4096"
            eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}_${name_type}]} ${item} ${BDEV_SIZE_MB} 4096"
        elif [[ ${name_type} == "disk" ]];then
            bdev_id=$(string_gensub "${item}" "\d+")
            echo_info "${UCTRL_CMD_MAP[${op_mode}_${name_type}]} -i ${bdev_id} --size ${BDEV_SIZE_MB}MB --rsize 512"
            eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}_${name_type}]} -i ${bdev_id} --size ${BDEV_SIZE_MB}MB --rsize 512"
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
    for tgt_name in "${create_target_node_array[@]}"
    do
        bdev_lun_pairs="${target_node_bl_map[${tgt_name}]}"
        pg_ig_pairs="${target_node_pi_map[${tgt_name}]}"

        echo_info "${UCTRL_CMD_MAP[${op_mode}]} ${ISCSI_NODE_BASE}:${tgt_name} ${tgt_name}_alias '${bdev_lun_pairs}' '${pg_ig_pairs}' 256 -d"
        eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}]} ${ISCSI_NODE_BASE}:${tgt_name} ${tgt_name}_alias '${bdev_lun_pairs}' '${pg_ig_pairs}' 256 -d"
        if [ $? -ne 0 ];then
            echo_erro "create target: ${ISCSI_NODE_BASE}:${tgt_name} fail"
            exit 1
        fi

        if [[ ${BDEV_TYPE,,} == "cstor" ]];then
            #echo_info "iscsi_target_node_set_vcns ${ISCSI_NODE_BASE}:${tgt_name} -r 3 -c 2 -b 512 --lr-size 4096 --unit-vendor \"CloudByte\" --unit-product \"iSCSI\" --unit-revision \"0001\" --replicas \"6361:6361 6362:6362 6363:6363\""
            echo_info "iscsi_target_node_set_vcns ${ISCSI_NODE_BASE}:${tgt_name}"
            eval "${ISCSI_APP_UCTRL} iscsi_target_node_set_vcns ${ISCSI_NODE_BASE}:${tgt_name}"
            if [ $? -ne 0 ];then
                echo_erro "set vcns target: ${ISCSI_NODE_BASE}:${tgt_name} fail"
                exit 1
            fi
        fi
        do_success=true
    done
fi

if math_bool "${do_success}";then
    exit 0
else
    echo_erro "fail. please check { "${op_mode}" } or { custom/private.conf }"
    exit 1
fi
