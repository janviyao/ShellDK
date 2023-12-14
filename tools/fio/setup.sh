#!/bin/bash
source ${TEST_SUIT_ENV}

FIO_DEBUG_ON=false
FIO_ROOT_DIR=$(current_scriptdir)
FIO_APP_RUNTIME="$MY_VIM_DIR/tools/app/fio --alloc-size=131072"

FIO_OUTPUT_DIR=${TEST_LOG_DIR}/fio
FIO_RESULT_FILE=${FIO_OUTPUT_DIR}/result.csv

kvconf_set "${TEST_SUIT_ENV}" "FIO_DEBUG_ON"    "${FIO_DEBUG_ON}"
kvconf_set "${TEST_SUIT_ENV}" "FIO_ROOT_DIR"    "${FIO_ROOT_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "FIO_APP_RUNTIME" "\"${FIO_APP_RUNTIME}\""
kvconf_set "${TEST_SUIT_ENV}" "FIO_OUTPUT_DIR"  "${FIO_OUTPUT_DIR}"
kvconf_set "${TEST_SUIT_ENV}" "FIO_RESULT_FILE" "${FIO_RESULT_FILE}"



