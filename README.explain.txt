explain
=======

DISCLAIMER & COPYRIGHT
----------------------

Copyright (c) 1998 Alan Burlison

You may distribute under the terms of either the GNU General Public License
or the Artistic License, as specified in the Perl README file.

This code is provided with no warranty of any kind, and is used entirely at
your own risk.

This code was written by the author as a private individual, and is in no way
endorsed or warrantied by Sun Microsystems.

WHAT IS IT?
-----------
explain is a GUI-based tool that enables easier visualisation of Oracle Query
plans.  A query plan is the access path that Oracle will use to satisfy a SQL
query.  The Oracle query optimiser is responsible for deciding on the optimal
path to use.  Needless to say, understanding such plans requires a fairly
sophisticated knowledge of Oracle architecture and internals.

explain allows a user to interactively edit a SQL statemant and view the
resulting query plan with the click of a single button.  The effects of
modifying the SQL or of adding hints can be rapidly established.

explain allows the user to grab all the SQL currently cached by Oracle.  The SQL
capture can be filtered and sorted by different criterea, e.g. all SQL matching
a pattern, order by number of executions etc.

explain is written using Perl, DBI/DBD::Oracle and Tk.

PREREQUISITES
-------------
1.  Oracle 7 or Oracle 8, with SQL*Net if appropriate
2.  Perl 5.004_04 or later
3.  DBI version 0.93 or later
4.  DBD::Oracle 0.49 or later
5.  Tk 800.005 or later
6.  Tk-Tree 3.00401 or later

Items 2 through 6 can be obtained from any CPAN mirror.

INSTALLATION
------------
1.  Check you have all the prequisites installed and working.
2.  Check the #! line in the script points to where your Perl interpreter is
    installed.
3.  Copy the "explain" script to somewhere on your path.
4.  Make sure the "explain" script is executable.
5.  Make sure you have run the script $ORACLE_HOME/rdbms/admin/utlxplan.sql
    from a SQL*Plus session.  This script creates the PLAN_TABLE that is used
    by Oracle when explaining query plans.

HOW TO USE
----------
 
Type "explain" at the shell prompt.  A window will appear with a menu bar and
three frames, labelled "Query Plan", "Query Step Details" and "SQL Editor".  At
the bottom of the window is a single button labelled "Explain".  A login dialog
will also appear, into which you should enter the database username, password
and database instance name (SID).  The parameters you enter are passed to the
DBI->connect() method, so if you have any problems refer to the DBI and
DBD::Oracle documentation.

Optionally you may supply up to two command-line arguments.  If the first
argument is of the form username/password@database, explain will use this to
log in to Oracle, otherwise if it is a filename it will be loaded into the SQL
editor.  If two arguments are supplied, the second one will be assumed to be a
filename.

Examples:
   explain scott/tiger@DB query.sql
   explain / query.sql                (assumes OPS$ user authentication)
   explain query.sql


Explain functionality
---------------------

The menu bar has one pulldown menu, "File", which allows you to login to Oracle,
Grab the contents of the Oracle SQL cache, Load SLQ from files, Save SQL to
files and to Exit the program.

The "SQL Editor" frame allows the editing of a SQL statement.  This should be
just a single statement - multiple statements are not allowed.  Refer to the
documentation for the Tk text widget for a description of the editing keys
available.  Text may be loaded and saved by using the "File" pulldown menu.

Once you have entered a SQL statement, the "Explain" button at the bottom of
the window will generate the query plan for the statement.  A tree
representation of the plan will appear in the "Query Plan" frame.  Individual
"legs" of the plan may be expanded and collapsed by clicking on the "+' and "-"
boxes on the plan tree.  The tree is drawn so that the "innermost" or "first"
query steps are indented most deeply.  The connecting lines show the
"parent-child" relationships between the query steps.  For a comprehensive
explanation of the meaning of query plans you should refer to the relevant
Oracle documentation.

Single-clicking on a plan step in the Query Plan pane will display more
detailed information on that query step in the Query Step Details frame.  This
information includes Oracle's estimates of cost, cardinality and bytes
returned.  The exact information displayed depends on the Oracle version.
Again, for detailed information on the meaning of these fields, refer to the
Oracle documentation.

Double-clicking on a plan step that refers to either a table or an index will
pop up a dialog box showing the definitiaon of the table or index in a format
similar to that of the SQL*Plus 'desc' command.

Grab functionality
-----------------

The explain window has an option on the "File" menu labelled "Grab SQL ...".
Selecting this will popup a new top-level window containing a menu bar and
three frames, labelled "SQL Cache", "SQL Statement Statistics" and "SQL
Selection Criterea".  At the bottom of the window is a single button labelled
"Grab".

The menu bar has one pulldown menu, "File", which allows you to Save the
contents of the SQL Cache frame and Close the Grab window.

The "SQL Cache" frame shows the statements currently in the Oracle SQL cache.
Text may be saved by using the "File" pulldown menu.

The "SQL Selection Criterea" frame allows you to specify which SQL statements
you are interested in, and how you want them sorted.  The pattern used to select
statements is a normal perl regexp.  Once you have defined the selection
criterea, clicking the "Grab" button will read all the matching statements from
the SQL cache and display them in the top frame.

Single-clicking on a statement in the SQL Cache pane will display more
detailed information on that statement in the Sql Statement Statistics frame,
including the number of times the statement has been executed and the numbers
of rows processed by the statement.

Double-clicking on a statement will copy it into the SQL editor in the Explain
window, so that the query plan for the statement can be examined.

SUPPORT
-------

Support questions and suggestions can be directed to Alan.Burlison@uk.sun.com


CHANGES
=======

Version 0.51 beta  09/08/98
---------------------------

Integrated into DBD::Oracle release 0.54.

Version 0.5 beta  02/06/98
--------------------------
Changes made to work with Tk800.005.
Fixed bug with grab due to Oracle's inconsistent storage of the hash_value
column in v$sqlarea and v$sqltext_with_newlines.
Disallowed multiple concurrent login/save/open dialogs.
Fixed double-posting of login dialog on startup.
Tried to make it less Oracle version dependent.

Version 0.4 beta  27/02/98
--------------------------
Grab functionality added, to allow interrogation of Oracle's SQL cache
Bind variables used wherever possible to prevent unnecessary reparses of the
SQL generated by explain
Extra error checking
Various code cleanups & restructuring
More extensive commenting of the source

Version 0.3 beta  19/02/98
--------------------------
Changed to use new Tk FileSelect instead of older FileDialog.
Added facility to supply user/pass@database & SQL filename on the command-line.
Thanks to Eric Zylberstejn <ezylbers@capgemini.fr> for the patch + suggestions.
Added check on login to Oracle for a PLAN_TABLE in the user's schema.

Version 0.2 beta  05/02/98
--------------------------
Changed to work with both Oracle 7 and 8 statistics.
Pop-up table & index description dialogs added.
First public version.

Version 0.1 beta  27/01/98
--------------------------
Initial version.
Not publically released.
