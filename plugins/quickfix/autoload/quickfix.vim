if &cp || exists('g:quickfix_loaded')
    if &cp && &verbose
        echo "Not loading Quickfix-Quickfix in compatible mode."
    endif
    finish
endif
let g:quickfix_loaded = 1
let s:cpo_save = &cpo
set cpo&vim

let s:qfix_module        = "init"
let s:qfix_main_index    = -1
let s:qfix_main_info     = {}
let s:qfix_list_max      = 5000
let s:qfix_read_timeout  = 30000
let s:qfix_open_list     = v:false
let s:qfix_list          = { 'csfind' : [], 'grep' : [] }
let s:qfix_list_pick     = 1
let s:map_op             = Map_get_ops()
let s:file_op            = File_get_ops()
let s:worker_op          = Worker_get_ops()

function! s:async_load(worker_id)
    "call PrintArgs("2file", "quickfix.async_load", a:worker_id)
    let line_dic = s:get_qfix_item(getqflist({'idx' : 0}).idx)

    let title = line_dic.text
    let str_idx = stridx(line_dic.text, "<->")
    if str_idx > 0
        let title = trim(strpart(line_dic.text, 0, str_idx))
    endif

    let value = s:map_op.get_value(s:qfix_module, title)
    call s:qfix_load(s:qfix_module, value.index)
    call quickfix#ctrl_main("close")
    "call LogPrint("2file", "async_load index: ".value.index." tag: ".line_dic.text)
endfunction

function! s:do_buf_enter()
    if &buftype == "quickfix"
        let s:qfix_opened = bufnr("$")
        "call LogPrint("2file", "enter pick: ".s:qfix_main_info["pick"])
    endif
endfunction

function! s:do_buf_leave()
    if &buftype == "quickfix"
        if s:qfix_open_list
            let s:qfix_open_list = v:false
            call timer_start(1, "s:async_load", {'repeat': 1})
        else
            let s:qfix_main_info["pick"] = getqflist({'idx' : 0}).idx
            "call LogPrint("2file", "leave pick: ".s:qfix_main_info["pick"])
        endif
    endif
endfunction

"跟踪quickfix窗口状态
augroup QFixToggle
    autocmd!

    autocmd BufWinEnter * call s:do_buf_enter()
    autocmd BufWinLeave * call s:do_buf_leave()
    autocmd BufLeave * call s:do_buf_leave()

    "不在quickfix窗内移动，则关闭quickfix窗口
    autocmd CursorMoved * if exists("s:qfix_opened") && &buftype != 'quickfix' | call quickfix#ctrl_main("close") | endif
augroup END

function! s:write_dict(module, file, mode, dic_data) abort
    "call PrintArgs("2file", "quickfix.write_dict", a:module, a:file, a:mode, a:dic_data)

    if s:worker_op.is_stoped("quickfix")
        call LogPrint("error", "write_dict worker stoped")
        return
    endif
 
    let request = s:file_op.make_req("write", a:mode, "dict", a:file, -1, 0, a:dic_data)
    let work_index = s:worker_op.work_alloc("quickfix")    
    call s:worker_op.fill_req("quickfix", work_index, request)
endfunction

function! s:write_list(module, file, mode, list_data) abort
    "call PrintArgs("2file", "quickfix.write_list", a:module, a:file, a:mode, a:list_data)

    if s:worker_op.is_stoped("quickfix")
        call LogPrint("2file", "write_list worker stoped")
        return
    endif
    
    let request = s:file_op.make_req("write", a:mode, "list", a:file, -1, 0, a:list_data)
    let work_index = s:worker_op.work_alloc("quickfix")    
    call s:worker_op.fill_req("quickfix", work_index, request)
endfunction

function! s:read_dict(module, file, mode, line_num) abort
    "call PrintArgs("2file", "quickfix.read_dict", a:module, a:file, a:mode, a:line_num)
    
    if s:worker_op.is_stoped("quickfix") == 1
        call LogPrint("2file", "read_dict worker stoped")
        return {}
    endif

    if s:file_op.has_file(a:file)
        if s:file_op.has_data(a:file)
            let data = s:file_op.get_data(a:file)
            if type(data) != v:t_dict
                call LogPrint("warn", "read [".a:file."] mode [".a:mode."] invalid dict: \n".string(data))
                let data = eval(string(data))
                if type(data) != v:t_dict
                    call LogPrint("error", "mode [".a:mode."] invalid dict from file [".a:file."]")
                    return {}
                endif
            endif

            call PrintDict("2file", "read_dict cache-result", data) 
            return data
        endif
    endif
    
    let request = s:file_op.make_req("read", a:mode, "dict", a:file, a:line_num, 0, {})
    let work_index = s:worker_op.work_alloc("quickfix")    
    call s:worker_op.fill_req("quickfix", work_index, request)

    let time_s = 0
    while !s:worker_op.work_cpl("quickfix", work_index)
        "call LogPrint("2file", "read_dict sleep: 2ms")
        silent! execute 'sleep 2m'
        let time_s += 2
        if time_s > s:qfix_read_timeout
            call LogPrint("error", "read_dict timeout: ".string(request))
            return {}
        endif
    endwhile

    let data = s:file_op.get_data(a:file)
    if type(data) != v:t_dict
        call LogPrint("warn", "read [".a:file."] mode [".a:mode."] invalid dict: \n".string(data))
        let data = eval(string(data))
        if type(data) != v:t_dict
            call LogPrint("error", "mode [".a:mode."] invalid dict from file [".a:file."]")
            return {}
        endif
    endif

    call PrintDict("2file", "read_dict return: ", data) 
    return data
