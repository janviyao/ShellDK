if &cp || exists('g:quickfix_map_loaded')
    if &cp && &verbose
        echo "Not loading Quickfix-Map in compatible mode."
    endif
    finish
endif
let g:quickfix_map_loaded = 1
let s:cpo_save = &cpo
set cpo&vim

let s:map_table_index = 0

function! s:compare(value1, value2) abort
    return -1
endfunction

let s:map_table = {
            \   'csfind' : {
            \          'stor' : {
            \               'key1' : {
            \                   'value' : {},
            \                   'time'  : 0.0,
            \                   'prev'  : '',
            \                   'next'  : []
            \               },
            \               'key2' : {
            \                   'value' : {},
            \                   'time'  : 0.0,
            \                   'prev'  : '',
            \                   'next'  : []
            \               },
            \          },
            \          'compare': function("s:compare")
            \   },
            \   'grep' : {
            \          'stor' : {
            \               'key1' : {
            \                   'value' : {},
            \                   'time'  : 0.0,
            \                   'prev'  : '',
            \                   'next'  : []
            \               },
            \               'key2' : {
            \                   'value' : {},
            \                   'time'  : 0.0,
            \                   'prev'  : '',
            \                   'next'  : []
            \               },
            \          },
            \          'compare': function("s:compare")
            \   },
            \ }

function! s:get_key(module, value) abort
    call PrintArgs("2file", "get_key", a:module, a:value)

    let stor_dic = s:map_table[a:module].stor
    for okey in keys(stor_dic)
        if s:map_table[a:module].compare(stor_dic[okey]["value"], a:value) == 0
            call LogPrint("2file", "get_key return: ".okey)
            return okey
        endif
    endfor
    
    call LogPrint("2file", "get_key return: ")
    return ""
endfunction

function! s:get_value(module, key) abort
    call PrintArgs("2file", "get_value", a:module, a:key)

    let stor_dic = s:map_table[a:module].stor
    if has_key(stor_dic, a:key)
        call LogPrint("2file", "get_value return: ".string(stor_dic[a:key]["value"]))
        return stor_dic[a:key]["value"]
    endif
    
    call LogPrint("2file", "get_value return: {}")
    return {}
endfunction

function! s:get_time(module, key) abort
    call PrintArgs("2file", "get_time", a:module, a:key)

    let stor_dic = s:map_table[a:module].stor
    if has_key(stor_dic, a:key)
        return stor_dic[a:key].time
    endif

    return 0.0
endfunction

function! s:set_value(module, key, value, prev, next) abort
    call PrintArgs("2file", "set_value", a:module, a:key, a:value, a:prev, string(a:next))

    if strlen(a:key) == 0
        call LogPrint("error", "module: ".a:module." key invalid")
        return
    endif

    let stor_dic = s:map_table[a:module].stor
    if ! has_key(stor_dic, a:key)
        let stor_dic[a:key] = {}
    endif

    let info_dic = stor_dic[a:key]
    let info_dic["value"] = a:value
    let info_dic["time"]  = GetElapsedTime()
    let info_dic["prev"]  = a:prev
    if !has_key(info_dic, "next")
        let info_dic["next"]  = []
    endif
    call extend(info_dic["next"], a:next)

    call PrintDict("2file", "set_value map_table[".a:key."]", info_dic)
    return 0
endfunction

function! s:insert_at(module, index, info = {}) abort
    call PrintArgs("2file", "insert_at", a:module, a:index, a:info)
    let stor_dic = s:map_table[a:module].stor

    let length = len(stor_dic)
    if a:index < 0
        call LogPrint("error", "module: ".a:module." insert_at index=".a:index." invalid")
        return -1
    endif

    if a:index >= length
        let fill_cnt = a:index - length
        while fill_cnt >= 0
            let info_dic = {}
            let info_dic["key"]   = ""
            let info_dic["value"] = {} 
            let info_dic["time"]  = 0.0 
            let info_dic["prev"]  = ""
            let info_dic["next"]  = []
            call add(stor_dic, info_dic)
            let fill_cnt -= 1
        endwhile
    endif

    if !empty(a:info)
        call insert(stor_dic, a:info, a:index)
        call PrintDict("2file", "insert_at [".a:index."]", a:info)
    endif

    return a:index
endfunction

