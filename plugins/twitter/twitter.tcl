# Tweet URLs mentioned on the channel, or their tinyurl the tinyurl plugin is
# loaded. Can be used by other Tcl scripts to just tweet anything.
# Uses bti written by Greg Kroah-Hartman - http://github.com/gregkh/bti/
# See twitter.conf for the settings (append them to your urlmagic config)

set VERSION 1.1+hg+1

proc tweet {what} {
	variable settings
	set what [string range $what 0 139]
	set logfd [open "$settings(log-file)" w]
	puts $logfd "*** [clock format [clock seconds]] - $what"
	close $logfd
	set fd [open "|$settings(tweet-command) >>$settings(log-file) 2>&1" w]
	puts $fd $what
	close $fd
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

proc init_plugin {} {
	variable settings
	variable ns
	setudef flag $settings(udef-flag)

	if {$settings(tweet-urls-at-all)} {
		hook::bind urlmagic <Post-String> [myself] ${ns}::tweet_url
	}
}

proc deinit_plugin {} {
	hook::forget [myself]
}
