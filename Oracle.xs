#include "Oracle.h"

DBISTATE_DECLARE;

#ifdef OCI_V8_SYNTAX
# define DBD_ORA_OCI 8
#else
# define DBD_ORA_OCI 7
#endif

MODULE = DBD::Oracle    PACKAGE = DBD::Oracle

I32
constant(name=Nullch)
    char *name
    ALIAS:
    ORA_VARCHAR2 =   1
    ORA_NUMBER	 =   2
    ORA_STRING	 =   5
    ORA_LONG	 =   8
    ORA_ROWID	 =  11
    ORA_DATE	 =  12
    ORA_RAW	 =  23
    ORA_LONGRAW	 =  24
    ORA_CHAR	 =  96
    ORA_CHARZ	 =  97
    ORA_MLSLABEL = 105
    ORA_NTY	 = 108
    ORA_CLOB	 = 112
    ORA_BLOB	 = 113
    ORA_RSET	 = 116
    ORA_OCI      = DBD_ORA_OCI
    ORA_SYSDBA	 = 0x0002
    ORA_SYSOPER	 = 0x0004
    CODE:
    if (!ix) {
	if (!name) name = GvNAME(CvGV(cv));
	croak("Unknown DBD::Oracle constant '%s'", name);
    }
    else RETVAL = ix;
    OUTPUT:
    RETVAL

MODULE = DBD::Oracle    PACKAGE = DBD::Oracle


INCLUDE: Oracle.xsi

MODULE = DBD::Oracle    PACKAGE = DBD::Oracle::st

void
ora_fetch(sth)
    SV *	sth
    PPCODE:
    /* fetchrow: but with scalar fetch returning NUM_FIELDS for Oraperl	*/
    /* This code is called _directly_ by Oraperl.pm bypassing the DBI.	*/
    /* as a result we have to do some things ourselves (like calling	*/
    /* CLEAR_ERROR) and we loose the tracing that the DBI offers :-(	*/
    D_imp_sth(sth);
    AV *av;
    int debug = DBIc_DEBUGIV(imp_sth);
    if (DBIS->debug > debug)
	debug = DBIS->debug;
    DBIh_CLEAR_ERROR(imp_sth);
    if (GIMME == G_SCALAR) {	/* XXX Oraperl	*/
	/* This non-standard behaviour added only to increase the	*/
	/* performance of the oraperl emulation layer (Oraperl.pm)	*/
	if (!imp_sth->done_desc && !dbd_describe(sth, imp_sth))
		XSRETURN_UNDEF;
	XSRETURN_IV(DBIc_NUM_FIELDS(imp_sth));
    }
    if (debug >= 2)
	PerlIO_printf(DBILOGFP, "    -> ora_fetch\n");
    av = dbd_st_fetch(sth, imp_sth);
    if (av) {
	int num_fields = AvFILL(av)+1;
	int i;
	EXTEND(sp, num_fields);
	for(i=0; i < num_fields; ++i) {
	    PUSHs(AvARRAY(av)[i]);
	}
	if (debug >= 2)
	    PerlIO_printf(DBILOGFP, "    <- (...) [%d items]\n", num_fields);
    }
    else {
	if (debug >= 2)
	    PerlIO_printf(DBILOGFP, "    <- () [0 items]\n");
    }
    if (debug >= 2 && SvTRUE(DBIc_ERR(imp_sth)))
	PerlIO_printf(DBILOGFP, "    !! ERROR: %s %s",
	    neatsvpv(DBIc_ERR(imp_sth),0), neatsvpv(DBIc_ERRSTR(imp_sth),0));


void
cancel(sth)
    SV *        sth
    CODE:
    D_imp_sth(sth);
    ST(0) = dbd_st_cancel(sth, imp_sth) ? &sv_yes : &sv_no;


MODULE = DBD::Oracle    PACKAGE = DBD::Oracle::db

void
reauthenticate(dbh, uid, pwd)
    SV *	dbh
    char *	uid
    char *	pwd
    CODE:
    D_imp_dbh(dbh);
    ST(0) = ora_db_reauthenticate(dbh, imp_dbh, uid, pwd) ? &sv_yes : &sv_no;

void
ora_lob_write(dbh, locator, offset, data)
    SV *dbh
    OCILobLocator   *locator
    UV	offset
    SV	*data
    PREINIT:
    D_imp_dbh(dbh);
    ub4 amtp;
    STRLEN data_len; /* bytes not chars */
    dvoid *bufp;
    sword status;
    CODE:
    bufp = SvPV(data, data_len);
    amtp = data_len;
    /* if locator is CLOB and data is UTF8 and not in bytes pragma */
    /* if (0 && SvUTF8(data) && !IN_BYTES) { amtp = sv_len_utf8(data); }  */
#ifdef OCI_V8_SYNTAX
    OCILobWrite_log_stat(imp_dbh->svchp, imp_dbh->errhp, locator,
	    &amtp, (ub4)offset,
	    bufp, (ub4)data_len, OCI_ONE_PIECE,
	    NULL, NULL,
	    0 /* indicate UTF8? */, SQLCS_IMPLICIT, status);
