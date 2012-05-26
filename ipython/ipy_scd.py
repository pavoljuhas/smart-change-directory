#!/usr/bin/env python
# $Id$

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

isipython010 = map(int, re.split(r'(\d+)', IPython.__version__)[1::2]) < [0, 11]

# isipython010 is True for IPython 0.10 or earlier
if isipython010:
    from IPython.Magic import Magic
else:
    from IPython.core.magic import Magic


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
    recently visited directories and directories with patterns in their tail
    component.  Display a selection menu in case of multiple matches.

    Options:
      -a, --add         add specified directories to the directory index
      --unindex         remove specified directories from the index
      -r, --recursive   applied options --add or --unindex recursively
      --alias=ALIAS     create alias for the current or specified directory and
                        store it in ~/.scdalias.zsh
      --unalias         remove ALIAS definition for the current or specified
                        directory from ~/.scdalias.zsh
      --list            show matching directories and exit
      -v, --verbose     display directory rank in the selection menu
      -h, --help        display this message and exit
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
        Magic.magic_cd(self, cmd[3:])
    return


def do_cd(self, arg):
    rv = Magic.magic_cd(self, arg)
    _scd_record_cwd()
    return rv
do_cd.__doc__ = Magic.magic_cd.__doc__


def do_pushd(self, arg):
    rv = Magic.magic_pushd(self, arg)
    _scd_record_cwd()
    return rv
do_pushd.__doc__ = Magic.magic_pushd.__doc__


def do_popd(self, arg):
    rv = Magic.magic_popd(self, arg)
    _scd_record_cwd()
    return rv
do_popd.__doc__ = Magic.magic_popd.__doc__

# Functions for loading and unloading scd magic using the 0.11 or later API

def load_ipython_extension(ipython):
    '''Define the scd command and overloads of cd, pushd, popd that record
    new visited paths to the scdhistory file.

    When flag is False, revert to the default behavior.
    '''
    _raiseIfNoExecutable()
    ipython.define_magic('scd', do_scd)
    ipython.define_magic('cd', do_cd)
    ipython.define_magic('pushd', do_pushd)
    ipython.define_magic('popd', do_popd)
    return


def unload_ipython_extension(ipython):
    if hasattr(ipython, 'magic_scd'):
        delattr(ipython, 'magic_scd')
    ipython.define_magic('cd', Magic.magic_cd)
    ipython.define_magic('pushd', Magic.magic_pushd)
    ipython.define_magic('popd', Magic.magic_popd)
    return

# This function activates or disables scd magic in IPython 0.10

def scdactivate(flag):
    '''Define the scd command and overloads of cd, pushd, popd that record
    new visited paths to the scdhistory file.

    When flag is False, undefine the scd command and revert all
    cd-related commands to their default behavior.
    '''
    import IPython.ipapi
    ip = IPython.ipapi.get()
    if flag:
        _raiseIfNoExecutable()
        ip.expose_magic('scd', do_scd)
        ip.expose_magic('cd', do_cd)
        ip.expose_magic('pushd', do_pushd)
        ip.expose_magic('popd', do_popd)
    else:
        ipshell = ip.IP
        if hasattr(ipshell, 'magic_scd'):
            delattr(ipshell, 'magic_scd')
        ip.expose_magic('cd', Magic.magic_cd)
        ip.expose_magic('pushd', Magic.magic_pushd)
        ip.expose_magic('popd', Magic.magic_popd)
    return

# Disable for later ipython versions
if not isipython010:
    del scdactivate

def _scd_record_cwd():
    import os
    import subprocess
    global _scd_last_directory
    cwd = os.getcwd()
    if cwd == _scd_last_directory:
        return
    _scd_last_directory = cwd
    args = [scd_executable, '--add', '.']
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
