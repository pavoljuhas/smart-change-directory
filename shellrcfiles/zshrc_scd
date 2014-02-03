## Try to load scd as a shell function either from FPATH or from PATH
## if installed at either place.  Complain if scd cannot be found.
if ( found=( ${^fpath}/scd(N-.) ) && [[ -n ${found} ]] ); then
    autoload scd
elif fpath=( ${fpath} =scd(:h) ); then
    autoload +X scd || unfunction -m scd
    fpath[-1]=( )
else
    print -u2 "scd could not be found neither in FPATH nor in PATH."
fi


## If the scd function exists, define a change-directory-hook function
## to record visited directories in the scd index.
if [[ ${+functions[scd]} == 1 ]]; then
    scd_chpwd_hook() { scd --add $PWD }
    autoload add-zsh-hook
    add-zsh-hook chpwd scd_chpwd_hook
fi


## Allow scd usage with unquoted wildcard characters such as "*" or "?".
alias scd='noglob scd'


## Load the directory aliases created by scd if any.
if [[ -s ~/.scdalias.zsh ]]; then source ~/.scdalias.zsh; fi
