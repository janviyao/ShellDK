#!/bin/bash
#set -o allexport
mkdir -p $(fname2path "${TEST_SUIT_ENV}")
echo "#!/bin/bash" > ${TEST_SUIT_ENV}

TOOL_ROOT_DIR=$(current_filedir)/..
TEST_ROOT_DIR=$(current_filedir)

KEEP_ENV_STATE=no
APPLY_SYSCTRL=no
TEST_FILL_DATA=no

declare -xa SERVER_IP_LIST=(172.24.15.161)
declare -xa CLIENT_IP_LIST=(172.24.15.162 172.24.15.163)

echo "# [global configure]" >> ${TEST_SUIT_ENV}
config_add "${TEST_SUIT_ENV}" "KEEP_ENV_STATE" "${KEEP_ENV_STATE}"
config_add "${TEST_SUIT_ENV}" "APPLY_SYSCTRL"  "${APPLY_SYSCTRL}"
config_add "${TEST_SUIT_ENV}" "TEST_FILL_DATA" "${TEST_FILL_DATA}"

config_add "${TEST_SUIT_ENV}" "TEST_ROOT_DIR"  "${TEST_ROOT_DIR}"
config_add "${TEST_SUIT_ENV}" "TOOL_ROOT_DIR"  "${TOOL_ROOT_DIR}"
config_add "${TEST_SUIT_ENV}" "export PATH"    "$HOME/.local/bin:/sbin/:$PATH"

export_all
echo "" >> ${TEST_SUIT_ENV}
echo "# [fio configure]" >> ${TEST_SUIT_ENV}
${TOOL_ROOT_DIR}/fio/setup.sh 

echo "" >> ${TEST_SUIT_ENV}
echo "# [iscsi configure]" >> ${TEST_SUIT_ENV}
${TOOL_ROOT_DIR}/iscsi/setup.sh 

# Push run env
#$MY_VIM_DIR/tools/collect.sh "/tmp/vim.tar"
#for ipaddr in ${SERVER_IP_LIST[*]}
#do
#    $MY_VIM_DIR/tools/scplogin.sh "${TEST_SUIT_ENV}" "${ipaddr}:${TEST_SUIT_ENV}"
#    $MY_VIM_DIR/tools/scplogin.sh "/tmp/vim.tar" "${ipaddr}:${HOME_DIR}"
#
#    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "tar -xf ${HOME_DIR}/vim.tar"
#done
