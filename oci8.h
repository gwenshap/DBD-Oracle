/*
   $Id: oci8.h,v 1.3 1998/12/02 02:48:32 timbo Exp $

   Copyright (c) 1998  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#define OCIAttrGet_stmhp(imp_sth, p, l, a) \
	OCIAttrGet(imp_sth->stmhp, OCI_HTYPE_STMT, (dvoid*)(p), (l), (a), imp_sth->errhp)
#define OCIAttrGet_parmdp(imp_sth, parmdp, p, l, a) \
	OCIAttrGet(parmdp, OCI_DTYPE_PARAM, (dvoid*)(p), (l), (a), imp_sth->errhp)

#define OCIHandleAlloc_ok(envhp, p, t) \
	if (OCIHandleAlloc((envhp), (dvoid**)(p), (t), 0, 0)==OCI_SUCCESS) ; \
	else croak("OCIHandleAlloc (type %d) failed",t)
#define OCIDescriptorAlloc_ok(envhp, p, t) \
	if (OCIDescriptorAlloc((envhp), (dvoid**)(p), (t), 0, 0)==OCI_SUCCESS) ; \
	else croak("OCIDescriptorAlloc (type %d) failed",t)


static char *
oci_status_name(status)
    int status;
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


static char *
oci_stmt_type_name(stmt_type)
    int stmt_type;
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


static int
oci_error(h, errhp, status, what)
    SV *h;
    OCIError *errhp;
    sword status;
    char *what;
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
	    if (dbis->debug >= 4 || recno>1/*XXX temp*/)
		fprintf(DBILOGFP, "OCIErrorGet after %s (err rec %ld = %s): %d, %ld: %s\n",
		    what, (long)recno, oci_status_name(eg_status),
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


int fetch_func_lob(sth, imp_sth, fbh, dest_sv)
    SV *sth;
    imp_sth_t *imp_sth;
    imp_fbh_t *fbh;
    SV *dest_sv;
{
    char *hint = "";
    ub4 loblen = 0;
    ub4 getlen;
    ub4 amtp = 0;
    OCILobLocator *lobl = (OCILobLocator*)fbh->desc_h;
    sword status;

    status = OCILobGetLength(imp_sth->svchp, imp_sth->errhp, lobl, &loblen);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCILobGetLength");
	return 0;
    }

    getlen = (loblen > imp_sth->long_readlen) ? imp_sth->long_readlen : loblen;
    amtp = getlen;	/* set right semantics for OCILobRead */

    SvUPGRADE(dest_sv, SVt_PV);
    SvGROW(dest_sv, getlen+1);

    status = OCILobRead(imp_sth->svchp, imp_sth->errhp, lobl,
	&amtp, 1, SvPVX(dest_sv), getlen, 0, 0, 0, SQLCS_IMPLICIT);
    if (dbis->debug >= 3)
	fprintf(DBILOGFP, "       OCILobRead %s: %ld/%ld/%ld\n",
	    oci_status_name(status), getlen, amtp, imp_sth->long_readlen);

    if (status == OCI_NEED_DATA) {		/* LOB was truncated	*/
	int oraperl = DBIc_COMPAT(imp_sth);
	if (DBIc_has(imp_sth,DBIcf_LongTruncOk) || (oraperl && SvIV(ora_trunc))) {
	    /* user says truncation is ok */
	    /* Oraperl recorded the truncation in ora_errno so we	*/
	    /* so also but only for Oraperl mode handles.		*/
	    if (oraperl)
		sv_setiv(DBIc_ERR(imp_sth), 1406);
	    status = OCI_SUCCESS;    /* but don't provoke an error here	*/
	}
	else {
	    /* else fall through and let status trigger failure below	*/
	    hint = ", LongReadLen too small and/or LongTruncOk not set";
        }
    }
    if (status != OCI_SUCCESS) {
	char buf[300];
	sprintf(buf,"OCILobRead of %ld bytes on field %d of %d%s",
		getlen, fbh->field_num+1, DBIc_NUM_FIELDS(imp_sth), hint);
	oci_error(sth, imp_sth->errhp, status, buf);
	return 0;
    }
    /* tell perl what we've put in its dest_sv */
    SvCUR(dest_sv) = amtp;
    *SvEND(dest_sv) = '\0';
    SvPOK_on(dest_sv);

    return 1;
}


