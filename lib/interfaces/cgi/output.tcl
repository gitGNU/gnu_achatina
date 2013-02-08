# Copyright (c) 2012, 2013 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::Achatina::Interfaces::Cgi {}

oo::class create ::Achatina::Interfaces::Cgi::Output {
    constructor {args} {
        package require ncgi

        variable contents {}
        variable headers {Content-Type text/html}
        variable status 200

        set handle {}
        catch {set handle [dict get $args -handle]}
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

    method set_cookie {name value expires} {
        # Validate arguments
        
        if {[catch {set name [dict get $args -name]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::set_cookie"
        }

        if {[catch {set value [dict get $args -value]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::set_cookie"
        }
        
        if {[catch {set expires [dict get $args -expiration_date]}]} {
            error "Invalid arguments to ::Achatina::Interfaces::Httpd::set_cookie"
        }

        set expiration_date [clock format $expires -format {%a, %d-%b-%Y %T %Z}]
        ::ncgi::setCookie -name $name -value $value -expires $expiration_date -path /
    }

    method set_status {s} {
        variable status
        set status $s
    }

    method output {} {
        variable contents
        variable headers
        variable status

        set content_type {}
        set tmp_headers $headers

        dict for {k v} $tmp_headers {
            if {[string tolower $k] eq "content-type"} {
                set content_type $v
                set tmp_headers [dict remove $tmp_headers $k]
            }

            if {[string tolower $k] eq "status"} {
                set tmp_headers [dict remove $tmp_headers $k]
            }
        }

        if {$content_type eq ""} {set content_type "text/html"}

        ::ncgi::header $content_type Status $status {*}$tmp_headers
        puts -nonewline $contents
    }
}