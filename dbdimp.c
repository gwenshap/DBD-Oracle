/*
   $Id: dbdimp.c,v 1.40 1998/08/14 18:07:46 timbo Exp $

   Copyright (c) 1994,1995  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#include "Oracle.h"

/* XXX DBI should provide a better version of this */
#define IS_DBI_HANDLE(h) \
    (SvROK(h) && SvTYPE(SvRV(h)) == SVt_PVHV && \
	SvRMAGICAL(SvRV(h)) && (SvMAGIC(SvRV(h)))->mg_type == 'P')

DBISTATE_DECLARE;

static SV *ora_long;
static SV *ora_trunc;
static SV *ora_pad_empty;
static SV *ora_cache;
static SV *ora_cache_o;		/* temp hack for ora_open() cache override */
static int ora_login_nomsg;	/* don't fetch real login errmsg if true  */
static int ora_fetchtest;
static int ora_sigchld_restart = 1;

static void dbd_preparse _((imp_sth_t *imp_sth, char *statement));


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
	ora_login_nomsg = atoi(getenv("DBD_ORACLE_LOGIN_NOMSG"));
    if (getenv("DBD_ORACLE_SIGCHLD"))
	ora_sigchld_restart = atoi(getenv("DBD_ORACLE_SIGCHLD"));
}


int
dbd_discon_all(drh, imp_drh)
    SV *drh;
    imp_drh_t *imp_drh;
{
    dTHR;

    /* The disconnect_all concept is flawed and needs more work */
    if (!dirty && !SvTRUE(perl_get_sv("DBI::PERL_ENDING",0))) {
	sv_setiv(DBIc_ERR(imp_drh), (IV)1);
	sv_setpv(DBIc_ERRSTR(imp_drh),
		(char*)"disconnect_all not implemented");
	DBIh_EVENT2(drh, ERROR_event,
		DBIc_ERR(imp_drh), DBIc_ERRSTR(imp_drh));
	return FALSE;
    }
    if (perl_destruct_level)
	perl_destruct_level = 0;
    return FALSE;
}


/* Database specific error handling.
	This will be split up into specific routines
	for dbh and sth level.
	Also split into helper routine to set number & string.
	Err, many changes needed, ramble ...
*/

static void
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


