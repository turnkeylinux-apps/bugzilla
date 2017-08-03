#!/usr/bin/python
"""Set Bugzilla email and password

Option:
    --email=    unless provided, will ask interactively
    --pass=     unless provided, will ask interactively
    --outmail=  unless provided, will ask interactively
                DEFAULT="bugzilla-daemon@www.example.com"
"""

import sys
import getopt
import inithooks_cache
from os.path import *
import subprocess
from subprocess import PIPE
import json
import codecs

from dialog_wrapper import Dialog
from mysqlconf import MySQL

DEFAULT_OUTMAIL = 'bugzilla-daemon@example.com'

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
                                       ['help', 'pass=', 'email=', 'outmail='])
    except getopt.GetoptError, e:
        usage(e)

    password = ""
    email = ""
    outmail = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val
        elif opt == '--outmail':
            outmail = val

    if not email:
        d = Dialog('TurnKey Linux - First boot configuration')
        email = d.get_email(
            "Bugzilla Email",
            "Enter email address for the Bugzilla 'admin' account.",
            "admin@example.com")

    inithooks_cache.write('APP_EMAIL', email)

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
    m.execute('UPDATE bugzilla.profiles SET cryptpassword=\"%s\" WHERE userid=\"1\";' % cryptpass)
    m.execute('UPDATE bugzilla.profiles SET login_name=\"%s\" WHERE userid=\"1\";' % email)

    if not outmail:
        if 'd' not in locals():
            d = Dialog('Turnkey Linux - First boot configuration')

        outmail = d.get_email(
            "Bugzilla Daemon Email",
            "Enter email address for Bugzilla to send email from",
            "{}".format(DEFAULT_OUTMAIL))

    if outmail == "DEFAULT":
        outmail = "{}".format(DEFAULT_OUTMAIL)

    with open('/var/www/bugzilla/data/params.json', 'r+') as fob:
        data = json.load(fob)
        data['mailfrom'] = outmail
        fob.seek(0)
        json.dump(data, fob, indent = 4)

if __name__ == "__main__":
    main()

