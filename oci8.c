/*
   vim:sw=4:ts=8
   $Id: oci8.c,v 1.44 2004/02/26 01:32:01 timbo Exp $

   Copyright (c) 1998-2004  Tim Bunce  Ireland

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

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
    DBIS = dbistate;
}

void
dbd_init_oci_drh(imp_drh_t * imp_drh)
{
    imp_drh->ora_long    = perl_get_sv("Oraperl::ora_long",      GV_ADDMULTI);
    imp_drh->ora_trunc   = perl_get_sv("Oraperl::ora_trunc",     GV_ADDMULTI);
    imp_drh->ora_cache   = perl_get_sv("Oraperl::ora_cache",     GV_ADDMULTI);
    imp_drh->ora_cache_o = perl_get_sv("Oraperl::ora_cache_o",   GV_ADDMULTI);
}


char *
oci_status_name(sword status)
{
    SV *sv;
    switch (status) {
    case OCI_SUCCESS:		return "SUCCESS";
    case OCI_SUCCESS_WITH_INFO:	return "SUCCESS_WITH_INFO";
    case OCI_NEED_DATA:		return "NEED_DATA";
    case OCI_NO_DATA:		return "NO_DATA";
    case OCI_ERROR:		return "ERROR";
    case OCI_INVALID_HANDLE:	return "INVALID_HANDLE";
    case OCI_STILL_EXECUTING:	return "STILL_EXECUTING";
    case OCI_CONTINUE:		return "CONTINUE";
    }
    sv = sv_2mortal(newSVpv("",0));
    sv_grow(sv, 50);
    sprintf(SvPVX(sv),"(UNKNOWN OCI STATUS %d)", status);
    return SvPVX(sv);
}


char *
oci_stmt_type_name(int stmt_type)
{
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
oci_hdtype_name(ub4 hdtype)
{
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
		what, (long)recno,
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
     switch(handle_type) {
     case OCI_HTYPE_ENV:	return imp_dbh->envhp;
     case OCI_HTYPE_ERROR:	return imp_dbh->errhp;
     case OCI_HTYPE_SERVER:	return imp_dbh->srvhp;
     case OCI_HTYPE_SVCCTX:	return imp_dbh->svchp;
     case OCI_HTYPE_SESSION:	return imp_dbh->authp;
     }
     croak("Can't get OCI handle type %d from DBI database handle", handle_type);
     /* satisfy compiler warning, even though croak will never return */
     return 0;
}

void *
oci_st_handle(imp_sth_t *imp_sth, int handle_type, int flags)
{
     switch(handle_type) {
     case OCI_HTYPE_ENV:	return imp_sth->envhp;
     case OCI_HTYPE_ERROR:	return imp_sth->errhp;
     case OCI_HTYPE_SERVER:	return imp_sth->srvhp;
     case OCI_HTYPE_SVCCTX:	return imp_sth->svchp;
     case OCI_HTYPE_STMT:	return imp_sth->stmhp;
     }
     croak("Can't get OCI handle type %d from DBI statement handle", handle_type);
     /* satisfy compiler warning, even though croak will never return */
     return 0;
}


