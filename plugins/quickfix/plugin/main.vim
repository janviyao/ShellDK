if &cp || exists('g:quickfix_main_loaded')
    if &cp && &verbose
        echo "Not loading Quickfix-Main in compatible mode."
    endif
    finish
endif
let g:quickfix_main_loaded = 1
let s:cpo_save = &cpo
set cpo&vim

let g:quickfix_dump_enable = 1
let g:quickfix_index_max   = 5000
let s:file_op              = File_get_ops()
let s:worker_op            = Worker_get_ops()

function! Quickfix_ctrl(mode)
    call quickfix#ctrl_main(a:mode)
endfunction

function! Quickfix_csfind(ccmd)
    let csarg = expand('<cword>')
    if a:ccmd == "ff"
        let csarg = expand('<cfile>')
    elseif a:ccmd == "fi"
        let csarg = expand('<cfile>')
    endif

    call LogPrint("2file", "CSFind: ".a:ccmd." ".csarg)
    call ToggleWindow("allclose")

    call quickfix#ctrl_main("save")
    call quickfix#ctrl_main("clear")

    call quickfix#csfind(a:ccmd, csarg)
endfunction

function! Quickfix_grep()
    let csarg = expand('<cword>')
    silent! normal! mX

    call LogPrint("2file", "GrepFind: ".csarg)
    call ToggleWindow("allclose")

    call quickfix#ctrl_main("save")
    call quickfix#ctrl_main("clear")

    call quickfix#grep_find(csarg)
endfunction

function! Quickfix_leave()
    while s:worker_op.has_work("quickfix")
        let works = s:worker_op.get_works("quickfix")
        call LogPrint("2file", "quickfix leave, wait worker [".string(works)."] stop: 10ms")
        silent! execute 'sleep 10m'
    endwhile

    call LogPrint("2file", "quickfix-worker stop: quickfix")
    call s:worker_op.stop("quickfix")
endfunction

"切换下一条quickfix记录
nnoremap <silent> <Leader>ql  :call quickfix#ctrl_main("list")<CR>
nnoremap <silent> <Leader>qf  :call quickfix#ctrl_main("next")<CR>
nnoremap <silent> <Leader>qb  :call quickfix#ctrl_main("prev")<CR>
nnoremap <silent> <Leader>qd  :call quickfix#ctrl_main("delete")<CR>
nnoremap <silent> <Leader>qrc :call quickfix#ctrl_main("recover")<CR>
nnoremap <silent> <Leader>qrf :call quickfix#ctrl_main("recover-next")<CR>
nnoremap <silent> <Leader>qrb :call quickfix#ctrl_main("recover-prev")<CR>

call s:worker_op.start("quickfix", s:file_op.process_req, 20, 3)

" restore 'cpo'
let &cpo = s:cpo_save
unlet s:cpo_save
