/*
   vim: sw=4:ts=8
   dbdimp.c

   Copyright (c) 1994-2006  Tim Bunce  Ireland

   See the COPYRIGHT section in the Oracle.pm file for terms.

*/

#ifdef WIN32
#define strcasecmp strcmpi
#endif

#ifdef __CYGWIN32__
#include "w32api/windows.h"
#include "w32api/winbase.h"
#endif /* __CYGWIN32__ */

#include "Oracle.h"

#if defined(CAN_USE_PRO_C)
/* #include <sql2oci.h>     for SQL_SINGLE_RCTX but causes clashes */
#if !defined(SQL_SINGLE_RCTX)
/* http://download-west.oracle.com/docs/cd/B10501_01/appdev.920/a97269/pc_01int.htm#1174 */
#define SQL_SINGLE_RCTX (dvoid *)0 /* from precomp/public/sqlcpr.h */
#endif
#endif

/* XXX DBI should provide a better version of this */
#define IS_DBI_HANDLE(h) \
    (SvROK(h) && SvTYPE(SvRV(h)) == SVt_PVHV && \
	SvRMAGICAL(SvRV(h)) && (SvMAGIC(SvRV(h)))->mg_type == 'P')

#ifndef SvPOK_only_UTF8
#define SvPOK_only_UTF8(sv) SvPOK_only(sv)
#endif

DBISTATE_DECLARE;

int ora_fetchtest;	/* intrnal test only, not thread safe */
int is_extproc = 0;

ub2 charsetid = 0;
ub2 ncharsetid = 0;
ub2 utf8_csid = 871;
ub2 al32utf8_csid = 873;
ub2 al16utf16_csid = 2000;

typedef struct sql_fbh_st sql_fbh_t;
struct sql_fbh_st {
  int dbtype;
  int prec;
  int scale;
};
static sql_fbh_t ora2sql_type _((imp_fbh_t* fbh));

void ora_free_phs_contents _((phs_t *phs));
static void dump_env_to_trace();

static sb4
oci_error_get(OCIError *errhp, sword status, char *what, SV *errstr, int debug)
{
    text errbuf[1024];
    ub4 recno = 0;
    sb4 errcode = 0;
    sb4 eg_errcode = 0;
    sword eg_status;

    if (!SvOK(errstr))
	sv_setpv(errstr,"");
    if (!errhp) {
	sv_catpv(errstr, oci_status_name(status));
	if (what) {
	    sv_catpv(errstr, " ");
	    sv_catpv(errstr, what);
	}
	return status;
    }

    while( ++recno
	&& OCIErrorGet_log_stat(errhp, recno, (text*)NULL, &eg_errcode, errbuf,
	    (ub4)sizeof(errbuf), OCI_HTYPE_ERROR, eg_status) != OCI_NO_DATA
	&& eg_status != OCI_INVALID_HANDLE
	&& recno < 100
    ) {
	if (debug >= 4 || recno>1/*XXX temp*/)
	    PerlIO_printf(DBILOGFP, "    OCIErrorGet after %s (er%ld:%s): %d, %ld: %s\n",
		what ? what : "<NULL>", (long)recno,
		    (eg_status==OCI_SUCCESS) ? "ok" : oci_status_name(eg_status),
		    status, (long)eg_errcode, errbuf);
	errcode = eg_errcode;
	sv_catpv(errstr, (char*)errbuf);
	if (*(SvEND(errstr)-1) == '\n')
	    --SvCUR(errstr);
    }
    if (what || status != OCI_ERROR) {
	sv_catpv(errstr, (debug<0) ? " (" : " (DBD ");
	sv_catpv(errstr, oci_status_name(status));
	if (what) {
	    sv_catpv(errstr, ": ");
	    sv_catpv(errstr, what);
	}
	sv_catpv(errstr, ")");
    }
    return errcode;
}

static int
GetRegKey(char *key, char *val, char *data, unsigned long *size)
{
#ifdef WIN32
    unsigned long len = *size - 1;
    HKEY hKey;
    long ret;

    ret = RegOpenKeyEx(HKEY_LOCAL_MACHINE, key, 0, KEY_QUERY_VALUE, &hKey);
    if (ret != ERROR_SUCCESS)
        return 0;
    ret = RegQueryValueEx(hKey, val, NULL, NULL, data, size);
    RegCloseKey(hKey);
    if ((ret != ERROR_SUCCESS) || (*size >= len))
        return 0;
    return 1;
#else
    return 0;
#endif
}

char *
ora_env_var(char *name, char *buf, unsigned long size)
{
#define WIN32_REG_BUFSIZE 80
    char last_home_id[WIN32_REG_BUFSIZE+1];
    char ora_home_key[WIN32_REG_BUFSIZE+1];
    unsigned long len = WIN32_REG_BUFSIZE;
    char *e = getenv(name);
    if (e)
	return e;
    if (!GetRegKey("SOFTWARE\\ORACLE\\ALL_HOMES", "LAST_HOME", last_home_id, &len))
	return Nullch;
    last_home_id[2] = 0;
    sprintf(ora_home_key, "SOFTWARE\\ORACLE\\HOME%s", last_home_id);
    size -= 1; /* allow room for null termination */
    if (!GetRegKey(ora_home_key, name, buf, &size))
	return Nullch;
    buf[size] = 0;
    return buf;
}

#ifdef __CYGWIN32__
/* Under Cygwin there are issues with setting environment variables
 * at runtime such that Windows-native libraries loaded by a Cygwin
 * process can see those changes.
 *
 * Cygwin maintains its own cache of environment variables, and also
 * only writes to the Windows environment using the "_putenv" win32
 * call. This call writes to a Windows C runtime cache, rather than
 * the true process environment block.
 *
 * In order to change environment variables so that the Oracle client
 * DLL can see the change, the win32 function SetEnvironmentVariable
 * must be called. This function gives an interface to that API.
 *
 * It is only available when building under Cygwin, and is used by
 * the testsuite.
 *
 * Whilst it could be called by end users, it should be used with
 * caution, as it bypasses the environment variable conversions that
 * Cygwin typically performs.
 */
void
ora_cygwin_set_env(char *name, char *value)
{
    SetEnvironmentVariable(name, value);
}
#endif /* __CYGWIN32__ */

void
dbd_init(dbistate_t *dbistate)
{
    DBIS = dbistate;
    dbd_init_oci(dbistate);
}


int
dbd_discon_all(SV *drh, imp_drh_t *imp_drh)
{
    dTHR;

    /* The disconnect_all concept is flawed and needs more work */
    if (!dirty && !SvTRUE(perl_get_sv("DBI::PERL_ENDING",0))) {
	DBIh_SET_ERR_CHAR(drh, (imp_xxh_t*)imp_drh, Nullch, 1, "disconnect_all not implemented", Nullch, Nullch);
	return FALSE;
    }
    return FALSE;
}



void
dbd_fbh_dump(imp_fbh_t *fbh, int i, int aidx)
{
    PerlIO *fp = DBILOGFP;
    PerlIO_printf(fp, "    fbh %d: '%s'\t%s, ",
		i, fbh->name, (fbh->nullok) ? "NULLable" : "NO null ");
    PerlIO_printf(fp, "otype %3d->%3d, dbsize %ld/%ld, p%d.s%d\n",
	    fbh->dbtype, fbh->ftype, (long)fbh->dbsize,(long)fbh->disize,
	    fbh->prec, fbh->scale);
    if (fbh->fb_ary) {
    PerlIO_printf(fp, "      out: ftype %d, bufl %d. indp %d, rlen %d, rcode %d\n",
	    fbh->ftype, fbh->fb_ary->bufl, fbh->fb_ary->aindp[aidx],
	    fbh->fb_ary->arlen[aidx], fbh->fb_ary->arcode[aidx]);
    }
}


int
ora_dbtype_is_long(int dbtype)
{
    /* Is it a LONG, LONG RAW, LONG VARCHAR or LONG VARRAW type?	*/
    /* Return preferred type code to use if it's a long, else 0.	*/
    if (dbtype == 8 || dbtype == 24)	/* LONG or LONG RAW		*/
	return dbtype;			/*		--> same	*/
    if (dbtype == 94)			/* LONG VARCHAR			*/
	return 8;			/*		--> LONG	*/
    if (dbtype == 95)			/* LONG VARRAW			*/
	return 24;			/*		--> LONG RAW	*/
    return 0;
}

static int
oratype_bind_ok(int dbtype) /* It's a type we support for placeholders */
{
    /* basically we support types that can be returned as strings */
    switch(dbtype) {
    case  1:	/* VARCHAR2	*/
    case  2:	/* NVARCHAR2	*/
    case  5:	/* STRING	*/
    case  8:	/* LONG		*/
    case 21:	/* BINARY FLOAT os-endian */
    case 22:	/* BINARY DOUBLE os-endian */
    case 23:	/* RAW		*/
    case 24:	/* LONG RAW	*/
    case 96:	/* CHAR		*/
    case 97:	/* CHARZ	*/
    case 100:	/* BINARY FLOAT oracle-endian */
    case 101:	/* BINARY DOUBLE oracle-endian */
    case 106:	/* MLSLABEL	*/
    case 102:	/* SQLT_CUR	OCI 7 cursor variable	*/
    case 112:	/* SQLT_CLOB / long	*/
    case 113:	/* SQLT_BLOB / long	*/
    case 116:	/* SQLT_RSET	OCI 8 cursor variable	*/
	return 1;
    }
    return 0;
}


/* --- allocate and free oracle oci 'array' buffers --- */

fb_ary_t *
fb_ary_alloc(int bufl, int size)
{
    fb_ary_t *fb_ary;
    /* these should be reworked to only to one Newz()	*/
    /* and setup the pointers in the head fb_ary struct	*/
    Newz(42, fb_ary, sizeof(fb_ary_t), fb_ary_t);
    Newz(42, fb_ary->abuf,   size * bufl, ub1);
    Newz(42, fb_ary->aindp,  size,        sb2);
    Newz(42, fb_ary->arlen,  size,        ub2);
    Newz(42, fb_ary->arcode, size,        ub2);
    fb_ary->bufl = bufl;
    return fb_ary;
}

void
fb_ary_free(fb_ary_t *fb_ary)
{
    Safefree(fb_ary->abuf);
    Safefree(fb_ary->aindp);
    Safefree(fb_ary->arlen);
    Safefree(fb_ary->arcode);
    Safefree(fb_ary);
}


/* ================================================================== */


int
dbd_db_login(SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *uid, char *pwd)
{
    return dbd_db_login6(dbh, imp_dbh, dbname, uid, pwd, Nullsv);
}


/* from shared.xs */
typedef struct {
    SV                 *sv;             /* The actual SV - in shared space */
	/* we don't need the following two */
    /*recursive_lock_t    lock; */
    /*perl_cond           user_cond;*/      /* For user-level conditions */
} shared_sv;



