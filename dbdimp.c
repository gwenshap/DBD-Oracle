/*
   $Id: dbdimp.c,v 1.14 1996/03/05 02:27:25 timbo Exp $

   Copyright (c) 1994,1995  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file.

*/

#include "Oracle.h"


DBISTATE_DECLARE;

static SV *ora_long;
static SV *ora_trunc;


void
dbd_init(dbistate)
    dbistate_t *dbistate;
{
    DBIS = dbistate;
    ora_long  = perl_get_sv("Oraperl::ora_long",  GV_ADDMULTI);
    ora_trunc = perl_get_sv("Oraperl::ora_trunc", GV_ADDMULTI);
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
    if (lda) {	/* is oracle error (allow for non-oracle errors) */
	int len;
	char msg[1024];
	/* Oracle oerhms can do duplicate free if connect fails */
	/* Ignore 'with different width due to prototype' gcc warning	*/
	oerhms(lda, rc, (text*)msg, sizeof(msg));
	len = strlen(msg);
	if (len && msg[len-1] == '\n')
	    msg[len-1] = '\0'; /* trim off \n from end of message */
	sv_setpv(errstr, (char*)msg);
    }
    else sv_setpv(errstr, what);
    sv_setiv(DBIc_ERR(imp_xxh), (IV)rc);
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
fbh_dump(fbh, i)
    imp_fbh_t *fbh;
    int i;
{
    FILE *fp = DBILOGFP;
    fprintf(fp, "fbh %d: '%s' %s, ",
		i, fbh->cbuf, (fbh->nullok) ? "NULLable" : "");
    fprintf(fp, "type %d,  dbsize %ld, dsize %ld, p%d s%d\n",
	    fbh->dbtype, (long)fbh->dbsize, (long)fbh->dsize,
	    fbh->prec, fbh->scale);
    fprintf(fp, "   out: ftype %d, indp %d, bufl %d, rlen %d, rcode %d\n",
	    fbh->ftype, fbh->indp, fbh->bufl, fbh->rlen, fbh->rcode);
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


/* ================================================================== */


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

    /* can give duplicate free errors (from Oracle) if connect fails */
    ret = orlon(&imp_dbh->lda, imp_dbh->hda, (text*)uid,-1, (text*)pwd,-1,0);
    if (ret) {
	ora_error(dbh, &imp_dbh->lda, imp_dbh->lda.rc, "login failed");
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
dbd_db_STORE(dbh, keysv, valuesv)
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
	/* Ignore SvTRUE warning: '=' where '==' may have been intended. */
	if ( (on) ? ocon(&imp_dbh->lda) : ocof(&imp_dbh->lda) ) {
	    ora_error(dbh, &imp_dbh->lda, imp_dbh->lda.rc, "ocon/ocof failed");
	    /* XXX um, we can't return FALSE and true isn't acurate */
	    /* the best we can do is cache an undef	*/
	    cachesv = &sv_undef;
	} else {
	    cachesv = (on) ? &sv_yes : &sv_no;	/* cache new state */
	}
    } else {
	return FALSE;
    }
    if (cachesv) /* cache value for later DBI 'quick' fetch? */
	hv_store((HV*)SvRV(dbh), key, kl, cachesv, 0);
    return TRUE;
}


SV *
dbd_db_FETCH(dbh, keysv)
    SV *dbh;
    SV *keysv;
{
    /* D_imp_dbh(dbh); */
    STRLEN kl;
    char *key = SvPV(keysv,kl);
    SV *retsv = NULL;
    /* Default to caching results for DBI dispatch quick_FETCH	*/
    int cacheit = TRUE;

    if (1) {		/* no attribs defined yet	*/
	return Nullsv;
    }
    if (cacheit) {	/* cache for next time (via DBI quick_FETCH)	*/
	hv_store((HV*)SvRV(dbh), key, kl, retsv, 0);
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
                (sword)oparse_defer, (ub4)oparse_lng)) {
	SV  *msgsv;
	char msg[99];
	sprintf(msg,"possibly parse error at character %d of %d in '",
	    imp_sth->cda->peo+1, (int)strlen(imp_sth->statement));
	msgsv = sv_2mortal(newSVpv(msg,0));
	sv_catpv(msgsv, imp_sth->statement);
	sv_catpv(msgsv, "'");
        ora_error(sth, imp_sth->cda, imp_sth->cda->rc, SvPV(msgsv,na));
	oclose(imp_sth->cda);	/* close the cursor	*/
        return 0;
    }

    /* long_buflen:	length for long/longraw (if >0)  */
    /* long_trunc_ok:	is truncating a long an error    XXX not implemented */

    if (DBIc_COMPAT(imp_sth)) {		/* is an Oraperl handle		*/
	imp_sth->long_buflen   = SvIV(ora_long);
	/* ora_trunc is checked at fetch time */
    } else {
	imp_sth->long_buflen   = 80;	/* typical oracle default	*/
	imp_sth->long_trunc_ok = 1;	/* can use blob_read()		*/
    }

    /* Describe and allocate storage for results. This could	*/
    /* and possibly should be deferred until execution or some	*/
    /* output related information is fetched.			*/
/* defered
    if (!dbd_describe(dbh, imp_sth)) {
	return 0;
    }
*/
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

    /* allocate room for copy of statement with spare capacity	*/
    /* for editing ':1' into ':p1' so we can use obndrv.	*/
    imp_sth->statement = (char*)safemalloc(strlen(statement) + 100);

    /* initialise phs ready to be cloned per placeholder	*/
    memset(&phs_tpl, sizeof(phs_tpl), 0);
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
	if (laststyle && style != laststyle)
	    croak("Can't mix placeholder styles (%d/%d)",style,laststyle);
	laststyle = style;
	if (imp_sth->bind_names == NULL)
	    imp_sth->bind_names = newHV();
	phs_tpl.sv = &sv_undef;
	phs_sv = newSVpv((char*)&phs_tpl, sizeof(phs_tpl));
	hv_store(imp_sth->bind_names, start, (STRLEN)(dest-start),
		phs_sv, 0);
	/* warn("bind_names: '%s'\n", start);	*/
    }
    *dest = '\0';
    if (imp_sth->bind_names) {
	DBIc_NUM_PARAMS(imp_sth) = (int)HvKEYS(imp_sth->bind_names);
	if (dbis->debug >= 2)
	    fprintf(DBILOGFP, "scanned %d distinct placeholders\n",
		(int)DBIc_NUM_PARAMS(imp_sth));
    }
}


