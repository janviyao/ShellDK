#!/bin/bash
LOCAL_IP=`ifconfig | grep -P 'inet\s+\d+\.\d+\.\d+\.\d+' -o | grep -v "127.0.0.1" | grep -P '\d+\.\d+\.\d+\.\d+' -o`

TGT_EXE=td_connector
#TGT_EXE=iscsi_tgt

TEST_PERF=no

