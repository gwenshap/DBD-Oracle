http://otn.oracle.com/tech/oci/htdocs/oci9ir2_new_features

OCI Session Pooling
Session Pooling is a new feature in Oracle 9i Database Release 2.
An application can now maintain a pool of sessions and use a session
from the pool when it needs it. This saves the time consuming process
of initiating a connection and authentication every time the process
needs a new session. Session Pooling is useful, especially when a
large number of stateless sessions are required for a very short
time. In a web scenario, where many users are connected for a short
time, and the primary operation is accessing data, it is a costly
operation to start up a new session every time. In such a scenario,
session pooling could boost up the performance.

OCI Statement caching
Client-side statement caching is also introduced in Oracle9i Database
Release 2. This feature can be enabled at the time of session
creation. It allows users to have a cache of statements per session.
On the server, this means having cursors that ready to be used,
without the need to parse the statements again, and thus improving
performance significantly. With this feature enabled, applications
do not have to keep a track of the statements themselves, as the
OCI layer will do it for them. In addition, a tagging feature is
provided, which users can use as a key to save and search for
statements.


