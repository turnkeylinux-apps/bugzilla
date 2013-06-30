Bugzilla - Bug Tracking System
==============================

`Bugzilla`_ is a Web-based general-purpose bugtracker and testing tool
originally developed and used by the Mozilla project. One of Bugzilla's
major attractions to developers is its lightweight implementation and
speed. Many projects use it to track feature requests as well. Bugs can
be submitted by anybody, and will be assigned to a particular developer.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Bugzilla configurations:
   
   - Installed from package management. See /var/www for links to file
     paths.
   - Periodically collect statistics and execute *whine*.
   - Suppress annoying new version messages (irrelevant due to package
     being managed by APT).
   - Includes support for dependency graphs and documentation.

- SSL support out of the box.
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, MySQL and Postfix.

Initial configuration: http://*appliance\_ip*/editparams.cgi

- Required settings (exemplary):
   
   - Maintainer: **admin@example.com**
   - URLBase: **http://bugs.example.com/** or **http://*appliance\_ip*/**
   - SSLBase: **https://bugs.example.com** or **https://*appliance\_ip*/**

-  Email (exemplary):
   
   - MailFrom: **bugzilla@example.com**

Credentials *(passwords set at first boot)*
-------------------------------------------

- Webmin, Webshell, SSH, MySQL: username **root**
- Bugzilla:
   
   - username is email set at first boot
   - customize via: http://*appliance\_ip*/editusers.cgi?action=edit&userid=1


.. _Bugzilla: http://www.bugzilla.org/
.. _TurnKey Core: http://www.turnkeylinux.org/core