int
dbd_db_login6(SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *uid, char *pwd, SV *attr)
{
    dTHR;
    sword status;
    SV **svp;
    shared_sv * shared_dbh_ssv = NULL ;
    imp_dbh_t * shared_dbh     = NULL ;
#if defined(USE_ITHREADS) && defined(PERL_MAGIC_shared_scalar)
    SV **       shared_dbh_priv_svp ;
    SV *        shared_dbh_priv_sv ;
    STRLEN 	shared_dbh_len  = 0 ;
#endif
    struct OCIExtProcContext *this_ctx;
    ub4 use_proc_connection = 0;
    SV **use_proc_connection_sv;
    D_imp_drh_from_dbh;

    imp_dbh->envhp = imp_drh->envhp;	/* will be NULL on first connect */

#if defined(USE_ITHREADS) && defined(PERL_MAGIC_shared_scalar)
    shared_dbh_priv_svp = (DBD_ATTRIB_OK(attr)?hv_fetch((HV*)SvRV(attr), "ora_dbh_share", 13, 0):NULL) ;
    shared_dbh_priv_sv = shared_dbh_priv_svp?*shared_dbh_priv_svp:NULL ;

    if (shared_dbh_priv_sv && SvROK(shared_dbh_priv_sv))
	shared_dbh_priv_sv = SvRV(shared_dbh_priv_sv) ;

    if (shared_dbh_priv_sv) {
	MAGIC * mg ;

	SvLOCK (shared_dbh_priv_sv) ;

        /* some magic from shared.xs (no public api yet :-( */
	mg = mg_find(shared_dbh_priv_sv, PERL_MAGIC_shared_scalar) ;

	shared_dbh_ssv = (shared_sv * )(mg?mg -> mg_ptr:NULL) ;  /*sharedsv_find(*shared_dbh_priv_sv) ;*/
	if (!shared_dbh_ssv)
	    croak ("value of ora_dbh_share must be a scalar that is shared") ;

	shared_dbh 		= (imp_dbh_t *)SvPVX(shared_dbh_ssv -> sv) ;
	shared_dbh_len 	= SvCUR((shared_dbh_ssv -> sv)) ;
	if (shared_dbh_len > 0 && shared_dbh_len != sizeof (imp_dbh_t))
	    croak ("Invalid value for ora_dbh_dup") ;

	if (shared_dbh_len == sizeof (imp_dbh_t)) {
	    /* initialize from shared data */
            memcpy (((char *)imp_dbh) + DBH_DUP_OFF, ((char *)shared_dbh) + DBH_DUP_OFF, DBH_DUP_LEN) ;
	    shared_dbh -> refcnt++ ;
	    imp_dbh -> shared_dbh_priv_sv = shared_dbh_priv_sv ;
	    imp_dbh -> shared_dbh         = shared_dbh ;
	    if (DBIS->debug >= 2)
		PerlIO_printf(DBILOGFP, "    dbd_db_login: use shared Oracle database handles.\n");
       } else {
            shared_dbh = NULL ;
       }
    }
#endif

    /* Check if we should re-use a ProC connection and not connect ourselves. */
    DBD_ATTRIB_GET_IV(attr, "ora_use_proc_connection", 23,
		      use_proc_connection_sv, use_proc_connection);

    imp_dbh->get_oci_handle = oci_db_handle;

    if (DBIS->debug >= 6 )
	dump_env_to_trace();

    if ((svp=DBD_ATTRIB_GET_SVP(attr, "ora_envhp", 9)) && SvOK(*svp)) {
	if (!SvTRUE(*svp)) {
	    imp_dbh->envhp = NULL; /* force new environment */
	}
	else {
	    IV tmp;
	    if (!sv_isa(*svp, "ExtProc::OCIEnvHandle"))
		croak("ora_envhp value is not of type ExtProc::OCIEnvHandle");
	    tmp = SvIV((SV*)SvRV(*svp));
	    imp_dbh->envhp = (struct OCIEnv *)tmp;
	}
    }

    /* "extproc" dbname is special if "ora_context" attribute also given */
    if (strEQ(dbname,"extproc") && (svp=DBD_ATTRIB_GET_SVP(attr, "ora_context", 11))) {
	IV tmp;
	SV **svcsvp;
	SV **errsvp;
	if (!svp)
	    croak("pointer to context SV is NULL");
	if (!sv_isa(*svp, "ExtProc::OCIExtProcContext"))
	    croak("ora_context value is not of type ExtProc::OCIExtProcContext");
	tmp = SvIV((SV*)SvRV(*svp));
	this_ctx = (struct OCIExtProcContext *)tmp;
	if (this_ctx == NULL)
	    croak("ora_context referenced ExtProc value is NULL");
	/* new */
	if ((svcsvp=DBD_ATTRIB_GET_SVP(attr, "ora_svchp", 9)) &&
	    (errsvp=DBD_ATTRIB_GET_SVP(attr, "ora_errhp", 9))
	) {
		if (!sv_isa(*svcsvp, "ExtProc::OCISvcHandle"))
	   		croak("ora_svchp value is not of type ExtProc::OCISvcHandle");
		tmp = SvIV((SV*)SvRV(*svcsvp));
		imp_dbh->svchp = (struct OCISvcCtx *)tmp;
		if (!sv_isa(*errsvp, "ExtProc::OCIErrHandle"))
	   		croak("ora_errhp value is not of type ExtProc::OCIErrHandle");
		tmp = SvIV((SV*)SvRV(*errsvp));
		imp_dbh->errhp = (struct OCIError *)tmp;
	}
	/* end new */
	else {
		status = OCIExtProcGetEnv(this_ctx, &imp_dbh->envhp,
			&imp_dbh->svchp, &imp_dbh->errhp);
		if (status != OCI_SUCCESS) {
		    oci_error(dbh, (OCIError*)imp_dbh->envhp, status, "OCIExtProcGetEnv");
		    return 0;
		}
	}
	is_extproc = 1;
	goto dbd_db_login6_out;
    }

    if (!imp_dbh->envhp || is_extproc) {
	SV **init_mode_sv;
	ub4 init_mode = OCI_OBJECT;	/* needed for LOBs (8.0.4)	*/
	DBD_ATTRIB_GET_IV(attr, "ora_init_mode",13, init_mode_sv, init_mode);
#if defined(USE_ITHREADS) || defined(MULTIPLICITY) || defined(USE_5005THREADS)
	init_mode |= OCI_THREADED;
#endif

	if (use_proc_connection) {
	    char *err_hint = Nullch;
#ifdef SQL_SINGLE_RCTX
	    /* Use existing SQLLIB connection. Do not call OCIInitialize(),	*/
	    /* since presumably SQLLIB already did that.			*/
	    status = SQLEnvGet(SQL_SINGLE_RCTX, &imp_dbh->envhp);
	    imp_dbh->proc_handles = 1;
#else
	    status = OCI_ERROR;
	    err_hint = "ProC connection reuse not available in this build of DBD::Oracle";
#endif /* SQL_SINGLE_RCTX*/
	    if (status != SQL_SUCCESS) {
		if (!err_hint)
		    err_hint = "SQLEnvGet failed to load ProC environment";
		oci_error(dbh, NULL, status, err_hint);
		return 0;
	    }
	}
	else {		/* Normal connect. */

            size_t rsize = 0;

	    imp_dbh->proc_handles = 0;

#ifdef NEW_OCI_INIT	/* XXX needs merging into use_proc_connection branch */

	    /* Get CLIENT char and nchar charset id values */
            OCINlsEnvironmentVariableGet_log_stat( &charsetid, 0, OCI_NLS_CHARSET_ID, 0, &rsize ,status );
            if (status != OCI_SUCCESS) {
                oci_error(dbh, NULL, status,
                    "OCINlsEnvironmentVariableGet(OCI_NLS_CHARSET_ID) Check ORACLE_HOME and NLS settings etc.");
                return 0;
            }

            OCINlsEnvironmentVariableGet_log_stat( &ncharsetid, 0, OCI_NLS_NCHARSET_ID, 0, &rsize ,status );
            if (status != OCI_SUCCESS) {
                oci_error(dbh, NULL, status,
                    "OCINlsEnvironmentVariableGet(OCI_NLS_NCHARSET_ID) Check ORACLE_HOME and NLS settings etc.");
                return 0;
            }

	    /*{
	    After using OCIEnvNlsCreate() to create the environment handle,
	    **the actual lengths and returned lengths of bind and define handles are
	    always in number of bytes**. This applies to the following calls:

	      * OCIBindByName()   * OCIBindByPos()      * OCIBindDynamic()
	      * OCIDefineByPos()  * OCIDefineDynamic()

	    This function enables you to set charset and ncharset ids at
	    environment creation time. [...]

	    This function sets nonzero charset and ncharset as client side
	    database and national character sets, replacing the ones specified
	    by NLS_LANG and NLS_NCHAR. When charset and ncharset are 0, it
	    behaves exactly the same as OCIEnvCreate(). Specifically, charset
	    controls the encoding for metadata and data with implicit form
	    attribute and ncharset controls the encoding for data with SQLCS_NCHAR
	    form attribute.
	    }*/

            OCIEnvNlsCreate_log_stat( &imp_dbh->envhp, init_mode, 0, NULL, NULL, NULL, 0, 0,
			charsetid, ncharsetid, status );
            if (status != OCI_SUCCESS) {
                oci_error(dbh, NULL, status,
                    "OCIEnvNlsCreate. Check ORACLE_HOME env var, NLS settings, permissions, etc.");
                return 0;
            }

            /* update the hard-coded csid constants for unicode charsets */
            utf8_csid      = OCINlsCharSetNameToId(imp_dbh->envhp, (void*)"UTF8");
            al32utf8_csid  = OCINlsCharSetNameToId(imp_dbh->envhp, (void*)"AL32UTF8");
            al16utf16_csid = OCINlsCharSetNameToId(imp_dbh->envhp, (void*)"AL16UTF16");

#else /* (the old init code) NEW_OCI_INIT */

	    /* XXX recent oracle docs recommend using OCIEnvCreate() instead of	*/
	    /* OCIInitialize + OCIEnvInit, we'd need ifdef's for pre-OCIEnvNlsCreate */

	    OCIInitialize_log_stat(init_mode, 0, 0,0,0, status);
	    if (status != OCI_SUCCESS) {
		oci_error(dbh, NULL, status,
		    "OCIInitialize. Check ORACLE_HOME env var, Oracle NLS settings, permissions etc.");
		return 0;
	    }

	    OCIEnvInit_log_stat( &imp_dbh->envhp, OCI_DEFAULT, 0, 0, status);
	    if (status != OCI_SUCCESS) {
		oci_error(dbh, (OCIError*)imp_dbh->envhp, status, "OCIEnvInit");
		return 0;
	    }
#endif /* NEW_OCI_INIT */

        }
    }

    if (shared_dbh_ssv) {
        if (!imp_dbh->envhp) {
	    if (use_proc_connection) {
		char *err_hint = Nullch;
#ifdef SQL_SINGLE_RCTX
		status = SQLEnvGet(SQL_SINGLE_RCTX, &imp_dbh->envhp);
		imp_dbh->proc_handles = 1;
#else
		status = OCI_ERROR;
		err_hint = "ProC connection reuse not available in this build of DBD::Oracle";
#endif /* SQL_SINGLE_RCTX*/
		if (status != SQL_SUCCESS) {
		    if (!err_hint)
			err_hint = "SQLEnvGet failed to load ProC environment";
		    oci_error(dbh, (OCIError*)imp_dbh->envhp, status, err_hint);
		    return 0;
		}
	    }
	    else {
		OCIEnvInit_log_stat( &imp_dbh->envhp, OCI_DEFAULT, 0, 0, status);
		imp_dbh->proc_handles = 0;
		if (status != OCI_SUCCESS) {
		    oci_error(dbh, (OCIError*)imp_dbh->envhp, status, "OCIEnvInit");
		    return 0;
		}
	    }
	}
    }

    OCIHandleAlloc_ok(imp_dbh->envhp, &imp_dbh->errhp, OCI_HTYPE_ERROR,  status);

#ifndef NEW_OCI_INIT /* have to get charsetid & ncharsetid the old way */
#if defined(OCI_ATTR_ENV_CHARSET_ID) && !defined(ORA_OCI_8)	/* Oracle 9.0+ */
    OCIAttrGet_log_stat(imp_dbh->envhp, OCI_HTYPE_ENV, &charsetid, (ub4)0 ,
			OCI_ATTR_ENV_CHARSET_ID, imp_dbh->errhp, status);
    if (status != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, status, "OCIAttrGet OCI_ATTR_ENV_CHARSET_ID");
	return 0;
    }
    OCIAttrGet_log_stat(imp_dbh->envhp, OCI_HTYPE_ENV, &ncharsetid, (ub4)0 ,
			OCI_ATTR_ENV_NCHARSET_ID, imp_dbh->errhp, status);
    if (status != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, status, "OCIAttrGet OCI_ATTR_ENV_NCHARSET_ID");
	return 0;
    }
#else				/* Oracle 8.x */
    {
	/* We don't have a way to get the actual charsetid & ncharsetid in use
	*  but we only care about UTF8 so we'll just check for that and use the
	*  the hardcoded utf8_csid if found
	*/
	char buf[81];
	char *nls = ora_env_var("NLS_LANG", buf, sizeof(buf)-1);
	if (nls && strlen(nls) >= 4 && !strcasecmp(nls + strlen(nls) - 4, "utf8"))
	    charsetid = utf8_csid;
	nls = ora_env_var("NLS_NCHAR", buf, sizeof(buf)-1);
	if (nls && strlen(nls) >= 4 && !strcasecmp(nls + strlen(nls) - 4, "utf8"))
	     ncharsetid = utf8_csid;
    }
