/*
   $Id: oci8.c,v 1.18 1999/06/05 03:23:07 timbo Exp $

   Copyright (c) 1998  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#include "Oracle.h"


#ifdef OCI_V8_SYNTAX


DBISTATE_DECLARE;

static SV *ora_long;
static SV *ora_trunc;
static SV *ora_cache;
static SV *ora_cache_o;		/* for ora_open() cache override */

extern int pp_exec_rset _((SV *sth, imp_sth_t *imp_sth, phs_t *phs, int pre_exec));

void
dbd_init_oci(dbistate_t *dbistate)
{
    DBIS = dbistate;
    ora_long     = perl_get_sv("Oraperl::ora_long",      GV_ADDMULTI);
    ora_trunc    = perl_get_sv("Oraperl::ora_trunc",     GV_ADDMULTI);
    ora_cache    = perl_get_sv("Oraperl::ora_cache",     GV_ADDMULTI);
    ora_cache_o  = perl_get_sv("Oraperl::ora_cache_o",   GV_ADDMULTI);
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


int
oci_error(SV *h, OCIError *errhp, sword status, char *what)
{
    D_imp_xxh(h);
    SV *errstr = DBIc_ERRSTR(imp_xxh);
    sv_setpv(errstr, "");
    if (errhp) {
	text errbuf[1024];
	ub4 recno = 0;
	sb4 errcode = 0;
	sb4 eg_errcode = 0;
	sword eg_status;
	while( (eg_status = OCIErrorGet(errhp, ++recno, (text*)NULL,
			    &eg_errcode, errbuf,
			    (ub4)sizeof(errbuf), OCI_HTYPE_ERROR)) != OCI_NO_DATA
		&& eg_status != OCI_INVALID_HANDLE
		&& recno < 100
	) {
	    if (DBIS->debug >= 4 || recno>1/*XXX temp*/)
		fprintf(DBILOGFP, "    OCIErrorGet after %s (er%ld:%s): %d, %ld: %s\n",
		    what, (long)recno,
			(eg_status==OCI_SUCCESS) ? "ok" : oci_status_name(eg_status),
			status, (long)eg_errcode, errbuf);
	    errcode = eg_errcode;
	    sv_catpv(errstr, (char*)errbuf);
	    if (*(SvEND(errstr)-1) == '\n')
		--SvCUR(errstr);
	}
	if (what || status != OCI_ERROR) {
	    sv_catpv(errstr, " (DBD ");
	    sv_catpv(errstr, oci_status_name(status));
	    if (what) {
		sv_catpv(errstr, ": ");
		sv_catpv(errstr, what);
	    }
	    sv_catpv(errstr, ")");
	}
	/* DBIc_ERR *must* be SvTRUE (for RaiseError etc), some	*/
	/* errors, like OCI_INVALID_HANDLE, don't set errcode.	*/
	if (errcode == 0)
	    errcode = (status != 0) ? status : -10000;
	sv_setiv(DBIc_ERR(imp_xxh), (IV)errcode);
    }
    else {
	sv_setiv(DBIc_ERR(imp_xxh), (IV)status);
	sv_catpv(errstr, oci_status_name(status));
	sv_catpv(errstr, " ");
	sv_catpv(errstr, what);
    }
    DBIh_EVENT2(h, ERROR_event, DBIc_ERR(imp_xxh), errstr);
    return 0;	/* always returns 0 */
}


int
dbd_st_prepare(sth, imp_sth, statement, attribs)
    SV *sth;
    imp_sth_t *imp_sth;
    char *statement;
    SV *attribs;
{
    D_imp_dbh_from_sth;
    ub4   oparse_lng   = 1;  /* auto v6 or v7 as suits db connected to	*/
    int   ora_check_sql = 0;	/* to force a describe to check SQL	*/
    sword status = 0;

    if (!DBIc_ACTIVE(imp_dbh)) {
	oci_error(sth, NULL, OCI_ERROR, "Database disconnected");
        return 0;
    }

    imp_sth->done_desc = 0;

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
	DBD_ATTRIB_GET_IV(  attribs, "ora_parse_lang", 14, svp, oparse_lng);
	DBD_ATTRIB_GET_IV(  attribs, "ora_auto_lob",   12, svp, imp_sth->auto_lob);
	/* ora_check_sql only works for selects owing to Oracle behaviour */
	DBD_ATTRIB_GET_IV(  attribs, "ora_check_sql",  13, svp, ora_check_sql);
    }

    /* scan statement for '?', ':1' and/or ':foo' style placeholders	*/
    dbd_preparse(imp_sth, statement);

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

    OCIHandleAlloc_ok(imp_dbh->envhp, &imp_sth->stmhp, OCI_HTYPE_STMT);
    status = OCIStmtPrepare(imp_sth->stmhp, imp_sth->errhp,
	       (text*)imp_sth->statement, (ub4)strlen(imp_sth->statement),
	       oparse_lng, OCI_DEFAULT);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCIStmtPrepare");
	OCIHandleFree(imp_sth->stmhp, OCI_HTYPE_STMT);
	return 0;
    }

    OCIAttrGet_stmhp(imp_sth, &imp_sth->stmt_type, 0, OCI_ATTR_STMT_TYPE);
    if (DBIS->debug >= 3)
	fprintf(DBILOGFP, "    dbd_st_prepare'd sql %s\n",
		oci_stmt_type_name(imp_sth->stmt_type));

    DBIc_IMPSET_on(imp_sth);

    if (ora_check_sql) {
	if (!dbd_describe(sth, imp_sth))
	    return 0;
    }

    return 1;
}


sb4
dbd_phs_in(dvoid *octxp, OCIBind *bindp, ub4 iter, ub4 index,
	      dvoid **bufpp, ub4 *alenp, ub1 *piecep, dvoid **indpp)
{
    phs_t *phs = octxp;
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
 	fprintf(DBILOGFP, "       dbd_phs_in  '%s' (%ld,%ld): len %2ld, ind %d%s\n",
		phs->name, iter, index, phs->alen, phs->indp,
		(phs->desc_h) ? " via descriptor" : "");
    if (index > 0 || iter > 0)
	croak("Arrays and multiple iterations not currently supported by DBD::Oracle");
    return OCI_CONTINUE;
}

