/*
   $Id: dbdimp.c,v 1.31 1997/06/14 17:42:12 timbo Exp $

   Copyright (c) 1994,1995  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#include "Oracle.h"


DBISTATE_DECLARE;

static SV *ora_long;
static SV *ora_trunc;
static SV *ora_pad_empty;
static SV *ora_cache;
static SV *ora_cache_o;		/* temp hack for ora_open() cache override */
static int ora_login_err;	/* fetch & show real login errmsg if true  */

static int autocommit = 0;	/* we assume autocommit is off initially   */


void
dbd_init(dbistate)
    dbistate_t *dbistate;
{
    DBIS = dbistate;
    ora_long     = perl_get_sv("Oraperl::ora_long",      GV_ADDMULTI);
    ora_trunc    = perl_get_sv("Oraperl::ora_trunc",     GV_ADDMULTI);
    ora_cache    = perl_get_sv("Oraperl::ora_cache",     GV_ADDMULTI);
    ora_cache_o  = perl_get_sv("Oraperl::ora_cache_o",   GV_ADDMULTI);

    ora_pad_empty= perl_get_sv("Oraperl::ora_pad_empty", GV_ADDMULTI);
    if (!SvOK(ora_pad_empty) && getenv("ORAPERL_PAD_EMPTY"))
	sv_setiv(ora_pad_empty, atoi(getenv("ORAPERL_PAD_EMPTY")));

    if (getenv("DBD_ORACLE_LOGIN_ERR"))
		ora_login_err = atoi(getenv("DBD_ORACLE_LOGIN_ERR"));
}


/* Database specific error handling.
	This will be split up into specific routines
	for dbh and sth level.
	Also split into helper routine to set number & string.
	Err, many changes needed, ramble ...
*/

void
ora_error(h, lda, rc, what)
    SV *h;
    Lda_Def *lda;
    sb2	rc;
    char *what;
{
    D_imp_xxh(h);
    SV *errstr = DBIc_ERRSTR(imp_xxh);
    sv_setiv(DBIc_ERR(imp_xxh), (IV)rc);	/* set err early	*/
    if (lda) {	/* is oracle error (allow for non-oracle errors)	*/
	int len;
	char msg[1024];
	/* Oracle oerhms can do duplicate free if connect fails.	*/
	/* Ignore 'with different width due to prototype' gcc warning	*/
	oerhms(lda, rc, (text*)msg, sizeof(msg));	/* may hang!	*/
	len = strlen(msg);
	if (len && msg[len-1] == '\n')
	    msg[len-1] = '\0'; /* trim off \n from end of message */
	sv_setpv(errstr, (char*)msg);
    }
    else sv_setpv(errstr, what);
    if (what && lda) {
	sv_catpv(errstr, " (DBD: ");
	sv_catpv(errstr, what);
	sv_catpv(errstr, ")");
    }
    DBIh_EVENT2(h, ERROR_event, DBIc_ERR(imp_xxh), errstr);
    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "%s error %d recorded: %s\n",
		what, rc, SvPV(errstr,na));
}


void
fbh_dump(fbh, i, aidx)
    imp_fbh_t *fbh;
    int i;
    int aidx;	/* array index */
{
    FILE *fp = DBILOGFP;
    fprintf(fp, "fbh %d: '%s' %s, ",
		i, fbh->cbuf, (fbh->nullok) ? "NULLable" : "");
    fprintf(fp, "type %d,  dbsize %ld, dsize %ld, p%d s%d\n",
	    fbh->dbtype, (long)fbh->dbsize, (long)fbh->dsize,
	    fbh->prec, fbh->scale);
    fprintf(fp, "   out: ftype %d, bufl %d. cache@%d: indp %d, rlen %d, rcode %d\n",
	    fbh->ftype, fbh->fb_ary->bufl, aidx, fbh->fb_ary->aindp[aidx],
	    fbh->fb_ary->arlen[aidx], fbh->fb_ary->arcode[aidx]);
}


static int
dbtype_is_long(dbtype)
    int dbtype;
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
dbtype_is_string(dbtype)	/* 'can we use SvPV to pass buffer?'	*/
    int dbtype;
{
    switch(dbtype) {
    case  1:	/* VARCHAR2	*/
    case  5:	/* STRING	*/
    case  8:	/* LONG		*/
    case 23:	/* RAW		*/
    case 24:	/* LONG RAW	*/
    case 96:	/* CHAR		*/
    case 97:	/* CHARZ	*/
    case 106:	/* MLSLABEL	*/
	return 1;
    }
    return 0;
}


/* --- allocate and free oracle oci 'array' buffers --- */

fb_ary_t *
fb_ary_alloc(bufl, size)
int bufl;
int size;
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
fb_ary_free(fb_ary)
fb_ary_t *fb_ary;
{
    Safefree(fb_ary->abuf);
    Safefree(fb_ary->aindp);
    Safefree(fb_ary->arlen);
    Safefree(fb_ary->arcode);
    Safefree(fb_ary);
}



static void
dump_error_status(cda)
    struct cda_def *cda;
{
    fprintf(DBILOGFP,
	"(rc %ld, v2 %ld, ft %ld, rpc %ld, peo %ld, fc %ld, ose %ld)\n",
	(long)cda->rc, (long)cda->v2_rc, (long)cda->ft, (long)cda->rpc,
	(long)cda->peo, (long)cda->fc, (long)cda->ose
    );
}


/* ================================================================== */

