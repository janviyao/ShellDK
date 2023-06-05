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
let s:map_table = {
            \   'csfind' : [
            \   {
            \     'tag'   : '',
            \     'time'  : 0.0,
            \     'prev'  : '',
            \     'next'  : []
            \   }
            \   ],
            \   'grep' : [
            \   {
            \     'tag'   : '',
            \     'time'  : 0.0,
            \     'prev'  : '',
            \     'next'  : []
            \   }
            \   ]
            \ }

function! s:tag2index(module, tag) abort
    call PrintArgs("2file", "tag2index", a:module, a:tag)
    let info_list = s:map_table[a:module]
    if strlen(a:tag) == 0
        call LogPrint("2file", "tag2index return: -1")
        return -1
    endif

    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["tag"] == a:tag
            call LogPrint("2file", "tag2index return: ".index)
            return index
        endif
        let index += 1
    endwhile

    call LogPrint("2file", "tag2index return: -1")
    return -1
endfunction

function! s:alloc_index(module, tag) abort
    let info_list = s:map_table[a:module]
    let length = len(info_list)
    call PrintArgs("2file", "alloc_index", a:module, a:tag, "length=".length)

    let index = 0
    while index < length
        let item = get(info_list, index)
        if item["tag"] == a:tag
            call LogPrint("2file", "alloc_index return: ".index." @tag exist")
            return index
        endif
        let index += 1
    endwhile

    let index = 0
    while index < length
        let item = get(info_list, index)
        if strlen(item["tag"]) == 0
            call LogPrint("2file", "alloc_index return: ".index." @tag null")
            return index
        endif
        let index += 1
    endwhile

    if s:map_table_index >= length
        let s:map_table_index = length
    endif

    let index = s:map_table_index
    let s:map_table_index += 1
    if s:map_table_index > g:quickfix_index_max
        let s:map_table_index = 0
        let drop_tag = s:get_tag(a:module, 0)
        if strlen(drop_tag) > 0
            call s:unset_map(a:module, drop_tag)
        endif
    endif

    call s:set_value(a:module, a:tag, index, "", [])
    call LogPrint("2file", "alloc_index return: ".index)
    return index
endfunction

function! s:set_value(module, tag, index, prev, next) abort
    call PrintArgs("2file", "set_value", "module=".a:module, "tag=".a:tag, "index=".a:index, "prev=".a:prev, "next=".string(a:next))
    if strlen(a:tag) == 0 || a:index < 0
        call LogPrint("error", "module: ".a:module." tag or index invalid")
        return
    endif

    let info_list = s:map_table[a:module]
    let length = len(info_list)
    let update = 0
    while update < length
        let item = get(info_list, update)
        if item["tag"] == a:tag
            call LogPrint("2file", "set [".a:tag."] find index: ".update)
            break
        endif
        let update += 1
    endwhile

    let info_dic = {}
    if update < length
        let info_dic = get(info_list, update)
        if update != a:index
            call remove(info_list, update)
            call insert(info_list, info_dic, a:index)
        endif
    else
        call insert(info_list, info_dic, a:index)
    endif

    let info_dic["time"]  = GetElapsedTime()
    let info_dic["tag"]   = a:tag
    let info_dic["index"] = a:index
    let info_dic["prev"]  = a:prev
    if has_key(info_dic, "next")
        for next_tag in a:next
            if index(info_dic["next"], next_tag) < 0
                call add(info_dic["next"], next_tag)
            endif
        endfor
    else
        let info_dic["next"]  = []
        call extend(info_dic["next"], a:next)
    endif

    call PrintDict("2file", "set_value map_table[".a:index."]", info_dic)
    return a:index
endfunction