sb4
dbd_phs_out(dvoid *octxp, OCIBind *bindp, ub4 iter, ub4 index,
	     dvoid **bufpp, ub4 **alenpp, ub1 *piecep,
	     dvoid **indpp, ub2 **rcodepp)
{
    phs_t *phs = octxp;
    if (phs->desc_h) {
	*bufpp  = phs->desc_h;
	phs->alen = 0;
    }
    else {
	*bufpp  = SvPVX(phs->sv);
	phs->alen = SvLEN(phs->sv);	/* max buffer size now, actual data len later */
    }
    *alenpp = &phs->alen;
    *indpp  = &phs->indp;
    *rcodepp= &phs->arcode;
    if (DBIS->debug >= 3)
 	fprintf(DBILOGFP, "       dbd_phs_out '%s' (%ld,%ld): len %ld, piece %d%s\n",
		phs->name, iter, index, phs->alen, *piecep,
		(phs->desc_h) ? " via descriptor" : "");
    if (index > 0 || iter > 0)
	croak("Arrays and multiple iterations not currently supported by DBD::Oracle");
    *piecep = OCI_ONE_PIECE;
    return OCI_CONTINUE;
}


/* ------ */


#ifdef moved_to_dbdimp
int
pp_exec_rset(SV *sth, imp_sth_t *imp_sth, phs_t *phs, int pre_exec) 
{
    if (pre_exec) {	/* pre-execute - allocate a statement handle */
	dSP;
	D_imp_dbh_from_sth;
	SV *sth_i;
        HV *init_attr = newHV();
	int count;
	if (DBIS->debug >= 3)
	    fprintf(DBILOGFP, "       bind %s - allocating new sth...\n", phs->name);
	ENTER;
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newRV(DBIc_MY_H(imp_dbh))));
	XPUSHs(sv_2mortal(newRV((SV*)init_attr)));
	PUTBACK;
	count = perl_call_pv("DBI::_new_sth", G_ARRAY);
	SPAGAIN;
	if (count != 2)
	    croak("panic: DBI::_new_sth returned %d values instead of 2", count);
	sth_i = SvREFCNT_inc(POPs);
	sv_setsv(phs->sv, SvREFCNT_inc(POPs));	/* outer handle */
	PUTBACK;
	LEAVE;
	if (DBIS->debug >= 3)
	    fprintf(DBILOGFP, "       bind %s - allocated %s...\n",
		phs->name, neatsvpv(phs->sv, 0));

    }
    else {		/* post-execute - setup the statement handle */
	dTHR;
	SV * sth_csr = phs->sv;
	D_impdata(imp_sth_csr, imp_sth_t, sth_csr);

	if (DBIS->debug >= 3)
	    fprintf(DBILOGFP, "       bind %s - initialising new %s...\n",
		phs->name, neatsvpv(sth_csr,0));

#ifdef OCI_V8_SYNTAX
	/* copy appropriate handles from parent statement	*/
	imp_sth_csr->envhp = imp_sth->envhp;
	imp_sth_csr->errhp = imp_sth->errhp;
	imp_sth_csr->srvhp = imp_sth->srvhp;
	imp_sth_csr->svchp = imp_sth->svchp;

	/* assign statement handle from placeholder descriptor	*/
	imp_sth_csr->stmhp = phs->desc_h;
	imp_sth_csr->disable_finish = 1;  /* else finish core dumps in kpuccan()! */

	/* force stmt_type since OCIAttrGet(OCI_ATTR_STMT_TYPE) doesn't work! */
	imp_sth_csr->stmt_type = OCI_STMT_SELECT;
#else

#endif

	DBIc_IMPSET_on(imp_sth);

	/* set ACTIVE so dbd_describe doesn't do explicit OCI describe */
	DBIc_ACTIVE_on(imp_sth_csr);
	if (!dbd_describe(sth_csr, imp_sth_csr)) {
	    return 0;
	}
    }
    return 1;
}
#endif


int 
dbd_rebind_ph_rset(SV *sth, imp_sth_t *imp_sth, phs_t *phs) 
{
    phs->out_prepost_exec = pp_exec_rset;
    return 2;	/* OCI bind done */
}


/* ------ */

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
    status = OCIAttrSet(phs->desc_h, phs->desc_t,
		    &lobEmpty, 0, OCI_ATTR_LOBEMPTY, imp_sth->errhp);
    if (status != OCI_SUCCESS)
	return oci_error(sth, imp_sth->errhp, status, "OCIAttrSet OCI_ATTR_LOBEMPTY");
    phs->progv = (void*)&phs->desc_h;
    phs->maxlen = sizeof(OCILobLocator*);

    return 1;
}


