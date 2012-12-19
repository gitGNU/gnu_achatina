# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Class: ::Achatina::Configuration
#
# This is configuration class, it will be instantiated automatically when you create <::Achatina::Application> object.
oo::class create ::Achatina::Configuration {
    # Constructor: new
    #
    # Creates configuration object and loads configuration from specified YAML file.
    #
    # Parameters:
    #
    #   - Path to configuration file
    constructor {config_file} {
        variable filename
        variable yaml_file
        variable configuration_dict {}

        package require yaml

        if {$config_file ne ""} {
            set filename [file normalize [file join [file dirname [file normalize $::argv0]] $config_file]]

            catch {set fp [open $filename r]}

            set yaml_file [read $fp]
            close $fp

            set configuration_dict [::yaml::yaml2dict -stream $yaml_file]
        }

        if {![dict exists $configuration_dict app httpd static_files_path]} {
            dict set configuration_dict app httpd static_files_path ../static
        }

        if {![dict exists $configuration_dict app port]} {
            dict set configuration_dict app httpd port 8080
        }

        if {![dict exists $configuration_dict app bind]} {
            dict set configuration_dict app httpd bind 0
        }

        if {![dict exists $configuration_dict app max_request_size]} {
            dict set configuration_dict app httpd max_request_size 10485760
        }

        if {![dict exists $configuration_dict app error templates]} {
            dict set configuration_dict app error templates {}
        }

        if {![dict exists $configuration_dict app template extension]} {
            dict set configuration_dict app template extension xxx
        }

        if {![dict exists $configuration_dict app template path]} {
            dict set configuration_dict app template path ../views
        }

        if {![dict exists $configuration_dict app session seconds]} {
            dict set configuration_dict app session seconds 31536000
        }

        if {![dict exists $configuration_dict app session algorithm]} {
            dict set configuration_dict app session algorithm ripemd160
        }

        if {![dict exists $configuration_dict app session secret_key]} {
            dict set configuration_dict app session secret_key cHaNgE_mE
        }

        if {![dict exists $configuration_dict app session cookie_name]} {
            dict set configuration_dict app session cookie_name __MURIS_SESSION
        }
    }

    # Function: get_params
    #
    # Returns dictionary containing configuration values.
    #
    # It takes no arguments.
    method get_params {} {
        variable configuration_dict
        return $configuration_dict
    }

    # Function: get_param
    #
    # Returns string containing requested configuration param.
    #
    # Example:
    #
    # > $config get_param app httpd static_files_path
    method get_param {args} {
        variable configuration_dict

        if {[dict exists $configuration_dict {*}$args]} {
            return [dict get $configuration_dict {*}$args]
        }

        return
    }
}
