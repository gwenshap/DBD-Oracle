/*
   $Id: Oracle.h,v 1.17 1999/07/12 03:20:42 timbo Exp $

   Copyright (c) 1994,1995  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media 
   for commercial distribution without the prior approval of the author.

*/


#define NEED_DBIXS_VERSION 93

#define PERL_POLLUTE

#include <DBIXS.h>		/* installed by the DBI module	*/

#include "dbdimp.h"

#include <dbd_xsh.h>		/* installed by the DBI module	*/

#ifdef yxyxyxyx
/* These prototypes are for dbdimp.c funcs used in the XS file          */ 
/* These names are #defined to driver specific names in dbdimp.h        */ 

void	dbd_init _((dbistate_t *dbistate));

int	 dbd_db_login  _((SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *user, char *pwd));
int	 dbd_db_do _((SV *sv, char *statement));
int	 dbd_db_commit     _((SV *dbh, imp_dbh_t *imp_dbh));
int	 dbd_db_rollback   _((SV *dbh, imp_dbh_t *imp_dbh));
int	 dbd_db_disconnect _((SV *dbh, imp_dbh_t *imp_dbh));
void	 dbd_db_destroy    _((SV *dbh, imp_dbh_t *imp_dbh));
int	 dbd_db_STORE_attrib _((SV *dbh, imp_dbh_t *imp_dbh, SV *keysv, SV *valuesv));
SV	*dbd_db_FETCH_attrib _((SV *dbh, imp_dbh_t *imp_dbh, SV *keysv));

int	 dbd_st_prepare _((SV *sth, imp_sth_t *imp_sth,
		char *statement, SV *attribs));
int	 dbd_st_rows	_((SV *sth, imp_sth_t *imp_sth));
int	 dbd_st_execute _((SV *sth, imp_sth_t *imp_sth));
AV	*dbd_st_fetch	_((SV *sth, imp_sth_t *imp_sth));
int	 dbd_st_finish	_((SV *sth, imp_sth_t *imp_sth));
void	 dbd_st_destroy _((SV *sth, imp_sth_t *imp_sth));
int      dbd_st_blob_read _((SV *sth, imp_sth_t *imp_sth,
		int field, long offset, long len, SV *destrv, long destoffset));
int	 dbd_st_STORE_attrib _((SV *sth, imp_sth_t *imp_sth, SV *keysv, SV *valuesv));
SV	*dbd_st_FETCH_attrib _((SV *sth, imp_sth_t *imp_sth, SV *keysv));
int	 dbd_bind_ph  _((SV *sth, imp_sth_t *imp_sth,
		SV *param, SV *value, IV sql_type, SV *attribs, int is_inout, IV maxlen));
#endif

int	 dbd_db_login6 _((SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *user, char *pwd, SV *attr));
int    dbd_describe _((SV *sth, imp_sth_t *imp_sth));
ub4    ora_blob_read_piece _((SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv,
                   long offset, long len, long destoffset));

/* end of Oracle.h */
