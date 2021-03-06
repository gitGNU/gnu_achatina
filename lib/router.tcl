# Copyright (c) 2012, 2013 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Class: ::Achatina::Router
#
# Router class routes requests. You have to set routes in set_routes method of your
# startup class.
#
# Example:
# > oo::class create ::Foobar {
# >     constructor {config} {
# >     }
# >
# >     method set_routes {router config} {
# >         $router add_route -path / -class ::Something::Class1
# >         $router add_route -path {/:lol/abc} -class ::Something::Class2
# >     }
# > }
# >
# > set application [Achatina::Application new {::Foobar} {../config.yml}]
oo::class create ::Achatina::Router {
    # Constructor: new
    #
    # It takes no arguments.
    constructor {} {
        namespace path ::tcl::mathop

        variable routes {}
    }

    destructor {
        variable routes

        # Delete all routes
        foreach route $routes {
            $route destroy
        }
    }

    # Function: get_routes
    #
    # Returns list of routes.
    #
    # It takes no arguments.
    method get_routes {} {
        return $routes
    }

    # Function: add_route
    #
    # This method adds route to router object. Note that route can contain placeholder
    # (example route with placeholder "bar": "/foo/:bar". For this route requests like
    # "/foo/fsakopads" and "/foo/123" will match.
    #
    # You can escape placeholder using "\" character. For example, path "/foo/\:ph"
    # does not contain placeholder.
    #
    # Value of placeholder can be retrieved using <::Achatina::Request> object.
    #
    # Arguments to this method must form valid dictionary.
    #
    # Usage:
    #
    # > $router add_route -path path -class class_name
    #
    # Parameters:
    #
    #   - path - Route path
    #   - class - Name of handler class (it will be constructed by router)
    #
    # Example:
    #
    # > $router add_route -path / -class ::Foo::Bar
    method add_route {args} {
        variable routes

        # Validate arguments
        if {[catch {set path [dict get $args -path]}]} {
            error "Invalid arguments to ::Achatina::Router::add_route"
        }

        if {[catch {set class_ [dict get $args -class]}]} {
            error "Invalid arguments to ::Achatina::Router::add_route"
        }

        # List of named placeholders
        set placeholders_keys ""

        # Capture placeholders names
        set results [regexp -inline -all -- {/:(\w+)} $path]

        # We only need capture-groups, so we use every other list element
        for {set i 1} {$i < [llength $results]} {set i [+ $i 2]} {
            lappend placeholders_keys [lindex $results $i]
        }

        set route_regexp [my _quote_regexp $path]

        # Replace placeholders with (\w+), this regexp will honour placeholder
        # escaping with backslash
        regsub -all {/(?!\\\\)\\:(\w+)} $route_regexp {/(\w+)} route_regexp;
        # $route_regexp may contain something like this: {/\\\:foobar}
        regsub -all {/\\\\\\:} $route_regexp {/\:} route_regexp;

        set route_regexp "^$route_regexp\$"

        set class_methods [info class methods $class_]
        set r_methods {}

        foreach mth $class_methods {
            switch -exact -- $mth {
                do_post {
                    lappend r_methods post
                }

                do_get {
                    lappend r_methods get
                }

                do_all {
                    lappend r_methods all
                }
            }
        }

        foreach mth $r_methods {
            # Okay, now we can create route object
            set rt [::Achatina::Route new]

            $rt set_request_method $mth
            $rt set_path $path
            $rt set_class $class_
            $rt set_route_regexp $route_regexp
            $rt set_placeholders_keys $placeholders_keys

            lappend routes $rt
        }
    }

    # Function: does_route_exist
    #
    # It checks whether specified route exists. It returns boolean value, "true"
    # or "false".
    #
    # Usage:
    #
    # > $router does_route_exist -path path -method request_method
    #
    # Parameters:
    #
    #   - path - Route path
    #   - method - Request method
    #
    # Example:
    #
    # > $router does_route_exist -path / -method get
    method does_route_exist {args} {
        variable routes

        # Validate arguments
        if {[catch {set path [dict get $args -path]}]} {
            error "Invalid arguments to ::Achatina::Router::does_route_exist"
        }

        if {[catch {set method [dict get $args -method]}]} {
            error "Invalid arguments to ::Achatina::Router::does_route_exist"
        }

        # Normalize slashes
        regsub -all {/+} $path {/} path

        foreach route $routes {
            # Check whether route exists
            if {(($method eq [$route get_request_method]) || ([$route get_request_method] eq "all"))
               && [regexp [$route get_route_regexp] $path]} {
               return true;
            }
        }

        return false;
    }

    method _does_route_match {args} {
        variable routes

        # Validate arguments
        if {[catch {set request [dict get $args -request]}]} {
            error "Invalid arguments to ::Achatina::Router::_does_route_match"
        }

        if {[catch {set route [dict get $args -route]}]} {
            error "Invalid arguments to ::Achatina::Router::_does_route_match"
        }

        # Normalize slashes
        set path [$request get_header PATH_INFO]
        regsub -all {/+} $path {/} path

        # Check whether route matches
        if {(([$route get_request_method] eq [$request get_header REQUEST_METHOD]) || ([$route get_request_method] eq "all"))
           && [regexp [$route get_route_regexp] $path]} {
           return true;
        }

        return false;
    }

    method _quote_regexp {s} {
        return [regsub -all -- {\W} $s {\\\0}]
    }

    method dispatch__ {args} {
        variable routes

        # Validate arguments
        if {[catch {set request [dict get $args -request]}]} {
            error "Invalid arguments to ::Achatina::Router::dispatch"
        }

        if {[catch {set session [dict get $args -session]}]} {
            error "Invalid arguments to ::Achatina::Router::dispatch"
        }

        if {[catch {set config [dict get $args -config]}]} {
            error "Invalid arguments to ::Achatina::Router::dispatch"
        }

        foreach route $routes {
            # Try to match path against route regexp and request method
            if {[my _does_route_match -request $request -route $route]} {
                # We only need list of capture-groups of placeholders values, so we need to strip first element from list
                set placeholders_values [lrange [regexp -inline -- [$route get_route_regexp] [$request get_header PATH_INFO]] 1 end]
                set placeholders_keys [$route get_placeholders_keys]
                set placeholders_dict ""

                if {[llength $placeholders_keys] != [llength $placeholders_values]} {
                    # Well, it is very unlikely
                    error {Number of placeholders keys and values is not equal}
                }

                # Create dict from placeholders keys and values
                for {set i 0} {$i < [llength $placeholders_keys]} {incr i} {
                    dict set placeholders_dict [lindex $placeholders_keys $i] [lindex $placeholders_values $i]
                }

                # Store placeholders dict in request object
                $request set_placeholders__ $placeholders_dict

                set response {}
                set obj [[$route get_class] new $config]

                switch -exact -- [$request get_header REQUEST_METHOD] {
                    get {
                        if {[$route get_request_method] eq "get"} {
                            set response [$obj do_get $request $session $config]
                        } else {
                            set response [$obj do_all $request $session $config]
                        }
                    }

                    post {
                        if {[$route get_request_method] eq "post"} {
                            set response [$obj do_post $request $session $config]
                        } else {
                            set response [$obj do_all $request $session $config]
                        }
                    }

                    default {
                        set response [$obj do_all $request $session $config]
                    }
                }

                set response_obj {}

                try {
                    info object isa typeof $response ::Achatina::Response
                } on error err {
                    set response_obj [::Achatina::Response new -contents $response]
                }

                if {$response_obj eq ""} { set response_obj $response }

                return $response_obj
            }
        }

        # 404
        set error_obj [::Achatina::Error new 404 {Not found} {} $config]
        set response_obj [$error_obj get_response_obj]

        return $response_obj
    }
}