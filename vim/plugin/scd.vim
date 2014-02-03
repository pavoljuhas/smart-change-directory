" scd.vim -- Vim plugin for Smart Change of Directory
" Date: 2014-01-11
" Maintainer: Pavol Juhas <pavol.juhas@gmail.com>
" URL: https://github.com/pavoljuhas/smart-change-directory/
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
"     scd is available at https://github.com/pavoljuhas/smart-change-directory/
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

if exists("loaded_scd") || &cp
    finish
endif
let loaded_scd = 1

" Parse configuration variables ----------------------------------------------

" expected relative location of the scd script within Git bundle
let s:rel_cmd = fnamemodify(resolve(expand('<sfile>')), ':h:h:h') . '/bin/scd'
" Resolve command name for the z-shell scd script: (i) use g:scd_command if
" defined, (ii) when this file is symlinked or scd is not in the PATH, check
" at the relative location, (iii) just fall back to scd.
let s:scd_command = exists('g:scd_command') ? g:scd_command :
        \ (('link' == getftype(expand('<sfile>')) || 1 != executable('scd'))) &&
        \ (1 == executable(s:rel_cmd)) ? s:rel_cmd : 'scd'
unlet s:rel_cmd

let s:scd_autoindex = exists('g:scd_autoindex') ? g:scd_autoindex : 1
let s:scd_autoindex = s:scd_autoindex && (1 == executable(s:scd_command))

" define the Scd commands
command! -complete=custom,s:ScdComplete -nargs=* Scd
            \ call <SID>ScdFun("cd", <f-args>)
command! -complete=custom,s:ScdComplete -nargs=* Slcd
            \ call <SID>ScdFun("lcd", <f-args>)

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
    execute a:cdcmd fnameescape(target)
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

" Completion function for aliases and directory names

function! s:ScdComplete(A, L, P)
    let aliases = {'a' : s:ScdLoadAliases()}
    let anames1 = keys(aliases.a)
    let anames2 = map(copy(anames1), '"~" . v:val')
    function aliases.expand(t) dict
        let idx = stridx(a:t, '/')
        let thead = strpart(a:t, 0, idx)
        let ttail = strpart(a:t, idx)
        let thead1 = strpart(thead, 1)
        let exphead = (thead =~ '^[~]' && has_key(self.a, thead1)) ?
                    \ self.a[thead1] : expand(thead)
        return exphead . ttail
    endfunction
    " avoid globing and associated shell calls if we are expanding an alias
    let searchdirs = (a:A !~ '^[~][^/]*$')
    let Afull = aliases.expand(a:A)
    let dirnames = searchdirs ? glob(Afull . '*', 0, 1) : []
    call filter(dirnames, 'isdirectory(v:val) && v:val !~ "/[.][.]\\?$"')
    let dir = {'path' : {}, 'A' : a:A, 'Afull' : Afull, 'nf' : strlen(Afull)}
    function dir.unique(d) dict
        let self.path[a:d] = has_key(self.path, a:d)
        return !self.path[a:d]
    endfunction
    function dir.unexpand(d) dict
        let d1 = stridx(a:d, self.Afull) ? a:d : self.A . strpart(a:d, self.nf)
        return escape(d1, ' \')
    endfunction
    call filter(dirnames, 'dir.unique(v:val)')
    call map(dirnames, 'dir.unexpand(v:val)')
    let suggestions = (empty(a:A) ? [] : anames1) + anames2 + dirnames
    return join(suggestions, "\n")
endfunction

" Helper function for loading scd aliases

let s:scd_alias = {}
let s:scd_alias_file = $HOME . '/.scdalias.zsh'
let s:scd_alias_mtime = -20

function! s:ScdLoadAliases()
    let ad = {}
    if !filereadable(s:scd_alias_file)
        return ad
    endif
    " shortcut if aliases have been cached
    if getftime(s:scd_alias_file) == s:scd_alias_mtime
        return s:scd_alias
    endif
    " here we need to load and cache the scd aliases
    for line in readfile(s:scd_alias_file)
        if line !~# '^hash -d .*\S='
            continue
        endif
        let eq = stridx(line, '=')
        let ca = substitute(strpart(line, 0, eq), '.*\s', '', '')
        let df = substitute(strpart(line, eq + 1), '\s*$', '', '')
        let df = substitute(df, "^'\\(.*\\)'$", '\1', '')
        if isdirectory(df)
            let ad[ca] = df
        endif
    endfor
    let s:scd_alias = ad
    let s:scd_alias_mtime = getftime(s:scd_alias_file)
    return s:scd_alias
endfunction