int
dbd_st_prepare(SV *sth, imp_sth_t *imp_sth, char *statement, SV *attribs)
{
    D_imp_dbh_from_sth;
    sword status = 0;
    ub4   oparse_lng   = 1;  /* auto v6 or v7 as suits db connected to	*/
    int   ora_check_sql = 1;	/* to force a describe to check SQL	*/
    IV    ora_placeholders = 1;	/* find and handle placeholders */
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
    if (attribs) {
	SV **svp;
	IV ora_auto_lob = 1;
	DBD_ATTRIB_GET_IV(  attribs, "ora_parse_lang", 14, svp, oparse_lng);
	DBD_ATTRIB_GET_IV(  attribs, "ora_placeholders", 16, svp, ora_placeholders);
	DBD_ATTRIB_GET_IV(  attribs, "ora_auto_lob",   12, svp, ora_auto_lob);
	imp_sth->auto_lob = (ora_auto_lob) ? 1 : 0;
	/* ora_check_sql only works for selects owing to Oracle behaviour */
	DBD_ATTRIB_GET_IV(  attribs, "ora_check_sql",  13, svp, ora_check_sql);
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
    if (DBIS->debug >= 3)
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
      /* [I'm not now sure why this is here - from a patch sometime ago - Tim] */
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
    phs_t *phs = (phs_t*)octxp;
    STRLEN phs_len;
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
    if (DBIS->debug >= 3)
 	PerlIO_printf(DBILOGFP, "       in  '%s' [%lu,%lu]: len %2lu, ind %d%s\n",
		phs->name, ul_t(iter), ul_t(index), ul_t(phs->alen), phs->indp,
		(phs->desc_h) ? " via descriptor" : "");
    if (index > 0 || iter > 0)
	croak("Arrays and multiple iterations not currently supported by DBD::Oracle (in %d/%d)", index,iter);
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
    phs_t *phs = (phs_t*)octxp;	/* context */
    /*imp_sth_t *imp_sth = phs->imp_sth;*/

    if (phs->desc_h) {
	*bufpp  = phs->desc_h;
	phs->alen = 0;
    }
    else {
	SV *sv = phs->sv;
	if (SvTYPE(sv) == SVt_RV && SvTYPE(SvRV(sv)) == SVt_PVAV) {
	    if (index > 0)	/* finish-up handling previous element */
		dbd_phs_avsv_complete(phs, (I32)index-1, DBIS->debug);
	    sv = *av_fetch((AV*)SvRV(sv), (IV)index, 1);
	    if (!SvOK(sv))
		sv_setpv(sv,"");
	}
	*bufpp = SvGROW(sv, (size_t)(((phs->maxlen < 28) ? 28 : phs->maxlen)+1)/*for null*/);
	phs->alen = SvLEN(sv);	/* max buffer size now, actual data len later */
    }
    *alenpp = &phs->alen;
    *indpp  = &phs->indp;
    *rcodepp= &phs->arcode;
    if (DBIS->debug >= 3)
 	PerlIO_printf(DBILOGFP, "       out '%s' [%ld,%ld]: alen %2ld, piece %d%s\n",
		phs->name, ul_t(iter), ul_t(index), ul_t(phs->alen), *piecep,
		(phs->desc_h) ? " via descriptor" : "");
    if (iter > 0)
	warn("Multiple iterations not currently supported by DBD::Oracle (out %d/%d)", index,iter);
    *piecep = OCI_ONE_PIECE;
    return OCI_CONTINUE;
}


#ifdef UTF8_SUPPORT
/* How many bytes are n utf8 chars in buffer */
static ub4
ora_utf8_to_bytes (ub1 *buffer, ub4 chars_wanted, ub4 max_bytes)
{
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

	    if (bytelen < datalen) {	/* will be truncated */
		int oraperl = DBIc_COMPAT(imp_sth);
		if (DBIc_has(imp_sth,DBIcf_LongTruncOk) 
		      || (oraperl && SvIV(imp_drh->ora_trunc))) {
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

		if (DBIS->debug >= 3) 
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

static int
fetch_func_nty(SV *sth, imp_fbh_t *fbh, SV *dest_sv)
{
    fb_ary_t *fb_ary = fbh->fb_ary;
    char *p = (char*)&fb_ary->abuf[0];
    ub4 datalen = *(ub4*)p;     /* XXX alignment ? */
    warn("fetch_func_nty unimplemented (datalen %d)", datalen);
    sv_set_undef(dest_sv);
    return 1;
}


/* ------ */


int 
dbd_rebind_ph_rset(SV *sth, imp_sth_t *imp_sth, phs_t *phs) 
{
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
lob_phs_post_execute(SV *sth, imp_sth_t *imp_sth, phs_t *phs, int pre_exec)
{
    if (pre_exec)
	return 1;
    sv_setref_pv(phs->sv, "OCILobLocatorPtr", (void*)phs->desc_h);
    return 1;
}

int 
dbd_rebind_ph_lob(SV *sth, imp_sth_t *imp_sth, phs_t *phs) 
{
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
	}
	else { /* ensure we're at least an SVt_PV (so SvPVX etc work)     */
            SvUPGRADE(phs->sv, SVt_PV);
	}
    }
    phs->indp   = (SvOK(phs->sv)) ? 0 : -1;
    phs->progv  = (char*)&phs->desc_h;
    phs->maxlen = sizeof(OCILobLocator*);
    if (phs->is_inout)
	phs->out_prepost_exec = lob_phs_post_execute;

    return 1;
}


#ifdef UTF8_SUPPORT
ub4
ora_blob_read_mb_piece(SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, 
  SV *dest_sv, long offset, UV len, long destoffset)
{
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

      if (dbis->debug >= 3)
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
      if (dbis->debug >= 3)
	PerlIO_printf(DBILOGFP,
		"       OCILobRead field %d %s: LOBlen %lu, LongReadLen %lu, BufLen %lu, Got %lu\n",
		fbh->field_num+1, "SKIPPED", (unsigned long)loblen,
		(unsigned long)imp_sth->long_readlen, (unsigned long)buflen,
		(unsigned long)amtp);
    }

    if (dbis->debug >= 3)
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

    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP,
	    "        blob_read field %d: ftype %d %s, offset %ld, len %lu."
		    "LOB csform %d, len %lu, amtp %lu, (destoffset=%ld)\n",
	    fbh->field_num+1, ftype, type_name, offset, ul_t(len),
	    csform, loblen, ul_t(amtp), destoffset);

    if (loblen > 0) {
        ub1 * bufp = (ub1 *)(SvPVX(dest_sv));
	bufp += destoffset;

	OCILobRead_log_stat(imp_sth->svchp, imp_sth->errhp, lobl,
	    &amtp, (ub4)1 + offset, bufp, buflen,
		0, 0, (ub2)0 , csform, status);

	if (DBIS->debug >= 3)
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
	if (DBIS->debug >= 3)
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
fetch_func_autolob(SV *sth, imp_fbh_t *fbh, SV *dest_sv)
{
    ub4 loblen = 0;
    ub4 buflen;
    ub4 amtp = 0;
    int loblen_is_chars;
    imp_sth_t *imp_sth = fbh->imp_sth;
    OCILobLocator *lobloc = (OCILobLocator*)fbh->desc_h;
    sword status;

    /* this function is not called for NULL lobs */

    /* The length is expressed in terms of bytes for BLOBs and BFILEs,	*/
    /* and in terms of characters for CLOBs				*/
    OCILobGetLength_log_stat(imp_sth->svchp, imp_sth->errhp, lobloc, &loblen, status);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCILobGetLength fetch_func_autolob");
	return 0;
    }
    loblen_is_chars = (fbh->ftype == 112);

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
	    sprintf(buf,"fetching field %d of %d. LOB value truncated from %ld to %ld. %s",
		    fbh->field_num+1, DBIc_NUM_FIELDS(imp_sth), ul_t(loblen), ul_t(amtp),
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

	if (fbh->dbtype == 114) {
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
	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP,
		"        OCILobRead field %d %s: csform %d, LOBlen %luc, LongReadLen %luc, BufLen %lub, Got %luc\n",
		fbh->field_num+1, oci_status_name(status), csform, ul_t(loblen),
		ul_t(imp_sth->long_readlen), ul_t(buflen), ul_t(amtp));

	if (fbh->dbtype == 114) {
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
	if (fbh->ftype == 112 && CSFORM_IMPLIES_UTF8(csform)) /* Don't set UTF8 on BLOBs */
	    SvUTF8_on(dest_sv);
	ora_free_templob(sth, imp_sth, lobloc);
    }
    else {			/* LOB length is 0 */
	assert(amtp == 0);
	/* tell perl what we've put in its dest_sv */
	SvCUR(dest_sv) = amtp;
	*SvEND(dest_sv) = '\0';
	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP,
		"        OCILobRead field %d %s: LOBlen %lu, LongReadLen %lu, BufLen %lu, Got %lu\n",
		fbh->field_num+1, "SKIPPED", ul_t(loblen),
		ul_t(imp_sth->long_readlen), ul_t(buflen), ul_t(amtp));
    }

    SvPOK_on(dest_sv);

    return 1;
}


static int
fetch_func_getrefpv(SV *sth, imp_fbh_t *fbh, SV *dest_sv)
{
    /* See the Oracle::OCI module for how to actually use this! */
    sv_setref_pv(dest_sv, fbh->bless, (void*)fbh->desc_h);
    return 1;
}

static void
fbh_setup_getrefpv(imp_fbh_t *fbh, int desc_t, char *bless)
{
    if (DBIS->debug >= 2)
	PerlIO_printf(DBILOGFP,
	    "    col %d: otype %d, desctype %d, %s", fbh->field_num, fbh->dbtype, desc_t, bless);
    fbh->ftype  = fbh->dbtype;
    fbh->disize = fbh->dbsize;
    fbh->fetch_func = fetch_func_getrefpv;
    fbh->bless  = bless;
    fbh->desc_t = desc_t;
    OCIDescriptorAlloc_ok(fbh->imp_sth->envhp, &fbh->desc_h, fbh->desc_t);
}


int
dbd_describe(SV *h, imp_sth_t *imp_sth)
{
    D_imp_dbh_from_sth;
	D_imp_drh_from_dbh ;
    UV	long_readlen;
    ub4 num_fields;
    int num_errors = 0;
    int has_longs = 0;
    int est_width = 0;		/* estimated avg row width (for cache)	*/
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

    if (imp_sth->stmt_type != OCI_STMT_SELECT) { /* XXX DISABLED, see num_fields test below */
	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP, "    dbd_describe skipped for %s\n",
		oci_stmt_type_name(imp_sth->stmt_type));
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    if (DBIS->debug >= 3)
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
	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP, "    dbd_describe skipped for %s (no fields returned)\n",
		oci_stmt_type_name(imp_sth->stmt_type));
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    DBIc_NUM_FIELDS(imp_sth) = num_fields;
    Newz(42, imp_sth->fbh, num_fields, imp_fbh_t);


    /* Get number of fields and space needed for field names	*/
    for(i = 1; i <= num_fields; ++i) {
	char *p;
	ub4 atrlen;
	int avg_width = 0;
	imp_fbh_t *fbh = &imp_sth->fbh[i-1];
	fbh->imp_sth   = imp_sth;
	fbh->field_num = i;

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
#ifdef OCI_ATTR_CHARSET_ID
        fbh->csid = 0; fbh->csform = 0; /* just to be sure */
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
	switch (fbh->dbtype) {
	/*	the simple types	*/
	case   1:				/* VARCHAR2	*/
		avg_width = fbh->dbsize / 2;
		/* FALLTHRU */
	case  96:				/* CHAR		*/
		fbh->disize = fbh->dbsize;
		if (CS_IS_UTF8(fbh->csid)) 
		    fbh->disize = fbh->dbsize * 4;
		fbh->prec   = fbh->disize;
		break;
	case  23:				/* RAW		*/
		fbh->disize = fbh->dbsize * 2;
		fbh->prec   = fbh->disize;
		break;

	case   2:				/* NUMBER	*/
		fbh->disize = 130+38+3;		/* worst case	*/
		avg_width = 4;     /* > approx +/- 1_000_000 ?  */
		break;

	case  12:				/* DATE		*/
		/* actually dependent on NLS default date format*/
		fbh->disize = 75;	/* a generous default	*/
		fbh->prec   = fbh->disize;
		avg_width = 8;	/* size in SQL*Net packet  */
		break;

	case   8:				/* LONG		*/
                if (CS_IS_UTF8(fbh->csid)) 
                    fbh->disize = long_readlen * 4;
                else
                    fbh->disize = long_readlen;

                /* not governed by else: */
		fbh->dbsize = (fbh->disize>65535) ? 65535 : fbh->disize;
		fbh->ftype  = 94; /* VAR form */
		fbh->fetch_func = fetch_func_varfield;
		++has_longs;
		break;
	case  24:				/* LONG RAW	*/
		fbh->disize = long_readlen * 2;
		fbh->dbsize = (fbh->disize>65535) ? 65535 : fbh->disize;
		fbh->ftype  = 95; /* VAR form */
		fbh->fetch_func = fetch_func_varfield;
		++has_longs;
		break;

	case  11:				/* ROWID	*/
	case 104:				/* ROWID Desc	*/
		fbh->disize = 20;
		fbh->prec   = fbh->disize;
		break;

	case 112:				/* CLOB	& NCLOB	*/
	case 113:				/* BLOB		*/
	case 114:				/* BFILE	*/
		fbh->ftype  = fbh->dbtype;
                /* do we need some addition size logic here? (lab) */
		fbh->disize = fbh->dbsize *10 ;	/* XXX! */
		fbh->fetch_func = (imp_sth->auto_lob)
				? fetch_func_autolob : fetch_func_getrefpv;
		fbh->bless  = "OCILobLocatorPtr";
		fbh->desc_t = OCI_DTYPE_LOB;
		OCIDescriptorAlloc_ok(imp_sth->envhp, &fbh->desc_h, fbh->desc_t);
		break;

#ifdef OCI_DTYPE_REF
	case 111:				/* REF		*/
		fbh_setup_getrefpv(fbh, OCI_DTYPE_REF, "OCIRefPtr");
		break;
#endif

	case 182:                  /* INTERVAL YEAR TO MONTH */
	case 183:                  /* INTERVAL DAY TO SECOND */
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
		if (DBIS->debug >= 1)
		    PerlIO_printf(DBILOGFP, p, i, fbh->dbtype, "\n");
		if (dowarn)
		    warn(p, i, fbh->dbtype, "");
		break;
	}
	if (DBIS->debug >= 3)
           PerlIO_printf(DBILOGFP,
	        "    col %2d: dbtype %d, scale %d, prec %d, nullok %d, name %s\n"
	         "          : dbsize %d, char_used %d, char_size %d, csid %d, csform %d, disize %d\n",
		i, fbh->dbtype, fbh->scale, fbh->prec, fbh->nullok, fbh->name,
		fbh->dbsize, fbh->len_char_used, fbh->len_char_size, fbh->csid, fbh->csform, fbh->disize);

	if (fbh->ftype == 5)	/* XXX need to handle wide chars somehow */
	    fbh->disize += 1;	/* allow for null terminator */

	/* dbsize can be zero for 'select NULL ...'			*/
	imp_sth->t_dbsize += fbh->dbsize;
	if (!avg_width)
	    avg_width = fbh->dbsize;
	est_width += avg_width;

	if (DBIS->debug >= 2)
	    dbd_fbh_dump(fbh, (int)i, 0);
    }
    imp_sth->est_width = est_width;

    /* --- Setup the row cache for this query --- */

    /* number of rows to cache	*/
    if      (SvOK(imp_drh->ora_cache_o)) imp_sth->cache_rows = SvIV(imp_drh->ora_cache_o);
    else if (SvOK(imp_drh->ora_cache))   imp_sth->cache_rows = SvIV(imp_drh->ora_cache);
    else                        imp_sth->cache_rows = imp_dbh->RowCacheSize;
    if (imp_sth->cache_rows >= 0) {	/* set cache size by row count	*/
	ub4 cache_mem  = 0; /* so memory isn't the limit */
	ub4 cache_rows = calc_cache_rows((int)num_fields,
				est_width, imp_sth->cache_rows, has_longs);
	imp_sth->cache_rows = cache_rows;	/* record updated value */
	OCIAttrSet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT,
	    &cache_mem,  sizeof(cache_mem), OCI_ATTR_PREFETCH_MEMORY,
	    imp_sth->errhp, status);
	OCIAttrSet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT,
		&cache_rows, sizeof(cache_rows), OCI_ATTR_PREFETCH_ROWS,
		imp_sth->errhp, status);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status, "OCIAttrSet OCI_ATTR_PREFETCH_ROWS");
	    ++num_errors;
	}
    }
    else {				/* set cache size by memory	*/
	ub4 cache_mem  = -imp_sth->cache_rows; /* cache_mem always +ve here */
	ub4 cache_rows = 100000;	/* set high so memory is the limit */
	OCIAttrSet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT,
	    &cache_rows, sizeof(cache_rows), OCI_ATTR_PREFETCH_ROWS,
	    imp_sth->errhp, status);
	OCIAttrSet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT,
	    &cache_mem,  sizeof(cache_mem), OCI_ATTR_PREFETCH_MEMORY,
	    imp_sth->errhp, status);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status,
		"OCIAttrSet OCI_ATTR_PREFETCH_ROWS/OCI_ATTR_PREFETCH_MEMORY");
	    ++num_errors;
	}
    }

    imp_sth->long_readlen = long_readlen;
    /* Initialise cache counters */
    imp_sth->in_cache  = 0;
    imp_sth->eod_errno = 0;

    for(i=1; i <= num_fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i-1];
	int ftype = fbh->ftype;
	/* add space for STRING null term, or VAR len prefix */
	sb4 define_len = (ftype==94||ftype==95) ? fbh->disize+4 : fbh->disize;
	fb_ary_t  *fb_ary;

	fbh->fb_ary = fb_ary_alloc(define_len, 1);
	fb_ary = fbh->fb_ary;

	OCIDefineByPos_log_stat(imp_sth->stmhp, &fbh->defnp,
	    imp_sth->errhp, (ub4) i,
	    (fbh->desc_h) ? (dvoid*)&fbh->desc_h : (dvoid*)fb_ary->abuf,
	    (fbh->desc_h) ?                   -1 :         define_len,
	    (ub2)fbh->ftype,
	    fb_ary->aindp,
	    (ftype==94||ftype==95) ? NULL : fb_ary->arlen,
	    fb_ary->arcode, OCI_DEFAULT, status);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status, "OCIDefineByPos");
	    ++num_errors;
	}

