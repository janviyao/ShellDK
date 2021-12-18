#!/bin/bash
ROOT_DIR=$(cd `dirname $0`;pwd)
LAST_ONE=`echo "${ROOT_DIR}" | grep -P ".$" -o`
if [ ${LAST_ONE} == '/' ]; then
    ROOT_DIR=`echo "${ROOT_DIR}" | sed 's/.$//g'`
fi
. $ROOT_DIR/api.sh

SRC_ROOT=$1
if [ ! -d ${SRC_ROOT} ]; then
    echo_erro "Not Dir: ${SRC_ROOT}"
    exit -1
fi

BAK_ROOT=$2
if [ -z "${BAK_ROOT}" ];then
    SUFFIX=`date '+%Y%m%d-%H%M%S'`
    BAK_ROOT=~/${SUFFIX}
fi

EXCLUDE_FILE=""
EXCLUDE_DIR="\w+\.d \w+\.o \w+\.gcno"

cd ${SRC_ROOT}

FLIST=`git status -s | awk '{ print $2 }'`
for fname in $FLIST
do
    fdir=$(readlink -f $(dirname ${fname}))
    if [ -f ${fname} ];then
        IS_EXCLUDE=0
        for xfile in ${EXCLUDE_FILE}
        do
            IS_VALID=`echo "${fname}" | grep -P "${xfile}" -o`
            if [ ! -z "${IS_VALID}" ];then 
                echo_warn "Exclude File: ${fname}"
                IS_EXCLUDE=1
                break
            fi
        done

        if [ ${IS_EXCLUDE} -ne 1 ];then 
            desdir=${BAK_ROOT}${fdir}
            mkdir -p ${desdir} 

            cp -f ${fname} ${desdir}
            echo_info "Copy File: ${fname}"
        fi
    else
        IS_EXCLUDE=0
        for xdir in ${EXCLUDE_DIR}
        do
            IS_VALID=`echo "${fname}" | grep -P "${xdir}" -o`
            if [ ! -z "${IS_VALID}" ];then 
                echo_warn "Exclude Dir: ${fname}"
                IS_EXCLUDE=1
                break
            fi
        done

        if [ ${IS_EXCLUDE} -ne 1 ];then 
            desdir=${BAK_ROOT}${fdir}
            mkdir -p ${desdir} 

            cp -fr ${fname} ${desdir}
            echo_info "Copy  Dir: ${fname}"
        fi
    fi
done

chmod 777 -R ${BAK_ROOT}
