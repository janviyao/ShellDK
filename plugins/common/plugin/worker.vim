if &cp || exists('g:quickfix_worker_loaded')
    if &cp && &verbose
        echo "Not loading Quickfix-Worker in compatible mode."
    endif
    finish
endif
let g:quickfix_worker_loaded = 1
let s:cpo_save = &cpo
set cpo&vim

let s:STATE_INIT     = 0
let s:STATE_HANDLING = 1
let s:STATE_COMPLETE = 2
let s:worker_time    = 1
let s:worker_table   = {
           \   'quickfix' :
           \   {
           \     'timer'  : -1,
           \     'func'   : function("tr"),
           \     'cursor' : 0,
           \     'log_en' : v:true,
           \     'idle'   : 0.0,
           \     'works'  : [
           \       {
           \         'wk_time' : 0.0,
           \         'request' : {},
           \         'status'  : s:STATE_COMPLETE
           \       },
           \       {
           \         'wk_time' : 0.0,
           \         'request' : {},
           \         'status'  : s:STATE_COMPLETE
           \       },
           \       {
           \         'wk_time' : 0.0,
           \         'request' : {},
           \         'status'  : s:STATE_COMPLETE
           \       }
           \     ]
           \   }
           \ }

python << EOF
import threading
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

function! s:get_name(timer_id)
    for [key, value] in items(s:worker_table)
        if value.timer == a:timer_id
            return key
        endif
    endfor
    return ""
endfunction

function! s:worker_run(timer_id)
    let name = s:get_name(a:timer_id)
    let work_index = s:work_next(name)
    if work_index >= 0
        let worker_dic = s:worker_table[name]
        "if worker_dic.log_en
        "    call PrintArgs("2file", "worker_run", work_index)
        "endif
        let work_table = worker_dic["works"]
        let work_dic = work_table[work_index]

        let request = work_dic["request"]
        "if worker_dic.log_en
        "    call PrintDict("2file", "handle work_table[".work_index."]", work_dic)
        "endif

        let work_dic['status'] = s:STATE_HANDLING
        call worker_dic.func(request)
        " free work resource
        let work_dic["request"] = {}
        let work_dic['status'] = s:STATE_COMPLETE
    else
        call s:enter_idle(name)
    endif
endfunction

function! s:start(name, func) abort
    if has_key(s:worker_table, a:name)
        let worker_dic = s:worker_table[a:name]
        if worker_dic.timer > 0
            return worker_dic.timer
        endif
    endif

    let timer = timer_start(s:worker_time, function("s:worker_run"), {'repeat': -1})
    let worker_dic = {} 
    let worker_dic["timer"]  = timer
    let worker_dic["func"]   = a:func
    let worker_dic["cursor"] = 0
    let worker_dic["idle"]   = 0.0
    let worker_dic["log_en"] = v:true
    let worker_dic["works"]  = []

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
        "if worker_dic.log_en
        "    call LogPrint("2file", "timer: ".string(info)) 
        "endif
        if info["paused"] == 1
            return 1
        endif
    endif

    return 0
endfunction

function! s:work_cpl(name, work_index) abort
    let worker_dic = s:worker_table[a:name]
    let work_table = worker_dic["works"]
    let work_dic = work_table[a:work_index]

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
                if worker_dic.log_en
                    call LogPrint("2file", "###### ".a:name." enter_idle") 
                endif
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
            let worker_dic = s:worker_table[a:name]
            if worker_dic.log_en
                call LogPrint("2file", "###### ".a:name." exit_idle") 
            endif
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

function! s:get_oldest(name, status) abort
    let worker_dic = s:worker_table[a:name]
    let work_table = worker_dic["works"]

    let time_oldest = GetElapsedTime()
    let old_index = -1

    let length = len(work_table)
    let index = 0
    while index < length
        let item = get(work_table, index)
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

    "if worker_dic.log_en
    "    call LogPrint("2file", "get_oldest: ".old_index) 
    "endif
    return old_index 
endfunction

function! s:work_alloc(name) abort
    call s:worker_lock()
    let worker_dic = s:worker_table[a:name]
    "let oldest_index = s:get_oldest(a:name, s:STATE_COMPLETE)
    "if oldest_index >= 0
    "    call s:worker_unlock()
    "    if worker_dic.log_en
    "        call LogPrint("2file", "old work_alloc: ".oldest_index)
    "    endif
    "    return oldest_index
    "endif
    let index = worker_dic.cursor
    let worker_dic.cursor += 1
    if worker_dic.cursor > 5000
        let worker_dic.cursor = 0
    endif

    let work_table = worker_dic["works"]
    if index >= len(work_table)
        call insert(work_table, {}, index)
    endif
    call s:worker_unlock()

    if worker_dic.log_en
        call LogPrint("2file", "new work_alloc: ".index)
    endif
    return index
endfunction

function! s:has_work(name) abort
    let worker_dic = s:worker_table[a:name]
    let work_table = worker_dic["works"]

    let length = len(work_table)
    let index = 0
    while index < length
        let item = get(work_table, index)
        if has_key(item, "status")
            if item["status"] == s:STATE_INIT
                return v:true
            endif
        endif
        let index += 1
    endwhile
    return v:false
endfunction

function! s:work_next(name) abort
    let res_index = s:get_oldest(a:name, s:STATE_INIT)
    "if res_index >= 0
    "    if worker_dic.log_en
    "        call LogPrint("2file", "work_next: ".res_index) 
    "    endif
    "endif
    return res_index 
endfunction

function! s:get_req(name, work_index) abort
    let worker_dic = s:worker_table[a:name]
    let work_table = worker_dic["works"]
    let work_dic = work_table[a:work_index]

    let request = {}
    if has_key(work_dic, "request")
        let request = work_dic["request"]
    endif
    
    return request
endfunction

function! s:fill_req(name, work_index, request) abort
    let worker_dic = s:worker_table[a:name]
    if worker_dic.log_en
        call PrintArgs("2file", "fill_req", "index=".a:work_index, a:request)
    endif

    let work_table = worker_dic["works"]
    let work_dic = work_table[a:work_index]
    let work_dic['wk_time'] = GetElapsedTime() 

    if !has_key(work_dic, "request")
        let work_dic["request"] = {}
    endif
    call extend(work_dic["request"], a:request)

    if s:is_paused(a:name)
        call s:exit_idle(a:name)
    endif

    "star to handle work
    let work_dic["status"] = s:STATE_INIT
endfunction

function! s:set_log(name, val) abort
    let worker_dic = s:worker_table[a:name]
    let worker_dic["log_en"] = a:val
endfunction

let s:worker_ops = {
            \   'start'       : function("s:start"),
            \   'stop'        : function("s:stop"),
            \   'pause'       : function("s:pause"),
            \   'fill_req'    : function("s:fill_req"),
            \   'get_req'     : function("s:get_req"),
            \   'work_alloc'  : function("s:work_alloc"),
            \   'work_cpl'    : function("s:work_cpl"),
            \   'has_work'    : function("s:has_work"),
            \   'set_log'     : function("s:set_log"),
            \   'is_stoped'   : function("s:is_stoped"),
            \   'is_paused'   : function("s:is_paused")
            \ }

function! Worker_get_ops() abort
    return s:worker_ops
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
