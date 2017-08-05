""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
"                      Personal Customal VIM IDE
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 公共函数列表 
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
"获取VIM工作目录
function! GetVimDir(work, dir)
    let makdir = expand('$HOME/.vimSession/')
    if strlen(a:dir) == 0
        let makdir = makdir . substitute(getcwd(), '[:\/]', '-', 'g')
    else
        if a:work == 1
            let makdir = makdir . a:dir . "/" . substitute(getcwd(), '[:\/]', '-', 'g')
        else
            let makdir = makdir . a:dir 
        endif
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

"set mouse-=a                                               "在所有的模式下面打开鼠标
"set selection=exclusive
"set selectmode=mouse,key

set scrolloff=10                                           "光标上下最少保留屏幕行数
set switchbuf=useopen                                      "显示已打开窗口，快速修复缓冲区，而不是打开新文件
set matchpairs=(:),{:},[:],<:>                             "匹配括号的规则，增加针对html的<>
set completeopt=longest,menu                               "关掉智能补全时的预览窗口

set viminfo=!,'1000,<1000,s1024,:100,f1                  "viminfo文件保存的信息选项

"自动保存文件
"set updatetime=1000
"autocmd CursorHoldI * silent w

"持久化的undo机制：保存文件修改的撤消/重做
set undodir=~/.vimSession/undodir
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
set expandtab                                              "将新增的tab转换为空格，不会对已有的tab进行转换
set tabstop=4                                              "设置一个tab对应4个空格
set shiftwidth=4                                           "统一缩进为4
set softtabstop=4                                          "在按退格键时，如果前面有4个空格，则会统一清除
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
highlight Visual ctermbg=241

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
set gdefault                                               "替换时所有的行内匹配都被替换，而不是只有第一个
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

"让vim记忆上次编辑文件的位置
autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | silent! execute "normal g'\"" | endif

"自动保存和加载VimSeesion和VimInfo
autocmd VimEnter * call EnterHandler()
autocmd VimLeave * call LeaveHandler() 

"跟踪quickfix窗口状态
augroup QFixToggle
    autocmd!
    autocmd BufWinEnter quickfix let g:qfix_win = bufnr("$")
    autocmd BufWinLeave * if exists("g:qfix_win") && expand("<abuf>") == g:qfix_win | unlet! g:qfix_win | endif
augroup END

"恢复命令栏默认高度
autocmd CursorMoved * if exists("g:show_func") | unlet! g:show_func | set cmdheight=1 | echo '' | endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 设置快捷键
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
vnoremap <silent> <C-c> y                                  "复制
nnoremap <silent> <C-c> yiw                                "复制
noremap  <silent> <C-v> p                                  "粘贴
vnoremap <silent> <C-x> d                                  "剪切
nnoremap <silent> <C-x> diw                                "剪切
nnoremap <silent> <C-a> ggvG$                              "全选

nnoremap <silent> <Leader>sw :w<CR>                        "保存当前窗口修改
nnoremap <silent> <Leader>sa :wa<CR>                       "保存所有窗口修改
nnoremap <silent> <Leader>wv <C-w>v                        "垂直分割当前窗口
nnoremap <silent> <Leader>wh <C-w>s                        "水平分割当前窗口
nnoremap <silent> <Leader>wt :tabe %<CR>                   "当前窗口移到新标签页
nnoremap <silent> <Leader>wr <C-w>r                        "旋转当前窗口位置
nnoremap <silent> <Leader>wc <C-w>c                        "关闭当前窗口
nnoremap <silent> <Leader>wd :bd<CR>                       "删除当前缓存窗口
nnoremap <silent> <Leader>ws :b#<CR>                       "切换上次缓存窗口
nnoremap <silent> <Leader>wq :q<CR>                        "退出
nnoremap <silent> <Leader>qq :qa<CR>                       "退出VIM

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
nnoremap <silent> <Leader>fw :call SearchWord()<CR>

"快速移动
nnoremap <silent> <C-h> 6h
nnoremap <silent> <C-l> 6l
nnoremap <silent> <C-j> 6j
nnoremap <silent> <C-k> 6k

