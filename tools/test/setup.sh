#!/bin/bash
#set -o allexport
mkdir -p $(fname2path "${TEST_SUIT_ENV}")
echo "#!/bin/bash" > ${TEST_SUIT_ENV}

WORK_ROOT_DIR=/tmp/test
TOOL_ROOT_DIR=${MY_VIM_DIR}/tools
TEST_ROOT_DIR=$(current_filedir)

TEST_TARGET=custom
#TEST_TARGET=istgt
#TEST_TARGET=spdk

TEST_DUMP_SAVE=no
TEST_FILL_DATA=no
KEEP_ENV_STATE=no
APPLY_SYSCTRL=no

declare -xa SERVER_IP_ARRAY=(11.158.227.241)
declare -xa CLIENT_IP_ARRAY=(11.164.100.228)
#declare -xa SERVER_IP_ARRAY=(172.24.15.166)
#declare -xa CLIENT_IP_ARRAY=(172.24.15.167)

echo "# [global configure]" >> ${TEST_SUIT_ENV}
kvconf_add "${TEST_SUIT_ENV}" "CONTROL_IP" "${LOCAL_IP}"
echo "" >> ${TEST_SUIT_ENV}

kvconf_add "${TEST_SUIT_ENV}" "declare -a SERVER_IP_ARRAY" "(${SERVER_IP_ARRAY[*]})"
kvconf_add "${TEST_SUIT_ENV}" "declare -a CLIENT_IP_ARRAY" "(${CLIENT_IP_ARRAY[*]})"
kvconf_add "${TEST_SUIT_ENV}" "declare -A HOST_DISK_MAP" "(['${LOCAL_IP}']='empty')"
echo "" >> ${TEST_SUIT_ENV}

kvconf_add "${TEST_SUIT_ENV}" "TEST_DUMP_SAVE" "${TEST_DUMP_SAVE}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_TARGET"    "${TEST_TARGET}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_FILL_DATA" "${TEST_FILL_DATA}"
kvconf_add "${TEST_SUIT_ENV}" "KEEP_ENV_STATE" "${KEEP_ENV_STATE}"
kvconf_add "${TEST_SUIT_ENV}" "APPLY_SYSCTRL"  "${APPLY_SYSCTRL}"

kvconf_add "${TEST_SUIT_ENV}" "WORK_ROOT_DIR"  "${WORK_ROOT_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "TEST_ROOT_DIR"  "${TEST_ROOT_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "TOOL_ROOT_DIR"  "${TOOL_ROOT_DIR}"
kvconf_add "${TEST_SUIT_ENV}" "export PATH"    "$HOME/.local/bin:/sbin/:$PATH"

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
