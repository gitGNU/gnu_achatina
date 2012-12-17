# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

namespace eval ::Achatina::Interfaces::Httpd {}

oo::class create ::Achatina::Interfaces::Httpd::Output {
    constructor {sock} {
        variable cookies {} ;# list of cookie headers
        variable contents {}
        variable headers {Content-Type text/html}
        variable status 200
        variable handle $sock

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

    method set_cookie {name value expires} {
        variable cookies
        lappend cookies [::query_plus::bake $name $value $expires /]
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