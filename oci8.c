/*
   vim:sw=4:ts=8
   oci8.c

   Copyright (c) 1998-2006  Tim Bunce  Ireland
   Copyright (c) 2006-2008 John Scoles (The Pythian Group), Canada

   See the COPYRIGHT section in the Oracle.pm file for terms.

*/

#include "Oracle.h"

#ifdef UTF8_SUPPORT
#include <utf8.h>
#endif

#define sv_set_undef(sv) if (SvROK(sv)) sv_unref(sv); else SvOK_off(sv)

DBISTATE_DECLARE;



void
dbd_init_oci(dbistate_t *dbistate)
{
	dTHX;
    DBIS = dbistate;
}

void
dbd_init_oci_drh(imp_drh_t * imp_drh)
{
	dTHX;
    imp_drh->ora_long    = perl_get_sv("Oraperl::ora_long",      GV_ADDMULTI);
    imp_drh->ora_trunc   = perl_get_sv("Oraperl::ora_trunc",     GV_ADDMULTI);
    imp_drh->ora_cache   = perl_get_sv("Oraperl::ora_cache",     GV_ADDMULTI);
    imp_drh->ora_cache_o = perl_get_sv("Oraperl::ora_cache_o",   GV_ADDMULTI);

}

char *
oci_exe_mode(ub4 mode)
{

	dTHX;
	SV *sv;
    switch (mode) {
	/*----------------------- Execution Modes -----------------------------------*/
		case OCI_DEFAULT:   		return "DEFAULT";
		case OCI_BATCH_MODE:		return "BATCH_MODE"; /* batch the oci stmt for exec */
		case OCI_EXACT_FETCH:		return "EXACT_FETCH";   /* fetch exact rows specified */
		case OCI_STMT_SCROLLABLE_READONLY :		return "STMT_SCROLLABLE_READONLY";
		case OCI_DESCRIBE_ONLY:		return "DESCRIBE_ONLY";  /* only describe the statement */
		case OCI_COMMIT_ON_SUCCESS:	return "COMMIT_ON_SUCCESS";   /* commit, if successful exec */
		case OCI_NON_BLOCKING:		return "NON_BLOCKING";                /* non-blocking */
		case OCI_BATCH_ERRORS:		return "BATCH_ERRORS";   /* batch errors in array dmls */
		case OCI_PARSE_ONLY:		return "PARSE_ONLY";     /* only parse the statement */
		case OCI_SHOW_DML_WARNINGS:	return "SHOW_DML_WARNINGS";
/*		case OCI_RESULT_CACHE:		return "RESULT_CACHE";   hint to use query caching only 11 so wait this one out*/
/*		case OCI_NO_RESULT_CACHE :	return "NO_RESULT_CACHE";   hint to bypass query caching*/
	}
	sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"(UNKNOWN OCI EXECUTE MODE %d)", mode);
    return SvPVX(sv);
}

/* SQL Types we support for placeholders basically we support types that can be returned as strings */
char *
sql_typecode_name(int dbtype) {
    dTHX;
	SV *sv;
    switch(dbtype) {
        case  0:    return "DEFAULT (varchar)";
    	case  1:	return "VARCHAR";
    	case  2:	return "NVARCHAR2";
    	case  5:	return "STRING";
    	case  8:	return "LONG";
    	case 21:	return "BINARY FLOAT os-endian";
    	case 22:	return "BINARY DOUBLE os-endian";
    	case 23:	return "RAW";
    	case 24:	return "LONG RAW";
    	case 96:	return "CHAR";
    	case 97:	return "CHARZ";
    	case 100:	return "BINARY FLOAT oracle-endian";
    	case 101:	return "BINARY DOUBLE oracle-endian";
    	case 106:	return "MLSLABEL";
    	case 102:	return "SQLT_CUR	OCI 7 cursor variable";
    	case 112:	return "SQLT_CLOB / long";
    	case 113:	return "SQLT_BLOB / long";
    	case 116:	return "SQLT_RSET	OCI 8 cursor variable";
    	case ORA_VARCHAR2_TABLE:return "ORA_VARCHAR2_TABLE";
    	case ORA_NUMBER_TABLE: 	return "ORA_NUMBER_TABLE";
    	case ORA_XMLTYPE:   	return "ORA_XMLTYPE or SQLT_NTY";/* SQLT_NTY   must be carefull here as its value (108) is the same for an embedded object Well realy only XML clobs not embedded objects  */

    }
     sv = sv_2mortal(newSVpv("",0));
	 sv_grow(sv, 50);
	 sprintf(SvPVX(sv),"(UNKNOWN SQL TYPECODE %d)", dbtype);
     return SvPVX(sv);
}



char *
oci_typecode_name(int typecode){

	dTHX;
	SV *sv;

    switch (typecode) {
    	case OCI_TYPECODE_INTERVAL_YM:		return "INTERVAL_YM";
    	case OCI_TYPECODE_INTERVAL_DS:		return "NTERVAL_DS";
   		case OCI_TYPECODE_TIMESTAMP_TZ:		return "TIMESTAMP_TZ";
    	case OCI_TYPECODE_TIMESTAMP_LTZ:	return "TIMESTAMP_LTZ";
    	case OCI_TYPECODE_TIMESTAMP:		return "TIMESTAMP";
    	case OCI_TYPECODE_DATE:				return "DATE";
    	case OCI_TYPECODE_CLOB:				return "CLOB";
    	case OCI_TYPECODE_BLOB:				return "BLOB";
    	case OCI_TYPECODE_BFILE:			return "BFILE";
    	case OCI_TYPECODE_RAW:				return "RAW";
	    case OCI_TYPECODE_CHAR:				return "CHAR";
	    case OCI_TYPECODE_VARCHAR:			return "VARCHAR";
	    case OCI_TYPECODE_VARCHAR2:			return "VARCHAR2";
	    case OCI_TYPECODE_SIGNED8:			return "SIGNED8";
	    case OCI_TYPECODE_UNSIGNED8:		return "DECLARE";
    	case OCI_TYPECODE_UNSIGNED16 :    	return "UNSIGNED8";
	    case OCI_TYPECODE_UNSIGNED32 :     	return "UNSIGNED32";
	    case OCI_TYPECODE_REAL :           	return "REAL";
	    case OCI_TYPECODE_DOUBLE :         	return "DOUBLE";
	    case OCI_TYPECODE_INTEGER :         return "INT";
	    case OCI_TYPECODE_SIGNED16 :	    return "SHORT";
	    case OCI_TYPECODE_SIGNED32 :        return "LONG";
	    case OCI_TYPECODE_DECIMAL :         return "DECIMAL";
	    case OCI_TYPECODE_FLOAT :  			return "FLOAT";
	    case OCI_TYPECODE_NUMBER : 			return "NUMBER";
	    case OCI_TYPECODE_SMALLINT:			return "SMALLINT";
        case OCI_TYPECODE_OBJECT:			return "OBJECT";
    	case OCI_TYPECODE_VARRAY:			return "VARRAY";
        case OCI_TYPECODE_TABLE:			return "TABLE";
        case OCI_TYPECODE_NAMEDCOLLECTION: 	return "NAMEDCOLLECTION";
    }

    sv = sv_2mortal(newSVpv("",0));
	sv_grow(sv, 50);
	sprintf(SvPVX(sv),"(UNKNOWN OCI TYPECODE %d)", typecode);
    return SvPVX(sv);

}

char *
oci_status_name(sword status)
{
	dTHX;
    SV *sv;
    switch (status) {
    case OCI_SUCCESS:			return "SUCCESS";
    case OCI_SUCCESS_WITH_INFO:	return "SUCCESS_WITH_INFO";
    case OCI_NEED_DATA:			return "NEED_DATA";
    case OCI_NO_DATA:			return "NO_DATA";
    case OCI_ERROR:				return "ERROR";
    case OCI_INVALID_HANDLE:	return "INVALID_HANDLE";
    case OCI_STILL_EXECUTING:	return "STILL_EXECUTING";
    case OCI_CONTINUE:			return "CONTINUE";
    }
    sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"(UNKNOWN OCI STATUS %d)", status);
    return SvPVX(sv);
}

/* the various modes used in OCI */
char *
oci_define_options(ub4 options)
{
	dTHX;
    SV *sv;
    switch (options) {
	/*------------------------Bind and Define Options----------------------------*/
		case OCI_DEFAULT:   	return "DEFAULT";
		case OCI_DYNAMIC_FETCH: return "DYNAMIC_FETCH";               /* fetch dynamically */

	 }
    sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"(UNKNOWN OCI DEFINE MODE %d)", options);
    return SvPVX(sv);
}

char *
oci_bind_options(ub4 options)
{
	dTHX;
    SV *sv;
    switch (options) {
	/*------------------------Bind and Define Options----------------------------*/
		case OCI_DEFAULT:   	return "DEFAULT";
		case OCI_SB2_IND_PTR:   return "SB2_IND_PTR";                          /* unused */
		case OCI_DATA_AT_EXEC:  return "DATA_AT_EXEC";             /* data at execute time */
		case OCI_PIECEWISE:   	return "PIECEWISE";         /* piecewise DMLs or fetch */
/*		case OCI_BIND_SOFT:   	return "BIND_SOFT";                soft bind or define */
/*		case OCI_DEFINE_SOFT:   return "DEFINE_SOFT";            soft bind or define */
/*		case OCI_IOV:   		return "";   11g only release 1.23 me thinks For scatter gather bind/define */

	 }
    sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"(UNKNOWN BIND MODE %d)", options);
    return SvPVX(sv);
}

/* the various modes used in OCI */
char *
oci_mode(ub4  mode)
{
	dTHX;
    SV *sv;
    switch (mode) {
        case 3:					return "THREADED | OBJECT";
		case OCI_DEFAULT:   	return "DEFAULT";
		/* the default value for parameters and attributes */
		/*-------------OCIInitialize Modes / OCICreateEnvironment Modes -------------*/
		case OCI_THREADED:      return "THREADED";      /* appl. in threaded environment */
		case OCI_OBJECT:        return "OBJECT";  /* application in object environment */
		case OCI_EVENTS:        return "EVENTS";  /* application is enabled for events */
		case OCI_SHARED:        return "SHARED";  /* the application is in shared mode */
		/* The following *TWO* are only valid for OCICreateEnvironment call */
		case OCI_NO_UCB:        return "NO_UCB "; /* No user callback called during ini */
		case OCI_NO_MUTEX:      return "NO_MUTEX"; /* the environment handle will not be
		                                      protected by a mutex internally */
		case OCI_SHARED_EXT:     return "SHARED_EXT";              /* Used for shared forms */
		case OCI_ALWAYS_BLOCKING:return "ALWAYS_BLOCKING";    /* all connections always blocking */
		case OCI_USE_LDAP:       return "USE_LDAP";            /* allow  LDAP connections */
		case OCI_REG_LDAPONLY:   return "REG_LDAPONLY";              /* only register to LDAP */
		case OCI_UTF16:          return "UTF16";        /* mode for all UTF16 metadata */
		case OCI_AFC_PAD_ON:     return "AFC_PAD_ON";  /* turn on AFC blank padding when rlenp present */
		case OCI_NEW_LENGTH_SEMANTICS: return "NEW_LENGTH_SEMANTICS";   /* adopt new length semantics
											       the new length semantics, always bytes, is used by OCIEnvNlsCreate */
		case OCI_NO_MUTEX_STMT:  return "NO_MUTEX_STMT";           /* Do not mutex stmt handle */
		case OCI_MUTEX_ENV_ONLY: return "MUTEX_ENV_ONLY";  /* Mutex only the environment handle */
/*		case OCI_SUPPRESS_NLS_VALIDATION:  return "SUPPRESS_NLS_VALIDATION";   suppress nls validation*/
													 /* 	  nls validation suppression is on by default;*/
													  /*   use OCI_ENABLE_NLS_VALIDATION to disable it */
/*		case OCI_MUTEX_TRY:                return "MUTEX_TRY";     try and acquire mutex */
/*		case OCI_NCHAR_LITERAL_REPLACE_ON: return "NCHAR_LITERAL_REPLACE_ON";  nchar literal replace on */
/*		case OCI_NCHAR_LITERAL_REPLACE_OFF:return "NCHAR_LITERAL_REPLACE_OFF";  nchar literal replace off*/
/*		case OCI_ENABLE_NLS_VALIDATION:    return "ENABLE_NLS_VALIDATION";     enable nls validation */
		/*------------------------OCIConnectionpoolCreate Modes----------------------*/
		case OCI_CPOOL_REINITIALIZE:	return "CPOOL_REINITIALIZE";
		/*--------------------------------- OCILogon2 Modes -------------------------*/
/*case OCI_LOGON2_SPOOL:      	return "LOGON2_SPOOL";      Use session pool */
		case OCI_LOGON2_CPOOL:      	return "LOGON2_CPOOL"; /* Use connection pool */
/*case OCI_LOGON2_STMTCACHE:  	return "LOGON2_STMTCACHE";      Use Stmt Caching */
		case OCI_LOGON2_PROXY:      	return "LOGON2_PROXY";     /* Proxy authentiaction */
		/*------------------------- OCISessionPoolCreate Modes ----------------------*/
/*case OCI_SPC_REINITIALIZE:		return "SPC_REINITIALIZE";    Reinitialize the session pool */
/*case OCI_SPC_HOMOGENEOUS: 		return "SPC_HOMOGENEOUS"; "";    Session pool is homogeneneous */
/*case OCI_SPC_STMTCACHE:   		return "SPC_STMTCACHE";    Session pool has stmt cache */
/*case OCI_SPC_NO_RLB:      		return "SPC_NO_RLB ";  Do not enable Runtime load balancing. */
		/*--------------------------- OCISessionGet Modes ---------------------------*/
/*case OCI_SESSGET_SPOOL:     	return "SESSGET_SPOOL";      SessionGet called in SPOOL mode */
/*case OCI_SESSGET_CPOOL:    		return "SESSGET_CPOOL";   SessionGet called in CPOOL mode */
/*case OCI_SESSGET_STMTCACHE: 	return "SESSGET_STMTCACHE";                  Use statement cache */
/*case OCI_SESSGET_CREDPROXY: 	return "SESSGET_CREDPROXY";      SessionGet called in proxy mode */
/*case OCI_SESSGET_CREDEXT:   	return "SESSGET_CREDEXT";     */
		case OCI_SESSGET_SPOOL_MATCHANY:return "SESSGET_SPOOL_MATCHANY";
/*case OCI_SESSGET_PURITY_NEW:    return "SESSGET_PURITY_NEW";
		case OCI_SESSGET_PURITY_SELF:   return "SESSGET_PURITY_SELF"; */
    }
    sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"(UNKNOWN OCI MODE %d)", mode);
    return SvPVX(sv);
}

char *
oci_stmt_type_name(int stmt_type)
{
	dTHX;
    SV *sv;
    switch (stmt_type) {
    case OCI_STMT_SELECT:	return "SELECT";
    case OCI_STMT_UPDATE:	return "UPDATE";
    case OCI_STMT_DELETE:	return "DELETE";
    case OCI_STMT_INSERT:	return "INSERT";
    case OCI_STMT_CREATE:	return "CREATE";
    case OCI_STMT_DROP:		return "DROP";
    case OCI_STMT_ALTER:	return "ALTER";
    case OCI_STMT_BEGIN:	return "BEGIN";
    case OCI_STMT_DECLARE:	return "DECLARE";
    }
    sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"(STMT TYPE %d)", stmt_type);
    return SvPVX(sv);
}

char *
oci_col_return_codes(int rc)
{
	dTHX;
    SV *sv;
    switch (rc) {
	    case 1406:	return "TRUNCATED";
	    case 0:		return "OK";
	    case 1405:	return "NULL";
	    case 1403:	return "NO DATA";

    }
    sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"UNKNOWN RC=%d)", rc);
    return SvPVX(sv);
}

char *
oci_hdtype_name(ub4 hdtype)
{
	dTHX;
    SV *sv;
    switch (hdtype) {
    /* Handles */
    case OCI_HTYPE_ENV:                 return "OCI_HTYPE_ENV";
    case OCI_HTYPE_ERROR:               return "OCI_HTYPE_ERROR";
    case OCI_HTYPE_SVCCTX:              return "OCI_HTYPE_SVCCTX";
    case OCI_HTYPE_STMT:                return "OCI_HTYPE_STMT";
    case OCI_HTYPE_BIND:                return "OCI_HTYPE_BIND";
    case OCI_HTYPE_DEFINE:              return "OCI_HTYPE_DEFINE";
    case OCI_HTYPE_DESCRIBE:            return "OCI_HTYPE_DESCRIBE";
    case OCI_HTYPE_SERVER:              return "OCI_HTYPE_SERVER";
    case OCI_HTYPE_SESSION:             return "OCI_HTYPE_SESSION";
    /* Descriptors */
    case OCI_DTYPE_LOB:			return "OCI_DTYPE_LOB";
    case OCI_DTYPE_SNAP:		return "OCI_DTYPE_SNAP";
    case OCI_DTYPE_RSET:		return "OCI_DTYPE_RSET";
    case OCI_DTYPE_PARAM:		return "OCI_DTYPE_PARAM";
    case OCI_DTYPE_ROWID:		return "OCI_DTYPE_ROWID";
#ifdef OCI_DTYPE_REF
    case OCI_DTYPE_REF:			return "OCI_DTYPE_REF";
#endif
    }
    sv = sv_2mortal(newSViv((IV)hdtype));
    return SvPV(sv,na);
}

/*used to look up the name of a fetchtype constant
  used only for debugging */
char *
oci_fetch_options(ub4 fetchtype)
{
	dTHX;
    SV *sv;
    switch (fetchtype) {
    /* fetch options */
    	case OCI_FETCH_CURRENT:     return "OCI_FETCH_CURRENT";
    	case OCI_FETCH_NEXT:        return "OCI_FETCH_NEXT";
    	case OCI_FETCH_FIRST:       return "OCI_FETCH_FIRST";
    	case OCI_FETCH_LAST:        return "OCI_FETCH_LAST";
    	case OCI_FETCH_PRIOR:       return "OCI_FETCH_PRIOR";
    	case OCI_FETCH_ABSOLUTE:    return "OCI_FETCH_ABSOLUTE";
    	case OCI_FETCH_RELATIVE:	return "OCI_FETCH_RELATIVE";
    }
    sv = sv_2mortal(newSViv((IV)fetchtype));
    return SvPV(sv,na);
}