function! s:unset_map(module, tag, callback) abort
    call PrintArgs("2file", "unset_map", a:module, a:tag)
    if strlen(a:tag) == 0
        call LogPrint("error", "module: ".a:module." tag invalid")
        return
    endif

    let info_list = s:map_table[a:module]

    let unset_item = {}
    let index = s:tag2index(a:module, a:tag)
    if index >= 0
        let unset_item = info_list[index]
        let unset_item["tag"] = ""
    endif

    for item in info_list 
        if item["prev"] == a:tag
            if empty(unset_item)
                let item["prev"] = "" 
                call LogPrint("2file", "change [".item["tag"]."] prev from [".a:tag."] to []")
            else
                let item["prev"] = unset_item["prev"]
                call LogPrint("2file", "change [".item["tag"]."] prev from [".a:tag."] to [".unset_item["prev"]."]")
            endif
            call a:callback(item["tag"])
        endif

        let index = index(item["next"], a:tag)
        if index >= 0
            call LogPrint("2file", "delete [".item["tag"]."] from ".string(item["next"]))
            call remove(item["next"], index)
            if !empty(unset_item)
                call add(item["next"], unset_item["next"])
            endif
            call a:callback(item["tag"])
        endif
    endfor
endfunction

function! s:get_index_all(module, index_list, start = 0, end = 0)
    if empty(a:index_list)
        let root_list = s:get_index_root(a:module)
        call extend(a:index_list, root_list)
    endif
    call LogPrint("2file", a:module." list: ".string(a:index_list)." start: ".a:start." end: ".a:end)

    let cur_list = deepcopy(a:index_list)
    if a:start < a:end && a:end > 0
        let cur_list = slice(cur_list, a:start, a:end)
    endif

    for cur_idx in cur_list
        let next_pos = index(a:index_list, cur_idx) 
        if next_pos < 0
            call LogPrint("error", a:module." index ".cur_idx." over range: ".string(a:index_list))
            return -1
        endif
        call LogPrint("2file", a:module." cur_idx: ".cur_idx." next_pos: ".next_pos)

        let next_list = s:get_index_next(a:module, cur_idx)
        if len(next_list) > 0
            "call LogPrint("2file", a:module." next: ".string(next_list))
            let insert_pos = next_pos + 1
            for idx in next_list
                call insert(a:index_list, idx, insert_pos)
                let insert_pos += 1
            endfor

            call s:get_index_all(a:module, a:index_list, next_pos + 1, insert_pos)
        endif
    endfor
endfunction

function! s:get_index_root(module) abort
    call PrintArgs("2file", "get_index_root", a:module)
    let info_list = s:map_table[a:module]

    let res_list = []
    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if strlen(item["tag"]) > 0
            let prev_index = s:tag2index(a:module, item["prev"])
            if prev_index < 0
                call add(res_list, index)
            endif
        endif
        let index += 1
    endwhile

    call LogPrint("2file", "get_index_root return: ".string(res_list))
    return res_list
endfunction

function! s:get_index_next(module, index) abort
    call PrintArgs("2file", "get_index_next", a:module, a:index)
    let info_list = s:map_table[a:module]
    if a:index < 0
        call LogPrint("2file", "get_index_prev return: []")
        return []
    endif

    let length = len(info_list)
    if a:index >= length
        call LogPrint("2file", "get_index_prev return: []")
        return []
    endif

    let res_list = []
    let item = get(info_list, a:index)
    let tag_list = item["next"] 
    for tag in tag_list
        let next_index = s:tag2index(a:module, tag)
        if next_index >= 0
            call add(res_list, next_index)
        else
            call LogPrint("error", "module: ".a:module." tag: ".tag." not map")
        endif
    endfor

    call LogPrint("2file", "get_index_next return: ".string(res_list))
    return res_list
endfunction

function! s:get_index_prev(module, index) abort
    call PrintArgs("2file", "get_index_prev", a:module, a:index)
    let info_list = s:map_table[a:module]
    if a:index < 0
        call LogPrint("2file", "get_index_prev return: -1")
        return -1
    endif

    let length = len(info_list)
    if a:index >= length
        call LogPrint("2file", "get_index_prev return: -1")
        return -1
    endif

    let item = get(info_list, a:index)
    let prev_tag = item["prev"] 
    let prev_index = s:tag2index(a:module, prev_tag)
    if prev_index >= 0
        call LogPrint("2file", "get_index_prev return: ".prev_index)
        return prev_index
    else
        call LogPrint("2file", "get_index_prev return: -1")
        return -1
    endif

    call LogPrint("2file", "get_index_prev return: -1")
    return -1
endfunction