endfunction

function! s:read_list(module, file, mode, line_num) abort
    "call PrintArgs("2file", "quickfix.read_list", a:module, a:file, a:mode, a:line_num)

    if s:worker_op.is_stoped("quickfix") == 1
        call LogPrint("2file", "read_list worker stoped")
        return {}
    endif

    if s:file_op.has_file(a:file)
        if s:file_op.has_data(a:file)
            let data = s:file_op.get_data(a:file)
            if type(data) != v:t_list
                call LogPrint("warn", "read [".a:file."] mode [".a:mode."] invalid list: \n".string(data))
                let data = eval(string(data))
                if type(data) != v:t_list
                    call LogPrint("error", "mode [".a:mode."] invalid list from file [".a:file."]")
                    return []
                endif
            endif

            call PrintList("2file", "read_list cache-result", data) 
            return data
        endif
    endif
    
    let request = s:file_op.make_req("read", a:mode, "list", a:file, a:line_num, 0, [])
    let work_index = s:worker_op.work_alloc("quickfix")    
    call s:worker_op.fill_req("quickfix", work_index, request)

    let time_ms = 0
    while !s:worker_op.work_cpl("quickfix", work_index)
        "call LogPrint("2file", "read_list sleep: 2ms")
        silent! execute 'sleep 2m'

        let time_ms += 2
        if time_ms > s:qfix_read_timeout
            call LogPrint("error", "read_list timeout: ".string(request))
            return {}
        endif
    endwhile

    let data = s:file_op.get_data(a:file)
    if type(data) != v:t_list
        call LogPrint("warn", "read [".a:file."] mode [".a:mode."] invalid list: \n".string(data))
        let data = eval(string(data))
        if type(data) != v:t_list
            call LogPrint("error", "mode [".a:mode."] invalid list from file [".a:file."]")
            return []
        endif
    endif

    call PrintList("2file", "read_list return: ", data) 
    return data 
endfunction

function! s:rename_file(module, old_name, new_name) abort
    call PrintArgs("2file", "quickfix.rename_file", a:module, a:old_name, a:new_name)

    if s:worker_op.is_stoped("quickfix") == 1
        call LogPrint("2file", "worker stoped")
        return {}
    endif
    
    let request = s:file_op.make_req("rename", "", "list", a:old_name, 0, 0, [a:new_name])
    let work_index = s:worker_op.work_alloc("quickfix")    
    call s:worker_op.fill_req("quickfix", work_index, request)
    while !s:worker_op.work_cpl("quickfix", work_index)
        "call LogPrint("2file", "rename_file sleep: 10ms")
        silent! execute 'sleep 10m'
    endwhile

    return 0
endfunction

function! s:get_tag(module, index)
    call PrintArgs("2file", "quickfix.get_tag", a:module, a:index)

    let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".a:index
    if filereadable(info_file)
        let info_dic = s:read_dict(a:module, info_file, 'b', 1)
        call LogPrint("2file", a:module." get tag [ ".info_dic.title." ] from index=".a:index)
        return info_dic.title
    endif
    
    call LogPrint("2file", "get_tag info.".a:module.".".a:index." not-exist")
    return ""
endfunction

function! s:csfind_sort(item1, item2)
    let fname1 = fnamemodify(bufname(a:item1.bufnr), ':p:.')
    let fname2 = fnamemodify(bufname(a:item2.bufnr), ':p:.')

    if fname1 == fname2 
        let lnum1 = str2nr(a:item1.lnum) 
        let lnum2 = str2nr(a:item2.lnum) 
        if lnum1 == lnum2 
            return 0
        elseif lnum1 < lnum2
            return -1
        else
            return 1
        endif
    else
        let nameList1 = split(fname1, "/")
        let nameList2 = split(fname2, "/")

        let minVal = min([len(nameList1), len(nameList2)])
        let startIndx = 0
        while startIndx < minVal
            if trim(nameList1[startIndx]) == trim(nameList2[startIndx])
                let startIndx += 1
            elseif trim(nameList1[startIndx]) < trim(nameList2[startIndx])
                return -1
            else
                return 1
            endif
        endwhile

        if startIndx == minVal
            return 0
        endif
    endif
    return 0
endfunction

function! s:csfind_format(info)
    "get information about a range of quickfix entries
    let items = getqflist({'id' : a:info.id, 'items' : 1}).items
    let newList = []
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
        "use the simplified file name
        let lnctn = fnamemodify(bufname(items[idx].bufnr), ':p:.')."| ".items[idx].lnum." | ".items[idx].text
        call add(newList, lnctn)
    endfor

    return newList