static sb4
oci_error_get(OCIError *errhp, sword status, char *what, SV *errstr, int debug)
{
	dTHX;
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


int
oci_error_err(SV *h, OCIError *errhp, sword status, char *what, sb4 force_err)
{
	dTHX;
    D_imp_xxh(h);
    sb4 errcode;
    SV *errstr = sv_newmortal();
    errcode = oci_error_get(errhp, status, what, errstr, DBIS->debug);

    /* DBIc_ERR *must* be SvTRUE (for RaiseError etc), some	*/
    /* errors, like OCI_INVALID_HANDLE, don't set errcode.	*/
    if (force_err)
	errcode = force_err;
    if (status == OCI_SUCCESS_WITH_INFO)
	errcode = 0;	/* record as a "warning" for DBI>=1.43 */
    else if (errcode == 0)
	errcode = (status != 0) ? status : -10000;
    DBIh_SET_ERR_CHAR(h, imp_xxh, Nullch, errcode, SvPV_nolen(errstr), Nullch, Nullch);
    return 0;	/* always returns 0 */
}


char *
ora_sql_error(imp_sth_t *imp_sth, char *msg)
{
	dTHX;
#ifdef OCI_ATTR_PARSE_ERROR_OFFSET
    D_imp_dbh_from_sth;
    SV  *msgsv, *sqlsv;
    char buf[99];
    sword status = 0;
    ub2 parse_error_offset = 0;
    OCIAttrGet_stmhp_stat(imp_sth, &parse_error_offset, 0,
                          OCI_ATTR_PARSE_ERROR_OFFSET, status);
    imp_dbh->parse_error_offset = parse_error_offset;
    if (!parse_error_offset)
        return msg;
    sprintf(buf,"error possibly near <*> indicator at char %d in '",
	    parse_error_offset);
    msgsv = sv_2mortal(newSVpv(buf,0));
    sqlsv = sv_2mortal(newSVpv(imp_sth->statement,0));
    sv_insert(sqlsv, parse_error_offset, 0, "<*>", 3);
    sv_catsv(msgsv, sqlsv);
    sv_catpv(msgsv, "'");
    return SvPV(msgsv,na);
#else
    imp_sth = imp_sth; /* not unused */
    return msg;
#endif
}


void *
oci_db_handle(imp_dbh_t *imp_dbh, int handle_type, int flags)
{
	dTHX;
     switch(handle_type) {
     case OCI_HTYPE_ENV:	return imp_dbh->envhp;
     case OCI_HTYPE_ERROR:	return imp_dbh->errhp;
     case OCI_HTYPE_SERVER:	return imp_dbh->srvhp;
     case OCI_HTYPE_SVCCTX:	return imp_dbh->svchp;
     case OCI_HTYPE_SESSION:	return imp_dbh->authp;
     }
     croak("Can't get OCI handle type %d from DBI database handle", handle_type);
     if( flags ) {/* For GCC not to warn on unused parameter */}
     /* satisfy compiler warning, even though croak will never return */
     return 0;
}

void *
oci_st_handle(imp_sth_t *imp_sth, int handle_type, int flags)
{
	dTHX;
     switch(handle_type) {
     case OCI_HTYPE_ENV:	return imp_sth->envhp;
     case OCI_HTYPE_ERROR:	return imp_sth->errhp;
     case OCI_HTYPE_SERVER:	return imp_sth->srvhp;
     case OCI_HTYPE_SVCCTX:	return imp_sth->svchp;
     case OCI_HTYPE_STMT:	return imp_sth->stmhp;
     }
     croak("Can't get OCI handle type %d from DBI statement handle", handle_type);
     if( flags ) {/* For GCC not to warn on unused parameter */}
     /* satisfy compiler warning, even though croak will never return */
     return 0;
}


int
dbd_st_prepare(SV *sth, imp_sth_t *imp_sth, char *statement, SV *attribs)
{
    dTHX;
    D_imp_dbh_from_sth;
    sword status 		 = 0;
    IV  ora_piece_size   = 0;
    IV  ora_pers_lob     = 0;
    IV  ora_piece_lob    = 0;
    IV  ora_clbk_lob     = 0;
    ub4	oparse_lng   	 = 1;  /* auto v6 or v7 as suits db connected to	*/
    int ora_check_sql 	 = 1;	/* to force a describe to check SQL	*/
    IV  ora_placeholders = 1;	/* find and handle placeholders */
	/* XXX we set ora_check_sql on for now to force setup of the	*/
	/* row cache. Change later to set up row cache using just a	*/
	/* a memory size, perhaps also default $RowCacheSize to a	*/
	/* negative value. OCI_ATTR_PREFETCH_MEMORY */

    if (!DBIc_ACTIVE(imp_dbh)) {
		oci_error(sth, NULL, OCI_ERROR, "Database disconnected");
        return 0;
    }

    imp_dbh->parse_error_offset = 0;

    imp_sth->done_desc = 0;
    imp_sth->get_oci_handle = oci_st_handle;

    if (DBIc_COMPAT(imp_sth)) {
		static SV *ora_pad_empty;
		if (!ora_pad_empty) {
		    ora_pad_empty= perl_get_sv("Oraperl::ora_pad_empty", GV_ADDMULTI);
		    if (!SvOK(ora_pad_empty) && getenv("ORAPERL_PAD_EMPTY"))
				sv_setiv(ora_pad_empty, atoi(getenv("ORAPERL_PAD_EMPTY")));
		}
		imp_sth->ora_pad_empty = (SvOK(ora_pad_empty)) ? SvIV(ora_pad_empty) : 0;
    }

    imp_sth->auto_lob = 1;
	imp_sth->exe_mode  = OCI_DEFAULT;

   	if (attribs) {
		SV **svp;
		IV ora_auto_lob = 1;
		DBD_ATTRIB_GET_IV(  attribs, "ora_parse_lang", 14, svp, oparse_lng);
		DBD_ATTRIB_GET_IV(  attribs, "ora_placeholders", 16, svp, ora_placeholders);
		DBD_ATTRIB_GET_IV(  attribs, "ora_auto_lob", 12, svp, ora_auto_lob);
		DBD_ATTRIB_GET_IV(  attribs, "ora_pers_lob", 12, svp, ora_pers_lob);
		DBD_ATTRIB_GET_IV(  attribs, "ora_clbk_lob", 12, svp, ora_clbk_lob);
		DBD_ATTRIB_GET_IV(  attribs, "ora_piece_lob", 13, svp, ora_piece_lob);
	    DBD_ATTRIB_GET_IV(  attribs, "ora_piece_size", 14, svp, ora_piece_size);

		imp_sth->auto_lob = (ora_auto_lob) ? 1 : 0;
		imp_sth->pers_lob = (ora_pers_lob) ? 1 : 0;
		imp_sth->clbk_lob = (ora_clbk_lob) ? 1 : 0;
		imp_sth->piece_lob = (ora_piece_lob) ? 1 : 0;
		imp_sth->piece_size = (ora_piece_size) ? ora_piece_size : 0;
		/* ora_check_sql only works for selects owing to Oracle behaviour */
		DBD_ATTRIB_GET_IV(  attribs, "ora_check_sql", 13, svp, ora_check_sql);
		DBD_ATTRIB_GET_IV(  attribs, "ora_exe_mode", 12, svp, imp_sth->exe_mode);
		DBD_ATTRIB_GET_IV(  attribs, "ora_prefetch_memory",  19, svp, imp_sth->prefetch_memory);
  	    DBD_ATTRIB_GET_IV(  attribs, "ora_verbose",  11, svp, dbd_verbose);

  	   	if (!dbd_verbose)
	   		DBD_ATTRIB_GET_IV(  attribs, "dbd_verbose",  11, svp, dbd_verbose);


   	}


 	/* scan statement for '?', ':1' and/or ':foo' style placeholders	*/
    if (ora_placeholders)
		dbd_preparse(imp_sth, statement);
    else imp_sth->statement = savepv(statement);

    imp_sth->envhp = imp_dbh->envhp;
    imp_sth->errhp = imp_dbh->errhp;
    imp_sth->srvhp = imp_dbh->srvhp;
    imp_sth->svchp = imp_dbh->svchp;

    switch(oparse_lng) {
    	case 0:  /* old: calls for V6 syntax - give them V7	*/
    	case 2:  /* old: calls for V7 syntax		*/
    	case 7:  oparse_lng = OCI_V7_SYNTAX;	break;
    	case 8:  oparse_lng = OCI_V8_SYNTAX;	break;
    	default: oparse_lng = OCI_NTV_SYNTAX;	break;
    }

    OCIHandleAlloc_ok(imp_dbh->envhp, &imp_sth->stmhp, OCI_HTYPE_STMT, status);
    OCIStmtPrepare_log_stat(imp_sth->stmhp, imp_sth->errhp,
	       (text*)imp_sth->statement, (ub4)strlen(imp_sth->statement),
	       oparse_lng, OCI_DEFAULT, status);

    if (status != OCI_SUCCESS) {
		oci_error(sth, imp_sth->errhp, status, "OCIStmtPrepare");
		OCIHandleFree_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT, status);
		return 0;
    }


    OCIAttrGet_stmhp_stat(imp_sth, &imp_sth->stmt_type, 0, OCI_ATTR_STMT_TYPE, status);

    if (DBIS->debug >= 3 || dbd_verbose >=3)
		PerlIO_printf(DBILOGFP, "    dbd_st_prepare'd sql %s (pl%d, auto_lob%d, check_sql%d)\n",
			oci_stmt_type_name(imp_sth->stmt_type),
			oparse_lng, imp_sth->auto_lob, ora_check_sql);

    DBIc_IMPSET_on(imp_sth);

    if (ora_check_sql) {
	if (!dbd_describe(sth, imp_sth))
	    return 0;
    }
    else {
      /* set initial cache size by memory */
      /* [I'm not now sure why this is here - from a patch sometime ago - Tim]*/
      ub4 cache_mem;
      IV cache_mem_iv;
      D_imp_dbh_from_sth ;
      D_imp_drh_from_dbh ;

      if      (SvOK(imp_drh->ora_cache_o)) cache_mem_iv = -SvIV(imp_drh -> ora_cache_o);
      else if (SvOK(imp_drh->ora_cache))   cache_mem_iv = -SvIV(imp_drh -> ora_cache);
      else                                 cache_mem_iv = -imp_dbh->RowCacheSize;
      cache_mem = (cache_mem_iv <= 0) ? 10 * 1460 : cache_mem_iv;
      OCIAttrSet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT,
	&cache_mem,  sizeof(cache_mem), OCI_ATTR_PREFETCH_MEMORY,
	imp_sth->errhp, status);
      if (status != OCI_SUCCESS) {
        oci_error(sth, imp_sth->errhp, status,
		  "OCIAttrSet OCI_ATTR_PREFETCH_MEMORY");
        return 0;
      }
    }

    return 1;
}


sb4
dbd_phs_in(dvoid *octxp, OCIBind *bindp, ub4 iter, ub4 index,
	      dvoid **bufpp, ub4 *alenp, ub1 *piecep, dvoid **indpp)
{
	dTHX;
    phs_t *phs = (phs_t*)octxp;
    STRLEN phs_len;
    AV *tuples_av;
	SV *sv;
	AV *av;
	SV **sv_p;
	if( bindp ) { /* For GCC not to warn on unused parameter*/ }

 		/* Check for bind values supplied by tuple array. */
		tuples_av = phs->imp_sth->bind_tuples;
		if(tuples_av) {
		   	/* NOTE: we already checked the validity in ora_st_bind_for_array_exec(). */
		   	sv_p = av_fetch(tuples_av, phs->imp_sth->rowwise ? (int)iter : phs->idx, 0);
		   	av = (AV*)SvRV(*sv_p);
		   	sv_p = av_fetch(av, phs->imp_sth->rowwise ? phs->idx : (int)iter, 0);
			sv = *sv_p;
	   		if(SvOK(sv)) {
	     		*bufpp = SvPV(sv, phs_len);
	     		phs->alen = (phs->alen_incnull) ? phs_len+1 : phs_len;
	     		phs->indp = 0;
	   		} else {
	     		*bufpp = SvPVX(sv);
	     		phs->alen = 0;
	     		phs->indp = -1;
	   		}
    	}
    	else
    		if (phs->desc_h) {
				*bufpp  = phs->desc_h;
				phs->alen = 0;
				phs->indp = 0;
    	}
    	else
    		if (SvOK(phs->sv)) {
				*bufpp  = SvPV(phs->sv, phs_len);
		phs->alen = (phs->alen_incnull) ? phs_len+1 : phs_len;;
		phs->indp = 0;
   	}
    else {
		*bufpp  = SvPVX(phs->sv);	/* not actually used? */
		phs->alen = 0;
		phs->indp = -1;
    }
    *alenp  = phs->alen;
    *indpp  = &phs->indp;
    *piecep = OCI_ONE_PIECE;
    if (DBIS->debug >= 3 || dbd_verbose >=3)
 		PerlIO_printf(DBILOGFP, "       in  '%s' [%lu,%lu]: len %2lu, ind %d%s, value=%s\n",
			phs->name, ul_t(iter), ul_t(index), ul_t(phs->alen), phs->indp,
			(phs->desc_h) ? " via descriptor" : "",neatsvpv(phs->sv,10));
    if (!tuples_av && (index > 0 || iter > 0))
		croak(" Arrays and multiple iterations not currently supported by DBD::Oracle (in %d/%d)", index,iter);
    return OCI_CONTINUE;
}

/*
``Binding and Defining''

Binding RETURNING...INTO variables

As mentioned in the previous section, an OCI application implements the placeholders in the RETURNING clause as
pure OUT bind variables. An application must adhere to the following rules when working with these bind variables:

  1.Bind RETURNING clause placeholders in OCI_DATA_AT_EXEC mode using OCIBindByName() or
    OCIBindByPos(), followed by a call to OCIBindDynamic() for each placeholder.

    Note: The OCI only supports the callback mechanism for RETURNING clause binds. The polling mechanism is
    not supported.

  2.When binding RETURNING clause placeholders, you must supply a valid out bind function as the ocbfp
    parameter of the OCIBindDynamic() call. This function must provide storage to hold the returned data.
  3.The icbfp parameter of OCIBindDynamic() call should provide a "dummy" function which returns NULL values
    when called.
  4.The piecep parameter of OCIBindDynamic() must be set to OCI_ONE_PIECE.
  5.No duplicate binds are allowed in a DML statement with a RETURNING clause (i.e., no duplication between bind
    variables in the DML section and the RETURNING section of the statement).

When a callback function is called, the OCI_ATTR_ROWS_RETURNED attribute of the bind handle tells the
application the number of rows being returned in that particular iteration. Thus, when the callback is called the first
time in a particular iteration (i.e., index=0), the user can allocate space for all the rows which will be returned for that
bind variable. When the callback is called subsequently (with index>0) within the same iteration, the user can merely
increment the buffer pointer to the correct memory within the allocated space to retrieve the data.

Every bind handle has a OCI_ATTR_MAXDATA_SIZE attribute. This attribute specifies the number of bytes to be
allocated on the server to accommodate the client-side bind data after any necessary character set conversions.

    Note: Character set conversions performed when data is sent to the server may result in the data expanding or
    contracting, so its size on the client may not be the same as its size on the server.

An application will typically set OCI_ATTR_MAXDATA_SIZE to the maximum size of the column or the size of the
PL/SQL variable, depending on how it is used. Oracle issues an error if OCI_ATTR_MAXDATA_SIZE is not a large
enough value to accommodate the data after conversion, and the operation will fail.
*/

sb4
dbd_phs_out(dvoid *octxp, OCIBind *bindp,
	ub4 iter,	/* execution itteration (0...)	*/
	ub4 index,	/* array index (0..)		*/
	dvoid **bufpp,	/* A pointer to a buffer to write the bind value/piece.	*/
	ub4 **alenpp,	/* A pointer to a storage for OCI to fill in the size	*/
			/* of the bind value/piece after it has been read.	*/
	ub1 *piecep,	/* */
	dvoid **indpp,	/* Return a pointer to contain the indicator value which either an sb2	*/
			/* value or a pointer to an indicator structure for named data types.	*/
	ub2 **rcodepp)	/* Returns a pointer to contains the return code.	*/
{
	dTHX;
    phs_t *phs = (phs_t*)octxp;	/* context */
    /*imp_sth_t *imp_sth = phs->imp_sth;*/
	if( bindp ) { /* For GCC not to warn on unused parameter */ }

    if (phs->desc_h) { /* a  descriptor if present  (LOBs etc)*/
		*bufpp  = phs->desc_h;
		phs->alen = 0;

    } else {
		SV *sv = phs->sv;

		if (SvTYPE(sv) == SVt_RV && SvTYPE(SvRV(sv)) == SVt_PVAV) {
  	    	sv = *av_fetch((AV*)SvRV(sv), (IV)iter, 1);
		   if (!SvOK(sv))
				sv_setpv(sv,"");
		}

		*bufpp = SvGROW(sv, (size_t)(((phs->maxlen < 28) ? 28 : phs->maxlen)+1)/*for null*/);
		phs->alen = SvLEN(sv);	/* max buffer size now, actual data len later */

    }
    *alenpp = &phs->alen;
    *indpp  = &phs->indp;
    *rcodepp= &phs->arcode;
    if (DBIS->debug >= 3 || dbd_verbose >=3)
 		PerlIO_printf(DBILOGFP, "       out '%s' [%ld,%ld]: alen %2ld, piece %d%s\n",
			phs->name, ul_t(iter), ul_t(index), ul_t(phs->alen), *piecep,
			(phs->desc_h) ? " via descriptor" : "");
    *piecep = OCI_ONE_PIECE;
    return OCI_CONTINUE;
}



/* --------------------------------------------------------------
   Fetch callback fill buffers.
   Finaly figured out how this fucntion works
   Seems it is like this. The function inits and then fills the
   buffer (fb_ary->abuf) with the data from the select until it
   either runs out of data or its piece size is reached
   (fb_ary->bufl).  If its piece size is reached it then goes and gets
   the the next piece and sets *piecep ==OCI_NEXT_PIECE at this point
   I take the data in the buffer and memcpy it onto my buffer
   (fb_ary->cb_abuf). This will go on until it runs out of full pieces
   so when it returns to back to the fetch I add what remains in
   (fb_ary->bufl) (the last piece) and memcpy onto my  buffer (fb_ary->cb_abuf)
   to get it all.  I also take set fb_ary->cb_abuf back to empty just
   to keep things clean
 -------------------------------------------------------------- */
sb4 presist_lob_fetch_cbk(dvoid *octxp, OCIDefine *dfnhp, ub4 iter, dvoid **bufpp,
                      ub4 **alenpp, ub1 *piecep, dvoid **indpp, ub2 **rcpp)
{
  dTHX;
  imp_fbh_t *fbh =(imp_fbh_t*)octxp;
  fb_ary_t  *fb_ary;
  fb_ary =  fbh->fb_ary;

  *bufpp  = (dvoid *) fb_ary->abuf;
  *alenpp = &fb_ary->bufl;
  *indpp  = (dvoid *) fb_ary->aindp;
  *rcpp   =  fb_ary->arcode;


  if (dbd_verbose >= 5) {
	  		PerlIO_printf(DBILOGFP, " In presist_lob_fetch_cbk\n");
  }

  if ( *piecep ==OCI_NEXT_PIECE ){/*more than one piece*/

	memcpy(fb_ary->cb_abuf+fb_ary->piece_count*fb_ary->bufl,fb_ary->abuf,fb_ary->bufl );
	/*as we will be using both blobs and clobs we have to use
	  pointer arithmetic to get the values right.  in this case we simply
	  copy all of the memory of the buff into the cb buffer starting
	  at the piece count * the  buffer length
	  */

	fb_ary->piece_count++;/*used to tell me how many pieces I have, Might be able to use aindp for this?*/

  }


  return OCI_CONTINUE;

}

#ifdef UTF8_SUPPORT
/* How many bytes are n utf8 chars in buffer */
static ub4
ora_utf8_to_bytes (ub1 *buffer, ub4 chars_wanted, ub4 max_bytes)
{
	dTHX;
    ub4 i = 0;
    while (i < max_bytes && (chars_wanted-- > 0)) {
	i += UTF8SKIP(&buffer[i]);
    }
    return (i < max_bytes)? i : max_bytes;
}


#if 0 /* save this for later just in case... */
/* Given the 5.6.0 implementation of utf8 handling in perl,
 * avoid setting the UTF8 flag as much as possible. Almost
 * every binary operator in Perl will do conversions when
 * strings marked as UTF8 are involved.
 * Maybe setting the flag should be default in Japan or
 * Europe? Deduce that from NLS_LANG? Possibly...
 */

int
set_utf8(SV *sv) {
    ub1 *c;
    for (c = (ub1*)SvPVX(sv); c < (ub1*)SvEND(sv); c++) {
       if (*c & 0x80) {
           SvUTF8_on(sv);
           return 1;
       }
    }
    return 0;
}
#endif
#endif