#endif
#endif

    /* At this point we have charsetid & ncharsetid
    *  note that it is possible for charsetid and ncharestid to
    *  be distinct if NLS_LANG and NLS_NCHAR are both used.
    *  BTW: NLS_NCHAR is set as follows: NSL_LANG=AL32UTF8
    */
    if (DBIS->debug >= 3) {
	PerlIO_printf(DBILOGFP,"       charsetid=%d ncharsetid=%d "
	    "(csid: utf8=%d al32utf8=%d)\n",
	     charsetid, ncharsetid, utf8_csid, al32utf8_csid);
    }


    if (!shared_dbh) {
	if(use_proc_connection) {
#ifdef SQL_SINGLE_RCTX
	    imp_dbh->proc_handles = 1;
	    status = SQLSvcCtxGet(SQL_SINGLE_RCTX, dbname, strlen(dbname),
				  &imp_dbh->svchp);
	    if (status != SQL_SUCCESS) {
		oci_error(dbh, imp_dbh->errhp, status, "SQLSvcCtxGet");
		OCIHandleFree_log_stat(imp_dbh->errhp, OCI_HTYPE_ERROR,  status);
		return 0;
	    }

	    OCIAttrGet_log_stat(imp_dbh->svchp, OCI_HTYPE_SVCCTX, &imp_dbh->srvhp, NULL,
				OCI_ATTR_SERVER, imp_dbh->errhp, status);
	    if (status != OCI_SUCCESS) {
		oci_error(dbh, imp_dbh->errhp, status,
			  "OCIAttrGet. Failed to get server context.");
		OCIHandleFree_log_stat(imp_dbh->errhp, OCI_HTYPE_ERROR,  status);
		return 0;
	    }

	    OCIAttrGet_log_stat(imp_dbh->svchp, OCI_HTYPE_SVCCTX, &imp_dbh->authp, NULL,
				OCI_ATTR_SESSION, imp_dbh->errhp, status);
	    if (status != OCI_SUCCESS) {
		oci_error(dbh, imp_dbh->errhp, status,
			  "OCIAttrGet. Failed to get authentication context.");
		OCIHandleFree_log_stat(imp_dbh->errhp, OCI_HTYPE_ERROR,  status);
		return 0;
	    }
#else /* SQL_SINGLE_RCTX */
	    oci_error(dbh, (OCIError*)imp_dbh->envhp, OCI_ERROR,
		"ProC connection reuse not available in this build of DBD::Oracle");
#endif /* SQL_SINGLE_RCTX*/
	}
	else {			/* !use_proc_connection */
	    imp_dbh->proc_handles = 0;
	    OCIHandleAlloc_ok(imp_dbh->envhp, &imp_dbh->srvhp, OCI_HTYPE_SERVER, status);
	    OCIHandleAlloc_ok(imp_dbh->envhp, &imp_dbh->svchp, OCI_HTYPE_SVCCTX, status);

	    OCIServerAttach_log_stat(imp_dbh, dbname, status);
	    if (status != OCI_SUCCESS) {
		oci_error(dbh, imp_dbh->errhp, status, "OCIServerAttach");
		OCIHandleFree_log_stat(imp_dbh->srvhp, OCI_HTYPE_SERVER, status);
		OCIHandleFree_log_stat(imp_dbh->svchp, OCI_HTYPE_SVCCTX, status);
		OCIHandleFree_log_stat(imp_dbh->errhp, OCI_HTYPE_ERROR,  status);
		return 0;
	    }

	    OCIAttrSet_log_stat( imp_dbh->svchp, OCI_HTYPE_SVCCTX, imp_dbh->srvhp,
			    (ub4) 0, OCI_ATTR_SERVER, imp_dbh->errhp, status);

	    OCIHandleAlloc_ok(imp_dbh->envhp, &imp_dbh->authp, OCI_HTYPE_SESSION, status);

	    {
		ub4  cred_type = ora_parse_uid(imp_dbh, &uid, &pwd);
		SV **sess_mode_type_sv;
		ub4  sess_mode_type = OCI_DEFAULT;
		DBD_ATTRIB_GET_IV(attr, "ora_session_mode",16, sess_mode_type_sv, sess_mode_type);
		OCISessionBegin_log_stat( imp_dbh->svchp, imp_dbh->errhp, imp_dbh->authp,
			    cred_type, sess_mode_type, status);
	    }
	    if (status == OCI_SUCCESS_WITH_INFO) {
		/* eg ORA-28011: the account will expire soon; change your password now */
		oci_error(dbh, imp_dbh->errhp, status, "OCISessionBegin");
		status = OCI_SUCCESS;
	    }
	    if (status != OCI_SUCCESS) {
		oci_error(dbh, imp_dbh->errhp, status, "OCISessionBegin");
		OCIServerDetach_log_stat(imp_dbh->srvhp, imp_dbh->errhp, OCI_DEFAULT, status);
		OCIHandleFree_log_stat(imp_dbh->authp, OCI_HTYPE_SESSION,status);
		OCIHandleFree_log_stat(imp_dbh->srvhp, OCI_HTYPE_SERVER, status);
		OCIHandleFree_log_stat(imp_dbh->errhp, OCI_HTYPE_ERROR,  status);
		OCIHandleFree_log_stat(imp_dbh->svchp, OCI_HTYPE_SVCCTX, status);
		return 0;
	    }

	    OCIAttrSet_log_stat(imp_dbh->svchp, (ub4) OCI_HTYPE_SVCCTX,
			   imp_dbh->authp, (ub4) 0,
			   (ub4) OCI_ATTR_SESSION, imp_dbh->errhp, status);
	} /* use_proc_connection */
    }

dbd_db_login6_out:
    DBIc_IMPSET_on(imp_dbh);	/* imp_dbh set up now			*/
    DBIc_ACTIVE_on(imp_dbh);	/* call disconnect before freeing	*/
    imp_dbh->ph_type = 1;	/* SQLT_CHR "(ORANET TYPE) character string" */
    imp_dbh->ph_csform = 0;	/* meaning auto (see dbd_rebind_ph)	*/

    if (!imp_drh->envhp)	/* cache first envhp info drh as future default */
	imp_drh->envhp = imp_dbh->envhp;

#if defined(USE_ITHREADS) && defined(PERL_MAGIC_shared_scalar)
    if (shared_dbh_ssv && !shared_dbh) {
	/* much of this could be replaced with a single sv_setpvn() */
	SvUPGRADE(shared_dbh_priv_sv, SVt_PV) ;
	SvGROW(shared_dbh_priv_sv, sizeof(imp_dbh_t) + 1) ;
	SvCUR (shared_dbh_priv_sv) = sizeof(imp_dbh_t) ;
	imp_dbh->refcnt = 1 ;
	imp_dbh->shared_dbh_priv_sv = shared_dbh_priv_sv ;
	memcpy(SvPVX(shared_dbh_priv_sv) + DBH_DUP_OFF, ((char *)imp_dbh) + DBH_DUP_OFF, DBH_DUP_LEN) ;
	SvSETMAGIC(shared_dbh_priv_sv);
	imp_dbh->shared_dbh = (imp_dbh_t *)SvPVX(shared_dbh_ssv->sv);
    }
#endif

    return 1;
}


int
dbd_db_commit(SV *dbh, imp_dbh_t *imp_dbh)
{
    sword status;
    OCITransCommit_log_stat(imp_dbh->svchp, imp_dbh->errhp, OCI_DEFAULT, status);
    if (status != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, status, "OCITransCommit");
	return 0;
    }
    return 1;
}




int
dbd_st_cancel(SV *sth, imp_sth_t *imp_sth)
{
    sword status;
    status = OCIBreak(imp_sth->svchp, imp_sth->errhp);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCIBreak");
	return 0;
    }
    return 1;
}



int
dbd_db_rollback(SV *dbh, imp_dbh_t *imp_dbh)
{
    sword status;
    OCITransRollback_log_stat(imp_dbh->svchp, imp_dbh->errhp, OCI_DEFAULT, status);
    if (status != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, status, "OCITransRollback");
	return 0;
    }
    return 1;
}


int
dbd_db_disconnect(SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHR;
    int refcnt = 1 ;

#if defined(USE_ITHREADS) && defined(PERL_MAGIC_shared_scalar)
    if (DBIc_IMPSET(imp_dbh) && imp_dbh->shared_dbh) {
	    SvLOCK (imp_dbh->shared_dbh_priv_sv) ;
	    refcnt = imp_dbh -> shared_dbh -> refcnt ;
    }
#endif

    /* We assume that disconnect will always work	*/
    /* since most errors imply already disconnected.	*/
    DBIc_ACTIVE_off(imp_dbh);

    /* Oracle will commit on an orderly disconnect.	*/
    /* See DBI Driver.xst file for the DBI approach.	*/

    if (refcnt == 1 && !imp_dbh->proc_handles) {
        sword s_se, s_sd;
	OCISessionEnd_log_stat(imp_dbh->svchp, imp_dbh->errhp, imp_dbh->authp,
			  OCI_DEFAULT, s_se);
	if (s_se) oci_error(dbh, imp_dbh->errhp, s_se, "OCISessionEnd");
	OCIServerDetach_log_stat(imp_dbh->srvhp, imp_dbh->errhp, OCI_DEFAULT, s_sd);
	if (s_sd) oci_error(dbh, imp_dbh->errhp, s_sd, "OCIServerDetach");
	if (s_se || s_sd)
	    return 0;
    }
    /* We don't free imp_dbh since a reference still exists	*/
    /* The DESTROY method is the only one to 'free' memory.	*/
    /* Note that statement objects may still exists for this dbh!	*/
    return 1;
}


void
dbd_db_destroy(SV *dbh, imp_dbh_t *imp_dbh)
{
    dTHX ;
    int refcnt = 1 ;
    sword status;

#if defined(USE_ITHREADS) && defined(PERL_MAGIC_shared_scalar)
    if (DBIc_IMPSET(imp_dbh) && imp_dbh->shared_dbh) {
	SvLOCK (imp_dbh->shared_dbh_priv_sv) ;
	refcnt = imp_dbh -> shared_dbh -> refcnt-- ;
    }
#endif

    if (refcnt == 1) {
	if (DBIc_ACTIVE(imp_dbh))
	    dbd_db_disconnect(dbh, imp_dbh);
	if (is_extproc)
	    goto dbd_db_destroy_out;
	if (!imp_dbh->proc_handles)
	{   sword status;
	    OCIHandleFree_log_stat(imp_dbh->authp, OCI_HTYPE_SESSION,status);
	    OCIHandleFree_log_stat(imp_dbh->srvhp, OCI_HTYPE_SERVER, status);
	    OCIHandleFree_log_stat(imp_dbh->svchp, OCI_HTYPE_SVCCTX, status);
	}
    }
    OCIHandleFree_log_stat(imp_dbh->errhp, OCI_HTYPE_ERROR,  status);
dbd_db_destroy_out:
    DBIc_IMPSET_off(imp_dbh);
}


int
dbd_db_STORE_attrib(SV *dbh, imp_dbh_t *imp_dbh, SV *keysv, SV *valuesv)
{
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    int on = SvTRUE(valuesv);
    int cacheit = 1;

    if (kl==10 && strEQ(key, "AutoCommit")) {
		DBIc_set(imp_dbh,DBIcf_AutoCommit, on);
    }
    else if (kl==12 && strEQ(key, "RowCacheSize")) {
		imp_dbh->RowCacheSize = SvIV(valuesv);
    }
    else if (kl==22 && strEQ(key, "ora_max_nested_cursors")) {
		imp_dbh->max_nested_cursors = SvIV(valuesv);
    }
    else if (kl==20 && strEQ(key, "ora_array_chunk_size")) {
			imp_dbh->array_chunk_size = SvIV(valuesv);
    }
    else if (kl==11 && strEQ(key, "ora_ph_type")) {
        if (SvIV(valuesv)!=1 && SvIV(valuesv)!=5 && SvIV(valuesv)!=96 && SvIV(valuesv)!=97)
		    warn("ora_ph_type must be 1 (VARCHAR2), 5 (STRING), 96 (CHAR), or 97 (CHARZ)");
		else
		    imp_dbh->ph_type = SvIV(valuesv);
   		 }

    else if (kl==13 && strEQ(key, "ora_ph_csform")) {
       	if (SvIV(valuesv)!=SQLCS_IMPLICIT && SvIV(valuesv)!=SQLCS_NCHAR)
		    warn("ora_ph_csform must be 1 (SQLCS_IMPLICIT) or 2 (SQLCS_NCHAR)");
		else
		    imp_dbh->ph_csform = (ub1)SvIV(valuesv);
	    }
    else
    {
		return FALSE;
    }

    if (cacheit) /* cache value for later DBI 'quick' fetch? */
	hv_store((HV*)SvRV(dbh), key, kl, newSVsv(valuesv), 0);
    return TRUE;
}


SV *
dbd_db_FETCH_attrib(SV *dbh, imp_dbh_t *imp_dbh, SV *keysv)
{
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    SV *retsv = Nullsv;
    /* Default to caching results for DBI dispatch quick_FETCH	*/
    int cacheit = FALSE;

    /* AutoCommit FETCH via DBI */

    if (kl==10 && strEQ(key, "AutoCommit")) {
        retsv = boolSV(DBIc_has(imp_dbh,DBIcf_AutoCommit));
    }
    else if (kl==12 && strEQ(key, "RowCacheSize")) {
	retsv = newSViv(imp_dbh->RowCacheSize);
    }
    else if (kl==22 && strEQ(key, "ora_max_nested_cursors")) {
	retsv = newSViv(imp_dbh->max_nested_cursors);
    }
    else if (kl==11 && strEQ(key, "ora_ph_type")) {
	retsv = newSViv(imp_dbh->ph_type);
    }
    else if (kl==13 && strEQ(key, "ora_ph_csform")) {
	retsv = newSViv(imp_dbh->ph_csform);
    }
    else if (kl==22 && strEQ(key, "ora_parse_error_offset")) {
       retsv = newSViv(imp_dbh->parse_error_offset);
    }
    if (!retsv)
	return Nullsv;
    if (cacheit) {	/* cache for next time (via DBI quick_FETCH)	*/
	SV **svp = hv_fetch((HV*)SvRV(dbh), key, kl, 1);
	sv_free(*svp);
	*svp = retsv;
	(void)SvREFCNT_inc(retsv);	/* so sv_2mortal won't free it	*/
    }
    if (retsv == &sv_yes || retsv == &sv_no)
	return retsv; /* no need to mortalize yes or no */
    return sv_2mortal(retsv);
}



/* ================================================================== */