ub4
ora_blob_read_piece(SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv,
		    long offset, long len, long destoffset)
{
    ub4 loblen = 0;
    ub4 buflen;
    ub4 amtp = 0;
    OCILobLocator *lobl = (OCILobLocator*)fbh->desc_h;
    sword ftype = fbh->ftype;
    sword status;

    if (ftype != 112 && ftype != 113) {
	oci_error(sth, imp_sth->errhp, OCI_ERROR,
	"blob_read not currently supported for non-LOB types with OCI 8 "
	"(but with OCI 8 you can set $dbh->{LongReadLen} to the length you need,"
	"so you don't need to call blob_read at all)");
	SvOK_off(dest_sv);	/* signal error */
	return 0;
    }

    status = OCILobGetLength(imp_sth->svchp, imp_sth->errhp, lobl, &loblen);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCILobGetLength");
	SvOK_off(dest_sv);	/* signal error */
	return 0;
    }

    amtp = (loblen > len) ? len : loblen;
    buflen = amtp;	/* set right semantics for OCILobRead */

    /*
     * We assume our caller has already done the
     * equivalent of the following:
     *		(void)SvUPGRADE(dest_sv, SVt_PV);
     *		SvGROW(dest_sv, buflen+destoffset+1);
     */

    if (loblen > 0) {
        ub1 * bufp = (ub1 *)(SvPVX(dest_sv));
	bufp += destoffset;

	status = OCILobRead(imp_sth->svchp, imp_sth->errhp, lobl,
	    &amtp, 1 + offset, bufp, buflen,
			    0, 0, 0, SQLCS_IMPLICIT);
	if (dbis->debug >= 3)
	    fprintf(DBILOGFP,
		"       OCILobRead field %d %s: LOBlen %ld, LongReadLen %ld, BufLen %ld, Got %ld\n",
		fbh->field_num+1, oci_status_name(status), loblen, imp_sth->long_readlen, buflen, amtp);
	if (status != OCI_SUCCESS) {
	    oci_error(sth, imp_sth->errhp, status, "OCILobRead");
	    SvOK_off(dest_sv);	/* signal error */
	    return 0;
	}
    }
    else {
	assert(amtp == 0);
	if (dbis->debug >= 3)
	    fprintf(DBILOGFP,
		"       OCILobRead field %d %s: LOBlen %ld, LongReadLen %ld, BufLen %ld, Got %ld\n",
		fbh->field_num+1, "SKIPPED", loblen, imp_sth->long_readlen, buflen, amtp);
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
fetch_func_autolob(SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv)
{
    ub4 loblen = 0;
    ub4 buflen;
    ub4 amtp = 0;
    OCILobLocator *lobl = (OCILobLocator*)fbh->desc_h;
    sword status;

    /* this function is not called for NULL lobs */

    status = OCILobGetLength(imp_sth->svchp, imp_sth->errhp, lobl, &loblen);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCILobGetLength");
	return 0;
    }

    amtp = (loblen > imp_sth->long_readlen) ? imp_sth->long_readlen : loblen;
    buflen = amtp;	/* set right semantics for OCILobRead */

    if (loblen > imp_sth->long_readlen) {	/* LOB will be truncated */
	int oraperl = DBIc_COMPAT(imp_sth);
	if (DBIc_has(imp_sth,DBIcf_LongTruncOk) || (oraperl && SvIV(ora_trunc))) {
	    /* user says truncation is ok */
	    /* Oraperl recorded the truncation in ora_errno so we	*/
	    /* so also but only for Oraperl mode handles.		*/
	    if (oraperl)
		sv_setiv(DBIc_ERR(imp_sth), 1406);
	}
	else {
	    char buf[300];
	    sprintf(buf,"fetching field %d of %d. LOB value truncated from %ld to %ld. %s",
		    fbh->field_num+1, DBIc_NUM_FIELDS(imp_sth), amtp, amtp,
		    "DBI attribute LongReadLen too small and/or LongTruncOk not set");
	    oci_error(sth, NULL, OCI_ERROR, buf);
	    sv_setiv(DBIc_ERR(imp_sth), (IV)24345); /* appropriate ORA error number */
	    (void)SvOK_off(dest_sv);
	    return 0;
        }
    }

    (void)SvUPGRADE(dest_sv, SVt_PV);
    SvGROW(dest_sv, buflen+1);

    if (loblen > 0) {
	status = OCILobRead(imp_sth->svchp, imp_sth->errhp, lobl,
	    &amtp, 1, SvPVX(dest_sv), buflen, 0, 0, 0, SQLCS_IMPLICIT);
	if (DBIS->debug >= 3)
	    fprintf(DBILOGFP,
		"       OCILobRead field %d %s: LOBlen %ld, LongReadLen %ld, BufLen %ld, Got %ld\n",
		fbh->field_num+1, oci_status_name(status), loblen, imp_sth->long_readlen, buflen, amtp);
	if (status != OCI_SUCCESS) {
	    oci_error(sth, imp_sth->errhp, status, "OCILobRead");
	    (void)SvOK_off(dest_sv);
	    return 0;
	}
    }
    else {
	assert(amtp == 0);
	if (DBIS->debug >= 3)
	    fprintf(DBILOGFP,
		"       OCILobRead field %d %s: LOBlen %ld, LongReadLen %ld, BufLen %ld, Got %ld\n",
		fbh->field_num+1, "SKIPPED", loblen, imp_sth->long_readlen, buflen, amtp);
    }

    /* tell perl what we've put in its dest_sv */
    SvCUR(dest_sv) = amtp;
    *SvEND(dest_sv) = '\0';
    SvPOK_on(dest_sv);

    return 1;
}


static int
fetch_func_loblocator(SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv)
{
	/*
    OCILobLocator *lobl = (OCILobLocator*)fbh->desc_h;
    sword status;
	*/
    sv_setsv(dest_sv, &sv_no);
    croak("LOB Locators are not directly accessible yet.");
    return 1;
}


