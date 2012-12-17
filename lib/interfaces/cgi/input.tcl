# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::Achatina::Interfaces::Cgi {}

oo::class create ::Achatina::Interfaces::Cgi::Input {
    constructor {handle} {
        package require ncgi

        variable headers {}
        variable params_dict {}


        ::ncgi::parse

        ### set headers ###

        if {[info exists ::env(REQUEST_METHOD)]} {
             dict set headers REQUEST_METHOD [string tolower $::env(REQUEST_METHOD)]
        }

        if {[info exists ::env(QUERY_STRING)]} {
            dict set headers QUERY_STRING $::env(QUERY_STRING)
        }

        if {[info exists ::env(SERVER_NAME)]} {
            dict set headers SERVER_NAME $::env(SERVER_NAME)
        }

        if {[info exists ::env(SERVER_PORT)]} {
            dict set headers SERVER_PORT $::env(SERVER_PORT)
        }

        if {[info exists ::env(SCRIPT_NAME)]} {
            dict set headers SCRIPT_NAME $::env(SCRIPT_NAME)
        }

        dict set headers __PROTOCOL__ {http}

        if {[info exists ::env(HTTPS)]} {
            if {$::env(HTTPS) == 1} {
                dict set headers __PROTOCOL__ {https}
            }
        }

        # IIS has broken PATH_INFO, it contains script name
        if {[info exists ::env(PATH_INFO)]} {
            if {[info exists ::env(SERVER_SOFTWARE)] && [info exists ::env(SCRIPT_NAME)]} {
                if {[regexp {^Microsoft-IIS} $::env(SERVER_SOFTWARE)]} {
                    set path {}
                    # Delete script name from path
                    if {[regsub "^$::env(SCRIPT_NAME)" $::env(PATH_INFO) {} path] > 0} {
                        dict set headers PATH_INFO $path
                    }
                }
            }
            if {![dict exists $headers PATH_INFO]} {
                dict set headers PATH_INFO $::env(PATH_INFO)
            }
        }
    }

    method get_cookie {c} {
        return [lindex [::ncgi::cookie $c] 0]
    }

    method get_headers {} {
        variable headers
        return $headers
    }

    method get_params {} {
        variable params_dict

        # Load dict from cache if it exists
        if {$params_dict ne ""} {
            return $params_dict
        }

        set nvlist [::ncgi::nvlist]

        if {[regexp {^multipart/form-data} [::ncgi::type]]} {
            # multipart/form-data
            for {set i 0} {$i < [llength $nvlist]} {set i [expr {$i+2}]} {
                set values_list {}
                set key [lindex $nvlist $i]
                set value [lindex [lindex $nvlist [expr {$i + 1}]] 1]
                set metadata [lindex [lindex $nvlist [expr {$i + 1}]] 0]

                # Note that $metadata is already formatted like dict
                set value_dict [dict create value $value metadata $metadata]

                # Add additional value to already existing key
                if {[dict exists $params_dict $key]} {
                    set values_list [dict get $params_dict $key]
                }

                # Done!
                lappend values_list $value_dict
                dict set params_dict $key $values_list
           }
        } else {
            # application/x-www-form-urlencoded and GET
            for {set i 0} {$i < [llength $nvlist]} {set i [expr {$i+2}]} {
                set values_list {}
                set key [lindex $nvlist $i]
                set value [lindex $nvlist [expr {$i + 1}]]
                set value_dict [dict create value $value metadata {}]

                # Add additional value to already existing key
                if {[dict exists $params_dict $key]} {
                    set values_list [dict get $params_dict $key]
                }

                # Done!
                lappend values_list $value_dict
                dict set params_dict $key $values_list
            }
        }

        # Here you are :P
        return $params_dict
    }
}