void
dbd_preparse(imp_sth_t *imp_sth, char *statement)
{
    D_imp_dbh_from_sth;
    bool in_literal = FALSE;
    char in_comment = '\0';
    char *src, *start, *dest;
    phs_t phs_tpl;
    SV *phs_sv;
    int idx=0;
    char *style="", *laststyle=Nullch;
    STRLEN namelen;
    phs_t *phs;

    /* allocate room for copy of statement with spare capacity	*/
    /* for editing '?' or ':1' into ':p1' so we can use obndrv.	*/
    /* XXX should use SV and append to it */
    imp_sth->statement = (char*)safemalloc(strlen(statement) * 10);

    /* initialise phs ready to be cloned per placeholder	*/
    memset(&phs_tpl, 0, sizeof(phs_tpl));
    phs_tpl.imp_sth = imp_sth;
    phs_tpl.ftype  = imp_dbh->ph_type;
    phs_tpl.csform = imp_dbh->ph_csform;
    phs_tpl.sv = &sv_undef;

    src  = statement;
    dest = imp_sth->statement;
    while(*src) {

	if (in_comment) {
	    /* 981028-jdl on mocha.  Adding all code which deals with           */
	    /*  in_comment variable (its declaration plus 2 code blocks).       */
	    /*  Text appearing within comments should be scanned for neither    */
	    /*  placeholders nor for single quotes (which toggle the in_literal */
	    /*  boolean).  Comments like "3:00" demonstrate the former problem, */
	    /*  and contractions like "don't" demonstrate the latter problem.   */
	    /* The comment style is stored in in_comment; each style is */
	    /* terminated in a different way.                          */
	    if (in_comment == '-' && *src == '\n') {
		in_comment = '\0';
	    }
	    else if (in_comment == '/' && *src == '*' && *(src+1) == '/') {
		*dest++ = *src++; /* avoids asterisk-slash-asterisk issues */
		in_comment = '\0';
	    }
	    *dest++ = *src++;
	    continue;
	}

	if (in_literal) {
	    if (*src == in_literal)
		in_literal = 0;
	    *dest++ = *src++;
	    continue;
	}

	/* Look for comments: '-- oracle-style' or C-style	*/
	if ((*src == '-' && *(src+1) == '-') ||
	    (*src == '/' && *(src+1) == '*'))
	{
	    in_comment = *src;
	    /* We know *src & the next char are to be copied, so do */
	    /*  it.  In the case of C-style comments, it happens to */
	    /*  help us avoid slash-asterisk-slash oddities.        */
	    *dest++ = *src++;
	    *dest++ = *src++;
	    continue;
	}

	if (*src != ':' && *src != '?') {

	    if (*src == '\'' || *src == '"')
		in_literal = *src;

	    *dest++ = *src++;
	    continue;
	}

	/* only here for : or ? outside of a comment or literal	*/

	start = dest;			/* save name inc colon	*/
	*dest++ = *src++;
	if (*start == '?') {		/* X/Open standard	*/
	    sprintf(start,":p%d", ++idx); /* '?' -> ':p1' (etc)	*/
	    dest = start+strlen(start);
	    style = "?";

	} else if (isDIGIT(*src)) {	/* ':1'		*/
	    idx = atoi(src);
	    *dest++ = 'p';		/* ':1'->':p1'	*/
	    if (idx <= 0)
		croak("Placeholder :%d invalid, placeholders must be >= 1", idx);
	    while(isDIGIT(*src))
		*dest++ = *src++;
	    style = ":1";

	} else if (isALNUM(*src)) {	/* ':foo'	*/
	    while(isALNUM(*src))	/* includes '_'	*/
		*dest++ = toLOWER(*src), src++;
	    style = ":foo";
	} else {			/* perhaps ':=' PL/SQL construct */
	    /* if (src == ':') *dest++ = *src++; XXX? move past '::'? */
	    continue;
	}
	*dest = '\0';			/* handy for debugging	*/
	namelen = (dest-start);
	if (laststyle && style != laststyle)
	    croak("Can't mix placeholder styles (%s/%s)",style,laststyle);
	laststyle = style;
	if (imp_sth->all_params_hv == NULL)
	    imp_sth->all_params_hv = newHV();
	phs_sv = newSVpv((char*)&phs_tpl, sizeof(phs_tpl)+namelen+1);
	phs = (phs_t*)(void*)SvPVX(phs_sv);
	hv_store(imp_sth->all_params_hv, start, namelen, phs_sv, 0);
	phs->idx = idx-1;       /* Will be 0 for :1, -1 for :foo. */
    strcpy(phs->name, start);

    }
    *dest = '\0';
    if (imp_sth->all_params_hv) {
	DBIc_NUM_PARAMS(imp_sth) = (int)HvKEYS(imp_sth->all_params_hv);
	if (DBIS->debug >= 2)
	    PerlIO_printf(DBILOGFP, "    dbd_preparse scanned %d distinct placeholders\n",
		(int)DBIc_NUM_PARAMS(imp_sth));
    }
}


static int
ora_sql_type(imp_sth_t *imp_sth, char *name, int sql_type)
{
    /* XXX should detect DBI reserved standard type range here */

    switch (sql_type) {
    case SQL_NUMERIC:
    case SQL_DECIMAL:
    case SQL_INTEGER:
    case SQL_BIGINT:
    case SQL_TINYINT:
    case SQL_SMALLINT:
    case SQL_FLOAT:
    case SQL_REAL:
    case SQL_DOUBLE:
    case SQL_VARCHAR:
	return 1;	/* Oracle VARCHAR2	*/

    case SQL_CHAR:
	return 96;	/* Oracle CHAR		*/

    case SQL_BINARY:
    case SQL_VARBINARY:
	return 23;	/* Oracle RAW		*/

    case SQL_LONGVARBINARY:
	return 24;	/* Oracle LONG RAW	*/

    case SQL_LONGVARCHAR:
	return 8;	/* Oracle LONG		*/

    case SQL_CLOB:
	return 112;	/* Oracle CLOB		*/

    case SQL_BLOB:
	return 113;	/* Oracle BLOB		*/

    case SQL_DATE:
    case SQL_TIME:
    case SQL_TIMESTAMP:
    default:
	if (imp_sth && DBIc_WARN(imp_sth) && name)
	    warn("SQL type %d for '%s' is not fully supported, bound as SQL_VARCHAR instead",
		sql_type, name);
	return ora_sql_type(imp_sth, name, SQL_VARCHAR);
    }
}



static int
dbd_rebind_ph_char(SV *sth, imp_sth_t *imp_sth, phs_t *phs, ub2 **alen_ptr_ptr)
{
    STRLEN value_len;
    int at_exec = 0;
    at_exec = (phs->desc_h == NULL);

    if (!SvPOK(phs->sv)) {	/* normalizations for special cases	*/
	if (SvOK(phs->sv)) {	/* ie a number, convert to string ASAP	*/
	    if (!(SvROK(phs->sv) && phs->is_inout))
		sv_2pv(phs->sv, &na);
	}
	else /* ensure we're at least an SVt_PV (so SvPVX etc work)	*/
	    SvUPGRADE(phs->sv, SVt_PV);
    }

    if (DBIS->debug >= 2) {
	char *val = neatsvpv(phs->sv,0);
 	PerlIO_printf(DBILOGFP, "       bind %s <== %.1000s (", phs->name, val);
 	if (!SvOK(phs->sv))
	    PerlIO_printf(DBILOGFP, "NULL, ");
	PerlIO_printf(DBILOGFP, "size %ld/%ld/%ld, ",
	    (long)SvCUR(phs->sv),(long)SvLEN(phs->sv),phs->maxlen);
 	PerlIO_printf(DBILOGFP, "ptype %d, otype %d%s)\n",
 	    (int)SvTYPE(phs->sv), phs->ftype,
 	    (phs->is_inout) ? ", inout" : "");
    }

    /* At the moment we always do sv_setsv() and rebind.	*/
    /* Later we may optimise this so that more often we can	*/
    /* just copy the value & length over and not rebind.	*/

    if (phs->is_inout) {	/* XXX */
	if (SvREADONLY(phs->sv))
	    croak("Modification of a read-only value attempted");
	if (imp_sth->ora_pad_empty)
	    croak("Can't use ora_pad_empty with bind_param_inout");
	if (1 || !at_exec) {
	    /* ensure room for result, 28 is magic number (see sv_2pv)	*/
	    /* don't apply 28 char min to CHAR types - probably shouldn't	*/
	    /* apply it anywhere really, trying to be too helpful.		*/
	    STRLEN min_len = (phs->ftype != 96) ? 28 : 0;
	    /* phs->sv _is_ the real live variable, it may 'mutate' later	*/
	    /* pre-upgrade to high'ish type to reduce risk of SvPVX realloc/move */
	    (void)SvUPGRADE(phs->sv, SVt_PVNV);
	    SvGROW(phs->sv, (STRLEN)(((unsigned int) phs->maxlen < min_len) ? min_len : (unsigned int) phs->maxlen)+1/*for null*/);
	}
    }

    /* At this point phs->sv must be at least a PV with a valid buffer,	*/
    /* even if it's undef (null)					*/
    /* Here we set phs->progv, phs->indp, and value_len.		*/
    if (SvOK(phs->sv)) {
	phs->progv = SvPV(phs->sv, value_len);
	phs->indp  = 0;
    }
    else {	/* it's null but point to buffer incase it's an out var	*/
	phs->progv = (phs->is_inout) ? SvPVX(phs->sv) : NULL;
	phs->indp  = -1;
	value_len  = 0;
    }
    if (imp_sth->ora_pad_empty && value_len==0) {
	sv_setpv(phs->sv, " ");
	phs->progv = SvPV(phs->sv, value_len);
    }
    phs->sv_type = SvTYPE(phs->sv);	/* part of mutation check	*/
    phs->maxlen  = ((IV)SvLEN(phs->sv))-1; /* avail buffer space (64bit safe) */
    if (phs->maxlen < 0)		/* can happen with nulls	*/
	phs->maxlen = 0;
    phs->alen = value_len + phs->alen_incnull;

    if (DBIS->debug >= 3) {
	UV neatsvpvlen = (UV)DBIc_DBISTATE(imp_sth)->neatsvpvlen;
	PerlIO_printf(DBILOGFP, "       bind %s <== '%.*s' (size %ld/%ld, otype %d, indp %d, at_exec %d)\n",
 	    phs->name,
	    (int)(phs->alen > neatsvpvlen ? neatsvpvlen : phs->alen),
	    (phs->progv) ? phs->progv : "",
 	    (long)phs->alen, (long)phs->maxlen, phs->ftype, phs->indp, at_exec);
    }

    return 1;
}


/*
 * Rebind an "in" cursor ref to its real statement handle
 * This allows passing cursor refs as "in" to pl/sql (but only if you got the
 * cursor from pl/sql to begin with)
 */
int
pp_rebind_ph_rset_in(SV *sth, imp_sth_t *imp_sth, phs_t *phs)
{
    /*dTHR; -- do we need to do this??? */
    SV * sth_csr = phs->sv;
    D_impdata(imp_sth_csr, imp_sth_t, sth_csr);
    sword status;

    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP, "    pp_rebind_ph_rset_in: BEGIN\n    calling OCIBindByName(stmhp=%p, bndhp=%p, errhp=%p, name=%s, csrstmhp=%p, ftype=%d)\n", imp_sth->stmhp, phs->bndhp, imp_sth->errhp, phs->name, imp_sth_csr->stmhp, phs->ftype);

    OCIBindByName_log_stat(imp_sth->stmhp, &phs->bndhp, imp_sth->errhp,
			   (text*)phs->name, (sb4)strlen(phs->name),
			   &imp_sth_csr->stmhp,
			   0,
			   (ub2)phs->ftype, 0,
			   NULL,
			   0, 0,
			   NULL,
			   (ub4)OCI_DEFAULT,
			   status
			   );
    if (status != OCI_SUCCESS) {
      oci_error(sth, imp_sth->errhp, status, "OCIBindByName SQLT_RSET");
      return 0;
    }
    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP, "    pp_rebind_ph_rset_in: END\n");
    return 2;
}


