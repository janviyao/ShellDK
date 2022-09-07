#!/bin/bash
function how_usage
{
    local script_name=$(path2fname $0)
    echo "=================== Usage ==================="
    printf "%-15s <file-name>\n" "${script_name}"
    printf "%-15s @%s\n" "<file-name>" "file name where ftrace into"
    echo "============================================="
}

if [ $# -lt 1 ];then
    how_usage
    exit 1
fi

file=$(real_path $1)
if ! can_access "${file}";then
    echo_erro "file lost: ${file}"
fi
tmp_file=$(file_temp "$(pwd)")

functions=(net_rx_action mlx5e_handle_rx_cqe nf_hook_slow smp_call_function_single_interrupt \
          iscsi_complete_task scsi_finish_command dm_complete_request blk_update_request blk_account_io_done \
          part_round_stats)

echo "FUNCTION TOTAL(us) COUNT AVG(us)" > ${tmp_file}
for func in ${functions[*]}
do
    cat ${file} | grep -F "${func}" | awk "BEGIN{ total=0; count=0; } { if (\$7 ~ /^[0-9.]+$/) { total=total+\$7;count=count+1; }} END{ printf \"${func} %f %d %f\n\",total,count,total/count; }" >> ${tmp_file}
done

#cat ${tmp_file} | sort -n -t " " -k 4 -o ${tmp_file}
cat ${tmp_file} | column -t
rm -f ${tmp_file}*
