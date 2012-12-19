# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::Achatina::Interfaces {}

# Class: ::Achatina::Interfaces::Httpd
#
# You shouldn't do anything with this class, it will be created automatically.
#
# When GATEWAY_INTERFACE environment variable is not present then http server will
# be started. Achatina is using Dandelion as its webserver.
oo::class create ::Achatina::Interfaces::Httpd {
    constructor {} {
        package require dandelion_plus
    }

    method go {code_ startup_class_ config_file} {
        variable code $code_
        variable startup_class $startup_class_
        variable config {}

        source [file join $::Achatina::lib_dir interfaces httpd input.tcl]
        source [file join $::Achatina::lib_dir interfaces httpd output.tcl]

        set config [::Achatina::Configuration new $config_file]
        set static_dir [file normalize [file join [file dirname [file normalize $::argv0]] [$config get_param app httpd static_files_path]]]
        set bind [$config get_param app httpd bind]
        set max_req [$config get_param app httpd max_request_size]

        proc handle {sock headers settings body} {
            variable code
            variable startup_class
            variable config

            if {[::dandelion_plus::try_file $sock $headers $settings]} {
                return
            }

            # File not found, try to find appropriate route

            set interface_out [::Achatina::Interfaces::Httpd::Output new $sock]
            set interface_in [::Achatina::Interfaces::Httpd::Input new $sock $headers $settings $body]

            if {[catch {eval $code} error_string] != 0} {
                # 500
                set error_obj [::Achatina::Error new 500 $error_string $config]
                set response_obj [$error_obj get_response_obj]

                if {[info exists session]} {
                    $response_obj output__ $session {} {} $interface_out
                } else {
                    $response_obj output__ {} {} {} $interface_out
                }

                $error_obj destroy
                $response_obj destroy
            }

            if {[info exists request]     } { $request      destroy }
            if {[info exists session]     } { $session      destroy }
            if {[info exists router]      } { $router       destroy }
            if {[info exists startup]     } { $startup      destroy }
            if {[info exists interface_in]} { $interface_in destroy }

            $interface_out destroy

            return
        }

        puts {Starting Dandelion...}

        ::dandelion_plus::init doc_root $static_dir handler "[self object]::handle" port 8080 static_fail 0 addr $bind limit $max_req
        vwait forever
    }


}