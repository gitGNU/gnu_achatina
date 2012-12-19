# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::Achatina {
    variable is_cgi false
    variable is_httpd false
    variable is_scgi false
}

# Class: ::Achatina::Application
#
# Main application class, your application will not work if you will not instantiate it.
#
# Example:
# > oo::class create ::Foobar {
# >     constructor {config} {
# >     }
# >
# >     method set_routes {router config} {
# >         $router add_route / ::Class1
# >         $router add_route /foo ::Class2
# >     }
# > }
# >
# > oo::class create ::Class1 {
# >     constructor {config} {
# >     }
# >
# >     method do_get {request session config} {
# >         return "hello!"
# >     }
# > }
# >
# > oo::class create ::Class2 {
# >     constructor {config} {
# >     }
# >
# >     method do_all {request session config} {
# >         return "bar!"
# >     }
# > }
# >
# > set application [Achatina::Application new {::Foobar} {../config.yml}]
#
# Note that ::Class1 and ::Class2 have to implement at least one of following methods :
# "do_get", "do_post" or "do_all". Class ::Fobar have to implement "set_routes".
oo::class create ::Achatina::Application {
    # Constructor: new
    #
    # Creates application.
    #
    # Parameters:
    #
    #   - Name of your application's startup class
    #   - Path to configuration file
    constructor {startup_class config_file} {
        set error_string {}

        set code {
            if {[$config get_param app session secret_key] eq "cHaNgE_mE"} {
                error {Please change session's secret_key (app->session->secret_key option)}
            }

            set request [::Achatina::Request new $interface_in]
            set session [::Achatina::Session new $request $config]
            set router [::Achatina::Router new]

            set startup [$startup_class new $config]
            $startup set_routes $router $config

            set response_obj [$router dispatch $request $session $config]
            $response_obj output__ $session $request $router $interface_out
        }

        if {![info exists ::argv0]} {
            set ::argv0 .
        }

        if {[info exists ::env(GATEWAY_INTERFACE)] && [regexp {^CGI} $::env(GATEWAY_INTERFACE)]} {
            set ::Achatina::is_cgi true
            set ::Achatina::is_httpd false
            set ::Achatina::is_scgi false

            source [file join $::Achatina::lib_dir interfaces cgi.tcl]

            set interface [::Achatina::Interfaces::Cgi new]
            $interface go $code $startup_class $config_file
        } else {
            set ::Achatina::is_cgi flase
            set ::Achatina::is_httpd true
            set ::Achatina::is_scgi false

            source [file join $::Achatina::lib_dir interfaces httpd.tcl]

            set interface [::Achatina::Interfaces::Httpd new]
            $interface go $code $startup_class $config_file
        }


    }
}