/* PerlIO_printf(DBILOGFP, "lab datalen=%d long_readlen=%d bytelen=%d\n" ,datalen ,imp_sth->long_readlen, bytelen ); */
static int	/* LONG and LONG RAW */
fetch_func_varfield(SV *sth, imp_fbh_t *fbh, SV *dest_sv)
{
	dTHX;
    D_imp_sth(sth);
    D_imp_dbh_from_sth ;
    D_imp_drh_from_dbh ;
    fb_ary_t *fb_ary = fbh->fb_ary;
    char *p = (char*)&fb_ary->abuf[0];
    ub4 datalen = *(ub4*)p;     /* XXX alignment ? */
    p += 4;

#ifdef UTF8_SUPPORT
    if (fbh->ftype == 94) {
		if (datalen > imp_sth->long_readlen) {
		    ub4 bytelen = ora_utf8_to_bytes((ub1*)p, (ub4)imp_sth->long_readlen, datalen);

		    if (bytelen < datalen ) {	/* will be truncated */
				int oraperl = DBIc_COMPAT(imp_sth);
				if (DBIc_has(imp_sth,DBIcf_LongTruncOk) || (oraperl && SvIV(imp_drh->ora_trunc))) {
				    /* user says truncation is ok */
				    /* Oraperl recorded the truncation in ora_errno so we	*/
				    /* so also but only for Oraperl mode handles.		*/
				    if (oraperl) sv_setiv(DBIc_ERR(imp_sth), 1406);
				} else {
				    char buf[300];
				    sprintf(buf,"fetching field %d of %d. LONG value truncated from %lu to %lu. %s",
					    fbh->field_num+1, DBIc_NUM_FIELDS(imp_sth), ul_t(datalen), ul_t(bytelen),
					    "DBI attribute LongReadLen too small and/or LongTruncOk not set");
				    oci_error_err(sth, NULL, OCI_ERROR, buf, 24345); /* appropriate ORA error number */
				    sv_set_undef(dest_sv);
				    return 0;
				}

			if (DBIS->debug >= 3 || dbd_verbose >=3)
			    PerlIO_printf(DBILOGFP, "       fetching field %d of %d. LONG value truncated from %lu to %lu.\n",
				    fbh->field_num+1, DBIc_NUM_FIELDS(imp_sth),
				    ul_t(datalen), ul_t(bytelen));
					datalen = bytelen;
		    }
	}
	sv_setpvn(dest_sv, p, (STRLEN)datalen);
	if (CSFORM_IMPLIES_UTF8(fbh->csform))
	    SvUTF8_on(dest_sv);
    } else {
#else
    {
#endif
	sv_setpvn(dest_sv, p, (STRLEN)datalen);
    }

    return 1;
}

/*static int
fetch_func_nty(SV *sth, imp_fbh_t *fbh, SV *dest_sv)
{
    fb_ary_t *fb_ary = fbh->fb_ary;
    char *p = (char*)&fb_ary->abuf[0];
    ub4 datalen = *(ub4*)p;   */
  /* XXX alignment ? */
/*
    warn("fetch_func_nty unimplemented (datalen %d)", datalen);
    sv_set_undef(dest_sv);
    return 1;
}
*/

/* ------ */
static void
fetch_cleanup_rset(SV *sth, imp_fbh_t *fbh)
{
	dTHX;
    SV *sth_nested = (SV *)fbh->special;
    fbh->special = NULL;

	if( sth ) { /* For GCC not to warn on unused parameter */ }
    if (sth_nested) {
	dTHR;
	D_impdata(imp_sth_nested, imp_sth_t, sth_nested);
        int fields = DBIc_NUM_FIELDS(imp_sth_nested);
	int i;
	for(i=0; i < fields; ++i) {
	    imp_fbh_t *fbh_nested = &imp_sth_nested->fbh[i];
	    if (fbh_nested->fetch_cleanup)
		fbh_nested->fetch_cleanup(sth_nested, fbh_nested);
	}
	if (DBIS->debug >= 3 || dbd_verbose >=3)
	    PerlIO_printf(DBILOGFP,
		    "    fetch_cleanup_rset - deactivating handle %s (defunct nested cursor)\n",
                		neatsvpv(sth_nested, 0));

	DBIc_ACTIVE_off(imp_sth_nested);
	SvREFCNT_dec(sth_nested);
    }
}

static int
fetch_func_rset(SV *sth, imp_fbh_t *fbh, SV *dest_sv)
{
	dTHX;
    OCIStmt *stmhp_nested = ((OCIStmt **)fbh->fb_ary->abuf)[0];
	dTHR;
    D_imp_sth(sth);
    D_imp_dbh_from_sth;
    dSP;
    HV *init_attr = newHV();
    int count;

    if (DBIS->debug >= 3 || dbd_verbose >=3)
		PerlIO_printf(DBILOGFP,
		"    fetch_func_rset - allocating handle for cursor nested within %s ...\n",
                		neatsvpv(sth, 0));

    ENTER; SAVETMPS; PUSHMARK(SP);
    XPUSHs(sv_2mortal(newRV((SV*)DBIc_MY_H(imp_dbh))));
    XPUSHs(sv_2mortal(newRV((SV*)init_attr)));
    PUTBACK;
    count = perl_call_pv("DBI::_new_sth", G_ARRAY);
    SPAGAIN;
    if (count != 2)
        croak("panic: DBI::_new_sth returned %d values instead of 2", count);

    if(POPs){} /* For GCC not to warn on unused result */

    sv_setsv(dest_sv, POPs);
    SvREFCNT_dec(init_attr);
    PUTBACK; FREETMPS; LEAVE;

    if (DBIS->debug >= 3 || dbd_verbose >=3)
		PerlIO_printf(DBILOGFP,
		"    fetch_func_rset - ... allocated %s for nested cursor\n",
                		neatsvpv(dest_sv, 0));

    fbh->special = (void *)newSVsv(dest_sv);

    {
	D_impdata(imp_sth_nested, imp_sth_t, dest_sv);
	imp_sth_nested->envhp = imp_sth->envhp;
	imp_sth_nested->errhp = imp_sth->errhp;
	imp_sth_nested->srvhp = imp_sth->srvhp;
	imp_sth_nested->svchp = imp_sth->svchp;

	imp_sth_nested->stmhp = stmhp_nested;
	imp_sth_nested->nested_cursor = 1;
	imp_sth_nested->rs_array_on = 1;
	imp_sth_nested->stmt_type = OCI_STMT_SELECT;

	DBIc_IMPSET_on(imp_sth_nested);
	DBIc_ACTIVE_on(imp_sth_nested);  /* So describe won't do an execute */

	if (!dbd_describe(dest_sv, imp_sth_nested))
		return 0;
    }

    return 1;
}
/* ------ */


int
dbd_rebind_ph_rset(SV *sth, imp_sth_t *imp_sth, phs_t *phs)
{
  dTHX;

   if (DBIS->debug >= 6 || dbd_verbose >=6)
	 PerlIO_printf(DBILOGFP, "     dbd_rebind_ph_rset phs->is_inout=%d\n",phs->is_inout);

  /* Only do this part for inout cursor refs because pp_exec_rset only gets called for all the output params */
  if (phs->is_inout) {
    phs->out_prepost_exec = pp_exec_rset;
    return 2;	/* OCI bind done */
  }
  else {
    /* Call a special rebinder for cursor ref "in" params */
    return(pp_rebind_ph_rset_in(sth, imp_sth, phs));
  }
}


/* ------ */
static int
fetch_lob(SV *sth, imp_sth_t *imp_sth, OCILobLocator* lobloc, int ftype, SV *dest_sv, char *name);

static int
lob_phs_post_execute(SV *sth, imp_sth_t *imp_sth, phs_t *phs, int pre_exec)
{
	dTHX;
    if (pre_exec)
		return 1;
	/* fetch PL/SQL LOB data */
	if (imp_sth->auto_lob && (
	    imp_sth->stmt_type == OCI_STMT_BEGIN || imp_sth->stmt_type == OCI_STMT_DECLARE )) {

	    return fetch_lob(sth, imp_sth, (OCILobLocator*) phs->desc_h, phs->ftype, phs->sv, phs->name);
	}

    sv_setref_pv(phs->sv, "OCILobLocatorPtr", (void*)phs->desc_h);

    return 1;
}

int
dbd_rebind_ph_lob(SV *sth, imp_sth_t *imp_sth, phs_t *phs)
{
	dTHX;
	D_imp_dbh_from_sth ;
    sword status;
    ub4 lobEmpty = 0;

    if (!phs->desc_h) {
	++imp_sth->has_lobs;
	phs->desc_t = OCI_DTYPE_LOB;
	OCIDescriptorAlloc_ok(imp_sth->envhp,
			&phs->desc_h, phs->desc_t);
    }
    OCIAttrSet_log_stat(phs->desc_h, phs->desc_t,
		    &lobEmpty, 0, OCI_ATTR_LOBEMPTY, imp_sth->errhp, status);
    if (status != OCI_SUCCESS)
	return oci_error(sth, imp_sth->errhp, status, "OCIAttrSet OCI_ATTR_LOBEMPTY");

    if (!SvPOK(phs->sv)) {     /* normalizations for special cases     */
		if (SvOK(phs->sv)) {    /* ie a number, convert to string ASAP  */
           if (!(SvROK(phs->sv) && phs->is_inout))
               sv_2pv(phs->sv, &na);
		} else { /* ensure we're at least an SVt_PV (so SvPVX etc work)     */
    		if(SvUPGRADE(phs->sv, SVt_PV)){} /* For GCC not to warn on unused result */
        }
    }
    phs->indp   = (SvOK(phs->sv)) ? 0 : -1;
    phs->progv  = (char*)&phs->desc_h;
    phs->maxlen = sizeof(OCILobLocator*);
    if (phs->is_inout)
	phs->out_prepost_exec = lob_phs_post_execute;
    /* accept input LOBs */

if (sv_isobject(phs->sv) && sv_derived_from(phs->sv, "OCILobLocatorPtr")) {

       OCILobLocator *src;
       OCILobLocator **dest;
       src = INT2PTR(OCILobLocator *, SvIV(SvRV(phs->sv)));
       dest = (OCILobLocator **) phs->progv;

       OCILobLocatorAssign_log_stat(imp_dbh->svchp, imp_sth->errhp, src, dest, status);
       if (status != OCI_SUCCESS) {
           oci_error(sth, imp_sth->errhp, status, "OCILobLocatorAssign");
           return 0;
       }
    }

    /* create temporary LOB for PL/SQL placeholder */

    else if (imp_sth->stmt_type == OCI_STMT_BEGIN ||
          imp_sth->stmt_type == OCI_STMT_DECLARE) {
       ub4 amtp;

      if(SvUPGRADE(phs->sv, SVt_PV)){/* For GCC not to warn on unused result */};	/* just in case */
      amtp = SvCUR(phs->sv);		/* XXX UTF8? */

       /* Create a temp lob for non-empty string */

       if (amtp > 0) {
           ub1 lobtype = (phs->ftype == 112 ? OCI_TEMP_CLOB : OCI_TEMP_BLOB);
           OCILobCreateTemporary_log_stat(imp_dbh->svchp, imp_sth->errhp,
               (OCILobLocator *) phs->desc_h, (ub2) OCI_DEFAULT,
               (ub1) OCI_DEFAULT, lobtype, TRUE, OCI_DURATION_SESSION, status);

	   	   if (status != OCI_SUCCESS) {
               oci_error(sth, imp_sth->errhp, status, "OCILobCreateTemporary");
               return 0;
           }

           if( ! phs->csid ) {
               ub1 csform = SQLCS_IMPLICIT;
	       ub2 csid = 0;
               OCILobCharSetForm_log_stat( imp_sth->envhp, imp_sth->errhp, (OCILobLocator*)phs->desc_h, &csform, status );
               if (status != OCI_SUCCESS)
                   return oci_error(sth, imp_sth->errhp, status, "OCILobCharSetForm");
#ifdef OCI_ATTR_CHARSET_ID
	        /* Effectively only used so AL32UTF8 works properly */
               OCILobCharSetId_log_stat( imp_sth->envhp, imp_sth->errhp, (OCILobLocator*)phs->desc_h, &csid, status );
               if (status != OCI_SUCCESS)
                   return oci_error(sth, imp_sth->errhp, status, "OCILobCharSetId");
#endif /* OCI_ATTR_CHARSET_ID */
		/* if data is utf8 but charset isn't then switch to utf8 csid */
	        csid = (SvUTF8(phs->sv) && !CS_IS_UTF8(csid)) ? utf8_csid : CSFORM_IMPLIED_CSID(csform);
                phs->csid = csid;
                phs->csform = csform;
           }

           if (DBIS->debug >= 3 || dbd_verbose >=3)
                PerlIO_printf(DBILOGFP, "      calling OCILobWrite phs->csid=%d phs->csform=%d amtp=%d\n",
                    phs->csid, phs->csform, amtp );

           /* write lob data */

	   OCILobWrite_log_stat(imp_sth->svchp, imp_sth->errhp,
		    (OCILobLocator*)phs->desc_h, &amtp, 1, SvPVX(phs->sv), amtp, OCI_ONE_PIECE,
		    0,0, phs->csid, phs->csform, status);

           if (status != OCI_SUCCESS) {
               return oci_error(sth, imp_sth->errhp, status, "OCILobWrite in dbd_rebind_ph_lob");
           }
        }
    }

    return 1;
}


#ifdef UTF8_SUPPORT
ub4
ora_blob_read_mb_piece(SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh,
  SV *dest_sv, long offset, UV len, long destoffset)
{
	dTHX;
    ub4 loblen = 0;
    ub4 buflen;
    ub4 amtp = 0;
    ub4 byte_destoffset = 0;
    OCILobLocator *lobl = (OCILobLocator*)fbh->desc_h;
    sword ftype = fbh->ftype;
    sword status;

    /*
     * We assume our caller has already done the
     * equivalent of the following:
     *		(void)SvUPGRADE(dest_sv, SVt_PV);
     */
    ub1 csform = SQLCS_IMPLICIT;

    OCILobCharSetForm_log_stat( imp_sth->envhp, imp_sth->errhp, lobl, &csform, status );
    if (status != OCI_SUCCESS) {
        oci_error(sth, imp_sth->errhp, status, "OCILobCharSetForm");
	sv_set_undef(dest_sv);	/* signal error */
	return 0;
    }
    if (ftype != 112) {
	oci_error(sth, imp_sth->errhp, OCI_ERROR,
	"blob_read not currently supported for non-CLOB types with OCI 8 "
	"(but with OCI 8 you can set $dbh->{LongReadLen} to the length you need,"
	"so you don't need to call blob_read at all)");
	sv_set_undef(dest_sv);	/* signal error */
	return 0;
    }

    OCILobGetLength_log_stat(imp_sth->svchp, imp_sth->errhp,
			     lobl, &loblen, status);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCILobGetLength ora_blob_read_mb_piece");
	sv_set_undef(dest_sv);	/* signal error */
	return 0;
    }

    loblen -= offset;   /* only count from offset onwards */
    amtp = (loblen > len) ? len : loblen;
    buflen = 4 * amtp;

    byte_destoffset = ora_utf8_to_bytes((ub1 *)(SvPVX(dest_sv)),
				    (ub4)destoffset, SvCUR(dest_sv));

    if (loblen > 0) {
      ub1 *dest_bufp;
      ub1 *buffer;

      New(42, buffer, buflen, ub1);

      OCILobRead_log_stat(imp_sth->svchp, imp_sth->errhp, lobl,
			  &amtp, (ub4)1 + offset, buffer, buflen,
                          0, 0, (ub2)0 ,csform ,status );
			  /* lab  0, 0, (ub2)0, (ub1)SQLCS_IMPLICIT, status); */

      if (dbis->debug >= 3 || dbd_verbose >=3)
		PerlIO_printf(DBILOGFP, "       OCILobRead field %d %s: LOBlen %lu, LongReadLen %lu, BufLen %lu, Got %lu\n",
			fbh->field_num+1, oci_status_name(status), ul_t(loblen),
			ul_t(imp_sth->long_readlen), ul_t(buflen), ul_t(amtp));
      if (status != OCI_SUCCESS) {
		oci_error(sth, imp_sth->errhp, status, "OCILobRead");
		sv_set_undef(dest_sv);	/* signal error */
		return 0;
      }

      amtp = ora_utf8_to_bytes(buffer, len, amtp);
      SvGROW(dest_sv, byte_destoffset + amtp + 1);
      dest_bufp = (ub1 *)(SvPVX(dest_sv));
      dest_bufp += byte_destoffset;
      memcpy(dest_bufp, buffer, amtp);
      Safefree(buffer);
    }
    else {
      assert(amtp == 0);
      SvGROW(dest_sv, byte_destoffset + 1);
      if (dbis->debug >= 3 || dbd_verbose >=3)
	PerlIO_printf(DBILOGFP,
		"       OCILobRead field %d %s: LOBlen %lu, LongReadLen %lu, BufLen %lu, Got %lu\n",
		fbh->field_num+1, "SKIPPED", (unsigned long)loblen,
		(unsigned long)imp_sth->long_readlen, (unsigned long)buflen,
		(unsigned long)amtp);
    }

    if (dbis->debug >= 3 || dbd_verbose >=3)
      PerlIO_printf(DBILOGFP, "    blob_read field %d, ftype %d, offset %ld, len %ld, destoffset %ld, retlen %lu\n",
	      fbh->field_num+1, ftype, offset, len, destoffset, ul_t(amtp));

    SvCUR_set(dest_sv, byte_destoffset+amtp);
    *SvEND(dest_sv) = '\0'; /* consistent with perl sv_setpvn etc	*/
    SvPOK_on(dest_sv);
    if (ftype == 112 && CSFORM_IMPLIES_UTF8(csform))
	SvUTF8_on(dest_sv);

    return 1;
}
#endif /* ifdef UTF8_SUPPORT */

ub4
ora_blob_read_piece(SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv,
		    long offset, UV len, long destoffset)
{
	dTHX;
    ub4 loblen = 0;
    ub4 buflen;
    ub4 amtp = 0;
    ub1 csform = 0;
    OCILobLocator *lobl = (OCILobLocator*)fbh->desc_h;
    sword ftype = fbh->ftype;
    sword status;
    char *type_name;

    if (ftype == 112)
    	type_name = "CLOB";
    else if (ftype == 113)
    	type_name = "BLOB";
    else if (ftype == 114)
    	type_name = "BFILE";
    else {
	oci_error(sth, imp_sth->errhp, OCI_ERROR,
	"blob_read not currently supported for non-LOB types with OCI 8 "
	"(but with OCI 8 you can set $dbh->{LongReadLen} to the length you need,"
	"so you don't need to call blob_read at all)");
	sv_set_undef(dest_sv);	/* signal error */
	return 0;
    }

    OCILobGetLength_log_stat(imp_sth->svchp, imp_sth->errhp, lobl, &loblen, status);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCILobGetLength ora_blob_read_piece");
	sv_set_undef(dest_sv);	/* signal error */
	return 0;
    }

    OCILobCharSetForm_log_stat( imp_sth->envhp, imp_sth->errhp, lobl, &csform, status );
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCILobCharSetForm");
	sv_set_undef(dest_sv);	/* signal error */
	return 0;
    }
    if (ftype == 112 && csform == SQLCS_NCHAR)
        type_name = "NCLOB";

    /*
     * We assume our caller has already done the
     * equivalent of the following:
     *		(void)SvUPGRADE(dest_sv, SVt_PV);
     *		SvGROW(dest_sv, buflen+destoffset+1);
     */

    /*	amtp is:      LOB/BFILE  CLOB/NCLOB
	Input         bytes      characters
	Output FW     bytes      characters    (FW=Fixed Width charset, VW=Variable)
	Output VW     bytes      characters(in), bytes returned (afterwards)
    */
    amtp = (loblen > len) ? len : loblen;

    /* buflen: length of buffer in bytes */
    /* so for CLOBs that'll be returned as UTF8 we need more bytes that chars */
    /* XXX the x4 here isn't perfect - really the code should be changed to loop */
    if (ftype == 112 && CSFORM_IMPLIES_UTF8(csform)) {
	buflen = amtp * 4;
	/* XXX destoffset would be counting chars here as well */
	SvGROW(dest_sv, (destoffset*4) + buflen + 1);
	if (destoffset) {
	    oci_error(sth, imp_sth->errhp, OCI_ERROR,
	    "blob_read with non-zero destoffset not currently supported for UTF8 values");
	    sv_set_undef(dest_sv);	/* signal error */
	    return 0;
	}
    }
    else {
	buflen = amtp;
    }

    if (DBIS->debug >= 3 || dbd_verbose >=3)
	PerlIO_printf(DBILOGFP,
	    "        blob_read field %d: ftype %d %s, offset %ld, len %lu."
		    "LOB csform %d, len %lu, amtp %lu, (destoffset=%ld)\n",
	    fbh->field_num+1, ftype, type_name, offset, ul_t(len),
	    csform,(unsigned long) (loblen), ul_t(amtp), destoffset);

    if (loblen > 0) {
        ub1 * bufp = (ub1 *)(SvPVX(dest_sv));
	bufp += destoffset;

	OCILobRead_log_stat(imp_sth->svchp, imp_sth->errhp, lobl,
	    &amtp, (ub4)1 + offset, bufp, buflen,
		0, 0, (ub2)0 , csform, status);

	if (DBIS->debug >= 3 || dbd_verbose >= 3)
	    PerlIO_printf(DBILOGFP,
		"        OCILobRead field %d %s: LOBlen %lu, LongReadLen %lu, BufLen %lu, amtp %lu\n",
		fbh->field_num+1, oci_status_name(status), ul_t(loblen),
		ul_t(imp_sth->long_readlen), ul_t(buflen), ul_t(amtp));
	if (status != OCI_SUCCESS) {
	    oci_error(sth, imp_sth->errhp, status, "OCILobRead");
	    sv_set_undef(dest_sv);	/* signal error */
	    return 0;
	}
	if (ftype == 112 && CSFORM_IMPLIES_UTF8(csform))
	    SvUTF8_on(dest_sv);
    }
    else {
	assert(amtp == 0);
	if (DBIS->debug >= 3 || dbd_verbose >=3)
	    PerlIO_printf(DBILOGFP,
		"       OCILobRead field %d %s: LOBlen %lu, LongReadLen %lu, BufLen %lu, Got %lu\n",
		fbh->field_num+1, "SKIPPED", ul_t(loblen),
		ul_t(imp_sth->long_readlen), ul_t(buflen), ul_t(amtp));
    }

    /*
     * We assume our caller will perform
     * the equivalent of the following:
     *		SvCUR(dest_sv) = amtp;
     *		*SvEND(dest_sv) = '\0';
     *		SvPOK_on(dest_sv);
     */

    return(amtp);
}