int
dbd_db_login(dbh, dbname, uid, pwd)
    SV *dbh;
    char *dbname;
    char *uid;
    char *pwd;
{
    D_imp_dbh(dbh);
    int ret;

    /* can give duplicate free errors (from Oracle) if connect fails	*/
    ret = orlon(&imp_dbh->lda, imp_dbh->hda, (text*)uid,-1, (text*)pwd,-1,0);
    if (ret) {
	int rc = imp_dbh->lda.rc;
	/* oerhms in ora_error may hang or corrupt memory (!) after a connect	*/
	/* failure. So we fake the common error messages unless ora_login_err	*/
	/* is true (set via env var above).	Thank Oracle for this sad hack.	*/
	char buf[100];
	char *msg="ORA-%d: (Text for error %d not fetched. Use 'oerr ORA %d' command.)";
        switch (rc) {
	case 1017:  msg="ORA-%d: invalid username/password; login denied";
		    break;
	case 1034:  msg="ORA-%d: ORACLE not available";
		    break;
	case 2700:  msg="ORA-%d: osnoraenv: error translating ORACLE_SID";
		    break;
	case 12154: msg="ORA-%d: TNS:could not resolve service name";
		    break;
        }
	sprintf(buf, msg, rc, rc, rc);
	ora_error(dbh,	ora_login_err ? &imp_dbh->lda  : NULL, rc,
			ora_login_err ? "login failed" : buf);
	return 0;
    }
    DBIc_IMPSET_on(imp_dbh);	/* imp_dbh set up now			*/
    DBIc_ACTIVE_on(imp_dbh);	/* call disconnect before freeing	*/
    return 1;
}


int
dbd_db_commit(dbh)
    SV *dbh;
{
    D_imp_dbh(dbh);
    if (ocom(&imp_dbh->lda)) {
	ora_error(dbh, &imp_dbh->lda, imp_dbh->lda.rc, "commit failed");
	return 0;
    }
    return 1;
}

int
dbd_db_rollback(dbh)
    SV *dbh;
{
    D_imp_dbh(dbh);
    if (orol(&imp_dbh->lda)) {
	ora_error(dbh, &imp_dbh->lda, imp_dbh->lda.rc, "rollback failed");
	return 0;
    }
    return 1;
}


int
dbd_db_disconnect(dbh)
    SV *dbh;
{
    D_imp_dbh(dbh);
    /* We assume that disconnect will always work	*/
    /* since most errors imply already disconnected.	*/
    DBIc_ACTIVE_off(imp_dbh);
    if (ologof(&imp_dbh->lda)) {
	ora_error(dbh, &imp_dbh->lda, imp_dbh->lda.rc, "disconnect error");
	return 0;
    }
    /* We don't free imp_dbh since a reference still exists	*/
    /* The DESTROY method is the only one to 'free' memory.	*/
    /* Note that statement objects may still exists for this dbh!	*/
    return 1;
}


void
dbd_db_destroy(dbh)
    SV *dbh;
{
    D_imp_dbh(dbh);
    if (DBIc_ACTIVE(imp_dbh))
	dbd_db_disconnect(dbh);
    /* Nothing in imp_dbh to be freed	*/
    DBIc_IMPSET_off(imp_dbh);
}


int
dbd_db_STORE_attrib(dbh, keysv, valuesv)
    SV *dbh;
    SV *keysv;
    SV *valuesv;
{
    D_imp_dbh(dbh);
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    SV *cachesv = NULL;
    int on = SvTRUE(valuesv);

    if (kl==10 && strEQ(key, "AutoCommit")) {
	if ( (on) ? ocon(&imp_dbh->lda) : ocof(&imp_dbh->lda) ) {
	    ora_error(dbh, &imp_dbh->lda, imp_dbh->lda.rc, "ocon/ocof failed");
	    /* XXX um, we can't return FALSE and true isn't acurate */
	    /* the best we can do is cache an undef	*/
	    cachesv = &sv_undef;
	} else {
	    autocommit = on;
	    cachesv = boolSV(on);	/* cache new state */
	}
    } else {
	return FALSE;
    }
    if (cachesv) /* cache value for later DBI 'quick' fetch? */
	hv_store((HV*)SvRV(dbh), key, kl, cachesv, 0);
    return TRUE;
}


SV *
dbd_db_FETCH_attrib(dbh, keysv)
    SV *dbh;
    SV *keysv;
{
    /* D_imp_dbh(dbh); */
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    SV *retsv = NULL;
    /* Default to caching results for DBI dispatch quick_FETCH	*/
    int cacheit = TRUE;

    if (kl==10 && strEQ(key, "AutoCommit")) {
	return boolSV(autocommit);
    }
    else
	return Nullsv;
    if (cacheit) {	/* cache for next time (via DBI quick_FETCH)	*/
	SV **svp = hv_fetch((HV*)SvRV(dbh), key, kl, 1);
	sv_free(*svp);
	*svp = retsv;
	(void)SvREFCNT_inc(retsv);	/* so sv_2mortal won't free it	*/
    }
    return sv_2mortal(retsv);
}



/* ================================================================== */


