# This plugin loads the youtube title via youtube's API because the internet is
# enshittified in 2025 and youtube doesn't support <title> anyore x_x

package require json

set VERSION 1.1+git
set no_settings 1

proc postFetch {} {
	upvar #0 ::urlmagic::title t

	if {[regexp -nocase {https?://(m\.|www\.)?youtube.com/watch.*([?&]v=([^&]*))} $t(url) -> _ _ vid] ||
	    [regexp -nocase {https?://youtu\.be/([^?]*)} $t(url) -> vid]} {
		warn "(debug) found youtube video, diversion needed: $vid"
		set curl [::curl::init]

		# pre-encoded url-encoding so I don't have to learn which library does that here
		$curl configure -url "https://www.youtube.com/oembed?format=json&url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D$vid" \
			-protocols {http https} \
			-followlocation 1 \
			-maxredirs 2 \
			-failonerror 1 \
			-nosignal 1 \
			-timeoutms $::urlmagic::settings(timeout) \
			-bodyvar data

		if {![catch {$curl perform} error]} {
			set d [json::json2dict $data]
			set t(title) "[dict get $d author_name] — [dict get $d title] — [dict get $d provider_name]"
		}

		$curl cleanup
	}
}

proc init_plugin {} {
	variable ns
	hook::bind urlmagic <Post-Fetch> [myself] ${ns}::postFetch
}

proc deinit_plugin {} {
	hook::forget [myself]
}