function! s:get_tag_root(module) abort
    call PrintArgs("2file", "get_tag_root", a:module)
    let info_list = s:map_table[a:module]

    let res_list = []
    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if strlen(item["tag"]) > 0
            let prev_index = s:tag2index(a:module, item["prev"])
            if prev_index < 0
                call add(res_list, item["tag"])
            endif
        endif
        let index += 1
    endwhile

    call LogPrint("2file", "get_tag_root return: ".string(res_list))
    return res_list
endfunction

function! s:get_tag_next(module, tag) abort
    call PrintArgs("2file", "get_tag_next", a:module, a:tag)
    let info_list = s:map_table[a:module]
    if strlen(a:tag) == 0
        call LogPrint("2file", "get_tag_next return: []")
        return []
    endif

    let res_list = []
    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if has_key(item, "tag")
            if item["tag"] == a:tag
                call extend(res_list, item["next"])
                break
            endif
        else
            call LogPrint("error", "module: ".a:module." tag: ".a:tag." invalid item: ".string(item))
        endif
        let index += 1
    endwhile

    call LogPrint("2file", "get_tag_next return: ".string(res_list))
    return res_list
endfunction

function! s:get_tag_prev(module, tag) abort
    call PrintArgs("2file", "get_tag_prev", a:module, a:tag)

    let info_list = s:map_table[a:module]
    if strlen(a:tag) == 0
        call LogPrint("2file", "get_tag_prev return: ")
        return ""
    endif

    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["tag"] == a:tag
            call LogPrint("2file", "get_tag_prev return: ".item["prev"]." @index: ".index)
            return item["prev"] 
        endif
        let index += 1
    endwhile

    call LogPrint("2file", "get_tag_prev return: ")
    return ""
endfunction

function! s:get_index_oldest(module) abort
    call PrintArgs("2file", "get_index_oldest", a:module)
    let info_list = s:map_table[a:module]

    let old_index = -1
    let oldest = GetElapsedTime()
    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["time"] < oldest
            let oldest = item["time"]
            let old_index = index
        endif
        let index += 1
    endwhile

    call LogPrint("2file", "get_index_oldest return: ".old_index)
    return old_index
endfunction

function! s:map_empty(module) abort
    let info_list = s:map_table[a:module]

    let length = len(info_list)
    let index = 0
    while index < length
        let item = get(info_list, index)
        if strlen(item["tag"]) > 0
            return 0
        endif

        let index += 1
    endwhile
    return 1
endfunction

function! s:get_tag(module, index) abort
    call PrintArgs("2file", "get_tag", a:module, a:index)
    let info_list = s:map_table[a:module]

    if len(info_list) <= a:index || a:index < 0
        call LogPrint("2file", "get_tag return: ")
        return "" 
    endif

    let item = info_list[a:index] 
    call LogPrint("2file", "get_tag return: ".item["tag"])
    return item["tag"]
endfunction

function! s:get_time(module, tag) abort
    call PrintArgs("2file", "get_time", a:module, a:tag)
    let info_list = s:map_table[a:module]

    let index = 0
    let length = len(info_list)
    while index < length
        let item = get(info_list, index)
        if item["tag"] == a:tag
            return item["time"]
        endif
        let index += 1
    endwhile

    return 0.0
endfunction

let s:map_ops = {
            \   'alloc_index'      : function("s:alloc_index"),
            \   'set_value'        : function("s:set_value"),
            \   'unset_map'        : function("s:unset_map"),
            \   'tag2index'        : function("s:tag2index"),
            \   'get_tag'          : function("s:get_tag"),
            \   'get_time'         : function("s:get_time"),
            \   'get_index_all'    : function("s:get_index_all"),
            \   'get_index_root'   : function("s:get_index_root"),
            \   'get_index_next'   : function("s:get_index_next"),
            \   'get_index_prev'   : function("s:get_index_prev"),
            \   'get_index_oldest' : function("s:get_index_oldest"),
            \   'get_tag_root'     : function("s:get_tag_root"),
            \   'get_tag_next'     : function("s:get_tag_next"),
            \   'get_tag_prev'     : function("s:get_tag_prev"),
            \   'empty'            : function("s:map_empty")
            \ }

function! map#get_ops() abort
    return s:map_ops
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