int
dbd_st_prepare(sth, statement, attribs)
    SV *sth;
    char *statement;
    SV *attribs;
{
    D_imp_sth(sth);
    D_imp_dbh_from_sth;
    sword oparse_defer = 0;  /* PARSE_NO_DEFER */
    ub4   oparse_lng   = 1;  /* auto v6 or v7 as suits db connected to	*/

    imp_sth->done_desc = 0;
    imp_sth->cda = &imp_sth->cdabuf;

    if (DBIc_COMPAT(imp_sth)) {
	imp_sth->ora_pad_empty = (SvOK(ora_pad_empty)) ? SvIV(ora_pad_empty) : 0;
    }

    if (attribs) {
	SV **svp;
	DBD_ATTRIB_GET_IV(  attribs, "ora_parse_lang", 14, svp, oparse_lng);
	DBD_ATTRIB_GET_BOOL(attribs, "ora_parse_defer",15, svp, oparse_defer);
    }

    if (oopen(imp_sth->cda, &imp_dbh->lda, (text*)0, -1, -1, (text*)0, -1)) {
        ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oopen error");
        return 0;
    }

    /* scan statement for '?', ':1' and/or ':foo' style placeholders	*/
    dbd_preparse(imp_sth, statement);

    /* parse the (possibly edited) SQL statement */
    /* Note that (if oparse_defer=0, the default) Data Definition	*/
    /* statements will be executed at once. This is a major pain!	*/
    imp_sth->cda->peo = 0;
    if (oparse(imp_sth->cda, (text*)imp_sth->statement, (sb4)-1,
                (sword)oparse_defer, (ub4)oparse_lng)
    ) {
	SV  *msgsv, *sqlsv;
	char msg[99];
	sqlsv = sv_2mortal(newSVpv(imp_sth->statement,0));
	sv_insert(sqlsv, imp_sth->cda->peo, 0, "<*>",3);
	sprintf(msg,"error possibly near <*> indicator at char %d in '",
		imp_sth->cda->peo+1);
	msgsv = sv_2mortal(newSVpv(msg,0));
	sv_catsv(msgsv, sqlsv);
	sv_catpv(msgsv, "'");
	ora_error(sth, imp_sth->cda, imp_sth->cda->rc, SvPV(msgsv,na));
	oclose(imp_sth->cda);	/* close the cursor	*/
	return 0;
    }

    /* detect warning for pl/sql create errors */
    if (imp_sth->cda->wrn & 32) {
	; /* XXX perl_call_method to get error text ? */
    }

    /* long_buflen:	length for long/longraw (if >0), else 80 (ora app dflt)	*/
    /* long_trunc_ok:	is truncating a long an error    XXX not implemented	*/
    imp_sth->long_buflen   = (SvOK(ora_long) && SvIV(ora_long)>0) ? SvIV(ora_long) : 80;
    imp_sth->long_trunc_ok = 1;	/* can use blob_read()		*/
    /* ora_trunc is checked at fetch time */

    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "    dbd_st_prepare'd sql f%d (lb %ld, lt %d)\n",
	    imp_sth->cda->ft, (long)imp_sth->long_buflen, imp_sth->long_trunc_ok);

    /* Describe and allocate storage for results.		*/
    if (!dbd_describe(sth, imp_sth)) {
	return 0;
    }
    DBIc_IMPSET_on(imp_sth);
    return 1;
}


void
dbd_preparse(imp_sth, statement)
    imp_sth_t *imp_sth;
    char *statement;
{
    bool in_literal = FALSE;
    char *src, *start, *dest;
    phs_t phs_tpl;
    SV *phs_sv;
    int idx=0, style=0, laststyle=0;
    STRLEN namelen;

    /* allocate room for copy of statement with spare capacity	*/
    /* for editing '?' or ':1' into ':p1' so we can use obndrv.	*/
    imp_sth->statement = (char*)safemalloc(strlen(statement) * 3);

    /* initialise phs ready to be cloned per placeholder	*/
    memset(&phs_tpl, 0, sizeof(phs_tpl));
    phs_tpl.ftype = 1;	/* VARCHAR2 */

    src  = statement;
    dest = imp_sth->statement;
    while(*src) {
	if (*src == '\'')
	    in_literal = ~in_literal;
	if ((*src != ':' && *src != '?') || in_literal) {
	    *dest++ = *src++;
	    continue;
	}
	start = dest;			/* save name inc colon	*/ 
	*dest++ = *src++;
	if (*start == '?') {		/* X/Open standard	*/
	    sprintf(start,":p%d", ++idx); /* '?' -> ':p1' (etc)	*/
	    dest = start+strlen(start);
	    style = 3;

	} else if (isDIGIT(*src)) {	/* ':1'		*/
	    idx = atoi(src);
	    *dest++ = 'p';		/* ':1'->':p1'	*/
	    if (idx <= 0)
		croak("Placeholder :%d must be a positive number", idx);
	    while(isDIGIT(*src))
		*dest++ = *src++;
	    style = 1;

	} else if (isALNUM(*src)) {	/* ':foo'	*/
	    while(isALNUM(*src))	/* includes '_'	*/
		*dest++ = *src++;
	    style = 2;
	} else {			/* perhaps ':=' PL/SQL construct */
	    continue;
	}
	*dest = '\0';			/* handy for debugging	*/
	namelen = (dest-start);
	if (laststyle && style != laststyle)
	    croak("Can't mix placeholder styles (%d/%d)",style,laststyle);
	laststyle = style;
	if (imp_sth->all_params_hv == NULL)
	    imp_sth->all_params_hv = newHV();
	phs_tpl.sv = &sv_undef;
	phs_sv = newSVpv((char*)&phs_tpl, sizeof(phs_tpl)+namelen+1);
	hv_store(imp_sth->all_params_hv, start, namelen, phs_sv, 0);
	strcpy( ((phs_t*)(void*)SvPVX(phs_sv))->name, start);
	/* warn("params_hv: '%s'\n", start);	*/
    }
    *dest = '\0';
    if (imp_sth->all_params_hv) {
	DBIc_NUM_PARAMS(imp_sth) = (int)HvKEYS(imp_sth->all_params_hv);
	if (dbis->debug >= 2)
	    fprintf(DBILOGFP, "    dbd_preparse scanned %d distinct placeholders\n",
		(int)DBIc_NUM_PARAMS(imp_sth));
    }
}



