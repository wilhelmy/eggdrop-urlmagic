# Tweet URLs mentioned on the channel, or their tinyurl if the tinyurl plugin
# is loaded.
# Can be used by other Tcl scripts to just tweet anything.
#
# Uses bti written by Greg Kroah-Hartman - http://github.com/gregkh/bti/
# Can alternatively use ttytter by Cameron Kaiser or other command line twitter
# utilities where bti isn't available.
#
# See twitter.conf for the settings (append them to your urlmagic config)
#
# If you rotate the logfile, remember to call reopen_logfile somehow.

set VERSION 1.1+hg+3
variable logfd ""

proc write_tweet {fd tweet} {
	puts $fd $tweet
	close $fd
}

proc tweet {what} {
	variable settings
	variable ns
	variable logfd
	set what [string range $what 0 139]
	puts $logfd "*** [clock format [clock seconds]] - $what"
	set fd [open "|$settings(tweet-command) >&@$logfd" w]
	fconfigure $fd -blocking no
	fileevent $fd writable [list ${ns}::write_tweet $fd $what]
	return
}

proc tweet_url {} {
	upvar #0 ::urlmagic::title t

	set text $t(url)
	if {[info exists t(tinyurl)] && $t(tinyurl) != ""} {
		set text $t(tinyurl)
	}

	lappend text $t(title)
	tweet "<$t(nick)> [join $text]"
}

proc open_logfile {} {
	variable logfd
	variable settings
	if {$logfd != ""} {
		warn "trying to open logfile which is already open"
		return
	}
	set logfd [open "$settings(log-file)" a]
}

proc close_logfile {} {
	variable logfd
	if {$logfd == ""} {
		warn "trying to close logfile which is not open"
		return
	}
	catch {close $logfd}
	set logfd ""
}

proc reopen_logfile {} {
	close_logfile
	open_logfile
}

proc init_plugin {} {
	variable settings
	variable ns
	setudef flag $settings(udef-flag)
	open_logfile

	if {$settings(tweet-urls-at-all)} {
		hook::bind urlmagic <Post-String> [myself] ${ns}::tweet_url
	}
}

proc deinit_plugin {} {
	variable logfd
	hook::forget [myself]
	close_logfile
}
