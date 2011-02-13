" scd.vim -- Vim plugin for Smart Change of Directory
" $Date$
" $Revision$
" Maintainer: Pavol Juhas <pavol.juhas@gmail.com>
"
" Installation: Drop this file to the Vim plugin directory or source
"   it from the .vimrc.  By default the scd plugin automatically indexes
"   the visited directory after each :cd within the Vim session.
"   To turn this autoindexing off, add the following line to your .vimrc:
"       let g:scd_autoindex = 0
"
" Requirements:
"   * Linux or other Unix-like operating system (MAC does qualify)
"   * zsh, the z-shell installed (usually a "zsh" package in Linux)
"   * scd, the scd z-shell script installed in the PATH
"     scd is available at http://code.google.com/p/smart-change-directory/
"
" Examples: these assume the target directories are in the scd index.
"
"       :Scd vi ftpl    " jump to the ~/.vim/ftplugin/ directory
"       :Scd etc        " change to the most recently visited etc directory
"       :Scd -ar ~/.vim " recursively index ~/.vim/ and its subdirectories
"       :Scd            " show selection menu of frequently used directories
"       :Scd -v         " show selection menu with directory ranking
"       :Slcd           " same as Scd, but use the :lcd Vim command
"       :Scd --help     " display usage info for the scd script

" $Id$

if exists("loaded_scd") || &cp
    finish
endif
let loaded_scd = 1

if !executable('scd')
    finish
endif

" Configuration:
if !exists('scd_autoindex')
    let scd_autoindex = 1
endif

" define the Scd commands
command! -nargs=* Scd call <SID>ScdFun("cd", <f-args>)
command! -nargs=* Slcd call <SID>ScdFun("lcd", <f-args>)

" remember the last directory to reduce scd calls when autoindexing.
let s:last_directory = getcwd()

" this function does all the work
function! s:ScdFun(cdcmd, ...)
    let qargs = map(copy(a:000), 'shellescape(v:val)')
    let cmd = 'scd --list ' . join(qargs, ' ')
    let output = system(cmd)
    if v:shell_error
        echo output
        return
    endif
    let lines = split(output, '\n')
    let cnt = len(lines)
    " even lines have directory alias names prefixed with '# '
    let daliases = filter(copy(lines), 'v:key % 2 == 0 && v:val =~ "^# "')
    let daliases = map(daliases, '(v:key + 1) . ")" . strpart(v:val, 1)')
    " odd lines have directory paths
    let dmatching = filter(lines, 'v:key % 2')
    " check if dmatching and daliases are consistent
    if !cnt || len(daliases) != len(dmatching) || cnt != 2 * len(daliases)
        echo output
        return
    endif
    " here dmatching is at least one
    let target = dmatching[0]
    if len(dmatching) > 1
        let idx = inputlist(['Select directory:'] + daliases) - 1
        redraw
        if idx < 0 || idx >= len(dmatching)
            return
        endif
        let target = dmatching[idx]
    endif
    execute a:cdcmd target
    call s:ScdAddChangedDir()
    pwd
endfunction

" Take care of autoindexing

function! s:ScdAddChangedDir()
    if s:last_directory == getcwd()
        return
    endif
    let s:last_directory = getcwd()
    call system('scd -a . &')
endfunction

" First remove all scd related autocommands.
augroup ScdAutoCommands
    autocmd!
augroup END
augroup! ScdAutoCommands
" If autoindex is on, watch for the CursorHold event.
if scd_autoindex
    augroup ScdAutoCommands
        autocmd CursorHold * call s:ScdAddChangedDir()
    augroup END
endif