#ifdef OCI_ATTR_CHARSET_FORM
        if ( (fbh->dbtype == 1) ) { /*  && (fbh->csform == SQLCS_NCHAR) && CS_IS_UTF8(ncharsetid) ) { */
            /* ok... after doing what tim asked: setting SvUTF8 strictly based on csid 8bit Nchar test was broken
               and this currently effectively just sets Attrs to the values in fhb ignoring ncharsetid altogether 
               probably wrong
             */
            ub1 csform = fbh->csform;
            if (DBIS->debug >= 3)
               PerlIO_printf(DBILOGFP, "     calling OCIAttrSet OCI_ATTR_CHARSET_FORM with csform=%d\n", csform );
            OCIAttrSet_log_stat( fbh->defnp, (ub4) OCI_HTYPE_DEFINE, (dvoid *) &csform, 
                                 (ub4) 0, (ub4) OCI_ATTR_CHARSET_FORM, imp_sth->errhp, status );
            if (status != OCI_SUCCESS) {
                oci_error(h, imp_sth->errhp, status, "OCIAttrSet OCI_ATTR_CHARSET_FORM");
                ++num_errors;
            }
        }
#endif /* OCI_ATTR_CHARSET_FORM */

	if (fbh->ftype == 108) {
	    oci_error(h, NULL, OCI_ERROR, "OCIDefineObject call needed but not implemented yet");
	    ++num_errors;
	}

    }

    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP,
	"    dbd_describe'd %d columns (row bytes: %d max, %d est avg, cache: %d)\n",
	(int)num_fields, imp_sth->t_dbsize, imp_sth->est_width, imp_sth->cache_rows);

    return (num_errors>0) ? 0 : 1;
}


