#!/bin/bash
#set -o allexport
mkdir -p $(fname2path "${TEST_SUIT_ENV}")
echo "#!/bin/bash" > ${TEST_SUIT_ENV}

WORK_ROOT_DIR=/tmp/test
TOOL_ROOT_DIR=${MY_VIM_DIR}/tools
TEST_ROOT_DIR=$(current_filedir)

#TEST_TARGET=istgt
TEST_TARGET=spdk

TEST_FILL_DATA=no
KEEP_ENV_STATE=no
APPLY_SYSCTRL=no

declare -xa SERVER_IP_ARRAY=(172.24.15.167)
declare -xa CLIENT_IP_ARRAY=(172.24.15.168)
#declare -xa SERVER_IP_ARRAY=(11.160.41.96)
#declare -xa CLIENT_IP_ARRAY=(11.160.41.224)

echo "# [global configure]" >> ${TEST_SUIT_ENV}
config_add "${TEST_SUIT_ENV}" "CONTROL_IP" "${LOCAL_IP}"
echo "" >> ${TEST_SUIT_ENV}

config_add "${TEST_SUIT_ENV}" "declare -a SERVER_IP_ARRAY" "(${SERVER_IP_ARRAY[*]})"
config_add "${TEST_SUIT_ENV}" "declare -a CLIENT_IP_ARRAY" "(${CLIENT_IP_ARRAY[*]})"
config_add "${TEST_SUIT_ENV}" "declare -A HOST_DISK_MAP" "(['${LOCAL_IP}']='empty')"
echo "" >> ${TEST_SUIT_ENV}

config_add "${TEST_SUIT_ENV}" "TEST_TARGET"    "${TEST_TARGET}"
config_add "${TEST_SUIT_ENV}" "TEST_FILL_DATA" "${TEST_FILL_DATA}"
config_add "${TEST_SUIT_ENV}" "KEEP_ENV_STATE" "${KEEP_ENV_STATE}"
config_add "${TEST_SUIT_ENV}" "APPLY_SYSCTRL"  "${APPLY_SYSCTRL}"

config_add "${TEST_SUIT_ENV}" "WORK_ROOT_DIR"  "${WORK_ROOT_DIR}"
config_add "${TEST_SUIT_ENV}" "TEST_ROOT_DIR"  "${TEST_ROOT_DIR}"
config_add "${TEST_SUIT_ENV}" "TOOL_ROOT_DIR"  "${TOOL_ROOT_DIR}"
config_add "${TEST_SUIT_ENV}" "export PATH"    "$HOME/.local/bin:/sbin/:$PATH"

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
