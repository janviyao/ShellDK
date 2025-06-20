#!/bin/bash
#set -o allexport
mkdir -p $(file_path_get "${TEST_SUIT_ENV}")
echo "#!/bin/bash" > ${TEST_SUIT_ENV}

WORK_ROOT_DIR=${GBL_USER_DIR}/test
TOOL_ROOT_DIR=${MY_VIM_DIR}/tools
TEST_ROOT_DIR=$(file_path_get)
TEST_LOG_DIR="/home/fastdisk/report_$(date '+%Y%m%d')/$(date '+%H%M%S')"

TEST_WORKGUIDE="env-check deploy fio-test env-clear app-log-clear fio-log-clear"
#TESTCASE_SUITE="fill,custom,full"
TESTCASE_SUITE="custom"
KERNEL_DEBUG_ON=false
KEEP_ENV_STATE=false
DUMP_SAVE_ON=true
APPLY_SYSCTRL=true

# TEST_TARGET=spdk
if [[ "${LOCAL_IP}" == "172.24.15.170" ]];then
    TEST_TARGET=istgt
    declare -xa SERVER_IP_ARRAY=(172.24.15.170)
    declare -xa CLIENT_IP_ARRAY=(172.24.15.171)
elif [[ "${LOCAL_IP}" == "100.69.248.137" ]];then
    TEST_TARGET=custom
    declare -xa SERVER_IP_ARRAY=(100.69.248.137)
    declare -xa CLIENT_IP_ARRAY=(100.69.248.139 11.158.227.241)
else
    TEST_TARGET=spdk
    declare -a ip_array=($(get_hosts_ip))
    if [ ${#ip_array[*]} -ge 1 ];then
        if [ ${#ip_array[*]} -ge 2 ];then
            declare -xa SERVER_IP_ARRAY=(${ip_array[0]})
            declare -xa CLIENT_IP_ARRAY=(${ip_array[1]})
        else
            declare -xa SERVER_IP_ARRAY=(${LOCAL_IP})
            declare -xa CLIENT_IP_ARRAY=(${ip_array[0]})
        fi
    else
        declare -xa SERVER_IP_ARRAY=(${LOCAL_IP})
        declare -xa CLIENT_IP_ARRAY=(${LOCAL_IP})
        echo_warn "/etc/hosts not config"
    fi
fi

echo "# [global configure]" >> ${TEST_SUIT_ENV}
kvconf_set "${TEST_SUIT_ENV}" "" "export PATH"     "$HOME/.local/bin:/sbin/:$PATH"
kvconf_set "${TEST_SUIT_ENV}" "" "CONTROL_IP"      "${LOCAL_IP}"
echo "" >> ${TEST_SUIT_ENV}

kvconf_set "${TEST_SUIT_ENV}" "" "declare -a SERVER_IP_ARRAY" "(${SERVER_IP_ARRAY[*]})"
kvconf_set "${TEST_SUIT_ENV}" "" "declare -a CLIENT_IP_ARRAY" "(${CLIENT_IP_ARRAY[*]})"
# kvconf_set "${TEST_SUIT_ENV}" "" "declare -A HOST_DISK_MAP"   "(['${LOCAL_IP}']='empty')"
echo "" >> ${TEST_SUIT_ENV}

kvconf_set "${TEST_SUIT_ENV}" "" "WORK_ROOT_DIR"   "${WORK_ROOT_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "" "TOOL_ROOT_DIR"   "${TOOL_ROOT_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "" "APPLY_SYSCTRL"   "${APPLY_SYSCTRL}"
kvconf_set "${TEST_SUIT_ENV}" "" "KERNEL_DEBUG_ON" "${KERNEL_DEBUG_ON}"
kvconf_set "${TEST_SUIT_ENV}" "" "DUMP_SAVE_ON"    "${DUMP_SAVE_ON}"

kvconf_set "${TEST_SUIT_ENV}" "" "KEEP_ENV_STATE"  "${KEEP_ENV_STATE}"
kvconf_set "${TEST_SUIT_ENV}" "" "TEST_TARGET"     "${TEST_TARGET}"
kvconf_set "${TEST_SUIT_ENV}" "" "TEST_WORKGUIDE"  "\"${TEST_WORKGUIDE}\""
kvconf_set "${TEST_SUIT_ENV}" "" "TESTCASE_SUITE"  "\"${TESTCASE_SUITE}\""

kvconf_set "${TEST_SUIT_ENV}" "" "TEST_ROOT_DIR"   "${TEST_ROOT_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "" "TEST_LOG_DIR"    "${TEST_LOG_DIR}"

echo "" >> ${TEST_SUIT_ENV}
echo "# [fio configure]" >> ${TEST_SUIT_ENV}
${TOOL_ROOT_DIR}/fio/setup.sh 

echo "" >> ${TEST_SUIT_ENV}
echo "# [iscsi configure]" >> ${TEST_SUIT_ENV}
${TOOL_ROOT_DIR}/iscsi/setup.sh 

echo "" >> ${TEST_SUIT_ENV}
echo "# [runtime configure]" >> ${TEST_SUIT_ENV}

# Push run env
for ipaddr in "${CLIENT_IP_ARRAY[@]}"
do
    if [[ ${LOCAL_IP} == ${ipaddr} ]];then
        continue
    fi
    ${TOOL_ROOT_DIR}/scplogin.sh "${TEST_SUIT_ENV}" "${ipaddr}:${TEST_SUIT_ENV}"
done

for ipaddr in "${SERVER_IP_ARRAY[@]}"
do
    if [[ ${LOCAL_IP} == ${ipaddr} ]];then
        continue
    fi
    ${TOOL_ROOT_DIR}/scplogin.sh "${TEST_SUIT_ENV}" "${ipaddr}:${TEST_SUIT_ENV}"
done