int
dbd_describe(h, imp_sth)
    SV *h;
    imp_sth_t *imp_sth;
{
    static sb4 *f_cbufl;		/* XXX not thread safe	*/
    static U32  f_cbufl_max;

    sb1 *cbuf_ptr;
    int t_cbufl=0;
    I32 num_fields;
    int has_longs = 0;
    int est_width = 0;		/* estimated avg row width (for cache)	*/
    int i = 0;

    I32	long_buflen = imp_sth->long_buflen;
    if (long_buflen < 0)
	long_buflen = 80;		/* typical oracle app default	*/

    if (imp_sth->done_desc)
	return 1;	/* success, already done it */
    imp_sth->done_desc = 1;

    if (imp_sth->cda->ft != FT_SELECT) {
	if (dbis->debug >= 2)
	    fprintf(DBILOGFP, "    dbd_describe skipped for non-select (sql f%d)\n",
		imp_sth->cda->ft);
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "    dbd_describe (for sql f%d after oci f%d)...\n",
			imp_sth->cda->ft, imp_sth->cda->fc);

    if (!f_cbufl) {
	f_cbufl_max = 120;
	New(1, f_cbufl, f_cbufl_max, sb4);
    }

    /* number of rows to cache	*/
    if      (SvOK(ora_cache_o)) imp_sth->cache_size = SvIV(ora_cache_o);
    else if (SvOK(ora_cache))   imp_sth->cache_size = SvIV(ora_cache);
    else                        imp_sth->cache_size = 0;   /* auto size	*/

    /* Get number of fields and space needed for field names	*/
    while(++i) {	/* break out within loop		*/
	sb1 cbuf[257];	/* generous max column name length	*/
	sb2 dbtype = 0;	/* workaround for Oracle bug #405032	*/
	sb4 dbsize;
	if (i >= f_cbufl_max) {
	    f_cbufl_max *= 2;
	    Renew(f_cbufl, f_cbufl_max, sb4);
	}
	f_cbufl[i] = sizeof(cbuf);
	odescr(imp_sth->cda, i, &dbsize, &dbtype,
		cbuf, &f_cbufl[i], (sb4*)0, (sb2*)0, (sb2*)0, (sb2*)0);
        if (imp_sth->cda->rc || dbtype == 0)
	    break;
	t_cbufl  += f_cbufl[i];

	/* now we calculate the approx average on-the-wire width of	*/
	/* each field (and thus row) to determine a 'good' cache size.	*/
	if (imp_sth->cache_size > 0)
	    continue;		/* no need, user specified a size	*/
	if (dbsize==0) {	/* is a LONG type or 'select NULL'	*/
	    if (dbtype_is_long(dbtype)) {
		est_width += long_buflen;
		++has_longs;	/* hint to auto cache sizing code	*/
	    }
	}
	else		/* deal with dbtypes with overblown dbsizes	*/
	switch(dbtype) {
	case 1:     /* VARCHAR2 - result of to_char() has dbsize==75	*/
		    /* for all but small strings we take off 25%	*/
		    est_width += (dbsize < 32) ? dbsize : dbsize-(dbsize>>2);
		    break;
	case 2:     /* NUMBER - e.g., from a sum() or max(), dbsize==22	*/
		    /* Most numbers are _much_ smaller than 22 bytes	*/
		    est_width += 4;	/* > approx +/- 1_000_000 ?	*/
		    break;
	default:    est_width += dbsize;
		    break;
	}
    }
    if (imp_sth->cda->rc && imp_sth->cda->rc != 1007) {
	D_imp_dbh_from_sth;
	ora_error(h, &imp_dbh->lda, imp_sth->cda->rc, "odescr failed");
	return 0;
    }
    imp_sth->cda->rc = 0;
    num_fields = i - 1;
    DBIc_NUM_FIELDS(imp_sth) = num_fields;

    /* --- Setup the row cache for this query --- */

    if (has_longs)			/* override/disable caching	*/
	imp_sth->cache_size = 1;	/* else read_blob can't work	*/

    else if (imp_sth->cache_size < 1) {	/* automaticaly size the cache	*/
	/*  0 == try to pick 'optimal' cache for this query.		*/
	/* <0 == base cache on transfer size of -n bytes (default 2048)	*/
	/* Use guessed average on-the-wire row width calculated above	*/
	/* + overhead of 5 bytes per field plus 8 bytes per row.	*/
	int width = est_width + num_fields*5 + 8;
	/* How many rows fit in 2Kb? (2Kb is a reasonable compromise)	*/
	int hunk  = 2048;		/* default cache size		*/
	if (imp_sth->cache_size < 0)	/* user is specifying txfr size	*/
	    hunk = -imp_sth->cache_size;/* is also approx cache size	*/
	imp_sth->cache_size = hunk / width;
	if (imp_sth->cache_size < 5)	/* always cache at least 5	*/
	    imp_sth->cache_size = 5;
    }
    if (imp_sth->cache_size > 32767)	/* keep within Oracle's limits  */
	imp_sth->cache_size = 32767;
    /* Initialise cache counters */
    imp_sth->in_cache  = 0;
    imp_sth->eod_errno = 0;


    /* allocate field buffers				*/
    Newz(42, imp_sth->fbh,      num_fields, imp_fbh_t);
    /* allocate a buffer to hold all the column names	*/
    Newz(42, imp_sth->fbh_cbuf, t_cbufl + num_fields, char);

    cbuf_ptr = (sb1*)imp_sth->fbh_cbuf;
    for(i=1; i <= num_fields && imp_sth->cda->rc != 10; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i-1];
	fb_ary_t  *fb_ary;
	int dbtype;

	fbh->imp_sth = imp_sth;
	fbh->cbuf    = cbuf_ptr;
	fbh->cbufl   = f_cbufl[i];
	/* DESCRIBE */
	odescr(imp_sth->cda, i,
		&fbh->dbsize, &fbh->dbtype,  fbh->cbuf,  &fbh->cbufl,
		&fbh->dsize,  &fbh->prec,   &fbh->scale, &fbh->nullok);
	fbh->cbuf[fbh->cbufl] = '\0';	 /* ensure null terminated	*/
	cbuf_ptr += fbh->cbufl + 1;	 /* increment name pointer	*/

	/* Now define the storage for this field data.			*/

	/* Is it a LONG, LONG RAW, LONG VARCHAR or LONG VARRAW?		*/
	/* If so we need to implement oraperl truncation hacks.		*/
	/* This may change in a future release.				*/
	/* Note that dbtype_is_long() returns alternate dbtype to use	*/
	if ( (dbtype = dbtype_is_long(fbh->dbtype)) ) {
	    fbh->dbsize = long_buflen;
	    fbh->dsize  = long_buflen;
	    fbh->ftype  = dbtype;	/* get long in non-var form	*/
	    imp_sth->t_dbsize += long_buflen;

	} else {
	    /* for the time being we fetch everything (except longs)	*/
	    /* as strings, that'll change (IV, NV and binary data etc)	*/
	    fbh->ftype = 5;		/* oraperl used 5 'STRING'	*/
	    /* dbsize can be zero for 'select NULL ...'			*/
	    imp_sth->t_dbsize += fbh->dbsize;
	}

	fbh->fb_ary = fb_ary = fb_ary_alloc(
			fbh->dsize+1,	/* +1: STRING null terminator   */
			imp_sth->cache_size
		    );

	/* DEFINE output column variable storage */
	if (odefin(imp_sth->cda, i, fb_ary->abuf, fb_ary->bufl,
		fbh->ftype, -1, fb_ary->aindp, (text*)0, -1, -1,
		fb_ary->arlen, fb_ary->arcode)) {
	    warn("odefin error on %s: %d", fbh->cbuf, imp_sth->cda->rc);
	}

	if (dbis->debug >= 2)
	    fbh_dump(fbh, i, 0);
    }

    if (dbis->debug >= 2)
	fprintf(DBILOGFP,
	    "    dbd_describe'd %d columns (~%d data bytes, %d cache rows @%db)\n",
	    (int)num_fields, imp_sth->t_dbsize, imp_sth->cache_size, est_width);

    if (imp_sth->cda->rc && imp_sth->cda->rc != 1007) {
	D_imp_dbh_from_sth;
	ora_error(h, &imp_dbh->lda, imp_sth->cda->rc, "odescr failed");
	return 0;
    }

    return 1;
}



