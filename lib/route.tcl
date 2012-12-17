# Copyright (c) 2012 Tomasz Konojacki
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

oo::class create ::Achatina::Route {
    constructor {} {
        variable path {}
        variable class_ {}
        variable request_method {}
        variable route_regexp {}
        variable placeholders_keys {}
    }

    method set_path {p} {
        variable path
        set path $p
    }

    method set_request_method {m} {
        variable request_method
        set request_method $m
    }

    method set_class {c} {
        variable class_
        set class_ $c
    }

    method set_route_regexp {r} {
        variable route_regexp
        set route_regexp $r
    }

    method set_placeholders_keys {p} {
        variable placeholders_keys
        set placeholders_keys $p
    }

    method get_path {} {
        variable path
        return $path
    }

    method get_request_method {} {
        variable request_method
        return $request_method
    }

    method get_class {} {
        variable class_
        return $class_
    }

    method get_route_regexp {} {
        variable route_regexp
        return $route_regexp
    }

    method get_placeholders_keys {} {
        variable placeholders_keys
        return $placeholders_keys
    }

}