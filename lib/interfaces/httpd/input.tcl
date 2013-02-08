# Copyright (c) 2012, 2013 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::Achatina::Interfaces::Httpd {}

oo::class create ::Achatina::Interfaces::Httpd::Input {
    constructor {args} {
        package require query_plus

        variable handle {}
        variable headers {}
        variable settings {}
        variable cookies [::query_plus::get_cookies $headers]
        variable body {}
        variable params_dict {}

        # Validate arguments, note that potential error will not be catched by anything
        if {[catch {set handle [dict get $args -sock]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::Input constructor"
        }

        if {[catch {set headers [dict get $args -headers]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::Input constructor"
        }

        if {[catch {set settings [dict get $args -settings]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::Input constructor"
        }

        if {[catch {set body [dict get $args -body]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::Input constructor"
        }

        ### set headers ###
        dict set headers REMOTE_ADDR [lindex [fconfigure $handle -peername] 0]
        dict set headers REQUEST_METHOD [string tolower [dict get $headers REQUEST_METHOD]]
        dict set headers __PROTOCOL__ {http}
    }

    method get_cookie {c} {
        variable cookies

        if {[dict exists $cookies $c]} {
            return [dict get $cookies $c]
        }

        return
    }

    method get_headers {} {
        variable headers
        return $headers
    }

    method get_params {} {
        variable params_dict
        variable headers
        variable body

        # Load dict from cache if it exists
        if {$params_dict ne ""} {
            return $params_dict
        }

        if {[dict get $headers REQUEST_METHOD] eq "post"} {
            set nvlist [::query_plus::nvlist [dict get $headers CONTENT_TYPE] $body]
        } else {
            set nvlist [::query_plus::nvlist {} [dict get $headers QUERY_STRING]]
        }

        if {[dict exists $headers CONTENT_TYPE] && [regexp {^multipart/form-data} [dict get $headers CONTENT_TYPE]]} {
            # multipart/form-data
            dict for {k v} $nvlist {
                set values_list {}

                dict for {value meta} $v {
                    set value_dict [dict create value $value metadata $meta]
                    lappend values_list $value_dict
                }

                dict set params_dict $k $values_list
           }
        } else {
            # application/x-www-form-urlencoded and GET
            dict for {k v} $nvlist {
                set values_list {}

                foreach value $v {
                    set value_dict [dict create value $value metadata {}]
                    lappend values_list $value_dict
                }

                dict set params_dict $k $values_list
            }
        }

        # Here you are :P
        return $params_dict
    }
}