static int 
_dbd_rebind_ph(sth, imp_sth, phs) 
    SV *sth;
    imp_sth_t *imp_sth;
    phs_t *phs;
{
    STRLEN value_len;

/*	for strings, must be a PV first for ptr to be valid? */
/*    sv_insert +4	*/
/*    sv_chop(phs->sv, SvPV(phs->sv,na)+4);	XXX */

    if (dbis->debug >= 2) {
	char *text = neatsvpv(phs->sv,0);
	fprintf(DBILOGFP, "bind %s <== %s (size %d/%d/%ld, ptype %ld, otype %d)\n",
	    phs->name, text, SvCUR(phs->sv),SvLEN(phs->sv),phs->maxlen,
	    SvTYPE(phs->sv), phs->ftype);
    }

    /* At the moment we always do sv_setsv() and rebind.	*/
    /* Later we may optimise this so that more often we can	*/
    /* just copy the value & length over and not rebind.	*/

    if (phs->is_inout) {	/* XXX */
	/* phs->sv _is_ the real live variable, it may 'mutate' later	*/
	/* pre-upgrade high to reduce risk of SvPVX realloc/move	*/
	(void)SvUPGRADE(phs->sv, SVt_PVNV);
	/* ensure room for result, 28 is magic number (see sv_2pv)	*/
	SvGROW(phs->sv, (phs->maxlen < 28) ? 28 : phs->maxlen+1);
	if (imp_sth->ora_pad_empty)
	    croak("Can't use ora_pad_empty with bind_param_inout");
    }
    else {
	/* phs->sv is copy of real variable, upgrade to at least string	*/
	(void)SvUPGRADE(phs->sv, SVt_PV);
    }

    /* At this point phs->sv must be at least a PV with a valid buffer,	*/
    /* even if it's undef (null)					*/
    /* Here we set phs->progv, phs->indp, and value_len.		*/
    if (SvOK(phs->sv)) {
	phs->progv = SvPV(phs->sv, value_len);
	phs->indp  = 0;
    }
    else {	/* it's null but point to buffer incase it's an out var	*/
	phs->progv = SvPVX(phs->sv);
	phs->indp  = -1;
	value_len  = 0;
    }
    if (imp_sth->ora_pad_empty && value_len==0) {
	sv_setpv(phs->sv, " ");
	phs->progv = SvPV(phs->sv, value_len);
    }
    phs->sv_type = SvTYPE(phs->sv);	/* part of mutation check	*/
    phs->alen    = value_len + phs->alen_incnull;
    phs->maxlen  = SvLEN(phs->sv)-1;	/* avail buffer space	*/

    /* ---------- */

    /* Since we don't support LONG VAR types we must check	*/
    /* for lengths too big to pass to obndrv as an sword.	*/
    if (phs->maxlen > MINSWORDMAXVAL)	/* generally 32K	*/
	croak("Can't bind %s, value is too long (%ld bytes, max %d)",
		    phs->name, phs->maxlen, MINSWORDMAXVAL);

    if (phs->alen > phs->maxlen)
	croak("panic: _dbd_rebind_ph alen %ld > maxlen %ld", phs->alen,phs->maxlen);

    if (dbis->debug >= 3) {
	fprintf(DBILOGFP, "bind %s <== '%.100s' (size %d/%ld, indp %d)\n",
	    phs->name, phs->progv, phs->alen, (long)phs->maxlen, phs->indp);
    }

    if (obndra(imp_sth->cda, (text *)phs->name, -1,
	    (ub1*)phs->progv, (ub2)phs->maxlen, /* cast reduces max size */
	    (sword)phs->ftype, -1,
	    &phs->indp, &phs->alen, &phs->arcode, 0, (ub4 *)0,
	    (text *)0, -1, -1)) {
	D_imp_dbh_from_sth;
	ora_error(sth, &imp_dbh->lda, imp_sth->cda->rc, "obndra failed");
	return 0;
    }
    return 1;
}


