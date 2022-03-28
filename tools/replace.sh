#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
. $MY_VIM_DIR/tools/paraparser.sh

function replace_file
{
    local old_reg="$1"
    local new_str="$2"
    local repfile="$3"

    local old_str=$(grep -P "${old_reg}" -o ${repfile} | head -n 1)
    if [ -n "${old_str}" ];then
        local old_str=$(replace_regex "${old_str}" '/' '\/')
        local old_str=$(replace_regex "${old_str}" '\*' '\*')
        local old_str=$(replace_regex "${old_str}" '\[' '\[')
        local old_str=$(replace_regex "${old_str}" '\]' '\]')
        local sed_str=$(replace_regex "${new_str}" '/' '\/')
        sed -i "s/${old_str}/${sed_str}/g" ${repfile}

        echo_info "replace: $(trim_str_start "${repfile}" "${rep_dir}/")"
    fi
}

function do_replace
{
    local old_reg="$1"
    local new_str="$2"
    local des_dir="$3"

    echo_debug "do_replace: [${old_reg} @ ${new_str} @ $(trim_str_start "${des_dir}" "${rep_dir}/")]"

    cd ${des_dir}
    for thing in `ls` 
    do
        if [ -d "${thing}" ];then
            do_replace "${old_reg}" "${new_str}" "${des_dir}/${thing}"
            cd ${des_dir}
            continue
        fi
        replace_file "${old_reg}" "${new_str}" "${des_dir}/${thing}"
    done

    echo_debug "finish: $(trim_str_start "${des_dir}" "${rep_dir}/")"
}

OLD_STR="${other_paras[0]}"
NEW_STR="${other_paras[1]}"
unset other_paras[0]
unset other_paras[1]
replace_list=(${other_paras[@]})

CUR_DIR=$(pwd)
for rep_dir in ${replace_list[@]}
do
    if ! can_access "${rep_dir}";then
        echo_erro "not a directory or file: ${rep_dir}"
        continue
    fi
    
    if [ -d "${rep_dir}" ];then
        rep_dir=$(cd ${rep_dir};pwd)
        rep_dir=$(trim_str_end "${rep_dir}" "/")
    fi

    if [ -d "${rep_dir}" ];then
        do_replace "${OLD_STR}" "${NEW_STR}" "${rep_dir}"
    else
        echo_debug "do_replace: [${OLD_STR} @ ${NEW_STR} @ ${rep_dir}]"
        replace_file "${OLD_STR}" "${NEW_STR}" "${rep_dir}" 
        echo_debug "finish: ${rep_dir}"
    fi

    cd ${CUR_DIR}
done