endfunc

function! s:grep_format(info)
    "get information about a range of quickfix entries
    let items = getqflist({'id' : a:info.id, 'items' : 1}).items
    let newList = []
    for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
        "call LogPrint("2file", string(items[idx]))
        if items[idx].lnum == 0
            call add(newList, "|| ".items[idx].text)
        else
            "use the simplified file name
            let lnctn = fnamemodify(bufname(items[idx].bufnr), ':p:.')."| ".items[idx].lnum." | ".items[idx].text
            call add(newList, lnctn)
        endif
    endfor

    return newList
endfunction

function! s:neat_show(module)
    if a:module == "csfind"
        let qflist = getqflist()
        if len(qflist) < s:qfix_list_max
            call LogPrint("2file", a:module." neat_show sort start")
            call sort(qflist, "s:csfind_sort")
            call LogPrint("2file", a:module." neat_show sort end")

            call setqflist([], "r", {'items' : qflist})
            call LogPrint("2file", a:module." neat_show finish")
        endif
    endif
endfunction

function! s:get_qfix_item(pick)
    call PrintArgs("2file", "quickfix.get_qfix_item", a:pick)

    let qflist = getqflist()

    call LogPrint("2file", "list-size: ".len(qflist)." pick: ".a:pick)
    if a:pick <= len(qflist)
        let index = a:pick - 1
        return get(qflist, index, {})
    endif

    return {}
endfunction

function! s:list_all_qfix(module, title)
    call PrintArgs("2file", "quickfix.list_all_qfix", a:module, a:title)

    let pick = s:qfix_list_pick
    let new_list = s:qfix_list[a:module]
    if empty(new_list)
        let value_list = [] 
        call s:map_op.get_all_value(a:module, value_list)

        for value in value_list 
            if !has_key(value, "index")
                call LogPrint("2file", "value invalid: ".string(value))
                continue
            endif

            let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".value.index
            if filereadable(info_file)
                let info_dic = s:read_dict(a:module, info_file, 'b', 1)
                let list_file = GetVimDir(1, 'quickfix').'/list.'.a:module.'.'.value.index
                if filereadable(list_file)
                    let qflist = s:read_list(a:module, list_file, '', 9999999)

                    let line_idx = info_dic.pick - 1

                    let item = get(qflist, line_idx, [])
                    if type(item) == v:t_dict
                        let line_dic = deepcopy(item)
                    else
                        let line_dic = deepcopy(eval(item))
                    endif

                    let title = info_dic["title"]
                    if title == a:title
                        let pick = len(new_list) + 1
                        let s:qfix_list_pick = pick
                    endif

                    let last_str = "["
                    let next_list = info_dic["next"]
                    for tag in next_list
                        if strlen(last_str) > 1
                            let last_str .= " , ".tag
                        else
                            let last_str .= tag
                        endif
                    endfor
                    let last_str .= "]"

                    if strlen(last_str) > 0
                        let line_dic["text"] = title." <-> ".last_str
                    else
                        let line_dic["text"] = title
                    endif
                    call add(new_list, line_dic)
                endif
            endif
        endfor
    endif

    "call LogPrint("2file", "list_all_qfix list-size: ".len(new_list))
    if !empty(new_list)
        call setqflist([], "r", {'items' : new_list})
        call setqflist([], 'a', {'idx': pick})
    endif
endfunction

function! s:alloc_qfix_index(module)
    call PrintArgs("2file", "quickfix.alloc_qfix_index", a:module)

    let all_index = []
    let info_list = systemlist("ls ".GetVimDir(1, "quickfix")."/info.".a:module.".*")
    for info_file in info_list
        if filereadable(info_file)
            let index_val = str2nr(matchstr(info_file, '\v-?\d+$'))
            call add(all_index, index_val)
        endif
    endfor

    let index = 0
    while index < g:quickfix_index_max
        if index(all_index, index) < 0
            return index
        endif

        let index += 1
    endwhile

    call LogPrint("error", "quickfix index used-up: ".string(all_index))
    return -1
endfunction

