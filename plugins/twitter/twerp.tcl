# Ermahgerd, twerper!
#
# This is a simple script that allows channel members to tweet stuff using the
# !tweet command provided that the +twerp udef flag is set on the channel, e.g.
#
#   .chanset #whatever +twerp
#
# If you only want to allow people who are +o or +v to tweet, use this as well:
#
#   .chanset #whatever +twerp-need-voice

namespace eval ::twerp {

# edit these values if you need to
set udef-flag twerp   ;# this is what the main udef flag is called
set needvoice-flag twerp-need-voice  ;# this is what the "need voice" udef flag is called.
set seconds-between 5 ;# wait at least this many seconds before allowing the next tweet to be posted
# stop editing here unless you know what you're doing

set last-tweet 0

proc twerp {nick uhost handle chan text} {
	variable lasttweet
	variable seconds-between
	variable udef-flag
	variable needvoice-flag

	set now [unixtime]

	if {($now < ${last-tweet} + ${seconds-between})
		|| ![channel get $chan ${udef-flag}]
		|| ([channel get $chan ${needvoice-flag}] && ![isop $nick $chan] && ![isvoice $nick $chan])
	} then {
		return
	}

	if {[string trim $text] != "" && [info commands ::urlmagic::plugins::twitter::tweet] != {}} {
		set last-tweet $now
		::urlmagic::plugins::twitter::tweet "<$nick> $text"
		puthelp "PRIVMSG $chan :$nick: Tweeted."
	}
}

setudef flag ${udef-flag}
setudef flag ${needvoice-flag}
bind pub - !tweet ::twerp::twerp

} ;# end namespace