int
dbd_describe(h, imp_sth)
    SV *h;
    imp_sth_t *imp_sth;
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
	if (dbis->debug >= 2)
	    fprintf(DBILOGFP, "    dbd_describe skipped for %s\n",
		oci_stmt_type_name(imp_sth->stmt_type));
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    if (dbis->debug >= 2)
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
		break;
	case  23:				/* RAW		*/
		fbh->disize = fbh->dbsize * 2;
		break;

	case   2:				/* NUMBER	*/
		/* actually dependent on scale & precision	*/
		if (!fbh->scale && !fbh->prec)	  /* always 0!	*/
		     fbh->disize = 38 + 2;	  /* max prec	*/
		else fbh->disize = fbh->prec + 2; /* sign + dot	*/
		avg_width = 4;     /* > approx +/- 1_000_000 ?  */
		break;

	case  12:				/* DATE		*/
		/* actually dependent on NLS default date format*/
		fbh->disize = 75;	/* a generous default	*/
		break;

	case   8:				/* LONG		*/
		fbh->disize = fbh->dbsize;
		fbh->dbsize = long_readlen;
		fbh->ftype  = 8;
		break;
	case  24:				/* LONG RAW	*/
		avg_width   = fbh->dbsize;
		fbh->disize = fbh->dbsize;
		fbh->dbsize = long_readlen * 2;
		fbh->ftype  = 24;
		break;

	case  11:				/* ROWID	*/
		fbh->disize = 20;
		break;
	case 104:				/* ROWID Desc	*/
		fbh->disize = 20;
		break;

	case 112:				/* CLOB		*/
	case 113:				/* BLOB		*/
		fbh->ftype  = fbh->dbtype;
		fbh->disize = fbh->dbsize;
		fbh->fetch_func = fetch_func_lob;
		fbh->desc_t = OCI_DTYPE_LOB;
	        OCIDescriptorAlloc_ok(imp_dbh->envhp, &fbh->desc_h, fbh->desc_t);
		break;

	case 105:				/* MLSLABEL	*/
	case 108:				/* User Defined	*/
	case 111:				/* REF		*/
	default:
		fbh->disize = fbh->dbsize;
		/* XXX unhandled type may lead to core dump */
		break;
	}
	if (fbh->ftype == 5)
	    fbh->disize += 1;	/* allow for null terminator */

	/* dbsize can be zero for 'select NULL ...'			*/
	imp_sth->t_dbsize += fbh->dbsize;
	if (!avg_width)
	    avg_width = fbh->dbsize;
	imp_sth->est_width += avg_width;

	if (dbis->debug >= 2)
	    fbh_dump(fbh, i, 0);
    }

    /* --- Setup the row cache for this query --- */

    /* number of rows to cache	*/
    if      (SvOK(ora_cache_o)) imp_sth->cache_rows = SvIV(ora_cache_o);
    else if (SvOK(ora_cache))   imp_sth->cache_rows = SvIV(ora_cache);
    else                        imp_sth->cache_rows = imp_dbh->RowCacheSize;
    if (imp_sth->cache_rows >= 0) {	/* set cache size by row count	*/
	ub4 cache_rows;
	cache_rows = calc_cache_rows(num_fields, est_width, imp_sth->cache_rows, has_longs);
	imp_sth->cache_rows = cache_rows;
	OCIAttrSet(imp_sth->stmhp, OCI_HTYPE_STMT,
		&cache_rows, 0, OCI_ATTR_PREFETCH_ROWS, imp_dbh->errhp);
    }
    else {				/* set cache size by memory	*/
	ub4 cache_rows = 100000;
	ub4 cache_mem  = -imp_sth->cache_rows;
	OCIAttrSet(imp_sth->stmhp, OCI_HTYPE_STMT,
		&cache_rows, 0, OCI_ATTR_PREFETCH_ROWS, imp_dbh->errhp);
	OCIAttrSet(imp_sth->stmhp, OCI_HTYPE_STMT,
		&cache_mem,  0, OCI_ATTR_PREFETCH_MEMORY, imp_dbh->errhp);
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

    if (dbis->debug >= 2)
	fprintf(DBILOGFP,
	"    dbd_describe'd %d columns (row bytes: %d max, %d est avg, cache: %d)\n",
	(int)num_fields, imp_sth->t_dbsize, imp_sth->est_width, imp_sth->cache_rows);

    return 1;
}


