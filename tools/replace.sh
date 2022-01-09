#!/bin/bash
INCLUDE "TEST_DEBUG" $MY_VIM_DIR/tools/include/common.api.sh
. $MY_VIM_DIR/tools/paraparser.sh

paras_list="${parasMap['others']}"

OLD_STR="$(echo ${paras_list} | cut -d ' ' -f 1)"
NEW_STR="$(echo ${paras_list} | cut -d ' ' -f 2)"
DES_DIR="$(echo ${paras_list} | cut -d ' ' -f 3)"

if [ -z "${DES_DIR}" ];then
    echo_warn "will do replacement in current directory"
    DES_DIR="."
else
    if [ ! -d "${DES_DIR}" ];then
        echo_erro "not a directory: ${DES_DIR}"
        exit 1
    fi
fi
DES_DIR="$(cd ${DES_DIR};pwd)"
DES_DIR="$(match_trim_end "${DES_DIR}" "/")"

function do_replace
{
    local old_reg="$1"
    local new_str="$2"
    local des_dir="$3"

    echo_debug "do_replace: [${old_reg} @ ${new_str} @ $(match_trim_start "${des_dir}" "${DES_DIR}/")]"

    cd ${des_dir}
    for thing in `ls` 
    do
        if [ -d "${thing}" ];then
            do_replace "${old_reg}" "${new_str}" "${des_dir}/${thing}"
            cd ${des_dir}
            continue
        fi

        echo_debug "replace: $(match_trim_start "${des_dir}" "${DES_DIR}/")/${thing}"

        local old_str=$(grep -P "${old_reg}" -o ${thing} | head -n 1)
        if [ -n "${old_str}" ];then
            local old_str="$(regex_replace "${old_str}" "/" "\/")"
            local sed_str="$(regex_replace "${new_str}" "/" "\/")"
            sed -i "s/${old_str}/${sed_str}/g" ${thing}
        fi
    done

    echo_info "finish: $(match_trim_start "${des_dir}" "${DES_DIR}/")"
}

do_replace "${OLD_STR}" "${NEW_STR}" "${DES_DIR}"