int
dbd_describe(SV *h, imp_sth_t *imp_sth)
{
    D_imp_dbh_from_sth;
    I32	long_readlen;
    ub4 num_fields;
    int has_longs = 0;
    int est_width = 0;		/* estimated avg row width (for cache)	*/
    int i = 0;
    sword status;

    if (imp_sth->done_desc)
	return 1;	/* success, already done it */
    imp_sth->done_desc = 1;

    /* ora_trunc is checked at fetch time */
    /* long_readlen:	length for long/longraw (if >0), else 80 (ora app dflt)	*/
    /* Ought to be for COMPAT mode only but was relaxed before LongReadLen existed */
    long_readlen = (SvOK(ora_long) && SvIV(ora_long)>0)
				? SvIV(ora_long) : DBIc_LongReadLen(imp_sth);
    if (long_readlen < 0)		/* trap any sillyness */
	long_readlen = 80;		/* typical oracle app default	*/

    if (imp_sth->stmt_type != OCI_STMT_SELECT) {
	if (DBIS->debug >= 3)
	    fprintf(DBILOGFP, "    dbd_describe skipped for %s\n",
		oci_stmt_type_name(imp_sth->stmt_type));
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    if (DBIS->debug >= 3)
	fprintf(DBILOGFP, "    dbd_describe %s (%s, lb %ld)...\n",
	    oci_stmt_type_name(imp_sth->stmt_type),
	    DBIc_ACTIVE(imp_sth) ? "implicit" : "EXPLICIT", (long)long_readlen);

    /* We know it's a select and we've not got the description yet, so if the	*/
    /* sth is not 'active' (executing) then we need an explicit describe.	*/
    if ( !DBIc_ACTIVE(imp_sth) ) {
	status = OCIStmtExecute(imp_sth->svchp, imp_sth->stmhp, imp_sth->errhp,
		0, 0, 0, 0, OCI_DESCRIBE_ONLY);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status, "OCIStmtExecute/Describe");
	    return 0;
	}
    }

    status = OCIAttrGet_stmhp(imp_sth, &num_fields, 0, OCI_ATTR_PARAM_COUNT);
    if (status != OCI_SUCCESS) {
	oci_error(h, imp_sth->errhp, status, "OCIAttrGet OCI_ATTR_PARAM_COUNT");
	return 0;
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

	status = OCIParamGet(imp_sth->stmhp, OCI_HTYPE_STMT, imp_sth->errhp,
			(dvoid*)&fbh->parmdp, (ub4)i);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status, "OCIParamGet");
	    return 0;
	}

	OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->dbtype, 0, OCI_ATTR_DATA_TYPE);
	OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->dbsize, 0, OCI_ATTR_DATA_SIZE);
	/* OCI_ATTR_PRECISION returns 0 for most types and even some numbers!	*/
	OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->prec,   0, OCI_ATTR_PRECISION);
	OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->scale,  0, OCI_ATTR_SCALE);
	OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->nullok, 0, OCI_ATTR_IS_NULL);
	OCIAttrGet_parmdp(imp_sth, fbh->parmdp, &fbh->name,   &atrlen, OCI_ATTR_NAME);
	fbh->name_sv = newSVpv(fbh->name,atrlen);
	fbh->name    = SvPVX(fbh->name_sv);

	fbh->ftype   = 5;	/* default: return as null terminated string */
	switch (fbh->dbtype) {
	/*	the simple types	*/
	case   1:				/* VARCHAR2	*/
	case  96:				/* CHAR		*/
		fbh->disize = fbh->dbsize;
		fbh->prec   = fbh->disize;
		break;
	case  23:				/* RAW		*/
		fbh->disize = fbh->dbsize * 2;
		fbh->prec   = fbh->disize;
		break;

	case   2:				/* NUMBER	*/
		if (!fbh->prec)	  /* is 0 for FLOATing point	*/
		     fbh->prec = 38;	 	 /* max prec	*/
		fbh->disize = 130+3;	/* worst case! 1**-130	*/
		avg_width = 4;     /* > approx +/- 1_000_000 ?  */
		break;

	case  12:				/* DATE		*/
		/* actually dependent on NLS default date format*/
		fbh->disize = 75;	/* a generous default	*/
		fbh->prec   = fbh->disize;
		break;

	case   8:				/* LONG		*/
		fbh->dbsize = long_readlen;
		fbh->disize = fbh->dbsize;
		fbh->ftype  = 8;
		++has_longs;
		break;
	case  24:				/* LONG RAW	*/
		fbh->dbsize = long_readlen * 2;
		fbh->disize = fbh->dbsize;
		avg_width   = fbh->dbsize;
		fbh->ftype  = 24;
		++has_longs;
		break;

	case  11:				/* ROWID	*/
	case 104:				/* ROWID Desc	*/
		fbh->disize = 20;
		fbh->prec   = fbh->disize;
		break;

	case 112:				/* CLOB		*/
	case 113:				/* BLOB		*/
		fbh->ftype  = fbh->dbtype;
		fbh->disize = fbh->dbsize;
		fbh->fetch_func = (imp_sth->auto_lob)
				? fetch_func_autolob : fetch_func_loblocator;
		fbh->desc_t = OCI_DTYPE_LOB;
		OCIDescriptorAlloc_ok(imp_sth->envhp, &fbh->desc_h, fbh->desc_t);
		break;

	case 105:				/* MLSLABEL	*/
	case 108:				/* User Defined	*/
	case 111:				/* REF		*/
	default:
		/* XXX unhandled type may lead to errors or worse */
		fbh->disize = fbh->dbsize;
		p = "Field %d has an Oracle type (%d) which is not explicitly supported";
		if (DBIS->debug >= 1)
		    fprintf(DBILOGFP, p, i, fbh->dbtype);
		if (dowarn)
		    warn(p, i, fbh->dbtype);
		break;
	}
	if (fbh->ftype == 5)
	    fbh->disize += 1;	/* allow for null terminator */

	/* dbsize can be zero for 'select NULL ...'			*/
	imp_sth->t_dbsize += fbh->dbsize;
	if (!avg_width)
	    avg_width = fbh->dbsize;
	imp_sth->est_width += avg_width;

	if (DBIS->debug >= 2)
	    dbd_fbh_dump(fbh, i, 0);
    }

    /* --- Setup the row cache for this query --- */

    /* number of rows to cache	*/
    if      (SvOK(ora_cache_o)) imp_sth->cache_rows = SvIV(ora_cache_o);
    else if (SvOK(ora_cache))   imp_sth->cache_rows = SvIV(ora_cache);
    else                        imp_sth->cache_rows = imp_dbh->RowCacheSize;
    if (imp_sth->cache_rows >= 0) {	/* set cache size by row count	*/
	ub4 cache_rows = calc_cache_rows(num_fields,
				est_width, imp_sth->cache_rows, has_longs);
	imp_sth->cache_rows = cache_rows;	/* record updated value */
	status = OCIAttrSet(imp_sth->stmhp, OCI_HTYPE_STMT,
		&cache_rows, sizeof(cache_rows), OCI_ATTR_PREFETCH_ROWS, imp_sth->errhp);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status, "OCIAttrSet OCI_ATTR_PREFETCH_ROWS");
	    return 0;
	}
    }
    else {				/* set cache size by memory	*/
	ub4 cache_mem  = -imp_sth->cache_rows;
	ub4 cache_rows = 100000;	/* set high so memory is the limit */
	status = OCIAttrSet(imp_sth->stmhp, OCI_HTYPE_STMT,
		    &cache_rows, sizeof(cache_rows), OCI_ATTR_PREFETCH_ROWS,   imp_sth->errhp)
	      || OCIAttrSet(imp_sth->stmhp, OCI_HTYPE_STMT,
		    &cache_mem,  sizeof(cache_mem), OCI_ATTR_PREFETCH_MEMORY, imp_sth->errhp);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status,
		"OCIAttrSet OCI_ATTR_PREFETCH_ROWS/OCI_ATTR_PREFETCH_MEMORY");
	    return 0;
	}
    }

    imp_sth->long_readlen = long_readlen;
    /* Initialise cache counters */
    imp_sth->in_cache  = 0;
    imp_sth->eod_errno = 0;

    for(i=1; i <= num_fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i-1];
	fb_ary_t  *fb_ary;

	fbh->fb_ary = fb_ary_alloc(fbh->disize+1 /* +1: STRING null terminator */, 1);
	fb_ary = fbh->fb_ary;

	status = OCIDefineByPos(imp_sth->stmhp, &fbh->defnp, imp_sth->errhp, (ub4) i,
	    (fbh->desc_h) ? (dvoid*)&fbh->desc_h : (dvoid*)fb_ary->abuf,
	    (fbh->desc_h) ?                   -1 :         fbh->disize,
	    fbh->ftype,
	    fb_ary->aindp, fb_ary->arlen, fb_ary->arcode, OCI_DEFAULT);
	if (status != OCI_SUCCESS) {
	    oci_error(h, imp_sth->errhp, status, "OCIDefineByPos");
	    return 0;
	}

    }

    if (DBIS->debug >= 3)
	fprintf(DBILOGFP,
	"    dbd_describe'd %d columns (row bytes: %d max, %d est avg, cache: %d)\n",
	(int)num_fields, imp_sth->t_dbsize, imp_sth->est_width, imp_sth->cache_rows);

    return 1;
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
	    fprintf(DBILOGFP, "    dbd_st_fetch %d fields...\n", DBIc_NUM_FIELDS(imp_sth));
	status = OCIStmtFetch(imp_sth->stmhp, imp_sth->errhp, 1, OCI_FETCH_NEXT, OCI_DEFAULT);
    }

    if (status != OCI_SUCCESS) {
	ora_fetchtest = 0;
	if (status == OCI_NO_DATA) {
	    dTHR; 			/* for DBIc_ACTIVE_off	*/
	    DBIc_ACTIVE_off(imp_sth);	/* eg finish		*/
	    if (DBIS->debug >= 3)
		fprintf(DBILOGFP, "    dbd_st_fetch no-more-data\n");
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
	fprintf(DBILOGFP, "    dbd_st_fetch %d fields %s\n",
			num_fields, oci_status_name(status));

    ChopBlanks = DBIc_has(imp_sth, DBIcf_ChopBlanks);

    err = 0;
    for(i=0; i < num_fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	int cache_entry = 0;
	fb_ary_t *fb_ary = fbh->fb_ary;
	int rc = fb_ary->arcode[cache_entry];
	SV *sv = AvARRAY(av)[i]; /* Note: we (re)use the SV in the AV	*/

	if (rc == 1406				/* field was truncated	*/
	    && ora_dbtype_is_long(fbh->dbtype)	/* field is a LONG	*/
	) {
	    int oraperl = DBIc_COMPAT(imp_sth);
	    if (DBIc_has(imp_sth,DBIcf_LongTruncOk) || (oraperl && SvIV(ora_trunc))) {
		/* user says truncation is ok */
		/* Oraperl recorded the truncation in ora_errno so we	*/
		/* so also but only for Oraperl mode handles.		*/
		if (oraperl)
		    sv_setiv(DBIc_ERR(imp_sth), (IV)rc);
		rc = 0;		/* but don't provoke an error here	*/
	    }
	    /* else fall through and let rc trigger failure below	*/
	}

	if (rc == 0) {			/* the normal case		*/
	    if (fbh->fetch_func) {
		if (!fbh->fetch_func(sth, imp_sth, fbh, sv))
		    ++err;	/* fetch_func already called oci_error */
	    }
	    else {
		int datalen = fb_ary->arlen[cache_entry];
		char *p = (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl];
		/* if ChopBlanks check for Oracle CHAR type (blank padded)	*/
		if (ChopBlanks && fbh->dbtype == 96) {
		    while(datalen && p[datalen - 1]==' ')
			--datalen;
		}
		sv_setpvn(sv, p, (STRLEN)datalen);
	    }

	} else if (rc == 1405) {	/* field is null - return undef	*/
	    (void)SvOK_off(sv);

	} else {  /* See odefin rcode arg description in OCI docs	*/
	    char buf[200];
	    char *hint = "";
	    /* These may get more case-by-case treatment eventually.	*/
	    if (rc == 1406) { /* field truncated (see above)  */
		if (!fbh->fetch_func) {
		    /* Copy the truncated value anyway, it may be of use,	*/
		    /* but it'll only be accessible via prior bind_column()	*/
		    sv_setpvn(sv, (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl],
			  fb_ary->arlen[cache_entry]);
		}
		if (ora_dbtype_is_long(fbh->dbtype))	/* double check */
		    hint = ", LongReadLen too small and/or LongTruncOk not set";
	    }
	    else {
		(void)SvOK_off(sv);	/* set field that caused error to undef	*/
	    }
	    ++err;	/* 'fail' this fetch but continue getting fields */
	    /* Some should probably be treated as warnings but	*/
	    /* for now we just treat them all as errors		*/
	    sprintf(buf,"ORA-%05d error on field %d of %d, ora_type %d%s",
			rc, i+1, num_fields, fbh->dbtype, hint);
	    oci_error(sth, imp_sth->errhp, OCI_ERROR, buf);
	}

	if (DBIS->debug >= 5)
	    fprintf(DBILOGFP, "        %d (rc=%d): %s\n",
		i, rc, neatsvpv(sv,0));
    }

    return (err) ? Nullav : av;
}


ub4
ora_parse_uid(imp_dbh, uidp, pwdp)
    imp_dbh_t *imp_dbh;
    char **uidp;
    char **pwdp;
{
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
    OCIAttrSet(imp_dbh->authp, OCI_HTYPE_SESSION,
	       *uidp, strlen(*uidp),
	       (ub4) OCI_ATTR_USERNAME, imp_dbh->errhp);
    OCIAttrSet(imp_dbh->authp, OCI_HTYPE_SESSION,
	       (strlen(*pwdp)) ? *pwdp : NULL, strlen(*pwdp),
	       (ub4) OCI_ATTR_PASSWORD, imp_dbh->errhp);
    return OCI_CRED_RDBMS;
}


int
ora_db_reauthenticate(dbh, imp_dbh, uid, pwd)
    SV *dbh;
    imp_dbh_t *imp_dbh;
    char *	uid;
    char *	pwd;
{
    sword status;
    /* XXX should possibly create new session before ending the old so	*/
    /* that if the new one can't be created, the old will still work.	*/
    OCISessionEnd (imp_dbh->svchp, imp_dbh->errhp,
		   imp_dbh->authp, OCI_DEFAULT);
    status = OCISessionBegin( imp_dbh->svchp, imp_dbh->errhp, imp_dbh->authp,
		       ora_parse_uid(imp_dbh, &uid, &pwd), (ub4) OCI_DEFAULT);
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
		while(*src && (isALNUM(*src) || *src=='.'))
		    ++src;
		*len = src - start;
		if (copy) {
		    p = alloc_via_sv(*len, 0, 1);
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
    SV *sql_select;
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
    OCIParam *parmhp = NULL, *collisthd = NULL;
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
			"LOB refetch attempted for unsupported statement type");
    }
    if (!tablename)
	return oci_error(sth, errhp, OCI_ERROR,
		"Unable to parse table name for LOB refetch");

    OCIHandleAlloc_ok(imp_sth->envhp, &dschp, OCI_HTYPE_DESCRIBE);
    status = OCIDescribeAny(imp_sth->svchp, errhp, tablename, strlen(tablename),
		OCI_OTYPE_NAME, 1, OCI_PTYPE_TABLE, dschp);
    if (status != OCI_SUCCESS) {
	OCIHandleFree(dschp, OCI_HTYPE_DESCRIBE);
	return oci_error(sth, errhp, status, "OCIDescribeAny/LOB refetch");
    }

    status =   OCIAttrGet(dschp,  OCI_HTYPE_DESCRIBE,
				&parmhp, 0, OCI_ATTR_PARAM, errhp)
	    || OCIAttrGet(parmhp, OCI_DTYPE_PARAM,
				&numcols, 0, OCI_ATTR_NUM_COLS, errhp)
	    || OCIAttrGet(parmhp, OCI_DTYPE_PARAM,
				&collisthd, 0, OCI_ATTR_LIST_COLUMNS, errhp);
    if (status != OCI_SUCCESS) {
	OCIHandleFree(dschp, OCI_HTYPE_DESCRIBE);
	return oci_error(sth, errhp, status, "OCIDescribeAny/OCIAttrGet/LOB refetch");
    }
    if (DBIS->debug >= 3)
	fprintf(DBILOGFP, "       lob refetch from table %s, %d columns:\n",
	    tablename, numcols);

    for (i = 1; i <= numcols; i++) {
	OCIParam *colhd;
	ub2 col_dbtype;
	char *col_name;
	ub4  col_name_len;
        if ((status=OCIParamGet(collisthd, OCI_DTYPE_PARAM, errhp, (dvoid**)&colhd, i)))
	    break;
        if ((status=OCIAttrGet(colhd, OCI_DTYPE_PARAM, &col_dbtype, 0,
              OCI_ATTR_DATA_TYPE, errhp)))
                break;
        if ((status=OCIAttrGet(colhd, OCI_DTYPE_PARAM, &col_name, &col_name_len,
              OCI_ATTR_NAME, errhp)))
                break;
	if (DBIS->debug >= 3)
	    fprintf(DBILOGFP, "       lob refetch table col %d: '%.*s' otype %d\n",
		(int)i, (int)col_name_len,col_name, col_dbtype);
	if (col_dbtype != SQLT_CLOB && col_dbtype != SQLT_BLOB)
	    continue;
	if (!lob_cols_hv)
	    lob_cols_hv = newHV();
	sv = newSViv(col_dbtype);
	(void)sv_setpvn(sv, col_name, col_name_len);
	(void)SvIOK_on(sv);   /* what a wonderful hack! */
	hv_store(lob_cols_hv, col_name,col_name_len, sv,0);
    }
    if (status != OCI_SUCCESS) {
	OCIHandleFree(dschp, OCI_HTYPE_DESCRIBE);
	return oci_error(sth, errhp, status,
		    "OCIDescribeAny/OCIParamGet/OCIAttrGet/LOB refetch");
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
    lr->fbh_ary = alloc_via_sv(sizeof(imp_fbh_t) * HvFILL(lob_cols_hv)+1,
			&lr->fbh_ary_sv, 0);

    sql_select = newSVpv("select ",0);

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
		if (SvCUR(phs->ora_field) != SvCUR(sv)
		|| ibcmp( SvPV(phs->ora_field,na), SvPV(sv,na), SvCUR(sv) ) )
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
			fprintf(DBILOGFP,
			"       both %s and %s have type %d - ambiguous\n",
				SvPV(sv,na), SvPV(sv_other,na), (int)SvIV(sv_other));
		    Safefree(lr);
		    return oci_error(sth, errhp, OCI_ERROR,
			"Need bind_param(..., { ora_field=>... }) attribute to identify table LOB field names");
		}
	    }
	    matched = 1;
	    sprintf(sql_field, "%s%s \"%s\"",
		(SvCUR(sql_select)>7)?", ":"", p, &phs->name[1]);
	    sv_catpv(sql_select, sql_field);
	    if (DBIS->debug >= 3)
		fprintf(DBILOGFP,
		"       lob refetch %s param: otype %d, matched field '%s' %s(%s)\n",
		    phs->name, phs->ftype, p,
		    (phs->ora_field) ? "by name " : "by type ", sql_field);
	    hv_delete(lob_cols_hv, p, i, 0);
	    fbh = &lr->fbh_ary[lr->num_fields++];
	    fbh->name   = phs->name;
	    fbh->dbtype = phs->ftype;
	    fbh->ftype  = fbh->dbtype;
	    fbh->disize = 99;
	    fbh->desc_t = OCI_DTYPE_LOB;
	    OCIDescriptorAlloc_ok(imp_sth->envhp, &fbh->desc_h, fbh->desc_t);
	    break;	/* we're done with this placeholder now	*/
	}
	if (!matched) {
	    ++unmatched_params;
	    if (DBIS->debug >= 3)
		fprintf(DBILOGFP,
		    "       lob refetch %s param: otype %d, UNMATCHED\n",
		    phs->name, phs->ftype);
	}
    }
    if (unmatched_params) {
        Safefree(lr);
	return oci_error(sth, errhp, OCI_ERROR,
	    "Can't match some parameters to LOB fields in the table, check type and name");
    }

    sv_catpv(sql_select, " from ");
    sv_catpv(sql_select, tablename);
    sv_catpv(sql_select, " where rowid = :rid for update"); /* get row with lock */
    if (DBIS->debug >= 3)
	fprintf(DBILOGFP,
	    "       lob refetch sql: %s\n", SvPVX(sql_select));
    lr->sql_select = sql_select;

    lr->stmthp = NULL;
    lr->bindhp = NULL;
    lr->rowid  = NULL;
    lr->parmdp_tmp = NULL;
    lr->parmdp_lob = NULL;


    OCIHandleAlloc_ok(imp_sth->envhp, &lr->stmthp, OCI_HTYPE_STMT);
    status = OCIStmtPrepare(lr->stmthp, errhp,
		(text*)SvPVX(sql_select), SvCUR(sql_select), OCI_NTV_SYNTAX, OCI_DEFAULT);
    if (status != OCI_SUCCESS)
	return oci_error(sth, errhp, status, "OCIStmtPrepare/LOB refetch");

    /* bind the rowid input */
    OCIDescriptorAlloc_ok(imp_sth->envhp, &lr->rowid, OCI_DTYPE_ROWID);
    status = OCIBindByName(lr->stmthp, &lr->bindhp, errhp, (text*)":rid", 4,
           &lr->rowid, sizeof(OCIRowid*), SQLT_RDD, 0,0,0,0,0, OCI_DEFAULT);
    if (status != OCI_SUCCESS)
	return oci_error(sth, errhp, status, "OCIBindByPos/LOB refetch");

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
	    fprintf(DBILOGFP,
		"       lob refetch %d for '%s' param: ftype %d setup\n",
		(int)i+1,fbh->name, fbh->dbtype);
	status = OCIDefineByPos(lr->stmthp, &defnp, errhp, i+1,
			 &fbh->desc_h, -1, fbh->ftype, 0,0,0, OCI_DEFAULT);
	if (status != OCI_SUCCESS)
	    return oci_error(sth, errhp, status, "OCIDefineByPos/LOB refetch");
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
    ub4 rowid_iter = 0;
    lob_refetch_t *lr;

    if (row_count == 0)
	return 1;	/* nothing to do */
    if (row_count  > 1)
	return oci_error(sth, errhp, OCI_ERROR, "LOB refetch attempted for multiple rows");

    if (!imp_sth->lob_refetch)
	if (!init_lob_refetch(sth, imp_sth))
	    return 0;	/* init_lob_refetch already called oci_error */
    lr = imp_sth->lob_refetch;

    status = OCIAttrGet_stmhp(imp_sth, (dvoid**)lr->rowid, &rowid_iter, OCI_ATTR_ROWID);
    if (status != OCI_SUCCESS)
	return oci_error(sth, errhp, status, "OCIAttrGet OCI_ATTR_ROWID /LOB refetch");

    status = OCIStmtExecute(imp_sth->svchp, lr->stmthp, errhp,
		1, 0, NULL, NULL, OCI_DEFAULT);	/* execute and fetch */
    if (status != OCI_SUCCESS)
	return oci_error(sth, errhp, status, "OCIStmtExecute/LOB refetch");

    for(i=0; i < lr->num_fields; ++i) {
	imp_fbh_t *fbh = &lr->fbh_ary[i];
	phs_t *phs = (phs_t*)fbh->special;
	ub4 amtp = SvCUR(phs->sv);
	if (DBIS->debug >= 3)
	    fprintf(DBILOGFP,
		"       lob refetch %d for '%s' param: ftype %d, len %ld\n",
		i+1,fbh->name, fbh->dbtype, amtp);
	if (amtp > 0) {	/* since amtp & OCI_ONE_PIECE fail (OCI 8.0.4) */
	    status = OCILobWrite(imp_sth->svchp, errhp,
		    fbh->desc_h, &amtp, 1, SvPVX(phs->sv), amtp, OCI_ONE_PIECE,
		    0,0, 0,SQLCS_IMPLICIT);
	}
	else {
	    status = OCILobTrim(imp_sth->svchp, errhp, fbh->desc_h, 0);
	}
	if (status != OCI_SUCCESS) {
	    return oci_error(sth, errhp, status, "OCILobTrim/OCILobWrite/LOB refetch");
	}
    }

    return 1;
}

