#!/usr/bin/env python

"""This module defines the "%scd" magic command in an IPython session.
The %scd or smart-cd command can find and change to any directory,
without having to know its exact path.  In addition, this module updates
the %cd, %popd, %pushd magic commands so that they record the visited
directory in the scd index file.

The scd executable script must be in the system PATH or the
ipy_scd.scd_executable  must be set to its full path.

To define the %scd magic in every ipython session in
IPython 0.10 or earlier, import this module from the
~/.ipython/ipy_user_conf.py file.

For IPython 0.11 or later, add this module to the
c.InteractiveShellApp.extensions list in the
IPYTHON/profile_default/ipython_config.py file.
"""

import re
import IPython

ipyversion = list(map(int, re.split(r'(\d+)', IPython.__version__)[1::2]))
isipython010 = ipyversion < [0, 11]
isipython012 = (ipyversion < [0, 13]) and not isipython010
isipython013 = not (ipyversion < [0, 13])

class _cdcommands:
    cd = None
    pushd = None
    popd = None
    if isipython013:
        from IPython.core.magics import OSMagics
        cd_doc = OSMagics.cd.__doc__
        pushd_doc = OSMagics.pushd.__doc__
        popd_doc = OSMagics.popd.__doc__
    else:
        if isipython010:
            from IPython.Magic import Magic
        else:
            from IPython.core.magic import Magic
        cd_doc = Magic.magic_cd.__doc__
        pushd_doc = Magic.magic_pushd.__doc__
        popd_doc = Magic.magic_popd.__doc__
    pass


def whereisexecutable(program):
    '''Return a list of files in the system PATH executable by the user.

    program  -- command name that is looked for in the PATH

    Return a list of absolute paths to the program.  When program
    contains any path components, just check if that file is executable.
    '''
    import os
    isexecutable = lambda f: os.access(f, os.X_OK) and os.path.isfile(f)
    ppath, pname = os.path.split(program)
    rv = []
    if ppath:
        rv += [program]
    else:
        rv += [os.path.join(d, program)
                for d in os.environ['PATH'].split(os.pathsep)]
    rv = [os.path.abspath(f) for f in rv if isexecutable(f)]
    return rv


# full path to the scd_executable or an empty string when not found
scd_executable = (whereisexecutable('scd') + [''])[0]


def do_scd(self, arg):
    '''scd -- smart change to a recently used directory
    usage: scd [options] [pattern1 pattern2 ...]
    Go to a directory path that contains all fixed string patterns.  Prefer
    recent or frequently visited directories as found in the directory index.
    Display a selection menu in case of multiple matches.

    Options:
    -a, --add         add current or specified directories to the index.
    --unindex         remove current or specified directories from the index.
    -r, --recursive   apply options --add or --unindex recursively.
    --alias=ALIAS     create alias for the current or specified directory and
                      store it in ~/.scdalias.zsh.
    --unalias         remove ALIAS definition for the current or specified
                      directory from ~/.scdalias.zsh.
    -A, --all         include all matching directories.  Disregard matching by
                      directory alias and filtering of less likely paths.
    --list            show matching directories and exit.
    -v, --verbose     display directory rank in the selection menu.
    -h, --help        display this message and exit.
    '''
    import os
    import subprocess
    import tempfile
    import shlex
    scdfile = tempfile.NamedTemporaryFile('r')
    env = dict(os.environ)
    env['SCD_SCRIPT'] = scdfile.name
    args = [scd_executable] + shlex.split(str(arg))
    retcode = subprocess.call(args, env=env)
    cmd = scdfile.read()
    if retcode == 0 and cmd.startswith('cd '):
        _cdcommands.cd(cmd[3:])
        cwd = shlex.split(cmd[3:])[0]
        _scd_record_cwd(cwd)
    return


def do_cd(self, arg):
    rv = _cdcommands.cd(arg)
    _scd_record_cwd()
    return rv
do_cd.__doc__ = _cdcommands.cd_doc


def do_pushd(self, arg):
    rv = _cdcommands.pushd(arg)
    _scd_record_cwd()
    return rv
do_pushd.__doc__ = _cdcommands.pushd_doc


def do_popd(self, arg):
    rv = _cdcommands.popd(arg)
    _scd_record_cwd()
    return rv
do_popd.__doc__ = _cdcommands.popd_doc


# Function for loading the scd magic with the 0.11 or later API

def load_ipython_extension(ipython):
    '''Define the scd command and overloads of cd, pushd, popd that record
    new visited paths to the scdhistory file.

    When flag is False, revert to the default behavior.
    '''
    _raiseIfNoExecutable()
    if _cdcommands.cd is None:
        if isipython013:
            _cdcommands.cd = ipython.find_magic('cd')
            _cdcommands.pushd = ipython.find_magic('pushd')
            _cdcommands.popd = ipython.find_magic('popd')
        else:
            _cdcommands.cd = ipython.magic_cd
            _cdcommands.pushd = ipython.magic_pushd
            _cdcommands.popd = ipython.magic_popd
    ipython.define_magic('scd', do_scd)
    ipython.define_magic('cd', do_cd)
    ipython.define_magic('pushd', do_pushd)
    ipython.define_magic('popd', do_popd)
    global _scd_active
    _scd_active = True
    return


def unload_ipython_extension(ipython):
    if hasattr(ipython, 'magic_scd'):
        delattr(ipython, 'magic_scd')
    global _scd_active
    _scd_active = False
    return

# This function activates or disables scd magic in IPython 0.10

def scdactivate(flag):
    '''Define the scd command and overloads of cd, pushd, popd that record
    new visited paths to the scdhistory file.

    When flag is False, undefine the scd command and revert all
    cd-related commands to their default behavior.
    '''
    global _scd_active
    import IPython.ipapi
    ip = IPython.ipapi.get()
    if _cdcommands.cd is None:
        _cdcommands.cd = ip.IP.magic_cd
        _cdcommands.pushd = ip.IP.magic_pushd
        _cdcommands.popd = ip.IP.magic_popd
    if flag:
        _raiseIfNoExecutable()
        ip.expose_magic('scd', do_scd)
        ip.expose_magic('cd', do_cd)
        ip.expose_magic('pushd', do_pushd)
        ip.expose_magic('popd', do_popd)
        _scd_active = True
    else:
        ipshell = ip.IP
        if hasattr(ipshell, 'magic_scd'):
            delattr(ipshell, 'magic_scd')
        _scd_active = False
    return
_scd_active = False

# Disable for later ipython versions
if not isipython010:
    del scdactivate

def _scd_record_cwd(cwd=None):
    if not _scd_active:  return
    import os
    import subprocess
    global _scd_last_directory
    if cwd is None:
        cwd = os.getcwd()
    if cwd == _scd_last_directory:
        return
    _scd_last_directory = cwd
    args = [scd_executable, '--add', cwd]
    subprocess.call(args)
    return
_scd_last_directory = ''


def _raiseIfNoExecutable():
    emsg = ("scd executable not found.  Place it to a directory in the "
            "PATH or define the ipy_scd.scd_executable variable.")
    if not scd_executable:
        raise RuntimeError(emsg)
    return


if isipython010 and scd_executable:
    scdactivate(True)
