# Copyright (c) 2012, 2013 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::Achatina::Interfaces {}

# Class: ::Achatina::Interfaces::Cgi
#
# You shouldn't do anything with this class, it will be created automatically.
#
# When GATEWAY_INTERFACE environment variable is present then Achatina will serve
# your page using CGI protocol.
oo::class create ::Achatina::Interfaces::Cgi {
    constructor {} {
    }

    method go {args} {
        # Validate arguments, note that potential error will not be catched by anything
        if {[catch {set code [dict get $args -code]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Cgi::go"
        }

        if {[catch {set startup_class [dict get $args -class]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Cgi::go"
        }

        if {[catch {set config_file [dict get $args -config_file]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Cgi::go"
        }

        source [file join $::Achatina::lib_dir interfaces cgi input.tcl]
        source [file join $::Achatina::lib_dir interfaces cgi output.tcl]

        set interface_in [::Achatina::Interfaces::Cgi::Input new -handle stdin]
        set interface_out [::Achatina::Interfaces::Cgi::Output new -handle stdout]

        set config [::Achatina::Configuration new -config_file $config_file]

        try {
            eval $code
        } on error {err opts} {
            # 500
            set error_obj [::Achatina::Error new -status 500 -contents $err -options $opts -config $config]
            set response_obj [$error_obj get_response_obj]

            if {[info exists session]} {
                $response_obj output__ -session $session -interface_out $interface_out
            } else {
                $response_obj output__ -interface_out $interface_out
            }

            exit 1
       }

       exit 0
    }
}