int
dbd_bind_ph(sth, ph_namesv, newvalue, attribs, is_inout, maxlen)
    SV *sth;
    SV *ph_namesv;
    SV *newvalue;
    SV *attribs;
    int is_inout;
    IV maxlen;
{
    D_imp_sth(sth);
    SV **phs_svp;
    STRLEN name_len;
    char *name;
    char namebuf[30];
    phs_t *phs;

    /* check if placeholder was passed as a number	*/
    if (SvNIOK(ph_namesv) || (SvPOK(ph_namesv) && isDIGIT(*SvPVX(ph_namesv)))) {
	name = namebuf;
	sprintf(name, ":p%d", (int)SvIV(ph_namesv));
	name_len = strlen(name);
    }
    else {		/* use the supplied placeholder name directly */
	name = SvPV(ph_namesv, name_len);
    }

    if (SvTYPE(newvalue) > SVt_PVMG)	/* hook for later array logic	*/
	croak("Can't bind non-scalar value (currently)");

    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "bind %s <== %s (attribs: %s)\n",
		name, neatsvpv(newvalue,0), attribs ? SvPV(attribs,na) : "" );

    phs_svp = hv_fetch(imp_sth->all_params_hv, name, name_len, 0);
    if (phs_svp == NULL)
	croak("Can't bind unknown placeholder '%s'", name);
    phs = (phs_t*)(void*)SvPVX(*phs_svp);	/* placeholder struct	*/

    if (phs->sv == &sv_undef) {	/* first bind for this placeholder	*/
	phs->ftype    = 1;		/* our default type VARCHAR2	*/
	phs->maxlen   = maxlen;		/* 0 if not inout		*/
	phs->is_inout = is_inout;
	if (is_inout) {
	    phs->sv = SvREFCNT_inc(newvalue);	/* point to live var	*/
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
		if (!dbtype_is_string(ora_type))	/* mean but safe	*/
		    croak("Can't bind %s, ora_type %d not a simple string type",
			    phs->name, ora_type);
		phs->ftype = ora_type;
	    }
	}

	/* some types require the trailing null included in the length.	*/
	phs->alen_incnull = (phs->ftype==SQLT_STR || phs->ftype==SQLT_AVC);

    }
	/* check later rebinds for any changes */
    else if (is_inout || phs->is_inout) {
	croak("Can't rebind or change param %s in/out mode after first bind", phs->name);
    }
    else if (maxlen && maxlen != phs->maxlen) {
	croak("Can't change param %s maxlen (%ld->%ld) after first bind",
			phs->name, phs->maxlen, maxlen);
    }

    if (!is_inout) {	/* normal bind to take a (new) copy of current value	*/
	if (phs->sv == &sv_undef)	/* (first time bind) */
	    phs->sv = newSV(0);
	sv_setsv(phs->sv, newvalue);
    }

    return _dbd_rebind_ph(sth, imp_sth, phs);
}



int
dbd_st_execute(sth)	/* <0 is error, >=0 is ok (row count) */
    SV *sth;
{
    D_imp_sth(sth);
    int debug = dbis->debug;
    int outparams = (imp_sth->out_params_av) ? AvFILL(imp_sth->out_params_av)+1 : 0;

    if (!imp_sth->done_desc) {
	/* describe and allocate storage for results (if any needed)	*/
	if (!dbd_describe(sth, imp_sth))
	    return -1; /* dbd_describe already called ora_error()	*/
    }

    if (debug >= 2)
	fprintf(DBILOGFP,
	    "    dbd_st_execute (for sql f%d after oci f%d, outs %d)...\n",
			imp_sth->cda->ft, imp_sth->cda->fc, outparams);

    if (outparams) {	/* check validity of bound SV's	*/
	int i = outparams;
	STRLEN phs_len;
	while(--i >= 0) {
	    phs_t *phs = (phs_t*)(void*)SvPVX(AvARRAY(imp_sth->out_params_av)[i]);
	    /* Make sure we have the value in string format. Typically a number	*/
	    /* will be converted back into a string using the same bound buffer	*/
	    /* so the progv test below will not trip.			*/
/* XXX needs reworking
call rebind for all changes
consider also case of undef and bind time and not undef at execute
*/
	    if (SvOK(phs->sv)) {
		if (!SvPOK(phs->sv))	/* ooops, no string ($var = 42)	*/
		    SvPV(phs->sv, phs_len);	/* get string ("42"), see progv	*/
		phs_len = SvCUR(phs->sv) + phs->alen_incnull;
		if (phs_len >= 65535)	/* alen is only 16 bit. XXX maxlen */
		    croak("Placeholder %s value too long",phs->name);
		phs->alen = phs_len;
		phs->indp =  0;		/* mark as not null */
	    }
	    else {
		phs->indp = -1;		/* mark as null */
	    }
	    /* Some checks for mutated storage since we pointed oracle at it.	*/
	    if (SvTYPE(phs->sv) != phs->sv_type || SvPVX(phs->sv) != phs->progv) {
		if (!_dbd_rebind_ph(sth, imp_sth, phs))
		    croak("Can't rebind placeholder %s", phs->name);
	    }
	    if (debug >= 2)
		warn("pre %s = '%s' (len %d)\n", phs->name, SvPVX(phs->sv), phs->alen);
	}
    }

    /* reset cache counters */
    imp_sth->in_cache   = 0;
    imp_sth->next_entry = 0;
    imp_sth->eod_errno  = 0;

    /* Trigger execution of the statement */
    if (DBIc_NUM_FIELDS(imp_sth) > 0) {  	/* is a SELECT	*/
	/* The number of fields is used because imp_sth->cda->ft is unreliable.	*/
	/* Specifically an update (5) may change to select (4) after odesc().	*/
	if (oexfet(imp_sth->cda, (ub4)imp_sth->cache_size, 0, 0)
		&& imp_sth->cda->rc != 1403 /* other than no more data */ ) {
	    ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oexfet error");
	    return -1;
	}
	imp_sth->in_cache = imp_sth->cda->rpc;	/* cache loaded */
	if (imp_sth->cda->rc == 1403)
	    imp_sth->eod_errno = 1403;
    }
    else {					/* NOT a select */
	if (oexec(imp_sth->cda)) {
	    ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oexec error");
	    return -1;
	}
    }

    if (debug >= 2)
	fprintf(DBILOGFP, "    dbd_st_execute complete (rc%d, w%02x, rpc%ld, eod%d, out%d)\n",
		imp_sth->cda->rc,  imp_sth->cda->wrn,
		imp_sth->cda->rpc, imp_sth->eod_errno,
		imp_sth->has_inout_params);

    if (outparams) {	/* check validity of bound SV's	*/
	int i = outparams;
	STRLEN retlen;
	while(--i >= 0) {
	    phs_t *phs = (phs_t*)(void*)SvPVX(AvARRAY(imp_sth->out_params_av)[i]);
	    SV *sv = phs->sv;
	    if (phs->indp == 0) {			/* is okay	*/
		SvPOK_only(sv);
		SvCUR(sv) = phs->alen;
		*SvEND(sv) = '\0';
		if (debug >= 2)
		    warn("    %s = '%s' (len %d)\n", phs->name, SvPV(sv,retlen),retlen);
	    }
	    else
	    if (phs->indp > 0 || phs->indp == -2) {	/* truncated	*/
		SvPOK_only(sv);
		SvCUR(sv) = phs->alen;
		*SvEND(sv) = '\0';
		if (debug >= 2)
		    warn("    %s = '%s' (TRUNCATED from %d to %d)\n", phs->name,
			    SvPV(sv,retlen), phs->indp, retlen);
	    }
	    else
	    if (phs->indp == -1) {			/* is NULL	*/
		(void)SvOK_off(phs->sv);
		if (debug >= 2)
		     warn("    %s = undef (NULL)\n", phs->name);
	    }
	    else croak("%s bad indp %d", phs->name, phs->indp);
	}
    }

    DBIc_ACTIVE_on(imp_sth);	/* XXX should only set for select ?	*/
    return imp_sth->cda->rpc;	/* row count	*/
}