function! s:qfix_rebuild(module)
    call PrintArgs("2file", "quickfix.qfix_rebuild", a:module)

    let index_init = -1
    let index_file = GetVimDir(1, "quickfix").'/index.'.a:module
    if filereadable(index_file)
        let data = s:read_list(a:module, index_file, 'b', 1)
        let index_init = str2nr(get(data, 0, ''))
        call LogPrint("2file", "qfix_rebuild main_index=".index_init)
    endif

    let info_list = systemlist("ls ".GetVimDir(1, "quickfix")."/info.".a:module.".*")
    for info_file in info_list
        if filereadable(info_file)
            let index_val = str2nr(matchstr(info_file, '\v-?\d+$'))
            call LogPrint("2file", "rebuild info.".a:module.".".index_val)

            let info_dic = s:read_dict(a:module, info_file, 'b', 1)
            if empty(info_dic)
                call LogPrint("warn", "skip empty file: ".info_file)
                call s:qfix_delete(a:module, index_val) 
                continue
            endif
            
            if has_key(info_dic, "title")
                let value = { "key": info_dic["title"], "index": index_val }
                call s:map_op.set_value(a:module, info_dic["title"], value, info_dic["prev"], info_dic["next"])
            else
                call LogPrint("error", "key-title empty from file [ ".info_file." ]")
            endif
        endif
    endfor

    let tag_list = s:map_op.get_root_key(a:module)
    while len(tag_list) > 0
        let tag = remove(tag_list, 0)
        let next_list = s:map_op.get_next_key(a:module, tag)
        for ntag in next_list
            let value = s:map_op.get_value(a:module, ntag)
            if empty(value)
                call LogPrint("warn", "destroyed info [ ".ntag." ] ")
                let Callback = function("s:unset_callback", [a:module])
                call s:map_op.unset_map(a:module, ntag, Callback) 
            endif
        endfor

        if !empty(next_list)
            call extend(tag_list, next_list)
        endif
    endwhile

    "let value_list = []
    "call s:map_op.get_all_value(a:module, value_list)
    "for value in value_list 
    "    let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".value.index
    "    if filereadable(info_file)

    "    endif
    "endfor
    "let map_index = 0
    "let map_size = s:map_op.get_size(a:module)
    "while map_index < map_size
    "    let info_file = GetVimDir(1, "quickfix")."/info.".a:module.".".map_index
    "    if filereadable(info_file)
    "        let map_index += 1
    "        continue
    "    else
    "        let map_next = map_index + 1
    "        while map_next < map_size
    "            let next_file = GetVimDir(1, "quickfix")."/info.".a:module.".".map_next
    "            if filereadable(next_file)
    "                break
    "            endif
    "            let map_next += 1
    "        endwhile

    "        if map_next < map_size
    "            let old_file = GetVimDir(1, "quickfix")."/info.".a:module.".".map_next
    "            let new_name = GetVimDir(1, "quickfix")."/info.".a:module.".".map_index
    "            call s:rename_file(a:module, old_file, new_name)

    "            let list_file = GetVimDir(1, 'quickfix').'/list.'.a:module.'.'.map_next
    "            if filereadable(list_file)
    "                let new_name = GetVimDir(1, "quickfix")."/list.".a:module.".".map_index
    "                call s:rename_file(a:module, list_file, new_name)
    "            endif

    "            if index_init == map_next
    "                call LogPrint("2file", "qfix_rebuild main_index change from ".index_init." to ".map_index)
    "                let index_init = map_index
    "                call s:write_list(a:module, index_file, 'b', [index_init])
    "            endif

    "            call s:map_op.copy(a:module, map_index, map_next)
    "            call s:map_op.remove_at(a:module, map_next)
    "            let map_size = s:map_op.get_size(a:module)
    "        endif
    "    endif
    "    let map_index += 1
    "endwhile
 
    return index_init
endfunction

function! s:qfix_load(module, index)
    call PrintArgs("2file", "quickfix.qfix_load", a:module, a:index)
    if strlen(a:module) == 0
        call LogPrint("error", "qfix_load index ".a:index." but module null")
        return -1
    endif

    let s:qfix_main_index = a:index
    if s:qfix_main_index < 0 
        "first load
        let s:qfix_main_index = s:qfix_rebuild(a:module)
    endif

    call LogPrint("2file", a:module." load index: ".s:qfix_main_index)
    if s:qfix_main_index < 0 
        return -1
    endif

    let list_file = GetVimDir(1, 'quickfix').'/list.'.a:module.'.'.s:qfix_main_index
    if filereadable(list_file) 
        let info_dic = {} 
        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".s:qfix_main_index
        if filereadable(info_file)
            let info_dic = s:read_dict(a:module, info_file, 'b', 1)
        else
            call LogPrint("error", a:module." info file lost: ".info_file)
            return -1
        endif 
        call PrintDict("2file", a:module." load key", info_dic)

        call filter(s:qfix_main_info, 0)
        call extend(s:qfix_main_info, info_dic)

        if info_dic.index != s:qfix_main_index
            call LogPrint("2file", a:module." load index from ".info_dic.index." to ".s:qfix_main_index)
            "call quickfix#dump_info(a:module)
            let s:qfix_main_info["index"] = s:qfix_main_index
        endif
        let qflist = s:read_list(a:module, list_file, '', 9999999)

        let dict_list = []
        for item in qflist
            if type(item) == v:t_dict
                "let res_code = setqflist([item], 'a')
                call add(dict_list, item)
            else
                let info_dic = eval(item)
                call add(dict_list, info_dic)
            endif
        endfor
        call setqflist([], "r", {'items' : dict_list})

        if len(qflist) != len(getqflist())
            call LogPrint("error", a:module." setqflist fail, set: ".len(qflist)." success: ".len(getqflist()))
        endif

        if a:module == "csfind"
            call setqflist([], 'a', {'quickfixtextfunc': 's:csfind_format'})
        elseif a:module == "grep"
            call setqflist([], 'a', {'quickfixtextfunc': 's:grep_format'})
        endif

        let res_code = setqflist([], 'a', {'idx': s:qfix_main_info["pick"]})
        if res_code != 0
            call LogPrint("error", a:module." pick invalid: ".s:qfix_main_info["pick"])
        endif

        let res_code = setqflist([], 'a', {'title': s:qfix_main_info["title"]})
        if res_code != 0
            call LogPrint("error", a:module." title invalid: ".s:qfix_main_info["title"])
        endif

        "call LogPrint("2file", a:module." set idx: ".s:qfix_main_info["pick"]." get: ".string(getqflist({'idx' : 0})))
        "call LogPrint("2file", a:module." set title: ".string(getqflist({'title' : 0})))

        let s:qfix_main_info["size"] = getqflist({'size' : 1}).size
        let s:qfix_main_info["title"] = getqflist({'title' : 1}).title

        let fname = fnamemodify(bufname("%"), ':p:.') 
        if fname != s:qfix_main_info.fname
            silent! execute "buffer! ".s:qfix_main_info.fname
        endif
        call cursor(s:qfix_main_info.fline, s:qfix_main_info.fcol)

        "save the newest index
        let index_file = GetVimDir(1, "quickfix").'/index.'.a:module
        call s:write_list(a:module, index_file, 'b', [s:qfix_main_index])
        "call quickfix#dump_info(a:module)
        return 0
    endif

    return -1
