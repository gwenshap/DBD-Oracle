/*
   $Id: oci7.c,v 1.6 1999/03/10 20:42:24 timbo Exp $

   Copyright (c) 1994,1995,1996,1997,1998  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#include "Oracle.h"


#ifdef OCI_V8_SYNTAX

	/* see oci8.c	*/

#else

DBISTATE_DECLARE;

static SV *ora_long;
static SV *ora_trunc;
static SV *ora_cache;
static SV *ora_cache_o;		/* for ora_open() cache override */

void
dbd_init_oci(dbistate)
    dbistate_t *dbistate;
{
    DBIS = dbistate;
    ora_long     = perl_get_sv("Oraperl::ora_long",      GV_ADDMULTI);
    ora_trunc    = perl_get_sv("Oraperl::ora_trunc",     GV_ADDMULTI);
    ora_cache    = perl_get_sv("Oraperl::ora_cache",     GV_ADDMULTI);
    ora_cache_o  = perl_get_sv("Oraperl::ora_cache_o",   GV_ADDMULTI);
}


void
ora_error(h, lda, rc, what)
    SV *h;
    Lda_Def *lda;
    int	rc;
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
	if (what) {
	    sv_catpv(errstr, " (DBD: ");
	    sv_catpv(errstr, what);
	    sv_catpv(errstr, ")");
	}
    }
    else sv_setpv(errstr, what);
    DBIh_EVENT2(h, ERROR_event, DBIc_ERR(imp_xxh), errstr);
}


int
dbd_describe(h, imp_sth)
    SV *h;
    imp_sth_t *imp_sth;
{
    static sb4 *f_cbufl;		/* XXX not thread safe	*/
    static U32  f_cbufl_max;

    D_imp_dbh_from_sth;
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

#ifndef FT_SELECT
#define FT_SELECT 4
#endif
    if (imp_sth->cda->ft != FT_SELECT) {
	if (dbis->debug >= 2)
	    fprintf(DBILOGFP,
		"    dbd_describe skipped for non-select (sql f%d, lb %ld, csr 0x%lx)\n",
		imp_sth->cda->ft, (long)long_buflen, (long)imp_sth->cda);
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    if (dbis->debug >= 2)
	fprintf(DBILOGFP,
	    "    dbd_describe (for sql f%d after oci f%d, lb %ld, csr 0x%lx)...\n",
	    imp_sth->cda->ft, imp_sth->cda->fc, (long)long_buflen, (long)imp_sth->cda);

    if (!f_cbufl) {
	f_cbufl_max = 120;
	New(1, f_cbufl, f_cbufl_max, sb4);
    }

    /* number of rows to cache	*/
    if      (SvOK(ora_cache_o)) imp_sth->cache_rows = SvIV(ora_cache_o);
    else if (SvOK(ora_cache))   imp_sth->cache_rows = SvIV(ora_cache);
    else                        imp_sth->cache_rows = imp_dbh->RowCacheSize;

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
	    if (ora_dbtype_is_long(dbtype)) {
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
	fbh->name    = (char*)cbuf_ptr;
	fbh->cbufl   = f_cbufl[i];
	/* DESCRIBE */
	odescr(imp_sth->cda, i,
		&fbh->dbsize, &fbh->dbtype, (sb1*)fbh->name,  &fbh->cbufl,
		&fbh->disize, &fbh->prec,   &fbh->scale, &fbh->nullok);
	fbh->name[fbh->cbufl] = '\0';	 /* ensure null terminated	*/
	cbuf_ptr += fbh->cbufl + 1;	 /* increment name pointer	*/

	/* Now define the storage for this field data.			*/

	if (fbh->dbtype==23 || fbh->dbtype==24) {	/* RAW types */
	    /* is this the right thing to do? what about longraw? XXX	*/
	    fbh->dbsize *= 2;
	    fbh->disize *= 2;
	}
	else if (fbh->dbtype == 2 && fbh->prec == 0) {
	    fbh->prec = 38;
	}
	else if ((fbh->dbtype == 1 || fbh->dbtype == 96) && fbh->prec == 0) {
	    fbh->prec = fbh->dbsize;
	}

	/* Is it a LONG, LONG RAW, LONG VARCHAR or LONG VARRAW?		*/
	/* If so we need to implement oraperl truncation hacks.		*/
	/* This may change in a future release.				*/
	/* Note that ora_dbtype_is_long() returns alternate dbtype to use	*/
	if ( (dbtype = ora_dbtype_is_long(fbh->dbtype)) ) {
	    fbh->dbsize = long_buflen;
	    fbh->disize = long_buflen;
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
			fbh->disize+1,	/* +1: STRING null terminator   */
			imp_sth->cache_rows
		    );

	/* DEFINE output column variable storage */
	if (odefin(imp_sth->cda, i, fb_ary->abuf, fb_ary->bufl,
		fbh->ftype, -1, fb_ary->aindp, (text*)0, -1, -1,
		fb_ary->arlen, fb_ary->arcode)) {
	    warn("odefin error on %s: %d", fbh->name, imp_sth->cda->rc);
	}

	if (dbis->debug >= 2)
	    dbd_fbh_dump(fbh, i, 0);
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
		dTHR; 				/* for DBIc_ACTIVE_off		*/
		DBIc_ACTIVE_off(imp_sth);	/* eg finish			*/
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

	if (rc == 1406 && ora_dbtype_is_long(fbh->dbtype)) {
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
		if (ora_dbtype_is_long(fbh->dbtype)) {	/* double check */
		    hint = (DBIc_LongReadLen(imp_sth) > 65535)
			 ? ", LongTruncOk not set and/or LongReadLen too small or > 65535 max"
			 : ", LongTruncOk not set and/or LongReadLen too small";
		}
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

	if (debug >= 5)
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


/* ------------------------------------------------------------ */



int
dbd_st_prepare(sth, imp_sth, statement, attribs)
    SV *sth;
    imp_sth_t *imp_sth;
    char *statement;
    SV *attribs;
{
    D_imp_dbh_from_sth;
    ub4   oparse_lng   = 1;  /* auto v6 or v7 as suits db connected to	*/

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

    if (attribs) {
	SV **svp;
	DBD_ATTRIB_GET_IV(  attribs, "ora_parse_lang", 14, svp, oparse_lng);
    }

    /* scan statement for '?', ':1' and/or ':foo' style placeholders	*/
    dbd_preparse(imp_sth, statement);

    if (oopen(&imp_sth->cdabuf, imp_dbh->lda, (text*)0, -1, -1, (text*)0, -1)) {
        ora_error(sth, &imp_sth->cdabuf, imp_sth->cdabuf.rc, "oopen error");
        return 0;
    }
    imp_sth->cda = &imp_sth->cdabuf;

    /* parse the (possibly edited) SQL statement */
    imp_sth->cda->peo = 0;
    if (oparse(imp_sth->cda, (text*)imp_sth->statement, (sb4)-1,
                (sword)0/*oparse_defer*/, (ub4)oparse_lng)
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
	oclose(imp_sth->cda);	/* close the cursor		*/
	imp_sth->cda = NULL;
	return 0;
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

#endif
