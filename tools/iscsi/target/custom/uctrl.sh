#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh

op_mode="$1"
echo_info "uctrl: ${op_mode}"

do_success=false
LUN_MAX_NUM=64

create_target_node_array=($(echo))
create_portal_group_array=($(echo))
create_initiator_group_array=($(echo))
create_bdev_array=($(echo))

for ini_ip in ${ISCSI_INITIATOR_IP_ARRAY[*]} 
do
    for index in $(seq 0 ${LUN_MAX_NUM})
    do
        map_value="${ISCSI_INFO_MAP[${ini_ip}-${index}]}"
        if [ -z "${map_value}" ];then
            if [ ${index} -eq 0 ];then
                echo_erro "initiator(${ini_ip}) not configed in custom/private.conf"
                exit 1
            fi
            break
        fi

        tgt_ip=$(echo "${map_value}" | awk '{ print $1 }')
        if ! array_has "${ISCSI_TARGET_IP_ARRAY[*]}" "${tgt_ip}";then
            echo_erro "target(${tgt_ip}) not configed in custom/private.conf"
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
        if [[ ${BDEV_TYPE,,} == "malloc" ]];then
            echo_info "${UCTRL_CMD_MAP[${op_mode}_${BDEV_TYPE,,}]} -b ${item} ${BDEV_SIZE_MB} 4096"
            eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}_${BDEV_TYPE,,}]} -b ${item} ${BDEV_SIZE_MB} 4096"
        elif [[ ${BDEV_TYPE,,} == "null" ]];then
            echo_info "${UCTRL_CMD_MAP[${op_mode}_${BDEV_TYPE,,}]} ${item} ${BDEV_SIZE_MB} 4096"
            eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}_${BDEV_TYPE,,}]} ${item} ${BDEV_SIZE_MB} 4096"
        elif [[ ${BDEV_TYPE,,} == "cstor" ]];then
            bdev_id=$(string_regex "${item}" "\d+")
            echo_info "${UCTRL_CMD_MAP[${op_mode}_${BDEV_TYPE,,}]} -i ${bdev_id} --size ${BDEV_SIZE_MB}MB --rsize 512"
            eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}_${BDEV_TYPE,,}]} -i ${bdev_id} --size ${BDEV_SIZE_MB}MB --rsize 512"
        else
            echo_erro "bdev_type { ${BDEV_TYPE,,} } don't be identified"
            exit 1
        fi

        if [ $? -ne 0 ];then
            echo_erro "create ${BDEV_TYPE,,} bdev: ${item} fail"
            exit 1
        fi
        do_success=true
    done
fi

if [[ "${op_mode}" == "create_target_node" ]];then
    for item in ${create_target_node_array[*]} 
    do
        target_node=$(echo "${item}" | awk -F${GBL_SPF1} '{ print $1 }')
        item=$(replace_str "${item}" "${GBL_SPF1}" " ")
        item=$(replace_str "${item}" "${GBL_SPF2}" " ")

        echo_info "${UCTRL_CMD_MAP[${op_mode}]} ${item}"
        eval "${ISCSI_APP_UCTRL} ${UCTRL_CMD_MAP[${op_mode}]} ${item}"
        if [ $? -ne 0 ];then
            echo_erro "create target: ${item} fail"
            exit 1
        fi

        if [[ ${BDEV_TYPE,,} == "cstor" ]];then
            #echo_info "iscsi_target_node_set_vcns ${target_node} -r 3 -c 2 -b 512 --lr-size 4096 --unit-vendor \"CloudByte\" --unit-product \"iSCSI\" --unit-revision \"0001\" --replicas \"6361:6361 6362:6362 6363:6363\""
            echo_info "iscsi_target_node_set_vcns ${target_node}"
            eval "${ISCSI_APP_UCTRL} iscsi_target_node_set_vcns ${target_node}"
            if [ $? -ne 0 ];then
                echo_erro "set vcns target: ${ISCSI_NODE_BASE}:${tgt_name} fail"
                exit 1
            fi
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
