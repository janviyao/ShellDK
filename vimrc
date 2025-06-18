""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
"                      Personal Customal VIM IDE
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:my_vim_dir = fnamemodify(resolve(expand('$MYVIMRC')), ":p:h") 

let g:log_dump_dict = 1
let g:log_dump_list = 0

let s:log_enable    = 0
let s:log_file_path = '/tmp/gbl/vim.debug'
let s:log_file_max  = 698351616
let s:log_line_max  = 500
let s:vim_start     = reltime()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 公共函数列表 
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
function! GetElapsedTime()
    let time = reltime(s:vim_start)
    if len(time) == 2
        return str2float(time[0].".". time[1])
    endif
    return 0
endfunction

function! LogEnable()
    let s:log_enable = 1
    if s:worker_op.is_stoped("loger")
        call s:worker_op.start("loger", function("s:loger_worker"), 50000, 10000)
        call s:worker_op.set_log("loger", v:false)
    endif

    if s:worker_op.is_paused("loger")
        call s:worker_op.pause("loger", 0)
    endif
endfunction

function! LogDisable()
    let s:log_enable = 0
    call s:worker_op.stop("loger")
endfunction

function! s:loger_worker(request)
        call LogPrint(a:request.type, a:request.msg)
endfunction

function! LogPrint(type, msg)
    if a:type == "esave"
        echohl ErrorMsg
        echoerr "[".a:type."]: ".a:msg
        echohl None
        call LogPrint("save", a:msg)
    elseif a:type == "error"
        echohl ErrorMsg
        echoerr "[".a:type."]: ".a:msg
        echohl None
        call LogPrint("2file", a:msg)
    elseif a:type == "warn" 
        echohl WarningMsg
        echomsg "[".a:type."]: ".a:msg
        echohl None
        call LogPrint("2file", a:msg)
    elseif a:type == "info"
        echohl ModeMsg
        echomsg "[".a:type."]: ".a:msg
        echohl None
        call LogPrint("2file", a:msg)
    elseif a:type == "2file" 
        if s:log_enable
            let time_str = printf("%.6f", GetElapsedTime())
            let request = {} 
            let request["type"] = "save"
            let request["msg"]  = "[".time_str."] ".a:msg
            if exists('s:worker_op')
                let work_index = s:worker_op.work_alloc("loger")    
                if work_index >= 0
                    call s:worker_op.fill_req("loger", work_index, request)
                else
                    call LogPrint("save", "loger dead: ".request["msg"])
                endif
            else
                call LogPrint("save", "loger none: ".request["msg"])
            endif
        endif
    elseif a:type == "save" 
        call writefile(split(a:msg, "\n", 1), s:log_file_path, 'a')
    else
        echomsg "[!!!]: ".a:msg
    endif
endfunction

function! PrintArgs(type, func, ...)
    if s:log_enable
        let args_str = "function: ".a:func
        call LogPrint(a:type, args_str)
        let args_str = "{"
        call LogPrint(a:type, args_str)

        if a:0 > 0
            let index = 1
            for arg in a:000
                if type(arg) == v:t_dict
                    let args_str = "  arg[".index."]: dict-size=".len(arg)
                    call LogPrint(a:type, args_str)
                    if !empty(arg)
                        call PrintDict(a:type, "", arg, "  ")
                    endif
                elseif type(arg) == v:t_list
                    let args_str = "  arg[".index."]:"
                    call LogPrint(a:type, args_str)
                    if !empty(arg)
                        call PrintList(a:type, "", arg, "  ")
                    endif
                else
                    if strlen(string(arg)) > s:log_line_max 
                        let args_str = "  arg[".index."]: ".strpart(string(arg), 0, s:log_line_max)."......"
                    else
                        let args_str = "  arg[".index."]: ".string(arg)
                    endif
                    call LogPrint(a:type, args_str)
                endif
                let index += 1
            endfor
        endif

        let args_str = "}\n"
        call LogPrint(a:type, args_str)
    endif
endfunction

function! PrintDict(type, explain, dict, prefix="")
    if s:log_enable
        if strlen(a:explain) > 0
            let args_str = a:prefix.a:explain
            call LogPrint(a:type, args_str)
        endif
        let args_str = a:prefix."{"
        call LogPrint(a:type, args_str)

        if g:log_dump_dict
            for [key, value] in items(a:dict)
                if type(value) == v:t_dict
                    if empty(value)
                        let args_str = a:prefix."  [".key."]: {}"
                        call LogPrint(a:type, args_str)
                    else
                        let args_str = a:prefix."  [".key."]:"
                        call LogPrint(a:type, args_str)
                        call PrintDict(a:type, "", value, a:prefix."  ")
                    endif
                elseif type(value) == v:t_list
                    if empty(value)
                        let args_str = a:prefix."  [".key."]: []"
                        call LogPrint(a:type, args_str)
                    else
                        let args_str = a:prefix."  [".key."]:"
                        call LogPrint(a:type, args_str)
                        call PrintList(a:type, "", value, a:prefix."  ")
                    endif
                else
                    if strlen(string(value)) > s:log_line_max 
                        let args_str = a:prefix."  [".key."]: ".strpart(string(value), 0, s:log_line_max)."......"
                    else
                        let args_str = a:prefix."  [".key."]: ".string(value)
                    endif
                    call LogPrint(a:type, args_str)
                endif
            endfor
        else
            let args_str = a:prefix."  dict-size: ".len(a:dict)
            call LogPrint(a:type, args_str)
        endif

        if strlen(a:prefix) > 0
            let args_str = a:prefix."}"
        else
            let args_str = a:prefix."}\n"
        endif
        call LogPrint(a:type, args_str)
    endif
endfunction

function! PrintList(type, explain, list, prefix="")
    if s:log_enable
        if strlen(a:explain) > 0
            let args_str = a:prefix.a:explain
            call LogPrint(a:type, args_str)
        endif
        let args_str = a:prefix."{"
        call LogPrint(a:type, args_str)

        if g:log_dump_list
            let index = 0
            for value in a:list
                if type(value) == v:t_dict
                    if empty(value)
                        let args_str = a:prefix."  [".index."]: {}"
                        call LogPrint(a:type, args_str)
                    else
                        let args_str = a:prefix."  [".index."]:"
                        call LogPrint(a:type, args_str)
                        call PrintDict(a:type, "", value, a:prefix."  ")
                    endif
                elseif type(value) == v:t_list
                    if empty(value)
                        let args_str = a:prefix."  [".index."]: []"
                        call LogPrint(a:type, args_str)
                    else
                        let args_str = a:prefix."  [".index."]:"
                        call LogPrint(a:type, args_str)
                        call PrintList(a:type, "", value, a:prefix."  ")
                    endif
                else
                    if strlen(string(value)) > s:log_line_max
                        let args_str = a:prefix."  [".index."]: ".strpart(string(value), 0, s:log_line_max)."......"
                    else
                        let args_str = a:prefix."  [".index."]: ".string(value)
                    endif
                    call LogPrint(a:type, args_str)
                endif
                let index += 1
            endfor 
        else
            let args_str = a:prefix."  list-size: ".len(a:list)
            call LogPrint(a:type, args_str)
        endif

        if strlen(a:prefix) > 0
            let args_str = a:prefix."}"
        else
            let args_str = a:prefix."}\n"
        endif
        call LogPrint(a:type, args_str)
    endif
endfunction

"获取VIM工作目录
function! GetVimDir(dir)
	let makdir = expand('$HOME/.vimSession/') . substitute(getcwd(), '[:\/]', '@', 'g')

    let gbranch = trim(system("git symbolic-ref --short -q HEAD 2>/dev/null"))
    if strlen(gbranch) > 0
        let gbranch = substitute(gbranch, '[#:\/]', '_', 'g')
        let makdir = makdir."/".gbranch
    endif

	if strlen(a:dir) > 0
		let makdir = makdir."/".a:dir 
	endif

    if !isdirectory(makdir) 
        call mkdir(makdir, "p")
    endif

    return makdir 
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
"一般设定 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"设置语法高亮
syntax enable
syntax on

set background=dark                                        "设为dark时，Vim试图使用深色背景上看起来舒服的颜色
set t_Co=256
colorscheme mine