static void
fbh_dump(fbh, i, aidx)
    imp_fbh_t *fbh;
    int i;
    int aidx;	/* array index */
{
    FILE *fp = DBILOGFP;
    fprintf(fp, "    fbh %d: '%s' %s, ",
		i, fbh->cbuf, (fbh->nullok) ? "NULLable" : "");
    fprintf(fp, "type %d,  dbsize %ld, dsize %ld, p%d s%d\n",
	    fbh->dbtype, (long)fbh->dbsize, (long)fbh->dsize,
	    fbh->prec, fbh->scale);
    fprintf(fp, "      out: ftype %d, bufl %d. cache@%d: indp %d, rlen %d, rcode %d\n",
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
oratype_bind_ok(dbtype)	/* It's a type we support for placeholders */
    int dbtype;
{
    /* basically we support types that can be returned as strings */
    switch(dbtype) {
    case  1:	/* VARCHAR2	*/
    case  5:	/* STRING	*/
    case  8:	/* LONG		*/
    case 23:	/* RAW		*/
    case 24:	/* LONG RAW	*/
    case 96:	/* CHAR		*/
    case 97:	/* CHARZ	*/
    case 106:	/* MLSLABEL	*/
#ifdef SQLT_CUR
    case SQLT_CUR:	/* cursor variable */
#endif
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



/* ================================================================== */

int
dbd_db_login(dbh, imp_dbh, dbname, uid, pwd)
    SV *dbh;
    imp_dbh_t *imp_dbh;
    char *dbname;
    char *uid;
    char *pwd;
{

    dTHR;
    int ret;

    imp_dbh->lda = &imp_dbh->ldabuf;
    imp_dbh->hda = &imp_dbh->hdabuf[0];
    /* can give duplicate free errors (from Oracle) if connect fails	*/
    ret = orlon(imp_dbh->lda, imp_dbh->hda, (text*)uid,-1, (text*)pwd,-1,0);

    if (ret) {
	int rc = imp_dbh->lda->rc;
	char buf[100];
	char *msg;
	switch(rc) {	/* add helpful hints to some errors */
	case    0: msg = "login failed, check ORACLE_HOME/bin is on your PATH";  break;
	case 1019: msg = "login failed, probably a symptom of a deeper problem"; break;
	default:   msg = "login failed"; break;
	}
	if (ora_login_nomsg) {
	    /* oerhms in ora_error may hang or corrupt memory (!) after a connect */
	    /* failure in some specific versions of Oracle 7.3.x. So we provide a */
	    /* way to skip the message lookup if ora_login_nomsg is true (set via */
	    /* env var above). */
	    sprintf(buf, 
		"ORA-%05d: (Text for error %d not fetched. Use 'oerr ORA %d' command.)",
		rc, rc, rc);
	    msg = buf;
	}
	ora_error(dbh,	ora_login_nomsg ? NULL : imp_dbh->lda, rc, msg);
	return 0;
    }

#ifdef SA_RESTART
#ifndef SIGCLD
#define SIGCLD SIGCHLD
#endif
    /* If orlon has installed a handler for SIGCLD, then reinstall it	*/
    /* with SA_RESTART.  We only do this if connected ok since I've	*/
    /* seen the process loop after being interrupted after connect failed. */
    if (ora_sigchld_restart) {
	struct sigaction act;
	if (sigaction( SIGCLD, (struct sigaction*)0, &act ) == 0
		&&  (act.sa_handler != SIG_DFL && act.sa_handler != SIG_IGN)
		&&  (act.sa_flags & SA_RESTART) == 0) {
	    /* XXX we should also check that act.sa_handler is not the perl handler */
	    act.sa_flags |= SA_RESTART;
	    sigaction( SIGCLD, &act, (struct sigaction*)0 );
	    if (dbis->debug >= 3)
		warn("dbd_db_login: sigaction errno %d, handler %lx, flags %lx",
			errno,act.sa_handler,act.sa_flags);
	    if (dbis->debug >= 2)
		fprintf(DBILOGFP, "    dbd_db_login: set SA_RESTART on Oracle SIGCLD handler.\n");
	}
    }  
#endif    /* HAS_SIGACTION */

    DBIc_IMPSET_on(imp_dbh);	/* imp_dbh set up now			*/
    DBIc_ACTIVE_on(imp_dbh);	/* call disconnect before freeing	*/
    return 1;
}


int
dbd_db_commit(dbh, imp_dbh)
    SV *dbh;
    imp_dbh_t *imp_dbh;
{
    if (ocom(imp_dbh->lda)) {
	ora_error(dbh, imp_dbh->lda, imp_dbh->lda->rc, "commit failed");
	return 0;
    }
    return 1;
}

int
dbd_db_rollback(dbh, imp_dbh)
    SV *dbh;
    imp_dbh_t *imp_dbh;
{
    if (orol(imp_dbh->lda)) {
	ora_error(dbh, imp_dbh->lda, imp_dbh->lda->rc, "rollback failed");
	return 0;
    }
    return 1;
}


int
dbd_db_disconnect(dbh, imp_dbh)
    SV *dbh;
    imp_dbh_t *imp_dbh;
{
    dTHR;

    /* We assume that disconnect will always work	*/
    /* since most errors imply already disconnected.	*/
    DBIc_ACTIVE_off(imp_dbh);
    if (ologof(imp_dbh->lda)) {
	ora_error(dbh, imp_dbh->lda, imp_dbh->lda->rc, "disconnect error");
	return 0;
    }
    /* We don't free imp_dbh since a reference still exists	*/
    /* The DESTROY method is the only one to 'free' memory.	*/
    /* Note that statement objects may still exists for this dbh!	*/
    return 1;
}


void
dbd_db_destroy(dbh, imp_dbh)
    SV *dbh;
    imp_dbh_t *imp_dbh;
{
    if (DBIc_ACTIVE(imp_dbh))
	dbd_db_disconnect(dbh, imp_dbh);
    /* Nothing in imp_dbh to be freed	*/
    DBIc_IMPSET_off(imp_dbh);
}


int
dbd_db_STORE_attrib(dbh, imp_dbh, keysv, valuesv)
    SV *dbh;
    imp_dbh_t *imp_dbh;
    SV *keysv;
    SV *valuesv;
{
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    SV *cachesv = NULL;
    int on = SvTRUE(valuesv);

    if (kl==10 && strEQ(key, "AutoCommit")) {
	if ( (on) ? ocon(imp_dbh->lda) : ocof(imp_dbh->lda) ) {
	    ora_error(dbh, imp_dbh->lda, imp_dbh->lda->rc, "ocon/ocof failed");
	    /* XXX um, we can't return FALSE and true isn't acurate so we croak */
	    croak(SvPV(DBIc_ERRSTR(imp_dbh),na));
	}
	DBIc_set(imp_dbh,DBIcf_AutoCommit, on);
    } else {
	return FALSE;
    }
    if (cachesv) /* cache value for later DBI 'quick' fetch? */
	hv_store((HV*)SvRV(dbh), key, kl, cachesv, 0);
    return TRUE;
}


SV *
dbd_db_FETCH_attrib(dbh, imp_dbh, keysv)
    SV *dbh;
    imp_dbh_t *imp_dbh;
    SV *keysv;
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

static int
get_cursor(imp_dbh, sth, imp_sth)
    imp_dbh_t *imp_dbh;
    SV *sth;
    imp_sth_t *imp_sth;
{
    if (oopen(&imp_sth->cdabuf, imp_dbh->lda, (text*)0, -1, -1, (text*)0, -1)) {
        ora_error(sth, &imp_sth->cdabuf, imp_sth->cdabuf.rc, "oopen error");
        return 0;
    }
    imp_sth->cda = &imp_sth->cdabuf;
    return 1;
}

static int
free_cursor(sth, imp_sth)
    SV *sth;
    imp_sth_t *imp_sth;
{
    if (!imp_sth->cda)
	return 0;

    if (DBIc_ACTIVE(imp_sth)) /* should never happen here	*/
	ocan(imp_sth->cda);   /* XXX probably not needed before oclose */

    if (oclose(imp_sth->cda)) {	/* close the cursor		*/
	/* Check for ORA-01041: 'hostdef extension doesn't exist' ? XXX	*/
	/* which indicates that the lda had already been logged out	*/
	/* in which case only complain if not in 'global destruction'?	*/
	ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oclose error");
	return 0;
    }
    imp_sth->cda = NULL;
    return 1;
}


int
dbd_st_prepare(sth, imp_sth, statement, attribs)
    SV *sth;
    imp_sth_t *imp_sth;
    char *statement;
    SV *attribs;
{
    D_imp_dbh_from_sth;
    sword oparse_defer = 0;  /* PARSE_NO_DEFER */
    ub4   oparse_lng   = 1;  /* auto v6 or v7 as suits db connected to	*/

    imp_sth->done_desc = 0;

    if (DBIc_COMPAT(imp_sth)) {
	imp_sth->ora_pad_empty = (SvOK(ora_pad_empty)) ? SvIV(ora_pad_empty) : 0;
    }

    if (attribs) {
	SV **svp;
	DBD_ATTRIB_GET_IV(  attribs, "ora_parse_lang", 14, svp, oparse_lng);
	DBD_ATTRIB_GET_BOOL(attribs, "ora_parse_defer",15, svp, oparse_defer);
    }

    if (!get_cursor(imp_dbh, sth, imp_sth)) {
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
	char buf[99];
	char *hint = "";
	if (1) {	/* XXX could make optional one day */
	    SV  *msgsv, *sqlsv;
	    sprintf(buf,"error possibly near <*> indicator at char %d in '",
		    imp_sth->cda->peo+1);
	    msgsv = sv_2mortal(newSVpv(buf,0));
	    sqlsv = sv_2mortal(newSVpv(imp_sth->statement,0));
	    sv_insert(sqlsv, imp_sth->cda->peo, 0, "<*>",3);
	    sv_catsv(msgsv, sqlsv);
	    sv_catpv(msgsv, "'");
	    hint = SvPV(msgsv,na);
	}
	ora_error(sth, imp_sth->cda, imp_sth->cda->rc, hint);
	free_cursor(sth, imp_sth);
	return 0;
    }

    /* detect warning for pl/sql create errors */
    if (imp_sth->cda->wrn & 32) {
	; /* XXX perl_call_method to get error text ? */
    }

    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "    dbd_st_prepare'd sql f%d\n", imp_sth->cda->ft);

    /* Describe and allocate storage for results.		*/
    if (!dbd_describe(sth, imp_sth)) {
	return 0;
    }
    DBIc_IMPSET_on(imp_sth);
    return 1;
}


static void
dbd_preparse(imp_sth, statement)
    imp_sth_t *imp_sth;
    char *statement;
{
    bool in_literal = FALSE;
    char *src, *start, *dest;
    phs_t phs_tpl;
    SV *phs_sv;
    int idx=0;
    char *style="", *laststyle=Nullch;
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
		*dest++ = *src++;
	    style = ":foo";
	} else {			/* perhaps ':=' PL/SQL construct */
	    continue;
	}
	*dest = '\0';			/* handy for debugging	*/
	namelen = (dest-start);
	if (laststyle && style != laststyle)
	    croak("Can't mix placeholder styles (%s/%s)",style,laststyle);
	laststyle = style;
	if (imp_sth->all_params_hv == NULL)
	    imp_sth->all_params_hv = newHV();
	phs_tpl.sv = &sv_undef;
	phs_sv = newSVpv((char*)&phs_tpl, sizeof(phs_tpl)+namelen+1);
	hv_store(imp_sth->all_params_hv, start, namelen, phs_sv, 0);
	strcpy( ((phs_t*)(void*)SvPVX(phs_sv))->name, start);
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

    I32	long_buflen;
    sb1 *cbuf_ptr;
    int t_cbufl=0;
    I32 num_fields;
    int has_longs = 0;
    int est_width = 0;		/* estimated avg row width (for cache)	*/
    int i = 0;


    if (imp_sth->done_desc)
	return 1;	/* success, already done it */
    imp_sth->done_desc = 1;

    /* ora_trunc is checked at fetch time */
    /* long_buflen:	length for long/longraw (if >0), else 80 (ora app dflt)	*/
    /* Ought to be for COMPAT mode only but was relaxed before LongReadLen existed */
    long_buflen = (SvOK(ora_long) && SvIV(ora_long)>0)
				? SvIV(ora_long) : DBIc_LongReadLen(imp_sth);
    if (long_buflen < 0)		/* trap any sillyness */
	long_buflen = 80;		/* typical oracle app default	*/

    if (imp_sth->cda->ft != FT_SELECT) {
	if (dbis->debug >= 2)
	    fprintf(DBILOGFP,
		"    dbd_describe skipped for non-select (sql f%d, lb %ld, csr 0x%lx)\n",
		imp_sth->cda->ft, (long)long_buflen, (long)imp_sth->cda);
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "    dbd_describe (for sql f%d after oci f%d, lb %ld, csr 0x%lx)...\n",
			imp_sth->cda->ft, imp_sth->cda->fc, (long)long_buflen, (long)imp_sth->cda);

    if (!f_cbufl) {
	f_cbufl_max = 120;
	New(1, f_cbufl, f_cbufl_max, sb4);
    }

    /* number of rows to cache	*/
    if      (SvOK(ora_cache_o)) imp_sth->cache_rows = SvIV(ora_cache_o);
    else if (SvOK(ora_cache))   imp_sth->cache_rows = SvIV(ora_cache);
    else                        imp_sth->cache_rows = 0;   /* auto size	*/

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
	if (imp_sth->cache_rows > 0)
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
	ora_error(h, imp_dbh->lda, imp_sth->cda->rc, "odescr failed");
	return 0;
    }
    imp_sth->cda->rc = 0;
    num_fields = i - 1;
    DBIc_NUM_FIELDS(imp_sth) = num_fields;

    /* --- Setup the row cache for this query --- */

    /* Use guessed average on-the-wire row width calculated above	*/
    /* and add in overhead of 5 bytes per field plus 8 bytes per row.	*/
    /* The n*5+8 was determined by studying SQL*Net v2 packets.		*/
    /* It could probably benefit from a more detailed analysis.		*/
    est_width += num_fields*5 + 8;

    if (has_longs)			/* override/disable caching	*/
	imp_sth->cache_rows = 1;	/* else read_blob can't work	*/

    else if (imp_sth->cache_rows < 1) {	/* automatically size the cache	*/
	int txfr_size;
	/*  0 == try to pick 'optimal' cache for this query (default)	*/
	/* <0 == base cache on target transfer size of -n bytes.	*/
	if (imp_sth->cache_rows == 0) {
	    /* Oracle packets on ethernet have max size of around 1460.	*/
	    /* We'll aim to fill our row cache with slightly less than	*/
	    /* two packets (to err on the safe side and avoid a third	*/
	    /* almost empty packet being generated in some cases).	*/
	    txfr_size = 1460 * 3.6;	/* default transfer/cache size	*/
	}
	else {	/* user is specifying desired transfer size in bytes	*/
	    txfr_size = -imp_sth->cache_rows;
	}
	imp_sth->cache_rows = txfr_size / est_width;	/* maybe 1 or 0	*/
	/* To ensure good performance with large rows (near or larger	*/
	/* than our target transfer size) we set a minimum cache size.	*/
	if (imp_sth->cache_rows < 6)	/* is cache a 'useful' size?	*/
	    imp_sth->cache_rows = (imp_sth->cache_rows>0) ? 6 : 4;
    }
    if (imp_sth->cache_rows > 32767)	/* keep within Oracle's limits  */
	imp_sth->cache_rows = 32767;
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

	if (fbh->dbtype==23 || fbh->dbtype==24) {	/* RAW types */
		/* is this the right thing to do? what about longraw? XXX	*/
		fbh->dbsize *= 2;
		fbh->dsize  *= 2;
	}

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
			imp_sth->cache_rows
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
    imp_sth->est_width = est_width;

    if (dbis->debug >= 2)
	fprintf(DBILOGFP,
	"    dbd_describe'd %d columns (Row bytes: %d max, %d est avg. Cache: %d rows)\n",
	(int)num_fields, imp_sth->t_dbsize, est_width, imp_sth->cache_rows);

    if (imp_sth->cda->rc && imp_sth->cda->rc != 1007) {
	D_imp_dbh_from_sth;
	ora_error(h, imp_dbh->lda, imp_sth->cda->rc, "odescr failed");
	return 0;
    }

    return 1;
}


static int
ora_sql_type(imp_sth, name, sql_type)
    imp_sth_t *imp_sth;
    char *name;
    int sql_type;
{
    switch (sql_type) {
    case SQL_NUMERIC:
    case SQL_DECIMAL:
    case SQL_INTEGER:
    case SQL_SMALLINT:
    case SQL_FLOAT:
    case SQL_REAL:
    case SQL_DOUBLE:
    case SQL_VARCHAR:
	return 1;	/* Oracle VARCHAR2	*/

    case SQL_CHAR:
	return 5;	/* Oracle CHAR		*/

    default:
	if (DBIc_WARN(imp_sth) && imp_sth && name)
	    warn("SQL type %d for '%s' is not fully supported, bound as VARCHAR instead");
	return ora_sql_type(imp_sth, name, SQL_VARCHAR);
    }
}



static void 
_rebind_ph_char(sth, imp_sth, phs, alen_ptr_ptr) 
    SV *sth;
    imp_sth_t *imp_sth;
    phs_t *phs;
    ub2 **alen_ptr_ptr;
{
    STRLEN value_len;

/* for inserting longs: */
/*    sv_insert +4	*/
/*    sv_chop(phs->sv, SvPV(phs->sv,na)+4);	XXX */

    if (dbis->debug >= 2) {
	char *val = neatsvpv(phs->sv,0);
 	fprintf(DBILOGFP, "       bind %s <== %s (", phs->name, val);
 	if (SvOK(phs->sv)) 
 	    fprintf(DBILOGFP, "size %ld/%ld/%ld, ",
 		(long)SvCUR(phs->sv),(long)SvLEN(phs->sv),phs->maxlen);
 	fprintf(DBILOGFP, "ptype %ld, otype %d%s)\n",
 	    SvTYPE(phs->sv), phs->ftype,
 	    (phs->is_inout) ? ", inout" : "");
    }

    /* At the moment we always do sv_setsv() and rebind.	*/
    /* Later we may optimise this so that more often we can	*/
    /* just copy the value & length over and not rebind.	*/

    if (phs->is_inout) {	/* XXX */
	if (SvREADONLY(phs->sv))
	    croak(no_modify);
	if (imp_sth->ora_pad_empty)
	    croak("Can't use ora_pad_empty with bind_param_inout");
	/* phs->sv _is_ the real live variable, it may 'mutate' later	*/
	/* pre-upgrade high to reduce risk of SvPVX realloc/move	*/
	(void)SvUPGRADE(phs->sv, SVt_PVNV);
	/* ensure room for result, 28 is magic number (see sv_2pv)	*/
	SvGROW(phs->sv, (phs->maxlen < 28) ? 28 : phs->maxlen+1);
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
	phs->progv = SvPVX(phs->sv);	/* can be NULL (undef) */
	phs->indp  = -1;
	value_len  = 0;
    }
    if (imp_sth->ora_pad_empty && value_len==0) {
	sv_setpv(phs->sv, " ");
	phs->progv = SvPV(phs->sv, value_len);
    }
    phs->sv_type = SvTYPE(phs->sv);	/* part of mutation check	*/
    phs->maxlen  = SvLEN(phs->sv)-1;	/* avail buffer space	*/

    if (value_len + phs->alen_incnull <= UB2MAXVAL) {
	phs->alen = value_len + phs->alen_incnull;
	*alen_ptr_ptr = &phs->alen;
	if (((IV)phs->alen) > phs->maxlen && phs->indp != -1)
	    croak("panic: _dbd_rebind_ph alen %ld > maxlen %ld", phs->alen,phs->maxlen);
    }
    else {
	phs->alen = 0;
	*alen_ptr_ptr = NULL; /* Can't use alen for long LONGs (>64k) */
	if (phs->is_inout)
	    croak("Can't bind LONG values (>%ld) as in/out parameters", (long)UB2MAXVAL);
    }

    if (dbis->debug >= 3) {
	fprintf(DBILOGFP, "bind %s <== '%.*s' (size %d/%ld, otype %d, indp %d)\n",
 	    phs->name, phs->alen, (phs->progv) ? phs->progv : "",
 	    phs->alen, (long)phs->maxlen, phs->ftype, phs->indp);
    }

}


#ifdef SQLT_CUR
static void 
_rebind_ph_cursor(sth, imp_sth, phs) 
    SV *sth;
    imp_sth_t *imp_sth;
    phs_t *phs;
{
    SV *phs_sth = phs->sv;
    D_impdata(phs_imp_sth, imp_sth_t, phs_sth);

    /* as a short-term hack we use and sacrifice an existing	*/
    /* statement handle. This will be changed later.		*/

    /* close cursor if open (the pl/sql code can/will open it?)	*/
/*
    if (phs_imp_sth->cda)
	free_cursor(phs_sth, phs_imp_sth);
    phs_imp_sth->cda = &phs_imp_sth->cdabuf;
*/

    assert(phs->ftype == SQLT_CUR);
    phs->progv = (void*)phs_imp_sth->cda;
    phs->maxlen = -1;

    warn("Cursor variables not yet supported");
}
#endif


static int 
_dbd_rebind_ph(sth, imp_sth, phs) 
    SV *sth;
    imp_sth_t *imp_sth;
    phs_t *phs;
{
    ub2 *alen_ptr = NULL;

#ifdef SQLT_CUR
    if (phs->ftype == SQLT_CUR) {
	_rebind_ph_cursor(sth, imp_sth, phs);
    }
    else
#endif
	_rebind_ph_char(sth, imp_sth, phs, &alen_ptr);

    /* Since we don't support LONG VAR types we must check	*/
    /* for lengths too big to pass to obndrv as an sword.	*/
    if (phs->maxlen > MINSWORDMAXVAL && sizeof(sword)<4)	/* generally 32K	*/
	croak("Can't bind %s, value is too long (%ld bytes, max %d)",
		    phs->name, phs->maxlen, MINSWORDMAXVAL);

    if (obndra(imp_sth->cda, (text *)phs->name, -1,
	    (ub1*)phs->progv, (sword)phs->maxlen, /* cast reduces max size */
	    (sword)phs->ftype, -1,
	    &phs->indp, alen_ptr, &phs->arcode, 0, (ub4 *)0,
	    (text *)0, -1, -1)) {
	D_imp_dbh_from_sth;
	ora_error(sth, imp_dbh->lda, imp_sth->cda->rc, "obndra failed");
	return 0;
    }
    return 1;
}


int
dbd_bind_ph(sth, imp_sth, ph_namesv, newvalue, sql_type, attribs, is_inout, maxlen)
    SV *sth;
    imp_sth_t *imp_sth;
    SV *ph_namesv;
    SV *newvalue;
    IV sql_type;
    SV *attribs;
    int is_inout;
    IV maxlen;
{
    SV **phs_svp;
    STRLEN name_len;
    char *name;
    char namebuf[30];
    phs_t *phs;

    /* check if placeholder was passed as a number	*/

    if (!SvNIOK(ph_namesv) && !SvPOK(ph_namesv)) {
	SvPV(ph_namesv, na);	/* force SvPOK */
    }
    if (SvNIOK(ph_namesv) || (SvPOK(ph_namesv) && isDIGIT(*SvPVX(ph_namesv)))) {
	sprintf(namebuf, ":p%d", (int)SvIV(ph_namesv));
	name = namebuf;
	name_len = strlen(name);
    }
    else {		/* use the supplied placeholder name directly */
	name = SvPV(ph_namesv, name_len);
	/* could check for leading colon here */
    }

    if (SvTYPE(newvalue) > SVt_PVLV) /* hook for later array logic	*/
	croak("Can't bind a non-scalar value (%s)", neatsvpv(newvalue,0));
    if (SvROK(newvalue) && !IS_DBI_HANDLE(newvalue))
	/* dbi handle allowed for cursor variables */
	croak("Can't bind a reference (%s)", neatsvpv(newvalue,0));
    if (SvTYPE(newvalue) == SVt_PVLV && is_inout)	/* may allow later */
	croak("Can't bind ``lvalue'' mode scalar as inout parameter (currently)");

    if (dbis->debug >= 2) {
	fprintf(DBILOGFP, "         bind %s <== %s (type %ld",
		name, neatsvpv(newvalue,0), (long)sql_type);
	if (is_inout)
	    fprintf(DBILOGFP, ", inout 0x%lx", (long)newvalue);
	if (attribs)
	    fprintf(DBILOGFP, ", attribs: %s", SvPV(attribs,na));
	fprintf(DBILOGFP, ")\n");
    }

    phs_svp = hv_fetch(imp_sth->all_params_hv, name, name_len, 0);
    if (phs_svp == NULL)
	croak("Can't bind unknown placeholder '%s' (%s)", name, neatsvpv(ph_namesv,0));
    phs = (phs_t*)(void*)SvPVX(*phs_svp);	/* placeholder struct	*/

    if (phs->sv == &sv_undef) {	/* first bind for this placeholder	*/
	phs->ftype    = 1;		/* our default type: VARCHAR2	*/
	phs->maxlen   = maxlen;		/* 0 if not inout		*/
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
	}
	if (sql_type)
	    phs->ftype = ora_sql_type(imp_sth, phs->name, sql_type);

	/* some types require the trailing null included in the length.	*/
	phs->alen_incnull = (phs->ftype==SQLT_STR || phs->ftype==SQLT_AVC);

    }
	/* check later rebinds for any changes */
    else if (is_inout != phs->is_inout) {
	croak("Can't rebind or change param %s in/out mode after first bind (%d => %d)",
		phs->name, phs->is_inout , is_inout);
    }
    else if (sql_type && phs->ftype != ora_sql_type(imp_sth, phs->name, sql_type)) {
	croak("Can't change TYPE of param %s to %d after initial bind",
		phs->name, sql_type);
    }

    if (!is_inout) {	/* normal bind to take a (new) copy of current value	*/
	if (phs->sv == &sv_undef)	/* (first time bind) */
	    phs->sv = newSV(0);
	sv_setsv(phs->sv, newvalue);
    }
    else if (newvalue != phs->sv) {
	if (phs->sv)
	    SvREFCNT_dec(phs->sv);
	phs->sv = SvREFCNT_inc(newvalue);	/* point to live var	*/
    }

    return _dbd_rebind_ph(sth, imp_sth, phs);
}


