" mlint.vim - A script to highlight MatLab code in Vim based on the output from
" Matlab's in built mlint function.
" Last Change: 2008 Sep 23
" Maintainer: Thomas Ibbotson <thomas.ibbotson@gmail.com>
" License: GPL

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

if !hasmapto('<Plug>mlintRunLint')
    map <buffer> <unique> <LocalLeader>l <Plug>mlintRunLint
endif

if !hasmapto('<Plug>mlintGetLintMessage')
    map <buffer> <unique> <LocalLeader>m <Plug>mlintGetLintMessage
endif

if !hasmapto('<SID>RunLint')
    noremap <unique> <script> <Plug>mlintRunLint <SID>RunLint
    noremap <SID>RunLint :call <SID>RunLint()<CR>
endif

if !hasmapto('<SID>GetLintMessage')
    noremap <unique> <script> <Plug>mlintGetLintMessage <SID>GetLintMessage
    noremap <SID>GetLintMessage :call <SID>GetLintMessage()<CR>
end

au BufWinLeave <buffer> call s:ClearLint()
au BufEnter <buffer> call s:RunLint()
au InsertLeave <buffer> call s:RunLint()
if !exists("mlint_hover")
    au CursorHold <buffer> call s:RunLint()
    au CursorHold <buffer> call s:GetLintMessage()
    au CursorHoldI <buffer> call s:RunLint()
endif

if !exists('*s:SID')
    function s:SID()
	  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
	endfun
endif
let b:undo_ftplugin = 'call <SNR>'.s:SID().'_ClearLint()'

"Create a temporary directory
let b:tempDir = tempname() . "/"
call mkdir(b:tempDir)

if !exists("*s:RunLint")
    function s:RunLint()
        "Clear previous matches
        if exists("b:cleared")
            if b:cleared == 0
                silent call s:ClearLint()
                let b:cleared = 1
            endif
        else
            let b:cleared = 1
        endif
        "Get the filename
        let s:filename = expand("%:t")
        exe "silent write! " . b:tempDir . s:filename
        "MatLab's mlint executable must be on the path for this to work
        let s:lint = system("mlint " . b:tempDir . s:filename)
        "Split the output from mlint and loop over each message
        let s:lint_lines = split(s:lint, '\n')
        highlight MLint term=underline gui=undercurl guisp=Orange
        let b:matched = []
        for s:line in s:lint_lines
            let s:matchDict = {}
            let s:lineNum = matchstr(s:line, 'L \zs[0-9]\+')
            let s:colStart = matchstr(s:line, 'C \zs[0-9]\+')
            let s:colEnd = matchstr(s:line, 'C [0-9]\+-\zs[0-9]\+')
            if s:colStart > 0
                if s:colEnd > 0
                    let s:colStart = s:colStart -1
                    let s:colEnd = s:colEnd + 1
                    let s:mID = matchadd('MLint', '\%'.s:lineNum.'l'.'\%>'.s:colStart.'c'.'\%<'.s:colEnd.'c')
                else
                    let s:colEnd = s:colStart + 1
                    let s:colStart = s:colStart - 1
                    let s:mID = matchadd('MLint', '\%'.s:lineNum.'l'.'\%>'.s:colStart.'c'.'\%<'.s:colEnd.'c')
                endif
            else
                let s:mID = matchadd('MLint', '\%'.s:lineNum.'l','\%>1c')
            endif
            if s:lineNum > line("$")
                let s:mID = matchadd('MLint', '\%'.line("$").'l', '\%>1c')
                let s:lineNum = s:lineNum - 1
            endif
            let s:message = matchstr(s:line, ': \zs.*')
            let s:matchDict['mID'] = s:mID
            let s:matchDict['lineNum'] = s:lineNum
            let s:matchDict['colStart'] = s:colStart
            let s:matchDict['colEnd'] = s:colEnd
            let s:matchDict['message'] = s:message
            call add(b:matched, s:matchDict)
        endfor
        let b:cleared = 0
    endfunction
endif

if !exists("*s:GetLintMessage")
    function s:GetLintMessage()
        let s:cursorPos = getpos(".")
        for s:lintMatch in b:matched
            if s:lintMatch['lineNum'] == s:cursorPos[1] "&& s:cursorPos[2] > s:lintMatch['colStart'] && s:cursorPos[2] < s:lintMatch['colEnd']
                echo s:lintMatch['message']
            endif
        endfor
    endfunction
endif

if !exists('*s:ClearLint')
    function s:ClearLint()
        silent! call clearmatches()
        let b:matched = []
        let b:cleared = 1
    endfunction
endif
