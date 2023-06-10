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
let s:file_table = {
            \   'file1' : {
            \         'cmd_time' : 0.0,
            \         'cmd_type' : 'write',
            \         'cmd_mode' : 'b',
            \         'line_nr'  : 0,
            \         'dat_type' : 'list',
            \         'dat_list' : [],
            \         'dat_dict' : {},
            \         'filepath' : "file1",
            \   },
            \   'file2' : {
            \         'cmd_time' : 0.0,
            \         'cmd_type' : 'read',
            \         'cmd_mode' : 'b',
            \         'line_nr'  : 0,
            \         'dat_type' : 'dict',
            \         'dat_list' : [],
            \         'dat_dict' : {},
            \         'filepath' : "file2",
            \   }
            \ }

function! s:has_file(filepath) abort
    call PrintArgs("2file", "file.has_file", a:filepath)
    return has_key(s:file_table, a:filepath)
endfunction

function! s:has_data(filepath) abort
    call PrintArgs("2file", "file.has_data", a:filepath)
    
    if has_key(s:file_table, a:filepath)
        let data = s:get_data(a:filepath) 

        let data_lines = len(data)
        "call LogPrint("2file", "data lines: ".data_lines) 
        if data_lines > 0
            return v:true
        endif
    endif

    return v:false
endfunction

function! s:get_data(filepath) abort
    call PrintArgs("2file", "file.get_data", a:filepath)

    let info_dic = s:file_table[a:filepath]
    if info_dic.dat_type ==# "dict"
        return info_dic["dat_dict"]
    elseif info_dic.dat_type ==# "list"
        return info_dic["dat_list"]
    endif
endfunction

function! s:make_req(cmd_type, cmd_mode, dat_type, filepath, line_nr, status, data) abort
    call PrintArgs("2file", "file.make_req", a:cmd_type, a:cmd_mode, a:dat_type, a:filepath, a:line_nr, a:status)

    if !empty(a:data)
        if a:dat_type == "dict"
            call PrintDict("2file", a:cmd_type." dict-data", a:data) 
        elseif a:dat_type == "list"
            call PrintList("2file", a:cmd_type." list-data", a:data) 
        endif
    endif
    
    if !has_key(s:file_table, a:filepath)
        let s:file_table[a:filepath] = {}
    endif

    let request = s:file_table[a:filepath]
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
    call PrintArgs("2file", "file.process_req", a:request)

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
                endif

                let a:request["filepath"] = new_name
                let a:request["dat_list"] = []
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
            \   'has_file'    : function("s:has_file"),
            \   'has_data'    : function("s:has_data"),
            \ }

function! File_get_ops() abort
    return s:file_ops
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
