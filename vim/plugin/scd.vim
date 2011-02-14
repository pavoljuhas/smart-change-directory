" scd.vim -- Vim plugin for Smart Change of Directory
" $Date$
" $Revision$
" Maintainer: Pavol Juhas <pavol.juhas@gmail.com>
" URL: http://code.google.com/p/smart-change-directory/
"
" Installation: Drop this file to the Vim plugin directory or source
"   it from the .vimrc.  Copy the scd z-shell script to some directory
"   in the PATH or use the g:scd_command variable to specify its location.
"   Make sure the scd script has its executable permission set.
"
"   This plugin makes Vim automatically add visited directories to
"   the scd index after each :cd command in the session.  This runs
"   a background system command "scd -a ." when Vim becomes idle.
"   To turn the indexing off, add the following line to the .vimrc file:
"
"       let g:scd_autoindex = 0
"
" Requirements:
"   * Linux or other Unix-like operating system (MAC does qualify)
"   * zsh, the z-shell installed (usually a "zsh" package in Linux)
"   * scd, the scd z-shell script installed in the PATH
"     scd is available at http://code.google.com/p/smart-change-directory/
"
" Examples: these assume that target directories are in the scd index
"
"   :Scd vi ftpl    " jump to the ~/.vim/ftplugin/ directory
"   :Scd doc        " change to the most recently visited doc directory
"   :Scd in(#e)     " change to the most recently visited doc directory
"   :Scd            " show selection menu of frequently used directories
"   :Scd -v         " show selection menu with directory ranking
"   :Slcd           " same as Scd, but use the :lcd Vim command
"   :Scd --help     " display usage info for the scd script
"   :Scd -ar ~/.vim " recursively index ~/.vim/ and its subdirectories
"
" Configuration: this plugin consults the following Vim variables:
"   g:scd_autoindex     flag for indexing the :cd visited directories [1]
"   g:scd_command       path to the scd z-shell script ["scd"]

" $Id$

if exists("loaded_scd") || &cp
    finish
endif
let loaded_scd = 1

" parse configuration variables
let s:scd_command = exists('g:scd_command') ? g:scd_command : 'scd'
let s:scd_executable = (executable(s:scd_command) == 1)
let s:scd_autoindex = exists('g:scd_autoindex') ? g:scd_autoindex : 1
let s:scd_autoindex = s:scd_autoindex && s:scd_executable

" define the Scd commands
command! -nargs=* Scd call <SID>ScdFun("cd", <f-args>)
command! -nargs=* Slcd call <SID>ScdFun("lcd", <f-args>)

" remember the last directory to reduce scd calls when autoindexing.
let s:last_directory = getcwd()

" this function does all the work
function! s:ScdFun(cdcmd, ...)
    let qargs = map(copy(a:000),
                \ '(v:val[0] == "~") ? v:val : shellescape(v:val)')
    let cmd = join([s:scd_command, '--list'] + qargs, ' ')
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
    call system(s:scd_command . ' -a . &')
endfunction

" First remove all scd related autocommands.
augroup ScdAutoCommands
    autocmd!
augroup END
augroup! ScdAutoCommands

" If autoindex is on, watch for the CursorHold event.
if s:scd_autoindex
    augroup ScdAutoCommands
        autocmd CursorHold * call s:ScdAddChangedDir()
    augroup END
endif