AV *
dbd_st_fetch(SV *sth, imp_sth_t *imp_sth)
{
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
	oci_error(sth, NULL, OCI_ERROR, 
	    "no statement executing (perhaps you need to call execute first)");
	return Nullav;
    }

    if (ora_fetchtest && DBIc_ROW_COUNT(imp_sth)>0) {
	--ora_fetchtest; /* trick for testing performance */
	status = OCI_SUCCESS;
    }
    else {
	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP, "    dbd_st_fetch %d fields...\n", DBIc_NUM_FIELDS(imp_sth));
	OCIStmtFetch_log_stat(imp_sth->stmhp, imp_sth->errhp,
		1, (ub2)OCI_FETCH_NEXT, OCI_DEFAULT, status);
    }

    if (status != OCI_SUCCESS) {
	ora_fetchtest = 0;
	if (status == OCI_NO_DATA) {
	    dTHR; 			/* for DBIc_ACTIVE_off	*/
	    DBIc_ACTIVE_off(imp_sth);	/* eg finish		*/
	    if (DBIS->debug >= 3)
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

    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP, "    dbd_st_fetch %d fields %s\n",
			num_fields, oci_status_name(status));

    ChopBlanks = DBIc_has(imp_sth, DBIcf_ChopBlanks);

    err = 0;
    for(i=0; i < num_fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	fb_ary_t *fb_ary = fbh->fb_ary;
	int rc = fb_ary->arcode[0];
	SV *sv = AvARRAY(av)[i]; /* Note: we (re)use the SV in the AV	*/

	if (rc == 1406				/* field was truncated	*/
	    && ora_dbtype_is_long(fbh->dbtype)/* field is a LONG	*/
	) {
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

	if (rc == 0) {			/* the normal case		*/
	    if (fbh->fetch_func) {
		if (!fbh->fetch_func(sth, fbh, sv))
		    ++err;	/* fetch_func already called oci_error */
	    }
	    else {
		int datalen = fb_ary->arlen[0];
		char *p = (char*)&fb_ary->abuf[0];
		/* if ChopBlanks check for Oracle CHAR type (blank padded)	*/
		if (ChopBlanks && fbh->dbtype == 96) {
		    while(datalen && p[datalen - 1]==' ')
			--datalen;
		}
		sv_setpvn(sv, p, (STRLEN)datalen);
		if (CSFORM_IMPLIES_UTF8(fbh->csform))
		    SvUTF8_on(sv);
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
		    sv_setpvn(sv, (char*)&fb_ary->abuf[0],
			  fb_ary->arlen[0]);
		    if (CSFORM_IMPLIES_UTF8(fbh->csform))
			SvUTF8_on(sv);
		}
		if (ora_dbtype_is_long(fbh->dbtype))	/* double check */
		    hint = ", LongReadLen too small and/or LongTruncOk not set";
	    }
	    else {	/* set field that caused error to undef */
	        sv_set_undef(sv);
	    }
	    ++err;	/* 'fail' this fetch but continue getting fields */
	    /* Some should probably be treated as warnings but	*/
	    /* for now we just treat them all as errors		*/
	    sprintf(buf,"ORA-%05d error on field %d of %d, ora_type %d%s",
			rc, i+1, num_fields, fbh->dbtype, hint);
	    oci_error(sth, imp_sth->errhp, OCI_ERROR, buf);
	}

	if (DBIS->debug >= 5)
	    PerlIO_printf(DBILOGFP, "        %d (rc=%d): %s\n",
		i, rc, neatsvpv(sv,0));
    }

    return (err) ? Nullav : av;
}