int
pp_exec_rset(SV *sth, imp_sth_t *imp_sth, phs_t *phs, int pre_exec)
{
    if (pre_exec) {	/* pre-execute - allocate a statement handle */
	dSP;
	D_imp_dbh_from_sth;
	HV *init_attr = newHV();
	int count;
	sword status;

	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP, "       bind %s - allocating new sth...\n", phs->name);

	/* extproc deallocates everything for us */
	if (is_extproc)
	    return 1;

	if (!phs->desc_h || 1) { /* XXX phs->desc_t != OCI_HTYPE_STMT) */
	    if (phs->desc_h) {
		OCIHandleFree_log_stat(phs->desc_h, phs->desc_t, status);
		phs->desc_h = NULL;
	    }
	    phs->desc_t = OCI_HTYPE_STMT;
	    OCIHandleAlloc_ok(imp_sth->envhp, &phs->desc_h, phs->desc_t, status);
	}
	phs->progv = (char*)&phs->desc_h;
	phs->maxlen = 0;
	OCIBindByName_log_stat(imp_sth->stmhp, &phs->bndhp, imp_sth->errhp,
		(text*)phs->name, (sb4)strlen(phs->name),
		phs->progv, 0,
		(ub2)phs->ftype, 0, /* using &phs->indp triggers ORA-01001 errors! */
		NULL, 0, 0, NULL, OCI_DEFAULT, status);
	if (status != OCI_SUCCESS) {
	    oci_error(sth, imp_sth->errhp, status, "OCIBindByName SQLT_RSET");
	    return 0;
	}
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newRV((SV*)DBIc_MY_H(imp_dbh))));
	XPUSHs(sv_2mortal(newRV((SV*)init_attr)));
	PUTBACK;
	count = perl_call_pv("DBI::_new_sth", G_ARRAY);
	SPAGAIN;
	if (count != 2)
	    croak("panic: DBI::_new_sth returned %d values instead of 2", count);
	(void)POPs;			/* discard inner handle */
	sv_setsv(phs->sv, POPs); 	/* save outer handle */
	SvREFCNT_dec(init_attr);
	PUTBACK;
	FREETMPS;
	LEAVE;
	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP, "       bind %s - allocated %s...\n",
		phs->name, neatsvpv(phs->sv, 0));

    }
    else {		/* post-execute - setup the statement handle */
	dTHR;
	SV * sth_csr = phs->sv;
	D_impdata(imp_sth_csr, imp_sth_t, sth_csr);

	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP, "       bind %s - initialising new %s for cursor 0x%lx...\n",
		phs->name, neatsvpv(sth_csr,0), (unsigned long)phs->progv);

	/* copy appropriate handles from parent statement	*/
	imp_sth_csr->envhp = imp_sth->envhp;
	imp_sth_csr->errhp = imp_sth->errhp;
	imp_sth_csr->srvhp = imp_sth->srvhp;
	imp_sth_csr->svchp = imp_sth->svchp;

	/* assign statement handle from placeholder descriptor	*/
	imp_sth_csr->stmhp = (OCIStmt*)phs->desc_h;
	phs->desc_h = NULL;		  /* tell phs that we own it now	*/

	/* force stmt_type since OCIAttrGet(OCI_ATTR_STMT_TYPE) doesn't work! */
	imp_sth_csr->stmt_type = OCI_STMT_SELECT;

	DBIc_IMPSET_on(imp_sth_csr);

	/* set ACTIVE so dbd_describe doesn't do explicit OCI describe */
	DBIc_ACTIVE_on(imp_sth_csr);
	if (!dbd_describe(sth_csr, imp_sth_csr)) {
	    return 0;
	}
    }
    return 1;
}


static int
dbd_rebind_ph(SV *sth, imp_sth_t *imp_sth, phs_t *phs)
{
    ub2 *alen_ptr = NULL;
    sword status;
    int done = 0;
    int at_exec;
    int trace_level = DBIS->debug;
    ub1 csform;
    ub2 csid;

    if (trace_level >= 5)
	PerlIO_printf(DBILOGFP, "       rebinding %s (%s, ftype %d, csid %d, csform %d, inout %d)\n",
		phs->name, (SvUTF8(phs->sv) ? "is-utf8" : "not-utf8"),
		phs->ftype, phs->csid, phs->csform, phs->is_inout);

    switch (phs->ftype) {
    case SQLT_CLOB:
    case SQLT_BLOB:
	    done = dbd_rebind_ph_lob(sth, imp_sth, phs);
	    break;
    case SQLT_RSET:
	    done = dbd_rebind_ph_rset(sth, imp_sth, phs);
	    break;
    default:
	    done = dbd_rebind_ph_char(sth, imp_sth, phs, &alen_ptr);
    }
    if (done == 2) { /* the dbd_rebind_* did the OCI bind call itself successfully */
	if (trace_level >= 3)
	    PerlIO_printf(DBILOGFP, "       bind %s done with ftype %d\n",
		    phs->name, phs->ftype);
	return 1;
    }
    if (done != 1) {
	return 0;	 /* the rebind failed	*/
    }

    at_exec = (phs->desc_h == NULL);
    OCIBindByName_log_stat(imp_sth->stmhp, &phs->bndhp, imp_sth->errhp,
	    (text*)phs->name, (sb4)strlen(phs->name),
	    phs->progv,
	    phs->maxlen ? (sb4)phs->maxlen : 1,	/* else bind "" fails	*/
	    (ub2)phs->ftype, &phs->indp,
	    NULL,	/* ub2 *alen_ptr not needed with OCIBindDynamic */
	    &phs->arcode,
	    0,		/* max elements that can fit in allocated array	*/
	    NULL,	/* (ptr to) current number of elements in array	*/
	    (ub4)(at_exec ? OCI_DATA_AT_EXEC : OCI_DEFAULT),
	    status
    );
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCIBindByName");
	return 0;
    }
    if (at_exec) {
	OCIBindDynamic_log(phs->bndhp, imp_sth->errhp,
		    (dvoid *)phs, dbd_phs_in,
		    (dvoid *)phs, dbd_phs_out, status);
	if (status != OCI_SUCCESS) {
	    oci_error(sth, imp_sth->errhp, status, "OCIBindDynamic");
	    return 0;
	}
    }

    /* some/all of the following should perhaps move into dbd_phs_in() */

    csform = phs->csform;

    if (!csform && SvUTF8(phs->sv)) {
    	/* try to default csform to avoid translation through non-unicode */
	if (CSFORM_IMPLIES_UTF8(SQLCS_NCHAR))		/* prefer NCHAR */
	    csform = SQLCS_NCHAR;
	else if (CSFORM_IMPLIES_UTF8(SQLCS_IMPLICIT))
	    csform = SQLCS_IMPLICIT;
	/* else leave csform == 0 */
	if (trace_level)
	    PerlIO_printf(DBILOGFP, "       rebinding %s with UTF8 value %s", phs->name,
		(csform == SQLCS_NCHAR)    ? "so setting csform=SQLCS_IMPLICIT" :
		(csform == SQLCS_IMPLICIT) ? "so setting csform=SQLCS_NCHAR" :
		    "but neither CHAR nor NCHAR are unicode\n");
    }

    if (csform) {
    	/* set OCI_ATTR_CHARSET_FORM before we get the default OCI_ATTR_CHARSET_ID */
	OCIAttrSet_log_stat(phs->bndhp, (ub4) OCI_HTYPE_BIND,
	    &csform, (ub4) 0, (ub4) OCI_ATTR_CHARSET_FORM, imp_sth->errhp, status);
	if ( status != OCI_SUCCESS ) {
	    oci_error(sth, imp_sth->errhp, status, ora_sql_error(imp_sth,"OCIAttrSet (OCI_ATTR_CHARSET_FORM)"));
	    return 0;
	}
    }

    if (!phs->csid_orig) {	/* get the default csid Oracle would use */
	OCIAttrGet_log_stat(phs->bndhp, OCI_HTYPE_BIND, &phs->csid_orig, (ub4)0 ,
		OCI_ATTR_CHARSET_ID, imp_sth->errhp, status);
    }

    /* if app has specified a csid then use that, else use default */
    csid = (phs->csid) ? phs->csid : phs->csid_orig;

    /* if data is utf8 but charset isn't then switch to utf8 csid */
    if (SvUTF8(phs->sv) && !CS_IS_UTF8(csid))
        csid = utf8_csid; /* not al32utf8_csid here on purpose */

    if (trace_level >= 3)
	PerlIO_printf(DBILOGFP, "       bind %s <== %s "
		"(%s, %s, csid %d->%d->%d, ftype %d, csform %d->%d, maxlen %lu, maxdata_size %lu)\n",
	      phs->name, neatsvpv(phs->sv,0),
	      (phs->is_inout) ? "inout" : "in",
	      (SvUTF8(phs->sv) ? "is-utf8" : "not-utf8"),
	      phs->csid_orig, phs->csid, csid,
	      phs->ftype, phs->csform, csform,
	      (unsigned long)phs->maxlen, (unsigned long)phs->maxdata_size);


    if (csid) {
	OCIAttrSet_log_stat(phs->bndhp, (ub4) OCI_HTYPE_BIND,
	    &csid, (ub4) 0, (ub4) OCI_ATTR_CHARSET_ID, imp_sth->errhp, status);
	if ( status != OCI_SUCCESS ) {
	    oci_error(sth, imp_sth->errhp, status, ora_sql_error(imp_sth,"OCIAttrSet (OCI_ATTR_CHARSET_ID)"));
	    return 0;
	}
    }

    if (phs->maxdata_size) {
	OCIAttrSet_log_stat(phs->bndhp, (ub4)OCI_HTYPE_BIND,
	    neatsvpv(phs->sv,0), (ub4)phs->maxdata_size, (ub4)OCI_ATTR_MAXDATA_SIZE, imp_sth->errhp, status);
	if ( status != OCI_SUCCESS ) {
	    oci_error(sth, imp_sth->errhp, status, ora_sql_error(imp_sth,"OCIAttrSet (OCI_ATTR_MAXDATA_SIZE)"));
	    return 0;
	}
    }

    return 1;
}


int
dbd_bind_ph(SV *sth, imp_sth_t *imp_sth, SV *ph_namesv, SV *newvalue, IV sql_type, SV *attribs, int is_inout, IV maxlen)
{
    SV **phs_svp;
    STRLEN name_len;
    char *name = Nullch;
    char namebuf[32];
    phs_t *phs;

    /* check if placeholder was passed as a number	*/

    if (SvGMAGICAL(ph_namesv))	/* eg tainted or overloaded */
	mg_get(ph_namesv);
    if (!SvNIOKp(ph_namesv)) {
	STRLEN i;
	name = SvPV(ph_namesv, name_len);
	if (name_len > sizeof(namebuf)-1)
	    croak("Placeholder name %s too long", neatsvpv(ph_namesv,0));
	for (i=0; i<name_len; i++) namebuf[i] = toLOWER(name[i]);
	namebuf[i] = '\0';
	name = namebuf;
    }
    if (SvNIOKp(ph_namesv) || (name && isDIGIT(name[0]))) {
	sprintf(namebuf, ":p%d", (int)SvIV(ph_namesv));
	name = namebuf;
	name_len = strlen(name);
    }
    assert(name != Nullch);

    if (SvROK(newvalue)
	&& !IS_DBI_HANDLE(newvalue)	/* dbi handle allowed for cursor variables */
	&& !SvAMAGIC(newvalue)		/* overload magic allowed (untested) */
    && !sv_derived_from(newvalue, "OCILobLocatorPtr" )  /* input LOB locator*/
    )
	croak("Can't bind a reference (%s)", neatsvpv(newvalue,0));
    if (SvTYPE(newvalue) > SVt_PVLV) /* hook for later array logic?	*/
	croak("Can't bind a non-scalar value (%s)", neatsvpv(newvalue,0));
    if (SvTYPE(newvalue) == SVt_PVLV && is_inout)	/* may allow later */
	croak("Can't bind ``lvalue'' mode scalar as inout parameter (currently)");

    if (DBIS->debug >= 2) {
	PerlIO_printf(DBILOGFP, "       bind %s <== %s (type %ld",
		name, neatsvpv(newvalue,0), (long)sql_type);
	if (is_inout)
	    PerlIO_printf(DBILOGFP, ", inout 0x%lx, maxlen %ld",
		(long)newvalue, (long)maxlen);
	if (attribs)
	    PerlIO_printf(DBILOGFP, ", attribs: %s", neatsvpv(attribs,0));
	PerlIO_printf(DBILOGFP, ")\n");
    }

    phs_svp = hv_fetch(imp_sth->all_params_hv, name, name_len, 0);
    if (phs_svp == NULL)
	croak("Can't bind unknown placeholder '%s' (%s)", name, neatsvpv(ph_namesv,0));
    phs = (phs_t*)(void*)SvPVX(*phs_svp);	/* placeholder struct	*/

    if (phs->sv == &sv_undef) {	/* first bind for this placeholder	*/
	phs->is_inout = is_inout;
	if (is_inout) {
	    /* phs->sv assigned in the code below */
	    ++imp_sth->has_inout_params;
	    /* build array of phs's so we can deal with out vars fast	*/
	    if (!imp_sth->out_params_av)
		imp_sth->out_params_av = newAV();
	    av_push(imp_sth->out_params_av, SvREFCNT_inc(*phs_svp));
	}

	if (attribs) {	/* only look for ora_type on first bind of var	*/
	    SV **svp;
	    /* Setup / Clear attributes as defined by attribs.		*/
	    /* XXX If attribs is EMPTY then reset attribs to default?	*/
	    if ( (svp=hv_fetch((HV*)SvRV(attribs), "ora_type",8, 0)) != NULL) {
		int ora_type = SvIV(*svp);
		if (!oratype_bind_ok(ora_type))
		    croak("Can't bind %s, ora_type %d not supported by DBD::Oracle",
			    phs->name, ora_type);
		if (sql_type)
		    croak("Can't specify both TYPE (%d) and ora_type (%d) for %s",
			    sql_type, ora_type, phs->name);
		phs->ftype = ora_type;
	    }
	    if ( (svp=hv_fetch((HV*)SvRV(attribs), "ora_field",9, 0)) != NULL) {
		phs->ora_field = SvREFCNT_inc(*svp);
	    }
	    if ( (svp=hv_fetch((HV*)SvRV(attribs), "ora_csform", 10, 0)) != NULL) {
		if (SvIV(*svp) == SQLCS_IMPLICIT || SvIV(*svp) == SQLCS_NCHAR)
		    phs->csform = (ub1)SvIV(*svp);
		else warn("ora_csform must be 1 (SQLCS_IMPLICIT) or 2 (SQLCS_NCHAR), not %d", SvIV(*svp));
	    }
	    if ( (svp=hv_fetch((HV*)SvRV(attribs), "ora_maxdata_size", 16, 0)) != NULL) {
		phs->maxdata_size = SvUV(*svp);
	    }
	}
	if (sql_type)
	    phs->ftype = ora_sql_type(imp_sth, phs->name, (int)sql_type);

	/* treat Oracle7 SQLT_CUR as SQLT_RSET for Oracle8	*/
	if (phs->ftype==102)
	    phs->ftype = 116;

	/* some types require the trailing null included in the length.	*/
	/* SQLT_STR=5=STRING, SQLT_AVC=97=VARCHAR	*/
	phs->alen_incnull = (phs->ftype==SQLT_STR || phs->ftype==SQLT_AVC);

    }	/* was first bind for this placeholder  */

	/* check later rebinds for any changes */
    else if (is_inout != phs->is_inout) {
	croak("Can't rebind or change param %s in/out mode after first bind (%d => %d)",
		phs->name, phs->is_inout , is_inout);
    }
    else if (sql_type && phs->ftype != ora_sql_type(imp_sth, phs->name, (int)sql_type)) {
	croak("Can't change TYPE of param %s to %d after initial bind",
		phs->name, sql_type);
    }

    phs->maxlen = maxlen;		/* 0 if not inout		*/

    if (!is_inout) {	/* normal bind so take a (new) copy of current value	*/
	if (phs->sv == &sv_undef)	/* (first time bind) */
	    phs->sv = newSV(0);
	sv_setsv(phs->sv, newvalue);
	if (SvAMAGIC(phs->sv)) /* overloaded. XXX hack, logic ought to be pushed deeper */
	    sv_pvn_force(phs->sv, &na);
    }
    else if (newvalue != phs->sv) {
	if (phs->sv)
	    SvREFCNT_dec(phs->sv);
	phs->sv = SvREFCNT_inc(newvalue);	/* point to live var	*/
    }

    return dbd_rebind_ph(sth, imp_sth, phs);
}


