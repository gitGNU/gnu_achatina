# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Class: ::Achatina::Error
#
# This class will generate error message using template specified in configuration of
# application. If no template is specified, it will use built-in templates from
# lib/AchatinaX.X/templates directory.
#
# Example usage:
#
# > method do_get {request session config} {
# >     if {$error} {
# >         set error_obj [::Achatina::Error new 500 {Something bad happened} $config
# >         return [$error_obj get_response_obj]
# >     }
# > }

oo::class create ::Achatina::Error {
    # Constructor: new
    #
    # Creates error object.
    #
    # Parameters:
    #
    #   - Status code
    #   - Error contents
    #   - Configuration dict
    constructor {status_ contents_ options_ config_} {
        variable status $status_
        variable contents $contents_
        variable options $options_
        variable config $config_
    }

    # Function: get_response_obj
    #
    # Returns <::Achatina::Response> object which contains error message.
    #
    # It takes no arguments.
    method get_response_obj {} {
        variable config
        variable contents
        variable status
        variable options

        set tmpl {}
        set tmpl_obj {}
        set response_obj {}
        set status_code {wrong_status_code}

        # Get numeric status code from status (for example: "404" from "404 Not Found")
        regexp {^\d+} $status status_code

        if {[$config get_param app error templates $status_code] ne ""} {
            # Custom error templates are set
            set tmpl [$config get_param app error templates $status_code]
        }

        if {$tmpl eq ""} {
            # Use default error templates
            switch -exact -- $status {
                500 {
                    set tmpl [file join $::Achatina::lib_dir templates 500.xxx]
                }

                404 {
                    set tmpl [file join $::Achatina::lib_dir templates 404.xxx]
                }

                403 {
                    set tmpl [file join $::Achatina::lib_dir templates 403.xxx]
                }

                default {
                    set tmpl [file join $::Achatina::lib_dir templates default_nf]
                }
            }

            try {
                set tmpl_obj [::Achatina::Template new $tmpl $config]
            } on error {err} {
                # Unable to load built-in template
                set response_obj [::Achatina::Response new "Your Achatina installation is broken, could not load &quo;$tmpl&quo;"]
                $response_obj set_status 500
                return $response_obj
            }
        } else {
            try {
                set tmpl_obj [::Achatina::Template new $tmpl $config]
            } on error {err} {
                # Unable to load specified template
                switch -exact -- $status {
                    500 {
                        set tmpl [file join $::Achatina::lib_dir templates 500_nf.xxx]
                    }

                    404 {
                        set tmpl [file join $::Achatina::lib_dir templates 404_nf.xxx]
                    }

                    403 {
                        set tmpl [file join $::Achatina::lib_dir templates 403_nf.xxx]
                    }

                    default {
                        set tmpl [file join $::Achatina::lib_dir templates default_nf.xxx]
                    }
                }

                try {
                    set tmpl_obj [::Achatina::Template new $tmpl $config]
                } on error {err} {
                    # Unable to load built-in template
                    set response_obj [::Achatina::Response new "Your Achatina installation is broken, could not load &quo;$tmpl&quo;"]
                    $response_obj set_status 500
                    return $response_obj
                }
            }
        }

        set response_obj [::Achatina::Response new]

        $response_obj set_status $status

        $tmpl_obj set_param err $contents
        $tmpl_obj set_param opts $options
        # Normalize status
        $tmpl_obj set_param status [$response_obj get_status]

        $response_obj set_contents [$tmpl_obj get_output]

        return $response_obj
    }
}
