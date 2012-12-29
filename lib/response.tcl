# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Class: ::Achatina::Response
#
# If you want to use custom status code or send custom header then your
# request handler have to return ::Achatina::Response object.
#
# Note that your request handler can return plain string. If that's the case,
# then response object will be automatically generated.
#
# Example usage:
#
# > method do_get {request session config} {
# >     set reponse [::Achatina::Response new "Hello World"]
# >     $response set_status 500
# >     return $response
# > }
oo::class create ::Achatina::Response {
    # Constructor: new
    #
    # Creates response object. You don't have to specify contents when constructing object,
    # you can specify it later using <set_contents>.
    #
    # Parameters:
    #
    #   - (optional) Contents
    constructor {args} {
        variable contents {}
        variable headers {}
        variable redirect {}
        variable status {}

        if {[llength $args] == 1} {
            set contents [lindex $args 0]
        }
    }

    # Function: set_contents
    #
    # Set contents of response object.
    #
    # Parameters:
    #
    #   - Contents
    method set_contents {c} {
        variable contents
        set contents $c
    }

    # Function: get_contents
    #
    # Returns string containing current contents of response object.
    #
    # It takes no arguments.
    method get_contents {} {
        variable contents
        return $contents
    }

    # Function: set_header
    #
    # Sets specified header of response object.
    #
    # Parameters:
    #
    #   - Name of header
    #   - Header value
    method set_header {k v} {
        variable headers
        dict set headers $k $v
    }

    # Function: get_headers
    #
    # Returns dict which contains current headers of response object.
    #
    # It takes no arguments.
    method get_headers {} {
        variable headers
        return $headers
    }

    method _normalize_status {s} {
        switch -regexp -- $s {
            ^100 { return "100 Continue" }
            ^101 { return "101 Switching Protocols" }
            ^200 { return "200 OK" }
            ^201 { return "201 Created" }
            ^202 { return "202 Accepted" }
            ^203 { return "203 Non-Authoritative Information" }
            ^204 { return "204 No Content" }
            ^205 { return "205 Reset Content" }
            ^206 { return "206 Partial Content" }
            ^300 { return "300 Multiple Choices" }
            ^301 { return "301 Moved Permanently" }
            ^302 { return "302 Found" }
            ^303 { return "303 See Other" }
            ^304 { return "304 Not Modified" }
            ^305 { return "305 Use Proxy" }
            ^307 { return "307 Temporary Redirect" }
            ^400 { return "400 Bad Request" }
            ^401 { return "401 Unauthorized" }
            ^402 { return "402 Payment Required" }
            ^403 { return "403 Forbidden" }
            ^404 { return "404 Not Found" }
            ^405 { return "405 Method Not Allowed" }
            ^406 { return "406 Not Acceptable" }
            ^407 { return "407 Proxy Authentication Required" }
            ^408 { return "408 Request Timeout" }
            ^409 { return "409 Conflict" }
            ^410 { return "410 Gone" }
            ^411 { return "411 Length Required" }
            ^412 { return "412 Precondition Failed" }
            ^413 { return "413 Request Entity Too Large" }
            ^414 { return "414 Request-URI Too Long" }
            ^415 { return "415 Unsupported Media Type" }
            ^416 { return "416 Requested Range Not Satisfiable" }
            ^417 { return "417 Expectation Failed" }
            ^500 { return "500 Internal Server Error" }
            ^501 { return "501 Not Implemented" }
            ^502 { return "502 Bad Gateway" }
            ^503 { return "503 Service Unavailable" }
            ^504 { return "504 Gateway Timeout" }
            ^505 { return "505 HTTP Version Not Supported" }
            default { return $s }
        }
    }

    # Function: get_status
    #
    # Returns string containing current HTTP status of response object.
    #
    # It takes no arguments.
    method get_status {} {
        variable status
        return $status
    }

    # Function: set_status
    #
    # Sets HTTP status of response object (for example "404" or "404 Not Found").
    #
    # Parameters:
    #
    #   - Status
    method set_status {s} {
        variable status
        set status [my _normalize_status $s]
    }

    # Function: get_redirect
    #
    # Returns string containing current HTTP redirect of response object.
    #
    # It takes no arguments.
    method get_redirect {} {
        variable redirect
        return $redirect
    }

    # Function: set_redirect
    #
    # Sets HTTP redirect of response object.
    #
    # Examples:
    #
    # > $reponse set_redirect /foo/bar
    # > $reponse set_redirect http://www.google.pl
    #
    # Parameters:
    #
    #   - Redirect address
    method set_redirect {r} {
        variable redirect
        set redirect $r
    }

    method output__ {session request router interface_out} {
        variable contents
        variable headers
        variable redirect
        variable status

        if {($session ne "") && ($request ne "")} {
            $session output__ $request $interface_out
        }

        dict for {k v} $headers {
            $interface_out set_header $k $v
        }

        if {($redirect ne "") && ($request ne "")} {
            set protocol [$request get_header __PROTOCOL__]
            set http_host [$request get_header HTTP_HOST]
            set script_name [$request get_header SCRIPT_NAME]
            set path [$request get_header PATH_INFO]

            if {[regexp {^[a-zA-Z]+://} $redirect]} {
                set url $redirect
                set url [$request _normalize_url $url]

                $interface_out set_header Location $url
                $interface_out set_status {302 Found}
                $interface_out output

                return
            }

            if {($router ne "") && [$router does_route_exist $redirect get]} {
                set url "$protocol://$http_host/$script_name/$redirect"
                set url [$request _normalize_url $url]

                $interface_out set_header Location $url
                $interface_out set_status {302 Found}
                $interface_out output

                return
            }

            if {[regexp {^/} $redirect]} {
                set url "$protocol://$http_host/$redirect"
                set url [$request _normalize_url $url]

                $interface_out set_header Location $url
                $interface_out set_status {302 Found}
                $interface_out output

                return
            }

            set url "$protocol://$http_host/$script_name/$path/$redirect"
            set url [$request _normalize_url $url]

            $interface_out set_header Location $url
            $interface_out set_status {302 Found}
            $interface_out output

            return
        }

        $interface_out set_status $status
        $interface_out set_contents $contents
        $interface_out output
    }

}