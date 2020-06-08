urlmagic
========

Written by rojo and ente

Description
-----------

Does following magic things with URLs:

  * Follows links posted in a channel if the udef flag +urlmagic is set
  * If content-type ~ text/html and <title>content exists</title> display title
  * Otherwise, display content-type
  * If url length > threshold, fetch and display tinyurl

Optional features
-----------------

Plugins exist for

  * Optionally recording all URLs to your Twitter page or an SQLite database
  * Flagging links as NSFW if it was mentioned in the text next to the link
  * Displaying the size of a page
  * Displaying the final destination URL in case there was a redirect

In short, what's displayed and what isn't can be influenced by plugins.

This script needs at least the following packages: http, tls and tcllib (for hook)
It is advised to also install the gumbo library for more failsafe HTML parsing.
Your eggdrop needs to be compiled against Tcl 8.5 or higher.

Dependencies
------------

Use your distribution's package management system to install the dependencies
as appropriate.

For optional dependencies introduced by specific plugins, check the directory of
the plugin you want to use for a file called README.

As of 2017-10-25 the HTTP implementation used by urlmagic has been changed to
TclCurl, which simplifies the code and is more robust. You now need to install
tclcurl instead of tcltls for urlmagic to work - distributions which don't have
a tclcurl package (RedHat, Gentoo, FreeBSD) have been stripped from the
examples. Please (make someone) package it and notify me.

### Examples:

#### Debian / Ubuntu:

  * apt-get install git             (optional; makes updating easier)
  * apt-get install tcllib tclcurl  (no matter what plugins are enabled; "core")
  * apt-get install libsqlite3-tcl  (if sqlite plugin is enabled)

On Debian stretch and above, there is a package for the gumbo title parser:

  * apt-get install libgumbo-dev build-essential (optional, possible title parser)

#### OpenSuSE:

  * zypper install git              (optional)
  * zypper install tcllib tclcurl   (core)
  * (sqlite plugin does not require extra packages to be installed)

#### NetBSD (pkgsrc package names):

  * devel/git                       (optional)
  * devel/tcllib wip/tcl-curl       (core)
  * databases/sqlite3               (sqlite)


### Title parsers

The "dumb" regex-based title extraction regexp is not very reliable. Therefore,
there are multiple options for extracting the title out of the HTML documents
downloaded from the server. The most reliable option is using Google's gumbo
library, however it isn't packaged for any distributions I've checked (and
neither is the much less robust arabica library, which has been around for
several years longer). To avoid making each potential user compile their own
gumbo version, I've written a title parser in perl that is invoked via pipe,
because html5 parsers for perl are more easily available than for Tcl or C.

On OpenSuSE, you can find a repository/package for Perl's html5 parser here:

  * http://software.opensuse.org/package/perl-HTML-HTML5-Parser

Alternatively, you can install the perl packages from cpan (for instance if
you're not on debian and your distribution doesn't have a package). The command
is:

  * cpan HTML::HTML5::Parser


Problems
--------

See the file TROUBLESHOOTING.

Please report bugs, gripes, missing operating systems in the table above, etc
to ente on IRCnet, and feel free to let me know if you use it, or just contact
me for chit-chat.

This repository used to live on bitbucket, but it has since moved to github.
See https://bitbucket.org/wilhelmy/eggdrop-urlmagic/issues/ for the issue
tracker.
