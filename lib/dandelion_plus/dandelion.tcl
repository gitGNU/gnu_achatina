# Copyright (c) 2008 Graeme Pietersz
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

package provide dandelion_plus 1.0

namespace eval ::dandelion_plus {
    #work around tcl bug # 2116053
    namespace eval tcl::mathfunc namespace export min max

    namespace import ::tcl::mathop::*
    namespace import ::tcl::mathfunc::*

    variable errors [dict create \
        100 Continue \
        200 OK \
        204 {No Content} \
        400 {Bad Request} \
        404 {Not Found} \
        405 {Method Not Allowed} \
        411 {Length Required} \
        413 {Request Entity Too Large} \
        500 {Internal Server Error} \
        501 {Not Implemented} \
        503 {Service Unavailable} \
        504 {Service Temporarily Unavailable}]

    #Dict of actual first lines or response
    variable first_line [dict create]
    dict for {k v} $errors {
        dict set first_line $k "HTTP/1.1 $k [dict get $errors $k]\nConnection: Close"
    }

    #Just to avoid overwriting global
    variable f
    #Get mime types
    variable mime [dict create {*}[read [set f [open [file join [file dirname [info script]] mime.txt] r]]] ]

    #Dict of ports in use
    #If a port is in use by an http server then the port number will be a key and the value will be a dict {sock server-socket root document-root ......}
    variable ports [dict create]

    variable config [dict create \
        limit 1024 \
        addr 0 \
        check_dir 0 \
        doc_root [file join ~ public_html] \
        port 8080 \
        handler static_handler \
        static 1 \
        static_fail 1 \
        filter_sock {} \
        filter_req {}]

    #Just for pattern matching
    variable pattern_sp [subst -nocommands -novariables {[ \t]*}]
}



proc ::dandelion_plus::init {args} {
	variable ports
	variable config
	#$args overrides config. {*}$config {*}$args does not work.
	set settings [dict create {*}[concat $config $args]]
	dict with settings {
		set doc_root [file normalize $doc_root]
		if {[dict exists $ports $port]} {stop $port}
		set opts [list -server ::dandelion_plus::respond]
		if {$addr != 0} {lappend opts -myaddr $addr}
		lappend opts $port
	}
	dict set settings server_sock [socket {*}$opts]
	puts "server on [dict get $settings port]"
	dict set ports $port $settings
}


proc ::dandelion_plus::stop {port} {
	variable ports
	close [dict get $port sock]
	dict unset ports $port
}

proc ::dandelion_plus::respond {sock caddr cport} {
	variable ports
	#Get the server port and use it to get the setting from the dict. Very neat behaviour on the part of [chan configure]/[fconfigure] as we do not need the original file handle.
	set settings [dict get $ports [lindex [chan configure $sock -sockname] 2]]
	chan configure $sock -blocking 0 -buffersize [min [dict get $settings limit] 1000000]
	#filter by socket data: ip is easilly pulled from the scoket name with [chan configure $sock -peername]. A true return value from the lambda expression called will terminate the response.
	foreach i [dict get $settings filter_sock] {
		if {[apply $i $sock]} {return}
	}
	chan event $sock readable [list ::dandelion_plus::get_initial $sock $settings {}]
	return
}