/* --- functions to 'complete' the fetch of a value --- */

void
dbd_phs_sv_complete(phs_t *phs, SV *sv, I32 debug)
{
    char *note = "";
    /* XXX doesn't check arcode for error, caller is expected to */
    if (phs->indp == 0) {                       /* is okay      */
	if (phs->is_inout && phs->alen == SvLEN(sv)) {
	    /* if the placeholder has not been assigned to then phs->alen */
	    /* is left untouched: still set to SvLEN(sv). If we use that  */
	    /* then we'll get garbage bytes beyond the original contents. */
	    phs->alen = SvCUR(sv);
	    note = " UNTOUCHED?";
	}
	if (SvPVX(sv)) {
	    SvCUR_set(sv, phs->alen);
	    *SvEND(sv) = '\0';
	    SvPOK_only_UTF8(sv);
	}
	else {	/* shouldn't happen */
	    debug = 2;
	    note = " [placeholder has no data buffer]";
	}
	if (debug >= 2)
	    PerlIO_printf(DBILOGFP, "       out %s = %s (arcode %d, ind %d, len %d)%s\n",
		phs->name, neatsvpv(sv,0), phs->arcode, phs->indp, phs->alen, note);
    }
    else
    if (phs->indp > 0 || phs->indp == -2) {     /* truncated    */
	if (SvPVX(sv)) {
	    SvCUR_set(sv, phs->alen);
	    *SvEND(sv) = '\0';
	    SvPOK_only_UTF8(sv);
	}
	else {	/* shouldn't happen */
	    debug = 2;
	    note = " [placeholder has no data buffer]";
	}
	if (debug >= 2)
	    PerlIO_printf(DBILOGFP,
		"       out %s = %s\t(TRUNCATED from %d to %ld, arcode %d)%s\n",
		phs->name, neatsvpv(sv,0), phs->indp, (long)phs->alen, phs->arcode, note);
    }
    else
    if (phs->indp == -1) {                      /* is NULL      */
	(void)SvOK_off(phs->sv);
	if (debug >= 2)
	    PerlIO_printf(DBILOGFP,
		"       out %s = undef (NULL, arcode %d)\n",
		phs->name, phs->arcode);
    }
    else
	croak("panic dbd_phs_sv_complete: %s bad indp %d, arcode %d", phs->name, phs->indp, phs->arcode);
}

void
dbd_phs_avsv_complete(phs_t *phs, I32 index, I32 debug)
{
    AV *av = (AV*)SvRV(phs->sv);
    SV *sv = *av_fetch(av, index, 1);
    dbd_phs_sv_complete(phs, sv, 0);
    if (debug >= 2)
	PerlIO_printf(DBILOGFP, "       out '%s'[%ld] = %s (arcode %d, ind %d, len %d)\n",
		phs->name, (long)index, neatsvpv(sv,0), phs->arcode, phs->indp, phs->alen);
}


/* --- */


int
dbd_st_execute(SV *sth, imp_sth_t *imp_sth) /* <= -2:error, >=0:ok row count, (-1=unknown count) */
{
    dTHR;
    ub4 row_count = 0;
    int debug = DBIS->debug;
    int outparams = (imp_sth->out_params_av) ? AvFILL(imp_sth->out_params_av)+1 : 0;

    D_imp_dbh_from_sth;
    sword status;
    int is_select = (imp_sth->stmt_type == OCI_STMT_SELECT);

    if (debug >= 2)
	PerlIO_printf(DBILOGFP, "    dbd_st_execute %s (out%d, lob%d)...\n",
	    oci_stmt_type_name(imp_sth->stmt_type), outparams, imp_sth->has_lobs);

    /* Don't attempt execute for nested cursor. It would be meaningless,
       and Oracle code has been seen to core dump */
    if (imp_sth->nested_cursor) {
	oci_error(sth, NULL, OCI_ERROR,
	    "explicit execute forbidden for nested cursor");
	return -2;
    }


    if (outparams) {	/* check validity of bind_param_inout SV's	*/
	int i = outparams;
	while(--i >= 0) {
	    phs_t *phs = (phs_t*)(void*)SvPVX(AvARRAY(imp_sth->out_params_av)[i]);
	    SV *sv = phs->sv;

	    /* Make sure we have the value in string format. Typically a number	*/
	    /* will be converted back into a string using the same bound buffer	*/
	    /* so the progv test below will not trip.			*/

	    /* is the value a null? */
	    phs->indp = (SvOK(sv)) ? 0 : -1;

	    if (phs->out_prepost_exec) {
		if (!phs->out_prepost_exec(sth, imp_sth, phs, 1))
		    return -2; /* out_prepost_exec already called ora_error()	*/
	    }
	    else
	    if (SvTYPE(sv) == SVt_RV && SvTYPE(SvRV(sv)) == SVt_PVAV) {
		if (debug >= 2)
 		    PerlIO_printf(DBILOGFP,
 		        "      with %s = [] (len %ld/%ld, indp %d, otype %d, ptype %d)\n",
 			phs->name,
			(long)phs->alen, (long)phs->maxlen, phs->indp,
			phs->ftype, (int)SvTYPE(sv));
		av_clear((AV*)SvRV(sv));
	    }
	    else
	    /* Some checks for mutated storage since we pointed oracle at it.	*/
	    if (SvTYPE(sv) != phs->sv_type
		    || (SvOK(sv) && !SvPOK(sv))
		    /* SvROK==!SvPOK so cursor (SQLT_CUR) handle will call dbd_rebind_ph */
		    /* that suits us for now */
		    || SvPVX(sv) != phs->progv
		    || (SvPOK(sv) && SvCUR(sv) > UB2MAXVAL)
	    ) {
		if (!dbd_rebind_ph(sth, imp_sth, phs))
		    croak("Can't rebind placeholder %s", phs->name);
	    }
	    else {
 		/* String may have grown or shrunk since it was bound	*/
 		/* so tell Oracle about it's current length		*/
		ub2 prev_alen = phs->alen;
		phs->alen = (SvOK(sv)) ? SvCUR(sv) + phs->alen_incnull : 0+phs->alen_incnull;
		if (debug >= 2)
 		    PerlIO_printf(DBILOGFP,
 		        "      with %s = '%.*s' (len %ld(%ld)/%ld, indp %d, otype %d, ptype %d)\n",
 			phs->name, (int)phs->alen,
			(phs->indp == -1) ? "" : SvPVX(sv),
			(long)phs->alen, (long)prev_alen, (long)phs->maxlen, phs->indp,
			phs->ftype, (int)SvTYPE(sv));
	    }
	}
    }

    OCIStmtExecute_log_stat(imp_sth->svchp, imp_sth->stmhp, imp_sth->errhp,
		(ub4)(is_select ? 0 : 1),
		0, 0, 0,
		/* we don't AutoCommit on select so LOB locators work */
		(ub4)((DBIc_has(imp_dbh,DBIcf_AutoCommit) && !is_select)
			? OCI_COMMIT_ON_SUCCESS : OCI_DEFAULT),
		status);
    if (status != OCI_SUCCESS) { /* may be OCI_ERROR or OCI_SUCCESS_WITH_INFO etc */
	/* we record the error even for OCI_SUCCESS_WITH_INFO */
	oci_error(sth, imp_sth->errhp, status, ora_sql_error(imp_sth,"OCIStmtExecute"));
	/* but only bail out here if not OCI_SUCCESS_WITH_INFO */
	if (status != OCI_SUCCESS_WITH_INFO)
	    return -2;
    }
    if (is_select) {
	DBIc_ACTIVE_on(imp_sth);
	DBIc_ROW_COUNT(imp_sth) = 0; /* reset (possibly re-exec'ing) */
	row_count = 0;
    }
    else {
	OCIAttrGet_stmhp_stat(imp_sth, &row_count, 0, OCI_ATTR_ROW_COUNT, status);
    }

    if (debug >= 2) {
	ub2 sqlfncode;
	OCIAttrGet_stmhp_stat(imp_sth, &sqlfncode, 0, OCI_ATTR_SQLFNCODE, status);
	PerlIO_printf(DBILOGFP,
	    "    dbd_st_execute %s returned (%s, rpc%ld, fn%d, out%d)\n",
		oci_stmt_type_name(imp_sth->stmt_type),
		oci_status_name(status),
		(long)row_count, sqlfncode, imp_sth->has_inout_params);
    }

    if (is_select && !imp_sth->done_desc) {
	/* describe and allocate storage for results (if any needed)	*/
	if (!dbd_describe(sth, imp_sth))
	    return -2; /* dbd_describe already called oci_error()	*/
    }
    if (imp_sth->has_lobs && imp_sth->stmt_type != OCI_STMT_SELECT) {
	if (!post_execute_lobs(sth, imp_sth, row_count))
	    return -2; /* post_insert_lobs already called oci_error()	*/
    }

    if (outparams) {	/* check validity of bound output SV's	*/
	int i = outparams;
	while(--i >= 0) {
 	    /* phs->alen has been updated by Oracle to hold the length of the result */
	    phs_t *phs = (phs_t*)(void*)SvPVX(AvARRAY(imp_sth->out_params_av)[i]);
	    SV *sv = phs->sv;

	    if (phs->out_prepost_exec) {
		if (!phs->out_prepost_exec(sth, imp_sth, phs, 0))
		    return -2; /* out_prepost_exec already called ora_error()	*/
	    }
	    else
	    if (SvTYPE(sv) == SVt_RV && SvTYPE(SvRV(sv)) == SVt_PVAV) {
		AV *av = (AV*)SvRV(sv);
		I32 avlen = AvFILL(av);
		if (avlen >= 0)
		    dbd_phs_avsv_complete(phs, avlen, debug);
	    }
	    else
		dbd_phs_sv_complete(phs, sv, debug);
	}
    }

    return row_count;	/* row count (0 will be returned as "0E0")	*/
}

static int
do_bind_array_exec(sth, imp_sth, phs)
    SV *sth;
    imp_sth_t *imp_sth;
    phs_t *phs;
{
    sword status;

    OCIBindByName_log_stat(imp_sth->stmhp, &phs->bndhp, imp_sth->errhp,
            (text*)phs->name, (sb4)strlen(phs->name),
            0,
            phs->maxlen ? (sb4)phs->maxlen : 1, /* else bind "" fails */
            (ub2)phs->ftype, 0,
            NULL, /* ub2 *alen_ptr not needed with OCIBindDynamic */
            0,
            0,      /* max elements that can fit in allocated array */
            NULL, /* (ptr to) current number of elements in array */
            (ub4)OCI_DATA_AT_EXEC,
            status);
    if (status != OCI_SUCCESS) {
        oci_error(sth, imp_sth->errhp, status, "OCIBindByName");
        return 0;
    }
    OCIBindDynamic_log(phs->bndhp, imp_sth->errhp,
                       (dvoid *)phs, dbd_phs_in,
                       (dvoid *)phs, dbd_phs_out, status);
    if (status != OCI_SUCCESS) {
        oci_error(sth, imp_sth->errhp, status, "OCIBindDynamic");
        return 0;
    }
    return 1;
}

