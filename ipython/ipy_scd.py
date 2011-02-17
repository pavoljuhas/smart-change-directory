#!/usr/bin/env python
# $Id$

import IPython.ipapi
ip = IPython.ipapi.get()


def do_scd(self, arg):
    import os
    import subprocess
    import tempfile
    import shlex
    scdfile = tempfile.NamedTemporaryFile('r')
    env = dict(os.environ)
    env['SCD_SCRIPT'] = scdfile.name
    args = ['scd'] + shlex.split(arg)
    retcode = subprocess.call(args, env=env)
    cmd = scdfile.read()
    if retcode == 0 and cmd.startswith('cd '):
        ip.magic(cmd)
    return


ip.expose_magic('scd', do_scd)
