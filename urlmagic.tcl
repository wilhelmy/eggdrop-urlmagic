###############################################################################
# urlmagic 1.1 by rojo with fixes by ente                                     #
#                                                                             #
# Copyright (c) 2011 Steve Church (rojo on EFnet). All rights reserved.       #
#           (c) 2013 Moritz Wilhelmy (ente on IRCnet and possibly elsewhere). #
#                                                                             #
# Description:                                                                #
# Follows links posted in channel                                             #
# If content-type ~ text/* and <title>content exists</title> display title    #
# Otherwise, display content-type                                             #
# If url length > threshold, fetch and display tinyurl                        #
# If redirect, display final destination URL                                  #
# Record all this bullshit to your Twitter page                               #
# To disable the Twitter garbage, just set twitter(username) to ""            #
#                                                                             #
# If your eggdrop is not patched for UTF-8, consider doing so.  It makes web  #
# page titles containing unicode characters display as they should.  See      #
# http://eggwiki.org/Utf-8 for details.                                       #
#                                                                             #
# Please report bugs to rojo on EFnet.                                        #
#                                                                             #
# License                                                                     #
#                                                                             #
# Redistribution and use in source and binary forms, with or without          #
# modification, are permitted provided that the following conditions are met: #
#                                                                             #
#   1. Redistributions of source code must retain the above copyright notice, #
#      this list of conditions and the following disclaimer.                  #
#                                                                             #
#   2. Redistributions in binary form must reproduce the above copyright      #
#      notice, this list of conditions and the following disclaimer in the    #
#      documentation and/or other materials provided with the distribution.   #
#                                                                             #
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" #
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE   #
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE  #
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE  #
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR         #
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF        #
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS    #
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN     #
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)     #
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE  #
# POSSIBILITY OF SUCH DAMAGE.                                                 #
###############################################################################
#                                                                             #
# Change Log:                                                                 #
#                                                                             #
# 2013-02-08  (Version 1.1)  -ente                                            #
#                                                                             #
# * fixed twitter support (their HTML layout has changed a bit since 2011)    #
#                                                                             #
# * fixed a bug where html pages without <title> tag would result in the html #
#   being spammed on the channel                                              #
#                                                                             #
# * fixed tinyurl support, use the API instead of screen scraping because it  #
#   didn't work anymore, anyway                                               #
#                                                                             #
###############################################################################