AV *
dbd_st_fetch(sth)
    SV *	sth;
{
    D_imp_sth(sth);
    int debug = dbis->debug;
    int num_fields;
    int ChopBlanks;
    int i;
    AV *av;

    /* Check that execute() was executed sucessfully. This also implies	*/
    /* that dbd_describe() executed sucessfuly so the memory buffers	*/
    /* are allocated and bound.						*/
    if ( !DBIc_ACTIVE(imp_sth) ) {
	ora_error(sth, NULL, 1, "no statement executing");
	return Nullav;
    }

    if (!imp_sth->in_cache) {	/* refill cache if empty	*/
	int rows_returned;

	if (imp_sth->eod_errno) {
    end_of_data:
	    if (imp_sth->eod_errno != 1403) {	/* was not just end-of-fetch	*/
		ora_error(sth, imp_sth->cda, imp_sth->eod_errno, "ofetch error");
	    } else {				/* is simply no more data	*/
		sv_setiv(DBIc_ERR(imp_sth), 0);	/* ensure errno set to 0 here	*/
		if (debug >= 2)
		    fprintf(DBILOGFP, "    dbd_st_fetch no-more-data, rc=%d, rpc=%ld\n",
			imp_sth->cda->rc, imp_sth->cda->rpc);
	    }
	    /* further fetches without an execute will arrive back here	*/
	    return Nullav;
	}

	rows_returned = imp_sth->cda->rpc;	/* remember rpc before re-fetch	*/
	if (ofen(imp_sth->cda, imp_sth->cache_size)) {
	    /* Note that errors may happen after one or more rows have been	*/
	    /* added to the cache. We record the error but don't handle it till	*/
	    /* the cache is empty (which may be at once if no rows returned).	*/
	    imp_sth->eod_errno = imp_sth->cda->rc;	/* store rc for later	*/
	    if (imp_sth->cda->rpc == rows_returned)	/* no more rows fetched	*/
		goto end_of_data;
	    /* else fall through and return the first of the fetched rows	*/
	}
	imp_sth->next_entry = 0;
	imp_sth->in_cache   = imp_sth->cda->rpc - rows_returned;
	assert(imp_sth->in_cache > 0);
    }

    av = DBIS->get_fbav(imp_sth);
    num_fields = AvFILL(av)+1;

    if (debug >= 3)
	fprintf(DBILOGFP, "    dbd_st_fetch %d fields, rpc %ld (cache: %d/%d/%d)\n",
		num_fields, (long)imp_sth->cda->rpc, imp_sth->next_entry,
		imp_sth->in_cache, imp_sth->cache_size);

    ChopBlanks = DBIc_has(imp_sth, DBIcf_ChopBlanks);

    for(i=0; i < num_fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	int cache_entry = imp_sth->next_entry;
	fb_ary_t *fb_ary = fbh->fb_ary;
	int rc = fb_ary->arcode[cache_entry];
	SV *sv = AvARRAY(av)[i]; /* Note: we (re)use the SV in the AV	*/

	if (rc == 1406 && dbtype_is_long(fbh->dbtype)) {
	    /* We have a LONG field which has been truncated.		*/
	    int oraperl = DBIc_COMPAT(imp_sth);
	    if ((oraperl) ? SvIV(ora_trunc) : imp_sth->long_trunc_ok) {
		/* Oraperl recorded the truncation in ora_errno.	*/
		/* We do so but it's not part of the DBI spec.		*/
		sv_setiv(DBIc_ERR(imp_sth), (IV)rc); /* record it	*/
		rc = 0;			/* but don't provoke an error	*/
	    }
	}

	if (rc == 0) {			/* the normal case		*/
	    sv_setpvn(sv, (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl],
			  fb_ary->arlen[cache_entry]);
	    /* if ChopBlanks check for Oracle CHAR type (blank padded)	*/
	    if (ChopBlanks && fbh->dbtype == 96) {
		char *p = SvEND(sv);
		int len = SvCUR(sv);
		while(len && *--p == ' ')
		    --len;
		if (len != SvCUR(sv)) {
		    SvCUR_set(sv, len);
		    *SvEND(sv) = '\0';
		}
	    }

	} else if (rc == 1405) {	/* field is null - return undef	*/
	    (void)SvOK_off(sv);

	} else {  /* See odefin rcode arg description in OCI docs	*/
	    /* These may get case-by-case treatment eventually.	*/
	    /* Some should probably be treated as warnings but	*/
	    /* for now we just treat them all as errors		*/
	    ora_error(sth, imp_sth->cda, rc, "ofetch rcode");
	    (void)SvOK_off(sv);
	}

	if (debug >= 3)
	    fprintf(DBILOGFP, "        %d: rc=%d '%s'\n",
		i, rc, SvPV(sv,na));

    }

    /* update cache counters */
    --imp_sth->in_cache;
    ++imp_sth->next_entry;

    return av;
}




