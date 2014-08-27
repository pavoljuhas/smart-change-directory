# smart-change-directory (scd)

[Z shell](http://www.zsh.org/) function for visiting any directory in
a Unix shell, [Vim](http://www.vim.org/) or [IPython](http://ipython.org/).

`scd` is a Z shell (Zsh) script for changing to any directory with a few
keystrokes.  scd keeps history of the visited directories, which
serves as an index of the known paths.  The directory index is updated after
every `cd` command in the shell and can be also filled manually by running
`scd -a`.  To switch to some directory, scd needs few fragments of the
desired path to match with the index.  A selection menu is displayed in case
of several matches, with a preference given to recently visited paths.  scd
can create permanent directory aliases, which directly map to the target path.

## SYNOPSIS

```sh
scd [options] [pattern1 pattern2 ...]
```

## OPTIONS

<dl><dt>
-a, --add</dt><dd>
  add specified directories to the directory index.</dd><dt>

--unindex</dt><dd>
  remove current or specified directories from the index.</dd><dt>

-r, --recursive</dt><dd>
  apply options <em>--add</em> or <em>--unindex</em> recursively.</dd><dt>

--alias=ALIAS</dt><dd>
  create alias for the current or specified directory and save it to
  <em>~/.scdalias.zsh</em>.</dd><dt>

--unalias</dt><dd>
  remove ALIAS definition for the current or specified directory from
  <em>~/.scdalias.zsh</em>.</dd><dt>

-A, --all</dt><dd>
  include all matching directories.  Disregard matching by directory
  alias and filtering of less likely paths.</dd><dt>

--list</dt><dd>
  show matching directories and exit.</dd><dt>

-v, --verbose</dt><dd>
  display directory rank in the selection menu.</dd><dt>

-h, --help</dt><dd>
  display this options summary and exit.</dd>
</dl>


## INSTALLATION

## Unix shell

1.  Make sure that Z shell is installed.  On Linux it is usually the `zsh`
    package.

2.  Copy or symlink the [bin/scd](bin/scd) script to some
    directory in the PATH.  Make sure `scd` has executable permissions set or
    add them with `chmod +x scd`.

3.  Find out what shell is active for your account by running `ps -p $$`.

4.  Edit the startup file for your shell, e.g., `.bashrc` for `bash`,
    and have it source the corresponding scd setup file from
    [shellrcfiles](shellrcfiles).
    ```sh
    source ~/Downloads/smart-change-directory/shellrcfiles/bashrc_scd
    ```

    For recent versions of Zsh use `zshrc_scd`.  Use `zshrc_scd_42` for Zsh
    version 4.2 or older.  Note that scd aliases are named directories in Zsh
    and thus can be expanded as `~NAME` in the shell.

    For `dash` or old Bource shells, replace `source` command above with `.`.


## Examples

```sh
# Index recursively some paths for the very first run
scd -ar ~/Documents/

# Change to a directory path matching "doc"
scd doc

# Change to a path matching all of "a", "b" and "c"
scd a b c

# Change to a directory path that ends with "ts"
scd "ts$"

# Show selection menu and ranking of 20 most likely directories
scd -v

# Alias current directory as "xray"
scd --alias=xray

# Jump to a previously defined aliased directory
scd xray
```

## Installation as Vim plugin

1.  Copy or symlink [vim/plugin/scd.vim](vim/plugin/scd.vim)
    file to the `~/.vim/plugin/` directory or source it from `.vimrc`.

2.  If `scd` is not in the PATH, set the `g:scd_command` variable in `.vimrc`
    to specify its location.
    ```VimL
    let g:scd_command = '/path/to/scd'
    ```

3.  When Vim is set to use zsh for system commands `:set shell=/bin/zsh`, scd
    aliases can be expanded in Vim command mode, as in `:e ~foo/file.txt`.
    Allow this by adding the following line to `~/.zshenv`
    ```sh
    if [[ -s ~/.scdalias.zsh ]]; then source ~/.scdalias.zsh; fi
    ```

## Examples

```VimL
" recursively index ~/.vim/ and its subdirectories
:Scd -ar ~/.vim

" jump to the ~/.vim/ftplugin/ directory
:Scd vi ftpl

" change to the most recently visited doc directory
:Scd doc

" show selection menu with directories ranked by likelihood
:Scd -v

" same as Scd, but use the :lcd Vim command
:Slcd

" complete scd-defined directory aliases
:Scd <Tab>
```


## Installation as IPython extension

1. Copy or symlink [ipython/ipy_scd.py](ipython/ipy_scd.py)
   to some directory in Python module path.

2. In IPython terminal session do `%load_ext ipy_scd`
   to define the `%scd` magic command.  This also modifies the `%cd`,
   `%pushd`, `%popd` magics to add directories to the scd index.  To load
   `ipy_scd` for every IPython session, modify
   `.../profile_default/ipython_config.py` so that it contains
   ```Python
   c.TerminalIPythonApp.extensions = ['ipy_scd']
   ```

   In IPython 0.10, which does not support extensions, import `ipy_scd` from
   the `~/.ipython/ipy_user_conf.py` startup file.  This should activate the
   `%scd` magic just as above.

3. If `scd` is not in the PATH, its location can be defined with
   ```Python
   import ipy_scd
   ipy_scd.scd_executable = '/path/to/scd'

## Examples

```Python
# recursively index ~/.local/ and its subdirectories
%scd -ar ~/.local

# jump to the site-packages directory (if exists in ~/.local)
%scd site pack
```

# FILES

<dl><dt>
~/.scdhistory</dt><dd>
    time-stamped index of visited directories.</dd><dt>

~/.scdalias.zsh</dt><dd>
    scd-generated definitions of directory aliases.</dd>
</dl>

# ENVIRONMENT

<dl><dt>
SCD_HISTFILE</dt><dd>
    path to the scd index file (by default ~/.scdhistory).</dd><dt>

SCD_HISTSIZE</dt><dd>
    maximum number of entries in the index (5000).  Index is trimmed when it
    exceeds <em>SCD_HISTSIZE</em> by more than 20%.</dd><dt>

SCD_MENUSIZE</dt><dd>
    maximum number of items for directory selection menu (20).</dd><dt>

SCD_MEANLIFE</dt><dd>
    mean lifetime in seconds for exponential decay of directory
    likelihood (86400).</dd><dt>

SCD_THRESHOLD</dt><dd>
    threshold for cumulative directory likelihood.  Directories with
    a lower likelihood compared to the best match are excluded (0.005).
    </dd><dt>

SCD_SCRIPT</dt><dd>
    command script file where scd writes the final <code>cd</code>
    command.  This variable must be defined when scd runs in its own
    process rather than as a shell function.  It is up to the
    scd caller to use the output in <em>SCD_SCRIPT</em>.</dd>
</dl>