namespace eval urlmagic {

variable settings                     ; # leave this alone
variable twitter                      ; # leave this alone

set settings(max-length) 80           ; # URLs longer than this are converted to tinyurl
set settings(ignore-flags) bdkqr|dkqr ; # links posted by users with these flags are ignored
set settings(seconds-between) 10      ; # stop listening for this many seconds after processing an address
set settings(seconds-between-user) 2  ; # stop listening to a user for this many seconds after they mentioned an URL
set settings(timeout) 10000           ; # wait this many milliseconds for a web server to respond
set settings(max-download) 1048576    ; # do not download pages larger than this many bytes
set settings(max-cookie-age) 2880     ; # if cookie shelf life > this many minutes, eat it sooner
set settings(udef-flag) urlmagic      ; # .chanset #channel +urlmagic
set settings(tinyurl-service) "tinyurl.tcl" ;# Name of shortening service to use. Must be a TCL script that contains a tinyurl proc
set settings(urlmagic-db) "urlmagic.db"
set settings(user-agent) "Mozilla/5.0 (compatible; TCL [info patchlevel] HTTP library) 20110501"; # HTTP User-Agent
set settings(url-regex) {(https?://|www\.|[a-z0-9\-]+\.[a-z]{2,4}/)\S+} ;# this regular expression is used to detect URLs. URLs which do not contain "://" will be extended to assume a default protocol of "http://"
set twitter(username) user            ; # your Twitter username or registered email address
set twitter(password) ""              ; # your Twitter password
set twitter(tweet-urls) no            ; # tweet urls mentioned on the channel to twitter? allows disabling the url tweeting part if you just want to use the tweet proc in another script
set settings(seconds-between-user) 1 ;# After someone posted an URL, ignore them for this many seconds. Set to 0 to disable
set settings(url-flooding-penalty) 3 ;# Penalize users flooding URLs for this many seconds
set settings(seconds-between-channel) 1 ;# Ignore URLs on a busy channel for this many seconds

catch {source conf/urlmagic.conf} ;# try loading this config file which may overwrite the values defined above

#########################
# end of user variables #
#########################

set scriptver 1.1
variable cookies
variable ns [namespace current]
variable skip_sqlite3 [catch {package require sqlite3}]
variable ignores ;# temporary ignores
set settings(base-path) [file dirname [info script]] 

proc reopen_db { } {
	# this procedure must be manually invoked via .tcl urlmagic::reopen_db if the database is moved
	# while messing with the database, use .set urlmagic::skip_sqlite3 1 to disable writes to the database until you're done.
	variable skip_sqlite3;
	variable settings;
	variable ns;

	if {! [string length $settings(urlmagic-db)]} {
		set skip_sqlite3 1
	}

	if {$skip_sqlite3} return;

	if {[llength [info commands ${ns}::db]]} {
		db close
	}

	sqlite3 ${ns}::db $settings(urlmagic-db)
	init_db
}

setudef flag $settings(udef-flag)

foreach lib {http htmlparse tls tdom} {
	if {[catch {package require $lib}]} {
		putlog "\00304urlmagic fail\003: Missing library \00308$lib\003.

urlmagic requires packages \00308http\00315\003, \00308htmlparse\00315\003, \00308tdom\00315\003, \00308tls\00315\003, and (optionally) \00308sqlite3\00315\003.  The http and htmlparse libraries are included in tcllib.
"
putlog "Use your distribution's package management system to install the dependencies as appropriate.

\002Debian / Ubuntu\002:
    \002\00309apt-get install tcllib tdom tcl-tls libsqlite3-tcl\003\002
\002Red Hat / SUSE / CentOS\002:
    \002\00309yum install tcllib tdom tcltls sqlite-tcl\003\002
\002Gentoo\002:
    \002\00309emerge -v tcllib tdom dev-tcltk/tls sqlite\003\002
\002FreeBSD\002:
    \002\00309pkg_add -r tcllib tdom tcltls sqlite3 sqlite3-tcl\003\002
"
		return false
	}
}

::http::register https 443 ::tls::socket
::http::config -useragent $settings(user-agent)

proc unignore {nick uhost hand chan msg} {
	# HACK: just unignore someone leaving *any* channel
	variable ignores
	catch { unset ignores($uhost) }
}

proc ignore {uhost chan} {
	variable ignores; variable settings

	set now [unixtime]

	if {$settings(seconds-between-user) && [info exists ignores($uhost)]
	&& $ignores($uhost) > $now - $settings(seconds-between-user) } then {
		incr ignores($uhost) $settings(url-flooding-penalty)
		return 1
	}

	if {$settings(seconds-between-channel) && [info exists ignores($chan)]
	&& $ignores($chan) > $now - $settings(seconds-between-channel) } then {
		# introducing a penalty for a noisy channel doesn't seem particularly useful
		return 1
	}

	set ignores($uhost) $now
	set ignores($chan) $now

	return 0
}

proc find_urls {nick uhost hand chan txt} {

	variable settings; variable twitter; variable skip_sqlite3; variable ns

	if {[matchattr $hand $settings(ignore-flags)] || ![channel get $chan $settings(udef-flag)]} { return }

	if {[regexp -nocase $settings(url-regex) $txt url] && [string length $url] > 7} {

		if {[ignore $uhost $chan]} return

		set url_complete [string match *://* $url]
		if {!$url_complete} { set url "http://$url" }

		# $details(url, content-length, tinyurl [where $url length > max], title, error [boolean])
		array set details [get_title $url]

		set output [list PRIVMSG $chan ":<$nick>"]

		if {[info exists details(tinyurl)]} {
			set url $details(tinyurl)
			lappend output "$details(tinyurl) ->"
		} elseif {![string equal -nocase $url $details(url)]} {
			set url $details(url)
			lappend output "$details(url) ->"

		} elseif {!$url_complete} {
			lappend output "$url ->"
		}

		if {[info exists details(title)]} {
			lappend output "\002$details(title)\002"
			record_history $url $nick $chan $details(title) $settings(content-type)
		} else {
			lappend output "\002Content type: $settings(content-type)\002"
			record_history $url $nick $chan "" $settings(content-type)
		}

		if {[info exists details(content-length)]} {
			lappend output "\($details(content-length)\)"
		}

		puthelp [join $output]
	}
}

proc init_db {} {
	variable skip_sqlite3;
	if {$skip_sqlite3} return

	db eval {
	CREATE TABLE IF NOT EXISTS
		urls( id                INTEGER PRIMARY KEY AUTOINCREMENT
		    , url               TEXT UNIQUE NOT NULL -- the URL that was mentioned
		    , last_mentioned_by TEXT                 -- who mentioned it the last time
		    , last_mentioned    INTEGER DEFAULT 0    -- unix time when it was last mentioned
		    , last_mentioned_on TEXT DEFAULT ""      -- channel the URL was last mentioned on
		    , mention_count     INTEGER DEFAULT 0    -- number of times it was mentioned
		    , content_type      TEXT
		    , html_title        TEXT
		    );
	}
}

proc query_history {url} {
	variable skip_sqlite3;
	if {$skip_sqlite3} return

	db eval {SELECT COUNT(*) AS count FROM urls WHERE url=:url} {
		return $count
	}
}

proc record_history {url nick chan title ctype} {
	variable skip_sqlite3;
	if {$skip_sqlite3} return

	if {! [string length $title]} {
		unset title ;# HACK: insert NULL in case there is no title
	}

	db eval {
		INSERT OR IGNORE INTO urls(url, mention_count) VALUES(:url, 0); -- initialise if it doesn't yet exist
	        UPDATE urls SET
	                last_mentioned_by = :nick,
	                last_mentioned_on = :chan,
	                content_type      = :ctype,
	                html_title        = :title,
	                last_mentioned    = strftime('%s','now'),
	                mention_count     = mention_count + 1
	        WHERE url = :url;
	}

}

proc update_cookies {tok} {
	variable cookies; variable settings; variable ns
	upvar \#0 $tok state
	set domain [lindex [split $state(url) /] 2]
	if {![info exists cookies($domain)]} { set cookies($domain) [list] }
	foreach {name value} $state(meta) {

		if {[string equal -nocase $name "Set-Cookie"]} {

			if {[regexp -nocase {expires=([^;]+)} $value - expires]} {

				if {[catch {expr {([clock scan $expires -gmt 1] - [clock seconds]) / 60}} expires] || $expires < 1 } {
					set expires 15
				} elseif {$expires > $settings(max-cookie-age)} {
					set expires $settings(max-cookie-age)
				}
			} { set expires $settings(max-cookie-age) }

			set value [lindex [split $value \;] 0]
			set cookie_name [lindex [split $value =] 0]

			set expire_command [list ${ns}::expire_cookie $domain $cookie_name]

			if {[set pos [lsearch -glob $cookies($domain) ${cookie_name}=*]] > -1} {
				set cookies($domain) [lreplace $cookies($domain) $pos $pos $value]
				foreach t [timers] {
					if {[lindex $t 1] == $expire_command} { killtimer [lindex $t 2] }
				}
			} else {
				lappend cookies($domain) $value
			}

			timer $expires $expire_command
		}
	}
}

proc expire_cookie {domain cookie_name} {
	variable cookies
	if {![info exists cookies($domain)]} { return }
	if {[set pos [lsearch -glob $cookies($domain) ${cookie_name}=*]] > -1} {
		set cookies($domain) [lreplace $cookies($domain) $pos $pos]
	}
	if {![llength $cookies($domain)]} { unset cookies($domain) }
}

proc pct_encode_extended {what} {
	set enc [list { } +]
	for {set i 0} {$i < 256} {incr i} {
		if {$i > 32 && $i < 127} { continue }
		lappend enc [format %c $i] %[format %02x $i]
	}
	return [string map $enc $what]
}

proc relative {full partial} {
	if {[string match -nocase http* $partial]} { return $partial }
	set base [join [lrange [split $full /] 0 2] /]
	if {[string equal [string range $partial 0 0] /]} {
		return "${base}${partial}"
	} else {
		return "[join [lreplace [split $full /] end end] /]/$partial"
	}
}

# charsets for encoding conversion in proc fetch
# reference: http://www.w3.org/International/O-charset-lang.html
array set _charset {
	lv	iso8859-13	lt	iso8859-13	et	iso8859-15	eo	iso8859-3	mt	iso8859-3
	bg	iso8859-5	be	iso8859-5	uk	iso8859-5	mk	iso8859-5	ar	iso8859-6
	el	iso8859-7	iw	iso8859-8	tr	iso8859-9	sr	iso8859-5
	ru	koi8-r		ja	euc-jp		ko	euc-kr		cn	euc-cn
}
foreach cc {af sq eu ca da nl en fo fi fr gl de is ga it no pt gd es sv} {
	set _charset($cc) iso8859-1
}
foreach cc {hr cs hu pl ro sr sk sl} {
	set _charset($cc) iso8859-2
}

set _charset(jp) euc-jp; # yay, nonstandard bullshit
set _charset(en) utf-8; # assume utf-8 if charset not specified and lang="en"
variable _charset

proc progresshandler {tok total current} {
	variable settings
	if {$current >= $settings(max-download)} {
		::http::reset $tok toobig
	}
}

proc fetch {url {post ""} {headers ""} {iterations 0} {validate 1}} {
	# follows redirects, sets cookies and allows post data
	# sets settings(content-length) if provided by server; 0 otherwise
	# sets settings(url) for redirection tracking
	# sets settings(content-type) so calling proc knows whether to parse data
	# returns data if content-type=text/html; returns content-type otherwise
	variable settings; variable cookies; variable _charset; variable ns
	
	if {[string length $post]} { set validate 0 }

	set url [pct_encode_extended $url]
	set settings(url) $url

	if {![string length $headers]} {
		set headers [list Referer $url]
		set domain [lindex [split $url /] 2]
		if {[info exists cookies($domain)] && [llength $cookies($domain)]} {
			lappend headers Cookie [join $cookies($domain) {; }]
		}
	}

	set command [list ::http::geturl $url             \
	                  -timeout $settings(timeout)     \
	                  -validate $validate             \
	                  -progress ${ns}::progresshandler]

	if {[string length $post]} {
		lappend command -query $post
	}

	if {[string length $headers]} {
		lappend command -headers $headers
	}

	if {[catch $command http]} {
		if {[catch {set data "Error [::http::ncode $http]: [::http::error $http]"}]} {
			set data "Error: Connection timed out."
		}
		::http::cleanup $http
		return $data
	} {
		update_cookies $http
		set data [::http::data $http]
	}
	
	upvar \#0 $http state
	array set raw_meta $state(meta)
	foreach {name val} [array get raw_meta] { set meta([string tolower $name]) $val }
	unset raw_meta
	# $state(status) == "toobig" in case the file wasn't downloaded completely because it was too big

	::http::cleanup $http

	if {[info exists meta(location)]} {
		set meta(redirect) $meta(location)
	}

	if {[info exists meta(redirect)]} {

		set meta(redirect) [relative $url $meta(redirect)]

		if {[incr iterations] < 10} {
			return [fetch $meta(redirect) "" $headers $iterations $validate]
		} else {
			return "Error: too many redirections"
		}
	}

	if {[info exists meta(content-length)]} {
		set settings(content-length) $meta(content-length)
	} else {
		set settings(content-length) 0
	}

	set charset1 ""
	if {[info exists meta(content-type)]} {
		set settings(content-type) [lindex [split $meta(content-type) ";"] 0]
		if {[regexp {\ycharset=([\w\-]+)} $meta(content-type) -> charset]} {
			set charset1 $charset
		}
#	elseif {[info exists meta(x-aspnet-version)]}
#		set settings(content-type) "text/html"
	} else {
		set settings(content-type) "unknown"
	}

	#if {[string match -nocase $settings(content-type) "text/html"]\
	&& $settings(content-length) <= $settings(max-download)} {}
	if {[string match -nocase $settings(content-type) "text/html"]\
	    || [string match -nocase $settings(content-type) "application/xhtml+xml"]} {
		if {$validate} {
			return [fetch $url "" $headers [incr iterations] 0]
		} else {
			# if it already exists, the charset specified in html takes precedence (mw)
			regexp -nocase {\ycharset=\"?\'?([\w\-]+)} $data -> charset
			if {[info exists charset]} {
				set charset [string map {iso- iso} [string tolower $charset]]
				set log "url: '$url', charset is '$charset', charset1 is '$charset1'"
				if {[lsearch [encoding names] $charset] < 0} {
					unset charset;
					set log "$log; and was unset because it doesn't exist"
				}
				putlog $log
			} else { #DEBUG
				putlog "url: '$url' has no charset"
			}
			if {![info exists charset] && [regexp -nocase {\ylang=\"?\'?(\w{2})} $data - lang]} {
				set charset $_charset([string tolower $lang])
			}
			if {[info exists charset] && ![string equal -nocase [encoding system] $charset]} {
				set data [encoding convertfrom $charset $data]
			}
			return $data
		}
	} else {
		return "Content type: $settings(content-type)"
	}
}

catch {source $settings(base-path)/$settings(tinyurl-service)}

proc nop args {}

proc get_title {url} {
#	returns $ret(url, content-length, tinyurl [where $url length > max], title)
	variable settings

	#set data [string map [list \r "" \n ""] [fetch $url]]
	set data [string map {\r "" \n ""} [fetch $url]]

	if {![string equal $url $settings(url)]} {
		set url $settings(url)
	}
	set ret(error) [string match Error* $data]
 	set ret(url) $url
	set content_length $settings(content-length)
	set title ""
	#{<title[^>]*>\s*(.*)\s*<\s*/\s*title[^>]*>}
	if {[regexp -nocase {<\s*?title\s*?>\s*?(.*?)\s*<\s*/title\s*>} $data - title]} {
		set title [string map {&#x202a; "" &#x202c; "" &rlm; ""} [string trim $title]]; # for YouTube
		regsub -all {\s+} $title { } title
		set ret(title) [string map {\r "" \n ""} [::htmlparse::mapEscapes $title]]
	}

	if {[string length $url] >= $settings(max-length)} {
		set ret(tinyurl) [tinyurl $url]
	}

	if {$content_length} {
		set ret(content-length) [bytes_to_human $content_length]
	}

	return [array get ret]
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

proc make_round {num denom} { # FIXME: what does this even do?
	global tcl_precision
	set expr {1.1 + 2.2 eq 3.3}; while {![catch { incr tcl_precision }]} {}; while {![expr $expr]} { incr tcl_precision -1 }
	return [regsub {00000+[1-9]} [expr {round([expr {100.0 * $num / $denom}]) * 0.01}] ""]
}

proc strip_codes {what} { #FIXME unused?
	return [regsub -all -- {\002|\037|\026|\003(\d{1,2})?(,\d{1,2})?} $what ""]
}

proc logged_in {} {
	variable cookies
	if {![info exists cookies(mobile.twitter.com)]} { return 0 }
	set idx [lsearch -glob $cookies(mobile.twitter.com) oauth_token*]
	if {$idx < 0} { return 0 }
	set oauth_token [lindex $cookies(mobile.twitter.com) $idx]
	set token [lindex [split $oauth_token =] 1]
	if {[string length $token]} { return 1 } { return 0 }
}

proc twitter_login {{tries 0}} {
	variable settings; variable cookies; variable twitter

	set data [fetch "https://mobile.twitter.com/session/new"]

	set dom [dom parse -html $data]
	set root [$dom documentElement]
	set forms [$root selectNodes {//form}]
	set form [lindex $forms 0]
	set inputs [$form selectNodes {//input}]
	set url [$form getAttribute action]

	foreach input $inputs {
		catch { set post([$input getAttribute name]) [$input getAttribute value] }
	}

	$dom delete

	set post(username) $twitter(username)
	set post(password) $twitter(password)

	foreach {name value} [array get post] {
		lappend postdata [::http::formatQuery $name $value]
	}

	fetch $url [join $postdata "&"]
	
	if {[logged_in]} { return }

	if {[incr tries] < 3} { twitter_login $tries } { putlog "Twitter login failed.  Tried $tries times." }

}

proc tweet {what} {
	variable settings; variable cookies
	if {![logged_in]} { twitter_login }

	set twitter_url "https://mobile.twitter.com/compose/tweet"
	set data [fetch $twitter_url]

	if {[catch {
		set dom [dom parse -html $data]
		set root [$dom documentElement]
		set forms [$root selectNodes {//form[@class='tweetform']}]
		set form [lindex $forms 0]
		set inputs [$form selectNodes {//input}]
		set url [$form getAttribute action]
		set textareas [$form selectNodes {//textarea[@class='tweetbox']}]
		set textarea [lindex $textareas 0]
	} err]} { putlog "Damn dom.  $err"; foreach l [split $data \n] { putlog $l } }

	foreach input $inputs {
		catch { set post([$input getAttribute name]) [$input getAttribute value] }
	}

	set post([$textarea getAttribute name]) $what

	$dom delete

	foreach {name value} [array get post] {
		lappend postdata [::http::formatQuery $name $value]
	}

	fetch [relative $twitter_url $url] [join $postdata "&"]
}

bind part - * ${ns}::unignore
bind sign - * ${ns}::unignore
# TODO: cron-bind that automatically deletes stale ignores
bind pubm - * ${ns}::find_urls

reopen_db ;# open the db for the first time

putlog "urlmagic.tcl $scriptver loaded."

}; # end namespace