static void
init_bind_for_array_exec(phs)
    phs_t *phs;
{
    if (phs->sv == &sv_undef) { /* first bind for this placeholder  */
        phs->is_inout = 0;
        phs->maxlen = 1;
        /* treat Oracle7 SQLT_CUR as SQLT_RSET for Oracle8 */
        if (phs->ftype==102)
            phs->ftype = 116;
        /* some types require the trailing null included in the length. */
        /* SQLT_STR=5=STRING, SQLT_AVC=97=VARCHAR */
        phs->alen_incnull = (phs->ftype==SQLT_STR || phs->ftype==SQLT_AVC);
    }
}

 int
ora_st_execute_array(sth, imp_sth, tuples, tuples_status, columns, exe_count)
    SV *sth;
    imp_sth_t *imp_sth;
    SV *tuples;
    SV *tuples_status;
    SV *columns;
    ub4 exe_count;
{
    dTHR;
    /*ub4 row_count = 0;*/
    int debug = DBIS->debug;
    D_imp_dbh_from_sth;
    sword status, exe_status;
    int is_select = (imp_sth->stmt_type == OCI_STMT_SELECT);
    AV *tuples_av, *tuples_status_av, *columns_av;
    ub4 oci_mode;
    ub4 num_errs;
    int i,j;
    int autocommit = DBIc_has(imp_dbh,DBIcf_AutoCommit);
    SV **sv_p;
	phs_t **phs;
	SV *sv;
	AV *av;
    int param_count;
    char namebuf[30];
    STRLEN len;

    if (debug >= 2)
 PerlIO_printf(DBILOGFP, "    ora_st_execute_array %s count=%d (%s %s %s)...\n",
                      oci_stmt_type_name(imp_sth->stmt_type), exe_count,
                      neatsvpv(tuples,0), neatsvpv(tuples_status,0),
                      neatsvpv(columns, 0));

    if (is_select) {
        croak("ora_st_execute_array(): SELECT statement not supported "
              "for array operation.");
    }

    if (imp_sth->out_params_av || imp_sth->has_lobs) {
        croak("ora_st_execute_array(): Output placeholders and LOBs not "
              "supported for array operation.");
    }

    /* Check that the `tuples' parameter is an array ref, find the length,
       and store it in the statement handle for the OCI callback. */
    if(!SvROK(tuples) || SvTYPE(SvRV(tuples)) != SVt_PVAV) {
        croak("ora_st_execute_array(): Not an array reference.");
    }
    tuples_av = (AV*)SvRV(tuples);

    /* Check the `columns' parameter. */
    if(SvTRUE(columns)) {
        if(!SvROK(columns) || SvTYPE(SvRV(columns)) != SVt_PVAV) {
          croak("ora_st_execute_array(): columns not an array peference.");
        }
        columns_av = (AV*)SvRV(columns);
    } else {
        columns_av = NULL;
    }

    /* Check the `tuples_status' parameter. */
    if(SvTRUE(tuples_status)) {
        if(!SvROK(tuples_status) || SvTYPE(SvRV(tuples_status)) != SVt_PVAV) {
          croak("ora_st_execute_array(): tuples_status not an array reference.");
        }
        tuples_status_av = (AV*)SvRV(tuples_status);
        av_fill(tuples_status_av, exe_count - 1);
        /* Fill in 'unknown' exe count in every element (know not how to get
           individual execute row counts from OCI). */
        for(i = 0; (unsigned int) i < exe_count; i++) {
            av_store(tuples_status_av, i, newSViv((IV)-1));
        }
    } else {
        tuples_status_av = NULL;
    }

    /* Nothing to do if no tuples. */
    if(exe_count <= 0)
      return 0;

    /* Ensure proper OCIBindByName() calls for all placeholders.
    if(!ora_st_bind_for_array_exec(sth, imp_sth, tuples_av, exe_count,
                                   DBIc_NUM_PARAMS(imp_sth), columns_av))
        return -2;

   fix for Perl undefined warning. Moved out of function back out to main code
   Still ensures proper OCIBindByName*/

        param_count=DBIc_NUM_PARAMS(imp_sth);
        phs = safemalloc(param_count*sizeof(*phs));
        memset(phs, 0, param_count*sizeof(*phs));
        for(j = 0; (unsigned int) j < exe_count; j++) {
            sv_p = av_fetch(tuples_av, j, 0);
            if(sv_p == NULL) {
                Safefree(phs);
                croak("Cannot fetch tuple %d", j);
            }
            sv = *sv_p;
            if(!SvROK(sv) || SvTYPE(SvRV(sv)) != SVt_PVAV) {
                Safefree(phs);
                croak("Not an array ref in element %d", j);
            }
            av = (AV*)SvRV(sv);
            for(i = 0; i < param_count; i++) {
                if(!phs[i]) {
                    SV **phs_svp;

                    sprintf(namebuf, ":p%d", i+1);
                    phs_svp = hv_fetch(imp_sth->all_params_hv,
                                       namebuf, strlen(namebuf), 0);
                    if (phs_svp == NULL) {
                        Safefree(phs);
                        croak("Can't execute for non-existent placeholder :%d", i);
                    }
                    phs[i] = (phs_t*)(void*)SvPVX(*phs_svp); /* placeholder struct */
                    if(phs[i]->idx < 0) {
                        Safefree(phs);
                        croak("Placeholder %d not of ?/:1 type", i);
                    }
                    init_bind_for_array_exec(phs[i]);
                }

                sv_p = av_fetch(av, phs[i]->idx, 0);

                if(sv_p == NULL) {
                    Safefree(phs);
                    croak("Cannot fetch value for param %d in entry %d", i, j);
                }

				sv = *sv_p;

                 //check to see if value sv is a null (undef) if it is upgrade it
 				if (!SvOK(sv))
 	           	{
					SvUPGRADE(sv, SVt_PV);
				}
				else
				{
            		SvPV(sv, len);
            	}


                /* Find the value length, and increase maxlen if needed. */
                if(SvROK(sv)) {
                    Safefree(phs);
                    croak("Can't bind a reference (%s) for param %d, entry %d",
                          neatsvpv(sv,0), i, j);
                }
                if(len > (unsigned int) phs[i]->maxlen)
                    phs[i]->maxlen = len;

                /* Do OCI bind calls on last iteration. */
                if(j == exe_count - 1) {
                  if(!do_bind_array_exec(sth, imp_sth, phs[i])) {
                    Safefree(phs);
                  }
                }
            }
	  }
			Safefree(phs);

    /* Store array of bind typles, for use in OCIBindDynamic() callback. */
    imp_sth->bind_tuples = tuples_av;
    imp_sth->rowwise = (columns_av == NULL);

    oci_mode = OCI_BATCH_ERRORS;
    if(autocommit)
        oci_mode |= OCI_COMMIT_ON_SUCCESS;
    OCIStmtExecute_log_stat(imp_sth->svchp, imp_sth->stmhp, imp_sth->errhp,
                            exe_count, 0, 0, 0, oci_mode, exe_status);
    imp_sth->bind_tuples = NULL;

    if (exe_status != OCI_SUCCESS) {
 oci_error(sth, imp_sth->errhp, exe_status, ora_sql_error(imp_sth,"OCIStmtExecute"));
        if(exe_status != OCI_SUCCESS_WITH_INFO)
            return -2;
    }

    OCIAttrGet_stmhp_stat(imp_sth, &num_errs, 0, OCI_ATTR_NUM_DML_ERRORS, status);
    if (debug >= 6)
 PerlIO_printf(DBILOGFP, "    ora_st_execute_array %d errors in batch.\n",
                      num_errs);
    if(num_errs && tuples_status_av) {
        OCIError *row_errhp, *tmp_errhp;
        ub4 row_off;
        SV *err_svs[2];
        /*AV *err_av;*/
        sb4 err_code;

        err_svs[0] = newSViv((IV)0);
        err_svs[1] = newSVpvn("", 0);
        OCIHandleAlloc_ok(imp_sth->envhp, &row_errhp, OCI_HTYPE_ERROR, status);
        OCIHandleAlloc_ok(imp_sth->envhp, &tmp_errhp, OCI_HTYPE_ERROR, status);
        for(i = 0; (unsigned int) i < num_errs; i++) {
            OCIParamGet_log_stat(imp_sth->errhp, OCI_HTYPE_ERROR,
                                 tmp_errhp, (dvoid *)&row_errhp,
                                 (ub4)i, status);
            OCIAttrGet_log_stat(row_errhp, OCI_HTYPE_ERROR, &row_off, 0,
                                OCI_ATTR_DML_ROW_OFFSET, imp_sth->errhp, status);
            if (debug >= 6)
                PerlIO_printf(DBILOGFP, "    ora_st_execute_array error in row %d.\n",
                              row_off);
            sv_setpv(err_svs[1], "");
            err_code = oci_error_get(row_errhp, exe_status, NULL, err_svs[1], debug);
            sv_setiv(err_svs[0], (IV)err_code);
            av_store(tuples_status_av, row_off,
                     newRV_noinc((SV *)(av_make(2, err_svs))));
        }
        OCIHandleFree_log_stat(tmp_errhp, OCI_HTYPE_ERROR,  status);
        OCIHandleFree_log_stat(row_errhp, OCI_HTYPE_ERROR,  status);

        /* Do a commit here if autocommit is set, since Oracle
           doesn't do that for us when some rows are in error. */
        if(autocommit) {
            OCITransCommit_log_stat(imp_sth->svchp, imp_sth->errhp,
                                    OCI_DEFAULT, status);
            if (status != OCI_SUCCESS) {
                oci_error(sth, imp_sth->errhp, status, "OCITransCommit");
                return -2;
            }
        }
    }

    if(num_errs) {
        return -2;
    } else {
        ub4 row_count = 0;
 OCIAttrGet_stmhp_stat(imp_sth, &row_count, 0, OCI_ATTR_ROW_COUNT, status);
        return row_count;
    }
}




int
dbd_st_blob_read(SV *sth, imp_sth_t *imp_sth, int field, long offset, long len, SV *destrv, long destoffset)
{
    ub4 retl = 0;
    SV *bufsv;
    imp_fbh_t *fbh = &imp_sth->fbh[field];
    int ftype = fbh->ftype;

    bufsv = SvRV(destrv);
    sv_setpvn(bufsv,"",0);	/* ensure it's writable string	*/

#ifdef UTF8_SUPPORT
    if (ftype == 112 && CS_IS_UTF8(ncharsetid) ) {
      return ora_blob_read_mb_piece(sth, imp_sth, fbh, bufsv,
				    offset, len, destoffset);
    }
#endif /* UTF8_SUPPORT */

    SvGROW(bufsv, (STRLEN)destoffset+len+1); /* SvGROW doesn't do +1	*/

    retl = ora_blob_read_piece(sth, imp_sth, fbh, bufsv,
				 offset, len, destoffset);
    if (!SvOK(bufsv)) { /* ora_blob_read_piece recorded error */
        ora_free_templob(sth, imp_sth, (OCILobLocator*)fbh->desc_h);
	return 0;
    }
    ftype = ftype;	/* no unused */

    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP,
	    "    blob_read field %d+1, ftype %d, offset %ld, len %ld, destoffset %ld, retlen %ld\n",
	    field, imp_sth->fbh[field].ftype, offset, len, destoffset, (long)retl);

    SvCUR_set(bufsv, destoffset+retl);

    *SvEND(bufsv) = '\0'; /* consistent with perl sv_setpvn etc	*/

    return 1;
}


int
dbd_st_rows(SV *sth, imp_sth_t *imp_sth)
{
    ub4 row_count = 0;
    sword status;
    OCIAttrGet_stmhp_stat(imp_sth, &row_count, 0, OCI_ATTR_ROW_COUNT, status);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCIAttrGet OCI_ATTR_ROW_COUNT");
	return -1;
    }
    return row_count;
}


int
dbd_st_finish(SV *sth, imp_sth_t *imp_sth)
{
    dTHR;
    D_imp_dbh_from_sth;
    sword status;
    int num_fields = DBIc_NUM_FIELDS(imp_sth);
    int i;


    if (DBIc_DBISTATE(imp_sth)->debug >= 6)
        PerlIO_printf(DBIc_LOGPIO(imp_sth), "    dbd_st_finish\n");

    if (!DBIc_ACTIVE(imp_sth))
	return 1;

    /* Cancel further fetches from this cursor.                 */
    /* We don't close the cursor till DESTROY (dbd_st_destroy). */
    /* The application may re execute(...) it.                  */

    /* Turn off ACTIVE here regardless of errors below.		*/
    DBIc_ACTIVE_off(imp_sth);

    for(i=0; i < num_fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	if (fbh->fetch_cleanup) fbh->fetch_cleanup(sth, fbh);
    }

    if (dirty)			/* don't walk on the wild side	*/
	return 1;

    if (!DBIc_ACTIVE(imp_dbh))		/* no longer connected	*/
	return 1;

    OCIStmtFetch_log_stat(imp_sth->stmhp, imp_sth->errhp, 0,
		OCI_FETCH_NEXT, OCI_DEFAULT, status);
    if (status != OCI_SUCCESS && status != OCI_SUCCESS_WITH_INFO) {
	oci_error(sth, imp_sth->errhp, status, "Finish OCIStmtFetch");
	return 0;
    }
    return 1;
}