"set spell                                                 "开启拼写检查功能,开启着色混乱
set number                                                 "显示文件行数
set nocompatible                                           "去掉vi一致性
set nobackup                                               "不要备份文件
set nowritebackup                                          "关闭写备份
set noswapfile                                             "不要生成swap文件，当buffer被丢弃的时候隐藏它
set shortmess=atI                                          "启动的时候不显示那个援助索马里儿童的提示
set autoread                                               "文件修改之后自动载入
set autowrite                                              "自动写入缓冲区
"set paste                                                 "粘贴时保持格式
set magic                                                  "模式匹配时使用，详情查看help

set virtualedit+=block                                     "在可视模式下可以选择一个方块
set clipboard+=unnamed                                     "与windows共享剪贴板 
set backspace=indent,eol,start                             "插入模式下使能 <BackSpace>、<Delete> <C-W> <C-U>
set iskeyword+=$,@,%,#                                     "带有如下符号的单词不要被换行分割
set whichwrap=b,s,<,>,~,[,]                                "允许<BS>和光标键到行首或行尾时自动到上一行或下一行
set history=1024                                           "history文件中需要记录的行数
set confirm                                                "在处理未保存或只读文件的时候，弹出确认
set hidden                                                 "允许在有未保存的修改时切换缓冲区
set wildmenu                                               "命令行TAB自动完成以及备选提示

"set mouse-=a                                              "在所有的模式下面打开鼠标
"set selection=exclusive
"set selectmode=mouse,key

set scrolloff=3                                            "光标上下最少保留屏幕行数
set switchbuf=useopen                                      "显示已打开窗口，快速修复缓冲区，而不是打开新文件
set matchpairs=(:),{:},[:],<:>                             "匹配括号的规则，增加针对html的<>
set completeopt=longest,menu                               "关掉智能补全时的预览窗口

set viminfo=!,%,'100,<100,s100,:100,@100,/100,f1           "viminfo文件保存的信息选项

"自动保存文件
"set updatetime=1000
"autocmd CursorHoldI * silent w

"持久化的undo机制：保存文件修改的撤消/重做
silent! execute 'set undodir='.GetVimDir("undodir")
set undofile
set undolevels=10000 "maximum number of changes that can be undone
set undoreload=10000 "maximum number lines to save for undo on a buffer reload

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 语言、字体设置 
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
set langmenu=zh_CN.UTF-8
set guifont=Courier\ 10\ Pitch\ 12                         "设置字体，字体名称和字号

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 文本格式、排版设置 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""  
set formatoptions=tcrqn                                    "自动格式化
set cindent                                                "使用C样式的缩进，换行自动缩进，是按照shiftwidth值来缩进的
set autoindent                                             "自动缩进
set smartindent                                            "智能缩进
set copyindent                                             "复制之前缩进
set smarttab                                               "在行和段开始处使用制表符
"set expandtab                                             "将新增的tab转换为空格，不会对已有的tab进行转换
set tabstop=4                                              "设置一个tab对应4个空格
set shiftwidth=4                                           "统一缩进为4
set softtabstop=4                                          "在按退格键时，如果前面有4个空格，则会统一清除
set listchars=tab:».,trail:·                               "tab和space使用特殊字符替换: tab:»\ ,space:.,trail:·
"set list                                                  "使能listchars
set nolist                                                 "禁止listchars
set linebreak                                              "换行不截断单词
set nowrap                                                 "不自动换行
set textwidth=180                                          "设置每行的最大字符数，超过将换行
set linespace=2                                            "设置行距
set pastetoggle=<F10>                                      "<F10>打开或关闭高级粘贴模式

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 状态栏设置 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set cursorline                                             "行高亮
"set cursorcolumn                                          "列高亮
"set showcmd                                               "在状态栏显示正在输入的命令
"set cmdheight=1                                           "命令行高度，默认为1

"显示当前的行号列号
set ruler 
"set rulerformat=%20(%2*%<%f%=\ %m%r\ %3l\ %c\ %p%%%) 

"底部状态栏显示：1为关闭，2为开启
set laststatus=2
"set statusline=%F%m%r%h%w%*%=[%{&ff}:%Y]\ [%l:%v]\ [%p%%]\ [%{strftime(\"%Y-%m-%d\ %H:%M\")}]

"可视模式
"highlight CursorLine   cterm=NONE ctermbg=239 ctermfg=NONE
"highlight CursorColumn cterm=NONE ctermbg=239 ctermfg=NONE
"highlight Visual       cterm=NONE ctermbg=241 ctermfg=NONE
"autocmd InsertEnter * highlight CursorLine ctermbg=53  ctermfg=NONE
"autocmd InsertLeave * highlight CursorLine ctermbg=239 ctermfg=NONE

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 编码设置
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set encoding=utf-8
set termencoding=utf-8
set fileencoding=utf-8 
set fileencodings=utf-8,usc-bom,euc-jp,gb18030,gbk,gb2312,cp936

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 文件设置 
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
filetype on                                                "打开文件类型检测功能
filetype plugin on                                         "开启支持文件类型的插件
filetype indent on                                         "启动自动补全
set fileformats=unix,dos,mac                               "自动识别文件格式

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 搜索、匹配、替换
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""  
set showmatch                                              "高亮显示匹配的括号
set nohlsearch                                             "不高亮被搜索的单词
set incsearch                                              "搜索时输入逐字符高亮 
set smartcase                                              "有一个或以上大写字母时仍大小写敏感
"set gdefault                                              "替换时所有的行内匹配都被替换，而不是只有第一个, 但s命令g标记失效，s///gg时重新生效
"set ignorecase                                            "搜索时候忽略大小写

