proc tinyurl {url} {
	variable settings;
	set result {}
	set query [::http::formatQuery $settings(tinyurl-post-field) $url compact 1]
	catch {
		set tok [::http::geturl $settings(tinyurl-service) -query $query -timeout $settings(timeout)]
		upvar #0 $tok state
		if {$state(status) == "ok" && $state(code) == 200 && [string match -nocase "text/plain*" $state(type)]} {
			set result [lindex [split $state(body) \n] 0]
		}
		::http::cleanup $tok
	}
	return $result
}
