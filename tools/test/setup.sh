#!/bin/bash
#set -o allexport
mkdir -p $(fname2path "${TEST_SUIT_ENV}")
echo "#!/bin/bash" > ${TEST_SUIT_ENV}

WORK_ROOT_DIR=/tmp/test
TOOL_ROOT_DIR=$(current_filedir)/..
TEST_ROOT_DIR=$(current_filedir)

KEEP_ENV_STATE=no
APPLY_SYSCTRL=no
TEST_FILL_DATA=no

declare -xa SERVER_IP_ARRAY=(172.24.15.161)
declare -xa CLIENT_IP_ARRAY=(172.24.15.162 172.24.15.163)

echo "# [global configure]" >> ${TEST_SUIT_ENV}
config_add "${TEST_SUIT_ENV}" "CONTROL_IP" "${LOCAL_IP}"
config_add "${TEST_SUIT_ENV}" "declare -a SERVER_IP_ARRAY" "(${SERVER_IP_ARRAY[*]})"
config_add "${TEST_SUIT_ENV}" "declare -a CLIENT_IP_ARRAY" "(${CLIENT_IP_ARRAY[*]})"
config_add "${TEST_SUIT_ENV}" "declare -A HOST_DISK_MAP" "(['${LOCAL_IP}']='empty')"
echo "" >> ${TEST_SUIT_ENV}

config_add "${TEST_SUIT_ENV}" "KEEP_ENV_STATE" "${KEEP_ENV_STATE}"
config_add "${TEST_SUIT_ENV}" "APPLY_SYSCTRL"  "${APPLY_SYSCTRL}"
config_add "${TEST_SUIT_ENV}" "TEST_FILL_DATA" "${TEST_FILL_DATA}"

config_add "${TEST_SUIT_ENV}" "WORK_ROOT_DIR"  "${WORK_ROOT_DIR}"
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
$MY_VIM_DIR/tools/collect.sh "/tmp/vim.tar"
for ipaddr in ${SERVER_IP_ARRAY[*]}
do
    if [[ ${LOCAL_IP} == ${ipaddr} ]];then
        continue
    fi

    $MY_VIM_DIR/tools/scplogin.sh "${TEST_SUIT_ENV}" "${ipaddr}:${TEST_SUIT_ENV}"
    $MY_VIM_DIR/tools/scplogin.sh "/tmp/vim.tar" "${ipaddr}:${HOME_DIR}"

    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "tar -xf ${HOME_DIR}/vim.tar"
    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "${HOME_DIR}/.git.vim/install.sh -o env"
done

# Push run env
for ipaddr in ${CLIENT_IP_ARRAY[*]}
do
    if [[ ${LOCAL_IP} == ${ipaddr} ]];then
        continue
    fi

    $MY_VIM_DIR/tools/scplogin.sh "${TEST_SUIT_ENV}" "${ipaddr}:${TEST_SUIT_ENV}"
    $MY_VIM_DIR/tools/scplogin.sh "/tmp/vim.tar" "${ipaddr}:${HOME_DIR}"

    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "tar -xf ${HOME_DIR}/vim.tar"
    $MY_VIM_DIR/tools/sshlogin.sh "${ipaddr}" "${HOME_DIR}/.git.vim/install.sh -o env"
done
