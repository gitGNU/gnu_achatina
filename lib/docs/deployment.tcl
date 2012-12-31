# Copyright (c) 2012, 2013 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Class: ::Achatina::Docs::Deployment
#
# There are three ways to deploy Achatina application: you can use built-in httpd server,
# use built-in httpd server through reverse proxy or use CGI.
#
# Achatina's CGI interface was tested under IIS8 and Apache 2.4.
#
# CGI deployment:
#
# 1. You need to hide *.yml files from user
#
# 2. Your webserver should treat *.tcl files as CGI scripts
#
# 3. In most webservers you need to modify shebang in app.tcl file