endfunction

function! s:qfix_save(module, index)
    call PrintArgs("2file", "quickfix.qfix_save", a:module, a:index)

    let qflist = getqflist()
    if !empty(qflist)
        if s:qfix_main_index != a:index
            call LogPrint("error", a:module." save index not consistent: ".s:qfix_main_index." != ".a:index)
            "call quickfix#dump_info(a:module)
            call s:qfix_load(a:module, a:index)
        endif

        let index_file = GetVimDir(1, "quickfix").'/index.'.a:module
        call s:write_list(a:module, index_file, 'b', [a:index])

        call s:persist_info(a:module, a:index)
        call s:persist_list(a:module, a:index, qflist)
        return 0
    endif

    return -1
endfunction

function! s:qfix_delete(module, index)
    call PrintArgs("2file", "quickfix.qfix_delete", a:module, a:index)

    let Callback = function("s:unset_callback", [a:module])
    let tag = s:get_tag(a:module, a:index)
    if strlen(tag) > 0
        call s:map_op.unset_map(a:module, tag, Callback)
    endif

    let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".a:index
    if filereadable(info_file)
        call delete(info_file)
        call LogPrint("2file", a:module." delete success: info".info_file)
    endif

    let list_file = GetVimDir(1, "quickfix").'/list.'.a:module.".".a:index
    if filereadable(list_file)
        call delete(list_file)
        call LogPrint("2file", a:module." delete success: list".list_file)
    endif

    if s:map_op.empty(a:module)
        let index_file = GetVimDir(1, "quickfix").'/index.'.a:module
        if filereadable(index_file)
            call delete(index_file)
        endif
        return 0
    endif
endfunction

function! s:persist_info(module, index, key="", value="")
    call PrintArgs("2file", "quickfix.persist_info", a:module, a:index, a:key, a:value)

    let s:qfix_main_info['time'] = GetElapsedTime() 
    if strlen(a:key) == 0
        let s:qfix_main_info['index']  = s:qfix_main_index
        let s:qfix_main_info['fname']  = expand("%:p:.") 
        let s:qfix_main_info['fline']  = line(".")
        let s:qfix_main_info['fcol']   = col(".")
    else
        if strlen(a:value) <= 0
            if a:key == "index"
                let s:qfix_main_info['index'] = s:qfix_main_index
            elseif a:key == "fname"
                let s:qfix_main_info['fname'] = expand("%:p:.") 
            elseif a:key == "fline"
                let s:qfix_main_info['fline'] = line(".")
            elseif a:key == "fcol"
                let s:qfix_main_info['fcol']  = col(".")
            endif
        else
            let s:qfix_main_info[a:key] = eval(a:value) 
        endif
    endif

    let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".a:index
    call LogPrint("2file", a:module." save info: ")
    call s:write_dict(a:module, info_file, 'b', s:qfix_main_info)
endfunction

function! s:persist_list(module, index, qflist)
    call PrintArgs("2file", "quickfix.persist_list", a:module, a:index, a:qflist)

    for item in a:qflist
        let fname = fnamemodify(bufname(item.bufnr), ':p:.') 
        let item["filename"] = fname
        let item["bufnr"]    = 0

        if has_key(item, "end_lnum")
            unlet item["end_lnum"]
        endif

        if has_key(item, "end_col")
            unlet item["end_col"]
        endif
    endfor

    let list_file = GetVimDir(1, "quickfix").'/list.'.a:module.".".a:index
    call s:write_list(a:module, list_file, 'b', a:qflist)
endfunction

