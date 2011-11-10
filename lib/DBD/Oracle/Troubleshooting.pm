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


=cut