void
ora_free_fbh_contents(imp_fbh_t *fbh)
{
    if (fbh->fb_ary)
	fb_ary_free(fbh->fb_ary);
    sv_free(fbh->name_sv);
    if (fbh->desc_h)
	OCIDescriptorFree_log(fbh->desc_h, fbh->desc_t);
}

void
ora_free_phs_contents(phs_t *phs)
{
    if (phs->desc_h)
	OCIDescriptorFree_log(phs->desc_h, phs->desc_t);

    sv_free(phs->ora_field);
    sv_free(phs->sv);
}

void
ora_free_templob(SV *sth, imp_sth_t *imp_sth, OCILobLocator *lobloc)
{
#if defined(OCI_HTYPE_DIRPATH_FN_CTX)	/* >= 9.0 */
    boolean is_temporary = 0;
    sword status;
    OCILobIsTemporary_log_stat(imp_sth->envhp, imp_sth->errhp, lobloc, &is_temporary, status);
    if (status != OCI_SUCCESS) {
        oci_error(sth, imp_sth->errhp, status, "OCILobIsTemporary");
        return;
    }

    if (is_temporary) {
        if (DBIS->debug >= 3) {
            PerlIO_printf(DBILOGFP, "       OCILobFreeTemporary %s\n", oci_status_name(status));
        }
        OCILobFreeTemporary_log_stat(imp_sth->svchp, imp_sth->errhp, lobloc, status);
        if (status != OCI_SUCCESS) {
            oci_error(sth, imp_sth->errhp, status, "OCILobFreeTemporary");
            return;
        }
    }
#endif
}


void
dbd_st_destroy(SV *sth, imp_sth_t *imp_sth)
{
    int fields;
    int i;
    sword status;
    dTHX ;

    /* Don't free the OCI statement handle for a nested cursor. It will
       be reused by Oracle on the next fetch. Indeed, we never
       free these handles. Experiment shows that Oracle frees them
       when they are no longer needed.
    */

    if (DBIc_DBISTATE(imp_sth)->debug >= 6)
	PerlIO_printf(DBIc_LOGPIO(imp_sth), "    dbd_st_destroy %s\n",
	 (dirty) ? "(OCIHandleFree skipped during global destruction)" :
	 (imp_sth->nested_cursor) ?"(OCIHandleFree skipped for nested cursor)" : "");

    if (!dirty) { /* XXX not ideal, leak may be a problem in some cases */
	if (!imp_sth->nested_cursor) {
	    OCIHandleFree_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT, status);
	    if (status != OCI_SUCCESS)
	        oci_error(sth, imp_sth->errhp, status, "OCIHandleFree");
	}
    }

    /* Free off contents of imp_sth	*/

    if (imp_sth->lob_refetch)
	ora_free_lob_refetch(sth, imp_sth);

    fields = DBIc_NUM_FIELDS(imp_sth);
    imp_sth->in_cache  = 0;
    imp_sth->eod_errno = 1403;
    for(i=0; i < fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	ora_free_fbh_contents(fbh);
    }
    Safefree(imp_sth->fbh);
    if (imp_sth->fbh_cbuf)
	Safefree(imp_sth->fbh_cbuf);
    Safefree(imp_sth->statement);

    if (imp_sth->out_params_av)
	sv_free((SV*)imp_sth->out_params_av);

    if (imp_sth->all_params_hv) {
	HV *hv = imp_sth->all_params_hv;
	SV *sv;
	char *key;
	I32 retlen;
	hv_iterinit(hv);
	while( (sv = hv_iternextsv(hv, &key, &retlen)) != NULL ) {
	    if (sv != &sv_undef) {
		  phs_t *phs = (phs_t*)(void*)SvPVX(sv);


	      if (phs->desc_h && phs->desc_t == OCI_DTYPE_LOB)
	        ora_free_templob(sth, imp_sth, (OCILobLocator*)phs->desc_h);


	      ora_free_phs_contents(phs);
	    }
	}
	sv_free((SV*)imp_sth->all_params_hv);
    }

    DBIc_IMPSET_off(imp_sth);		/* let DBI know we've done it	*/
}


int
dbd_st_STORE_attrib(SV *sth, imp_sth_t *imp_sth, SV *keysv, SV *valuesv)
{
    STRLEN kl;
    SV *cachesv = NULL;
    char *key = SvPV(keysv,kl);
/*
    int on = SvTRUE(valuesv);
    int oraperl = DBIc_COMPAT(imp_sth); */

    if (strEQ(key, "ora_fetchtest")) {
	ora_fetchtest = SvIV(valuesv);
    }
    else
	return FALSE;

    if (cachesv) /* cache value for later DBI 'quick' fetch? */
	hv_store((HV*)SvRV(sth), key, kl, cachesv, 0);
    return TRUE;
}


SV *
dbd_st_FETCH_attrib(SV *sth, imp_sth_t *imp_sth, SV *keysv)
{
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    int i;
    SV *retsv = NULL;
    /* Default to caching results for DBI dispatch quick_FETCH	*/
    int cacheit = TRUE;
    /* int oraperl = DBIc_COMPAT(imp_sth); */

    if (kl==13 && strEQ(key, "NUM_OF_PARAMS"))	/* handled by DBI */
	return Nullsv;

    if (!imp_sth->done_desc && !dbd_describe(sth, imp_sth)) {
	STRLEN lna;
	/* dbd_describe has already called ora_error()		*/
	/* we can't return Nullsv here because the xs code will	*/
	/* then just pass the attribute name to DBI for FETCH.	*/
	croak("Describe failed during %s->FETCH(%s): %ld: %s",
		SvPV(sth,na), key, (long)SvIV(DBIc_ERR(imp_sth)),
		SvPV(DBIc_ERRSTR(imp_sth),lna)
	);
    }

    i = DBIc_NUM_FIELDS(imp_sth);

    if (kl==4 && strEQ(key, "NAME")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSVpv((char*)imp_sth->fbh[i].name,0));

    } else if (kl==11 && strEQ(key, "ParamValues")) {
	HV *pvhv = newHV();
	if (imp_sth->all_params_hv) {
	    SV *sv;
	    char *key;
	    I32 keylen;
	    hv_iterinit(imp_sth->all_params_hv);
	    while ( (sv = hv_iternextsv(imp_sth->all_params_hv, &key, &keylen)) ) {
		phs_t *phs = (phs_t*)(void*)SvPVX(sv);       /* placeholder struct   */
		hv_store(pvhv, key, keylen, newSVsv(phs->sv), 0);
	    }
	}
	retsv = newRV_noinc((SV*)pvhv);
	cacheit = FALSE;

    } else if (kl==11 && strEQ(key, "ora_lengths")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv((IV)imp_sth->fbh[i].disize));

    } else if (kl==9 && strEQ(key, "ora_types")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv(imp_sth->fbh[i].dbtype));

    } else if (kl==4 && strEQ(key, "TYPE")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv(ora2sql_type(imp_sth->fbh+i).dbtype));

    } else if (kl==5 && strEQ(key, "SCALE")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv(ora2sql_type(imp_sth->fbh+i).scale));

    } else if (kl==9 && strEQ(key, "PRECISION")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv(ora2sql_type(imp_sth->fbh+i).prec));

#ifdef XXX
    } else if (kl==9 && strEQ(key, "ora_rowid")) {
	/* return current _binary_ ROWID (oratype 11) uncached	*/
	/* Use { ora_type => 11 } when binding to a placeholder	*/
	retsv = newSVpv((char*)&imp_sth->cda->rid, sizeof(imp_sth->cda->rid));
	cacheit = FALSE;
#endif

    } else if (kl==17 && strEQ(key, "ora_est_row_width")) {
	retsv = newSViv(imp_sth->est_width);
	cacheit = TRUE;

    } else if (kl==8 && strEQ(key, "NULLABLE")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, boolSV(imp_sth->fbh[i].nullok));

    } else {
	return Nullsv;
    }
    if (cacheit) { /* cache for next time (via DBI quick_FETCH)	*/
	SV **svp = hv_fetch((HV*)SvRV(sth), key, kl, 1);
	sv_free(*svp);
	*svp = retsv;
	(void)SvREFCNT_inc(retsv);	/* so sv_2mortal won't free it	*/
    }
    return sv_2mortal(retsv);
}

/* --------------------------------------- */

static sql_fbh_t
ora2sql_type(imp_fbh_t* fbh) {
    sql_fbh_t sql_fbh;
    sql_fbh.dbtype = fbh->dbtype;
    sql_fbh.prec   = fbh->prec;
    sql_fbh.scale  = fbh->scale;

    switch(fbh->dbtype) { /* oracle Internal (not external) types */
    case SQLT_NUM:
        if (fbh->scale == -127) { /* FLOAT, REAL, DOUBLE_PRECISION */
            sql_fbh.dbtype = SQL_DOUBLE;
            sql_fbh.scale  = 0; /* better: undef */
            if (fbh->prec == 0) { /* NUMBER; s. Oracle Bug# 2755842, 2235818 */
                sql_fbh.prec   = 126;
            }
        }
        else if (fbh->scale == 0) {
            if (fbh->prec == 0) { /* NUMBER */
                sql_fbh.dbtype = SQL_DOUBLE;
                sql_fbh.prec   = 126;
            }
            else { /* INTEGER, NUMBER(p,0) */
                sql_fbh.dbtype = SQL_DECIMAL; /* better: SQL_INTEGER */
            }
	}
        else { /* NUMBER(p,s) */
            sql_fbh.dbtype = SQL_DECIMAL; /* better: SQL_NUMERIC */
        }
        break;
#ifdef SQLT_IBDOUBLE
    case SQLT_BDOUBLE:
    case SQLT_BFLOAT:
    case SQLT_IBDOUBLE:
    case SQLT_IBFLOAT:
               sql_fbh.dbtype = SQL_DOUBLE;
               sql_fbh.prec   = 126;
               break;
#endif
    case SQLT_CHR:  sql_fbh.dbtype = SQL_VARCHAR;       break;
    case SQLT_LNG:  sql_fbh.dbtype = SQL_LONGVARCHAR;   break; /* long */
    case SQLT_DAT:  sql_fbh.dbtype = SQL_TYPE_TIMESTAMP;break;
    case SQLT_BIN:  sql_fbh.dbtype = SQL_BINARY;        break; /* raw */
    case SQLT_LBI:  sql_fbh.dbtype = SQL_LONGVARBINARY; break; /* long raw */
    case SQLT_AFC:  sql_fbh.dbtype = SQL_CHAR;          break; /* Ansi fixed char */
    case SQLT_CLOB: sql_fbh.dbtype = SQL_CLOB;		break;
    case SQLT_BLOB: sql_fbh.dbtype = SQL_BLOB;		break;
#ifdef SQLT_TIMESTAMP_TZ
    case SQLT_DATE:		sql_fbh.dbtype = SQL_DATE;			break;
    case SQLT_TIME:		sql_fbh.dbtype = SQL_TIME;			break;
    case SQLT_TIME_TZ:		sql_fbh.dbtype = SQL_TYPE_TIME_WITH_TIMEZONE;	break;
    case SQLT_TIMESTAMP:	sql_fbh.dbtype = SQL_TYPE_TIMESTAMP;		break;
    case SQLT_TIMESTAMP_TZ:	sql_fbh.dbtype = SQL_TYPE_TIMESTAMP_WITH_TIMEZONE; break;
    case SQLT_TIMESTAMP_LTZ:	sql_fbh.dbtype = SQL_TYPE_TIMESTAMP_WITH_TIMEZONE; break;
    case SQLT_INTERVAL_YM:	sql_fbh.dbtype = SQL_INTERVAL_YEAR_TO_MONTH;	break;
    case SQLT_INTERVAL_DS:	sql_fbh.dbtype = SQL_INTERVAL_DAY_TO_SECOND;	break;
#endif
    default:        sql_fbh.dbtype = -9000 - fbh->dbtype; /* else map type into DBI reserved standard range */
    }
    return sql_fbh;
}

static void
dump_env_to_trace() {
    PerlIO *fp = DBILOGFP;
    int i = 0;
    char *p;
#ifndef __BORLANDC__
    extern char **environ;
#endif
    PerlIO_printf(fp, "Environment variables:\n");
    do {
	p = (char*)environ[i++];
	PerlIO_printf(fp,"\t%s\n",p);
    } while ((char*)environ[i] != '\0');
}

