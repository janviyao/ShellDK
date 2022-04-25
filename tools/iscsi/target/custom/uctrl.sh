#!/bin/bash
source ${TEST_SUIT_ENV} 
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"

source ${ISCSI_ROOT_DIR}/target/${TEST_TARGET}/include/private.conf.sh

op_mode="$1"

LUN_MAX_NUM=64
for ini_ip in ${ISCSI_INITIATOR_IP_ARRAY[*]} 
do
    netmask=$(echo "${ini_ip}" | grep -P "\d+\.\d+\.\d+" -o)
    for index in $(seq 0 ${LUN_MAX_NUM})
    do
        map_value="${ISCSI_INFO_MAP[${ini_ip}-${index}]}"
        if [ -z "${map_value}" ];then
            break
        fi

        tgt_ip=$(echo "${map_value}" | awk '{ print $1 }')
        if ! array_has "${ISCSI_TARGET_IP_ARRAY[*]}" "${tgt_ip}";then
            break
        fi
        
        if [[ "${op_mode}" == "create_portal_group" ]];then
            pg_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 1)

            echo_info "create target group: ${tgt_ip}:3260"
            ${ISCSI_APP_UCTRL} iscsi_create_portal_group ${pg_id} ${tgt_ip}:3260
            if [ $? -ne 0 ];then
                echo_erro "create target group: ${tgt_ip}:3260 fail"
                exit 1
            fi
        elif [[ "${op_mode}" == "create_initiator_group" ]];then
            ig_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 2)

            echo_info "create initiator group: ${netmask}.0/24"
            ${ISCSI_APP_UCTRL} iscsi_create_initiator_group ${ig_id} ANY ${netmask}.0/24
            if [ $? -ne 0 ];then
                echo_erro "create initiator group: ${netmask}.0/24 fail"
                exit 1
            fi
        elif [[ "${op_mode}" == "create_target_node" ]];then
            tgt_name=$(echo "${map_value}" | awk '{ print $2 }')
            pg_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 1)
            ig_id=$(echo "${map_value}" | awk '{ print $3 }' | cut -d ":" -f 2)

            map_num=$(echo "${map_value}" | awk '{ print NF }')
            if [ ${map_num} -le 3 ];then
                echo_erro "config: { ${map_value} } error"
                exit 1
            fi

            arr_idx=0
            bdev_name_id_pairs=($(echo))
            for seq in $(seq 4 ${map_num})
            do
                bdev_lun_map=$(echo "${map_value}" | awk "{ print \$${seq} }")
                bdev_name_id_pairs[${arr_idx}]="${bdev_lun_map}"
                let arr_idx++
            done

            echo_info "create target node: ${ISCSI_NODE_BASE}:${targe_name} { ${bdev_name_id_pairs[*]} } { ${pg_id}:${ig_id} }"
            ${ISCSI_APP_UCTRL} iscsi_create_target_node ${ISCSI_NODE_BASE}:${tgt_name} ${tgt_name}_alias "${bdev_name_id_pairs[*]}" ${pg_id}:${ig_id} 256 -d
            if [ $? -ne 0 ];then
                echo_erro "create target: ${ISCSI_NODE_BASE}:${tgt_name} fail"
                exit 1
            fi

            if [[ ${BDEV_TYPE,,} == "cstor" ]];then
                echo_info "set target node vcns: ${ISCSI_NODE_BASE}:${tgt_name}"
                ${ISCSI_APP_UCTRL} iscsi_target_node_set_vcns ${ISCSI_NODE_BASE}:${tgt_name}
                if [ $? -ne 0 ];then
                    echo_erro "set vcns target: ${ISCSI_NODE_BASE}:${tgt_name} fail"
                    exit 1
                fi
            fi
        elif [[ "${op_mode}" == "create_bdev" ]];then
            map_num=$(echo "${map_value}" | awk '{ print NF }')
            if [ ${map_num} -le 3 ];then
                echo_erro "config: { ${map_value} } error"
                exit 1
            fi

            for seq in $(seq 4 ${map_num})
            do
                bdev_lun_map=$(echo "${map_value}" | awk "{ print \$${seq} }")
                bdev_name=$(echo "${bdev_lun_map}" | cut -d ":" -f 1)
                
                echo_info "create ${BDEV_TYPE,,} bdev: ${bdev_name}"
                if [[ ${BDEV_TYPE,,} == "malloc" ]];then
                    ${ISCSI_APP_UCTRL} bdev_malloc_create -b ${bdev_name} 10240 4096
                elif [[ ${BDEV_TYPE,,} == "null" ]];then
                    ${ISCSI_APP_UCTRL} bdev_null_create ${bdev_name} 10240 4096
                elif [[ ${BDEV_TYPE,,} == "cstor" ]];then
                    bdev_id=$(string_regex "${bdev_name}" "\d+")
                    ${ISCSI_APP_UCTRL} bdev_cstor_create -i ${bdev_id} --size 10GB --rsize 512
                fi

                if [ $? -ne 0 ];then
                    echo_erro "create ${BDEV_TYPE,,} bdev: ${bdev_name} fail"
                    exit 1
                fi
            done
        fi 
    done
done