"切换下一条quickfix记录
nnoremap <silent> <Leader>qf :silent! cn!<CR>
nnoremap <silent> <Leader>qb :silent! cp!<CR>

"替换当前光标下单词为复制寄存器内容
nnoremap <silent> <Leader>p  :call ReplaceWord()<CR> 

"搜索光标下单词
nnoremap <silent> <Leader>rg :Rgrep<CR>

"替换字符串
nnoremap <silent> <Leader>gr :call GlobalReplace()<CR>

"显示当前行所在函数名,等同于df命令
nnoremap <silent> <Leader>sfn :call ShowFuncName()<CR>

"跳转到函数指定位置
nnoremap <silent> <Leader>jfs  :call JumpFunctionPos("jfs")<CR> 
nnoremap <silent> <Leader>jfe  :call JumpFunctionPos("jfe")<CR> 

"格式化当前文件
nnoremap <silent> <Leader>cf :call CodeFormat()<CR>

"清除工程相关文件
nnoremap <silent> <Leader><F11> :call LoadProject("delete")<CR>

"重新生成工程文件
nnoremap <silent> <Leader><F12> :call LoadProject("create")<CR>

"窗口切换
nnoremap <silent> <Leader>tl :call ToggleWindow("tl")<CR>  "切换TagsList
nnoremap <silent> <Leader>qo :call ToggleWindow("qo")<CR>  "切换QickFix
nnoremap <silent> <Leader>be :call ToggleWindow("be")<CR>  "切换BufExplorer
nnoremap <silent> <Leader>nt :call ToggleWindow("nt")<CR>  "切换NERDTree

"扩展跳转功能
nnoremap <Leader>tj  :tj <C-R>=expand("<cword>")<CR>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 设置CSCOPE
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set cscopequickfix=s-,c-,d-,i-,t-,e-                       "设定是否使用quickfix窗口显示cscope结果
set csprg=/usr/bin/cscope                                  "制定cscope命令
set csto=0                                                 "ctags查找顺序，0表示先cscope数据库再标签文件
set cst                                                    "同时搜索tag文件和cscope数据库

nmap <silent> <Leader>fs :call CSFind('fs')<CR>           "查找符号
nmap <silent> <Leader>fg :call CSFind('fg')<CR>           "查找定义
nmap <silent> <Leader>fc :call CSFind('fc')<CR>           "查找调用这个函数的函数
nmap <silent> <Leader>fd :call CSFind('fd')<CR>           "查找被这个函数调用的函数
nmap <silent> <Leader>ft :call CSFind('ft')<CR>           "查找这个字符串
nmap <silent> <Leader>fe :call CSFind('fe')<CR>           "查找这个egrep匹配模式
nmap <silent> <Leader>ff :call CSFind('ff')<CR>           "查找同名文件
nmap <silent> <Leader>fi :call CSFind('fi')<CR>           "查找包含这个文件的文件
nmap <silent> <Leader>ss :cs find s <C-R>=expand("<cword>")<CR>

"CS命令
function! CSFind(ccmd)
    silent! execute 'call ToggleWindow("allclose")'
    silent! execute 'call setqflist([], "r")'

    let csarg=expand('<cword>')
    if a:ccmd == "fs"
        silent! execute "cs find s ".csarg 
    elseif a:ccmd == "fg"
        silent! execute "cs find g ".csarg 
    elseif a:ccmd == "fc"
        silent! execute "cs find c ".csarg 
    elseif a:ccmd == "fd"
        silent! execute "cs find d ".csarg 
    elseif a:ccmd == "ft"
        silent! execute "cs find t ".csarg 
    elseif a:ccmd == "fe"
        silent! execute "cs find e ".csarg 
    elseif a:ccmd == "ff"
        let csarg=expand('<cfile>')
        execute "cs find f ".csarg 
    elseif a:ccmd == "fi"
        let csarg=expand('<cfile>')
        silent! execute "cs find i ".csarg 
    endif

    let itemCount=0
    for item in getqflist()
        let itemCount = itemCount + 1
        if itemCount > 1
            silent! execute 'call ToggleWindow("qo")'
            break
        endif
    endfor
