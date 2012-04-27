#!/usr/bin/python
"""Set Bugzilla email and password

Option:
    --email=    unless provided, will ask interactively
    --pass=     unless provided, will ask interactively

"""

import sys
import getopt
from os.path import *
import subprocess
from subprocess import PIPE

from dialog_wrapper import Dialog
from mysqlconf import MySQL

def fatal(s):
    print >> sys.stderr, "Error:", s
    sys.exit(1)

def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email='])
    except getopt.GetoptError, e:
        usage(e)

    password = ""
    email = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val

    if not email:
        d = Dialog('TurnKey Linux - First boot configuration')
        email = d.get_email(
            "Bugzilla Email",
            "Enter email address for the Bugzilla 'admin' account.",
            "admin@example.com")

    if not password:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        password = d.get_password(
            "Bugzilla Password",
            "Enter new password for the Bugzilla '%s' account." % email)
 
    command = [join(dirname(__file__), 'bz_crypt.pl'), password]
    p = subprocess.Popen(command, stdin=PIPE, stdout=PIPE, shell=False)
    stdout, stderr = p.communicate()
    if stderr:
        fatal(stderr)

    cryptpass = stdout.strip()

    m = MySQL()
    m.execute('UPDATE bugzilla3.profiles SET cryptpassword=\"%s\" WHERE userid=\"1\";' % cryptpass)
    m.execute('UPDATE bugzilla3.profiles SET login_name=\"%s\" WHERE userid=\"1\";' % email)

if __name__ == "__main__":
    main()