void
ora_free_lob_refetch(SV *sth, imp_sth_t *imp_sth)
{
    lob_refetch_t *lr = imp_sth->lob_refetch;
    int i;
    sword status = OCIHandleFree(imp_sth->stmhp, OCI_HTYPE_STMT);
    if (status != OCI_SUCCESS)
	oci_error(sth, imp_sth->errhp, status, "ora_free_lob_refetch/OCIHandleFree");
    for(i=0; i < lr->num_fields; ++i) {
	imp_fbh_t *fbh = &lr->fbh_ary[i];
	ora_free_fbh_contents(fbh);
    }
    sv_free(lr->sql_select);
    sv_free(lr->fbh_ary_sv);
    Safefree(imp_sth->lob_refetch);
    imp_sth->lob_refetch = NULL;
}



#ifdef OCI8_RSET_TEST_CODE

#define VARCHAR2_TYPE            1
#define NUMBER_TYPE              2
#define INT_TYPE                 3
#define FLOAT_TYPE               4
#define STRING_TYPE              5
#define ROWID_TYPE              11
#define DATE_TYPE               12
#define LONG_RAW                24
#define LONG_VARRAW             95

/*
 * Macro and Other Definitions
 */
#define UNREFERENCED_PARAMETER(x) ((x)=(x))
#define NO_DATA_FOUND                   1403
#define OCI8_INITIALIZED                1
#define OCI8_SERVER_ATTACHED    2
#define OCI8_SESSION_BEGAN              3
#define BOOL                                    short int
#define UINT                                    unsigned int