function! s:remove_at(module, index) abort
    call PrintArgs("2file", "remove_at", a:module, a:index)
    let stor_dic = s:map_table[a:module].stor

    let length = len(stor_dic)
    if length <= a:index || a:index < 0
        call LogPrint("error", "module: ".a:module." remove_at index=".a:index." invalid")
        return -1
    endif

    call remove(stor_dic, a:index)
    return a:index
endfunction

function! s:unset_map(module, key, callback) abort
    call PrintArgs("2file", "unset_map", a:module, a:key)

    if strlen(a:key) == 0
        call LogPrint("error", "module: ".a:module." key invalid")
        return
    endif

    let unset_item = {}
    let stor_dic = s:map_table[a:module].stor
    if has_key(stor_dic, a:key)
        let unset_item = deepcopy(stor_dic[a:key])
        call PrintDict("2file", "unset_item[".a:key."]", unset_item)
        unlet stor_dic[a:key]
    endif

    for okey in keys(stor_dic)
        if stor_dic[okey]["prev"] == a:key
            if empty(unset_item)
                let stor_dic[okey]["prev"] = "" 
                call LogPrint("2file", "change [".okey."] prev from [".a:key."] to []")
            else
                if len(unset_item["prev"]) == 0
                    let stor_dic[okey]["prev"] = "" 
                    call LogPrint("2file", "change [".okey."] prev from [".a:key."] to []")
                else
                    let stor_dic[okey]["prev"] = unset_item["prev"]
                    call LogPrint("2file", "change [".okey."] prev from [".a:key."] to [".unset_item["prev"]."]")
                endif
            endif
            call a:callback(okey)
        endif

        let next_index = index(stor_dic[okey]["next"], a:key)
        if next_index >= 0
            call LogPrint("2file", "delete [".okey."] from ".string(stor_dic[okey]["next"]))
            call remove(stor_dic[okey]["next"], next_index)

            if !empty(unset_item)
                if !empty(unset_item["next"])
                    call extend(stor_dic[okey]["next"], unset_item["next"])
                endif
            endif
            call a:callback(okey)
        endif
    endfor
endfunction

function! s:get_all_value(module, value_list, start = 0, end = 0)
    if empty(a:value_list)
        let root_list = s:get_root_value(a:module)
        call extend(a:value_list, root_list)
    endif
    call LogPrint("2file", a:module." get_all_value: ".string(a:value_list)." start: ".a:start." end: ".a:end)

    let cur_list = deepcopy(a:value_list)
    if a:start < a:end && a:end > 0
        let cur_list = slice(cur_list, a:start, a:end)
    endif

    for cur_val in cur_list
        let next_pos = index(a:value_list, cur_val) 
        if next_pos < 0
            call LogPrint("error", a:module." index ".string(cur_val)." over range: ".string(a:value_list))
            return -1
        endif
        call LogPrint("2file", a:module." cur_val: ".string(cur_val)." next_pos: ".next_pos)

        let cur_key = s:get_key(a:module, cur_val)
        let next_list = s:get_next_value(a:module, cur_key)
        if len(next_list) > 0
            "call LogPrint("2file", a:module." next: ".string(next_list))
            let insert_pos = next_pos + 1
            for val in next_list
                call insert(a:value_list, val, insert_pos)
                let insert_pos += 1
            endfor

            call s:get_all_value(a:module, a:value_list, next_pos + 1, insert_pos)
        endif
    endfor
endfunction

function! s:get_root_value(module) abort
    call PrintArgs("2file", "get_root_value", a:module)

    let res_list = []
    let stor_dic = s:map_table[a:module].stor
    for okey in keys(stor_dic)
        if strlen(stor_dic[okey]["prev"]) == 0
            call add(res_list, stor_dic[okey]["value"])
        else
            if !has_key(stor_dic, stor_dic[okey]["prev"])
                call add(res_list, stor_dic[okey]["value"])
            endif
        endif
    endfor

    call LogPrint("2file", "get_root_value return: ".string(res_list))
    return res_list
endfunction