function! s:unset_callback(module, tag)
    call PrintArgs("2file", "quickfix.unset_callback", a:module, a:tag)

    let value = s:map_op.get_value(a:module, a:tag)
    if !empty(value)
        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".value.index
        if filereadable(info_file)
            let prev_tag = s:map_op.get_prev_key(a:module, a:tag)
            let next_tag = s:map_op.get_next_key(a:module, a:tag)

            let info_dic = s:read_dict(a:module, info_file, 'b', 1)
            let info_dic["prev"] = prev_tag
            let info_dic["next"] = next_tag
            call s:write_dict(a:module, info_file, 'b', info_dic)

            if value.index == s:qfix_main_index
                let s:qfix_main_info['prev']  = prev_tag 
                let s:qfix_main_info['next']  = next_tag
            endif
        endif
    endif
endfunction

function! s:info_seek(module, mode, index)
    call PrintArgs("2file", "quickfix.info_seek", a:module, a:mode, a:index)

    let tag_val = ""
    let tag = s:get_tag(a:module, a:index)
    if a:mode == "next"
        let tag_list = s:map_op.get_next_key(a:module, tag)    
        let tag_val = s:find_newest_tag(a:module, tag_list)
    elseif a:mode == "prev"
        let tag_val = s:map_op.get_prev_key(a:module, tag)
    endif

    let value = s:map_op.get_value(a:module, tag_val)
    call LogPrint("2file", a:module." seek from info.".a:index." mode: ".a:mode." return: ".value.index)
    return value.index
endfunction

function! s:find_newest_tag(module, tag_list)
    call PrintArgs("2file", "quickfix.find_newest_tag", a:module, a:tag_list)

    let time_max = 0 
    let ret_tag = ""
    for tag in a:tag_list
        let time = s:map_op.get_time(a:module, tag)
        if time_max < time 
            let time_max = time
            let ret_tag = tag
        endif
    endfor

    call LogPrint("2file", a:module." find newest: ".ret_tag)
    return ret_tag
endfunction

function! s:compare_value(val1, val2)
    if ! has_key(a:val1, "key") || ! has_key(a:val2, "key")
        return -1
    endif

    if ! has_key(a:val1, "index") || ! has_key(a:val2, "index")
        return -1
    endif

    if a:val1.key == a:val2.key
        if a:val1.index == a:val2.index
            return 0
        elseif if a:val1.index > a:val2.index
            return 1
        endif
    endif

    return -1
endfunction