"搜索时要忽略的文件和目录
set wildignore=*.o,*~,*.pyc,*/.repo/*,*/.git/*,*/.svn/*,*.git*,*.svn*,tags,cscope.*

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 代码折叠
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""  
set foldenable                                             "使能折叠
set foldmethod=manual                                      "折叠方法
set foldcolumn=0                                           "在左侧显示折叠的层次
set foldlevel=1                                            "设置折叠层数为

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 标签页
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""  
"标签页只显示文件名
set tabline=%!ShowTabLabel()

"标签样式
highlight TabLineFill term=none ctermfg=DarkGrey
highlight TabLineSel term=inverse cterm=none ctermfg=yellow ctermbg=Black

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 自动命令
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"normal模式下取消输入法
autocmd InsertEnter * set noimdisable
autocmd InsertLeave * set imdisable

"vimrc文件修改之后自动加载
autocmd BufWritePost .vimrc source ~/.vimrc

"bashrc文件修改之后自动加载
autocmd BufWritePost .bashrc source ~/.bashrc

"让vim记忆上次编辑文件的位置
autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | silent! execute "normal! g'\"" | endif

"自动保存和加载VimSeesion和VimInfo
autocmd VimEnter * call EnterHandler()
"autocmd VimLeave * call LeaveHandler(1) 

"恢复命令栏默认高度
autocmd CursorMoved * if exists("g:show_func") 
                      \| unlet! g:show_func 
                      \| set cmdheight=1 
                      \| echo '' 
                      \| endif

"autocmd FileType c,cpp let g:prj_type=c
"autocmd FileType go let g:prj_type=go

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 设置快捷键
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
vnoremap <silent> <C-c> y                                  "复制
nnoremap <silent> <C-c> yiw                                "复制
"noremap  <silent> <C-v> p                                  "粘贴
vnoremap <silent> <C-x> d                                  "剪切
nnoremap <silent> <C-x> diw                                "剪切
nnoremap <silent> <C-a> ggvG$                              "全选

nnoremap <silent> <Leader>sw :w<CR>                        "保存当前窗口修改
nnoremap <silent> <Leader>sa :wa<CR>                       "保存所有窗口修改

nnoremap <silent> <Leader>wv <C-w>v                        "垂直分割当前窗口
nnoremap <silent> <Leader>wh <C-w>s                        "水平分割当前窗口
nnoremap <silent> <C-up> :resize +5<CR>                    "水平分隔窗口调大
nnoremap <silent> <C-down> :resize -5<CR>                  "水平分隔窗口调小
nnoremap <silent> <C-right> :vertical resize+5<CR>         "垂直分隔窗口调大
nnoremap <silent> <C-left> :vertical resize-5<CR>          "垂直分隔窗口调大

nnoremap <silent> <Leader>te  :tabe %<CR>                  "当前窗口拷贝到新标签页
nnoremap <silent> <Leader>tc  :tabc<CR>                    "关闭当前标签窗口
nnoremap <silent> <Leader>tco :tabo<CR>                    "关闭其它所有标签窗口
nnoremap <silent> <Leader>tp  :tabp<CR>                    "当前窗口移到左侧标签页,同gT
nnoremap <silent> <Leader>tn  :tabn<CR>                    "当前窗口移到右侧标签页,同gt

nnoremap <silent> <Leader>ab <C-^>                         "切换最近两个文件,同:next #,:edit #
nnoremap <silent> <Leader>wr <C-w>r                        "旋转当前窗口位置
nnoremap <silent> <Leader>wc <C-w>c                        "关闭当前窗口
nnoremap <silent> <Leader>wd :bd<CR>                       "删除当前缓存窗口
nnoremap <silent> <Leader>ws :b#<CR>                       "切换上次缓存窗口
nnoremap <silent> <Leader>wq :q<CR>                        "退出
nnoremap <silent> <Leader>qq :call LeaveHandler(1)<CR>     "退出VIM

"控制窗口
nnoremap <silent> <Leader>h <C-w>h                         "光标移到左面窗口
nnoremap <silent> <Leader>l <C-w>l                         "光标移到右面窗口
nnoremap <silent> <Leader>j <C-w>j                         "光标移到上面窗口
nnoremap <silent> <Leader>k <C-w>k                         "光标移到下面窗口
nnoremap <silent> <Leader>H <C-w>H                         "当前窗口移到最左面
nnoremap <silent> <Leader>L <C-w>L                         "当前窗口移到最右面
nnoremap <silent> <Leader>J <C-w>J                         "当前窗口移到最上面
nnoremap <silent> <Leader>K <C-w>K                         "当前窗口移到最下面

"搜索光标下单词
nnoremap <silent> <Leader>fw :call SearchLetters("word")<CR>
nnoremap <silent> //         :call SearchLetters("any")<CR>

"快速移动
nnoremap <silent> <C-h> 6h
nnoremap <silent> <C-l> 6l
nnoremap <silent> <C-j> 6j
nnoremap <silent> <C-k> 6k

vnoremap <silent> <C-h> 6h
vnoremap <silent> <C-l> 6l
vnoremap <silent> <C-j> 6j
vnoremap <silent> <C-k> 6k

"替换当前光标下单词为复制寄存器内容
nnoremap <silent> <Leader>p  :call ReplaceWord()<CR>

"搜索光标下单词
nnoremap <silent> <Leader>rg :call QuickfixDo("grep", expand("<cword>"))<CR>

"替换字符串
nnoremap <silent> <Leader>gr :call GlobalReplace()<CR>

"显示当前行所在函数名,等同于df命令
nnoremap <silent> <Leader>sfn :call ShowFuncName()<CR>

"跳转到函数指定位置
nnoremap <silent> <Leader>jfs  :call JumpFunctionPos("jfs")<CR>
nnoremap <silent> <Leader>jfe  :call JumpFunctionPos("jfe")<CR>

"跳转到当前层括号
nnoremap <silent> <Leader>j{  :call JumpBracket("{", "bW")<CR>
nnoremap <silent> <Leader>j}  :call JumpBracket("}", "W")<CR>

"跳转到当前层括号
nnoremap <silent> <Leader>=  :call FormatSelect()<CR>

"格式化当前文件
nnoremap <silent> <Leader>cf :call CodeFormat()<CR>

"清除工程相关文件
nnoremap <silent> <Leader><F11> :call ProjectGo("delete")<CR>

"重新生成工程文件
nnoremap <silent> <Leader><F12> :call ProjectGo("create")<CR>

"窗口切换
nnoremap <silent> <Leader>tl :call ToggleWindow("tl")<CR>  "切换TagsList
nnoremap <silent> <Leader>qo :call ToggleWindow("qo")<CR>  "切换QickFix
nnoremap <silent> <Leader>be :call ToggleWindow("be")<CR>  "切换BufExplorer
nnoremap <silent> <Leader>nt :call ToggleWindow("nt")<CR>  "切换NERDTree

"扩展跳转功能
nnoremap <Leader>tj  :cstag <C-R>=expand("<cword>")<CR>

nmap <silent> <Leader>fs :call QuickfixDo('cs', 'fs')<CR>  "查找符号
nmap <silent> <Leader>fg :call QuickfixDo('cs', 'fg')<CR>  "查找定义
nmap <silent> <Leader>fc :call QuickfixDo('cs', 'fc')<CR>  "查找调用这个函数的函数
nmap <silent> <Leader>fd :call QuickfixDo('cs', 'fd')<CR>  "查找被这个函数调用的函数
nmap <silent> <Leader>ft :call QuickfixDo('cs', 'ft')<CR>  "查找这个字符串
nmap <silent> <Leader>fe :call QuickfixDo('cs', 'fe')<CR>  "查找这个egrep匹配模式
nmap <silent> <Leader>ff :call QuickfixDo('cs', 'ff')<CR>  "查找同名文件
nmap <silent> <Leader>fi :call QuickfixDo('cs', 'fi')<CR>  "查找包含这个文件的文件
nmap <silent> <Leader>ss :cs find s <C-R>=expand("<cword>")<CR>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 函数列表 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"获取输入字符串
function! GetInputStr(prompt, default, type)
    let rowNum = line(".")
    let colNum = col(".")

    if a:type == "dir"
        let cmd = input(a:prompt, a:default, "dir")
    else
        let cmd = input(a:prompt, a:default)
    endif

    call search("\\%" . rowNum . "l" . "\\%" . colNum . "c")
    return cmd
endfunction

"查找光标下单词
function! SearchLetters(type)
    let fargs=expand('<cword>')
    if a:type == "word"
        let fargs="\\<".fargs."\\>"
    endif

    "搜索模式寄存器赋值
    call setreg("/", fargs)
    silent! execute 'normal! n'
endfunction

"获取函数头开始行
function! JumpFuncStart()
    " E872: (NFA regexp) Too many '('
    " use non-capturing groups with the \%(pattern\) syntax
    " when \v, %(pattern) syntax
    let code_word='[a-zA-Z0-9_]+'
    let line_end='%(\r?\n?)?'
    let not_in_bracket='[^\r\n\+\-\!\/\(\)\{\},;]'
    let exclude_char='[^\s\r\n\+\-\!\/\(\)\{\}\:,;]'
    let gcc_attrs='__attribute__.+'

    let func_return='\s*%(^%(\s*'.code_word.'\s*){0,2}'.exclude_char.'$'.line_end.')?\s*'
    let func_name='\s*%(%('.code_word.'%(\s*::'.code_word.')*)|%(operator.+\s*))'

    let fptr_return='\s*%('.code_word.'\s*)+\s*'
    let fptr_name='\s*\(\s*\*\s*'.code_word.'\s*\)\s*'
    let fptr_args='\s*\(%('.not_in_bracket.'+,?)*\)\s*'
    let func_ptr=fptr_return.fptr_name.fptr_args.",?"

    let comm_arg='%('.code_word.'\s*)+%(%(%(\*{1,2})|%(\&))?\s*'.code_word.')\s*%(\[\s*\d*\s*\])?\s*%(\s+'.gcc_attrs.')?,?'
    let func_arg='\s*%(%('.comm_arg.')|%('.func_ptr.'))\s*'

    let func_arglist='\s*\(%(%(\s*void\s*)|%(%('.func_arg.line_end.')*))\)\s*'
    let func_restrict='\s*%(\s*const\s*)?'.line_end
    let func_regex='\v'.func_return.func_name.func_arglist.func_restrict.'\{'
    let excl_regex='\v%(%(if)|%(for)|%(while)|%(switch)|%(catch))\s*\(.*\)'.line_end.'\{?'

    "call LogPrint("2file", "func_return: ".func_return)
    "call LogPrint("2file", "func_name: ".func_name)
    "call LogPrint("2file", "func_ptr: ".func_ptr)
    "call LogPrint("2file", "comm_arg: ".comm_arg)
    "call LogPrint("2file", "func_arg: ".func_arg)
    "call LogPrint("2file", "func_arglist: ".func_arglist)
    "call LogPrint("2file", "func_restrict: ".func_restrict)
    "call LogPrint("2file", "func_regex: ".func_regex)
    "call LogPrint("2file", "excl_regex: ".excl_regex)

    let find_line = search(func_regex, 'bW')
    if find_line == 0
        "call LogPrint("error", "search fail: ".func_regex)
        return 1
    endif

    "call LogPrint("2file", "find0 line: ".find_line)
    let find_str = getline(find_line)
    while find_str == ""
        let find_line = search(func_regex, 'bW')
        if find_line <= 1
            break
        endif

        "call LogPrint("2file", "find1 line: ".find_line)
        let find_str = getline(find_line)
    endwhile

    let match_str = matchstr(find_str, excl_regex)
    "call LogPrint("2file", "find: \'".find_str."\' match: \'".match_str."\'")
    while match_str != ""
        let find_line = search(func_regex, 'bW')
        if find_line <= 1
            break
        endif

        "call LogPrint("2file", "find2 line: ".find_line)
        let find_str = getline(find_line)
        while find_str == ""
            let find_line = search(func_regex, 'bW')
            if find_line <= 1
                break
            endif

            "call LogPrint("2file", "find3 line: ".find_line)
            let find_str = getline(find_line)
        endwhile

        let match_str = matchstr(find_str, excl_regex)
        "call LogPrint("2file", "find: \'".find_str."\' match: \'".match_str."\'")
    endwhile

    let rowNum = line(".")
    let colNum = col(".")

    let find_line=search('\v'.func_return, 'bW')
    "call LogPrint("2file", "return line: ".find_line)

    if getline(find_line) != ""
        return find_line
    endif

    call cursor(rowNum, colNum)
    return rowNum
endfunction

function! JumpBracket(aim, flags)
    let rowNum = line(".")
    let forword = 1
    if stridx(a:flags, "b") >= 0
        let forword = 0
    endif

    while 1
        let cursor = getcurpos()
        "call LogPrint("info", a:aim." ".a:flags." Row: ".string(cursor))
        if forword == 0
            let startLine = search(a:aim, a:flags)
            let cursor = getcurpos()
            "call LogPrint("info", a:aim." ".a:flags." Row: ".string(cursor))

            if startLine > 0
                silent! execute 'normal! ^'
                call search(a:aim, 'c')
                silent! execute 'normal! %'
                let endLine = line(".") 
                call setpos('.', cursor)
            else
                break
            endif
        elseif forword == 1
            let endLine = search(a:aim, a:flags)
            let cursor = getcurpos()
            "call LogPrint("info", a:aim." ".a:flags." Row: ".string(cursor))
            
            if endLine > 0 
                silent! execute 'normal! ^'
                call search(a:aim, 'c')
                silent! execute 'normal! %'
                let startLine = line(".")
                call setpos('.', cursor)
            else
                break
            endif
        endif

        "call LogPrint("info", a:aim." ".a:flags." Start: ".startLine." End: ".endLine." Pos: ".rowNum)
        if rowNum >= startLine && rowNum <= endLine
            if forword == 0
                return startLine
            elseif forword == 1
                return endLine
            endif
        endif
    endwhile

    return 0
endfunction

"状态栏显示当前行所在函数名
function! ShowFuncName()
    let rowNum = line(".")
    let colNum = col(".")

    let headStart = JumpFuncStart()
    silent! execute 'normal! ^'
    call search("{", 'c')

    let headEnd = line(".")
    let headHeight = 0
    let saveStart=headStart
    while headStart <= headEnd  
        let headHeight += 1
        let headStart += 1
    endwhile
    silent! execute 'set cmdheight='.headHeight
    let g:show_func=headHeight

    let headStart = saveStart
    echohl ModeMsg
    while headStart <= headEnd  
        echo getline(headStart)
        let headStart += 1
    endwhile
    echohl None

    call search("\\%" . rowNum . "l" . "\\%" . colNum . "c")
endfunction

"获取函数开始行数与结束行数
function! GetFuncRange()
    let rowNum = line(".")
    let colNum = col(".")

    let funcStart = JumpFuncStart()
    silent! execute 'normal! ^'
    call search("{", 'c')
    silent! execute 'normal! %'
    let funcEnd = line(".")

    call search("\\%" . rowNum . "l" . "\\%" . colNum . "c")
    return funcStart . "," . funcEnd 
endfunction

"格式化代码
function! FormatLanguage()
    let startLine = 0 
    let endLine = 0 
    let rangeStr = GetInputStr("Input Format Range (separated with comma): ", GetFuncRange(), "")
    if strlen(rangeStr) == 0
        let rangeStr="1,$"
    endif

    if stridx(rangeStr, ',') > 0
        let rangeStr = rangeStr . "," 
        let lineNum = strpart(rangeStr, 0, stridx(rangeStr, ','))
        if matchstr(lineNum, '\d\+') != ''
            let startLine = str2nr(lineNum)
        else
            return 
        endif

        let rangeStr = strpart(rangeStr, stridx(rangeStr, ',') + 1)
        let lineNum = strpart(rangeStr, 0, stridx(rangeStr, ','))
        if matchstr(lineNum, '\d\+') != ''
            let endLine = str2nr(lineNum)
        else
            if lineNum == '$'
                let rowCurNum = line(".")
                let colCurNum = col(".")
                silent! execute "normal! G"
                let endLine = line(".")
            else
                return
            endif
        endif
    else
        return
    endif

    let rangeStr = startLine.",".endLine

    "格式化文件
    let as_config = expand('$HOME/').".astylerc"
    silent! execute rangeStr."!astyle --options=".as_config
endfunction

function! FormatSelect()
    let rowNum = line(".")
    let colNum = col(".")

    let startLine = JumpBracket("{", "bW")
    if startLine <= 0
        call cursor(rowNum, colNum)
        return
    endif

    call cursor(rowNum, colNum)
    let endLine = JumpBracket("}", "W")
    if endLine <= 0
        call cursor(rowNum, colNum)
        return
    endif
    call cursor(rowNum, colNum)

    "call LogPrint("info", "Start: ".startLine." End: ".endLine." Pos: ".rowNum)
    silent! execute 'normal! '.startLine.'G'
    silent! execute 'normal! V'
    silent! execute 'normal! '.endLine.'G'
    silent! execute 'normal! ='
    call cursor(rowNum, colNum)
endfunction

"格式化并刷新
function! CodeFormat()
    "保存标签位置，格式化后恢复
    silent! normal! mX

    "去除行结尾字符
    silent! execute '%s/\r//g' 
    "保存当前文件
    silent! execute 'w'
    "重新加载当前文件
    silent! execute 'e' 

    "格式化语言
    call FormatLanguage()
    "保存当前文件
    silent! execute 'w'
    "重新加载当前文件
    silent! execute 'e' 

    "恢复文件行位置
    silent! normal! g`X
    silent! delmarks X
endfunction

"跳转到函数指定位置
function! JumpFunctionPos(pos)
    if a:pos == 'jfs'
        call JumpFuncStart()
        silent! execute 'normal! ^'
    elseif a:pos == 'jfe'
        call JumpFuncStart()
        silent! execute 'normal! ^'
        call search("{", 'c')
        silent! execute 'normal! %'
    endif
endfunction

"替换当前光标下单词为复制寄存器内容
function! ReplaceWord()
    let rowNum = line(".")
    let colNum = col(".")

    let oldStr = expand('<cword>')
    let oldStr = trim(oldStr)
    let lineStr = getline(rowNum)

    let index = stridx(lineStr, oldStr) + 1 
    while (index + strlen(oldStr)) < colNum
        let index = stridx(lineStr, oldStr, index + strlen(oldStr)) + 1
    endwhile

    if index >= 1
        call cursor(rowNum, index)
        silent! execute "normal! ".strlen(oldStr)."x"
        let curCol = col(".")
        if curCol < index
            silent! execute "normal! \"0p"
        else
            silent! execute "normal! \"0P"
        endif
    endif
    
    silent! execute "normal! $"
    let tailCol = col(".") 
    if colNum <= tailCol
        let colNum -= 1
        if colNum <= 0
            silent! execute "normal! ^"
        else
            call cursor(rowNum, colNum)
        endif
    else
        let index -= 1
        if index <= 0
            silent! execute "normal! ^"
        else
            call cursor(rowNum, index)
        endif
    endif
endfunction

"全局替换
function! GlobalReplace()
    let rowNum = line(".")
    let colNum = col(".")

    let oldStr = GetInputStr("Input Old String: ", expand('<cword>'), "")
    if strlen(oldStr) == 0
        return
    endif

    let newStr = GetInputStr("Input New String: ", "", "")

    let separatorStr = GetInputStr("Input Expression Separator: ", "/", "")
    if strlen(separatorStr) == 0
        return
    endif

    let startLine = 0 
    let endLine = 0 
    let rangeStr = GetInputStr("Input Replace Range (separated with comma): ", GetFuncRange(), "")
    if strlen(rangeStr) == 0
        let rangeStr="1,$"
    endif

    if stridx(rangeStr, ',') > 0
        let rangeStr = rangeStr . "," 
        let lineNum = strpart(rangeStr, 0, stridx(rangeStr, ','))
        if matchstr(lineNum, '\v\d+') != ''
            let startLine = str2nr(lineNum)
        else
            return 
        endif

        let rangeStr = strpart(rangeStr, stridx(rangeStr, ',') + 1)
        let lineNum = strpart(rangeStr, 0, stridx(rangeStr, ','))
        if matchstr(lineNum, '\v\d+') != ''
            let endLine = str2nr(lineNum)
        else
            if lineNum == '$'
                let rowCurNum = line(".")
                let colCurNum = col(".")
                silent! execute "normal! G"
                let endLine = line(".")
                call search("\\%" . rowCurNum . "l" . "\\%" . colCurNum . "c")
            else
                return
            endif
        endif
    else
        return
    endif

    let wholeWordStr = GetInputStr("Match Whole Word(y/n): ", "y", "")
    if strlen(wholeWordStr) == 0
        return
    endif

    let confirmStr = GetInputStr("Confirm Before Replace(y/n): ", "n", "")
    if strlen(confirmStr) == 0
        return
    endif

    if startLine != 0 && endLine != 0 
        while startLine <= endLine  
            call cursor(startLine, 1)
            if confirmStr == "y" || confirmStr == "Y" 
                if wholeWordStr == "y" || wholeWordStr == "Y"
                    if matchstr(getline(startLine), "\\<".oldStr."\\>") != '' 
                        execute "s".separatorStr."\\<".oldStr."\\>".separatorStr.newStr.separatorStr."gec"
                    endif
                elseif wholeWordStr == "n" || wholeWordStr == "N"
                    if matchstr(getline(startLine), "\\v([\s\S]{-})".oldStr."([\s\S]{-})") != ''
                        execute "s".separatorStr."\\v([\s\S]{-})".oldStr."([\s\S]{-})".separatorStr."\\1".newStr."\\2".separatorStr."gec"
                    endif
                endif
            elseif confirmStr == "n" || confirmStr == "N"
                if wholeWordStr == "y" || wholeWordStr == "Y"
                    if matchstr(getline(startLine), "\\<".oldStr."\\>") != '' 
                        silent! execute "s".separatorStr."\\<".oldStr."\\>".separatorStr.newStr.separatorStr."ge"
                    endif
                elseif wholeWordStr == "n" || wholeWordStr == "N"
                    if matchstr(getline(startLine), "\\v([\s\S]{-})".oldStr."([\s\S]{-})") != '' 
                        silent! execute "s".separatorStr."\\v([\s\S]{-})".oldStr."([\s\S]{-})".separatorStr."\\1".newStr."\\2".separatorStr."ge"
                    endif
                endif
            endif     

            let startLine = startLine + 1
        endwhile
    else
        return
    endif

    "恢复文件行列位置
    call search("\\%" . rowNum . "l" . "\\%" . colNum . "c")
    silent! normal! M
endfunction

"恢复加载
function! RestoreLoad()
    if !exists("autocommands_loaded")
        "防止多次加载                                                                                            
        let autocommands_loaded = 1

        call Quickfix_ctrl("load")

        let bufnr = bufnr('%')
        let filename = bufname(bufnr)
        call LogPrint("2file", "RestoreLoad bufnr: ".bufnr." file: ".filename)
        silent! execute 'e '.filename
    endif
endfunction

"关闭BufExplorer
function! CloseBufExp()
    let benr = bufnr("BufExplorer")
    if bufname(benr) == "[BufExplorer]"
        silent! execute 'bwipeout! '.benr
    endif
    "silent! execute "ToggleBufExplorer"
endfunction

"窗口控制
function! ToggleWindow(ccmd)
    if a:ccmd == "nt"
        silent! execute 'TagbarClose'
        call Quickfix_ctrl("close") 
        call CloseBufExp()
        
        silent! execute 'NERDTreeToggle' 
    elseif a:ccmd == "tl"
        silent! execute 'NERDTreeClose'
        call Quickfix_ctrl("close") 
        call CloseBufExp()

        let benr = bufnr("[BufExplorer]")
        if bufname(benr) == "[BufExplorer]"
            silent! execute 'bw! '.benr
        endif

        silent! execute "TagbarToggle"
    elseif a:ccmd == "be"
        silent! execute 'TagbarClose'
        silent! execute 'NERDTreeClose'
        call Quickfix_ctrl("close") 

        silent! execute "BufExplorer"
    elseif a:ccmd == "qo"
        silent! execute 'TagbarClose'
        silent! execute 'NERDTreeClose'
        call CloseBufExp()
        
        call Quickfix_ctrl("toggle")
    elseif a:ccmd == "allclose"
        silent! execute 'TagbarClose'
        silent! execute 'NERDTreeClose'
        silent! execute 'SrcExplClose'
        silent! execute 'CtrlSFClose'
        call Quickfix_ctrl("close") 
        call CloseBufExp()
    endif
endfunction

function! QuickfixDo(opmode, arg="")
    call LogPrint("2file", "QuickfixDo ".a:opmode." ".a:arg)

    if a:opmode == "cs"
        call Quickfix_csfind(a:arg)
    elseif a:opmode == "grep" 
        call Quickfix_grep(a:arg)
    endif
endfunction

"工程控制
function! ProjectGo(opmode) 
    call LogPrint("2file", "ProjectGo ".a:opmode)

    if a:opmode == "create"
        silent! execute "!bash ".g:my_vim_dir."/vimrc.sh -m create -p \"".getcwd()."\" -o ".GetVimDir("database")
        call LeaveHandler(1)
    elseif a:opmode == "delete" 
        call LeaveHandler(0)
        silent! execute "!bash ".g:my_vim_dir."/vimrc.sh -m delete -o ".GetVimDir("")
		silent! execute "qa"
    elseif a:opmode == "load" 
		silent! execute "!bash ".g:my_vim_dir."/vimrc.sh -m load -o ".GetVimDir("database")

        if has("ctags")
            if filereadable("tags")
                set tags=tags;                             "结尾分号能够向父目录查找tags文件
                set autochdir                              "自动切换工作目录
            endif
        endif

        if has("cscope")
            set cscopeverbose                              "show msg when any other cscope db added
            set cscopequickfix=s-,c-,d-,i-,t-,e-           "设定是否使用quickfix窗口显示cscope结果
            set csprg=/usr/bin/cscope                      "制定cscope命令
            ":tj, :ts, only search tags 
            "effect <C-L>, :cstag, :tag, g], search both cscope.* and tags 
            set cscopetag                                  "use both cscope and ctag for 'ctrl-]', ':ta', and 'vim -t'
            set cscopetagorder=0                           "cscope database(s) are searched first, followed by tag file(s) if cscope did not return any matches

            set nocsverb
            if filereadable("cscope.out")
                silent! execute "cs add cscope.out ./"
            endif
            set csverb       
        endif

		if filereadable(GetVimDir("session")."/session.vim")
			silent! execute "source ".GetVimDir("session")."/session.vim"
		endif

		if filereadable(GetVimDir("session")."/session.vim")
			silent! execute "rviminfo ".GetVimDir("session")."/session.viminfo"
		endif

		if len(v:argv) > 1
			if filereadable(v:argv[1])
				silent! execute "edit ".v:argv[1]
			endif
		endif
	elseif a:opmode == "unload" 
		silent! execute "mks! ".GetVimDir("session")."/session.vim"
		silent! execute "wviminfo! ".GetVimDir("session")."/session.viminfo"
		silent! execute "!bash ".g:my_vim_dir."/vimrc.sh -m unload -o ".GetVimDir("database")
    endif
endfunction

"VIM进入事件
function! EnterHandler()
    let s:worker_op = Worker_get_ops()
    if s:log_enable
        call s:worker_op.start("loger", function("s:loger_worker"), 50000, 10000)
        call s:worker_op.set_log("loger", v:false)
    endif
 
	call ProjectGo("load")
	call RestoreLoad()
    "silent! normal! M
endfunction

"VIM退出事件
function! LeaveHandler(exit)
    if filereadable("tags") && filereadable("cscope.out") 
        call ToggleWindow("allclose")
        call Quickfix_ctrl("save")    
    endif

	call ProjectGo("unload")
    call Quickfix_leave()

    call LogDisable()
    if getfsize(s:log_file_path) > s:log_file_max 
        call delete(s:log_file_path)
    endif
	
	if a:exit == 1
		silent! execute "qa"
	endif
endfunction

"显示标签名
function! ShowTabLabel()
    let s = ''
    for i in range(tabpagenr('$'))
        "选择高亮
        if i + 1 == tabpagenr()
            let s .= '%#TabLineSel#'
        else
            let s .= '%#TabLine#'
        endif

        "设置标签页号 (用于鼠标点击)
        let s .= '%' . (i + 1) . 'T'
        "FullTabLabel()  提供完整路径标签 
        "ShortTabLabel() 提供文件名标签
        let s .= ' %{ShortTabLabel(' . (i + 1) . ')} '
    endfor

    "最后一个标签页之后用 TabLineFill 填充并复位标签页号
    let s .= '%#TabLineFill#%T'

    "右对齐用于关闭当前标签页的标签
    if tabpagenr('$') > 1
        let s .= '%=%#TabLine#%999Xclose'
    endif

    return s
endfunction

"文件名标签
function! ShortTabLabel(n)
    let buflist = tabpagebuflist(a:n)
    let label = bufname (buflist[tabpagewinnr (a:n) -1])
    let filename = fnamemodify (label, ':t')

    return filename
endfunction

"完整路径标签
function! FullTabLabel(n)
    let buflist = tabpagebuflist(a:n) 
    let winnr = tabpagewinnr(a:n)

    return bufname(buflist[winnr - 1])
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 开始插件管理
" 可以通过以下四种方式指定插件的来源
" a) 指定Github中vim-scripts仓库中的插件，直接指定插件名称即可，插件明中的空格使用“-”代替，如：Bundle 'L9'
" b) 指定Github中其他用户仓库的插件，使用“用户名/插件名称”的方式指定，如：Bundle 'tpope/vim-fugitive'
" c) 指定非Github的Git仓库的插件，需要使用git地址，如：Bundle 'git://git.wincent.com/command-t.git'
" d) 指定本地Git仓库中的插件，如：Bundle 'file:///Users/gmarik/path/to/plugin'
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
filetype off
set runtimepath+=~/.vim/bundle/vundle
silent! execute "set runtimepath+=".g:my_vim_dir."/plugins/common"
silent! execute "set runtimepath+=".g:my_vim_dir."/plugins/quickfix"
call vundle#rc()
Bundle "gmarik/vundle"                                     

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 支持GO语言
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Bundle 'fatih/vim-go'
"let g:go_fmt_command = "goimports"                         "格式化将默认的 gofmt 替换
"let g:go_autodetect_gopath = 1
"let g:go_list_type = "quickfix"
"let g:go_version_warning = 1
"let g:go_highlight_types = 1
"let g:go_highlight_fields = 1
"let g:go_highlight_functions = 1
"let g:go_highlight_function_calls = 1
"let g:go_highlight_operators = 1
"let g:go_highlight_extra_types = 1
"let g:go_highlight_methods = 1
"let g:go_highlight_generate_tags = 1
"let g:godef_split=2

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 设置PowerLine插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle 'Lokaltog/vim-powerline'

let g:Powline_symbols = 'fancy'                            "使用的符号集
let g:Powerline_theme = 'default'                          "使用的默认主题
let g:Powerline_colorscheme = 'default'                    "使用的颜色模式

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 文件缓存列表 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "jlanzarotta/bufexplorer"

let g:bufExplorerDisableDefaultKeyMapping = 1              "不使能默认快捷键
let g:bufExplorerDefaultHelp = 0                           "不显示默认帮忙信息
let g:bufExplorerDetailedHelp = 0                          "显示详细帮助信息
let g:bufExplorerFindActive = 1                            "选择buffer后返回到激活窗口
let g:bufExplorerShowTabBuffer = 0                         "不显示TabBuffer
let g:bufExplorerShowNoName = 0                            "不显示无名buffer
let g:bufExplorerShowUnlisted = 0                          "不显示无列表buffer
let g:bufExplorerShowDirectories = 1                       "在列表中是否显示目录
let g:bufExplorerShowRelativePath = 1                      "显示目录相对路径
"let g:bufExplorerSplitRight = 0                           "垂直拆分窗口显示在左边.
"let g:bufExplorerSplitVertSize = 0                        "垂直拆分窗口宽度，0代表VIM决定大小
"let g:bufExplorerSplitBelow = 1                           "水平拆分窗口在当前窗口上面显示
"let g:bufExplorerSplitHorzSize = 0                        "水平拆分窗口高度，0代表VIM决定大小

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 标签 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "name5566/vim-bookmark"

"关闭后保存书签，目录路径要存在，否则失败
let g:vbookmark_bookmarkSaveFile = GetVimDir("bookmark")."/save.vbm" 

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 关键字搜索 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "janviyao/grep"

let Grep_Default_Filelist = '*'                                           "查找文件类型
let Grep_Skip_Dirs = 'RCS CVS SCCS .repo .git .svn build'                 "不匹配指定目录
let Grep_Skip_Files = '*.o *.d *.bak *~ .git* tags cscope.* vim.debug'    "不匹配指定文件
let Grep_OpenQuickfixWindow = 0                                           "默认不自动打开quickfix, 完成格式化打开
if has('win32unix')
let Grep_Xargs_Path = 'env -i '.trim(system('which xargs'))               "xargs传递大量环境变量会导致出错
let Grep_Path = trim(system('which grep'))                                "清空环境变量后指定全路径
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 快速搜索 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"install tools/the_silver_searcher-2.2.0.tar.gz
if executable('ag')
    let g:ackprg = 'ag --vimgrep'
endif
Bundle "mileszs/ack.vim"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 文件资源管理 插件
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
Bundle "scrooloose/nerdtree"

let NERDTreeChDirMode = 0                                  "0当前目录从不改变
let NERDTreeQuitOnOpen = 1                                 "打开文件时关闭树
let NERDTreeWinPos = 'right'                               "窗口位置
let NERDTreeWinSize = 50                                   "窗口大小
let NERDTreeMinimalUI = 1                                  "不显示帮助面板
let NERDTreeDirArrows = 1                                  "目录箭头 1显示箭头 0传统+-|号
let NERDChristmasTree = 1                                  "以圣诞树样式显示，多姿多彩
let NERDTreeAutoCenter = 1                                 "光标居中显示
let NERDTreeShowHidden = 0                                 "不显示隐藏文件
"忽略指定文件
let NERDTreeIgnore = ['\.vim$', '\~$', 'cscope\.*', 'tags[[file]]', '\.git*', '\.repo$[[dir]]'] 

"在NERDTree上显示Git状态
Bundle "Xuyuanp/nerdtree-git-plugin"
let g:NERDTreeGitStatusIndicatorMapCustom = {
            \ "Modified"  : "✹",
            \ "Staged"    : "✚",
            \ "Untracked" : "✭",
            \ "Renamed"   : "➜",
            \ "Unmerged"  : "═",
            \ "Deleted"   : "✖",
            \ "Dirty"     : "✗",
            \ "Clean"     : "✔︎",
            \ 'Ignored'   : '☒',
            \ "Unknown"   : "?"
            \ }

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 模糊查找文件 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "kien/ctrlp.vim"

let g:ctrlp_cache_dir = GetVimDir("ctrlpcache")            "设置存储缓存文件的目录
let g:ctrlp_root_markers = ['tags', 'cscope.out']          "设置自定义的根目录标记作为默认标记
let g:ctrlp_use_caching = 1                                "启用/禁用每个会话的缓存
let g:ctrlp_clear_cache_on_exit = 0                        "通过退出Vim时不删除缓存文件来启用跨回话的缓存
let g:ctrlp_max_files = 0                                  "扫描文件的最大数量，设置为0时不进行限制
let g:ctrlp_max_depth = 50                                 "目录树递归的最大层数
let g:ctrlp_mruf_max = 250                                 "指定最近打开的文件历史的数目
let g:ctrlp_lazy_update = 300                              "即时搜索延迟时间ms
let g:ctrlp_match_window_bottom = 1                        "匹配窗口位置
let g:ctrlp_max_height = 15                                "匹配窗口高度
let g:ctrlp_match_window_reversed = 0                      "匹配窗口列表顺序from top to bottom
let g:ctrlp_open_multiple_files = 'i'                      "<c-o>以隐藏方式打开所有窗口
let g:ctrlp_open_new_file = 't'                            "<c-y>新建文件时在新的标签页打开
let g:ctrlp_map = '<C-p>'
let g:ctrlp_cmd = 'CtrlPMixed'
let g:ctrlp_custom_ignore = {'dir': '\v[\/]\.(git|repo|svn)$', 'file': '\v(\.exe|\.out|tags)$'}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 TAG列表显示 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "majutsushi/tagbar"

let g:tagbar_left = 1                                       "窗口放置左侧
let g:tagbar_width = 50                                     "窗口的宽度
let g:tagbar_zoomwidth = 0                                  "窗口放大时，显示的最大宽度：0：最大tag宽度，1：能得到的最大宽度，>1：实际宽度值
let g:tagbar_autoclose = 1                                  "跳转到tag时，自动关闭窗口
let g:tagbar_autofocus = 1                                  "窗口打开时，光标自动移动到窗口内
let g:tagbar_sort = 0                                       "按文件顺序显示tag
let g:tagbar_compact = 1                                    "不显示顶部的简短帮忙信息
let g:tagbar_indent = 2                                     "每级缩进空格数
let g:tagbar_show_visibility = 1                            "显示可见符号，例如c++的public、private、protected等
let g:tagbar_show_linenumbers = 0                           "显示行数，0：不显示行数，1：显示绝对行数，2：显示相对行数，-1：使用全局行数设置
let g:tagbar_hide_nonpublic = 0                             "显示非public标识符
let g:tagbar_singleclick = 0                                "关闭单击跳转
let g:tagbar_autoshowtag = 1                                "自动打开关闭状态的折叠
let g:tagbar_autopreview = 0                                "在预览窗口自动显示光标下的tag
let g:tagbar_iconchars = ['▸', '▾']                         "折叠ICON

"Bundle 'taglist.vim'
"let Tlist_Sort_Type = "order"                              "两种排序方式：name,order
"let Tlist_Auto_Highlight_Tag = 1                           "自动高亮标签
"let Tlist_Auto_Update = 1                                  "修改文件自动更新标签
"let Tlist_Close_On_Select = 1                              "选择tag后关闭taglist窗口
"let Tlist_Compact_Format = 1                               "移除不同标签间空行
"let Tlist_Display_Prototype = 0                            "不显示标签或原型
"let Tlist_Enable_Fold_Column = 1                           "显示折叠
"let Tlist_File_Fold_Auto_Close = 1                         "显示当前文件tag，其它文件的tag都被折叠起来
"let Tlist_GainFocus_On_ToggleOpen = 1                      "打开taglist，切换焦点到taglist窗口
"let Tlist_Inc_Winwidth = 1                                 "自动调整taglist窗口宽度
"let Tlist_Process_File_Always = 1                          "taglist窗口关闭时继续解析
"let Tlist_Use_SingleClick = 1                              "支持单击tag跳转，缺省双击
"let Tlist_Show_One_File = 1                                "只显示当前文件tag
"let Tlist_Use_Horiz_Window = 0                             "垂直分隔窗口
"let Tlist_Use_Right_Window = 0                             "窗口显示在左侧
"let Tlist_WinWidth = 50                                    "垂直分隔时窗口宽度
"let Tlist_WinHeight = 20                                   "水平分隔时窗口高度

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 C文件与H文件相互转化 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "vim-scripts/a.vim"

"switches to the header file corresponding to the current file being edited
nnoremap <silent> <Leader>aa  :A<CR>
"cycles through matches
nnoremap <silent> <Leader>an  :AN<CR> 
"new tab and switches
nnoremap <silent> <Leader>at  :AT<CR>
"switches to file under cursor
nnoremap <silent> <Leader>af  :IH<CR>
"cycles through matches
nnoremap <silent> <Leader>afn :IHN<CR>
"new tab and switches
nnoremap <silent> <Leader>aft :IHT<CR>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 自动补全 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Bundle 'Valloric/YouCompleteMe'

"跳转到定义处
"nnoremap <Leader>jd :YcmCompleter GoToDefinitionElseDeclaration<CR>

"let g:ycm_global_ycm_extra_conf='~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'
"let g:ycm_confirm_extra_conf=0                             "不显示开启vim时检查ycm_extra_conf文件的信息
"let g:ycm_collect_identifiers_from_tags_files=1            "开启基于tag的补全，可以在这之后添加需要的标签路径
"let g:ycm_min_num_of_chars_for_completion=1                "输入第1个字符开始补全
"let g:ycm_cache_omnifunc=0                                 "禁止缓存匹配项,每次都重新生成匹配项
"let g:ycm_seed_identifiers_with_syntax=1                   "开启语义补全
"let g:ycm_complete_in_comments=1                           "在注释输入中也能补全
"let g:ycm_complete_in_strings=1                            "在字符串输入中也能补全
"let g:ycm_use_ultisnips_completer=1                        "允许使用UltiSnip插件的自动补全结果
"let g:ycm_autoclose_preview_window_after_insertion=1       "离开插入模式，自动关闭窗口
"let g:ycm_enable_diagnostic_signs = 0                      "语法告警以及错误标签指示使能
"let g:ycm_enable_diagnostic_highlighting = 1               "语法告警以及错误高亮使能
"let g:ycm_echo_current_diagnostic = 1                      "语法告警以及错误提示
"let g:ycm_key_list_select_completion=['<c-n>', '<Down>']   "按键选中当前项
"let g:ycm_key_list_previous_completion=['<c-p>', '<Up>']   "向前选择
"let g:ycm_key_invoke_completion='<C-Space>'                "激活自动补全

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 快速移动 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "easymotion/vim-easymotion"

map e <Plug>(easymotion-prefix)
let g:EasyMotion_use_upper = 1                              "使能标签以大写显示，增加可读性
let g:EasyMotion_keys = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ;'       "显示标签内容
let g:EasyMotion_enter_jump_first = 1                       "回车跳到第一个匹配项
let g:EasyMotion_space_jump_first = 1                       "空格跳到第一个匹配项


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 撤销重做 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "sjl/gundo.vim"

nnoremap <silent> <Leader>ud :silent! GundoToggle<CR>
let g:gundo_width = 60                                     "设置窗口宽度
let g:gundo_preview_height = 20                            "设置预览窗口高度
let g:gundo_right = 0                                      "设置窗口在左侧
let g:gundo_help = 0                                       "不显示帮忙信息
let g:gundo_close_on_revert = 1                            "恢复之后自动关闭窗口

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 自动补全 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if has('patch-8.2.0662') || has('nvim-0.5')
    Bundle 'Shougo/ddc.vim'
    Bundle 'vim-denops/denops.vim'
    let g:denops_disable_version_check = 1                 "denops与vim版本不兼容时不报错

    " Install your sources
    Bundle 'Shougo/ddc-around'

    " Install your filters
    Bundle 'Shougo/ddc-matcher_head'
    Bundle 'Shougo/ddc-sorter_rank'

    " Customize global settings
    " Use around source.
    " https://github.com/Shougo/ddc-around
    call ddc#custom#patch_global('sources', ['around'])

    " Use matcher_head and sorter_rank.
    " https://github.com/Shougo/ddc-matcher_head
    " https://github.com/Shougo/ddc-sorter_rank
    call ddc#custom#patch_global('sourceOptions', {
                \ '_': {
                \   'matchers': ['matcher_head'],
                \   'sorters': ['sorter_rank']},
                \ })

    " Change source options
    call ddc#custom#patch_global('sourceOptions', { 'around': {'mark': 'A'}, })

    call ddc#custom#patch_global('sourceParams', { 'around': {'maxSize': 500}, })

    " Customize settings on a filetype
    call ddc#custom#patch_filetype(['c', 'cpp'], 'sources', ['around', 'clangd'])
    call ddc#custom#patch_filetype(['c', 'cpp'], 'sourceOptions', { 'clangd': {'mark': 'C'}, })
    call ddc#custom#patch_filetype('markdown', 'sourceParams', { 'around': {'maxSize': 100}, })

    " Mappings
    " <TAB>: completion.
    inoremap <silent><expr> <TAB> pumvisible() ? '<C-n>' : (col('.') <= 1 <Bar><Bar> getline('.')[col('.') - 2] =~# '\s') ? '<TAB>' : ddc#map#manual_complete()

    " <S-TAB>: completion back.
    inoremap <expr><S-TAB>  pumvisible() ? '<C-p>' : '<C-h>'

    " Use ddc.
    call ddc#enable()
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 自动补全符号 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "Raimondi/delimitMate"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 代码片段 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Bundle "SirVer/ultisnips"
Bundle "honza/vim-snippets"

let g:UltiSnipsExpandTrigger="<C-y>"
let g:UltiSnipsJumpForwardTrigger="<C-j>"
let g:UltiSnipsJumpBackwardTrigger="<C-k>"
let g:UltiSnipsSnippetDirectories=["UltiSnips", "MySnippets"]
let g:UltiSnipsNoPythonWarning = 0

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 代码预览 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "wesleyche/SrcExpl"

nnoremap <silent> <Leader>se :SrcExplToggle<CR>
let g:SrcExpl_winHeight = 10                               "代码预览窗口的高度
let g:SrcExpl_refreshTime = 100                            "代码预览窗口刷新时间ms
let g:SrcExpl_jumpKey = "<ENTER>"                          "在代码预览窗口内，回车跳转
let g:SrcExpl_gobackKey = "<SPACE>"                        "空格返回跳转前光标位置
let g:SrcExpl_prevDefKey = "<Leader>sp"                    "在代码预览窗口内，查看下一预览
let g:SrcExpl_nextDefKey = "<Leader>sn"                    "在代码预览窗口内，查看上一预览
let g:SrcExpl_searchLocalDef = 1                           "允许搜索本地标识符
let g:SrcExpl_isUpdateTags = 0                             "不允许更新tags文件

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 全局查找和替换 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "dyng/ctrlsf.vim"

let g:ctrlsf_auto_close = 1                                "选中文件后自动关闭预览窗口
let g:ctrlsf_regex_pattern = 1                             "默认以正则表达式搜索
let g:ctrlsf_indent = 2                                    "在原文本缩进基础上增加缩进后显示
let g:ctrlsf_winsize = '50%'                               "搜索结果显示窗口大小
let g:ctrlsf_case_sensitive = 'yes'                        "搜索大小写敏感
let g:ctrlsf_context = '-B 5 -A 3'                         "匹配行前后上下文显示行数配置
let g:ctrlsf_position = 'left'                             "结果窗口显示位置
let g:ctrlsf_selected_line_hl = 'op'                       "在预览窗口和目标文件同时高亮行
if executable('ag')
    let g:ctrlsf_ackprg = 'ag'                             "指定后端搜索工具
else
    let g:ctrlsf_ackprg = 'ack-grep'                       "指定后端搜索工具
endif
let g:ctrlsf_ignore_dir = ['.git', '.repo', '.svn']

nmap     <C-F>f <Plug>CtrlSFPrompt
vmap     <C-F>f <Plug>CtrlSFVwordPath
vmap     <C-F>F <Plug>CtrlSFVwordExec
nmap     <C-F>n <Plug>CtrlSFCwordPath
nmap     <C-F>p <Plug>CtrlSFPwordPath
nnoremap <C-F>o :CtrlSFOpen<CR>
nnoremap <C-F>t :CtrlSFToggle<CR>
inoremap <C-F>t <Esc>:CtrlSFToggle<CR>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 NerdCommenter自动注释 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "scrooloose/nerdcommenter"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 关键字高亮显示 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "mbriggs/mark.vim"
let g:mwAutoLoadMarks = 1                                  "自动加载高亮
let g:mwAutoSaveMarks = 1                                  "自动保存高亮

highlight def MarkWord7  ctermbg=Brown    ctermfg=Black  guibg=Brown      guifg=Black
highlight def MarkWord8  ctermbg=White    ctermfg=Black  guibg=White      guifg=Black
highlight def MarkWord9  ctermbg=DarkRed  ctermfg=Black  guibg=DarkRed    guifg=Black

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 自动保存文档 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "907th/vim-auto-save"
let g:auto_save = 1                                        "使能自动保存

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 单词或行自动包围 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "tpope/vim-surround"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 Git命令封装 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "tpope/vim-fugitive"

"动态显示Git状态
Bundle "airblade/vim-gitgutter"

"定义每行处理接口
function! GlobalChangedLines(ex_cmd)
    for hunk in GitGutterGetHunks()
        for lnum in range(hunk[2], hunk[2]+hunk[3]-1)
            let cursor = getcurpos()
            silent! execute lnum.a:ex_cmd
            call setpos('.', cursor)
        endfor
    endfor
endfunction
command -nargs=1 Glines call GlobalChangedLines(<q-args>)
"示例 :Glines s/\s\+$//                                    "清除行尾空格

"循环跳转
function! GitGutterNextHunkCycle()
    let linenr = line('.')
    silent! GitGutterNextHunk
    if line('.') == linenr 
        normal! gg
        GitGutterNextHunk
    endif
endfunction

function! GitGutterPrevHunkCycle()
    let linenr = line('.')
    silent! GitGutterPrevHunk 
    if line('.') == linenr 
        normal! G
        GitGutterPrevHunk 
    endif
endfunction

function! GitGutterNextHunkAllBuffers()
    let linenr = line('.')
    GitGutterNextHunk
    if line('.') != linenr 
        return
    endif

    let bufnr = bufnr('')
    while 1
        bnext
        if bufnr('') == bufnr
            return
        endif
        if !empty(GitGutterGetHunks())
            normal! gg
            GitGutterNextHunk
            return
        endif
    endwhile
endfunction

function! GitGutterPrevHunkAllBuffers()
    let linenr = line('.')
    GitGutterPrevHunk
    if line('.') != linenr 
        return
    endif

    let bufnr = bufnr('')
    while 1
        bprevious
        if bufnr('') == bufnr
            return
        endif
        if !empty(GitGutterGetHunks())
            normal! G
            GitGutterPrevHunk
            return
        endif
    endwhile
endfunction

nmap <silent> <Leader>gf  :call GitGutterNextHunkCycle()<CR>
nmap <silent> <Leader>gb  :call GitGutterPrevHunkCycle()<CR>
nmap <silent> <Leader>gaf :call GitGutterNextHunkAllBuffers()<CR>
nmap <silent> <Leader>gab :call GitGutterPrevHunkAllBuffers()<CR>
nmap <silent> <Leader>gg  :GitGutterToggle<CR>

"执行写操作时更新签名列
autocmd BufWritePost * GitGutter
highlight GitGutterAdd    guifg=#009900 ctermfg=2
highlight GitGutterChange guifg=#bbbb00 ctermfg=3
highlight GitGutterDelete guifg=#ff2222 ctermfg=1

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 多光标选择 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "terryma/vim-multiple-cursors"

let g:multi_cursor_use_default_mapping = 0
let g:multi_cursor_start_word_key      = '<C-n>'	       "选中一个
let g:multi_cursor_select_all_word_key = '<A-n>'	       "全选匹配的字符
let g:multi_cursor_start_key           = 'g<C-n>'
let g:multi_cursor_select_all_key      = 'g<A-n>'
let g:multi_cursor_next_key            = '<C-n>'
let g:multi_cursor_prev_key            = '<C-p>'	       "回到上一个
let g:multi_cursor_skip_key            = '<C-x>'	       "跳过当前选中, 选中下一个
let g:multi_cursor_quit_key            = '<Esc>'	       "退出

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 选择区域增加或缩小 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "Yggdroot/indentLine"
let g:indentLine_enabled = 0
let g:indentLine_setColors = 1
let g:indentLine_color_term = 0
let g:indentLine_bgcolor_term = 220
let g:indentLine_char_list = ['|', '¦', '┆', '┊']

nnoremap <silent> <Leader>il :IndentLinesToggle<CR>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 选择区域增加或缩小 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "terryma/vim-expand-region"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 扩展％匹功能 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "vim-scripts/matchit.zip"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 文本对齐 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "godlygeek/tabular"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 :XtermColorTable颜色表 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "guns/xterm-color-table.vim"

"开启插件
filetype plugin indent on
