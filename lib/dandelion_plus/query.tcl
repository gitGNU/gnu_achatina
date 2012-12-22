# Copyright (c) 2000 Ajuba Solutions.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# Copyright (c) 2008 Graeme Pietersz and other parties.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

package provide query_plus 1.0

namespace eval ::query_plus {}

proc ::query_plus::decode {str} {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]

    # convert %HH to \uxxx, process the escapes, and concvert from utf-8
    return [encoding convertfrom utf-8 [subst -novar -nocommand [regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1}]]]
}

proc ::query_plus::nvlist {type query} {
    switch -glob -- $type {
        "" -
        text/xml* -
        application/x-www-form-urlencoded* -
        application/x-www-urlencoded* {
            set result {}

            # Any whitespace at the beginning or end of urlencoded data is not
            # considered to be part of that data, so we trim it off.  One special
            # case in which post data is preceded by a \n occurs when posting
            # with HTTPS in Netscape.

        foreach {x} [split [string trim $query] &] {
                # Turns out you might not get an = sign,
                # especially with <isindex> forms.

                set pos [string first = $x]
                set len [string length $x]

                if { $pos>=0 } {
                    if { $pos == 0 } { # if the = is at the beginning ...
                        if { $len>1 } {
                                    # ... and there is something to the right ...
                            set varname anonymous
                            set val [string range $x 1 end]]
                        } else {
                                    # ... otherwise, all we have is an =
                            set varname anonymous
                            set val ""
                        }
                    } elseif { $pos==[expr {$len-1}] } {
                                # if the = is at the end ...
                        set varname [string range $x 0 [expr {$pos-1}]]
                    set val ""
                    } else {
                        set varname [string range $x 0 [expr {$pos-1}]]
                        set val [string range $x [expr {$pos+1}] end]
                    }
                } else { # no = was found ...
                    set varname anonymous
                    set val $x
                }
                dict lappend result [decode $varname] [decode $val]
            }
            return $result
        }
        multipart/* {
            return [multipart $type $query]
        }
        default {
            return -code error "Unknown Content-Type: $type"
        }
    }
}

proc ::query_plus::parseMimeValue {value} {
    set parts [split $value \;]
    set results [list [string trim [lindex $parts 0]]]
    set paramList [list]
    foreach sub [lrange $parts 1 end] {
        if {[regexp -- {([^=]+)=(.+)} $sub match key val]} {
                    set key [string trim [string tolower $key]]
                    set val [string trim $val]
                    # Allow single as well as double quotes
            if {[regexp -- {^["']} $val quote]} { ;# need a " for balance
                if {[regexp -- ^${quote}(\[^$quote\]*)$quote $val x val2]} {
                    # Trim quotes and any extra crap after close quote
                    set val $val2
                }
            }

            lappend paramList $key $val
        }
    }

    if {[llength $paramList]} {
        lappend results $paramList
    }

    return $results
}

proc ::query_plus::multipart {type query {count -1}} {
    set parsedType [parseMimeValue $type]
    if {![string match multipart/* [lindex $parsedType 0]]} {
        error "Not a multipart Content-Type: [lindex $parsedType 0]"
    }
    array set options [lindex $parsedType 1]
    if {![info exists options(boundary)]} {
        error "No boundary given for multipart document"
    }
    set boundary $options(boundary)
    # The query data is typically read in binary mode, which preserves
    # the \r\n sequence from a Windows-based browser.
    # Also, binary data may contain \r\n sequences.

    if {[string match "*$boundary\r\n*" $query]} {
        set lineDelim "\r\n"
        # puts "DELIM"
    } else {
        set lineDelim "\n"
        # puts "NO"
    }

    # Iterate over the boundary string and chop into parts

    set len [string length $query]
    # [string length $lineDelim]+2 is for "$lineDelim--"
    set blen [expr {[string length $lineDelim] + 2 + \
                [string length $boundary]}]
    set first 1
    set results [dict create]
    set offset 0

    # Ensuring the query data starts
    # with a newline makes the string first test simpler
    if {[string first $lineDelim $query 0] != 0} {
        set query $lineDelim$query
    }

    while {[set offset [string first "$lineDelim--$boundary" $query $offset]] >= 0} {
        # offset is the position of the next boundary string
        # in $query after $offset

        if {$first} {
            set first 0    ;# this was the opening delimiter
        } else {
            # this was the delimiter bounding current element
            # generate a n,v element from parsed content
            dict lappend results \
                $formName \
                [string range $query $off2 [expr {$offset -1}]] \
                $headers
        }
        incr offset $blen    ;# skip boundary in stream

        # Check for the terminating entity boundary,
        # which is signaled by --$boundary--
        if {[string range $query $offset [expr {$offset + 1}]] eq "--"} {
            # end of parse
            break
        }

        # We have a new element. Split headers out from content.
        # The headers become a nested dict structure in result:
        # {header-name { value { paramname paramvalue ... } } }

        # find off2, the offset of the delimiter which terminates
        # the current element
        set off2 [string first "$lineDelim$lineDelim" $query $offset]

        # generate a dict called headers with element's headers and values
        set headers [dict create -count [incr count]]
        set formName ""    ;# any header 'name' becomes the element name
        foreach line [split [string range $query $offset $off2] $lineDelim] {
            if {[regexp -- {([^:\t ]+):(.*)$} $line x hdrname value]} {
                set hdrname [string tolower $hdrname]
                set valueList [parseMimeValue $value]
                if {$hdrname eq "content-disposition"} {
                    # Promote Content-Disposition parameters up to headers,
                    # and look for the "name" that identifies the form element

                    dict lappend headers $hdrname [lindex $valueList 0]
                    foreach {n v} [lindex $valueList 1] {
                        lappend headers $n $v
                        if {$n eq "name"} {
                            set formName $v    ;# the name of the element
                        }
                    }
                } else {
                    dict lappend headers $hdrname $valueList
                }
            }
        }

        if {$off2 > 0} {
            # +[string length "$lineDelim$lineDelim"] for the
            # $lineDelim$lineDelim
            incr off2 [string length "$lineDelim$lineDelim"]
            set offset $off2
        } else {
            break
        }
    }

    set q [dict create]
    dict for {n v} $results {
        # Old way dealing with this was broken, for example it was impossible to tell whether there were two values or
        # one when someone supplied "value" and "meta" as form values.
        dict set q $n [dict create {*}$v]
    }
    return $q
}

proc ::query_plus::bake {name value {expires {}} {path /} {domain {}} {secure 0}} {
    append cookie $name=$value
    if {$expires ne {}} {append cookie \;expires=[clock format $expires -format {%A, %d-%b-%Y %H:%M:%S GMT} -timezone :UTC]}
    append cookie \;path=$path
    if {$domain ne {}} {append cookie \;domain=$domain}
    if {$secure} {append cookie ;secure}
    return $cookie
}

proc ::query_plus::get_cookies {req_headers} {
    if {![dict exists $req_headers HTTP_COOKIE]} { return }
    set cookies [dict create]
    foreach cookie [split [dict get $req_headers HTTP_COOKIE] \;] {
        lassign [split $cookie =] name value
        set name [string trim $name]
        set value [string trim $value]
        dict set cookies $name $value
    }
    return $cookies
}