/*
 * Oracle 8 OCI Global Variables for this Sample
 */
OCIEnv          *or8EnvHandle;
OCIError        *or8ErrorHandle;
OCIStmt         *or8StmtHandle;
OCIStmt         *or8CursorStmtHandle;
OCISvcCtx       *or8SrcHandle;

typedef dvoid * PDV;

/*
 * Function Prototypes
 */

BOOL oci8Error (sb2 sb2ErrorCode);

/*****************************************************************/
BOOL oci8Error (sb2 sb2ErrorCode)
{
        text errbuf[512];
        sb4 errcode;
        switch (sb2ErrorCode) {
                case OCI_SUCCESS:
                        break;
                case OCI_SUCCESS_WITH_INFO:
                        printf ("Error - OCI_SUCCESS_WITH_INFO\n");
                        break;
                case OCI_NEED_DATA:
                        printf ("Error - OCI_NEED_DATA\n");
                        break;
                case OCI_NO_DATA:
                        printf ("Error - OCI_NO_DATA\n");
                        break;
                case OCI_ERROR:
                        OCIErrorGet ((dvoid *) or8ErrorHandle, (ub4) 1, (OraText *)
                                NULL, &errcode, errbuf, (ub4) sizeof(errbuf),
                                (ub4) OCI_HTYPE_ERROR);
                        printf ("Error - %s\n", errbuf);
                        break;
                case OCI_INVALID_HANDLE:
                        printf ("Error - OCI_INVALID_HANDLE\n");
                        break;
                case OCI_STILL_EXECUTING:
                        printf ("Error - OCI_STILL_EXECUTE\n");
                        break;
                case OCI_CONTINUE:
                        printf ("Error - OCI_CONTINUE\n");
                        break;
                default:
                        break;
        }
        return ((sb2ErrorCode==OCI_SUCCESS) ? FALSE : TRUE );
}