int
dbd_st_execute(sth, imp_sth)	/* <= -2:error, >=0:ok row count, (-1=unknown count) */
    SV *sth;
    imp_sth_t *imp_sth;
{
    dTHR;

    int debug = dbis->debug;
    int outparams = (imp_sth->out_params_av) ? AvFILL(imp_sth->out_params_av)+1 : 0;

    if (!imp_sth->done_desc) {
	/* describe and allocate storage for results (if any needed)	*/
	if (!dbd_describe(sth, imp_sth))
	    return -2; /* dbd_describe already called ora_error()	*/
    }

    if (debug >= 2)
	fprintf(DBILOGFP,
	    "    dbd_st_execute (for sql f%d after oci f%d, outs %d)...\n",
			imp_sth->cda->ft, imp_sth->cda->fc, outparams);

    if (outparams) {	/* check validity of bound SV's	*/
	int i = outparams;
	while(--i >= 0) {
	    phs_t *phs = (phs_t*)(void*)SvPVX(AvARRAY(imp_sth->out_params_av)[i]);
	    /* Make sure we have the value in string format. Typically a number	*/
	    /* will be converted back into a string using the same bound buffer	*/
	    /* so the progv test below will not trip.			*/

	    /* is the value a null? */
	    phs->indp = (SvOK(phs->sv)) ? 0 : -1;

	    /* Some checks for mutated storage since we pointed oracle at it.	*/
	    if (SvTYPE(phs->sv) != phs->sv_type
		    || (SvOK(phs->sv) && !SvPOK(phs->sv))
		    /* SvROK==!SvPOK so cursor (SQLT_CUR) handle will call _dbd_rebind_ph */
		    /* that suits us for now */
		    || SvPVX(phs->sv) != phs->progv
		    || SvCUR(phs->sv) > UB2MAXVAL
	    ) {
		if (!_dbd_rebind_ph(sth, imp_sth, phs))
		    croak("Can't rebind placeholder %s", phs->name);
	    }
	    else {
 		/* String may have grown or shrunk since it was bound	*/
 		/* so tell Oracle about it's current length		*/
		phs->alen = SvCUR(phs->sv) + phs->alen_incnull;
		if (debug >= 2)
 		    fprintf(DBILOGFP,
 		        "      with %s = '%.*s' (len %d/%d, indp %d, otype %d, ptype %ld)\n",
 			phs->name, phs->alen, SvPVX(phs->sv), phs->alen, (int)phs->maxlen,
 			phs->indp, phs->ftype, SvTYPE(phs->sv));
	    }
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
	if (oexfet(imp_sth->cda, (ub4)imp_sth->cache_rows, 0, 0)
		&& imp_sth->cda->rc != 1403 /* other than no more data */ ) {
	    ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oexfet error");
	    return -2;
	}
	imp_sth->in_cache = imp_sth->cda->rpc;	/* cache loaded */
	if (imp_sth->cda->rc == 1403)
	    imp_sth->eod_errno = 1403;
    }
    else {					/* NOT a select */
	if (oexec(imp_sth->cda)) {
	    ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oexec error");
	    return -2;
	}
    }

    if (debug >= 2)
	fprintf(DBILOGFP,
	    "    dbd_st_execute complete (rc%d, w%02x, rpc%ld, eod%d, out%d)\n",
		imp_sth->cda->rc,  imp_sth->cda->wrn,
		imp_sth->cda->rpc, imp_sth->eod_errno,
		imp_sth->has_inout_params);

    if (outparams) {	/* check validity of bound output SV's	*/
	int i = outparams;
	while(--i >= 0) {
	    phs_t *phs = (phs_t*)(void*)SvPVX(AvARRAY(imp_sth->out_params_av)[i]);
	    SV *sv = phs->sv;
	    if (SvROK(sv)) {	/* XXX assume it's a cursor variable sth */
		D_impdata(phs_imp_sth, imp_sth_t, sv);
		if (debug >= 2)
		    fprintf(DBILOGFP,
			"       out %s = %s (oracle cursor 0x%lx, indp %d, arcode %d)\n",
			phs->name, neatsvpv(sv,0), (long)phs_imp_sth->cda,
			phs->indp, phs->arcode);
		/* XXX !!! */
		free_cursor(sth, imp_sth); /* oracle's cdemo5.c does an oclose */
		/* reset cache counters */
		phs_imp_sth->in_cache   = 0;
		phs_imp_sth->next_entry = 0;
		phs_imp_sth->eod_errno  = 0;
		phs_imp_sth->done_desc = 0;
		/* describe and allocate storage for results (if any needed)	*/
		if (!dbd_describe(sv, phs_imp_sth))
		    return -2; /* dbd_describe already called ora_error()	*/
	    }
	    else
 	    /* phs->alen has been updated by Oracle to hold the length of the result	*/
	    if (phs->indp == 0) {			/* is okay	*/
		SvPOK_only(sv);
		SvCUR(sv) = phs->alen;
		*SvEND(sv) = '\0';
		if (debug >= 2)
		    fprintf(DBILOGFP,
			"       out %s = '%s'\t(len %d, arcode %d)\n",
			phs->name, SvPV(sv,na),phs->alen, phs->arcode);
	    }
	    else
	    if (phs->indp > 0 || phs->indp == -2) {	/* truncated	*/
		SvPOK_only(sv);
		SvCUR(sv) = phs->alen;
		*SvEND(sv) = '\0';
		if (debug >= 2)
		    fprintf(DBILOGFP,
			"       out %s = '%s'\t(TRUNCATED from %d to %d, arcode %d)\n",
			phs->name, SvPV(sv,na), phs->indp, phs->alen, phs->arcode);
	    }
	    else
	    if (phs->indp == -1) {			/* is NULL	*/
		(void)SvOK_off(phs->sv);
		if (debug >= 2)
		    fprintf(DBILOGFP,
			"       out %s = undef (NULL, arcode %d)\n",
			phs->name, phs->arcode);
	    }
	    else croak("panic: %s bad indp %d, arcode %d",
		phs->name, phs->indp, phs->arcode);
	}
    }

    if (DBIc_NUM_FIELDS(imp_sth) > 0) {  	/* is a SELECT	*/
	DBIc_ACTIVE_on(imp_sth);
    }
    if (!imp_sth->cda)	/* XXX closed cursor after exe for cursor vars */
	return 0;
    return imp_sth->cda->rpc;	/* row count (0 will be returned as "0E0")	*/
}



AV *
dbd_st_fetch(sth, imp_sth)
    SV *	sth;
    imp_sth_t *imp_sth;
{
    int debug = dbis->debug;
    int num_fields;
    int ChopBlanks;
    int err = 0;
    int i;
    AV *av;

    if (!imp_sth->in_cache) {	/* refill cache if empty	*/
	int previous_rpc;

	/* Check that execute() was executed sucessfully. This also implies	*/
	/* that dbd_describe() executed sucessfuly so the memory buffers	*/
	/* are allocated and bound.						*/
	if ( !DBIc_ACTIVE(imp_sth) ) {
	    ora_error(sth, NULL, 1, "no statement executing (perhaps you need to call execute first)");
	    return Nullav;
	}

	if (imp_sth->eod_errno) {
    end_of_data:
	    if (imp_sth->eod_errno != 1403) {	/* was not just end-of-fetch	*/
		ora_error(sth, imp_sth->cda, imp_sth->eod_errno, "cached ofetch error");
	    } else {				/* is simply no more data	*/
		sv_setiv(DBIc_ERR(imp_sth), 0);	/* ensure errno set to 0 here	*/
		if (debug >= 2)
		    fprintf(DBILOGFP, "    dbd_st_fetch no-more-data, rc=%d, rpc=%ld\n",
			imp_sth->cda->rc, imp_sth->cda->rpc);
	    }
	    /* further fetches without an execute will arrive back here	*/
	    return Nullav;
	}

	previous_rpc = imp_sth->cda->rpc;	/* remember rpc before re-fetch	*/
	if (ofen(imp_sth->cda, imp_sth->cache_rows)) {
	    /* Note that errors may happen after one or more rows have been	*/
	    /* added to the cache. We record the error but don't handle it till	*/
	    /* the cache is empty (which may be at once if no rows returned).	*/
	    imp_sth->eod_errno = imp_sth->cda->rc;	/* store rc for later	*/
	    if (imp_sth->cda->rpc == previous_rpc)	/* no more rows fetched	*/
		goto end_of_data;
	    /* else fall through and return the first of the fetched rows	*/
	}
	imp_sth->next_entry = 0;
	imp_sth->in_cache   = imp_sth->cda->rpc - previous_rpc;
	assert(imp_sth->in_cache > 0);
    }

    av = DBIS->get_fbav(imp_sth);
    num_fields = AvFILL(av)+1;

    if (debug >= 3)
	fprintf(DBILOGFP, "    dbd_st_fetch %d fields, rpc %ld (cache: %d/%d/%d)\n",
		num_fields, (long)imp_sth->cda->rpc, imp_sth->next_entry,
		imp_sth->in_cache, imp_sth->cache_rows);

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
	    int datalen = fb_ary->arlen[cache_entry];
	    char *p = (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl];
	    /* if ChopBlanks check for Oracle CHAR type (blank padded)	*/
	    if (ChopBlanks && fbh->dbtype == 96) {
		while(datalen && p[datalen - 1]==' ')
		    --datalen;
	    }
	    sv_setpvn(sv, p, (STRLEN)datalen);

	} else if (rc == 1405) {	/* field is null - return undef	*/
	    (void)SvOK_off(sv);

	} else {  /* See odefin rcode arg description in OCI docs	*/
	    char buf[200];
	    char *hint = "";
	    /* These may get more case-by-case treatment eventually.	*/
	    if (rc == 1406) {		/* field truncated (see above)  */
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
	    sprintf(buf,"ofetch error on field %d (of %d), ora_type %d%s",
			i+1, num_fields, fbh->dbtype, hint);
	    ora_error(sth, imp_sth->cda, rc, buf);
	}

	if (debug >= 3)
	    fprintf(DBILOGFP, "        %d (rc=%d): %s\n",
		i, rc, neatsvpv(sv,0));
    }

    /* update cache counters */
    if (ora_fetchtest)			/* unless we're testing performance */
	--ora_fetchtest;
    else {
	--imp_sth->in_cache;
	++imp_sth->next_entry;
    }

    return (err) ? Nullav : av;
}




