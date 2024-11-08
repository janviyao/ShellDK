#!/bin/bash
echo_debug "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
source $MY_VIM_DIR/tools/paraparser.sh "" "$@"

function how_use
{
    local script_name=$(path2fname $0)
    echo "=================== Usage ==================="
    printf "%-20s <source-dir> <destination-dir> [<exclude-regex> ...]\n" "${script_name}"
    printf "%-20s @ %s\n" "<source-dir>"      "where all will be copied from"
    printf "%-20s @ %s\n" "<destination-dir>" "where all will be saved into"
    printf "%-20s @ %s\n" "<exclude-regex>"   "all matches will be eliminated"
    echo "============================================="
}

if [ -z "$(get_subcmd '0')" ];then
    how_use
    exit 1
fi

SRC_DIR="$(get_subcmd 0)"
if [ ! -d ${SRC_DIR} ]; then
    echo_erro "first-para(SRC_DIR) must be directory: ${SRC_DIR}"
    exit 1
fi
SRC_DIR=$(real_path ${SRC_DIR})

regex_index=0
DES_DIR="$(get_subcmd 1)"
if [ -n "${DES_DIR}" ];then
    if [ ! -d ${DES_DIR} ]; then
        echo_erro "second-para(DES_DIR) not directory: ${DES_DIR}"
        exit 1
    fi
    
	regex_index=2
else
    suffix=$(date '+%Y%m%d-%H%M%S')
    DES_DIR=~/${suffix}

	regex_index=1
fi
DES_DIR=$(real_path ${DES_DIR})

BAK_CONF=$(pwd)/.bak.conf
EXCLUDE_FILS=($(get_subcmd "${regex_index}-") "\w+\.d" "\w+\.o" "\w+\.gcno")
EXCLUDE_DIRS=($(get_subcmd "${regex_index}-")) "build")

function common_backup
{
    local bak_obj="$1"
    if [ -z "${bak_obj}" ];then
        echo_erro "item empty: ${bak_obj}"
        return 1
    fi

    local real_item=$(real_path ${bak_obj})
    if ! have_file "${real_item}"; then
        return 1
    fi

    local real_path=$(fname2path ${real_item})
    local same_path=$(string_same "${real_item}" "${SRC_DIR}" 1)
    if [ -n "${same_path}" ];then
        real_path=$(string_trim "${real_path}" "${same_path}" 1)
    fi

    local is_exclude=1
    if [ -f ${real_item} ];then
        for regex in ${EXCLUDE_FILS[*]}
        do
            [ -z "${regex}" ] && continue
            if match_regex "${real_item}" "${regex}";then 
                echo_warn "Exclude F: ${real_item}"
                is_exclude=0
                break
            fi
        done

        if [ ${is_exclude} -ne 0 ];then 
            local desdir=${DES_DIR}${real_path}
            mkdir -p ${desdir} 

            cp -f ${real_item} ${desdir}
            echo_info "Copy File: ${real_item}"
        fi
    else
        for regex in ${EXCLUDE_DIRS[*]}
        do
            [ -z "${regex}" ] && continue
            if match_regex "${real_item}" "${regex}";then 
                echo_warn "Exclude D: ${real_item}"
                is_exclude=0
                break
            fi
        done

        if [ ${is_exclude} -ne 0 ];then 
            local desdir=${DES_DIR}${real_path}
            mkdir -p ${desdir} 

            cp -fr ${real_item} ${desdir}
            echo_info "Copy  Dir: ${real_item}"
        fi
    fi

    return 0
}

function get_from_conf
{
    local list=($(cat ${BAK_CONF}))
    for item in ${list[*]}
    do
        echo ${item}
    done
}

function get_from_git
{
    local list=($(git status --porcelain | awk '{ print $2 }'))
    for item in ${list[*]}
    do
        echo ${item}
    done
}

cd ${SRC_DIR}
if have_file ".git"; then
    ITEM_LIST=($(get_from_git))
    for item in ${ITEM_LIST[*]}
    do
        common_backup "${item}"
        if [ $? -ne 0 ];then
            echo_erro "Git-inval: ${item}"
        fi
    done
fi

if have_file "${BAK_CONF}"; then
    ITEM_LIST=($(get_from_conf))
    for item in ${ITEM_LIST[*]}
    do
        common_backup "${item}"
        if [ $? -ne 0 ];then
            echo_erro "Cnf-inval: ${item}"
        fi
    done
else
    if ! have_file ".git"; then
		echo_erro "file { ${BAK_CONF} } not accessed"
        exit 1
    fi
fi

echo_info "SavedPath: ${DES_DIR}"
chmod 777 -R ${DES_DIR}
