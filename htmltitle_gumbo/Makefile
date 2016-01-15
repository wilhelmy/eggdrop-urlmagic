# If you installed gumbo or Tcl in your home directory, change the path(s) below.
# On BSD, you need to use gmake instead of make.
GUMBO_INC=	$(shell pkg-config --cflags gumbo)
GUMBO_LIB=	$(shell pkg-config --libs gumbo)
TCL_PREFIX=	/usr
TCL_INC=	-I$(TCL_PREFIX)/include/tcl8.5
TCL_LIB=	

# Uncomment the following line and adjust the path if you installed gumbo in a
# directory which is not part of ld.so.conf, e.g. /usr/local/lib on OpenSuSE or
# Debian >= jessie. Alternatively, you can add the path to /etc/ld.so.conf and
# run ldconfig.
#LDFLAGS+=	-Wl,-rpath,/usr/local/lib

# You can probably stop editing here.

CFLAGS=		-std=c99 -Os -fPIC $(GUMBO_INC) $(TCL_INC)
LDFLAGS+=	-shared
LIBS=		$(GUMBO_LIB) $(TCL_LIB)

htmltitle.so: htmltitle.o
	$(CC) $(LDFLAGS) -o $@ $< $(LIBS)
	strip $@

clean:
	rm -f htmltitle.o htmltitle.so
