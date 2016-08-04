#!/usr/bin/env python

"""This module defines the "%scd" magic command in an IPython session.
The %scd or smart-cd command can find and change to any directory,
without having to know its exact path.  In addition, this module updates
the %cd, %popd, %pushd magic commands so that they record the visited
directory in the scd index file.

The scd executable script must be in the system PATH or the
ipy_scd.scd_executable  must be set to its full path.

To define the %scd magic for every IPython session, add this module
to the c.TerminalIPythonApp.extensions list in the
IPYTHON/profile_default/ipython_config.py file.
"""

import IPython

# Require IPython version 0.13 or later --------------------------------------

ipyversion = []
for w in IPython.__version__.split('.'):
    if not w.isdigit():  break
    ipyversion.append(int(w))

assert ipyversion >= [0, 13], "ipy_scd requires IPython 0.13 or later."

# We have a recent IPython here ----------------------------------------------

import os
import subprocess
import tempfile
import shlex

from IPython.core.magic import Magics, magics_class, line_magic


class _cdcommands:
    """Namespace class for saving original cd-related commands."""
    cd = None
    pushd = None
    popd = None
    pass


def whereisexecutable(program):
    '''Return a list of files in the system PATH executable by the user.

    program  -- command name that is looked for in the PATH

    Return a list of absolute paths to the program.  When program
    contains any path components, just check if that file is executable.
    '''
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


@magics_class
class SCDMagics(Magics):

    @line_magic
    def scd(self, arg):
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

    from IPython.core.magics import OSMagics

    @line_magic
    def cd(self, arg):
        rv = _cdcommands.cd(arg)
        _scd_record_cwd()
        return rv
    cd.__doc__ = OSMagics.cd.__doc__


    @line_magic
    def pushd(self, arg):
        rv = _cdcommands.pushd(arg)
        _scd_record_cwd()
        return rv
    pushd.__doc__ = OSMagics.pushd.__doc__


    @line_magic
    def popd(self, arg):
        rv = _cdcommands.popd(arg)
        _scd_record_cwd()
        return rv
    popd.__doc__ = OSMagics.popd.__doc__

    del OSMagics


# Function for loading the scd magic with the 0.11 or later API

def load_ipython_extension(ipython):
    '''Define the scd command and overloads of cd, pushd, popd that record
    new visited paths to the scdhistory file.

    When flag is False, revert to the default behavior.
    '''
    _raiseIfNoExecutable()
    if _cdcommands.cd is None:
        _cdcommands.cd = ipython.find_magic('cd')
        _cdcommands.pushd = ipython.find_magic('pushd')
        _cdcommands.popd = ipython.find_magic('popd')
    ipython.register_magics(SCDMagics)
    global _scd_active
    _scd_active = True
    return


def unload_ipython_extension(ipython):
    global _scd_active
    _scd_active = False
    ipython.magics_manager.magics['line'].pop('scd', None)
    if _cdcommands.cd is not None:
        ipython.register_magic_function(_cdcommands.cd)
        ipython.register_magic_function(_cdcommands.pushd)
        ipython.register_magic_function(_cdcommands.popd)
    return


def _scd_record_cwd(cwd=None):
    if not _scd_active:  return
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
