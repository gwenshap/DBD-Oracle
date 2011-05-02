From PGWeiss@arity.com  Thu Mar  9 09:51:45 2000
Return-Path: <PGWeiss@arity.com>
Received: from oink by toad.ig.co.uk (SMI-8.6/SMI-SVR4)
	id JAA14948; Thu, 9 Mar 2000 09:51:43 GMT
Received: from tele-punt-22.mail.demon.net by oink with SMTP (PP) 
          id <27566-0@oink>; Mon, 9 Mar 1970 10:51:10 +0100
Received: from punt-2.mail.demon.net by mailstore for Tim.Bunce@ig.co.uk 
          id 952595299:20:10439:68; Thu, 09 Mar 2000 09:48:19 GMT
Received: from image.arity.com ([140.239.104.130]) by punt-2.mail.demon.net 
          id aa2010598; 9 Mar 2000 9:47 GMT
Received: by image.arity.com with Internet Mail Service (5.5.2650.21) 
          id <F5TBNB5X>; Thu, 9 Mar 2000 04:51:44 -0500
Message-ID: <F1E8458A2ADBCF11996E02608C6AD1690EFB1A@image.arity.com>
From: "Paul G. Weiss" <PGWeiss@arity.com>
To: Perl-Win32-Database Mailing List <perl-win32-database@lyris.activestate.com>,
        "'Tim Bunce'" <Tim.Bunce@ig.co.uk>
Subject: Another CLOB related DBD::Oracle bug
Date: Thu, 9 Mar 2000 04:51:41 -0500
MIME-Version: 1.0
X-Mailer: Internet Mail Service (5.5.2650.21)
Content-Type: text/plain; charset="iso-8859-1"
Status: RO
Content-Length: 689
Lines: 32

Binding a parameter to type ORA_CLOB causes a leak.
Consider:

for (1..10000)
{
    for (1..100)
    {
        my $sth = $db->prepare('update item set descr = ? where id = ?');
        if ($leak)
        {
            $sth->bind_param(1, $descr, {ora_type => ORA_CLOB,
ora_field=>'DESCR'});
            $sth->bind_param(2, 12);
            $sth->execute;
        }
        else
        {
            $sth->execute($descr,12);
        }
    }
    sleep 1;
}


With $leak set to 1, i.e. binding the parameters explicitly the
program leaks.  With $leak set to 0 it does not (but then I can't
set descr to anything greater than 4K nor can I set it to the
empty string).

Is there a patch?

-P

