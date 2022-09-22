#!/bin/bash
echo_info "@@@@@@: $(path2fname $0) @${LOCAL_IP}"
. $MY_VIM_DIR/tools/paraparser.sh

SRC_ROOT="${other_paras[0]}"
if [ ! -d ${SRC_ROOT} ]; then
    echo_erro "Not Dir: ${SRC_ROOT}"
    exit 1
fi

BAK_ROOT="${other_paras[1]}"
if [ -z "${BAK_ROOT}" ];then
    suffix=$(date '+%Y%m%d-%H%M%S')
    BAK_ROOT=~/${suffix}

    if [ ${#paras_list[*]} -ge 2 ];then
        # remove the first two item
        unset other_paras[0]
        unset other_paras[1]
    else
        # remove the first item
        unset other_paras[0]
    fi
else
    if [ ! -d ${BAK_ROOT} ]; then
        echo_erro "Not Dir: ${BAK_ROOT}"
        exit 1
    fi
    
    # remove the first two item
    unset other_paras[0]
    unset other_paras[1]
fi

EXCLUDE_FILS=(${other_paras[*]} "\w+\.d" "\w+\.o" "\w+\.gcno")
EXCLUDE_DIRS=(${other_paras[*]} "build")

function git_backup
{
    local git_item="$1"

    local is_exclude=1
    if [ -f ${git_item} ];then
        for regex in ${EXCLUDE_FILS[*]}
        do
            [ -z "${regex}" ] && continue
            if match_regex "${git_item}" "${regex}";then 
                echo_warn "Exclude File: ${git_item}"
                is_exclude=0
                break
            fi
        done

        if [ ${is_exclude} -ne 0 ];then 
            local fdir=$(fname2path ${git_item})
            local desdir=${BAK_ROOT}${fdir}
            mkdir -p ${desdir} 

            cp -f ${git_item} ${desdir}
            echo_info "Copy File: ${git_item}"
        fi
    else
        for regex in ${EXCLUDE_DIRS[*]}
        do
            [ -z "${regex}" ] && continue
            if match_regex "${git_item}" "${regex}";then 
                echo_warn "Exclude Dir: ${git_item}"
                is_exclude=0
                break
            fi
        done

        if [ ${is_exclude} -ne 0 ];then 
            local fdir=$(fname2path ${git_item})
            local desdir=${BAK_ROOT}${fdir}
            mkdir -p ${desdir} 

            cp -fr ${git_item} ${desdir}
            echo_info "Copy  Dir: ${git_item}"
        fi
    fi
}

cd ${SRC_ROOT}
FLIST=($(git status -s | awk '{ print $2 }'))
for git_item in ${FLIST[*]}
do
    git_backup "${git_item}"
done

chmod 777 -R ${BAK_ROOT}
