#!/bin/bash
KV_CONF="test.conf"
TOTAL=5
rm -f ${KV_CONF}
file_create "${KV_CONF}"

echo_info "test: kvconf_set kvconf_append"
for ((idx = 0; idx < ${TOTAL}; idx++))
do
	process_run kvconf_set "${KV_CONF}" "SECTION${idx}" "key${idx}" "value${idx} ${idx}"
	if [ $? -ne 0 ];then
		exit 1
	fi

	process_run kvconf_append "${KV_CONF}" "SECTION${idx}" "key${idx}" "value$((idx + 1)) $((idx + 1))"
	if [ $? -ne 0 ];then
		exit 1
	fi

	process_run kvconf_append "${KV_CONF}" "SECTION${idx}" "key${idx}" "value$((idx + 2)) $((idx + 2))"
	if [ $? -ne 0 ];then
		exit 1
	fi
done

echo
echo_info "test: kvconf_val_get"
for ((idx = 0; idx < ${TOTAL}; idx++))
do
	res=$(process_run kvconf_val_get "${KV_CONF}" "SECTION${idx}" "key${idx}" 0)
	if [ $? -ne 0 ];then
		exit 1
	fi
	echo "section: SECTION${idx} key: key${idx} value(0): ${res}"

	if [[ "${res}" != "value${idx} ${idx}" ]];then
		exit 1
	fi

	res=$(process_run kvconf_val_get "${KV_CONF}" "SECTION${idx}" "key${idx}" 1)
	if [ $? -ne 0 ];then
		exit 1
	fi
	echo "section: SECTION${idx} key: key${idx} value(1): ${res}"

	if [[ "${res}" != "value$((idx + 1)) $((idx + 1))" ]];then
		exit 1
	fi

	res=$(process_run kvconf_val_get "${KV_CONF}" "SECTION${idx}" "key${idx}" 2)
	if [ $? -ne 0 ];then
		exit 1
	fi
	echo "section: SECTION${idx} key: key${idx} value(2): ${res}"

	if [[ "${res}" != "value$((idx + 2)) $((idx + 2))" ]];then
		exit 1
	fi
	echo
done

echo_info "test: kvconf_key_get kvconf_val_get"
for ((idx = 0; idx < ${TOTAL}; idx++))
do
	key_list=($(process_run kvconf_key_get "${KV_CONF}" "SECTION${idx}"))
	if [ $? -ne 0 ];then
		exit 1
	fi

	echo "section: SECTION${idx}"
	for key in "${key_list[@]}"
	do
		val_list=($(process_run kvconf_val_get "${KV_CONF}" "SECTION${idx}" "${key}"))
		if [ $? -ne 0 ];then
			exit 1
		fi
		echo "key: ${key} values: ${val_list[@]}"
	done
	echo
done

echo_info "test: kvconf_val_del kvconf_val_have"
for ((idx = 0; idx < ${TOTAL}; idx++))
do
	process_run kvconf_val_del "${KV_CONF}" "SECTION${idx}" "key${idx}" "value$((idx + 1)) $((idx + 1))"
	if [ $? -ne 0 ];then
		exit 1
	fi

	kvconf_val_have "${KV_CONF}" "SECTION${idx}" "key${idx}" "value$((idx + 1)) $((idx + 1))"
	if [ $? -eq 0 ];then
		exit 1
	fi
done

echo_info "test: kvconf_key_get kvconf_val_get"
for ((idx = 0; idx < ${TOTAL}; idx++))
do
	key_list=($(process_run kvconf_key_get "${KV_CONF}" "SECTION${idx}"))
	if [ $? -ne 0 ];then
		exit 1
	fi

	echo "section: SECTION${idx}"
	for key in "${key_list[@]}"
	do
		val_list=($(process_run kvconf_val_get "${KV_CONF}" "SECTION${idx}" "${key}"))
		if [ $? -ne 0 ];then
			exit 1
		fi
		echo "key: ${key} values: ${val_list[@]}"
	done
	echo
done

echo_info "test: kvconf_key_del kvconf_key_have"
for ((idx = 0; idx < ${TOTAL}; idx++))
do
	process_run kvconf_key_del "${KV_CONF}" "SECTION${idx}" "key${idx}"
	if [ $? -ne 0 ];then
		exit 1
	fi

	kvconf_key_have "${KV_CONF}" "SECTION${idx}" "key${idx}"
	if [ $? -eq 0 ];then
		exit 1
	fi
done

echo_info "test: kvconf_section_del kvconf_section_have"
for ((idx = 0; idx < ${TOTAL}; idx++))
do
	process_run kvconf_section_del "${KV_CONF}" "SECTION${idx}"
	if [ $? -ne 0 ];then
		exit 1
	fi

	kvconf_section_have "${KV_CONF}" "SECTION${idx}"
	if [ $? -eq 0 ];then
		exit 1
	fi
done

echo_info "cat ${KV_CONF}"
cat ${KV_CONF}
rm -f ${KV_CONF}
