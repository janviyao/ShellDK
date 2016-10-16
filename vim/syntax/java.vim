"========================================================
" Highlight All Function
"========================================================
highlight cFunctions cterm=bold  ctermfg=76
syntax match cFunctions "\<[a-zA-Z_][a-zA-Z_0-9]*\>\s*("me=e-1

"highlight class name
highlight cClass cterm=bold ctermfg=76
syntax match cClass "\<[a-zA-Z_][a-zA-Z_0-9]*\>::"me=e-2

"========================================================
" Highlight All Math Operator
"========================================================
highlight cMathOperator            ctermfg=45
highlight cPointerOperator         ctermfg=45
highlight cBinaryOperator          ctermfg=45
highlight cLogicalOperator         ctermfg=45
highlight cClassOperator           ctermfg=45

syntax match cMathOperator         "-\|+\|\*\|%\|="
syntax match cPointerOperator      "->\|\."
syntax match cLogicalOperator      "\(=\|<\|>\|!\|\~\|&\||\|\^\|<<\|>>\|&&\|||\)=\?"
syntax match cClassOperator        "::"