AV *
dbd_st_fetch(sth, imp_sth)
    SV *	sth;
    imp_sth_t *imp_sth;
{
    sword status;
    int num_fields;
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
	if (dbis->debug >= 3)
	    fprintf(DBILOGFP, "    dbd_st_fetch %d fields...\n", DBIc_NUM_FIELDS(imp_sth));
	status = OCIStmtFetch(imp_sth->stmhp, imp_sth->errhp, 1, OCI_FETCH_NEXT, OCI_DEFAULT);
    }
    if (status != OCI_SUCCESS) {
	ora_fetchtest = 0;
	if (status == OCI_NO_DATA) {
	    if (dbis->debug >= 2)
		fprintf(DBILOGFP, "    dbd_st_fetch no-more-data\n");
	    return Nullav;
	}
	if (status != OCI_SUCCESS_WITH_INFO) {
	    oci_error(sth, imp_sth->errhp, status, "OCIStmtFetch");
	    return Nullav;
	}
	/* for OCI_SUCCESS_WITH_INFO we fall through and let the	*/
	/* per-field rcode value be dealt with as we fetch the data	*/
    }

    av = DBIS->get_fbav(imp_sth);
    num_fields = AvFILL(av)+1;

    if (dbis->debug >= 3)
	fprintf(DBILOGFP, "    dbd_st_fetch %d fields %s:\n",
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
	    && dbtype_is_long(fbh->dbtype)	/* field is a LONG	*/
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
	    if (fbh->ftype == 5) {
		int datalen = fb_ary->arlen[cache_entry];
		char *p = (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl];
		/* if ChopBlanks check for Oracle CHAR type (blank padded)	*/
		if (ChopBlanks && fbh->dbtype == 96) {
		    while(datalen && p[datalen - 1]==' ')
			--datalen;
		}
		sv_setpvn(sv, p, (STRLEN)datalen);
	    }
	    else if (fbh->desc_h) {
		if (!fbh->fetch_func(sth, imp_sth, fbh, sv))
		    ++err;	/* fetch_func already called oci_error */
	    }
	    else {
		++err;
		oci_error(sth, imp_sth->errhp, OCI_ERROR, "panic: unhandled field type");
	    }

	} else if (rc == 1405) {	/* field is null - return undef	*/
	    (void)SvOK_off(sv);

	} else {  /* See odefin rcode arg description in OCI docs	*/
	    char buf[200];
	    char *hint = "";
	    /* These may get more case-by-case treatment eventually.	*/
	    if (rc == 1406 && fbh->ftype == 5) { /* field truncated (see above)  */
		/* Copy the truncated value anyway, it may be of use,	*/
		/* but it'll only be accessible via prior bind_column()	*/
		sv_setpvn(sv, (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl],
			  fb_ary->arlen[cache_entry]);
		if (dbtype_is_long(fbh->dbtype))	/* double check */
		    hint = ", LongReadLen too small and/or LongTruncOk not set";
	    }
	    else {
		SvOK_off(sv);	/* set field that caused error to undef	*/
	    }
	    ++err;	/* 'fail' this fetch but continue getting fields */
	    /* Some should probably be treated as warnings but	*/
	    /* for now we just treat them all as errors		*/
	    sprintf(buf,"ORA-%05d error on field %d of %d, ora_type %d%s",
			rc, i+1, num_fields, fbh->dbtype, hint);
	    oci_error(sth, imp_sth->errhp, OCI_ERROR, buf);
	}

	if (dbis->debug >= 3)
	    fprintf(DBILOGFP, "        %d (rc=%d): %s\n",
		i, rc, neatsvpv(sv,0));
    }

    return (err) ? Nullav : av;
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
		while(*src && (isALPHA(*src) || *src=='.'))
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
    if (dbis->debug >= 3)
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
	if (dbis->debug >= 3)
	    fprintf(DBILOGFP, "       lob refetch table col %d: '%.*s' otype %d\n",
		(int)i, (int)col_name_len,col_name, col_dbtype);
	if (col_dbtype != SQLT_CLOB && col_dbtype != SQLT_BLOB)
	    continue;
	if (!lob_cols_hv)
	    lob_cols_hv = newHV();
	sv = newSViv(col_dbtype);
	sv_setpvn(sv, col_name, col_name_len);
	SvIOK_on(sv);   /* what a wonderful hack! */
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

    /*	our bind params are in imp_sth->all_params_hv
	our table cols are in lob_cols_hv
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
	    if (SvIV(sv) != phs->ftype)
		continue;
	    matched = 1;
	    sprintf(sql_field, "%s%s \"%s\"",
		(SvCUR(sql_select)>7)?", ":"", p, &phs->name[1]);
	    sv_catpv(sql_select, sql_field);
	    if (dbis->debug >= 3)
		fprintf(DBILOGFP,
		"       lob refetch %s param: otype %d, matched field '%s' (%s)\n",
		    phs->name, phs->ftype, p, sql_field);
	    hv_delete(lob_cols_hv, p, i, 0);
	    fbh = &lr->fbh_ary[lr->num_fields++];
	    fbh->name   = phs->name;
	    fbh->dbtype = phs->ftype;
	    fbh->ftype  = fbh->dbtype;
	    fbh->disize = 99;
	    fbh->desc_t = OCI_DTYPE_LOB;
	    OCIDescriptorAlloc_ok(imp_sth->envhp, &fbh->desc_h, fbh->desc_t);
	    break;
	}
	if (!matched) {
	    ++unmatched_params;
	    if (dbis->debug >= 3)
		fprintf(DBILOGFP,
		    "       lob refetch %s param: otype %d, UNMATCHED\n",
		    phs->name, phs->ftype);
	}
    }
    if (unmatched_params) {
	/* not all the lob columns in the table were accounted for */
        Safefree(lr);
	return oci_error(sth, errhp, OCI_ERROR,
	    "Can't refetch LOBs, LOB column mismatch (too many or wrong type)");
    }

    sv_catpv(sql_select, " from ");
    sv_catpv(sql_select, tablename);
    sv_catpv(sql_select, " where rowid = :rid");
    if (dbis->debug >= 3)
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
	if (dbis->debug >= 3)
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


