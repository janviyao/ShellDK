if &cp || exists('g:quickfix_file_loaded')
    if &cp && &verbose
        echo "Not loading Quickfix-Worker in compatible mode."
    endif
    finish
endif
let g:quickfix_file_loaded = 1
let s:cpo_save = &cpo
set cpo&vim

let s:file_table_index = 0
let s:file_table = [
            \   {
            \     'cmd_time' : 0.0,
            \     'cmd_type' : 'write',
            \     'cmd_mode' : 'b',
            \     'line_nr'  : 0,
            \     'dat_type' : 'list',
            \     'filepath' : '',
            \     'dat_list' : [],
            \     'dat_dict' : {},
            \   },
            \   {
            \     'cmd_time' : 0.0,
            \     'cmd_type' : 'read',
            \     'cmd_mode' : 'b',
            \     'line_nr'  : 0,
            \     'dat_type' : 'dict',
            \     'filepath' : '',
            \     'dat_list' : [],
            \     'dat_dict' : {},
            \   },
            \   {
            \     'cmd_time' : 0.0,
            \     'cmd_type' : 'delete',
            \     'cmd_mode' : '',
            \     'line_nr'  : 0,
            \     'dat_type' : '',
            \     'filepath' : '',
            \     'dat_list' : [],
            \     'dat_dict' : {},
            \   }
            \ ]

python << EOF
import vim, threading
file_lock = threading.Lock()
def FileLock():
    file_lock.acquire()
def FileUnlock():
    file_lock.release()
EOF

function! s:file_lock()
python << EOF
try:
    FileLock()
except Exception, e:
    print e
EOF
endfunction

function! s:file_unlock()
python << EOF
try:
    FileUnlock()
except Exception, e:
    print e
EOF
endfunction

function! s:alloc_index(filepath) abort
    "call PrintArgs("2file", "alloc_index", "filepath=".a:filepath)
    call s:file_lock()
    let oldest_index = s:get_oldest(a:filepath)
    if oldest_index >= 0
        call LogPrint("2file", "old file_alloc_index: ".oldest_index." for: ".fnamemodify(a:filepath, ":t"))
        call s:file_unlock()
        return oldest_index
    endif

    let index = s:file_table_index
    let s:file_table_index += 1
    if s:file_table_index > 5000
        let s:file_table_index = 0
    endif

    if index >= len(s:file_table)
        call insert(s:file_table, {}, index)
    endif
    call s:file_unlock()

    call LogPrint("2file", "new file_alloc_index: ".index." for: ".fnamemodify(a:filepath, ":t"))
    return index
endfunction

function! s:get_oldest(filepath) abort
    "call PrintArgs("2file", "get_oldest", a:filepath)
    let time_oldest = GetElapsedTime()
    let res_index = -1

    let length = len(s:file_table)
    let index =0
    while index < length
        let item = get(s:file_table, index)
        if item["filepath"] == a:filepath 
            if item["cmd_time"] < time_oldest 
                let time_oldest = item["cmd_time"]
                let res_index = index
            endif
        endif
        let index += 1
    endwhile

    "call LogPrint("2file", "get_oldest: ".res_index) 
    return res_index 
endfunction

function! s:get_index(filepath) abort
    "call PrintArgs("2file", "get_index", a:filepath)
    let time_newest = 0
    let res_index = -1

    let length = len(s:file_table)
    let index =0
    while index < length
        let item = get(s:file_table, index)
        if item["filepath"] ==# a:filepath
            if item["cmd_time"] > time_newest 
                let time_newest = item["cmd_time"]
                let res_index = index
            endif
        endif
        let index += 1
    endwhile

    call LogPrint("2file", "get_index: ".res_index) 
    return res_index 
endfunction

function! s:get_data(request) abort
    if a:request.dat_type ==# "dict"
        return a:request["dat_dict"]
    elseif a:request.dat_type ==# "list"
        return a:request["dat_list"]
    endif
endfunction

function! s:get_cache(cache_index) abort
    let info_dic = s:file_table[a:cache_index]
    return s:get_data(info_dic) 
endfunction

