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
command! -nargs=* Scd call <SID>ScdFun("cd", "<args>")
command! -nargs=* Slcd call <SID>ScdFun("lcd", "<args>")

" Temporary file, where scd script saves the target directory.
let $SCD_SCRIPT = tempname()
let s:last_directory = getcwd()

" The ScdFun does all the work.
function! s:ScdFun(cdcmd, scdargs)
    if has("gui_running")
        execute '!scd' a:scdargs
    else
        execute 'silent !scd' a:scdargs
    endif
    if v:shell_error
        echo "Directory not found"
    elseif getfsize($SCD_SCRIPT) > 0
        let lines = readfile($SCD_SCRIPT, '', 1)
        let cmd = lines[0]
        let cmd = substitute(cmd, '^cd', a:cdcmd, '')
        execute cmd
        redraw!
        echo getcwd()
    endif
    let s:last_directory = getcwd()
endfunction

" Take care of autoindexing

function! s:ScdAddChangedDir()
    if s:last_directory == getcwd()
        return
    endif
    let s:last_directory = getcwd()
    silent !scd -a . &
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