int
dbd_bind_ph(sth, ph_namesv, newvalue, attribs)
    SV *sth;
    SV *ph_namesv;
    SV *newvalue;
    SV *attribs;
{
    D_imp_sth(sth);
    SV **svp;
    STRLEN name_len;
    char *name;
    phs_t *phs;

    STRLEN value_len;
    void  *value_ptr;

    if (SvNIOK(ph_namesv) ) {	/* passed as a number	*/
	char buf[90];
	name = buf;
	sprintf(name, ":p%d", (int)SvIV(ph_namesv));
	name_len = strlen(name);
    } else {
	name = SvPV(ph_namesv, name_len);
    }

    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "bind %s <== '%s' (attribs: %s)\n",
		name, SvPV(newvalue,na), attribs ? SvPV(attribs,na) : "" );

    svp = hv_fetch(imp_sth->bind_names, name, name_len, 0);
    if (svp == NULL)
	croak("dbd_bind_ph placeholder '%s' unknown", name);
    phs = (phs_t*)((void*)SvPVX(*svp));		/* placeholder struct	*/

    if (phs->sv == &sv_undef) {	 /* first bind for this placeholder	*/
	phs->sv = newSV(0);
	phs->ftype = 1;
    }

    if (attribs) {
	/* Setup / Clear attributes as defined by attribs.		*/
	/* If attribs is EMPTY then reset attribs to default.		*/
	;	/* XXX */
	if ( (svp=hv_fetch((HV*)SvRV(attribs), "ora_type",0, 0)) == NULL) {
	    if (!dbtype_is_string(SvIV(*svp)))	/* mean but safe	*/
		croak("bind_param %s ora_type %d not a simple string type",
			name, (int)SvIV(*svp));
	    phs->ftype = SvIV(*svp);
	}

    }	/* else if NULL / UNDEF then don't alter attributes.	*/
	/* This approach allows maximum performance when	*/
	/* rebinding parameters often (for multiple executes).	*/

    /* At the moment we always do sv_setsv() and rebind.	*/
    /* Later we may optimise this so that more often we can	*/
    /* just copy the value & length over and not rebind.	*/

    if (SvOK(newvalue)) {
	/* XXX need to consider oraperl null vs space issues?	*/
	/* XXX need to consider taking reference to source var	*/
	sv_setsv(phs->sv, newvalue);
	value_ptr = SvPV(phs->sv, value_len);
	phs->indp = 0;

	/* Since we don't support LONG VAR types we must check	*/
	/* for lengths too big to pass to obndrv as an sword.	*/
	if (value_len > SWORDMAXVAL)	/* generally INT_MAX	*/
	    croak("bind_param %s value is too long (%d bytes, max %d)",
			name, value_len, SWORDMAXVAL);
    } else {
	value_ptr = "";
	value_len = 0;
	phs->indp = -1;
    }

    /* this will change to odndra sometime	*/
    if (obndrv(imp_sth->cda, (text*)name, -1,
	    (ub1*)value_ptr, (sword)value_len,
	    phs->ftype, -1, &phs->indp,
	    (text*)0, -1, -1)) {
	D_imp_dbh_from_sth;
	ora_error(sth, &imp_dbh->lda, imp_sth->cda->rc, "obndrv failed");
	return 0;
    }
    return 1;
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
    int i = 0;

    if (!f_cbufl) {
	f_cbufl_max = 120;
	New(1, f_cbufl, f_cbufl_max, sb4);
    }

    if (imp_sth->done_desc)
	return 1;	/* success, already done it */
    imp_sth->done_desc = 1;

    /* Get number of fields and space needed for field names	*/
    while(++i) {	/* break out within loop		*/
	sb1 cbuf[256];	/* generous max column name length	*/
	sb2 dbtype = 0;	/* workaround for problem log #405032	*/
	if (i >= f_cbufl_max) {
	    f_cbufl_max *= 2;
	    Renew(f_cbufl, f_cbufl_max, sb4);
	}
	f_cbufl[i] = sizeof(cbuf);
	odescr(imp_sth->cda, i, (sb4*)0, &dbtype,
		cbuf, &f_cbufl[i], (sb4*)0, (sb2*)0, (sb2*)0, (sb2*)0);
        if (imp_sth->cda->rc || dbtype == 0)
	    break;
	t_cbufl += f_cbufl[i];
    }
    if (imp_sth->cda->rc && imp_sth->cda->rc != 1007) {
	D_imp_dbh_from_sth;
	ora_error(h, &imp_dbh->lda, imp_sth->cda->rc, "odescr failed");
	return 0;
    }
    imp_sth->cda->rc = 0;
    num_fields = i - 1;
    DBIc_NUM_FIELDS(imp_sth) = num_fields;

    /* allocate field buffers				*/
    Newz(42, imp_sth->fbh,      num_fields, imp_fbh_t);
    /* allocate a buffer to hold all the column names	*/
    Newz(42, imp_sth->fbh_cbuf, t_cbufl + num_fields, char);

    cbuf_ptr = (sb1*)imp_sth->fbh_cbuf;
    for(i=1; i <= num_fields && imp_sth->cda->rc != 10; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i-1];
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
	if ( (dbtype = dbtype_is_long(fbh->dbtype)) ) {
	    sb4 buflen = imp_sth->long_buflen;
	    if (buflen < 0)
		buflen = 80;		/* typical oracle app default	*/
	    fbh->dbsize = buflen;
	    fbh->dsize  = buflen;
	    fbh->ftype  = dbtype;	/* get long in non-var form	*/
	} else {
	    /* for the time being we fetch everything (except longs)	*/
	    /* as strings, that'll change (IV, NV and binary data etc)	*/
	    fbh->ftype = 5;		/* oraperl used 5 'STRING'	*/
	    /* dbsize can be zero for 'select NULL ...'			*/
	}

	fbh->bufl  = fbh->dsize+1;	/* +1: STRING null terminator	*/

	/* currently we use an sv, later we'll use an array	*/
	fbh->sv = newSV((STRLEN)fbh->bufl);
	(void)SvUPGRADE(fbh->sv, SVt_PV);
	SvREADONLY_on(fbh->sv);
	(void)SvPOK_only(fbh->sv);
	fbh->buf = (ub1*)SvPVX(fbh->sv);

	/* BIND */
	if (odefin(imp_sth->cda, i, fbh->buf, fbh->bufl,
		fbh->ftype, -1, &fbh->indp,
		(text*)0, -1, -1, &fbh->rlen, &fbh->rcode)) {
	    warn("odefin error on %s: %d", fbh->cbuf, imp_sth->cda->rc);
	}

	if (dbis->debug >= 2)
	    fbh_dump(fbh, i);
    }

    if (imp_sth->cda->rc && imp_sth->cda->rc != 1007) {
	D_imp_dbh_from_sth;
	ora_error(h, &imp_dbh->lda, imp_sth->cda->rc, "odescr failed");
	return 0;
    }
    return 1;
}