function! s:has_data(file_index) abort
    if len(s:file_table) <= a:file_index
        call LogPrint("2file", "no data, index(".a:file_index.") over max-length(".len(s:file_table).")") 
        return 0
    endif

    let info_dic = s:file_table[a:file_index]
    let data = s:get_data(info_dic) 
    let data_lines = len(data)

    call LogPrint("2file", "work[".a:file_index."] data lines: ".data_lines) 
    return data_lines 
endfunction

function! s:make_req(cmd_type, cmd_mode, dat_type, filepath, line_nr, status, data) abort
    let file_index = s:alloc_index(a:filepath)

    call PrintArgs("2file", "make_req", "index=".file_index, a:cmd_type, a:cmd_mode, a:dat_type, a:filepath, a:line_nr, a:status)
    if !empty(a:data)
        if a:dat_type == "dict"
            call PrintDict("2file", a:cmd_type." dict-data @index-".file_index, a:data) 
        elseif a:dat_type == "list"
            call PrintList("2file", a:cmd_type." list-data @index-".file_index, a:data) 
        endif
    endif

    let request = s:file_table[file_index]
    let request['cmd_time'] = GetElapsedTime() 
    let request["cmd_type"] = a:cmd_type
    let request["cmd_mode"] = a:cmd_mode
    let request["dat_type"] = a:dat_type
    let request["filepath"] = a:filepath
    let request["line_nr"]  = a:line_nr

    if !empty(a:data) 
        let request["dat_dict"] = {}
        let request["dat_list"] = []

        if a:dat_type == "dict"
            call extend(request["dat_dict"], a:data)
        elseif a:dat_type == "list"
            call extend(request["dat_list"], a:data)
        endif
    endif

    if !has_key(request, "dat_dict")
        let request["dat_dict"] = {}
    endif

    if !has_key(request, "dat_list")
        let request["dat_list"] = []
    endif

    return request
endfunction

function! s:process_req(request) abort
    call PrintArgs("2file", "process_req", a:request)
    let cmd_type = a:request['cmd_type'] 
    let cmd_mode = a:request['cmd_mode'] 
    let dat_type = a:request['dat_type'] 
    let filepath = a:request['filepath'] 
    let line_nr  = a:request['line_nr'] 

    if cmd_type == "write"
        if dat_type == "list"
            let write_list = []
            let data_list = a:request['dat_list'] 
            for item in data_list
                call add(write_list, string(item))
            endfor
            call writefile(write_list, filepath, cmd_mode)
        elseif dat_type == "dict"
            let data_dic  = a:request['dat_dict'] 
            call writefile([string(data_dic)], filepath, cmd_mode)
        endif
    elseif cmd_type == "read"
        if dat_type == "list"
            let data_list = a:request['dat_list'] 
            if ! empty(data_list)
                let count = len(data_list)
                call remove(data_list, 0, count - 1)
            endif

            if filereadable(filepath)
                let read_list = readfile(filepath, cmd_mode, line_nr)
                call extend(data_list, read_list)
            endif
        elseif dat_type == "dict"
            let data_dic  = a:request['dat_dict'] 
            if filereadable(filepath)
                let read_dic = eval(get(readfile(filepath, cmd_mode, line_nr), 0, ''))
                call extend(data_dic, read_dic)
            endif
        endif
    elseif cmd_type == "rename"
        if dat_type == "list"
            let data_list = a:request['dat_list'] 
            if len(data_list) == 1
                let new_name = data_list[0]
                let res_code = rename(filepath, new_name)
                if res_code != 0
                    call LogPrint("error", "rename from ".filepath." to ".new_name." fail")
                else
                    let a:request["dat_list"] = []
                    let a:request["filepath"] = new_name
                endif
            else
                call LogPrint("error", "rename file invalid: ".string(data_list))
            endif
        endif
    endif
endfunction

let s:file_ops = {
            \   'process_req' : function("s:process_req"),
            \   'make_req'    : function("s:make_req"),
            \   'get_data'    : function("s:get_data"),
            \   'get_index'   : function("s:get_index"),
            \   'get_cache'   : function("s:get_cache"),
            \   'has_data'    : function("s:has_data"),
            \ }

function! File_get_ops() abort
    return s:file_ops
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
