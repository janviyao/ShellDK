if &cp || exists('g:lock_loaded')
    if &cp && &verbose
        echo "Not loading Lock.vim in compatible mode."
    endif
    finish
endif
let g:lock_loaded = 1
let s:cpo_save = &cpo
set cpo&vim

if has('python3')
python3 << EOF
import vim
import threading

g_lock_map = {}
class VimMutex:
    def __init__(self, name):
        self.name = name
        self.mutex = threading.Lock()

    def lock(self):
        self.mutex.acquire()
    
    def unlock(self):
        self.mutex.release()

g_task_map = {}
class VimTask(threading.Thread):
    def __init__(self, name, func):
        threading.Thread.__init__(self)
        self.name = name
        self.func = func
        self.destory = False
        self.paused = False
        self.task_event = threading.Event()
        self.pause_event = threading.Event()

    def run(self):
        try:
            while not self.destory:
                print('Thread [ %s ] started\n' % self.name)
                if self.paused:
                    print('Thread [ %s ] Paused\n' % self.name)
                    self.pause_event.wait()

                self.task_event.wait(1)
                print('Thread [ %s ] wait\n' % self.name)
                # vim.eval(self.func + '("' + self.name + '")')
                vim.command("doautocmd User MyEvent")
                print('Thread [ %s ] Ended\n' % self.name)
        except Exception as e:
            print(Exception, ":", e)

    def destroy(self):
        self.destory = True
    
    def do_work(self):
        self.task_event.set()

    def pause(self, value):
        self.paused = value
        if not self.paused:
            self.pause_event.set()
EOF

function! s:mutex_create(name)
python3 << EOF
import vim
try:
    name = vim.eval("a:name")    
    if g_lock_map.get(name) is None:
        mutex = VimMutex(name) 
        g_lock_map[name] = mutex
except Exception as e:
    print(Exception, ":", e)
EOF
endfunction

function! s:mutex_lock(name)
python3 << EOF
import vim
try:
    name = vim.eval("a:name")    
    mutex = g_lock_map.get(name) 
    mutex.lock()
except Exception as e:
    print(Exception, ":", e)
EOF
endfunction

function! s:mutex_unlock(name)
python3 << EOF
import vim
try:
    name = vim.eval("a:name")    
    mutex = g_lock_map.get(name) 
    mutex.unlock()
except Exception as e:
    print(Exception, ":", e)
EOF
endfunction

function! s:task_create(name, func)
    call PrintArgs("2file", "thread.task_create", a:name, string(a:func))
python3 << EOF
import vim
try:
    name = vim.eval("a:name")    
    func = vim.eval("a:func")    
    if g_task_map.get(name) is None:
        print("task create: ", name, func)
        task = VimTask(name, func) 
        task.start()
        g_task_map[name] = task
except Exception as e:
    print(Exception, ":", e)
EOF
endfunction

function! s:task_work(name)
    "call PrintArgs("2file", "thread.task_work", a:name)
python3 << EOF
import vim
try:
    name = vim.eval("a:name")    
    task = g_task_map[name] 
    task.do_work()
except Exception as e:
    print(Exception, ":", e)
EOF
endfunction

function! s:task_delete(name)
    call PrintArgs("2file", "thread.task_delete", a:name)
python3 << EOF
import vim
try:
    name = vim.eval("a:name")    
    task = g_task_map[name] 
    task.destroy()
    g_task_map.pop(name)
except Exception as e:
    print(Exception, ":", e)
EOF
endfunction

function! s:task_pause(name, value)
    "call PrintArgs("2file", "thread.task_pause", a:name, string(a:value))
python3 << EOF
import vim
try:
    name = vim.eval("a:name")    
    value = vim.eval("a:value")    
    print("task pause: ", name, value)
    task = g_task_map[name] 
    task.pause(value)
except Exception as e:
    print(Exception, ":", e)
EOF
endfunction
else
python << EOF
import vim
import threading

g_lock_map = {}
class VimMutex:
    def __init__(self, name):
        self.name = name
        self.mutex = threading.Lock()

    def lock(self):
        self.mutex.acquire()
    
    def unlock(self):
        self.mutex.release()

g_task_map = {}
class VimTask(threading.Thread):
    def __init__(self, name, func):
        threading.Thread.__init__(self)
        self.name = name
        self.func = func
        self.destory = False
        self.paused = False
        self.task_event = threading.Event()
        self.pause_event = threading.Event()

    def run(self):
        try:
            while not self.destory:
                print('Thread [ %s ] started\n' % self.name)
                if self.paused:
                    print('Thread [ %s ] Paused\n' % self.name)
                    self.pause_event.wait()

                self.task_event.wait(1)
                print('Thread [ %s ] wait\n' % self.name)
                # vim.eval(self.func + '("' + self.name + '")')
                vim.command("doautocmd User MyEvent")
                print('Thread [ %s ] Ended\n' % self.name)
        except Exception, e:
            print e

    def destroy(self):
        self.destory = True
    
    def do_work(self):
        self.task_event.set()

    def pause(self, value):
        self.paused = value
        if not self.paused:
            self.pause_event.set()
EOF

function! s:mutex_create(name)
python << EOF
import vim
try:
    name = vim.eval("a:name")    
    if g_lock_map.get(name) is None:
        mutex = VimMutex(name) 
        g_lock_map[name] = mutex
except Exception, e:
    print e
EOF
endfunction

function! s:mutex_lock(name)
python << EOF
import vim
try:
    name = vim.eval("a:name")    
    mutex = g_lock_map.get(name) 
    mutex.lock()
except Exception, e:
    print e
EOF
endfunction

function! s:mutex_unlock(name)
python << EOF
import vim
try:
    name = vim.eval("a:name")    
    mutex = g_lock_map.get(name) 
    mutex.unlock()
except Exception, e:
    print e
EOF
endfunction

function! s:task_create(name, func)
    call PrintArgs("2file", "thread.task_create", a:name, string(a:func))
python << EOF
import vim
try:
    name = vim.eval("a:name")    
    func = vim.eval("a:func")    
    if g_task_map.get(name) is None:
        print("task create: ", name, func)
        task = VimTask(name, func) 
        task.start()
        g_task_map[name] = task
except Exception, e:
    print e
EOF
endfunction

function! s:task_work(name)
    "call PrintArgs("2file", "thread.task_work", a:name)
python << EOF
import vim
try:
    name = vim.eval("a:name")    
    task = g_task_map[name] 
    task.do_work()
except Exception, e:
    print e
EOF
endfunction

function! s:task_delete(name)
    call PrintArgs("2file", "thread.task_delete", a:name)
python << EOF
import vim
try:
    name = vim.eval("a:name")    
    task = g_task_map[name] 
    task.destroy()
    g_task_map.pop(name)
except Exception, e:
    print e
EOF
endfunction

function! s:task_pause(name, value)
    "call PrintArgs("2file", "thread.task_pause", a:name, string(a:value))
python << EOF
import vim
try:
    name = vim.eval("a:name")    
    value = vim.eval("a:value")    
    print("task pause: ", name, value)
    task = g_task_map[name] 
    task.pause(value)
except Exception, e:
    print e
EOF
endfunction
endif

let s:lock_ops = {
            \   'mutex_create' : function("s:mutex_create"),
            \   'mutex_lock'   : function("s:mutex_lock"),
            \   'mutex_unlock' : function("s:mutex_unlock"),
            \ }

function! Lock_get_ops() abort
    return s:lock_ops
endfunction

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