ub4
ora_parse_uid(imp_dbh_t *imp_dbh, char **uidp, char **pwdp)
{
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
    SV *sv;
    SV *sql_select;
    HV *lob_cols_hv = NULL;
    sword status;
    OCIError *errhp = imp_sth->errhp;
    OCIDescribe  *dschp = NULL;
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

    OCIHandleAlloc_ok(imp_sth->envhp, &dschp, OCI_HTYPE_DESCRIBE, status);
#ifdef OCI_ATTR_OBJ_NAME /* not in 8.0.x */
    OCIDescribeAny_log_stat(imp_sth->svchp, errhp, tablename, strlen(tablename),
		(ub1)OCI_OTYPE_NAME, (ub1)1, (ub1)OCI_PTYPE_SYN, dschp, status);
    if (status == OCI_SUCCESS) { /* There is a synonym, get the schema */
      char new_tablename[100];
      char *syn_schema=NULL,  *syn_name=NULL;
      OCIAttrGet_log_stat(dschp,  OCI_HTYPE_DESCRIBE,
				  &parmhp, 0, OCI_ATTR_PARAM, errhp, status);
      OCIAttrGet_log_stat(parmhp, OCI_DTYPE_PARAM,
			  &syn_schema, 0, OCI_ATTR_SCHEMA_NAME, errhp, status);
      OCIAttrGet_log_stat(parmhp, OCI_DTYPE_PARAM,
			  &syn_name, 0, OCI_ATTR_OBJ_NAME, errhp, status);
      strcpy(new_tablename, syn_schema);
      strcat(new_tablename, ".");
      strcat(new_tablename, syn_name);
      tablename=new_tablename;
      if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP, "       lob refetch synonym, schema=%s, name=%s, new tablename=%s\n", syn_schema, syn_name, tablename);
    }
