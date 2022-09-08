#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
. $MY_VIM_DIR/tools/paraparser.sh

function do_replace
{
    local old_reg="$1"
    local new_str="$2"
    local des_dir="$3"

    echo_debug "do_replace: [${old_reg} @ ${new_str} @ $(string_trim "${des_dir}" "${rep_dir}/" 1)]"

    cd ${des_dir}
    for thing in `ls` 
    do
        if [ -d "${thing}" ];then
            do_replace "${old_reg}" "${new_str}" "${des_dir}/${thing}"
            cd ${des_dir}
            continue
        fi
        file_replace "${des_dir}/${thing}" "${old_reg}" "${new_str}" true
    done

    echo_debug "finish: $(string_trim "${des_dir}" "${rep_dir}/" 1)"
}

OLD_STR="${other_paras[0]}"
NEW_STR="${other_paras[1]}"
unset other_paras[0]
unset other_paras[1]
replace_list=(${other_paras[*]})

CUR_DIR=$(pwd)
for rep_dir in ${replace_list[*]}
do
    if ! can_access "${rep_dir}";then
        echo_erro "not a directory or file: ${rep_dir}"
        continue
    fi
    
    if [ -d "${rep_dir}" ];then
        rep_dir=$(cd ${rep_dir};pwd)
        rep_dir=$(string_trim "${rep_dir}" "/" 2)
    fi

    if [ -d "${rep_dir}" ];then
        do_replace "${OLD_STR}" "${NEW_STR}" "${rep_dir}"
    else
        echo_debug "do_replace: [${OLD_STR} @ ${NEW_STR} @ ${rep_dir}]"
        file_replace "${rep_dir}" "${OLD_STR}" "${NEW_STR}" true
        echo_debug "finish: ${rep_dir}"
    fi

    cd ${CUR_DIR}
done