function! quickfix#ctrl_main(mode)
    call PrintArgs("2file", "quickfix.quickfix#ctrl_main", a:mode, s:qfix_module)
    if a:mode == "open"
        "call LogPrint("2file", s:qfix_module." pick state: ".string(getqflist({'idx': 0})))
        if !empty(getqflist())
            let height = winheight(0)/2
            silent! execute 'copen '.height
            let s:qfix_opened = bufnr("$")
        endif
    elseif a:mode == "close"
        if exists("s:qfix_opened")
            silent! execute 'cclose'
            unlet! s:qfix_opened
        endif
    elseif a:mode == "toggle"
        if exists("s:qfix_opened")
            call quickfix#ctrl_main("close")        
        else
            call quickfix#ctrl_main("open")        
        endif
    elseif a:mode == "clear"
        call setqflist([], "r", {'items' : []})
    elseif a:mode == "recover"
        silent! execute 'cc!'
    elseif a:mode == "list"
        call quickfix#ctrl_main("save")
        let s:qfix_open_list = v:true
        call s:list_all_qfix(s:qfix_module, s:qfix_main_info["title"])
        call quickfix#ctrl_main("open")
        return 0
    elseif a:mode == "recover-next"
        "call quickfix#dump_info(s:qfix_module)
        call quickfix#ctrl_main("save")

        let next_index = s:info_seek(s:qfix_module, "next", s:qfix_main_index)
        if next_index >= 0
            return s:qfix_load(s:qfix_module, next_index)
        endif
        return -1
    elseif a:mode == "recover-prev"
        "call quickfix#dump_info(s:qfix_module)
        call quickfix#ctrl_main("save")

        let prev_index = s:info_seek(s:qfix_module, "prev", s:qfix_main_index)
        if prev_index >= 0
            return s:qfix_load(s:qfix_module, prev_index)
        endif
        return -1
    elseif a:mode == "next"
        silent! execute 'cn!'
        let s:qfix_main_info["pick"] = getqflist({'idx' : 0}).idx
    elseif a:mode == "prev"
        silent! execute 'cp!'
        let s:qfix_main_info["pick"] = getqflist({'idx' : 0}).idx
    elseif a:mode == "save"
        if empty(getqflist())
            return 0
        endif

        if strlen(s:qfix_module) > 0 && s:qfix_module != "init"
            let moduleFile = GetVimDir(1, "quickfix").'/module'
            call writefile([s:qfix_module], moduleFile, 'b')
        endif

        "call quickfix#dump_info(s:qfix_module)
        let value = s:map_op.get_value(s:qfix_module, getqflist({'title' : 1}).title)
        if has_key(value, "index") && value.index >= 0
            call s:qfix_save(s:qfix_module, value.index)
        else 
            call s:qfix_save(s:qfix_module, s:qfix_main_index)
        endif
    elseif a:mode == "load"
        if s:qfix_module == "init"
            let module_file = GetVimDir(1, "quickfix").'/module'
            if filereadable(module_file)
                let s:qfix_module = get(readfile(module_file, 'b', 1), 0, '')
                if strlen(s:qfix_module) == 0
                    call LogPrint("error", "file [".module_file."] content null, recover to default: csfind")
                    let s:qfix_module = "csfind"
                endif
            else
                let s:qfix_module = "csfind"
            endif
        endif

        call s:qfix_load(s:qfix_module, s:qfix_main_index)

        "when quickfix load empty and then first save, var not exist
        if s:qfix_main_index < 0
            let s:qfix_main_index = 0 

            let s:qfix_main_info["prev"]  = ""
            let s:qfix_main_info["index"] = 0 
            let s:qfix_main_info["next"]  = []

            let s:qfix_main_info["title"] = "!anon!" 
            let s:qfix_main_info["pick"]  = 1
            let s:qfix_main_info["size"]  = 0 
        endif
        "call quickfix#dump_info(s:qfix_module)
    elseif a:mode == "delete"
        "call quickfix#dump_info(s:qfix_module)
        call filter(s:qfix_list[s:qfix_module], 0)

        let delete_index = s:qfix_main_index
        let switch_success = 0

        let value = s:map_op.get_prev_value(s:qfix_module, s:qfix_main_info["title"]) 
        if has_key(value, "index") && value.index >= 0
            let switch_success = 1
            call s:qfix_load(s:qfix_module, value.index)
        else
            let tag_list = copy(s:map_op.get_next_key(s:qfix_module, s:qfix_main_info["title"]))
            while len(tag_list) > 0
                let next_tag = s:find_newest_tag(s:qfix_module, tag_list)
                if strlen(next_tag) == 0
                    call filter(tag_list, 0)
                    break
                endif

                let value = s:map_op.get_value(s:qfix_module, next_tag) 
                if value.index < 0
                    let index = index(tag_list, next_tag)    
                    call remove(tag_list, index)
                else
                    let switch_success = 1
                    call s:qfix_load(s:qfix_module, value.index)
                    break
                endif
            endwhile
        endif

        call s:qfix_delete(s:qfix_module, delete_index) 
        if !switch_success
            call quickfix#ctrl_main("clear")
        endif
    elseif a:mode == "home"
        "call quickfix#dump_info(s:qfix_module)
        call s:neat_show(s:qfix_module)
        call filter(s:qfix_list[s:qfix_module], 0)

        let title = getqflist({'title' : 1}).title
        let value = s:map_op.get_value(s:qfix_module, title)
        if has_key(value, "index") && value.index >= 0
            let prev_tag = "" 
            let next_tag = []

            let info_file = GetVimDir(1, "quickfix").'/info.'.s:qfix_module.".".value.index
            if filereadable(info_file)
                let info_dic = s:read_dict(s:qfix_module, info_file, 'b', 1)
                let prev_tag = info_dic.prev
                let next_tag = info_dic.next
            endif

            let new_value = { "key": title, "index": value.index }
            call s:map_op.set_value(s:qfix_module, title, new_value, prev_tag, next_tag)
            call s:persist_list(s:qfix_module, value.index, getqflist())
            call s:qfix_load(s:qfix_module, value.index)
            return value.index
        else
            let prev_tag = s:get_tag(s:qfix_module, s:qfix_main_index) 
            let new_index= s:alloc_qfix_index(s:qfix_module)
            let next_tag = []

            if strlen(prev_tag) > 0
                let tag_list = s:map_op.get_next_key(s:qfix_module, prev_tag)
                if index(tag_list, title) < 0
                    call add(tag_list, title)
                    let  prevprevtag = s:map_op.get_prev_key(s:qfix_module, prev_tag)

                    let new_value = { "key": prev_tag, "index": s:qfix_main_index }
                    call s:map_op.set_value(s:qfix_module, prev_tag, new_value, prevprevtag, tag_list)
                    call s:persist_info(s:qfix_module, s:qfix_main_index, "next", string(tag_list))
                endif
            else
                call LogPrint("2file", "tag [".title."] prev null")
            endif

            let s:qfix_main_index = new_index

            let s:qfix_main_info["prev"]  = prev_tag
            let s:qfix_main_info["index"] = new_index
            let s:qfix_main_info["next"]  = next_tag

            let s:qfix_main_info["title"] = getqflist({'title' : 1}).title
            let s:qfix_main_info["pick"]  = getqflist({'idx' : 0}).idx
            let s:qfix_main_info["size"]  = getqflist({'size' : 1}).size

            let new_value = { "key": title, "index": s:qfix_main_index }
            call s:map_op.set_value(s:qfix_module, title, new_value, prev_tag, next_tag)
            call s:qfix_save(s:qfix_module, s:qfix_main_index)
            "call quickfix#dump_info(s:qfix_module)
            return new_index 
        endif
    endif

    return 0
