>From Perl 5.6.0 onwards DBD::Oracle supports UTF8 as local
character set (using OCI8). Thus, when the environment 
variable NLS_LANG ends with "utf8", DBD::Oracle marks Perl 
strings as unicode (when multibyte characters are present). 
This affects the handling of CHAR/VARCHARx columns and 
LONGs/CLOBs.

Multibyte chars in Perl 5.6.0:

Perl 5.6.0 switches to character semantics (as compared to
byte) for multibyte strings. According to Perl documentation
this is done transparently to Perl scripts - all builtin
operators know about it. DBD::Oracle tries to preserve this
transparency as far as Oracle allows this (see below).

As a consequence, "LongReadLen" now counts characters and
not bytes when dealing with LONG/CLOB values. Selected LONGs
and CLOBs will return at most LongReadLen chars, but may
contain a multiple of that in actual bytes.

blob_read issued on CLOBs will also use character semantics.
You have to take extra precautions when using such strings
in a byte-size context, for example a fixed size field in
a protocol message. This is not specific to DBD::Oracle as
such, but be warned.

You need patches at least up to 6090 for Perl 5.6.0 for utf8
to work with DBD::Oracle. (For WinUsers: ActiveState build 
beyond 613 will probably do).


Multibyte chars in Oracle 8(i)

CHAR/VARCHAR and friends count size in bytes, not characters.
If you have a Oracle database created with character set utf8
and insert a string with 10 characters into a VARCHAR2(10)
column, this will only work if the string is 10 bytes long.
If the string is longer, it will fail (and report and error). 
This behaviour is inherent to Oracle/OCI and not influenced 
by DBD::Oracle.

This is then the place where transparency of utf8 breaks. If
you want to check your parameter lengths before insert, you 
have to switch Perl to bytes semantics (see "use bytes" in
Perl documentation).



2000-05-09, Stefan Eissing (se@acm.org)