static int
fetch_lob(SV *sth, imp_sth_t *imp_sth, OCILobLocator* lobloc, int ftype, SV *dest_sv, char *name)
{
	dTHX;
    ub4 loblen = 0;
    ub4 buflen;
    ub4 amtp = 0;
    int loblen_is_chars;
    sword status;

    if (!name)
        name = "an unknown field";

    /* this function is not called for NULL lobs */

    /* The length is expressed in terms of bytes for BLOBs and BFILEs,	*/
    /* and in terms of characters for CLOBs				*/
    OCILobGetLength_log_stat(imp_sth->svchp, imp_sth->errhp, lobloc, &loblen, status);
    if (status != OCI_SUCCESS) {
		oci_error(sth, imp_sth->errhp, status, "OCILobGetLength fetch_lob");
 		return 0;
    }
    loblen_is_chars = (ftype == 112);

    if (loblen > imp_sth->long_readlen) {	/* LOB will be truncated */
	int oraperl = DBIc_COMPAT(imp_sth);
	D_imp_dbh_from_sth ;
	D_imp_drh_from_dbh ;

	/* move setting amtp up to ensure error message OK */
	amtp = imp_sth->long_readlen;
	if (DBIc_has(imp_sth,DBIcf_LongTruncOk) || (oraperl && SvIV(imp_drh -> ora_trunc))) {
	    /* user says truncation is ok */
	    /* Oraperl recorded the truncation in ora_errno so we	*/
	    /* so also but only for Oraperl mode handles.		*/
	    if (oraperl) sv_setiv(DBIc_ERR(imp_sth), 1406);
	}
	else {
	    char buf[300];
	    sprintf(buf,"fetching %s. LOB value truncated from %ld to %ld. %s",
		    name, ul_t(loblen), ul_t(amtp),
		    "DBI attribute LongReadLen too small and/or LongTruncOk not set");
	    oci_error_err(sth, NULL, OCI_ERROR, buf, 24345); /* appropriate ORA error number */
	    sv_set_undef(dest_sv);
	    return 0;
        }
    }
    else
	amtp = loblen;

    (void)SvUPGRADE(dest_sv, SVt_PV);

    /* XXXX I've hacked on this and left it probably broken
	because I didn't have time to research which args to OCI funcs need
	to be in char or byte units. That still needs to be done.
	better variable names may help.
	(The old version (1.15) duplicated too much code here because
	I applied a contributed patch that wasn't ideal, I had too little time
	to sort it out.)
	Whatever is done here, similar changes are probably needed for the
	ora_lob_*() methods when handling CLOBs.
    */

    /* set char vs bytes and get right semantics for OCILobRead */
    if (loblen_is_chars) {
		buflen = amtp * 4;  /* XXX bit of a hack, efective but wasteful */
    }
    else buflen = amtp;

    SvGROW(dest_sv, buflen+1);

    if (loblen > 0) {
	ub1  csform = 0;
	OCILobCharSetForm_log_stat(imp_sth->envhp, imp_sth->errhp, lobloc, &csform, status );
        if (status != OCI_SUCCESS) {
            oci_error(sth, imp_sth->errhp, status, "OCILobCharSetForm");
            sv_set_undef(dest_sv);
            return 0;
        }

	if (ftype == 114) {
	    OCILobFileOpen_log_stat(imp_sth->svchp, imp_sth->errhp, lobloc,
				    (ub1)OCI_FILE_READONLY, status);
	    if (status != OCI_SUCCESS) {
		oci_error(sth, imp_sth->errhp, status, "OCILobFileOpen");
		sv_set_undef(dest_sv);
		return 0;
	    }
	}

	OCILobRead_log_stat(imp_sth->svchp, imp_sth->errhp, lobloc,
	    &amtp, (ub4)1, SvPVX(dest_sv), buflen,
	    0, 0, (ub2)0, csform, status);
	if (DBIS->debug >= 3 || dbd_verbose >=3)
	    PerlIO_printf(DBILOGFP,
		"        OCILobRead %s %s: csform %d, LOBlen %luc, LongReadLen %luc, BufLen %lub, Got %luc\n",
	    name, oci_status_name(status), csform, ul_t(loblen),
	    ul_t(imp_sth->long_readlen), ul_t(buflen), ul_t(amtp));

	if (ftype == 114) {
	    OCILobFileClose_log_stat(imp_sth->svchp, imp_sth->errhp,
		lobloc, status);
	}
	if (status != OCI_SUCCESS) {
	    oci_error(sth, imp_sth->errhp, status, "OCILobRead");
	    sv_set_undef(dest_sv);
	    return 0;
	}

	/* tell perl what we've put in its dest_sv */
	SvCUR(dest_sv) = amtp;
	*SvEND(dest_sv) = '\0';
	if (ftype == 112 && CSFORM_IMPLIES_UTF8(csform)) /* Don't set UTF8 on BLOBs */
 	  SvUTF8_on(dest_sv);
	ora_free_templob(sth, imp_sth, lobloc);
    }
    else {			/* LOB length is 0 */
	assert(amtp == 0);
	/* tell perl what we've put in its dest_sv */
	SvCUR(dest_sv) = amtp;
	*SvEND(dest_sv) = '\0';
	if (DBIS->debug >= 3 || dbd_verbose >=3)
	    PerlIO_printf(DBILOGFP,
		"        OCILobRead %s %s: LOBlen %lu, LongReadLen %lu, BufLen %lu, Got %lu\n",
	    name, "SKIPPED", ul_t(loblen),
 		ul_t(imp_sth->long_readlen), ul_t(buflen), ul_t(amtp));
    }

    SvPOK_on(dest_sv);

    return 1;
}

static int
fetch_func_autolob(SV *sth, imp_fbh_t *fbh, SV *dest_sv)
{
	dTHX;
    char name[64];
    sprintf(name, "field %d of %d", fbh->field_num, DBIc_NUM_FIELDS(fbh->imp_sth));
    return fetch_lob(sth, fbh->imp_sth, (OCILobLocator*)fbh->desc_h, fbh->ftype, dest_sv, name);
}


static int
fetch_func_getrefpv(SV *sth, imp_fbh_t *fbh, SV *dest_sv)
{
	dTHX;
    if( sth ) { /* For GCC not to warn on unused parameter */ }
    /* See the Oracle::OCI module for how to actually use this! */
    sv_setref_pv(dest_sv, fbh->bless, (void*)fbh->desc_h);
    return 1;
}

#ifdef OCI_DTYPE_REF
static void
fbh_setup_getrefpv(imp_fbh_t *fbh, int desc_t, char *bless)
{
	dTHX;
    if (DBIS->debug >= 2 || dbd_verbose >=2)
	PerlIO_printf(DBILOGFP,
	    "    col %d: otype %d, desctype %d, %s", fbh->field_num, fbh->dbtype, desc_t, bless);
    fbh->ftype  = fbh->dbtype;
    fbh->disize = fbh->dbsize;
    fbh->fetch_func = fetch_func_getrefpv;
    fbh->bless  = bless;
    fbh->desc_t = desc_t;
    OCIDescriptorAlloc_ok(fbh->imp_sth->envhp, &fbh->desc_h, fbh->desc_t);
}
#endif


static int
calc_cache_rows(int cache_rows, int num_fields, int est_width, int has_longs)
{
	dTHX;
    if (has_longs)			/* override/disable caching	*/
		cache_rows = 1;			/* else read_blob can't work	*/
    else
	    if (cache_rows == 0) {		/* automatically size the cache	*/

			/* Oracle packets on ethernet have max size of around 1460.	*/
			/* We'll aim to fill our row cache with around 10 per go.	*/
			/* Using 10 means any 'runt' packets will have less impact.	*/
			int txfr_size  = 10 * 1460;	/* desired transfer/cache size	*/

			/* Use guessed average on-the-wire row width calculated above &	*/
			/* add in overhead of 5 bytes per field plus 8 bytes per row.	*/
			/* The n*5+8 was determined by studying SQL*Net v2 packets.	*/
			/* It could probably benefit from a more detailed analysis.	*/
			est_width += num_fields*5 + 8;

			cache_rows = txfr_size / est_width;	      /* (maybe 1 or 0)	*/

			/* To ensure good performance with large rows (near or larger	*/
			/* than our target transfer size) we set a minimum cache size.	*/
			if (cache_rows < 6)	/* is cache a 'useful' size?	*/
			    cache_rows = (cache_rows > 0) ? 6 : 4;
		}

	if (cache_rows > 10000000)	/* keep within Oracle's limits  */
		cache_rows = 10000000;	/* seems it was ub2 at one time now ub4 this number is arbitary on my part*/

    return cache_rows;
}

/* called by get_object to return the actual value in the proerty */

static void get_attr_val(SV *sth,AV *list,imp_fbh_t *fbh, text  *name , OCITypeCode  typecode, dvoid   *attr_value )
{
  dTHX;
  text		str_buf[200];
  double   	dnum;
  size_t   	str_len;
  OCIRaw   	*raw = (OCIRaw *) 0;
  OCIString	*vs = (OCIString *) 0;
  ub1      	*temp = (ub1 *)0;
  ub4      	rawsize = 0;
  ub4      	i = 0;
  sword		status;
  SV		*raw_sv;

  /* get the data based on the type code*/
  if (DBIS->debug >= 5 || dbd_verbose >=5) {
	PerlIO_printf(DBILOGFP, " getting value of object attribute named  %s with typecode=%s\n",name,oci_typecode_name(typecode));
  }

  switch (typecode)
  {

	 case OCI_TYPECODE_INTERVAL_YM  :
	 case OCI_TYPECODE_INTERVAL_DS  :

		OCIIntervalToText_log_stat(fbh->imp_sth->envhp,
	 	 						fbh->imp_sth->errhp,
	 	 						attr_value,
	 	 						str_buf,
	 	 						200,
	 	 						&str_len,
	 						status);
	  	str_buf[str_len+1] = '\0';
	 	av_push(list, newSVpv( (char *) str_buf,0));
	 	break;

 	 case OCI_TYPECODE_TIMESTAMP_TZ :
     case OCI_TYPECODE_TIMESTAMP_LTZ :
     case OCI_TYPECODE_TIMESTAMP :


	     str_len = 200;
	     OCIDateTimeToText_log_stat(fbh->imp_sth->envhp,
		                           fbh->imp_sth->errhp,attr_value,&str_len,str_buf,status);



		if (typecode == OCI_TYPECODE_TIMESTAMP_TZ || typecode == OCI_TYPECODE_TIMESTAMP_LTZ){
			char s_tz_hour[3]="000";
			char s_tz_min[3]="000";
            sb1 tz_hour;
  		    sb1 tz_minute;
			status = OCIDateTimeGetTimeZoneOffset (fbh->imp_sth->envhp,
			                                     fbh->imp_sth->errhp,
			                                     *(OCIDateTime**)attr_value,
			                                     &tz_hour,
                                    &tz_minute );

            if (  (tz_hour<0) && (tz_hour>-10) ){
               sprintf(s_tz_hour," %03d",tz_hour);
            } else {
               sprintf(s_tz_hour," %02d",tz_hour);
            }

            sprintf(s_tz_min,":%02d", tz_minute);
            strcat((signed char*)str_buf, s_tz_hour);
            strcat((signed char*)str_buf, s_tz_min);
            str_buf[str_len+7] = '\0';

		} else {
		  str_buf[str_len+1] = '\0';
		}

		av_push(list, newSVpv( (char *) str_buf,0));
		break;

     case OCI_TYPECODE_DATE :                         /* fixed length string*/
         str_len = 200;
         OCIDateToText_log_stat(fbh->imp_sth->errhp, (CONST OCIDate *) attr_value,&str_len,str_buf,status);
         str_buf[str_len+1] = '\0';
         av_push(list, newSVpv( (char *) str_buf,0));
         break;


     case OCI_TYPECODE_CLOB:
     case OCI_TYPECODE_BLOB:
	 case OCI_TYPECODE_BFILE:
		raw_sv = newSV(0);
		fetch_lob(sth, fbh->imp_sth,*(OCILobLocator**)attr_value, typecode, raw_sv, (signed char*)name);


		av_push(list, raw_sv);
		break;

     case OCI_TYPECODE_RAW :/* RAW*/

 		raw_sv = newSV(0);
 		raw = *(OCIRaw **) attr_value;
      	temp = OCIRawPtr(fbh->imp_sth->envhp, raw);
      	rawsize = OCIRawSize (fbh->imp_sth->envhp, raw);
		for (i=0; i < rawsize; i++) {
			sv_catpvf(raw_sv,"0x%x ", temp[i]);
        }
        sv_catpv(raw_sv,"\n");

		av_push(list, raw_sv);

         break;
     case OCI_TYPECODE_CHAR :                         /* fixed length string */
     case OCI_TYPECODE_VARCHAR :                                 /* varchar  */
     case OCI_TYPECODE_VARCHAR2 :                                /* varchar2 */
         vs = *(OCIString **) attr_value;
          av_push(list, newSVpv((char *) OCIStringPtr(fbh->imp_sth->envhp, vs),0));
         break;
     case OCI_TYPECODE_SIGNED8 :                              /* BYTE - sb1  */
           av_push(list, newSVuv(*(sb1 *)attr_value));
         break;
     case OCI_TYPECODE_UNSIGNED8 :                   /* UNSIGNED BYTE - ub1  */
         av_push(list, newSViv(*(ub1 *)attr_value));
         break;
     case OCI_TYPECODE_OCTET :                                       /* OCT*/
          av_push(list, newSViv(*(ub1 *)attr_value));
         break;
     case OCI_TYPECODE_UNSIGNED16 :                       /* UNSIGNED SHORT  */
     case OCI_TYPECODE_UNSIGNED32 :                        /* UNSIGNED LONG  */
     case OCI_TYPECODE_REAL :                                     /* REAL    */
     case OCI_TYPECODE_DOUBLE :                                   /* DOUBLE  */
     case OCI_TYPECODE_INTEGER :                                     /* INT  */
     case OCI_TYPECODE_SIGNED16 :                                  /* SHORT  */
     case OCI_TYPECODE_SIGNED32 :                                   /* LONG  */
     case OCI_TYPECODE_DECIMAL :                                 /* DECIMAL  */
     case OCI_TYPECODE_FLOAT :                                   /* FLOAT    */
     case OCI_TYPECODE_NUMBER :                                  /* NUMBER   */
     case OCI_TYPECODE_SMALLINT :                                /* SMALLINT */
         (void) OCINumberToReal(fbh->imp_sth->errhp, (CONST OCINumber *) attr_value,
                                (uword) sizeof(dnum), (dvoid *) &dnum);

		 av_push(list, newSVnv(dnum));
         break;
     default:
         break;
    }
}

/*gets the properties of an object from a fetch by using the attributes saved in the describe */

int
get_object (SV *sth, AV *list, imp_fbh_t *fbh,fbh_obj_t *obj,OCIComplexObject *value){
  	dTHX;
   	sword 		status;
	dvoid    	*element ;
   	dvoid    	*attr_value;
  	boolean  	eoc;
  	ub2     	pos;
  	dvoid 		*attr_null_struct;
	OCIInd 		attr_null_status;
	OCIInd 		*element_null;
	OCIType 	*attr_tdo;
	OCIIter  	*itr;
  	fbh_obj_t	*fld;
  	OCIInd       *obj_ind;

	if (DBIS->debug >= 5 || dbd_verbose >=5) {
		PerlIO_printf(DBILOGFP, " getting attributes of object named  %s with typecode=%s\n",obj->type_name,oci_typecode_name(obj->typecode));
	}

	switch (obj->typecode) {

       case OCI_TYPECODE_OBJECT :                            /* embedded ADT */

           if (obj->obj_ind) {
		      obj_ind = obj->obj_ind;
		   } else {

		     status=OCIObjectGetInd(fbh->imp_sth->envhp,fbh->imp_sth->errhp,value,(dvoid**)&obj_ind);

		     if (status != OCI_SUCCESS) {
		       oci_error(sth, fbh->imp_sth->errhp, status, "OCIObjectGetInd");
		       return 0;
		     }
		   }

    	   for (pos = 0; pos < obj->field_count; pos++){
  	  			fld = &obj->fields[pos]; /*get the field */

/*				status=OCIObjectGetInd(fbh->imp_sth->envhp,fbh->imp_sth->errhp,value,(dvoid**)&obj->obj_ind);

the little bastard above took me ages to find out
seems Oracle does not like people to know that it can do this
the concept is simple really
 1. pin the object
 2. bind with dty = SQLT_NTY
 3. OCIDefineObject using the TDO
 4. one gets the null indicator of the objcet with OCIObjectGetInd
    The the obj_ind is for the entier object not the properties so you call it once it
    gets all of the indicators for the objects so you pass it into OCIObjectGetAttr and that
    function will set attr_null_status as in the get below.
 5. interate over the atributes of the object

The thing to remember is that OCI and C have no way of representing a DB NULLs so we use the OCIInd find out
if the object or any of its properties are NULL, This is one little line in a 20 chapter book and even then
id only shows you examples with the C struct built in and only a single record. Nowhere does it say you can do it this way.

				if (status != OCI_SUCCESS) {
					oci_error(sth, fbh->imp_sth->errhp, status, "OCIObjectGetInd");
					return 0;
	    		}*/

				status = OCIObjectGetAttr(fbh->imp_sth->envhp, fbh->imp_sth->errhp, value,
										obj_ind, obj->tdo,
										(CONST oratext**)&fld->type_name, &fld->type_namel, 1,
										(ub4 *)0, 0, &attr_null_status, &attr_null_struct,
										&attr_value, &attr_tdo);

				if (status != OCI_SUCCESS) {
					oci_error(sth, fbh->imp_sth->errhp, status, "OCIObjectGetAttr");
					return 0;
	    		}

	    		if (attr_null_status==OCI_IND_NULL){
				     av_push(list,  &sv_undef);
				} else {
					if (fld->typecode == OCI_TYPECODE_OBJECT || fld->typecode == OCI_TYPECODE_VARRAY || fld->typecode == OCI_TYPECODE_TABLE || fld->typecode == OCI_TYPECODE_NAMEDCOLLECTION){

               			fld->fields[0].value = newAV();
						if (fld->typecode != OCI_TYPECODE_OBJECT)
						   attr_value = *(dvoid **)attr_value;
						get_object (sth,fld->fields[0].value, fbh, &fld->fields[0],attr_value);
						av_push(list, newRV_noinc((SV *) fld->fields[0].value));

                	} else{  /* else, display the scaler type attribute */

                	    get_attr_val(sth,list, fbh, fld->type_name, fld->typecode, attr_value);

                	}
				}
             }
           break;

       case OCI_TYPECODE_REF :                               /* embedded ADT */
			croak("panic: OCI_TYPECODE_REF objets () are not supported ");
		   break;

       	case OCI_TYPECODE_NAMEDCOLLECTION : /*this works for both as I am using CONST OCIColl */

       		switch (obj->col_typecode) {

				case OCI_TYPECODE_TABLE :                       /* nested table */
				case OCI_TYPECODE_VARRAY :                    /* variable array */
               		fld = &obj->fields[0]; /*get the field */
              		OCIIterCreate_log_stat(fbh->imp_sth->envhp, fbh->imp_sth->errhp,
                         (OCIColl*) value, &itr,status);

					if (status != OCI_SUCCESS) {
						/*not really an error just no data
						oci_error(sth, fbh->imp_sth->errhp, status, "OCIIterCreate");*/
						status = OCI_SUCCESS;
			  		 	av_push(list,  &sv_undef);
						return 0;
	    			}

					for(eoc = FALSE;!OCIIterNext(fbh->imp_sth->envhp, fbh->imp_sth->errhp, itr,
                               (dvoid **) &element,
                               (dvoid **) &element_null, &eoc) && !eoc;)
              		{

						if (*element_null==OCI_IND_NULL){

						     av_push(list,  &sv_undef);
						} else {
							if (obj->element_typecode == OCI_TYPECODE_OBJECT || obj->element_typecode == OCI_TYPECODE_VARRAY || obj->element_typecode== OCI_TYPECODE_TABLE || obj->element_typecode== OCI_TYPECODE_NAMEDCOLLECTION){
								fld->value = newAV();
                 				get_object (sth,fld->value, fbh, fld,element);
								av_push(list, newRV_noinc((SV *) fld->value));
							} else{  /* else, display the scaler type attribute */
								get_attr_val(sth,list, fbh, obj->type_name, obj->element_typecode, element);
							}
                		}
               		}
               		/*nasty surprise here. one has to get rid of the iterator or you will leak memory
               		  not documented in oci or in demos */
               		OCIIterDelete_log_stat( fbh->imp_sth->envhp,
					                      fbh->imp_sth->errhp, &itr,status );

                    if (status != OCI_SUCCESS) {
						oci_error(sth, fbh->imp_sth->errhp, status, "OCIIterDelete");
						return 0;
	    			}
               		break;
             	default:
               		break;
           	}
           	break;
       default:
           if (value  ) {
               get_attr_val(sth,list, fbh, obj->type_name, obj->typecode, value);
           }
           else
              return 1;
           break;
    	}
    	return 1;
 }



