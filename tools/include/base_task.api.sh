#!/bin/bash
source $MY_VIM_DIR/tools/include/bashrc.api.sh
INCLUDE "GBL_MDAT_PIPE" $MY_VIM_DIR/tools/task/mdat_task.sh
INCLUDE "GBL_NCAT_PIPE" $MY_VIM_DIR/tools/task/ncat_task.sh