endfunction

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
function! SearchWord()
    let fargs="\\<".expand('<cword>')."\\>"
    "搜索模式寄存器赋值
    call setreg("/", fargs)
    silent! execute 'normal n'
endfunction

"获取函数头开始行
function! JumpFuncStart()
    let line_end="\\s*\\r\\?\\n\\?\\s*"
    let not_in_bracket="[^;+\\-=!/(){}]"

    let func_name="^\\(\\s*[\\~\\*:]*\\s*\\w\\+\\s*\\)\\+\\(::\\~\\?\\w\\+\\)\\?".line_end
    let func_args="(\\(".not_in_bracket."*".line_end.",\\?".line_end."\\)*)".line_end
    let func_its_cpp="\\(:\\(".line_end."\\w\\+(\\(".line_end."[^{}]*".line_end."\\)\\+),\\?".line_end."\\)\\+\\)\\?".line_end
    let func_limit="\\(\\s*const\\s*\\)\\?".line_end."{"

    let func_reg=func_name.func_args.func_its_cpp.func_limit
    let exclude_reg="\\(}\\?\\s*\\(else\\)\\?\\s*if\\|for\\|while\\|switch\\|catch\\)\\s*(.*)".line_end."{\\?"

    let find_line=search(func_reg, 'bW')
    let find_str=getline(find_line)
    while matchstr(find_str, exclude_reg) != ""
        let find_line=search(func_reg, 'bW')
        let find_str=getline(find_line)
    endwhile

    let func_start = line(".")
    return func_start
endfunction

"状态栏显示当前行所在函数名
function! ShowFuncName()
    let rowNum = line(".")
    let colNum = col(".")

    let headStart = JumpFuncStart()
    silent! execute 'normal ^'
    call search("{", 'c')
    let headEnd = line(".")

    let headHeight = 0
    let saveStart=headStart
    while headStart <= headEnd  
        let headHeight = headHeight + 1
        let headStart = headStart + 1
    endwhile
    silent! execute 'set cmdheight='.headHeight
    let g:show_func=headHeight

    let headStart = saveStart
    echohl ModeMsg
    while headStart <= headEnd  
        echo getline(headStart)
        let headStart = headStart + 1
    endwhile
    echohl None

    call search("\\%" . rowNum . "l" . "\\%" . colNum . "c")
endfunction

"获取函数开始行数与结束行数
function! GetFuncRange()
    let rowNum = line(".")
    let colNum = col(".")

    let funcStart = JumpFuncStart()
    silent! execute 'normal ^'
    call search("{", 'c')
    silent! execute 'normal %'
    let funcEnd = line(".")

    call search("\\%" . rowNum . "l" . "\\%" . colNum . "c")
    return funcStart . "," . funcEnd 
endfunction

"格式化语言
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
                silent! execute "normal G"
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
    silent! execute rangeStr."!astyle --style=ansi --indent=spaces=4 -p -U -S --suffix=none --convert-tabs"
endfunction