/*cutsom fetch for embedded objects */

static int
fetch_func_oci_object(SV *sth, imp_fbh_t *fbh,SV *dest_sv)
{
    dTHX;
	if (DBIS->debug >= 4 || dbd_verbose >=4) {
		PerlIO_printf(DBILOGFP, " getting an embedded object named  %s with typecode=%s\n",fbh->obj->type_name,oci_typecode_name(fbh->obj->typecode));
	}

    if (fbh->obj->obj_ind && fbh->obj->obj_ind[0] == OCI_IND_NULL) {
      sv_set_undef(dest_sv);
      return 1;
    }

	fbh->obj->value=newAV();

	/*will return referance to an array of scalars*/
  	if (!get_object(sth,fbh->obj->value,fbh,fbh->obj,fbh->obj->obj_value)){
  		return 0;
	} else {
		sv_setsv(dest_sv, sv_2mortal(newRV_noinc((SV *) fbh->obj->value)));
		return 1;
	}

}



static int
fetch_clbk_lob(SV *sth, imp_fbh_t *fbh,SV *dest_sv){

	dTHX;
	D_imp_sth(sth);
	fb_ary_t *fb_ary = fbh->fb_ary;

    ub4 actual_bufl=imp_sth->piece_size*(fb_ary->piece_count)+fb_ary->bufl;

	if (fb_ary->piece_count==0){
		if (DBIS->debug >= 6 || dbd_verbose >= 6)
			PerlIO_printf(DBILOGFP,"  Fetch persistent lob of %d (char/bytes) with callback in 1 piece of %d (Char/Bytes)\n",actual_bufl,fb_ary->bufl);

		memcpy(fb_ary->cb_abuf,fb_ary->abuf,fb_ary->bufl );

	} else {
	   	if (DBIS->debug >= 6 || dbd_verbose >= 6)
			PerlIO_printf(DBILOGFP,"  Fetch persistent lob of %d (Char/Bytes) with callback in %d piece(s) of %d (Char/Bytes) and one piece of %d (Char/Bytes)\n",actual_bufl,fb_ary->piece_count,fbh->piece_size,fb_ary->bufl);

		memcpy(fb_ary->cb_abuf+imp_sth->piece_size*(fb_ary->piece_count),fb_ary->abuf,fb_ary->bufl );
	}

	if (fbh->ftype == SQLT_BIN){
	    *(fb_ary->cb_abuf+(actual_bufl))='\0'; /* add a null teminator*/
	    sv_setpvn(dest_sv, (char*)fb_ary->cb_abuf,(STRLEN)actual_bufl);
	} else {
		sv_setpvn(dest_sv, (char*)fb_ary->cb_abuf,(STRLEN)actual_bufl);
		if (CSFORM_IMPLIES_UTF8(fbh->csform) ){
			SvUTF8_on(dest_sv);
		}
	}
	return 1;
}
/* This is another way to get lobs as a alternate to callback */

static int
fetch_get_piece(SV *sth, imp_fbh_t *fbh,SV *dest_sv)
{
	dTHX;
	D_imp_sth(sth);
	fb_ary_t *fb_ary = fbh->fb_ary;
    ub4 buflen		 = fb_ary->bufl;
    ub4 actual_bufl	 = 0;
	ub1   piece  = OCI_FIRST_PIECE;
	void *hdlptr = (dvoid *) 0;
	ub4 hdltype  = OCI_HTYPE_DEFINE, iter = 0, idx = 0;
	ub1   in_out = 0;
	sb2   indptr = 0;
	ub2   rcode  = 0;
	sword status = OCI_NEED_DATA;



    if (DBIS->debug >= 4 || dbd_verbose >= 4) {
	  	PerlIO_printf(DBILOGFP, "in fetch_get_piece  \n");
	}

	while (status == OCI_NEED_DATA){

	   	OCIStmtGetPieceInfo_log_stat(fbh->imp_sth->stmhp,
						   			 fbh->imp_sth->errhp,
						   			 &hdlptr,
						   			 &hdltype,
						   			 &in_out,
						   			 &iter,
						   			 &idx,
						   			 &piece,
						   			 status);

		/* This is how this works
		First we get the piece Info above
		the bugger thing is that this will get the piece info in sequential order so on each call to the above
		you have to check to ensure you have the right define handle from the OCIDefineByPos
		I do it in the next if statement.  So this will loop untill the handle changes at that point it exits the loop
		during the loop I add the abuf to the  cb_abuf  using the buflen that is set above.
		I get the actual buffer length by adding up all the pieces (buflen) as I go along
		Another really anoying thing is once can only find out if there is data left over at the very end of the fetching of the colums
		so I make it warn if the LongTruncOk. I could also do this before but that would not result in any of the good data getting
		in
		*/
		if ( hdlptr==fbh->defnp){

			OCIStmtSetPieceInfo_log_stat(fbh->defnp,
										 fbh->imp_sth->errhp,
										 fb_ary->abuf,
										 &buflen,
										 piece,
										 (dvoid *)&indptr,
										 &rcode,status);


   			OCIStmtFetch_log_stat(fbh->imp_sth->stmhp,fbh->imp_sth->errhp,1,(ub2)OCI_FETCH_NEXT,OCI_DEFAULT,status);


            if (status==OCI_SUCCESS_WITH_INFO && !DBIc_has(fbh->imp_sth,DBIcf_LongTruncOk)){
             	dTHR; 			/* for DBIc_ACTIVE_off	*/
			    DBIc_ACTIVE_off(fbh->imp_sth);	/* eg finish		*/
			    oci_error(sth, fbh->imp_sth->errhp, status, "OCIStmtFetch, LongReadLen too small and/or LongTruncOk not set");
			}
 			memcpy(fb_ary->cb_abuf+fb_ary->piece_count*imp_sth->piece_size,fb_ary->abuf,buflen );
			fb_ary->piece_count++;/*used to tell me how many pieces I have, for debuffing in this case */
			actual_bufl=actual_bufl+buflen;

		}else {
		  status=OCI_LAST_PIECE;
		}
	}


    if (DBIS->debug >= 6 || dbd_verbose >= 6){
        if (fb_ary->piece_count==1){
			PerlIO_printf(DBILOGFP,"     Fetch persistent lob of %d (Char/Bytes) with Polling in 1 piece\n",actual_bufl);

        } else {
			PerlIO_printf(DBILOGFP,"     Fetch persistent lob of %d (Char/Bytes) with Polling in %d piece(s) of %d (Char/Bytes) and one piece of %d (Char/Bytes)\n",actual_bufl,fb_ary->piece_count,fbh->piece_size,buflen);
		}
    }
    sv_setpvn(dest_sv, (char*)fb_ary->cb_abuf,(STRLEN)actual_bufl);

  	if (fbh->ftype != SQLT_BIN){
		
		if (CSFORM_IMPLIES_UTF8(fbh->csform) ){ /* do the UTF 8 magic*/
			SvUTF8_on(dest_sv);
		}
	}

	return 1;
}


int
empty_oci_object(fbh_obj_t *obj){
	dTHX;
	int       pos  = 0;
	fbh_obj_t *fld=NULL;



	switch (obj->element_typecode) {

       	case OCI_TYPECODE_OBJECT :                            /* embedded ADT */

       		for (pos = 0; pos < obj->field_count; pos++){
				fld = &obj->fields[pos]; /*get the field */
				if (fld->typecode == OCI_TYPECODE_OBJECT || fld->typecode == OCI_TYPECODE_VARRAY || fld->typecode == OCI_TYPECODE_TABLE || fld->typecode == OCI_TYPECODE_NAMEDCOLLECTION){
					empty_oci_object(fld);
					if (fld->value && SvTYPE(fld->value) == SVt_PVAV){
						av_clear(fld->value);
			 			av_undef(fld->value);
                	}

				} else {
					return 1;
				}
           	}
           break;

       	case OCI_TYPECODE_NAMEDCOLLECTION :
			fld = &obj->fields[0]; /*get the field */
			if (obj->element_typecode == OCI_TYPECODE_OBJECT){
				empty_oci_object(fld);
			}
			if (fld->value && SvTYPE(fld->value)){
				if (SvTYPE(fld->value) == SVt_PVAV){
					av_clear(fld->value);
					av_undef(fld->value);
				}
			}
			break;
		default:
		 	break;
    }
    if ( fld && fld->value && (SvTYPE(fld->value) == SVt_PVAV) ){
   		av_clear(obj->value);
		av_undef(obj->value);
	}

    return 1;

}

static void
fetch_cleanup_pres_lobs(SV *sth,imp_fbh_t *fbh){
	dTHX;
   	fb_ary_t *fb_ary = fbh->fb_ary;

   	if( sth ) { /* For GCC not to warn on unused parameter*/  }
   	fb_ary->piece_count=0;/*reset the peice counter*/
   	memset( fb_ary->abuf, '\0', fb_ary->bufl); /*clean out the piece fetch buffer*/
   	fb_ary->bufl=fbh->piece_size; /*reset this back to the piece length */
   	fb_ary->cb_bufl=fbh->disize; /*reset this back to the max size for the fetch*/
 	memset( fb_ary->cb_abuf, '\0', fbh->disize ); /*clean out the call back buffer*/

 	if (DBIS->debug >= 5 || dbd_verbose >=5)
		PerlIO_printf(DBILOGFP,"  fetch_cleanup_pres_lobs \n");

	return;
}

static void
fetch_cleanup_oci_object(SV *sth, imp_fbh_t *fbh){
	dTHX;

	if( sth ) { /* For GCC not to warn on unused parameter*/  }

   	if (fbh->obj){
		if(fbh->obj->obj_value || fbh->obj->obj_ind){
	    	empty_oci_object(fbh->obj);
		}
	}

	if (DBIS->debug >= 3  || dbd_verbose >= 3)
		    PerlIO_printf(DBILOGFP,"  fetch_cleanup_oci_object \n");
	return;
}

void rs_array_init(imp_sth_t *imp_sth)
{
	dTHX;
	if (imp_sth->rs_array_on!=1 || imp_sth->rs_array_size<1 || imp_sth->rs_array_size>128){
		imp_sth->rs_array_on=0;
		imp_sth->rs_array_size=1;
	}
	imp_sth->rs_array_num_rows=0;
	imp_sth->rs_array_idx=0;
	imp_sth->rs_array_status=OCI_SUCCESS;
	if (DBIS->debug >= 3 || dbd_verbose >=3)
		PerlIO_printf(DBILOGFP, "    rs_array_init: rs_array_on=%d, rs_array_size=%d\n",imp_sth->rs_array_on,imp_sth->rs_array_size);
}


static int			/* --- Setup the row cache for this sth --- */
sth_set_row_cache(SV *h, imp_sth_t *imp_sth, int max_cache_rows, int num_fields, int has_longs)
{
	dTHX;
    D_imp_dbh_from_sth;
    D_imp_drh_from_dbh;
    int num_errors = 0;
    ub4 cache_mem=0;
    sb4 cache_rows=10000;/* set high so memory is the limit */
    sword status;

    /* reworked this is little so the user can set up his own cache
      basically if rowcachesize or prefetch_mem is set it uses those values
      otherwise it does it itself
      no sure what happens in the last case but I lwft it in for now
      Also I think in later version of OCI this call does not really do anything
    */

    /* number of rows to cache	 if using oraperl */
    if      (SvOK(imp_drh->ora_cache_o)) imp_sth->cache_rows = SvIV(imp_drh->ora_cache_o);
    else if (SvOK(imp_drh->ora_cache))   imp_sth->cache_rows = SvIV(imp_drh->ora_cache);


    if (imp_sth->is_child){ /*ref cursors and sp only one row is allowed*/

       cache_rows  =1;
	   cache_mem  =0;

   	} else if (imp_dbh->RowCacheSize || imp_sth->prefetch_memory){
	/*user set values */
   		 cache_rows  =imp_dbh->RowCacheSize;
	     cache_mem   =imp_sth->prefetch_memory;

   	} else if (imp_sth->cache_rows >= 0) {	/* set cache size by row count	*/

		/* imp_sth->est_width needs to be set */
		cache_mem  = 0;             /* so memory isn't the limit */

		cache_rows = calc_cache_rows(imp_sth->cache_rows,(int)num_fields, imp_sth->est_width, has_longs);

		if (max_cache_rows && cache_rows > (signed long) max_cache_rows)
		    cache_rows = max_cache_rows;

		imp_sth->cache_rows = cache_rows;	/* record updated value */

    }
    else {				/* set cache size by memory	*/
    					/* not sure if we ever reach this*/
		cache_mem  = -imp_sth->cache_rows; /* cache_mem always +ve here */
		if (max_cache_rows &&  cache_rows > (signed long) max_cache_rows) {
		    cache_rows = max_cache_rows;
		    imp_sth->cache_rows = cache_rows;	/* record updated value only if max_cache_rows */
		}

    }


    OCIAttrSet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT,
	   			    &cache_mem,  sizeof(cache_mem), OCI_ATTR_PREFETCH_MEMORY,
	   			    imp_sth->errhp, status);

	if (status != OCI_SUCCESS) {
		oci_error(h, imp_sth->errhp, status,
				"OCIAttrSet OCI_ATTR_PREFETCH_ROWS/OCI_ATTR_PREFETCH_MEMORY");
		++num_errors;
	}

	OCIAttrSet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT,
	   			&cache_rows, sizeof(cache_rows), OCI_ATTR_PREFETCH_ROWS,
   			imp_sth->errhp, status);

   	if (status != OCI_SUCCESS) {
		oci_error(h, imp_sth->errhp, status, "OCIAttrSet OCI_ATTR_PREFETCH_ROWS");
		++num_errors;
	}

	if (imp_sth->rs_array_on && cache_rows>0)
		imp_sth->rs_array_size=cache_rows>128?128:cache_rows;	/* restrict to 128 for now */

    if (DBIS->debug >= 3 || dbd_verbose >= 3)
		PerlIO_printf(DBILOGFP,
	    "    row cache OCI_ATTR_PREFETCH_ROWS %lu, OCI_ATTR_PREFETCH_MEMORY %lu\n",
	    (unsigned long) (cache_rows), (unsigned long) (cache_mem));

    return num_errors;
}



/*recurses down the field's TDOs and saves the little bits it need for later use on a fetch fbh->obj */

int
describe_obj(SV *sth,imp_sth_t *imp_sth,OCIParam *parm,fbh_obj_t *obj,int level )
{
	dTHX;
	sword status;

	if (DBIS->debug >= 5 || dbd_verbose >= 5) {
		PerlIO_printf(DBILOGFP, "At level=%d in description an embedded object \n",level);
	}
	/*Describe the field (OCIParm) we know it is a object or a collection */

	OCIAttrGet_parmdp(imp_sth,parm, &obj->type_name, &obj->type_namel, OCI_ATTR_TYPE_NAME, status);
   	/*get its name and hence TDO*/
	/*Now get the Actual TDO */

	if (status != OCI_SUCCESS) {
		oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
		return 0;
	}

	if (DBIS->debug >= 6 || dbd_verbose >= 6) {
		PerlIO_printf(DBILOGFP, "Geting the properties of object named =%s at level %d\n",obj->type_name,level);
	}
	OCITypeByName_log_stat(imp_sth->envhp,imp_sth->errhp,imp_sth->svchp,obj->type_name,obj->type_namel,&obj->tdo,status);
	if (status != OCI_SUCCESS) {
		oci_error(sth, imp_sth->errhp, status, "OCITypeByName");
		return 0;
	}
    OCIDescribeAny_log_stat(imp_sth->svchp,imp_sth->errhp,obj->tdo,(ub4)0,OCI_OTYPE_PTR,(ub1)1,OCI_PTYPE_TYPE,imp_sth->dschp,status);
	/*we have the Actual TDO  so lets see what it is made up of by a describe*/
	if (status != OCI_SUCCESS) {
		oci_error(sth,imp_sth->errhp, status, "OCIDescribeAny");
		return 0;
	}

    OCIAttrGet_parmap(imp_sth, imp_sth->dschp,OCI_HTYPE_DESCRIBE,  &obj->parmdp, 0, status);
	if (status != OCI_SUCCESS) {
		oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
		return 0;
	}

	/*and we store it in the object's paramdp for now*/

    OCIAttrGet_parmdp(imp_sth,  obj->parmdp, (dvoid *)&obj->typecode, 0, OCI_ATTR_TYPECODE, status);

	/*we need to know its type code*/

	if (status != OCI_SUCCESS) {
		oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
		return 0;
	}

    if (obj->typecode == OCI_TYPECODE_OBJECT){
		OCIParam *list_attr= (OCIParam *) 0;
		ub2      pos;

		if (DBIS->debug >= 6 || dbd_verbose >= 6) {
			PerlIO_printf(DBILOGFP, "Object named =%s at level %d is an Object\n",obj->type_name,level);
		}

		OCIAttrGet_parmdp(imp_sth, obj->parmdp, (dvoid *)&obj->obj_ref, 0, OCI_ATTR_REF_TDO, status);

		if (status != OCI_SUCCESS) {
			oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
			return 0;
		}
		/*we will need a reff to the TDO for the pin operation*/

		OCIObjectPin_log_stat(imp_sth->envhp,imp_sth->errhp, obj->obj_ref,(dvoid  **)&obj->obj_type,status);

		if (status != OCI_SUCCESS) {
			oci_error(sth,imp_sth->errhp, status, "OCIObjectPin");
			return 0;
		}

		OCIAttrGet_parmdp(imp_sth,  obj->parmdp, (dvoid *)&obj->field_count,(ub4 *) 0, OCI_ATTR_NUM_TYPE_ATTRS, status);

		if (status != OCI_SUCCESS) {
			oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
			return 0;
		}

		/*now get the differnt fields of this object add one field object for property*/
		Newz(1, obj->fields, (unsigned) obj->field_count, fbh_obj_t);

		/*a field is just another instance of an obj not a new struct*/

		OCIAttrGet_parmdp(imp_sth,  obj->parmdp, (dvoid *)&list_attr,(ub4 *) 0, OCI_ATTR_LIST_TYPE_ATTRS, status);

		if (status != OCI_SUCCESS) {
			oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
			return 0;
		}


		for (pos = 1; pos <= obj->field_count; pos++){
			OCIParam *parmdf= (OCIParam *) 0;
			fbh_obj_t *fld = &obj->fields[pos-1]; /*get the field holder*/

			OCIParamGet_log_stat((dvoid *) list_attr,(ub4) OCI_DTYPE_PARAM, imp_sth->errhp,(dvoid *)&parmdf, (ub4) pos ,status);

			if (status != OCI_SUCCESS) {
				oci_error(sth,imp_sth->errhp, status, "OCIParamGet");
				return 0;
			}

	        OCIAttrGet_parmdp(imp_sth,  (dvoid*)parmdf, (dvoid *)&fld->type_name,(ub4 *) &fld->type_namel, OCI_ATTR_NAME, status);

			/* get the name of the attribute */

			if (status != OCI_SUCCESS) {
				oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
				return 0;
			}

		   	OCIAttrGet_parmdp(imp_sth,  (dvoid*)parmdf, (void *)&fld->typecode,(ub4 *) 0, OCI_ATTR_TYPECODE, status);

			if (status != OCI_SUCCESS) {
				oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
				return 0;
			}

			if (DBIS->debug >= 6 || dbd_verbose >= 6) {
				PerlIO_printf(DBILOGFP, "Getting property #%d, named=%s and its typecode is %d \n",pos,fld->type_name,fld->typecode);
			}

			if (fld->typecode == OCI_TYPECODE_OBJECT || fld->typecode == OCI_TYPECODE_VARRAY || fld->typecode == OCI_TYPECODE_TABLE || fld->typecode == OCI_TYPECODE_NAMEDCOLLECTION){
				 /*this is some sort of object or collection so lets drill down some more*/
  				Newz(1, fld->fields, 1, fbh_obj_t);
  			    fld->field_count=1;/*not really needed but used internally*/
		   		status=describe_obj(sth,imp_sth,parmdf,fld->fields,level+1);
        	}
	    }
    } else {
		/*well this is an embedded table or varray of some form so find out what is in it*/

		if (DBIS->debug >= 6 || dbd_verbose >= 6) {
			PerlIO_printf(DBILOGFP, "Object named =%s at level %d is an Varray or Table\n",obj->type_name,level);
		}

    	OCIAttrGet_parmdp(imp_sth,  obj->parmdp, (dvoid *)&obj->col_typecode, 0, OCI_ATTR_COLLECTION_TYPECODE, status);

		if (status != OCI_SUCCESS) {
			oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
			return 0;
		}
		/* first get what sort of collection it is by coll typecode*/
   		OCIAttrGet_parmdp(imp_sth,  obj->parmdp, (dvoid *)&obj->parmap, 0, OCI_ATTR_COLLECTION_ELEMENT, status);

		if (status != OCI_SUCCESS) {
			oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
			return 0;
		}

    	OCIAttrGet_parmdp(imp_sth, obj->parmap, (dvoid *)&obj->element_typecode, 0, OCI_ATTR_TYPECODE, status);

		if (status != OCI_SUCCESS) {
			oci_error(sth,imp_sth->errhp, status, "OCIAttrGet");
			return 0;
		}

        if (obj->element_typecode == OCI_TYPECODE_OBJECT || obj->element_typecode == OCI_TYPECODE_VARRAY || obj->element_typecode == OCI_TYPECODE_TABLE || obj->element_typecode == OCI_TYPECODE_NAMEDCOLLECTION){
	    	 /*this is some sort of object or collection so lets drill down some more*/
            fbh_obj_t *fld;
            Newz(1, obj->fields, 1, fbh_obj_t);
            fld = &obj->fields[0]; /*get the field holder*/
            obj->field_count=1; /*not really needed but used internally*/
   		    status=describe_obj(sth,imp_sth,obj->parmap,fld,level+1);
	    }

   }
   return 1;

}


