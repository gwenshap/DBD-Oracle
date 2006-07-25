Add this to the DBD::Oracle docs as a handy note:

$dbh->do(q{alter session set events '65285 trace name errorstack level 3'});

A trace file should then be generated.

Trace files are generated in the 'user_dump_destination' specified in init<SID>.ora.

Try $ORACLE_BASE/admin/$ORACLE_SID/udump.

or the location returned by
select value
from v$parameter
where name like '%user_dump%'