/*****************************************************************/

int rset_main (imp_dbh_t *imp_dbh)
{
	sword rc;
        static unsigned char *szPLSQLBlock = (unsigned char *)
"BEGIN RefTest.GetEmpData (:DEPTNO , :empCursor); END;";

        static char *pszUserName   = "scott";
        static char *pszPassword   = "tiger";
        static char *pszConnection = "firstdb";

        sb2                     rv;
        int                     bv_deptno = 10;
        char            bv_ename[40];
        int                     bv_ename_len = 40;
        OCIBind         *ptrBindHandle1;
        OCIBind         *ptrBindHandle2;
        OCIDefine       *or8Define1;
        char *pszBindVarName;
        char *pszBindVarName2;

        /* oci8Connect(pszUserName, pszPassword, pszConnection); */
         or8ErrorHandle= imp_dbh->errhp;
         or8SrcHandle  = imp_dbh->svchp;
         or8EnvHandle  = imp_dbh->envhp;

        /*
         * Allocate Stmt handle
         */
        rv = OCIHandleAlloc ((PDV) or8EnvHandle, (PDV*) &or8StmtHandle,
                                OCI_HTYPE_STMT, 0, (PDV*) 0);
        if (rv) { exit(1); }

        /*
         * Allocate Stmt handle for cursor resultset
         */
        rv = OCIHandleAlloc ((PDV) or8EnvHandle, (PDV*) &or8CursorStmtHandle,
                                OCI_HTYPE_STMT, 0, (PDV*) 0);
        if (rv) { exit(1); }

        /*
         * Prepare statement
         */
        rv = OCIStmtPrepare (or8StmtHandle,
                                                or8ErrorHandle,
                                                (OraText *) szPLSQLBlock,
                                                (ub4)strlen((char *)szPLSQLBlock),
                                                (ub4)OCI_NTV_SYNTAX,
                                                (ub4)OCI_DEFAULT);
        if (rv) { puts("OCIStmtPrepare"); oci8Error (rv); exit(1); }

{ ub2 stmt_type = 0;
	OCIAttrGet(or8StmtHandle, OCI_HTYPE_STMT, &stmt_type, 0, OCI_ATTR_STMT_TYPE, or8ErrorHandle);
warn("stmt_type=%d\n",stmt_type);
}

        pszBindVarName = ":DEPTNO";

        rv = OCIBindByName( or8StmtHandle,
                                                (OCIBind **)&ptrBindHandle1,
                                                or8ErrorHandle,
                                                (OraText *) pszBindVarName,
                                                -1, /* (sb4) strlen(pszBindVarName), */
                                                (dvoid *) &bv_deptno,
                                                (sb4) sizeof (bv_deptno),
                                                (ub2) SQLT_INT,
                                                (dvoid *) 0,
                                                (ub2 *) 0,
                                                (ub2 *) 0,
                                                (ub4) 0,
                                                (ub4 *)0,
                                                (ub4) OCI_DEFAULT);
        if (rv) { puts("OCIBindByName"); oci8Error (rv); exit(1); }

        pszBindVarName2 = ":empCursor";
        rv =  OCIBindByName(or8StmtHandle,
                                                (OCIBind **)&ptrBindHandle2,
                                                or8ErrorHandle,
                                                (OraText *) pszBindVarName2,
                                                -1, /* (sb4) strlen(pszBindVarName2), */
                                                (dvoid *)&or8CursorStmtHandle,
                                                (sb4) 0,
                                                SQLT_RSET,
                                                (dvoid *) 0,
                                                (ub2 *) 0,
                                                (ub2 *) 0,
                                                (ub4) 0,
                                                (ub4 *)0,
                                                (ub4) OCI_DEFAULT);
        if (rv) { puts("OCIBindByName 2"); oci8Error (rv); exit(1); }

        rv = OCIStmtExecute(or8SrcHandle,
                                                or8StmtHandle,
                                                or8ErrorHandle,
                                                (ub4) 1,
                                                (ub4) 0,
                                                (CONST OCISnapshot *) NULL,
                                                (OCISnapshot *) NULL,
                                                OCI_DEFAULT);
        if (rv) { puts("execute"); oci8Error (rv); exit(1); }

        rv = OCIDefineByPos(or8CursorStmtHandle,
                                                (OCIDefine **)&or8Define1,
                                                or8ErrorHandle,
                                                (ub4) 1,
                                                (dvoid *)&bv_ename,
                                                (sb4) bv_ename_len,
                                                SQLT_STR,
                                                (dvoid *)0,
                                                0, 0,
                                                OCI_DEFAULT);

        if (rv) { puts("OCIDefineByPos post execute"); oci8Error (rv); exit(1); }

        rc = OCIStmtFetch(or8CursorStmtHandle, or8ErrorHandle, 1, 0, 0);
        while (rc == OCI_SUCCESS) {
                printf("[%s]\n", bv_ename);
                rc = OCIStmtFetch(or8CursorStmtHandle, or8ErrorHandle, 1, 0, 0);
        }
	if (rc != OCI_NO_DATA) {
		oci8Error (rc);
		exit(1);
	}

        oci8Error (OCIHandleFree ((PDV) or8StmtHandle, OCI_HTYPE_STMT));
        return 1;
}
#endif /* OCI8_RSET_TEST_CODE */


#endif