int
dump_struct(imp_sth_t *imp_sth,fbh_obj_t *obj,int level){
	dTHX;
	int i;
/*dumps the contents of the current fbh->obj*/

 	PerlIO_printf(DBILOGFP, " level=%d   type_name = %s\n",level,obj->type_name);
	PerlIO_printf(DBILOGFP, "    type_namel = %u\n",obj->type_namel);
	PerlIO_printf(DBILOGFP, "    parmdp = %p\n",obj->parmdp);
	PerlIO_printf(DBILOGFP, "    parmap = %p\n",obj->parmap);
	PerlIO_printf(DBILOGFP, "    tdo = %p\n",obj->tdo);
 	PerlIO_printf(DBILOGFP, "    typecode = %s\n",oci_typecode_name(obj->typecode));
 	PerlIO_printf(DBILOGFP, "    col_typecode = %d\n",obj->col_typecode);
 	PerlIO_printf(DBILOGFP, "    element_typecode = %s\n",oci_typecode_name(obj->element_typecode));
	PerlIO_printf(DBILOGFP, "    obj_ref = %p\n",obj->obj_ref);
	PerlIO_printf(DBILOGFP, "    obj_value = %p\n",obj->obj_value);
	PerlIO_printf(DBILOGFP, "    obj_type = %p\n",obj->obj_type);
 	PerlIO_printf(DBILOGFP, "    field_count = %d\n",obj->field_count);
	PerlIO_printf(DBILOGFP, "    fields = %p\n",obj->fields);

	for (i = 0; i < obj->field_count;i++){
		fbh_obj_t *fld = &obj->fields[i];
		PerlIO_printf(DBILOGFP, "  \n--->sub objects\n  ");
		dump_struct(imp_sth,fld,level+1);
    }

    PerlIO_printf(DBILOGFP, "  \n--->done %s\n  ",obj->type_name);

	return 1;
}





int
dbd_describe(SV *h, imp_sth_t *imp_sth)
{
	dTHX;
    D_imp_dbh_from_sth;
    D_imp_drh_from_dbh;
    UV	long_readlen;
    ub4 num_fields;
    int num_errors = 0;
    int has_longs = 0;
    int est_width = 0;		/* estimated avg row width (for cache)	*/
    int nested_cursors = 0;
    ub4 i = 0;
    sword status;


    if (imp_sth->done_desc)
	return 1;	/* success, already done it */
    imp_sth->done_desc = 1;

    /* ora_trunc is checked at fetch time */
    /* long_readlen:	length for long/longraw (if >0), else 80 (ora app dflt)	*/
    /* Ought to be for COMPAT mode only but was relaxed before LongReadLen existed */
    long_readlen = (SvOK(imp_drh -> ora_long) && SvUV(imp_drh->ora_long)>0)
				? SvUV(imp_drh->ora_long) : DBIc_LongReadLen(imp_sth);

    /* set long_readlen for SELECT or PL/SQL with output placeholders */
	imp_sth->long_readlen = long_readlen;

    if (imp_sth->stmt_type != OCI_STMT_SELECT) { /* XXX DISABLED, see num_fields test below */
		if (DBIS->debug >= 3 || dbd_verbose >= 3)
	   		PerlIO_printf(DBILOGFP, "    dbd_describe skipped for %s\n",
			oci_stmt_type_name(imp_sth->stmt_type));
	/* imp_sth memory was cleared when created so no setup required here	*/
		return 1;
    }

    if (DBIS->debug >= 3 || dbd_verbose >= 3)
	PerlIO_printf(DBILOGFP, "    dbd_describe %s (%s, lb %lu)...\n",
	    oci_stmt_type_name(imp_sth->stmt_type),
	    DBIc_ACTIVE(imp_sth) ? "implicit" : "EXPLICIT", (unsigned long)long_readlen);

    /* We know it's a select and we've not got the description yet, so if the	*/
    /* sth is not 'active' (executing) then we need an explicit describe.	*/
    if ( !DBIc_ACTIVE(imp_sth) ) {

	OCIStmtExecute_log_stat(imp_sth->svchp, imp_sth->stmhp, imp_sth->errhp,
		0, 0, 0, 0, OCI_DESCRIBE_ONLY, status);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status,
		ora_sql_error(imp_sth, "OCIStmtExecute/Describe"));
	    if (status != OCI_SUCCESS_WITH_INFO)
		return 0;
	}
    }

    OCIAttrGet_stmhp_stat(imp_sth, &num_fields, 0, OCI_ATTR_PARAM_COUNT, status);
    if (status != OCI_SUCCESS) {
	oci_error(h, imp_sth->errhp, status, "OCIAttrGet OCI_ATTR_PARAM_COUNT");
	return 0;
    }
    if (num_fields == 0) {
	if (DBIS->debug >= 3 || dbd_verbose >= 3)
	    PerlIO_printf(DBILOGFP, "    dbd_describe skipped for %s (no fields returned)\n",
		oci_stmt_type_name(imp_sth->stmt_type));
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    DBIc_NUM_FIELDS(imp_sth) = num_fields;
    Newz(42, imp_sth->fbh, num_fields, imp_fbh_t);

    /* Get number of fields and space needed for field names	*/
/* loop though the fields and get all the fileds and thier types to get back*/

    for(i = 1; i <= num_fields; ++i) { /*start define of filed struct[i] fbh */
		char *p;
		ub4 atrlen;
		int avg_width    = 0;
		imp_fbh_t *fbh   = &imp_sth->fbh[i-1];
		fbh->imp_sth     = imp_sth;
		fbh->field_num   = i;
		fbh->define_mode = OCI_DEFAULT;


		OCIParamGet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT, imp_sth->errhp,
				(dvoid**)&fbh->parmdp, (ub4)i, status);

		if (status != OCI_SUCCESS) {
		    oci_error(h, imp_sth->errhp, status, "OCIParamGet");
		    return 0;
		}

		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->dbtype, 0, OCI_ATTR_DATA_TYPE, status);
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->dbsize, 0, OCI_ATTR_DATA_SIZE, status);

#ifdef OCI_ATTR_CHAR_USED
        /* 0 means byte-length semantics, 1 means character-length semantics */
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->len_char_used, 0, OCI_ATTR_CHAR_USED, status);
        /* OCI_ATTR_CHAR_SIZE: like OCI_ATTR_DATA_SIZE but measured in chars	*/
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->len_char_size, 0, OCI_ATTR_CHAR_SIZE, status);
#endif
        fbh->csid = 0; fbh->csform = 0; /* just to be sure */
#ifdef OCI_ATTR_CHARSET_ID
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->csid,   0, OCI_ATTR_CHARSET_ID,   status);
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->csform, 0, OCI_ATTR_CHARSET_FORM, status);
#endif
	/* OCI_ATTR_PRECISION returns 0 for most types including some numbers		*/
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->prec,   0, OCI_ATTR_PRECISION, status);
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->scale,  0, OCI_ATTR_SCALE,     status);
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->nullok, 0, OCI_ATTR_IS_NULL,   status);
		OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->name,   &atrlen, OCI_ATTR_NAME,status);
		if (atrlen == 0) { /* long names can cause oracle to return 0 for atrlen */
		    char buf[99];
		    sprintf(buf,"field_%d_name_too_long", i);
		    fbh->name = &buf[0];
		    atrlen = strlen(fbh->name);
		}
		fbh->name_sv = newSVpv(fbh->name,atrlen);
		fbh->name    = SvPVX(fbh->name_sv);

		fbh->ftype   = 5;	/* default: return as null terminated string */


		if (DBIS->debug >= 4 || dbd_verbose >= 4)
	    	PerlIO_printf(DBILOGFP, "Describe col #%d type=%d(%s)\n",i,fbh->dbtype,sql_typecode_name(fbh->dbtype));


		switch (fbh->dbtype) {
		/*	the simple types	*/
 			case   1:				/* VARCHAR2	*/
				avg_width = fbh->dbsize / 2;
		/* FALLTHRU */
			case  96:				/* CHAR		*/
				if ( CSFORM_IMPLIES_UTF8(fbh->csform) && !CS_IS_UTF8(fbh->csid) )
				    fbh->disize = fbh->dbsize * 4;
				else
				    fbh->disize = fbh->dbsize;

				fbh->prec   = fbh->disize;
				break;
			case  23:				/* RAW		*/
				fbh->disize = fbh->dbsize * 2;
				fbh->prec   = fbh->disize;
				break;

			case   2:				/* NUMBER	*/
			case  21:				/* BINARY FLOAT os-endian	*/
			case  22:				/* BINARY DOUBLE os-endian	*/
			case 100:				/* BINARY FLOAT oracle-endian	*/
			case 101:				/* BINARY DOUBLE oracle-endian	*/
				fbh->disize = 130+38+3;		/* worst case	*/
				avg_width = 4;     /* NUMBER approx +/- 1_000_000 */
				break;

			case  12:				/* DATE		*/
				/* actually dependent on NLS default date format*/
				fbh->disize = 75;	/* a generous default	*/
				fbh->prec   = fbh->disize;
				avg_width = 8;	/* size in SQL*Net packet  */
				break;

			case   8:				/* LONG		*/

			   if (imp_sth->clbk_lob){ /*get by peice with callback a slow*/

					fbh->clbk_lob      = 1;
					fbh->define_mode   = OCI_DYNAMIC_FETCH; /* piecwise fetch*/
				    fbh->disize 	   = imp_sth->long_readlen; /*user set max value for the fetch*/
				    fbh->piece_size	   = imp_sth->piece_size; /*the size for each piece*/
					fbh->fetch_cleanup = fetch_cleanup_pres_lobs; /* clean up buffer before each fetch*/

				    if (!imp_sth->piece_size){ /*if not set use max value*/
						imp_sth->piece_size=imp_sth->long_readlen;
					}

			    	fbh->ftype = SQLT_CHR;
				    fbh->fetch_func = fetch_clbk_lob;

				} else if (imp_sth->piece_lob){ /*get by peice with polling slowest*/

					fbh->piece_lob      = 1;
					fbh->define_mode   = OCI_DYNAMIC_FETCH; /* piecwise fetch*/
					fbh->disize 	   = imp_sth->long_readlen; /*user set max value for the fetch*/
					fbh->piece_size	   = imp_sth->piece_size; /*the size for each piece*/
					fbh->fetch_cleanup = fetch_cleanup_pres_lobs; /* clean up buffer before each fetch*/

					if (!imp_sth->piece_size){ /*if not set use max value*/
						imp_sth->piece_size=imp_sth->long_readlen;
					}
					fbh->ftype = SQLT_CHR;
					fbh->fetch_func = fetch_get_piece;
				}else {

					if ( CSFORM_IMPLIES_UTF8(fbh->csform) && !CS_IS_UTF8(fbh->csid) )
			    	    fbh->disize = long_readlen * 4;
        	    	else
        	    	    fbh->disize = long_readlen;

        	        /* not governed by else: */
					fbh->dbsize = (fbh->disize>65535) ? 65535 : fbh->disize;
					fbh->ftype  = 94; /* VAR form */
					fbh->fetch_func = fetch_func_varfield;
					++has_longs;

				}
				break;
			case  24:				/* LONG RAW	*/
			 	if (imp_sth->clbk_lob){ /*get by peice with callback a slow*/

						fbh->clbk_lob      = 1;
						fbh->define_mode   = OCI_DYNAMIC_FETCH; /* piecwise fetch*/
					    fbh->disize 	   = imp_sth->long_readlen; /*user set max value for the fetch*/
					    fbh->piece_size	   = imp_sth->piece_size; /*the size for each piece*/
						fbh->fetch_cleanup = fetch_cleanup_pres_lobs; /* clean up buffer before each fetch*/

					    if (!imp_sth->piece_size){ /*if not set use max value*/
							imp_sth->piece_size=imp_sth->long_readlen;
						}

				    	fbh->ftype = SQLT_BIN;
					    fbh->fetch_func = fetch_clbk_lob;

				} else if (imp_sth->piece_lob){ /*get by peice with polling slowest*/

						fbh->piece_lob      = 1;
						fbh->define_mode   = OCI_DYNAMIC_FETCH; /* piecwise fetch*/
						fbh->disize 	   = imp_sth->long_readlen; /*user set max value for the fetch*/
						fbh->piece_size	   = imp_sth->piece_size; /*the size for each piece*/
						fbh->fetch_cleanup = fetch_cleanup_pres_lobs; /* clean up buffer before each fetch*/

						if (!imp_sth->piece_size){ /*if not set use max value*/
							imp_sth->piece_size=imp_sth->long_readlen;
						}
						fbh->ftype = SQLT_BIN;
						fbh->fetch_func = fetch_get_piece;
				}else {
					fbh->disize = long_readlen * 2;
					fbh->dbsize = (fbh->disize>65535) ? 65535 : fbh->disize;
					fbh->ftype  = 95; /* VAR form */
					fbh->fetch_func = fetch_func_varfield;
					++has_longs;
				}
				break;

			case  11:				/* ROWID	*/
			case 104:				/* ROWID Desc	*/
				fbh->disize = 20;
				fbh->prec   = fbh->disize;
				break;
	  		case 108:  			     /* some sort of embedded object */

  	    	    fbh->ftype  = fbh->dbtype;  /*varray or alike */
  	    	    fbh->fetch_func = fetch_func_oci_object; /* need a new fetch function for it */
  	    	    fbh->fetch_cleanup = fetch_cleanup_oci_object; /* clean up any AV  from the fetch*/
  	    	    fbh->desc_t = SQLT_NTY;
        	    if (!imp_sth->dschp){
   	    	     	OCIHandleAlloc_ok(imp_sth->envhp, &imp_sth->dschp, OCI_HTYPE_DESCRIBE, status);
   	    	     	if (status != OCI_SUCCESS) {
						oci_error(h,imp_sth->errhp, status, "OCIHandleAlloc");
						++num_errors;
					}

	    	    }
        	    break;

			case 112:				/* CLOB	& NCLOB	*/
			case 113:				/* BLOB		*/
			case 114:				/* BFILE	*/
				fbh->ftype  = fbh->dbtype;


                /* do we need some addition size logic here? (lab) */

                if (imp_sth->pers_lob){  /*get as one peice fasted but limited to how big you can get.*/
					fbh->pers_lob      = 1;
					fbh->disize 	   = fbh->disize+long_readlen; /*user set max value for the fetch*/
	    			if (fbh->dbtype == 112){
				  		fbh->ftype = SQLT_CHR;
				  	} else {
				  		fbh->ftype = SQLT_LVB; /*Binary form seems this is the only value where we cna get the length correctly*/
				  	}
			   } else if (imp_sth->clbk_lob){ /*get by peice with callback a slow*/

					fbh->clbk_lob      = 1;
    				fbh->define_mode   = OCI_DYNAMIC_FETCH; /* piecwise fetch*/
	    		    fbh->disize 	   = imp_sth->long_readlen; /*user set max value for the fetch*/
	    		    fbh->piece_size	   = imp_sth->piece_size; /*the size for each piece*/
 					fbh->fetch_cleanup = fetch_cleanup_pres_lobs; /* clean up buffer before each fetch*/

	    		    if (!imp_sth->piece_size){ /*if not set use max value*/
						imp_sth->piece_size=imp_sth->long_readlen;
					}

	    		    if (fbh->dbtype == 112){
	    		    	fbh->ftype = SQLT_CHR;
	    		    } else {
	    				fbh->ftype = SQLT_BIN; /*other Binary*/

	    			}
	    			fbh->fetch_func = fetch_clbk_lob;

				} else if (imp_sth->piece_lob){ /*get by peice with polling slowest*/

					fbh->piece_lob      = 1;
					fbh->define_mode   = OCI_DYNAMIC_FETCH; /* piecwise fetch*/
					fbh->disize 	   = imp_sth->long_readlen; /*user set max value for the fetch*/
					fbh->piece_size	   = imp_sth->piece_size; /*the size for each piece*/
					fbh->fetch_cleanup = fetch_cleanup_pres_lobs; /* clean up buffer before each fetch*/

					if (!imp_sth->piece_size){ /*if not set use max value*/
						imp_sth->piece_size=imp_sth->long_readlen;
					}
					if (fbh->dbtype == 112){
						fbh->ftype = SQLT_CHR;
					} else {
						fbh->ftype = SQLT_BIN; /*other Binary */
					}
					fbh->fetch_func = fetch_get_piece;
				} else { /*auto lob fetch with locator by far the fastest*/

					fbh->disize = fbh->dbsize *10 ;	/* XXX! */
					fbh->fetch_func = (imp_sth->auto_lob) ? fetch_func_autolob : fetch_func_getrefpv;
					fbh->bless  = "OCILobLocatorPtr";
					fbh->desc_t = OCI_DTYPE_LOB;
					OCIDescriptorAlloc_ok(imp_sth->envhp, &fbh->desc_h, fbh->desc_t);
				}

				break;

#ifdef OCI_DTYPE_REF
			case 111:				/* REF		*/
				fbh_setup_getrefpv(fbh, OCI_DTYPE_REF, "OCIRefPtr");
				break;
#endif

			case 116:				/* RSET		*/
				fbh->ftype  = fbh->dbtype;
				fbh->disize = sizeof(OCIStmt *);
				fbh->fetch_func = fetch_func_rset;
				fbh->fetch_cleanup = fetch_cleanup_rset;
				nested_cursors++;
				break;

			case 182:                  /* INTERVAL YEAR TO MONTH */
			case 183:                  /* INTERVAL DAY TO SECOND */
			case 190:                  /* INTERVAL DAY TO SECOND */
			case 187:                  /* TIMESTAMP */
			case 188: 	           /* TIMESTAMP WITH TIME ZONE	*/
			case 232:                  /* TIMESTAMP WITH LOCAL TIME ZONE */
				/* actually dependent on NLS default date format*/
				fbh->disize = 75;       /* XXX */
				break;

			default:
			/* XXX unhandled type may lead to errors or worse */
				fbh->ftype  = fbh->dbtype;
				fbh->disize = fbh->dbsize;
				p = "Field %d has an Oracle type (%d) which is not explicitly supported%s";
				if (DBIS->debug >= 1 || dbd_verbose >= 1)
				    PerlIO_printf(DBILOGFP, p, i, fbh->dbtype, "\n");
				if (dowarn)
				    warn(p, i, fbh->dbtype, "");
				break;
		}

		if (DBIS->debug >= 3 || dbd_verbose >= 3)
        	  PerlIO_printf(DBILOGFP,
	    	    "Described col %2d: dbtype %d(%s), scale %d, prec %d, nullok %d, name %s\n"
	    	     "          : dbsize %d, char_used %d, char_size %d, csid %d, csform %d, disize %d\n",
					i, fbh->dbtype, sql_typecode_name(fbh->dbtype),fbh->scale, fbh->prec, fbh->nullok, fbh->name,
					fbh->dbsize, fbh->len_char_used, fbh->len_char_size, fbh->csid, fbh->csform, fbh->disize);

		if (fbh->ftype == 5)	/* XXX need to handle wide chars somehow */
			fbh->disize += 1;	/* allow for null terminator */

	/* dbsize can be zero for 'select NULL ...'			*/

		imp_sth->t_dbsize += fbh->dbsize;

		if (!avg_width)
		    avg_width = fbh->dbsize;

		est_width += avg_width;

		if (DBIS->debug >= 2 || dbd_verbose >= 2)
		    dbd_fbh_dump(fbh, (int)i, 0);

    }/* end define of filed struct[i] fbh*/

    imp_sth->est_width = est_width;

    sth_set_row_cache(h, imp_sth,
			(nested_cursors) ? imp_dbh->max_nested_cursors / nested_cursors : 0,
			(int)num_fields, has_longs );
    /* Initialise cache counters */
	imp_sth->in_cache  = 0;
	imp_sth->eod_errno = 0;
	rs_array_init(imp_sth);

	/* now set up the oci call with define by pos*/
	for(i=1; i <= num_fields; ++i) {
		imp_fbh_t *fbh = &imp_sth->fbh[i-1];
		int ftype = fbh->ftype;
		/* add space for STRING null term, or VAR len prefix */
		sb4 define_len = (ftype==94||ftype==95) ? fbh->disize+4 : fbh->disize;
		fb_ary_t  *fb_ary;

		if (fbh->clbk_lob || fbh->piece_lob  ){/*init the cb_abuf with this call*/
			fbh->fb_ary = fb_ary_cb_alloc(imp_sth->piece_size,define_len, imp_sth->rs_array_size);

		} else {
		   	fbh->fb_ary = fb_ary_alloc(define_len, imp_sth->rs_array_size);
   		}

		fb_ary = fbh->fb_ary;

		if (fbh->ftype == SQLT_BIN)  {
			define_len++;
			/*add one extra byte incase the size of the lob is equal to the define_len*/
		}

		if (fbh->ftype == 116) { /* RSET */
		    OCIHandleAlloc_ok(imp_sth->envhp,
			(dvoid*)&((OCIStmt **)fb_ary->abuf)[0],
			 OCI_HTYPE_STMT, status);
		}

	    OCIDefineByPos_log_stat(imp_sth->stmhp,
	        &fbh->defnp,
		    imp_sth->errhp,
		    (ub4) i,
		    (fbh->desc_h) ? (dvoid*)&fbh->desc_h : fbh->clbk_lob  ? (dvoid *) 0: fbh->piece_lob  ? (dvoid *) 0:(dvoid*)fb_ary->abuf,
		    (fbh->desc_h) ?                   0 :        define_len,
		    (ub2)fbh->ftype,
		    fb_ary->aindp,
		    (ftype==94||ftype==95) ? NULL : fb_ary->arlen,
		    fb_ary->arcode,
		    fbh->define_mode,
			    status);


		if (fbh->clbk_lob){
			 /* use a dynamic callback for persistent binary and char lobs*/
		    OCIDefineDynamic_log_stat(fbh->defnp,imp_sth->errhp,(dvoid *) fbh,status);
		}

		if (fbh->ftype == 108)  { /* Embedded object bind it differently*/

				if (DBIS->debug >= 5 || dbd_verbose >= 5){
	    	   		PerlIO_printf(DBILOGFP,"Field #%d is a  object or colection of some sort. Using OCIDefineObject and or OCIObjectPin \n",i);
	    		}

			    Newz(1, fbh->obj, 1, fbh_obj_t);

			    fbh->obj->typecode=fbh->dbtype;

			    if (!describe_obj(h,imp_sth,fbh->parmdp,fbh->obj,0)){
					++num_errors;
				}

				if (DBIS->debug >= 5 || dbd_verbose >= 5){
					dump_struct(imp_sth,fbh->obj,0);
				}

				OCIDefineObject_log_stat(fbh->defnp,imp_sth->errhp,fbh->obj->tdo,(dvoid**)&fbh->obj->obj_value,(dvoid**)&fbh->obj->obj_ind,status);

				if (status != OCI_SUCCESS) {
					oci_error(h,imp_sth->errhp, status, "OCIDefineObject");
					++num_errors;
				}

			}

			if (status != OCI_SUCCESS) {
		    	oci_error(h, imp_sth->errhp, status, "OCIDefineByPos");
		    	++num_errors;
			}


#ifdef OCI_ATTR_CHARSET_FORM
        	if ( (fbh->dbtype == 1) && fbh->csform ) {
	    	/* csform may be 0 when talking to Oracle 8.0 database*/
	            if (DBIS->debug >= 3 || dbd_verbose >= 3)
	               PerlIO_printf(DBILOGFP, "    calling OCIAttrSet OCI_ATTR_CHARSET_FORM with csform=%d\n", fbh->csform );
		            OCIAttrSet_log_stat( fbh->defnp, (ub4) OCI_HTYPE_DEFINE, (dvoid *) &fbh->csform,
	                                 (ub4) 0, (ub4) OCI_ATTR_CHARSET_FORM, imp_sth->errhp, status );
	            if (status != OCI_SUCCESS) {
	                oci_error(h, imp_sth->errhp, status, "OCIAttrSet OCI_ATTR_CHARSET_FORM");
	                ++num_errors;
	            }
	        }
#endif /* OCI_ATTR_CHARSET_FORM */

    }

    if (DBIS->debug >= 3 || dbd_verbose >= 3)
		PerlIO_printf(DBILOGFP,
			"    dbd_describe'd %d columns (row bytes: %d max, %d est avg, cache: %d)\n",
			(int)num_fields, imp_sth->t_dbsize, imp_sth->est_width, imp_sth->cache_rows);

    return (num_errors>0) ? 0 : 1;
}


