# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package provide Achatina 1.0;

namespace eval ::Achatina {
    variable lib_dir [file dirname [file normalize [info script]]]
}

# Load Achatina
source [file join $::Achatina::lib_dir application.tcl]
source [file join $::Achatina::lib_dir error.tcl]
source [file join $::Achatina::lib_dir configuration.tcl]
source [file join $::Achatina::lib_dir request.tcl]
source [file join $::Achatina::lib_dir response.tcl]
source [file join $::Achatina::lib_dir route.tcl]
source [file join $::Achatina::lib_dir router.tcl]
source [file join $::Achatina::lib_dir session.tcl]
source [file join $::Achatina::lib_dir template.tcl]