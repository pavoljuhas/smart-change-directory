" $Id$

if exists("loaded_scd") || &cp
    finish
endif
let loaded_scd = 1

if !executable('scd')
    finish
endif

" define the Scd commands
com! -nargs=* Scd call <SID>ScdFun("cd", "<args>")
com! -nargs=* Slcd call <SID>ScdFun("lcd", "<args>")

let $SCD_SCRIPT = tempname()
let s:last_directory = getcwd()

" and to define s:WcdFun
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
        exe cmd
        redraw!
        echo getcwd()
    endif
    let s:last_directory = getcwd()
endfunction

function! s:ScdAddChangedDir()
    if s:last_directory == getcwd()
        return
    endif
    let s:last_directory = getcwd()
    silent !scd -a . &
endfunction

augroup ScdAutoCommands
    autocmd!
    autocmd CursorHold * call s:ScdAddChangedDir()
augroup END