#endif /* OCI_ATTR_OBJ_NAME */
    OCIDescribeAny_log_stat(imp_sth->svchp, errhp, tablename, strlen(tablename),
	(ub1)OCI_OTYPE_NAME, (ub1)1, (ub1)OCI_PTYPE_TABLE, dschp, status);
    if (status != OCI_SUCCESS) {
      /* XXX this OCI_PTYPE_TABLE->OCI_PTYPE_VIEW fallback should actually be	*/
      /* a loop that includes synonyms etc */
      OCIDescribeAny_log_stat(imp_sth->svchp, errhp, tablename, strlen(tablename),
	    (ub1)OCI_OTYPE_NAME, (ub1)1, (ub1)OCI_PTYPE_VIEW, dschp, status);
      if (status != OCI_SUCCESS) {
	OCIHandleFree_log_stat(dschp, OCI_HTYPE_DESCRIBE, status);
	return oci_error(sth, errhp, status, "OCIDescribeAny(view)/LOB refetch");
      }
    } 

    OCIAttrGet_log_stat(dschp,  OCI_HTYPE_DESCRIBE,
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
	OCIHandleFree_log_stat(dschp, OCI_HTYPE_DESCRIBE, status);
	return oci_error(sth, errhp, status, "OCIDescribeAny/OCIAttrGet/LOB refetch");
    }
    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP, "       lob refetch from table %s, %d columns:\n",
	    tablename, numcols);

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
	if (DBIS->debug >= 3)
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
	OCIHandleFree_log_stat(dschp, OCI_HTYPE_DESCRIBE, status);
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
		    if (DBIS->debug >= 3)
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
	    if (DBIS->debug >= 3)
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
	    if (DBIS->debug >= 3)
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
    if (DBIS->debug >= 3)
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
	if (DBIS->debug >= 3)
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

    imp_sth->lob_refetch = lr;	/* structure copy */
    return 1;
}


