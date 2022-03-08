#!/bin/sh
source /tmp/fio.env

echo_debug "@@@@@@: $(echo `basename $0`) @${APP_WORK_DIR} @${LOCAL_IP}"

IS_KEEP=$(bool_v "${KEEP_ENV_STATE}";echo $?)
if [ ${IS_KEEP} -ne 1 ];then
    echo_info "clean devs: ${LOCAL_IP}"
else
    echo_info "donot clean: ${LOCAL_IP}"
    exit 0
fi

sh stop_p.sh kill "fio --server"
sleep 2
if [ -b /dev/dm-0 ];then
    echo_info "remove old-mpath device"
    multipath -F
fi

get_tgt_ips=`iscsiadm -m node | grep -P "\d+\.\d+\.\d+\.\d+" -o | sort | uniq`
for ipaddr in ${get_tgt_ips}
do
    have_session=`echo "${ISCSI_TARGET_IP_ARRAY}" | grep "${ipaddr}" | wc -l`
    if [ ${have_session} -eq 0 ];then
        echo_info "no sessions from ${ipaddr} not in { ${ISCSI_TARGET_IP_ARRAY} }"
        continue
    fi
    
    sh log.sh iscsiadm -m node -p ${ipaddr} --logout
    sh log.sh iscsiadm -m node -p ${ipaddr} -o delete
    
    echo_info "clean: sessions=${have_session} from ${ipaddr}"
done
