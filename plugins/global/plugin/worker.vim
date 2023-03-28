if &cp || exists('g:quickfix_worker_loaded')
    if &cp && &verbose
        echo "Not loading Quickfix-Worker in compatible mode."
    endif
    finish
endif
let g:quickfix_worker_loaded = 1
let s:cpo_save = &cpo
set cpo&vim

let s:STATE_INIT = 0
let s:STATE_HANDLING = 1
let s:STATE_COMPLETE = 2

let s:worker_table_index = 0
let s:worker_time = 2
let s:work_table = [
            \   {
            \     'wk_time' : 0.0,
            \     'request'   : {},
            \     'status'  : s:STATE_COMPLETE
            \   },
            \   {
            \     'wk_time' : 0.0,
            \     'request'   : {},
            \     'status'  : s:STATE_COMPLETE
            \   },
            \   {
            \     'wk_time' : 0.0,
            \     'request'   : {},
            \     'status'  : s:STATE_COMPLETE
            \   }
            \ ]

let s:worker_table = {}

python << EOF
import vim, threading
worker_lock = threading.Lock()
def WorkerLock():
    worker_lock.acquire()
def WorkerUnlock():
    worker_lock.release()
EOF

function! s:worker_lock()
python << EOF
try:
    WorkerLock()
except Exception, e:
    print e
EOF
endfunction

function! s:worker_unlock()
python << EOF
try:
    WorkerUnlock()
except Exception, e:
    print e
EOF
endfunction

function! s:start(name, func) abort
    if has_key(s:worker_table, a:name)
        let worker_dic = s:worker_table[a:name]
        return worker_dic.timer
    endif

    let timer = timer_start(s:worker_time, a:func, {'repeat': -1})

    let worker_dic = {} 
    let worker_dic["timer"] = timer
    let worker_dic["func"] = a:func
    let s:worker_table[a:name] = worker_dic

    return timer
endfunction

function! s:stop(name) abort
    if has_key(s:worker_table, a:name)
        let worker_dic = s:worker_table[a:name]
        call timer_stop(worker_dic.timer) 
        unlet s:worker_table[a:name]
    endif
endfunction

function! s:pause(name, paused) abort
    if has_key(s:worker_table, a:name)
        let worker_dic = s:worker_table[a:name]
        call timer_pause(worker_dic.timer, a:paused) 
    endif
endfunction

function! s:is_stoped(name)
    if has_key(s:worker_table, a:name)
        return 0
    else
        return 1
    endif
endfunction

function! s:is_paused(name)
    if has_key(s:worker_table, a:name)
        let worker_dic = s:worker_table[a:name]
        let info = get(timer_info(worker_dic.timer), 0) 
        "call LogPrint("2file", "timer: ".string(info)) 
        if info["paused"] == 1
            return 1
        endif
    endif

    return 0
endfunction

function! s:work_cpl(work_index) abort
    let work_dic = s:work_table[a:work_index]

    if work_dic["status"] == s:STATE_COMPLETE
        return 1
    endif

    return 0
endfunction

function! s:enter_idle(name) abort
    if has_key(s:worker_table, a:name)
        let worker_dic = s:worker_table[a:name]
        if has_key(worker_dic, "idle")
            let idle_time = s:idle_time(a:name)
            " over 1s
            if idle_time > 1
                call LogPrint("save", "###### ".a:name." enter_idle") 
                call s:pause(a:name, 1)
                unlet worker_dic["idle"]
            endif
        else
            let worker_dic["idle"] = GetElapsedTime()
        endif
    endif
endfunction

function! s:exit_idle(name) abort
    if has_key(s:worker_table, a:name)
        if s:is_paused(a:name)
            call LogPrint("save", "###### ".a:name." exit_idle") 
            call s:pause(a:name, 0)
        endif
    endif
endfunction

function! s:idle_time(name) abort
    if has_key(s:worker_table, a:name)
        let worker_dic = s:worker_table[a:name]
        if has_key(worker_dic, "idle")
            let diff = GetElapsedTime() - worker_dic["idle"]
            return diff
        endif
    endif

    return 0.0
endfunction

function! s:get_oldest(status) abort
    let time_oldest = GetElapsedTime()
    let old_index = -1

    let length = len(s:work_table)
    let index = 0
    while index < length
        let item = get(s:work_table, index)
        if has_key(item, "status")
            if item["status"] == a:status 
                if item["wk_time"] < time_oldest 
                    let time_oldest = item["wk_time"]
                    let old_index = index
                endif
            endif
        endif
        let index += 1
    endwhile

    "call LogPrint("2file", "get_oldest: ".old_index) 
    return old_index 
endfunction

function! s:work_alloc() abort
    call s:worker_lock()
    let oldest_index = s:get_oldest(s:STATE_COMPLETE)
    if oldest_index >= 0
        call s:worker_unlock()
        call LogPrint("2file", "old work_alloc: ".oldest_index)
        return oldest_index
    endif

    let index = s:worker_table_index
    let s:worker_table_index += 1
    if s:worker_table_index > 5000
        let s:worker_table_index = 0
    endif

    if index >= len(s:work_table)
        call insert(s:work_table, {}, index)
    endif
    call s:worker_unlock()

    call LogPrint("2file", "new work_alloc: ".index)
    return index
endfunction

function! s:work_next() abort
    let res_index = s:get_oldest(s:STATE_INIT)
    "if res_index >= 0
    "    call LogPrint("2file", "work_next: ".res_index) 
    "endif
    return res_index 
endfunction

function! s:get_req(work_index) abort
    let work_dic = s:work_table[a:work_index]

    let request = {}
    if has_key(work_dic, "request")
        let request = work_dic["request"]
    endif
    
    return request
endfunction

function! s:fill_req(work_index, request) abort
    call PrintArgs("2file", "fill_req", "index=".a:work_index, a:request)

    let work_dic = s:work_table[a:work_index]
    let work_dic['wk_time'] = GetElapsedTime() 

    if !has_key(work_dic, "request")
        let work_dic["request"] = {}
    endif
    call extend(work_dic["request"], a:request)

    "star to handle work
    let work_dic["status"] = s:STATE_INIT
endfunction

function! s:do_work(work_index, callback) abort
    "call PrintArgs("2file", "do_work", a:work_index)
    let work_dic = s:work_table[a:work_index]
    let request = work_dic["request"]
    "call PrintDict("2file", "handle work_table[".a:work_index."]", work_dic)

    let work_dic['status'] = s:STATE_HANDLING
    call a:callback(request)
    let work_dic['status'] = s:STATE_COMPLETE
endfunction

let s:worker_ops = {
            \   'start'       : function("s:start"),
            \   'stop'        : function("s:stop"),
            \   'pause'       : function("s:pause"),
            \   'enter_idle'  : function("s:enter_idle"),
            \   'exit_idle'   : function("s:exit_idle"),
            \   'do_work'     : function("s:do_work"),
            \   'fill_req'    : function("s:fill_req"),
            \   'get_req'     : function("s:get_req"),
            \   'work_alloc'  : function("s:work_alloc"),
            \   'work_next'   : function("s:work_next"),
            \   'work_cpl'    : function("s:work_cpl"),
            \   'is_stoped'   : function("s:is_stoped"),
            \   'is_paused'   : function("s:is_paused")
            \ }

function! Worker_get_ops() abort
    return s:worker_ops
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