int
dbd_st_blob_read(sth, imp_sth, field, offset, len, destrv, destoffset)
    SV *sth;
    imp_sth_t *imp_sth;
    int field;
    long offset;
    long len;
    SV *destrv;
    long destoffset;
{
    ub4 retl;
    SV *bufsv;

    bufsv = SvRV(destrv);
    sv_setpvn(bufsv,"",0);	/* ensure it's writable string	*/
    SvGROW(bufsv, len+destoffset+1);	/* SvGROW doesn't do +1	*/

	/* The +1 on field was a mistake tht's too late to fix :-(	*/
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
dbd_st_rows(sth, imp_sth)
    SV *sth;
    imp_sth_t *imp_sth;
{
    /* spot common mistake of checking $h->rows just after ->execute	*/
    if (   imp_sth->in_cache > 0		 /* has unfetched rows	*/
	&& imp_sth->in_cache== imp_sth->cda->rpc /* NO rows fetched yet	*/
	&& DBIc_WARN(imp_sth)	/* provide a way to disable warning	*/
    ) {
	warn("$h->rows count is incomplete before all rows fetched.\n");
    }
    /* imp_sth->in_cache should always be 0 for non-select statements	*/
    return imp_sth->cda->rpc - imp_sth->in_cache;	/* fetched rows	*/
}


int
dbd_st_finish(sth, imp_sth)
    SV *sth;
    imp_sth_t *imp_sth;
{
    dTHR;

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
dbd_st_destroy(sth, imp_sth)
    SV *sth;
    imp_sth_t *imp_sth;
{
    D_imp_dbh_from_sth;
    int fields;
    int i;

    /* dbd_st_finish has already been called by .xs code if needed.	*/

    /* Check if an explicit disconnect() or global destruction has	*/
    /* disconnected us from the database before attempting to close.	*/
    if (DBIc_ACTIVE(imp_dbh)) {
	free_cursor(sth, imp_sth);		/* ignore errors here	*/
	/* fall through anyway to free up our memory */
    } 

    /* Free off contents of imp_sth	*/

    fields = DBIc_NUM_FIELDS(imp_sth);
    imp_sth->in_cache  = 0;
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
dbd_st_STORE_attrib(sth, imp_sth, keysv, valuesv)
    SV *sth;
    imp_sth_t *imp_sth;
    SV *keysv;
    SV *valuesv;
{
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    int on = SvTRUE(valuesv);
    SV *cachesv = NULL;
/*  int oraperl = DBIc_COMPAT(imp_sth); */

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
dbd_st_FETCH_attrib(sth, imp_sth, keysv)
    SV *sth;
    imp_sth_t *imp_sth;
    SV *keysv;
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

    } else if (kl==17 && strEQ(key, "ora_est_row_width")) {
	retsv = newSViv(imp_sth->est_width);
	cacheit = TRUE;

    } else if (kl==14 && strEQ(key, "ora_cache_rows")) {
	retsv = newSViv(imp_sth->cache_rows);
	cacheit = TRUE;

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

