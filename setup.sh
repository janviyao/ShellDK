#!/bin/bash
# Push run env
$MY_VIM_DIR/tools/collect.sh "/tmp/vim.tar"
$MY_VIM_DIR/tools/scphosts.sh "/tmp/vim.tar" "${HOME_DIR}"
$MY_VIM_DIR/tools/sshhosts.sh "tar -xf ${HOME_DIR}/vim.tar"