endfunction

"CS命令
function! quickfix#csfind(ccmd, csarg)
    call PrintArgs("2file", "quickfix.quickfix#csfind", a:ccmd, a:csarg)

    if s:qfix_module != "csfind"
        let s:qfix_module = "csfind"
        let s:qfix_main_index = -1
        let s:qfix_main_info  = {}

        call quickfix#ctrl_main("load")
        call quickfix#ctrl_main("clear")
    endif

    if a:ccmd == "fs"
        silent! execute "cs find s ".a:csarg 
    elseif a:ccmd == "fg"
        execute "cs find g ".a:csarg 
    elseif a:ccmd == "fc"
        silent! execute "cs find c ".a:csarg 
    elseif a:ccmd == "fd"
        silent! execute "cs find d ".a:csarg 
    elseif a:ccmd == "ft"
        silent! execute "cs find t ".a:csarg 
    elseif a:ccmd == "fe"
        silent! execute "cs find e ".a:csarg 
    elseif a:ccmd == "ff"
        silent! execute "cs find f ".a:csarg 
    elseif a:ccmd == "fi"
        silent! execute "cs find i ".a:csarg 
    endif

    if empty(getqflist())
        call LogPrint("2file", "CSFind: ".a:ccmd." empty")
        return
    endif

    call setqflist([], 'a', {'quickfixtextfunc': 's:csfind_format'}) 
    call quickfix#ctrl_main("home")
    call quickfix#ctrl_main("open")
endfunction

function! quickfix#grep_find(csarg)
    call PrintArgs("2file", "quickfix.quickfix#csfind", a:csarg)

    if s:qfix_module != "grep"
        let s:qfix_module = "grep"
        let s:qfix_main_index = -1
        let s:qfix_main_info  = {}

        call quickfix#ctrl_main("load")
        call quickfix#ctrl_main("clear")
    endif
	
	let pattern = input('Search for perl-regex pattern: ', expand('<cword>'))
	if pattern == ''
		return
	endif

    silent! normal! g`X
    silent! delmarks X
    execute "Rgrep ".pattern

    if empty(getqflist())
        return
    endif

    call setqflist([], 'a', {'quickfixtextfunc': 's:grep_format'}) 
    call quickfix#ctrl_main("home")
    call quickfix#ctrl_main("open")
endfunction

function! quickfix#dump_info(module, value_list=[], width=[])
    if !exists("g:quickfix_dump_enable") || g:quickfix_dump_enable == 0
        return
    endif

    " width[0] prev   width
    " width[1] index  width
    " width[2] next   width
    " width[3] pick   width
    " width[4] cursor width
    " width[5] title  width
    " width[6] file   width

    if len(a:value_list) == 0
        let root_list = s:map_op.get_root_value(a:module)
        call extend(a:value_list, root_list)
    endif

    if len(a:width) == 0
        let next_man_len = 0
        let title_max_len = 0
 
        for value in a:value_list 
            let next_list = s:map_op.get_next_value(a:module, value.key)
            if len(string(next_list)) > next_man_len
                let next_man_len = len(string(next_list))
            endif

            let tag = s:get_tag(a:module, value.index)
            if len(tag) > title_max_len
                let title_max_len = len(tag)
            endif
        endfor

        let next_man_len  += 4
        let title_max_len += 10

        call add(a:width, 2)             "prev
        call add(a:width, 2)             "index
        call add(a:width, next_man_len)  "next
        call add(a:width, 4)             "pick
        call add(a:width, 18)            "cursor
        call add(a:width, title_max_len) "title
        call add(a:width, 2)             "file
    endif

    for value in a:value_list 
        let prev_index = s:map_op.get_prev_value(a:module, value.key)
        let next_list = s:map_op.get_next_value(a:module, value.key)

        let info_file = GetVimDir(1, "quickfix").'/info.'.a:module.".".value.index
        if filereadable(info_file)
            let info_dic = s:read_dict(a:module, info_file, 'b', 1)

            let indexInfo = printf("prev: %-".a:width[0]."d index: %-".a:width[1]."d next: %-".a:width[2]."s", prev_index, value.index, string(next_list))
            let cursorInfo = printf("cursor: %d/%d", info_dic.fline, info_dic.fcol)
            let pickInfo = printf("pick: %-".a:width[3]."d %-".a:width[4]."s", info_dic.pick, cursorInfo)
            let fileInfo = printf("title: %-".a:width[5]."s"." file: %".a:width[6]."s", info_dic.title, info_dic.fname)

            call LogPrint("save", "map ".indexInfo." ".pickInfo." ".fileInfo)
        endif

        if len(next_list) > 0
            call quickfix#dump_info(a:module, next_list, a:width)
        endif
    endfor
endfunction

call s:map_op.map_initiate("csfind", function("s:compare_value"))
call s:map_op.map_initiate("grep", function("s:compare_value"))

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