AV *
dbd_st_fetch(SV *sth, imp_sth_t *imp_sth){
	dTHX;
    sword status;
    int num_fields = DBIc_NUM_FIELDS(imp_sth);
    int ChopBlanks;
    int err;
    int i;
    AV *av;


    /* Check that execute() was executed sucessfully. This also implies	*/
    /* that dbd_describe() executed sucessfuly so the memory buffers	*/
    /* are allocated and bound.						*/
    if ( !DBIc_ACTIVE(imp_sth) ) {
		oci_error(sth, NULL, OCI_ERROR, imp_sth->nested_cursor ?
	    "nested cursor is defunct (parent row is no longer current)" :
	    "no statement executing (perhaps you need to call execute first)");
		return Nullav;
    }

    for(i=0; i < num_fields; ++i) {
		imp_fbh_t *fbh = &imp_sth->fbh[i];
		if (fbh->fetch_cleanup) fbh->fetch_cleanup(sth, fbh);
	}

    if (ora_fetchtest && DBIc_ROW_COUNT(imp_sth)>0) {

		--ora_fetchtest; /* trick for testing performance */
		status = OCI_SUCCESS;

    } else {
    	if (DBIS->debug >= 3 || dbd_verbose >= 3){
	    	PerlIO_printf(DBILOGFP, "    dbd_st_fetch %d fields...\n", DBIc_NUM_FIELDS(imp_sth));
	    }

        if (imp_sth->fetch_orient != OCI_DEFAULT) {

			if (imp_sth->exe_mode!=OCI_STMT_SCROLLABLE_READONLY)
				croak ("attempt to use a scrollable cursor without first setting ora_exe_mode to OCI_STMT_SCROLLABLE_READONLY\n") ;

			if (DBIS->debug >= 4 || dbd_verbose >= 4)
				PerlIO_printf(DBILOGFP,"    Scrolling Fetch, postion before fetch=%d, Orientation = %s , Fetchoffset =%d\n",
					imp_sth->fetch_position,oci_fetch_options(imp_sth->fetch_orient),imp_sth->fetch_offset);

				OCIStmtFetch_log_stat(imp_sth->stmhp, imp_sth->errhp,1, imp_sth->fetch_orient,imp_sth->fetch_offset, status);

				/*this will work without a round trip so might as well open it up for all statments handles*/
				/* defualt and OCI_FETCH_NEXT are the same so this avoids miscaluation on the next value*/
				OCIAttrGet_stmhp_stat(imp_sth, &imp_sth->fetch_position, 0, OCI_ATTR_CURRENT_POSITION, status);

			if (DBIS->debug >= 4 || dbd_verbose >= 4)
				PerlIO_printf(DBILOGFP,"    Scrolling Fetch, postion after fetch=%d\n",imp_sth->fetch_position);

		} else {


			if (imp_sth->rs_array_on) {	/* if array fetch on, fetch only if not in cache */
				imp_sth->rs_array_idx++;
				if (imp_sth->rs_array_num_rows<=imp_sth->rs_array_idx && imp_sth->rs_array_status==OCI_SUCCESS) {
		      		OCIStmtFetch_log_stat(imp_sth->stmhp,imp_sth->errhp,imp_sth->rs_array_size,(ub2)OCI_FETCH_NEXT,OCI_DEFAULT,status);
					imp_sth->rs_array_status=status;
					OCIAttrGet_stmhp_stat(imp_sth, &imp_sth->rs_array_num_rows,0,OCI_ATTR_ROWS_FETCHED, status);
					imp_sth->rs_array_idx=0;
				}
				if (imp_sth->rs_array_num_rows>imp_sth->rs_array_idx)	/* set status to success if rows in cache */
					status=OCI_SUCCESS;
				else
					status=imp_sth->rs_array_status;
			} else {

				OCIStmtFetch_log_stat(imp_sth->stmhp, imp_sth->errhp,1,(ub2)OCI_FETCH_NEXT, OCI_DEFAULT, status);
				imp_sth->rs_array_idx=0;
			}
		}
	}

    if (status != OCI_SUCCESS && status !=OCI_NEED_DATA) {
		ora_fetchtest = 0;

		if (status == OCI_NO_DATA) {
		    dTHR; 			/* for DBIc_ACTIVE_off	*/
		    DBIc_ACTIVE_off(imp_sth);	/* eg finish		*/
		    if (DBIS->debug >= 3 || dbd_verbose >= 3)
			PerlIO_printf(DBILOGFP, "    dbd_st_fetch no-more-data\n");
		    return Nullav;
		}
		if (status != OCI_SUCCESS_WITH_INFO) {
		    dTHR; 			/* for DBIc_ACTIVE_off	*/
		    DBIc_ACTIVE_off(imp_sth);	/* eg finish		*/
		    oci_error(sth, imp_sth->errhp, status, "OCIStmtFetch");
		    return Nullav;
		}
	/* for OCI_SUCCESS_WITH_INFO we fall through and let the	*/
	/* per-field rcode value be dealt with as we fetch the data	*/
    }

    av = DBIS->get_fbav(imp_sth);

    if (DBIS->debug >= 3  || dbd_verbose >= 3) {
		PerlIO_printf(DBILOGFP, "    dbd_st_fetched %d fields with status of %d(%s)\n",	num_fields,status, oci_status_name(status));
    }

    ChopBlanks = DBIc_has(imp_sth, DBIcf_ChopBlanks);

    err = 0;


	for(i=0; i < num_fields; ++i) {
		imp_fbh_t *fbh = &imp_sth->fbh[i];
		fb_ary_t *fb_ary = fbh->fb_ary;
		int rc = fb_ary->arcode[imp_sth->rs_array_idx];
		ub1* row_data=&fb_ary->abuf[0]+(fb_ary->bufl*imp_sth->rs_array_idx);
		SV *sv = AvARRAY(av)[i]; /* Note: we (re)use the SV in the AV	*/;


		if (DBIS->debug >= 4  || dbd_verbose >= 4) {
			PerlIO_printf(DBILOGFP, "    field #%d with rc=%d(%s)\n",i+1,rc,oci_col_return_codes(rc));
    	}

		if (rc == 1406				/* field was truncated	*/
		    && ora_dbtype_is_long(fbh->dbtype)/* field is a LONG	*/
		){
	    	int oraperl = DBIc_COMPAT(imp_sth);
	    	D_imp_dbh_from_sth ;
	    	D_imp_drh_from_dbh ;
	    	if (DBIc_has(imp_sth,DBIcf_LongTruncOk) || (oraperl && SvIV(imp_drh -> ora_trunc))) {
			/* user says truncation is ok */
			/* Oraperl recorded the truncation in ora_errno so we	*/
			/* so also but only for Oraperl mode handles.		*/
				if (oraperl) sv_setiv(DBIc_ERR(imp_sth), (IV)rc);
					rc = 0;		/* but don't provoke an error here	*/
		    }
	    /* else fall through and let rc trigger failure below	*/
		}

		if (rc == 0    || 	/* the normal case*/
		   (rc == 1406 && DBIc_has(imp_sth,DBIcf_LongTruncOk))/*Field Truncaded*/
		   ) {

			if (fbh->fetch_func) {

 				if (!fbh->fetch_func(sth, fbh, sv)){
					++err;	/* fetch_func already called oci_error */
				}
	      	} else {

				int datalen = fb_ary->arlen[imp_sth->rs_array_idx];
				char *p = (char*)row_data;

				if (fbh->ftype == SQLT_LVB){
					/* very special case for binary lobs that are directly fetched.
			           Seems I have to use SQLT_LVB to get the length all other will fail*/
					datalen = *(ub4*)row_data;
					sv_setpvn(sv, (char*)row_data+ sizeof(ub4), datalen);
				} else {
					if (ChopBlanks && fbh->dbtype == 96) {
				    while(datalen && p[datalen - 1]==' ')
						--datalen;
					}
					sv_setpvn(sv, p, (STRLEN)datalen);
					if (CSFORM_IMPLIES_UTF8(fbh->csform) ){
				    	SvUTF8_on(sv);
					}
				}
		    }

		} else if (rc == 1405) {	/* field is null - return undef	*/
	    	sv_set_undef(sv);
		} else {  /* See odefin rcode arg description in OCI docs	*/
			char buf[200];
		    char *hint = "";
		    /* These may get more case-by-case treatment eventually.	*/
		    if (rc == 1406) { /* field truncated (see above)  */
				if (!fbh->fetch_func) {
				    /* Copy the truncated value anyway, it may be of use,	*/
				    /* but it'll only be accessible via prior bind_column()	*/
				    sv_setpvn(sv, (char *)row_data,fb_ary->arlen[imp_sth->rs_array_idx]);
 				    if ((CSFORM_IMPLIES_UTF8(fbh->csform)) && (fbh->ftype != SQLT_BIN)){
						SvUTF8_on(sv);
					}
				}

				if (ora_dbtype_is_long(fbh->dbtype)){	/* double check */
				    hint = ", LongReadLen too small and/or LongTruncOk not set";
				}

			} else {	/* set field that caused error to undef */
	    	    	sv_set_undef(sv);
	        }
	    	++err;	/* 'fail' this fetch but continue getting fields */
	    	        /* Some should probably be treated as warnings but	*/
	    			/* for now we just treat them all as errors		*/
	    	sprintf(buf,"ORA-%05d error on field %d of %d, ora_type %d%s",rc, i+1, num_fields, fbh->dbtype, hint);
			oci_error(sth, imp_sth->errhp, OCI_ERROR, buf);
		}

		if (DBIS->debug >= 5 || dbd_verbose >= 5){
		    PerlIO_printf(DBILOGFP, "\n        %p (field=%d): %s\n",	 av, i,neatsvpv(sv,10));
		}
	}
    return (err) ? Nullav : av;
}


ub4
ora_parse_uid(imp_dbh_t *imp_dbh, char **uidp, char **pwdp)
{
	dTHX;
    sword status;
    /* OCI 8 does not seem to allow uid to be "name/pass" :-( */
    /* so we have to split it up ourselves */
    if (strlen(*pwdp)==0 && strchr(*uidp,'/')) {
	SV *tmpsv = sv_2mortal(newSVpv(*uidp,0));
	*uidp = SvPVX(tmpsv);
	*pwdp = strchr(*uidp, '/');
	*(*pwdp)++ = '\0';
	/* XXX look for '@', e.g. "u/p@d" and "u@d" and maybe "@d"? */
    }
    if (**uidp == '\0' && **pwdp == '\0') {
	return OCI_CRED_EXT;
    }
    OCIAttrSet_log_stat(imp_dbh->authp, OCI_HTYPE_SESSION,
	       *uidp, strlen(*uidp),
	       (ub4) OCI_ATTR_USERNAME, imp_dbh->errhp, status);
    OCIAttrSet_log_stat(imp_dbh->authp, OCI_HTYPE_SESSION,
	       (strlen(*pwdp)) ? *pwdp : NULL, strlen(*pwdp),
	       (ub4) OCI_ATTR_PASSWORD, imp_dbh->errhp, status);
    return OCI_CRED_RDBMS;
}


int
ora_db_reauthenticate(SV *dbh, imp_dbh_t *imp_dbh, char *uid, char *pwd)
{
	dTHX;
    sword status;
    /* XXX should possibly create new session before ending the old so	*/
    /* that if the new one can't be created, the old will still work.	*/
    OCISessionEnd_log_stat(imp_dbh->svchp, imp_dbh->errhp,
		   imp_dbh->authp, OCI_DEFAULT, status); /* XXX check status here?*/
    OCISessionBegin_log_stat( imp_dbh->svchp, imp_dbh->errhp, imp_dbh->authp,
		     ora_parse_uid(imp_dbh, &uid, &pwd), (ub4) OCI_DEFAULT, status);
    if (status != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, status, "OCISessionBegin");
	return 0;
    }
    return 1;
}


#ifdef not_used_curently
static char *
rowid2hex(OCIRowid *rowid)
{
	int i;
    SV *sv = sv_2mortal(newSVpv("",0));
    for (i = 0; i < OCI_ROWID_LEN; i++) {
	char buf[6];
	sprintf(buf, "%02X ", (int)(((ub1*)rowid)[i]));
	sv_catpv(sv, buf);
    }
    return SvPVX(sv);
}
#endif


static void *
alloc_via_sv(STRLEN len, SV **svp, int mortal)
{
	dTHX;
    SV *sv = newSVpv("",0);
    sv_grow(sv, len+1);
    memset(SvPVX(sv), 0, len);
    if (mortal)
	sv_2mortal(sv);
    if (svp)
	*svp = sv;
    return SvPVX(sv);
}


char *
find_ident_after(char *src, char *after, STRLEN *len, int copy)
{

    int seen_key = 0;
    char *orig = src;
    char *p;
    while(*src) {
	if (*src == '\'' || *src == '"') {
	    char delim = *src;
	    while(*src && *src != delim) ++src;
	}
	else if (*src == '-' && src[1] == '-') {
	    while(*src && *src != '\n') ++src;
	}
	else if (*src == '/' && src[1] == '*') {
	    while(*src && !(*src == '*' && src[1]=='/')) ++src;
	}
	else if (isALPHA(*src)) {
	    if (seen_key) {
		char *start = src;
		while(*src && (isALNUM(*src) || *src=='.' || *src=='$'))
		    ++src;
		*len = src - start;
		if (copy) {
		    p = (char*)alloc_via_sv(*len, 0, 1);
		    strncpy(p, start, *len);
		    p[*len] = '\0';
		    return p;
		}
		return start;
	    }
	    else if (  toLOWER(*src)==toLOWER(*after)
		    && (src==orig ? 1 : !isALPHA(src[-1]))
	    ) {
		p = after;
		while(*p && *src && toLOWER(*p)==toLOWER(*src))
		    ++p, ++src;
		if (!*p)
		    seen_key = 1;
	    }
	    ++src;
	}
	else
	    ++src;
    }
    return NULL;
}



struct lob_refetch_st {
    OCIStmt *stmthp;
    OCIBind *bindhp;
    OCIRowid *rowid;
    OCIParam *parmdp_tmp;
    OCIParam *parmdp_lob;
    int num_fields;
    SV *fbh_ary_sv;
    imp_fbh_t *fbh_ary;
};