int
post_execute_lobs(SV *sth, imp_sth_t *imp_sth, ub4 row_count)	/* XXX leaks handles on error */
{
    /* To insert a new LOB transparently (without using 'INSERT . RETURNING .')	*/
    /* we have to insert an empty LobLocator and then fetch it back from the	*/
    /* server before we can call OCILobWrite on it! This function handles that.	*/
    sword status;
    int i;
    OCIError *errhp = imp_sth->errhp;
    lob_refetch_t *lr;
    D_imp_dbh_from_sth;
    SV *dbh = (SV*)DBIc_MY_H(imp_dbh);

    if (!imp_sth->auto_lob)
	return 1;	/* application doesn't want magical lob handling */
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

        SvUPGRADE(phs->sv, SVt_PV);	/* just in case */
	amtp = SvCUR(phs->sv);		/* XXX UTF8? */
	if (rc == 1405) {		/* NULL - return undef */
	    sv_set_undef(phs->sv);
	    status = OCI_SUCCESS;
	}
	else if (amtp > 0) {	/* since amtp==0 & OCI_ONE_PIECE fail (OCI 8.0.4) */
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

            if (DBIS->debug >= 3)
                PerlIO_printf(DBILOGFP, "      calling OCILobWrite fbh->csid=%d fbh->csform=%d amtp=%d\n",
                    fbh->csid, fbh->csform, amtp );
	    OCILobWrite_log_stat(imp_sth->svchp, errhp,
		    (OCILobLocator*)fbh->desc_h, &amtp, 1, SvPVX(phs->sv), amtp, OCI_ONE_PIECE,
		    0,0, fbh->csid ,fbh->csform, status);
            if (status != OCI_SUCCESS) {
                return oci_error(sth, errhp, status, "OCILobWrite in post_execute_lobs");
            }
	}
	else {			/* amtp==0 so truncate LOB to zero length */
	    OCILobTrim_log_stat(imp_sth->svchp, errhp, (OCILobLocator*)fbh->desc_h, 0, status);
            if (status != OCI_SUCCESS) {
                return oci_error(sth, errhp, status, "OCILobTrim in post_execute_lobs");
            }
	}
	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP,
		"       lob refetch %d for '%s' param: ftype %d, len %ld: %s %s\n",
		i+1,fbh->name, fbh->dbtype, ul_t(amtp),
		(rc==1405 ? "NULL" : (amtp > 0) ? "LobWrite" : "LobTrim"), oci_status_name(status)
                );
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