int
dbd_st_execute(sth)
    SV *sth;
{
    D_imp_sth(sth);

    if (!imp_sth->done_desc) {
	/* describe and allocate storage for results		*/
	if (!dbd_describe(sth, imp_sth))
	    return 0; /* dbd_describe already called ora_error()	*/
    }

    /* Trigger execution of the statement			*/
    if (oexec(imp_sth->cda)) {  /* may change to oexfet later	*/
        ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "oexec error");
	return 0;
    }
    DBIc_ACTIVE_on(imp_sth);
    return 1;
}



AV *
dbd_st_fetch(sth)
    SV *	sth;
{
    D_imp_sth(sth);
    int debug = dbis->debug;
    int num_fields;
    int i;
    AV *av;
    /* Check that execute() was executed sucessfuly. This also implies	*/
    /* that dbd_describe() executed sucessfuly so the memory buffers	*/
    /* are allocated and bound.						*/
    if ( !DBIc_ACTIVE(imp_sth) ) {
	ora_error(sth, NULL, 1, "no statement executing");
	return Nullav;
    }
    /* This will become ofen() once the buffer management is reworked.	*/
    if (ofetch(imp_sth->cda)) {
	if (imp_sth->cda->rc != 1403) {	/* was not just end-of-fetch	*/
	    ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "ofetch error");
	    /* should we ocan() here? */
	} else {
	    sv_setiv(DBIc_ERR(imp_sth), 0);	/* just end-of-fetch	*/
	}
	if (debug >= 3)
	    fprintf(DBILOGFP, "    dbd_st_fetch failed, rc=%d",
		imp_sth->cda->rc);
	return Nullav;
    }

    av = DBIS->get_fbav(imp_sth);
    num_fields = AvFILL(av)+1;

    if (debug >= 3)
	fprintf(DBILOGFP, "    dbd_st_fetch %d fields\n", num_fields);

    for(i=0; i < num_fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	int rc = fbh->rcode;
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
	    SvCUR(fbh->sv) = fbh->rlen;
	    sv_setsv(sv, fbh->sv);	/* XXX can be optimised later	*/

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
    /* We don't close the cursor till DESTROY.                  */
    /* The application may re execute it.			*/
    if (DBIc_ACTIVE(imp_sth) && ocan(imp_sth->cda) ) {
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

    for(i=0; i < DBIc_NUM_FIELDS(imp_sth); ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	sv_free(fbh->sv);
    }
    safefree(imp_sth->fbh);
    safefree(imp_sth->fbh_cbuf);
    safefree(imp_sth->statement);

    if (imp_sth->bind_names) {
	HV *hv = imp_sth->bind_names;
	SV *sv;
	char *key;
	I32 retlen;
	hv_iterinit(hv);
	while( (sv = hv_iternextsv(hv, &key, &retlen)) != NULL ) {
	    phs_t *phs_tpl;
	    if (sv != &sv_undef) {
		phs_tpl = (phs_t*)SvPVX(sv);
		sv_free(phs_tpl->sv);
	    }
	}
	sv_free((SV*)imp_sth->bind_names);
    }

    DBIc_IMPSET_off(imp_sth);		/* let DBI know we've done it	*/
}


int
dbd_st_STORE(sth, keysv, valuesv)
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
dbd_st_FETCH(sth, keysv)
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
	retsv = newRV((SV*)av);
	while(--i >= 0)
	    av_store(av, i, newSViv((IV)imp_sth->fbh[i].dsize));

    } else if (kl==9 && strEQ(key, "ora_types")) {
	AV *av = newAV();
	retsv = newRV((SV*)av);
	while(--i >= 0)
	    av_store(av, i, newSViv(imp_sth->fbh[i].dbtype));

    } else if (kl==4 && strEQ(key, "NAME")) {
	AV *av = newAV();
	retsv = newRV((SV*)av);
	while(--i >= 0)
	    av_store(av, i, newSVpv((char*)imp_sth->fbh[i].cbuf,0));

    } else {
	return Nullsv;
    }
    if (cacheit) { /* cache for next time (via DBI quick_FETCH)	*/
	hv_store((HV*)SvRV(sth), key, kl, retsv, 0);
	(void)SvREFCNT_inc(retsv);	/* so sv_2mortal won't free it	*/
    }
    return sv_2mortal(retsv);
}



/* --------------------------------------- */