static int
init_lob_refetch(SV *sth, imp_sth_t *imp_sth)
{
	dTHX;
    SV *sv;
    SV *sql_select;
    HV *lob_cols_hv = NULL;
    sword status;
    OCIError *errhp = imp_sth->errhp;
    OCIParam *parmhp = NULL, *collisthd = NULL, *colhd = NULL;
    ub2 numcols = 0;
    imp_fbh_t *fbh;
    int unmatched_params;
    I32 i;
    char *p;
    lob_refetch_t *lr = NULL;
    STRLEN tablename_len;
    char *tablename;
	switch (imp_sth->stmt_type) {
    	case OCI_STMT_UPDATE:
			tablename = find_ident_after(imp_sth->statement,
				"update", &tablename_len, 1);
			break;
    	case OCI_STMT_INSERT:
			tablename = find_ident_after(imp_sth->statement,
				"into", &tablename_len, 1);
			break;
    	default:
		return oci_error(sth, errhp, OCI_ERROR,
			"LOB refetch attempted for unsupported statement type (see also ora_auto_lob attribute)");
    }

    if (!tablename)
		return oci_error(sth, errhp, OCI_ERROR,
		"Unable to parse table name for LOB refetch");

 	if (!imp_sth->dschp){
   	    OCIHandleAlloc_ok(imp_sth->envhp, &imp_sth->dschp, OCI_HTYPE_DESCRIBE, status);
   	    if (status != OCI_SUCCESS) {
			oci_error(sth,imp_sth->errhp, status, "OCIHandleAlloc");
		}

	 }

    OCIDescribeAny_log_stat(imp_sth->svchp, errhp, tablename, strlen(tablename),
		(ub1)OCI_OTYPE_NAME, (ub1)1, (ub1)OCI_PTYPE_SYN, imp_sth->dschp, status);
    if (status == OCI_SUCCESS) { /* There is a synonym, get the schema */
    	char *syn_schema=NULL, *syn_name=NULL;
    	char new_tablename[100];
    	ub4 syn_schema_len = 0, syn_name_len = 0,tn_len;
      	OCIAttrGet_log_stat(imp_sth->dschp,  OCI_HTYPE_DESCRIBE,
				  &parmhp, 0, OCI_ATTR_PARAM, errhp, status);				  
      	OCIAttrGet_log_stat(parmhp, OCI_DTYPE_PARAM,
      		      &syn_schema, &syn_schema_len, OCI_ATTR_SCHEMA_NAME, errhp, status);
		OCIAttrGet_log_stat(parmhp, OCI_DTYPE_PARAM,
			      &syn_name, &syn_name_len, OCI_ATTR_OBJ_NAME, errhp, status);
		OCIAttrGet_log_stat(parmhp, OCI_DTYPE_PARAM,
			      &tablename, &tn_len, OCI_ATTR_NAME, errhp, status);
		strcpy(new_tablename,syn_schema);
		strcat(new_tablename, ".");
      	strncat(new_tablename, tablename,tn_len);
	    tablename=new_tablename;

	    if (DBIS->debug >= 3 || dbd_verbose >= 3)
			PerlIO_printf(DBILOGFP, "       lob refetching a synonym named=%s for %s \n", syn_name,tablename);
    }

    OCIDescribeAny_log_stat(imp_sth->svchp, errhp, tablename, strlen(tablename),
		(ub1)OCI_OTYPE_NAME, (ub1)1, (ub1)OCI_PTYPE_TABLE, imp_sth->dschp, status);
	if (status != OCI_SUCCESS) {
      /* XXX this OCI_PTYPE_TABLE->OCI_PTYPE_VIEW fallback should actually be	*/
      /* a loop that includes synonyms etc */
      OCIDescribeAny_log_stat(imp_sth->svchp, errhp, tablename, strlen(tablename),
	    (ub1)OCI_OTYPE_NAME, (ub1)1, (ub1)OCI_PTYPE_VIEW, imp_sth->dschp, status);
    	if (status != OCI_SUCCESS) {
			OCIHandleFree_log_stat(imp_sth->dschp, OCI_HTYPE_DESCRIBE, status);
			return oci_error(sth, errhp, status, "OCIDescribeAny(view)/LOB refetch");
    	  }
    }

    OCIAttrGet_log_stat(imp_sth->dschp,  OCI_HTYPE_DESCRIBE,
				&parmhp, 0, OCI_ATTR_PARAM, errhp, status);
    if ( ! status ) {
	    OCIAttrGet_log_stat(parmhp, OCI_DTYPE_PARAM,
				&numcols, 0, OCI_ATTR_NUM_COLS, errhp, status);
    }
    if ( ! status ) {
	    OCIAttrGet_log_stat(parmhp, OCI_DTYPE_PARAM,
				&collisthd, 0, OCI_ATTR_LIST_COLUMNS, errhp, status);
    }
    if (status != OCI_SUCCESS) {
		OCIHandleFree_log_stat(imp_sth->dschp, OCI_HTYPE_DESCRIBE, status);
		return oci_error(sth, errhp, status, "OCIDescribeAny/OCIAttrGet/LOB refetch");
    }

    if (DBIS->debug >= 3 || dbd_verbose >= 3)
		PerlIO_printf(DBILOGFP, "       lob refetch from table %s, %d columns:\n", tablename, numcols);

    for (i = 1; i <= (long)numcols; i++) {
		ub2 col_dbtype;
		char *col_name;
		ub4  col_name_len;
        OCIParamGet_log_stat(collisthd, OCI_DTYPE_PARAM, errhp, (dvoid**)&colhd, i, status);
        if (status)
		    break;

        OCIAttrGet_log_stat(colhd, OCI_DTYPE_PARAM, &col_dbtype, 0,
                            OCI_ATTR_DATA_TYPE, errhp, status);
        if (status)
           break;
        OCIAttrGet_log_stat(colhd, OCI_DTYPE_PARAM, &col_name, &col_name_len,
			    OCI_ATTR_NAME, errhp, status);
        if (status)
           break;
		if (DBIS->debug >= 3 || dbd_verbose >= 3)
		    PerlIO_printf(DBILOGFP, "       lob refetch table col %d: '%.*s' otype %d\n",
				(int)i, (int)col_name_len,col_name, col_dbtype);
		if (col_dbtype != SQLT_CLOB && col_dbtype != SQLT_BLOB)
		    continue;
		if (!lob_cols_hv)
		    lob_cols_hv = newHV();
			sv = newSViv(col_dbtype);
			(void)sv_setpvn(sv, col_name, col_name_len);
			if (CSFORM_IMPLIES_UTF8(SQLCS_IMPLICIT))
			    SvUTF8_on(sv);
				(void)SvIOK_on(sv);   /* "what a wonderful hack!" */
				hv_store(lob_cols_hv, col_name,col_name_len, sv,0);
				OCIDescriptorFree(colhd, OCI_DTYPE_PARAM);
		        colhd = NULL;
		    }
		    if (colhd)
				OCIDescriptorFree(colhd, OCI_DTYPE_PARAM);
		    if (status != OCI_SUCCESS) {
				oci_error(sth, errhp, status,
				    "OCIDescribeAny/OCIParamGet/OCIAttrGet/LOB refetch");
				OCIHandleFree_log_stat(imp_sth->dschp, OCI_HTYPE_DESCRIBE, status);
				return 0;
		    }
		    if (!lob_cols_hv)
				return oci_error(sth, errhp, OCI_ERROR,
				    "LOB refetch failed, no lobs in table");

    /*	our bind params are in %imp_sth->all_params_hv
	our table cols are in %lob_cols_hv
	we now iterate through our bind params
	and allocate them to the appropriate table columns
    */
		    Newz(1, lr, 1, lob_refetch_t);
		    unmatched_params = 0;
		    lr->num_fields = 0;
		    lr->fbh_ary = (imp_fbh_t*)alloc_via_sv(sizeof(imp_fbh_t) * HvKEYS(lob_cols_hv)+1,
			&lr->fbh_ary_sv, 0);

		    sql_select = sv_2mortal(newSVpv("select ",0));

		    hv_iterinit(imp_sth->all_params_hv);
		    while( (sv = hv_iternextsv(imp_sth->all_params_hv, &p, &i)) != NULL ) {
				int matched = 0;
				phs_t *phs = (phs_t*)(void*)SvPVX(sv);
				if (sv == &sv_undef || !phs)
				    croak("panic: unbound params");
				if (phs->ftype != SQLT_CLOB && phs->ftype != SQLT_BLOB)
				    continue;
				hv_iterinit(lob_cols_hv);
				while( (sv = hv_iternextsv(lob_cols_hv, &p, &i)) != NULL ) {
				    char sql_field[200];
				    if (phs->ora_field) {	/* must match this phs by field name	*/
						char *ora_field_name = SvPV(phs->ora_field,na);
						if (SvCUR(phs->ora_field) != SvCUR(sv)
						|| ibcmp(ora_field_name, SvPV(sv,na), (I32)SvCUR(sv) ) )
					    continue;
				    }
				    else			/* basic dumb match by type		*/
					    if (phs->ftype != SvIV(sv))
							continue;
				    else {			/* got a type match - check it's safe	*/
						SV *sv_other;
						char *p_other;
						/* would any other lob field match this type? */
						while( (sv_other = hv_iternextsv(lob_cols_hv, &p_other, &i)) != NULL ) {
						    if (phs->ftype != SvIV(sv_other))
								continue;
						    if (DBIS->debug >= 3 || dbd_verbose >= 3)
								PerlIO_printf(DBILOGFP,
									"       both %s and %s have type %d - ambiguous\n",
									neatsvpv(sv,0), neatsvpv(sv_other,0), (int)SvIV(sv_other));
							    Safefree(lr);
						    sv_free((SV*)lob_cols_hv);
						    return oci_error(sth, errhp, OCI_ERROR,
							"Need bind_param(..., { ora_field=>... }) attribute to identify table LOB field names");
						}
					}
				    matched = 1;
				    sprintf(sql_field, "%s%s \"%s\"",
					(SvCUR(sql_select)>7)?", ":"", p, &phs->name[1]);
				    sv_catpv(sql_select, sql_field);
				    if (DBIS->debug >= 3 || dbd_verbose >= 3)
						PerlIO_printf(DBILOGFP,
						"       lob refetch %s param: otype %d, matched field '%s' %s(%s)\n",
				    phs->name, phs->ftype, p,
				    (phs->ora_field) ? "by name " : "by type ", sql_field);
				    hv_delete(lob_cols_hv, p, i, G_DISCARD);
				    fbh = &lr->fbh_ary[lr->num_fields++];
				    fbh->name   = phs->name;
				    fbh->ftype  = phs->ftype;
				    fbh->dbtype = phs->ftype;
				    fbh->disize = 99;
				    fbh->desc_t = OCI_DTYPE_LOB;
				    OCIDescriptorAlloc_ok(imp_sth->envhp, &fbh->desc_h, fbh->desc_t);
				    break;	/* we're done with this placeholder now	*/
				}
				if (!matched) {
	   				++unmatched_params;
	   				if (DBIS->debug >= 3 || dbd_verbose >= 3)
						PerlIO_printf(DBILOGFP,
						    "       lob refetch %s param: otype %d, UNMATCHED\n",
				    phs->name, phs->ftype);
				}
    		}
    		sv_free((SV*)lob_cols_hv);
    		if (unmatched_params) {
    		    Safefree(lr);
				return oci_error(sth, errhp, OCI_ERROR,
				    "Can't match some parameters to LOB fields in the table, check type and name");
    		}

    		sv_catpv(sql_select, " from ");
    		sv_catpv(sql_select, tablename);
    		sv_catpv(sql_select, " where rowid = :rid for update"); /* get row with lock */
    		if (DBIS->debug >= 3 || dbd_verbose >= 3)
				PerlIO_printf(DBILOGFP,
				    "       lob refetch sql: %s\n", SvPVX(sql_select));
		   	lr->stmthp = NULL;
    		lr->bindhp = NULL;
    		lr->rowid  = NULL;
    		lr->parmdp_tmp = NULL;
    		lr->parmdp_lob = NULL;
			OCIHandleAlloc_ok(imp_sth->envhp, &lr->stmthp, OCI_HTYPE_STMT, status);
    		OCIStmtPrepare_log_stat(lr->stmthp, errhp,
				(text*)SvPVX(sql_select), SvCUR(sql_select), OCI_NTV_SYNTAX,
				OCI_DEFAULT, status);
    		if (status != OCI_SUCCESS) {
				OCIHandleFree(lr->stmthp, OCI_HTYPE_STMT);
				Safefree(lr);
				return oci_error(sth, errhp, status, "OCIStmtPrepare/LOB refetch");
    		}

    		/* bind the rowid input */
    		OCIDescriptorAlloc_ok(imp_sth->envhp, &lr->rowid, OCI_DTYPE_ROWID);
    		OCIBindByName_log_stat(lr->stmthp, &lr->bindhp, errhp, (text*)":rid", 4,
    	       &lr->rowid, sizeof(OCIRowid*), SQLT_RDD, 0,0,0,0,0, OCI_DEFAULT, status);
    		if (status != OCI_SUCCESS) {
				OCIDescriptorFree(lr->rowid, OCI_DTYPE_ROWID);
				OCIHandleFree(lr->stmthp, OCI_HTYPE_STMT);
				Safefree(lr);
				return oci_error(sth, errhp, status, "OCIBindByPos/LOB refetch");
    		}

    		/* define the output fields */
    		for(i=0; i < lr->num_fields; ++i) {
				OCIDefine *defnp = NULL;
				imp_fbh_t *fbh = &lr->fbh_ary[i];
				phs_t *phs;
				SV **phs_svp = hv_fetch(imp_sth->all_params_hv, fbh->name,strlen(fbh->name), 0);
				if (!phs_svp)
				    croak("panic: LOB refetch for '%s' param (%d) - name not found",
				fbh->name,i+1);
				phs = (phs_t*)(void*)SvPVX(*phs_svp);
				fbh->special = phs;
				if (DBIS->debug >= 3 || dbd_verbose >= 3)
				    PerlIO_printf(DBILOGFP,
						"       lob refetch %d for '%s' param: ftype %d setup\n",
			(int)i+1,fbh->name, fbh->dbtype);
			fbh->fb_ary = fb_ary_alloc(fbh->disize, 1);
			OCIDefineByPos_log_stat(lr->stmthp, &defnp, errhp, (ub4)i+1,
				&fbh->desc_h, -1, (ub2)fbh->ftype,
			fbh->fb_ary->aindp, 0, fbh->fb_ary->arcode, OCI_DEFAULT, status);
		if (status != OCI_SUCCESS) {
			OCIDescriptorFree(lr->rowid, OCI_DTYPE_ROWID);
		    OCIHandleFree(lr->stmthp, OCI_HTYPE_STMT);
		    Safefree(lr);
		    fb_ary_free(fbh->fb_ary);
			fbh->fb_ary = NULL;
		    return oci_error(sth, errhp, status, "OCIDefineByPos/LOB refetch");
		}
    }

    OCIHandleFree_log_stat(imp_sth->dschp, OCI_HTYPE_DESCRIBE, status);

    imp_sth->lob_refetch = lr;	/* structure copy */
    return 1;
}

int
post_execute_lobs(SV *sth, imp_sth_t *imp_sth, ub4 row_count)	/* XXX leaks handles on error */
{

    /* To insert a new LOB transparently (without using 'INSERT . RETURNING .')	*/
    /* we have to insert an empty LobLocator and then fetch it back from the	*/
    /* server before we can call OCILobWrite on it! This function handles that.	*/
    dTHX;
    sword status;
    int i;
    OCIError *errhp = imp_sth->errhp;
    lob_refetch_t *lr;
    D_imp_dbh_from_sth;
    SV *dbh = (SV*)DBIc_MY_H(imp_dbh);

    if (!imp_sth->auto_lob)
	  return 1;	/* application doesn't want magical lob handling */

	if (imp_sth->stmt_type == OCI_STMT_BEGIN || imp_sth->stmt_type == OCI_STMT_DECLARE){
	  /* PL/SQL is handled by lob_phs_ora_free_templobpost_execute */
	    if (imp_sth->has_lobs) { 	  /*get rid of OCILob Temporary used in non inout bind*/
  			SV *phs_svp;
		  	I32 i;
    	  	char *p;
    	  	hv_iterinit(imp_sth->all_params_hv);
		  	while( (phs_svp = hv_iternextsv(imp_sth->all_params_hv, &p, &i)) != NULL ) {
		  		phs_t *phs = (phs_t*)(void*)SvPVX(phs_svp);
		  		if (phs->desc_h && !phs->is_inout){
				   OCIHandleFree_log_stat(phs->desc_h, phs->desc_t, status);
		  	  	}
   			}
		}
		return 1;
	}

    if (row_count == 0)
		return 1;	/* nothing to do */
    if (row_count  > 1)
		return oci_error(sth, errhp, OCI_ERROR, "LOB refetch attempted for multiple rows");

    if (!imp_sth->lob_refetch) {
		if (!init_lob_refetch(sth, imp_sth))
	    	return 0;	/* init_lob_refetch already called oci_error */
    }
    lr = imp_sth->lob_refetch;

    OCIAttrGet_stmhp_stat(imp_sth, lr->rowid, 0, OCI_ATTR_ROWID,
			  status);
    if (status != OCI_SUCCESS)
		return oci_error(sth, errhp, status, "OCIAttrGet OCI_ATTR_ROWID /LOB refetch");


   		OCIStmtExecute_log_stat(imp_sth->svchp, lr->stmthp, errhp,
		1, 0, NULL, NULL, OCI_DEFAULT, status);	/* execute and fetch */
	if (status != OCI_SUCCESS)
	return oci_error(sth, errhp, status,
		ora_sql_error(imp_sth,"OCIStmtExecute/LOB refetch"));

    for(i=0; i < lr->num_fields; ++i) {
		imp_fbh_t *fbh = &lr->fbh_ary[i];
		int rc = fbh->fb_ary->arcode[0];
		phs_t *phs = (phs_t*)fbh->special;
		ub4 amtp;

    	if(SvUPGRADE(phs->sv, SVt_PV)){/* For GCC not to warn on unused result */ };	/* just in case */

		amtp = SvCUR(phs->sv);		/* XXX UTF8? */
		if (rc == 1405) {		/* NULL - return undef */
		    sv_set_undef(phs->sv);
		    status = OCI_SUCCESS;
		} else if (amtp > 0) {	/* since amtp==0 & OCI_ONE_PIECE fail (OCI 8.0.4) */
            if( ! fbh->csid ) {
				ub1 csform = SQLCS_IMPLICIT;
				ub2 csid = 0;
                OCILobCharSetForm_log_stat( imp_sth->envhp, errhp, (OCILobLocator*)fbh->desc_h, &csform, status );
                if (status != OCI_SUCCESS)
                    return oci_error(sth, errhp, status, "OCILobCharSetForm");
#ifdef OCI_ATTR_CHARSET_ID
		/* Effectively only used so AL32UTF8 works properly */
                OCILobCharSetId_log_stat( imp_sth->envhp, errhp, (OCILobLocator*)fbh->desc_h, &csid, status );
                if (status != OCI_SUCCESS)
                    return oci_error(sth, errhp, status, "OCILobCharSetId");
#endif /* OCI_ATTR_CHARSET_ID */
		/* if data is utf8 but charset isn't then switch to utf8 csid */
			csid = (SvUTF8(phs->sv) && !CS_IS_UTF8(csid)) ? utf8_csid : CSFORM_IMPLIED_CSID(csform);
       		         fbh->csid = csid;
       		         fbh->csform = csform;
       		}

       		if (DBIS->debug >= 3 || dbd_verbose >= 3)
                PerlIO_printf(DBILOGFP, "      calling OCILobWrite fbh->csid=%d fbh->csform=%d amtp=%d\n",
                    fbh->csid, fbh->csform, amtp );

	   		OCILobWrite_log_stat(imp_sth->svchp, errhp,
			    (OCILobLocator*)fbh->desc_h, &amtp, 1, SvPVX(phs->sv), amtp, OCI_ONE_PIECE,
			    0,0, fbh->csid ,fbh->csform, status);

            if (status != OCI_SUCCESS) {
                return oci_error(sth, errhp, status, "OCILobWrite in post_execute_lobs");
       		}
		}else {			/* amtp==0 so truncate LOB to zero length */
		    OCILobTrim_log_stat(imp_sth->svchp, errhp, (OCILobLocator*)fbh->desc_h, 0, status);
            if (status != OCI_SUCCESS) {
                return oci_error(sth, errhp, status, "OCILobTrim in post_execute_lobs");
        }
	}
		if (DBIS->debug >= 3 || dbd_verbose >= 3 )
		    PerlIO_printf(DBILOGFP,
			"       lob refetch %d for '%s' param: ftype %d, len %ld: %s %s\n",
			i+1,fbh->name, fbh->dbtype, ul_t(amtp),
			(rc==1405 ? "NULL" : (amtp > 0) ? "LobWrite" : "LobTrim"), oci_status_name(status));
		if (status != OCI_SUCCESS) {
		    return oci_error(sth, errhp, status, "OCILobTrim/OCILobWrite/LOB refetch");
		}
    }

    if (DBIc_has(imp_dbh,DBIcf_AutoCommit))
	dbd_db_commit(dbh, imp_dbh);

    return 1;
}

void
ora_free_lob_refetch(SV *sth, imp_sth_t *imp_sth)
{
	dTHX;
    lob_refetch_t *lr = imp_sth->lob_refetch;
    int i;
    sword status;
    if (lr->rowid)
       OCIDescriptorFree(lr->rowid, OCI_DTYPE_ROWID);
    OCIHandleFree_log_stat(lr->stmthp, OCI_HTYPE_STMT, status);
    if (status != OCI_SUCCESS)
	oci_error(sth, imp_sth->errhp, status, "ora_free_lob_refetch/OCIHandleFree");
    for(i=0; i < lr->num_fields; ++i) {
	imp_fbh_t *fbh = &lr->fbh_ary[i];
	ora_free_fbh_contents(fbh);
    }
    sv_free(lr->fbh_ary_sv);
    Safefree(imp_sth->lob_refetch);
    imp_sth->lob_refetch = NULL;
}

