=pod

=head1 NAME

DBD::Oracle::Troubleshooting - Tips and Hints to Troubleshoot DBD::Oracle

=head1 CONNECTING TO ORACLE

If you are reading this it is assumed that you have successfully
installed DBD::Oracle and you are having some problems connecting to
Oracle.

First off you will have to tell DBD::Oracle where the binaries reside
for the Oracle client it was compiled against.  This is the case when
you encounter a

 DBI connect('','system',...) failed: ERROR OCIEnvNlsCreate.

error in Linux or in Windows when you get

  OCI.DLL not found

The solution to this problem in the case of Linux is to ensure your
'ORACLE_HOME' (or LD_LIBRARY_PATH for InstantClient) environment
variable points to the correct directory.

  export ORACLE_HOME=/app/oracle/product/xx.x.x

For Windows the solution is to add this value to you PATH

  PATH=c:\app\oracle\product\xx.x.x;%PATH%


If you get past this stage and get a

  ORA-12154: TNS:could not resolve the connect identifier specified

error then the most likely cause is DBD::ORACLE cannot find your .ORA
(F<TNSNAMES.ORA>, F<LISTENER.ORA>, F<SQLNET.ORA>) files. This can be
solved by setting the TNS_ADMIN environment variable to the directory
where these files can be found.

If you get to this stage and you have either one of the following
errors;

  ORA-12560: TNS:protocol adapter error
  ORA-12162: TNS:net service name is incorrectly specified

usually means that DBD::Oracle can find the listener but the it cannot connect to the DB because the listener cannot find the DB you asked for.

=head2 Oracle utilities

If you are still having problems connecting then the Oracle adapters
utility may offer some help. Run these two commands:

  $ORACLE_HOME/bin/adapters
  $ORACLE_HOME/bin/adapters $ORACLE_HOME/bin/sqlplus

and check the output. The "Protocol Adapters" section should be the
same.  It should include at least "IPC Protocol Adapter" and "TCP/IP
Protocol Adapter".

If it generates any errors which look relevant then please talk to your
Oracle technical support (and not the dbi-users mailing list).

=head1 OPTIMIZING ORACLE'S LISTENER

[By Lane Sharman <lane@bienlogic.com>] I spent a lot of time optimizing
listener.ora and I am including it here for anyone to benefit from. My
connections over tnslistener on the same humble Netra 1 take an average
of 10-20 milli seconds according to tnsping. If anyone knows how to
make it better, please let me know!

  LISTENER =
   (ADDRESS_LIST =
    (ADDRESS =
      (PROTOCOL = TCP)
      (Host = aa.bbb.cc.d)
      (Port = 1521)
      (QUEUESIZE=10)
    )
   )

  STARTUP_WAIT_TIME_LISTENER = 0
  CONNECT_TIMEOUT_LISTENER = 10
  TRACE_LEVEL_LISTENER = OFF
  SID_LIST_LISTENER =
   (SID_LIST =
    (SID_DESC =
      (SID_NAME = xxxx)
      (ORACLE_HOME = /xxx/local/oracle7-3)
        (PRESPAWN_MAX = 40)
        (PRESPAWN_LIST=
        (PRESPAWN_DESC=(PROTOCOL=tcp) (POOL_SIZE=40) (TIMEOUT=120))
      )
     )
   )

1) When the application is co-located on the host and there is no need for
outside SQLNet connectivity, stop the listener. You do not need it. Get
your application/cgi/whatever working using pipes and shared memory. I am
convinced that this is one of the connection bugs (sockets over the same
machine). Note the $ENV{ORAPIPES} env var.  The essential code to do
this at the end of this section.

2) Be careful in how you implement the multi-threaded server. Currently I
am not using it in the initxxxx.ora file but will be doing some more testing.

3) Be sure to create user rollback segments and use them; do not use the
system rollback segments; however, you must also create a small rollback
space for the system as well.

5) Use large tuning settings and get lots of RAM. Check out all the
parameters you can set in v$parameters because there are quite a few not
documented you may to set in your initxxx.ora file.

6) Use svrmgrl to control oracle from the command line. Write lots of small
SQL scripts to get at V$ info.

  use DBI;
  # Environmental variables used by Oracle
  $ENV{ORACLE_SID}   = "xxx";
  $ENV{ORACLE_HOME}  = "/opt/oracle7";
  $ENV{EPC_DISABLED} = "TRUE";
  $ENV{ORAPIPES} = "V2";
  my $dbname = "xxx";
  my $dbuser = "xxx";
  my $dbpass = "xxx";
  my $dbh = DBI->connect("dbi:Oracle:$dbname", $dbuser, $dbpass)
             || die "Unable to connect to $dbname: $DBI::errstr\n";


=cut