"格式化并刷新
function! CodeFormat()
    "保存标签位置，格式化后恢复
    normal! ma

    "去除行结尾字符
    silent! execute '%s/\r//g' 
    "保存当前文件
    silent! execute 'w'
    "重新加载当前文件
    silent! execute 'e' 

    "格式化语言
    silent! execute 'call FormatLanguage()'
    "保存当前文件
    silent! execute 'w'
    "重新加载当前文件
    silent! execute 'e' 

    "加载恢复
    silent! execute 'call RestoreLoad()'

    "恢复文件行位置
    silent! normal! g`a
    delmarks a
endfunction

"跳转到函数指定位置
function! JumpFunctionPos(pos)
    if a:pos == 'jfs'
        silent! execute 'call JumpFuncStart()'
        silent! execute 'normal ^'
    elseif a:pos == 'jfe'
        silent! execute 'call JumpFuncStart()'
        silent! execute 'normal ^'
        call search("{", 'c')
        silent! execute 'normal %'
    endif
endfunction

"替换当前光标下单词为复制寄存器内容
function! ReplaceWord()
    let rowNum = line(".")
    let colNum = col(".")

    let oldStr = expand('<cword>')
    let lineStr = getline(rowNum)

    let index = stridx(lineStr, oldStr) + 1 
    while (index + strlen(oldStr)) < colNum
        let index = stridx(lineStr, oldStr, index + strlen(oldStr)) + 1
    endwhile

    if index >= 1
        call cursor(rowNum, index)
        silent! execute "normal ".strlen(oldStr)."x"
        silent! execute "normal \"0P"
    endif

    call search("\\%" . rowNum . "l" . "\\%" . colNum . "c")
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
                silent! execute "normal G"
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
                    while matchstr(getline(startLine), "\\<".oldStr."\\>") != '' 
                        execute "s".separatorStr."\\<".oldStr."\\>".separatorStr.newStr.separatorStr."gec"
                    endwhile
                elseif wholeWordStr == "n" || wholeWordStr == "N"
                    while matchstr(getline(startLine), "\\v([\s\S]{-})".oldStr."([\s\S]{-})") != '' 
                        execute "s".separatorStr."\\v([\s\S]{-})".oldStr."([\s\S]{-})".separatorStr."\\1".newStr."\\2".separatorStr."gec"
                    endwhile
                endif
            elseif confirmStr == "n" || confirmStr == "N"
                if wholeWordStr == "y" || wholeWordStr == "Y"
                    while matchstr(getline(startLine), "\\<".oldStr."\\>") != '' 
                        silent! execute "s".separatorStr."\\<".oldStr."\\>".separatorStr.newStr.separatorStr."ge"
                    endwhile
                elseif wholeWordStr == "n" || wholeWordStr == "N"
                    while matchstr(getline(startLine), "\\v([\s\S]{-})".oldStr."([\s\S]{-})") != '' 
                        silent! execute "s".separatorStr."\\v([\s\S]{-})".oldStr."([\s\S]{-})".separatorStr."\\1".newStr."\\2".separatorStr."ge"
                    endwhile
                endif
            endif     

            let startLine = startLine + 1
        endwhile
    else
        return
    endif

    "恢复文件行列位置
    call search("\\%" . rowNum . "l" . "\\%" . colNum . "c")
endfunction

"恢复加载
function! RestoreLoad()
    if !exists("autocommands_loaded")
        "防止多次加载                                                                                            
        let autocommands_loaded = 1

        "创建文件修改回退目录
        let dirStr=GetVimDir(0,"undodir")
    endif
endfunction

"窗口控制
function! ToggleWindow(ccmd)
    if a:ccmd == "nt"
        silent! execute 'TagbarClose'
        if exists("g:qfix_win")
            silent! execute 'cclose'
        endif
        let benr = bufnr("[BufExplorer]")
        if bufname(benr) == "[BufExplorer]"
            silent! execute 'bw! '.benr
        endif

        silent! execute 'NERDTreeToggle' 
    elseif a:ccmd == "tl"
        silent! execute 'NERDTreeClose'
        if exists("g:qfix_win")
            silent! execute 'cclose'
        endif
        let benr = bufnr("[BufExplorer]")
        if bufname(benr) == "[BufExplorer]"
            silent! execute 'bw! '.benr
        endif

        silent! execute "TagbarToggle"
    elseif a:ccmd == "be"
        silent! execute 'TagbarClose'
        silent! execute 'NERDTreeClose'
        if exists("g:qfix_win")
            silent! execute 'cclose'
        endif

        silent! execute "BufExplorer"
    elseif a:ccmd == "qo"
        silent! execute 'TagbarClose'
        silent! execute 'NERDTreeClose'
        let benr = bufnr("[BufExplorer]")
        if bufname(benr) == "[BufExplorer]"
            silent! execute 'bw! '.benr
        endif

        if exists("g:qfix_win")
            silent! execute 'cclose'
        else
            silent! execute 'copen 15'
        endif
    elseif a:ccmd == "allclose"
        silent! execute 'TagbarClose'
        silent! execute 'NERDTreeClose'
        if exists("g:qfix_win")
            silent! execute 'cclose'
        endif

        let benr = bufnr("[BufExplorer]")
        if bufname(benr) == "[BufExplorer]"
            silent! execute 'bw! '.benr
        endif
    endif
endfunction

"自定义变量
let g:isDeleteSave = 0

"工程控制
function! LoadProject(opmode) 
    if a:opmode == "create"
        let defaultStr = "c\\|cpp\\|cc\\|java\\|hpp\\|h\\|s\\|S"

        let findStr = GetInputStr("Input file type (separated with comma) to parse: ", "", "")
        if strlen(findStr) > 0
            let findStr = substitute(findStr, ',', '\\|', 'g')                
        else
            let findStr = defaultStr
        endif

        silent! execute "!rm -f tags"
        silent! execute "!rm -f cscope.*"
        silent! execute "!rm -f ncscope.*"

        let includeStr = GetInputStr("Input search directory: ", "", "dir")
        if includeStr == ""
            silent! execute "!find . -type f ".
                        \ "-regex '.+\\.\\(".findStr."\\)' ".
                        \ "> cscope.files"
        else
            while includeStr != ''
                let includeStr = "./".includeStr                

                silent! execute "!find ".includeStr." -type f ".
                            \ "-regex '.+\\.\\(".findStr."\\)' ".
                            \ ">> cscope.files"

                let includeStr = GetInputStr("Input search directory: ", "", "dir")
            endwhile

            silent! execute "!sort -u cscope.files > cscope.files.tmp"
            silent! execute "!mv cscope.files.tmp cscope.files"
        endif

        "删除cscope.files中无用文件
        let excludeStr = GetInputStr("Input wipe directory: ", "", "dir")
        while excludeStr != ''
            let excludeStr = substitute(excludeStr, $HOME."/", "", 'g')                
            let excludeStr = substitute(excludeStr, "/", "\\\\/", 'g')                

            silent! execute "!sed -i '/".excludeStr."/d' cscope.files"

            let excludeStr = GetInputStr("Input wipe directory: ", "", "dir")
        endwhile

        silent! execute "!ctags --c++-kinds=+p --fields=+iaS --extra=+q -L cscope.files"
        silent! execute "!cscope -ckbq -i cscope.files"

        silent! execute "!rm -f ncscope.*"
        silent! execute "!rm -f cscope.files"
        silent! execute "qa"
    elseif a:opmode == "delete" 
        let g:isDeleteSave = 1
        silent! execute "qa"
    elseif a:opmode == "load" 
        if filereadable("tags")
            set tags=tags;  "结尾分号能够向父目录查找tags文件
        endif
        set nocsverb
        if filereadable("cscope.out")
            silent! execute "cs add cscope.out ./"
        endif
        set csverb       
    endif
endfunction

"VIM进入事件
function! EnterHandler()
    if filereadable(GetVimDir(1,"sessions")."/tags") && filereadable(GetVimDir(1,"sessions")."/cscope.out")
        silent! execute "!mv ".GetVimDir(1,"sessions")."/tags ".getcwd()
        silent! execute "!mv ".GetVimDir(1,"sessions")."/cscope.* ".getcwd()
    endif

    if filereadable("tags") && filereadable("cscope.out")
        silent! execute "call LoadProject(\"load\")"

        if filereadable(GetVimDir(1,"sessions")."/session.vim")
            silent! execute "source ".GetVimDir(1,"sessions")."/session.vim"
        endif
        if filereadable(GetVimDir(1,"sessions")."/session.vim")
            silent! execute "rviminfo ".GetVimDir(1,"sessions")."/session.viminfo"
        endif

        silent! execute 'call RestoreLoad()'
    endif
endfunction

"VIM退出事件
function! LeaveHandler()
    if filereadable("tags") && filereadable("cscope.out")
        silent! execute 'TagbarClose'
        silent! execute 'NERDTreeClose'
        silent! execute 'SrcExplClose'
        silent! execute 'CtrlSFClose'
        silent! execute 'cclose'

        let benr = bufnr("[BufExplorer]")
        if bufname(benr) == "[BufExplorer]"
            silent! execute 'bw! '.benr
        endif

        if g:isDeleteSave == 0
            silent! execute "mks! ".GetVimDir(1,"sessions")."/session.vim"
            silent! execute "wviminfo! ".GetVimDir(1,"sessions")."/session.viminfo"

            silent! execute "!mv tags ".GetVimDir(1,"sessions")
            silent! execute "!mv cscope.* ".GetVimDir(1,"sessions")
        else
            silent! execute "!rm -fr ".GetVimDir(1,"sessions") 
            silent! execute "!rm -fr ".GetVimDir(1,"ctrlpcache") 
            silent! execute "!rm -fr ".GetVimDir(1,"bookmark") 
            silent! execute "!rm -f cscope.* ncscope.* tags"
        endif 
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
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()
Bundle "gmarik/vundle"                                     

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
let g:vbookmark_bookmarkSaveFile = GetVimDir(1,"bookmark")."/save.vbm" 

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 关键字搜索 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "yegappan/grep"

let Grep_Default_Filelist = '*.*'                          "查找文件类型
let Grep_Skip_Dirs = 'RCS CVS SCCS .repo .git .svn'        "不匹配指定目录
let Grep_Skip_Files = '*.bak *~ .git* tags cscope.*'       "不匹配指定文件

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

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 模糊查找文件 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "kien/ctrlp.vim"

let g:ctrlp_cache_dir = GetVimDir(1,"ctrlpcache")          "设置存储缓存文件的目录
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

nnoremap <silent> <Leader>a :A<CR>
nnoremap <silent> <Leader>an :AN<CR>
nnoremap <silent> <Leader>at :AT<CR>
nnoremap <silent> <Leader>af :IH<CR>
nnoremap <silent> <Leader>afn :IHN<CR>
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
Bundle "Shougo/neocomplete.vim"

inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
inoremap <expr><CR>  pumvisible() ? "\<C-y>" : "\<CR>"
let g:neocomplete#enable_at_startup = 1                    "启用该插件
let g:neocomplete#sources#syntax#min_keyword_length = 3    "缓存的最小关键字长度
let g:neocomplete#enable_ignore_case = 1                   "输入关键字忽略大小写
let g:neocomplete#enable_smart_case = 1                    "输入存在大写时，不忽略大小写
let g:neocomplete#enable_auto_select = 1                   "自动指示第一个候选
let g:neocomplete#enable_auto_delimiter = 1                "自动插入路径分隔符
let g:neocomplete#enable_auto_close_preview = 1            "自动关闭候选窗口

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 代码片段 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "SirVer/ultisnips"
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

nmap     <C-F>f <Plug>CtrlSFPrompt
vmap     <C-F>v <Plug>CtrlSFVwordPath
vmap     <C-F>V <Plug>CtrlSFVwordExec
nmap     <C-F>c <Plug>CtrlSFCwordPath
nmap     <C-F>p <Plug>CtrlSFPwordPath
nnoremap <C-F>o :CtrlSFToggle<CR>
inoremap <C-F>o <Esc>:CtrlSFToggle<CR>
let g:ctrlsf_auto_close = 1                                "选中文件后自动关闭预览窗口
let g:ctrlsf_regex_pattern = 1                             "默认以正则表达式搜索
let g:ctrlsf_indent = 0                                    "在原文本缩进基础上增加缩进后显示
let g:ctrlsf_winsize = '100%'                              "搜索结果显示窗口大小
let g:ctrlsf_case_sensitive = 'yes'                        "搜索大小写敏感
let g:ctrlsf_context = '-B 5 -A 3'                         "匹配行前后上下文显示行数配置
let g:ctrlsf_position = 'left'                             "结果窗口显示位置
let g:ctrlsf_selected_line_hl = 'op'                       "在预览窗口和目标文件同时高亮行
let g:ctrlsf_ackprg = '/usr/bin/ack-grep'                  "指定后端搜索工具
let g:ctrlsf_ignore_dir = ['.git', '.repo', '.svn']

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
Bundle "gregsexton/gitv"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 多光标选择 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "terryma/vim-multiple-cursors"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" 
" 绑定 自动补全符号 插件
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
Bundle "Raimondi/delimitMate"

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

"开启插件
filetype plugin indent on
