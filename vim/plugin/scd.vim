" scd.vim -- Vim plugin for Smart Change of Directory
" Date: 2016-06-16
" Maintainer: Pavol Juhas <pavol.juhas@gmail.com>
" URL: https://github.com/pavoljuhas/smart-change-directory/
"
" Requirements:
"
"   * Linux, Mac OS X or other unix-like operating system
"   * Z shell (usually the "zsh" package in Linux)
"
" Installation:
"
"   (A) Manual
"   Drop this file to the Vim plugin directory or source it from .vimrc.
"   Copy or symlink the bin/scd script to some directory in the PATH or
"   set the g:scd_command variable to its location.
"
"   (B) Installation from Git bundle
"   Navigate to the vim/plugin directory in the bundle and create symbolic
"   link to this file in the Vim plugin directory, e.g.,
"       ln -si $PWD/scd.vim ~/.vim/plugin/
"   The bin/scd script will be then located relative to the absolute path
"   of scd.vim.
"
" Notes:
"
"   This plugin adds visited directories to the scd index after each
"   :cd command in the Vim session.  This is accomplished by executing
"   background command "scd -a ." when Vim becomes idle.  This auto-indexing
"   feature can be disabled by adding the following line to .vimrc:
"
"       let g:scd_autoindex = 0
"
"   For best results activate scd also in the system shell as described at
"   https://github.com/pavoljuhas/smart-change-directory#installation
"
" Examples:
"
"   :Scd -ar ~/.vim " recursively index ~/.vim/ and its subdirectories
"   :Scd vi ftpl    " jump to the ~/.vim/ftplugin/ directory
"   :Scd doc        " change to the most recently visited doc directory
"   :Scd in$        " jump to recent directory ending in 'in'
"   :Scd            " show selection menu of frequently used directories
"   :Scd -v         " show selection menu with directory ranking
"   :Slcd           " same as Scd, but use the :lcd Vim command
"   :Scd --help     " display usage info for the scd script
"   :Scd <Tab>      " complete scd-defined directory aliases
"
" Configuration: this plugin honors the following global variables:
"
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

" Define user Scd commands ---------------------------------------------------

command! -complete=custom,s:ScdComplete -nargs=* Scd
            \ call <SID>ScdFun("cd", [<f-args>])
command! -complete=custom,s:ScdComplete -nargs=* Slcd
            \ call <SID>ScdFun("lcd", [<f-args>])

" Implementation -------------------------------------------------------------

" main interface to the z-shell script
function! s:ScdFun(cdcmd, scdargs)
    let qargs = map(copy(a:scdargs),
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

" Indexing and auto-indexing -------------------------------------------------

" Remember startup directory to detect directory change.
let s:last_directory = getcwd()

function! s:ScdAddChangedDir() abort
    let cwd = getcwd()
    if s:last_directory == cwd
        return
    endif
    let s:last_directory = cwd
    " Deprecated code for older Vim versions where writefile cannot append.
    if v:version < 800
        call system(s:scd_command . ' -a . &')
        return
    endif
    " Record the current directory without calling system and thus
    " overwriting the v:shell_error value.
    let scd_histfile = exists('$SCD_HISTFILE') ?
                \ $SCD_HISTFILE : expand('~/.scdhistory')
    " Ensure history file exists.  If not create it with private permissions.
    if !filereadable(scd_histfile)
        call writefile([], scd_histfile)
        call setfperm(scd_histfile, 'rw-------')
    endif
    " Obtain the last line or empty string for an empty file.
    let tail = ([''] + readfile(scd_histfile, '', -1))[-1]
    let tail_directory = substitute(tail, '^[^;]*;', '', '')
    if tail_directory == cwd
        return
    endif
    let line = ': ' . localtime() . ':0;' . cwd
    call writefile([line], scd_histfile, 'a')
endfunction

" First remove all scd-related autocommands.
augroup ScdAutoCommands
    autocmd!
augroup END
augroup! ScdAutoCommands

" If autoindex is enabled, add autocommand to check for directory change.
if s:scd_autoindex
    augroup ScdAutoCommands
        autocmd CursorHold,CursorHoldI * call s:ScdAddChangedDir()
    augroup END
endif

" Completion -----------------------------------------------------------------

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
    let Apattern = substitute(Afull, '[*]*$', '*', '')
    let dirnames = searchdirs ? split(glob(Apattern), '\n') : []
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
    let suggestions = empty(a:A) ? (anames2 + dirnames) :
                \ (a:A =~ '[?*]$') ? dirnames : (anames1 + anames2 + dirnames)
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
