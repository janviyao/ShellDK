#!/bin/bash
source ${TEST_SUIT_ENV}

${ISCSI_ROOT_DIR}/run.sh
${FIO_ROOT_DIR}/run.sh
