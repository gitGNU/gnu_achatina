# Copyright (c) 2012, 2013 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::Achatina::Interfaces::Httpd {}

oo::class create ::Achatina::Interfaces::Httpd::Output {
    constructor {args} {
        variable cookies {} ;# list of cookie headers
        variable contents {}
        variable headers {Content-Type text/html}
        variable status 200
        variable handle {}

        # Validate arguments, note that potential error will not be catched by anything
        if {[catch {set handle [dict get $args -sock]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::Output constructor"
        }

        package require query_plus
    }

    method set_contents {c} {
        variable contents
        set contents $c
    }

    method set_header {h v} {
        variable headers
        dict set headers $h $v
    }

    method get_header {h} {
        variable headers

        if {[dict exists $headers $h]} {
            return [dict get $headers $h]
        }

        return
    }

    method set_cookie {args} {
        # Validate arguments
        
        if {[catch {set name [dict get $args -name]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::set_cookie"
        }

        if {[catch {set value [dict get $args -value]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::set_cookie"
        }
        
        if {[catch {set expiration_date [dict get $args -expiration_date]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::set_cookie"
        }

        variable cookies
        
        lappend cookies [::query_plus::bake $name $value $expiration_date /]
    }

    method set_status {s} {
        variable status
        set status $s
    }

    method output {} {
        variable contents
        variable headers
        variable status
        variable handle
        variable cookies

        set tmp_headers $headers

        dict for {k v} $tmp_headers {
            if {[string tolower $k] eq "content-type"} {
                set content_type $v
                set tmp_headers [dict remove $tmp_headers $k]
                continue
            }
        }

        if {$content_type eq ""} {set content_type "text/html"}

        puts $handle "HTTP/1.1 $status"
        puts $handle "Connection: Close"
        puts $handle "Content-Type: $content_type"

        dict for {k v} $tmp_headers {
            puts $handle "$k: $v"
        }

        foreach c $cookies {
            puts $handle "Set-Cookie: $c"
        }

        puts $handle {}

        puts -nonewline $handle $contents

        close $handle
    }
}