function! s:get_next_value(module, key) abort
    call PrintArgs("2file", "get_next_value", a:module, a:key)

    let res_list = []
    let stor_dic = s:map_table[a:module].stor
    if has_key(stor_dic, a:key) 
        let next_list = stor_dic[a:key]["next"]
        for okey in next_list
            if has_key(stor_dic, okey) 
                call add(res_list, stor_dic[okey]["value"])
            else
                call LogPrint("error", "module: ".a:module." key: ".okey." not map")
            endif
        endfor
    endif
    
    call LogPrint("2file", "get_next_value return: ".string(res_list))
    return res_list
endfunction

function! s:get_prev_value(module, key) abort
    call PrintArgs("2file", "get_prev_value", a:module, a:key)

    let stor_dic = s:map_table[a:module].stor
    if has_key(stor_dic, a:key)
        let prev_key = stor_dic[a:key]["prev"]
        if has_key(stor_dic, prev_key)
            call LogPrint("2file", "get_prev_value return: ".string(stor_dic[prev_key].value))
            return stor_dic[prev_key].value
        endif
    endif
    
    call LogPrint("2file", "get_prev_value return: {}")
    return {}
endfunction

function! s:get_root_key(module) abort
    call PrintArgs("2file", "get_root_key", a:module)

    let res_list = []
    let stor_dic = s:map_table[a:module].stor
    for okey in keys(stor_dic)
        if strlen(stor_dic[okey]["prev"]) == 0
            call add(res_list, okey)
        else
            if !has_key(stor_dic, stor_dic[okey]["prev"])
                call add(res_list, okey)
            endif
        endif
    endfor

    call LogPrint("2file", "get_root_key return: ".string(res_list))
    return res_list
endfunction

function! s:get_next_key(module, key) abort
    call PrintArgs("2file", "get_next_key", a:module, a:key)

    let res_list = []
    let stor_dic = s:map_table[a:module].stor
    if has_key(stor_dic, a:key) 
        let next_list = stor_dic[a:key]["next"]
        for okey in next_list
            call add(res_list, okey)
            if !has_key(stor_dic, okey) 
                call LogPrint("2file", "module: ".a:module." key: ".okey." not map")
            endif
        endfor
    endif
    
    call LogPrint("2file", "get_next_key return: ".string(res_list))
    return res_list
endfunction

function! s:get_prev_key(module, key) abort
    call PrintArgs("2file", "get_prev_key", a:module, a:key)
    
    let stor_dic = s:map_table[a:module].stor
    if has_key(stor_dic, a:key)
        let prev_key = stor_dic[a:key]["prev"]
        if has_key(stor_dic, prev_key)
            call LogPrint("2file", "get_prev_key return: ".prev_key)
            return prev_key
        endif
    endif

    call LogPrint("2file", "get_prev_key return: ")
    return ""
endfunction

function! s:empty(module) abort
    let stor_dic = s:map_table[a:module].stor
    return empty(stor_dic)
endfunction

function! s:copy(module, des_key, src_key) abort
    let stor_dic = s:map_table[a:module].stor
    if has_key(stor_dic, a:src_key)
        let src_item = stor_dic[a:src_key] 

        if ! has_key(stor_dic, a:des_key)
            let stor_dic[a:des_key] = {}
        endif
        let des_item = stor_dic[a:des_key] 

        call extend(des_item, src_item)
    endif
endfunction

function! s:map_initiate(module, compare_func) abort
    let s:map_table[a:module] = {}
    let s:map_table[a:module]["stor"] = {}
    let s:map_table[a:module]["compare"] = a:compare_func
endfunction

let s:map_ops = {
            \   'map_initiate'     : function("s:map_initiate"),
            \   'set_value'        : function("s:set_value"),
            \   'unset_map'        : function("s:unset_map"),
            \   'remove_at'        : function("s:remove_at"),
            \   'empty'            : function("s:empty"),
            \   'copy'             : function("s:copy"),
            \   'get_key'          : function("s:get_key"),
            \   'get_value'        : function("s:get_value"),
            \   'get_time'         : function("s:get_time"),
            \   'get_all_value'    : function("s:get_all_value"),
            \   'get_root_value'   : function("s:get_root_value"),
            \   'get_next_value'   : function("s:get_next_value"),
            \   'get_prev_value'   : function("s:get_prev_value"),
            \   'get_root_key'     : function("s:get_root_key"),
            \   'get_next_key'     : function("s:get_next_key"),
            \   'get_prev_key'     : function("s:get_prev_key"),
            \ }

function! map#get_ops() abort
    return s:map_ops
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
