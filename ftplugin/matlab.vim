" matlab.vim - A script to highlight MatLab code in Vim based on the output from
" Matlab's in built mlint function.
"
" Place in your after/ftplugin directory.
"
" Last Change: 2008 Oct 13
" Maintainer: Thomas Ibbotson <thomas.ibbotson@gmail.com>
" License: Copyright 2008 Thomas Ibbotson
"    This program is free software: you can redistribute it and/or modify
"    it under the terms of the GNU General Public License as published by
"    the Free Software Foundation, either version 3 of the License, or
"    (at your option) any later version.
"
"    This program is distributed in the hope that it will be useful,
"    but WITHOUT ANY WARRANTY; without even the implied warranty of
"    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"    GNU General Public License for more details.
"
"    You should have received a copy of the GNU General Public License
"    along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
" Version: 0.2

if exists("b:did_mlint_plugin")
    finish
endif
let b:did_mlint_plugin = 2

" This plugin uses line continuation...save cpo to restore it later
let s:cpo_sav = &cpo
set cpo-=C

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
au BufUnload <buffer> call s:Cleanup(expand("<afile>:t"), getbufvar(expand("<afile>"), "mlintTempDir"))

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

if exists('b:undo_ftplugin')
    let b:undo_ftplugin = b:undo_ftplugin.' | '
else
    let b:undo_ftplugin = ""
endif
let b:undo_ftplugin = b:undo_ftplugin.'call <SNR>'.s:SID().'_Cleanup()'

" determine 'rmdir' command to use (use 'g:mlint_rmdir_cmd' if it exists or
" default to the one used by netrw if it exists, or just 'rmdir' if it doesn't)
if !exists('g:mlint_rmdir_cmd')
  if exists('g:netrw_local_rmdir')
      let g:mlint_rmdir_cmd=g:netrw_local_rmdir
  else
      let g:mlint_rmdir_cmd='rmdir'
  endif
endif

"Create a temporary directory
let b:mlintTempDir = tempname() . "/"
call mkdir(b:mlintTempDir)

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
        exe "silent write! " . b:mlintTempDir . s:filename
        "MatLab's mlint executable must be on the path for this to work
        let s:lint = system("mlint " . b:mlintTempDir . s:filename)
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
        let s:matches = getmatches()
        for s:matchId in s:matches
            if s:matchId['group'] == 'MLint'
                call matchdelete(s:matchId['id'])
            end
        endfor
        let b:matched = []
        let b:cleared = 1
    endfunction
endif

if !exists('*s:Cleanup')
    function s:Cleanup(filename, mlintTempDir)
        " NOTE: ClearLint should already have been called from BufWinLeave

        let l:mlintTempDir = a:mlintTempDir
            
        " for some reason, rmdir doesn't work with '/' characters on mswin,
        " so convert to '\' characters
        if has("win16") || has("win32") || has("win64")
            let l:mlintTempDir = substitute(l:mlintTempDir,'/','\','g')
        endif

        " For some reason, this function gets called multiple times for one
        " buffer sometimes. Check to prevent this.
        if !exists('s:lastMlintCleanup') || s:lastMlintCleanup != l:mlintTempDir.a:filename
            let s:lastMlintCleanup = l:mlintTempDir.a:filename

            if filewritable(fnameescape(l:mlintTempDir.a:filename)) == 1
                if delete(fnameescape(l:mlintTempDir.a:filename)) == 0
                    " TODO: find a way to detect success and output a warning on failure
                    exe "silent! !".g:mlint_rmdir_cmd." ".fnameescape(l:mlintTempDir)
                else
                    echohl WarningMsg
                    echomsg "mlint: could not delete temp file ".
                                \ fnameescape(l:mlintTempDir.a:filename).
                                \ "; error during file deletion"
                    echohl None
                endif
            else
                echohl WarningMsg
                echomsg "mlint: could not delete temp file ".
                            \ fnameescape(l:mlintTempDir.a:filename).
                            \ "; no write privileges"
                echohl None
            endif
        endif
    endfunction
endif

let &cpo = s:cpo_sav

" vim: sw=4 et