int
dbd_st_blob_read(sth, field, offset, len, destrv, destoffset)
    SV *sth;
    int field;
    long offset;
    long len;
    SV *destrv;
    long destoffset;
{
    D_imp_sth(sth);
    ub4 retl;
    SV *bufsv;

    bufsv = SvRV(destrv);
    sv_setpvn(bufsv,"",0);	/* ensure it's writable string	*/
    SvGROW(bufsv, len+destoffset+1);	/* SvGROW doesn't do +1	*/

    if (oflng(imp_sth->cda, (sword)field+1,
	    ((ub1*)SvPVX(bufsv)) + destoffset, len,
	    imp_sth->fbh[field].ftype, /* original long type	*/
	    &retl, offset)) {
	ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oflng error");
	/* XXX database may have altered the buffer contents	*/
	return 0;
    }
    /* Sadly, even though retl is a ub4, oracle will cap the	*/
    /* value of retl at 65535 even if more was returned!	*/
    /* This is according to the OCI manual for Oracle 7.0.	*/
    /* Once again Oracle causes us grief. How can we tell what	*/
    /* length to assign to destrv? We do have a compromise: if	*/
    /* retl is exactly 65535 we assume that all data was read.	*/
    SvCUR_set(bufsv, destoffset+((retl == 65535) ? len : retl));
    *SvEND(bufsv) = '\0'; /* consistent with perl sv_setpvn etc	*/

    return 1;
}


int
dbd_st_rows(sth)
    SV *sth;
{
    D_imp_sth(sth);
    return imp_sth->cda->rpc;
}


int
dbd_st_finish(sth)
    SV *sth;
{
    D_imp_sth(sth);
    /* Cancel further fetches from this cursor.                 */
    /* We don't close the cursor till DESTROY (dbd_st_destroy). */
    /* The application may re execute(...) it.                  */
    if (DBIc_ACTIVE(imp_sth) && ocan(imp_sth->cda) ) {
	/* oracle 7.3 code can core dump looking up an error message	*/
	/* if we have logged out of the database. This typically	*/
	/* happens during global destruction. This should catch most:	*/
	if (dirty && imp_sth->cda->rc == 3114)
	    ora_error(sth, NULL, imp_sth->cda->rc,
		"ORA-03114: not connected to ORACLE (ocan)");
	else
	    ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "ocan error");
	return 0;
    }
    DBIc_ACTIVE_off(imp_sth);
    return 1;
}


void
dbd_st_destroy(sth)
    SV *sth;
{
    D_imp_sth(sth);
    D_imp_dbh_from_sth;
    int fields;
    int i;
    /* Check if an explicit disconnect() or global destruction has	*/
    /* disconnected us from the database before attempting to close.	*/
    if (DBIc_ACTIVE(imp_dbh) && oclose(imp_sth->cda)) {
	/* Check for ORA-01041: 'hostdef extension doesn't exist'	*/
	/* which indicates that the lda had already been logged out	*/
	/* in which case only complain if not in 'global destruction'.	*/
	/* NOT NEEDED NOW? if ( ! (imp_sth->cda->rc == 1041 && dirty) ) */
	    ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oclose error");
	/* fall through */
    } 

    /* Free off contents of imp_sth	*/

    fields = DBIc_NUM_FIELDS(imp_sth);
    imp_sth->in_cache    = 0;
    imp_sth->eod_errno = 1403;
    for(i=0; i < fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	fb_ary_free(fbh->fb_ary);
    }
    Safefree(imp_sth->fbh);
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
		phs_t *phs_tpl = (phs_t*)(void*)SvPVX(sv);
		sv_free(phs_tpl->sv);
	    }
	}
	sv_free((SV*)imp_sth->all_params_hv);
    }

    DBIc_IMPSET_off(imp_sth);		/* let DBI know we've done it	*/
}


int
dbd_st_STORE_attrib(sth, keysv, valuesv)
    SV *sth;
    SV *keysv;
    SV *valuesv;
{
    return FALSE;
#ifdef not_used_yet
    D_imp_sth(sth);
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    int on = SvTRUE(valuesv);
    SV *cachesv = NULL;
    int oraperl = DBIc_COMPAT(imp_sth);

    if (cachesv) /* cache value for later DBI 'quick' fetch? */
	hv_store((HV*)SvRV(sth), key, kl, cachesv, 0);
    return TRUE;
#endif
}


SV *
dbd_st_FETCH_attrib(sth, keysv)
    SV *sth;
    SV *keysv;
{
    D_imp_sth(sth);
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
	/* dbd_describe has already called ora_error()		*/
	/* we can't return Nullsv here because the xs code will	*/
	/* then just pass the attribute name to DBI for FETCH.	*/
	croak("Describe failed during %s->FETCH(%s)",
		SvPV(sth,na), key);
    }

    i = DBIc_NUM_FIELDS(imp_sth);

    if (kl==11 && strEQ(key, "ora_lengths")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv((IV)imp_sth->fbh[i].dsize));

    } else if (kl==9 && strEQ(key, "ora_types")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv(imp_sth->fbh[i].dbtype));

    } else if (kl==9 && strEQ(key, "ora_rowid")) {
	/* return current _binary_ ROWID (oratype 11) uncached	*/
	/* Use { ora_type => 11 } when binding to a placeholder	*/
	retsv = newSVpv((char*)&imp_sth->cda->rid, sizeof(imp_sth->cda->rid));
	cacheit = FALSE;

    } else if (kl==4 && strEQ(key, "NAME")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSVpv((char*)imp_sth->fbh[i].cbuf,0));

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

