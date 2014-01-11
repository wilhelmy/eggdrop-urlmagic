#! tclsh

# This plugin adds the size of a document behind an URL to the title sent to
# the channel.
# There are no configurable settings for it.
# It binds on urlmagic's <String> string builder hook.

namespace eval ::urlmagic::plugins::size {

package require hook

set VERSION 1.1+hg
namespace path ::urlmagic

variable no_settings 1

proc size {} {
	upvar #0 ::urlmagic::title t

	if {$t(content-length)} {
		lappend t(output) "([bytes_to_human $t(content-length)])"
	}
}


proc bytes_to_human {bytes} {
	if {$bytes > 1073741824} {
		return "[make_round $bytes 1073741824] GB"
	} elseif {$bytes > 1048576} {
		return "[make_round $bytes 1048576] MB"
	} elseif {$bytes > 1024} {
		return "[make_round $bytes 1024] KB"
	} else { return "$bytes B" }
}

# FIXME This is broken. Replace by something that makes sense.
proc make_round {num denom} {
	global tcl_precision
	set expr {1.1 + 2.2 eq 3.3}; while {![catch { incr tcl_precision }]} {}; while {![expr $expr]} { incr tcl_precision -1 }
	return [regsub {00000+[1-9]} [expr {round([expr {100.0 * $num / $denom}]) * 0.01}] ""]
}

proc init_plugin {} {
	hook::bind urlmagic <String> urlmagic::plugin::size [namespace current]::size
}

proc deinit_plugin {} {
	hook::forget urlmagic::plugin::size
}

} ;# end namespace