#else
    status = OCI_ERROR;
#endif
    if (status != OCI_SUCCESS) {
        oci_error(dbh, imp_dbh->errhp, status, "OCILobWrite");
	ST(0) = &sv_undef;
    }
    else {
	ST(0) = &sv_yes;
    }

void
ora_lob_append(dbh, locator, data)
    SV *dbh
    OCILobLocator   *locator
    SV	*data
    PREINIT:
    D_imp_dbh(dbh);
    ub4 amtp;
    STRLEN data_len; /* bytes not chars */
    dvoid *bufp;
    sword status;
    CODE:
    bufp = SvPV(data, data_len);
    amtp = data_len;
    /* if locator is CLOB and data is UTF8 and not in bytes pragma */
    /* if (0 && SvUTF8(data) && !IN_BYTES) { amtp = sv_len_utf8(data); }  */
#ifdef OCI_V8_SYNTAX
    OCILobWriteAppend_log_stat(imp_dbh->svchp, imp_dbh->errhp, locator,
	    &amtp, bufp, (ub4)data_len, OCI_ONE_PIECE,
	    NULL, NULL,
	    0 /* indicate UTF8? */, SQLCS_IMPLICIT, status);
#else
    status = OCI_ERROR;
#endif
    if (status != OCI_SUCCESS) {
        oci_error(dbh, imp_dbh->errhp, status, "OCILobWriteAppend");
	ST(0) = &sv_undef;
    }
    else {
	ST(0) = &sv_yes;
    }

void
ora_lob_read(dbh, locator, offset, length)
    SV *dbh
    OCILobLocator   *locator
    UV	offset
    UV	length
    PREINIT:
    D_imp_dbh(dbh);
    ub4 amtp;
    STRLEN bufp_len;
    SV *dest_sv;
    dvoid *bufp;
    sword status;
    CODE:
    dest_sv = sv_2mortal(newSV(length));
    SvPOK_on(dest_sv);
    bufp_len = SvLEN(dest_sv);	/* XXX bytes not chars? */
    bufp = SvPVX(dest_sv);
    amtp = length;	/* if utf8 and clob/nclob: in: chars, out: bytes */
#ifdef OCI_V8_SYNTAX
    /* http://www.lc.leidenuniv.nl/awcourse/oracle/appdev.920/a96584/oci16m40.htm#427818 */
    /* if locator is CLOB and data is UTF8 and not in bytes pragma */
    /* if (0 && SvUTF8(dest_sv) && !IN_BYTES) { amtp = sv_len_utf8(dest_sv); }  */
    OCILobRead_log_stat(imp_dbh->svchp, imp_dbh->errhp, locator,
	    &amtp, (ub4)offset, /* offset starts at 1 */
	    bufp, (ub4)bufp_len,
	    0, 0, (ub2)0, (ub1)SQLCS_IMPLICIT, status);
#else
    status = OCI_ERROR;
#endif
    if (status != OCI_SUCCESS) {
        oci_error(dbh, imp_dbh->errhp, status, "OCILobRead");
	dest_sv = &sv_undef;
    }
    else {
	SvCUR(dest_sv) = amtp; /* always bytes here */
	*SvEND(dest_sv) = '\0';
    }
    ST(0) = dest_sv;

void
ora_lob_trim(dbh, locator, length)
    SV *dbh
    OCILobLocator   *locator
    UV	length
    PREINIT:
    D_imp_dbh(dbh);
    sword status;
    CODE:
#ifdef OCI_V8_SYNTAX
    OCILobTrim_log_stat(imp_dbh->svchp, imp_dbh->errhp, locator, length, status);
#else
    status = OCI_ERROR;
#endif
    if (status != OCI_SUCCESS) {
        oci_error(dbh, imp_dbh->errhp, status, "OCILobTrim");
	ST(0) = &sv_undef;
    }
    else {
	ST(0) = &sv_yes;
    }

void
ora_lob_length(dbh, locator)
    SV *dbh
    OCILobLocator   *locator
    PREINIT:
    D_imp_dbh(dbh);
    sword status;
    ub4 len = 0;
    CODE:
#ifdef OCI_V8_SYNTAX
    OCILobGetLength_log_stat(imp_dbh->svchp, imp_dbh->errhp, locator, &len, status);
#else
    status = OCI_ERROR;
#endif
    if (status != OCI_SUCCESS) {
        oci_error(dbh, imp_dbh->errhp, status, "OCILobTrim");
	ST(0) = &sv_undef;
    }
    else {
	ST(0) = sv_2mortal(newSVuv(len));
    }



MODULE = DBD::Oracle    PACKAGE = DBD::Oracle::dr

void
init_oci(drh)
    SV *	drh
    CODE:
    D_imp_drh(drh);
	dbd_init_oci(DBIS) ;
	dbd_init_oci_drh(imp_drh) ;

    

	
