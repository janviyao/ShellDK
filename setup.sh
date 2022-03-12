#!/bin/bash
$MY_VIM_DIR/tools/collect.sh "/tmp/vim.tar"
$MY_VIM_DIR/tools/scphosts.sh "/tmp/vim.tar" "${MY_HOME}"
$MY_VIM_DIR/tools/sshhosts.sh "tar -xf ${MY_HOME}/vim.tar"
$MY_VIM_DIR/tools/sshhosts.sh "${MY_VIM_DIR}/install.sh -o env"

