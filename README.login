Using Oracle environment variables with sqlplus and Perl.
---------------------------------------------------------

sqlplus
-------

ORACLE_SID is really unnecessary to set since TWO_TASK provides the
same functionality in addition to allowing remote connections.

% setenv TWO_TASK T:hostname:ORACLE_SID
% sqlplus username/password

Note that if you have *both* local and remote databases, and you
have ORACLE_SID *and* TWO_TASK set, and you don't specify a fully
qualified connect string on the command line, TWO_TASK takes precedence
over ORACLE_SID (i.e. you get connected to remote system).

TWO_TASK = P:sid will use the pipe driver for local connections  
SQL*Net 1.x

TWO_TASK = T:machine:sid will use TCP/IP (or D for DECNET, etc.) for
remote SQL*Net 1.x conn.

TWO_TASK = dbname will use the info stored in the SQL*Net 2.x
configuration file for local or remote connections.

ORACLE_HOME can also be left unset if you aren't using any of Oracle's
executables, but error messages may not display.

Discouraging the use of ORACLE_SID makes it easier on the users to see
what is going on. I just wish that TWO_TASK could be renamed, since it
makes no sense to the end user, and doesn't have the ORACLE prefix on
it.

Perl with DBI/DBD
-----------------

Below are various ways of connecting to an oracle database using
SQL*Net 1.x and SQL*Net 2.x.  "Machine" is the computer the database is
running on, "SID" is the SID of the database, "DB" is the SQL*Net 2.x
connection descriptor for the database.

     BEGIN { 
        $ENV{TWO_TASK}='DB'; 
        $ENV{ORACLE_HOME} = '/home/oracle/product/7.x.x';
     }
     ora_login('','scott/tiger');

works here for SQL*Net 2.x, as does

     BEGIN { 
        $ENV{TWO_TASK}='T:Machine:SID';
        $ENV{ORACLE_HOME} = '/home/oracle/product/7.x.x';
     }
     ora_login('','scott/tiger');

for SQL*Net 1.x connections.

For local connections use 'P:SID'.

login variations (not setting TWO_TASK)
----------------------------------------

$lda = ora_login('T:Machine:SID','username','password');

$lda = ora_login('','username@T:Machine:SID','password');

$lda = ora_login('','username@DB','password');

$lda = ora_login('DB','username','password');

$lda = ora_login('DB','username/password','');

With thanks to James Taylor <james.taylor@srs.gov>.

If you are having problems with login taking a long time (>10 secs say)
then try using one of the ...@DB variants. E.g.,

	$lda = ora_login('','username/password@DB','');

Tim.