proc ::dandelion_plus::get_initial {sock settings {line {}}} {
	#Check request size against limit.
	if {([chan pending input $sock]+[string bytelength $line])>[dict get $settings limit]} {
		deny $sock 413 $settings
		return
	}
	#Try to get the line.
	append line [gets $sock]
	#If we got a partial line, complete when more is available.
	if {[chan blocked $sock]} {
		chan event $sock [list ::dandelion_plus::get_initial $sock $settings $line]
		return
	}
	set size [string bytelength $line]
	set line [split [string trim $line]]
	#Should only be three elements in the inital line.
	if {[llength $line] > 3} {
		deny $sock 400 $settings
		return
	}
	#Reject request for files if request uri is absolute. This should be extended to proper http 1.1 support.
	set uri [lindex $line 1]
	if {[string index $uri 0] ne {/}} {
		deny $sock 400 $settings
		return
	}
	#Strip fragment.
	if {[string first # $uri] != -1} {
		set uri [string range $uri 0 [string first # $uri]]
	}
	#Separate query string.
	lassign [split $uri ?] path query
	if {[string first {./} $uri] != -1} {
		deny $sock 404 $settings
		return
	}
	chan event $sock readable [list ::dandelion_plus::get_headers $sock $size [dict create REQUEST_METHOD [lindex $line 0] REQUEST_URI $uri PATH_INFO [decode $path] SCRIPT_NAME / SERVER_PORT [dict get $settings port] QUERY_STRING $query SERVER_PROTOCOL [lindex $line 2]] $settings {}]
	return
}

proc ::dandelion_plus::get_headers {sock size headers settings {partial {}}} {
	variable pattern_sp
	#If what is in the buffer, and what has already been processed, exceeds the limit, send back a 413
	if {([chan pending input $sock] + $size) > [dict get $settings limit]} {
		deny $sock 413 $settings
		return
	}
	while {[gets $sock line] >= 0} {
		#Deal with partial line: Store data in event handler. Increase size by data read from buffer
		#Increase size by data read from buffer. Add two bytes for discarded cr-lf newline.
		set size [+ $size [string bytelength $line] 2]
		if { "$partial$line" eq {}} {
			#headers done, adjust to match CGI, then get body (if any!)
			foreach i [list CONTENT_TYPE CONTENT_LENGTH] {
				if [dict exists $headers HTTP_$i] {
					dict set headers $i [dict get  $headers HTTP_$i]
				}
			}
			foreach i [dict get $settings filter_req] {
				lassign [apply $i $headers $settings] $headers $settings
				if {[dict size] == 0} {return}
			}
			#If the request is a GET or HEAD, respond immediately. If a POST get the body. If none of these, reply not implemented.
			switch [dict get $headers REQUEST_METHOD] {
				GET -
				DELETE -
				HEAD {
					if {[dict get $settings static] && [try_file $sock $headers $settings]} {return}
					[dict get $settings handler] $sock $headers $settings {}
					return
				}
				PUT -
				POST {
					#check length within limit
					if {[dict exists $headers CONTENT_LENGTH]} {
						if {([dict get $headers CONTENT_LENGTH] + $size)  > [dict get $settings limit]} {
							deny $sock 413 $settings
							return
						}
					} else {
						#insist on content length for post
						deny $sock 411 $settings
						return
					}
					#Change encoding to match content type
					if {[dict exists $headers CONTENT_TYPE]} {
						if {[string match multipart/* [dict get $headers CONTENT_TYPE]]} {
							chan configure $sock -encoding binary -translation binary
						}
					}
					::dandelion_plus::get_body $sock $size $headers $settings {}
					return
				}
				default {
					deny $sock 501 $settings
					return
				}
			}
		}
		#Check for continuation line. Inefficient but not common case
		if {[string match $pattern_sp $line]} {
			dict append headers [lindex [dict keys $headers] end] " $line"
			continue
		}
		#Increase size by data read from buffer. 2 bytes for discarded cr-lf newline.
		set size [+ $size [string bytelength $partial$line] 2]
		#Parse header, add to dict. dashes to underscores like CGI, combine multiple values. Combine multiple values.
		set index [string first : $line]
		set key HTTP_[string map {- _} [string toupper [string trim [string range $line 0 [- $index 1]]]]]
		if {[dict exists $headers $key]} {
			dict append headers $key ,[string trim [string range $line [+ $index 1] end]]
		} else {
			dict set headers $key [string trim [string range $line [+ $index 1] end]]
		}
	}
	if {[chan blocked $sock]} {
		chan event $sock readable [list ::dandelion_plus::get_headers $sock [+ $size [string bytelength $partial]] $headers $settings $partial$line]
		return
	}
	#if it is not blocking and headers have not finished and there is nothing to read, something is wrong with the request
	deny $sock 400 $settings
	return
}

proc ::dandelion_plus::get_body {sock size headers settings {body {}}} {
	if {([chan pending input $sock] + $size + [string bytelength $body]) > [dict get $settings limit]} {
		deny $sock 413 $settings
		return
	}
	append body [read $sock]
	if {[chan blocked $sock]} {
		chan event $sock readable [list ::dandelion_plus::get_body $sock $size $headers $settings $body]
		return
	}
	#nothing left to read, so try returning file, if cannot adjust headers to CGI var names and pass to handler
	if {[chan configure $sock -encoding] eq {binary}} {
		set blength [string length $body]
	} else {
		set blength [string bytelength $body]
	}
	if {[dict exists $headers CONTENT_LENGTH] && ($blength < [dict get $headers CONTENT_LENGTH])} {
		chan event $sock readable [list ::dandelion_plus::get_body $sock $size $headers $settings $body]
		return
	}
	[dict get $settings handler] $sock $headers $settings $body
	return
}

proc ::dandelion_plus::try_file {sock headers settings} {
	#get mime type. If it does not have a mime type do not serve and go to handler
	variable mime
	set ext [file extension [dict get $headers PATH_INFO]]
	if {[dict exists $mime $ext]} {
		set mime_type [dict get $mime $ext]
	} else {
		set mime_type {application/octet-stream}
	}
	#normalised request path
	set path [file normalize [file join [dict get $settings doc_root] [string trimleft [dict get $headers PATH_INFO] /]]]
	#ensure within doc_root
	if {[dict get $settings check_dir] && (![string equal [string range $path 0 [- [string length [dict get $settings doc_root]] 1]] [dict get $settings doc_root]])} {
		deny $sock 404 $settings
		#return 1 to say response sent
		return 1
	}
	#open file, if error, return 0 so handler is used. Return 404 or fallback to handler depending on settings.
	if {[catch {file stat $path attribs}]} {
		if {[dict get $settings static_fail]} {
			deny $sock 404 $settings
			return 1
		} else {
			#add back looking for default file for directory here. Check if directory and call directory handler?
			return 0
		}
	}
	switch [dict get $headers REQUEST_METHOD] {
		GET {
			send_head $sock $mime_type
			set fd [open $path r]
			if {![string match text/* $mime_type]} {
				chan configure $sock -encoding binary -translation binary
				chan configure $fd -encoding binary -translation binary
			}
			chan copy $fd $sock -command [list ::dandelion_plus::file_done $fd $sock]
		}
		HEAD {
			#just send the header
			send_head $sock $mime_type
			close $sock
		}
		default {
			deny $sock 405 $settings
			close $sock
		}
	}
	return 1
}

proc ::dandelion_plus::send_head {sock mime} {
	upvar attribs attribs
	variable first_line
	puts $sock [dict get $first_line 200]
	puts $sock "Content-Type: $mime"
	puts $sock [clock format $attribs(atime) -format {Date: %a, %d %b %Y %T GMT} -timezone :UTC]
	puts $sock "Content-Length: $attribs(size)\n"
}

proc ::dandelion_plus::file_done {fd sock bytes {error {}}} {
	close $fd
	close $sock
}

proc ::dandelion_plus::decode {str} {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]

    # convert %HH to \uxxx, process the escapes, and convert from utf-8
    return [encoding convertfrom utf-8 [subst -novar -nocommand [regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1}]]]
}

proc ::dandelion_plus::deny {sock code settings} {
	#expand to be able to return custom error page from file
	variable first_line
	variable errors
	puts $sock [dict get $first_line $code]
	puts $sock "Content-Type: text/html\n"
	set msg [dict get $errors $code]
	puts $sock "<html><head><title>$msg</title></head></html><h1>$msg</h1>"
	close $sock
}

proc ::dandelion_plus::static_handler {sock headers settings body} {
	dict set headers SCRIPT_NAME [file join [dict get $headers SCRIPT_NAME] index.html]
	if {[try_file $sock $headers $settings]} {return}
	deny $sock 404 $settings
}

proc ::dandelion_plus::simple_handler {sock headers settings body} {
	variable first_line
	puts $sock [dict get $first_line 404]\n
	puts $sock {<html><head><title>Show request</title></head><body><h1>Headers</h1><table>}
	dict for {name value} $headers {
		puts $sock "<tr><td>$name</td><td>$value</td></tr>"
	}
	puts $sock {</table><h1>Settings</h1><table>}
	dict for {name value} $settings {
		puts $sock "<tr><td>$name</td><td>$value</td></tr>"
	}
	puts $sock {</table><h1>Body</h1><table>}
	puts $sock $body
	puts $sock {</body></html>}
	close $sock
	return
}
