/*
   Copyright (c) 1994-2006  Tim Bunce

   See the COPYRIGHT section in the Oracle.pm file for terms.

*/


#define NEED_DBIXS_VERSION 93

#define PERL_POLLUTE

#include <DBIXS.h>		/* installed by the DBI module	*/

#include "dbdimp.h"

#include "dbivport.h"

#include <dbd_xsh.h>		/* installed by the DBI module	*/

/* These prototypes are for dbdimp.c funcs used in the XS file          */ 
/* These names are #defined to driver specific names in dbdimp.h        */ 

void	dbd_init _((dbistate_t *dbistate));
void	dbd_init_oci_drh _((imp_drh_t * imp_drh));

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
int	 dbd_st_cancel  _((SV *sth, imp_sth_t *imp_sth));
AV	*dbd_st_fetch	_((SV *sth, imp_sth_t *imp_sth));

int	 dbd_st_finish	_((SV *sth, imp_sth_t *imp_sth));
void	 dbd_st_destroy _((SV *sth, imp_sth_t *imp_sth));
int      dbd_st_blob_read _((SV *sth, imp_sth_t *imp_sth,
		int field, long offset, long len, SV *destrv, long destoffset));
int	 dbd_st_STORE_attrib _((SV *sth, imp_sth_t *imp_sth, SV *keysv, SV *valuesv));
SV	*dbd_st_FETCH_attrib _((SV *sth, imp_sth_t *imp_sth, SV *keysv));
int	 dbd_bind_ph  _((SV *sth, imp_sth_t *imp_sth,
		SV *param, SV *value, IV sql_type, SV *attribs, int is_inout, IV maxlen));

int	 dbd_db_login6 _((SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *user, char *pwd, SV *attr));
int    dbd_describe _((SV *sth, imp_sth_t *imp_sth));
ub4    ora_blob_read_piece _((SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv,
                   long offset, UV len, long destoffset));
ub4    ora_blob_read_mb_piece _((SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv,
		   long offset, UV len, long destoffset));

/* end of Oracle.h */
