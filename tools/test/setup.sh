#!/bin/bash
#set -o allexport
mkdir -p $(fname2path "${TEST_SUIT_ENV}")
echo "#!/bin/bash" > ${TEST_SUIT_ENV}

WORK_ROOT_DIR=${GBL_BASE_DIR}/test
TOOL_ROOT_DIR=${MY_VIM_DIR}/tools
TEST_ROOT_DIR=$(current_filedir)
TEST_LOG_DIR="/home/fastdisk/$(date '+%Y%m%d-%H%M%S')"

KERNEL_DEBUG_ON=false
TEST_FILL_DATA=false
KEEP_ENV_STATE=false
APPLY_SYSCTRL=false
DUMP_SAVE_ON=false

#TEST_TARGET=spdk
if [[ "${LOCAL_IP}" == "172.24.15.166" ]];then
    TEST_TARGET=istgt
    declare -xa SERVER_IP_ARRAY=(172.24.15.166)
    declare -xa CLIENT_IP_ARRAY=(172.24.15.167)
elif [[ "${LOCAL_IP}" == "11.158.227.241" ]];then
    TEST_TARGET=custom
    declare -xa SERVER_IP_ARRAY=(11.158.227.241)
    declare -xa CLIENT_IP_ARRAY=(11.167.232.47)
fi

echo "# [global configure]" >> ${TEST_SUIT_ENV}
kvconf_add "${TEST_SUIT_ENV}" "export PATH"     "$HOME/.local/bin:/sbin/:$PATH"
kvconf_add "${TEST_SUIT_ENV}" "CONTROL_IP"      "${LOCAL_IP}"
echo "" >> ${TEST_SUIT_ENV}

kvconf_add "${TEST_SUIT_ENV}" "declare -a SERVER_IP_ARRAY" "(${SERVER_IP_ARRAY[*]})"
kvconf_add "${TEST_SUIT_ENV}" "declare -a CLIENT_IP_ARRAY" "(${CLIENT_IP_ARRAY[*]})"
kvconf_add "${TEST_SUIT_ENV}" "declare -A HOST_DISK_MAP"   "(['${LOCAL_IP}']='empty')"
echo "" >> ${TEST_SUIT_ENV}

kvconf_add "${TEST_SUIT_ENV}" "WORK_ROOT_DIR"   "${WORK_ROOT_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "TOOL_ROOT_DIR"   "${TOOL_ROOT_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "APPLY_SYSCTRL"   "${APPLY_SYSCTRL}"
kvconf_add "${TEST_SUIT_ENV}" "KERNEL_DEBUG_ON" "${KERNEL_DEBUG_ON}"
kvconf_add "${TEST_SUIT_ENV}" "DUMP_SAVE_ON"    "${DUMP_SAVE_ON}"

kvconf_add "${TEST_SUIT_ENV}" "KEEP_ENV_STATE"  "${KEEP_ENV_STATE}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_TARGET"     "${TEST_TARGET}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_FILL_DATA"  "${TEST_FILL_DATA}"

kvconf_add "${TEST_SUIT_ENV}" "TEST_ROOT_DIR"   "${TEST_ROOT_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_LOG_DIR"    "${TEST_LOG_DIR}"

echo "" >> ${TEST_SUIT_ENV}
echo "# [fio configure]" >> ${TEST_SUIT_ENV}
${TOOL_ROOT_DIR}/fio/setup.sh 

echo "" >> ${TEST_SUIT_ENV}
echo "# [iscsi configure]" >> ${TEST_SUIT_ENV}
${TOOL_ROOT_DIR}/iscsi/setup.sh 

echo "" >> ${TEST_SUIT_ENV}
echo "# [runtime configure]" >> ${TEST_SUIT_ENV}

# Push run env
for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    if [[ ${LOCAL_IP} == ${ipaddr} ]];then
        continue
    fi
    ${TOOL_ROOT_DIR}/scplogin.sh "${TEST_SUIT_ENV}" "${ipaddr}:${TEST_SUIT_ENV}"
done

for ipaddr in ${SERVER_IP_ARRAY[*]}
do
    if [[ ${LOCAL_IP} == ${ipaddr} ]];then
        continue
    fi
    ${TOOL_ROOT_DIR}/scplogin.sh "${TEST_SUIT_ENV}" "${ipaddr}:${TEST_SUIT_ENV}"
done