static int
post_execute_lobs(sth, imp_sth, row_count)	/* XXX leaks handles on error */
    SV *	sth;
    imp_sth_t *imp_sth;
    ub4 row_count;
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
	if (dbis->debug >= 3)
	    fprintf(DBILOGFP,
		"       lob refetch %d for '%s' param: ftype %d, len %ld\n",
		i+1,fbh->name, fbh->dbtype, amtp);
	status = OCILobWrite(imp_sth->svchp, errhp,
		fbh->desc_h, &amtp, 1, SvPVX(phs->sv), amtp, OCI_ONE_PIECE,
		0,0, 0,SQLCS_IMPLICIT);
	if (status != OCI_SUCCESS) {
	    oci_error(sth, errhp, status, "OCILobWrite");
	    return -2;
	}
    }

    return 1;
}

static void
ora_free_lob_refetch(imp_sth_t *imp_sth)
{
    lob_refetch_t *lr = imp_sth->lob_refetch;
    int i;
    for(i=0; i < lr->num_fields; ++i) {
	imp_fbh_t *fbh = &lr->fbh_ary[i];
	ora_free_fbh_contents(fbh);
    }
    sv_free(lr->sql_select);
    sv_free(lr->fbh_ary_sv);
    Safefree(imp_sth->lob_refetch);
    imp_sth->lob_refetch = NULL;
}
