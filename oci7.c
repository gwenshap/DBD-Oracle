/*
   $Id: oci7.c,v 1.16 2003/03/13 14:28:50 timbo Exp $

   Copyright (c) 1994,1995,1996,1997,1998,1999  Tim Bunce

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

/* JLU: Looks like these are being moved to imp_drh... */
#if 0
static SV *ora_long; 
static SV *ora_trunc;
static SV *ora_cache;
static SV *ora_cache_o;		/* for ora_open() cache override */
#endif

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
    D_imp_drh_from_dbh;
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
    long_buflen = (SvOK(imp_drh->ora_long) && SvIV(imp_drh->ora_long)>0)
				? SvIV(imp_drh->ora_long) : DBIc_LongReadLen(imp_sth);
    if (long_buflen < 0)		/* trap any sillyness */
	long_buflen = 80;		/* typical oracle app default	*/

#ifndef FT_SELECT
#define FT_SELECT 4
#endif
    if (imp_sth->cda->ft != FT_SELECT) {
	if (DBIS->debug >= 3)
	    PerlIO_printf(DBILOGFP,
		"    dbd_describe skipped for non-select (sql f%d, lb %ld, csr 0x%lx)\n",
		imp_sth->cda->ft, (long)long_buflen, (long)imp_sth->cda);
	/* imp_sth memory was cleared when created so no setup required here	*/
	return 1;
    }

    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP,
	    "    dbd_describe (for sql f%d after oci f%d, lb %ld, csr 0x%lx)...\n",
	    imp_sth->cda->ft, imp_sth->cda->fc, (long)long_buflen, (long)imp_sth->cda);

    if (!f_cbufl) {
	f_cbufl_max = 120;
	New(1, f_cbufl, f_cbufl_max, sb4);
    }

    /* number of rows to cache	*/
    if      (SvOK(imp_drh->ora_cache_o)) imp_sth->cache_rows = SvIV(imp_drh->ora_cache_o);
    else if (SvOK(imp_drh->ora_cache))   imp_sth->cache_rows = SvIV(imp_drh->ora_cache);
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
	    if (OTYPE_IS_LONG(dbtype)) {
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
	sb4 defin_len;

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

	if (fbh->dbtype==23) {		/* RAW type			*/
	    if (fbh->prec == 0) { fbh->prec = fbh->dbsize; }
	    fbh->dbsize *= 2;
	    fbh->disize *= 2;
	}
	else if ((fbh->dbtype == 1 || fbh->dbtype == 96) && fbh->prec == 0) {
	    fbh->prec = fbh->dbsize;
	}

	if (OTYPE_IS_LONG(fbh->dbtype)) {
	    long lbl;
	    if (fbh->dbtype==24 || fbh->dbtype==95) {
		lbl = long_buflen * 2;
		fbh->ftype = 95;	/* get long in var raw form	*/
	    }
	    else {
		lbl = long_buflen;
		fbh->ftype = 94;	/* get long in var form	*/
	    }
	    fbh->dbsize = lbl;
	    fbh->disize = lbl;
	    defin_len = fbh->disize + 4;

	} else {
	    /* for the time being we fetch everything (except longs)	*/
	    /* as strings, that'll change (IV, NV and binary data etc)	*/
	    fbh->ftype = 5;		/* oraperl used 5 'STRING'	*/
	    defin_len = fbh->disize + 1;	/* +1: STRING null	*/
	}
	/* dbsize can be zero for 'select NULL ...'			*/
        imp_sth->t_dbsize += fbh->dbsize;

	fbh->fb_ary = fb_ary = fb_ary_alloc(defin_len, imp_sth->cache_rows);

	/* DEFINE output column variable storage */
	if (odefin(imp_sth->cda, i, fb_ary->abuf, defin_len,
		fbh->ftype, -1, fb_ary->aindp, (text*)0, -1, -1,
		fb_ary->arlen, fb_ary->arcode)) {
	    warn("odefin error on %s: %d", fbh->name, imp_sth->cda->rc);
	}

	if (DBIS->debug >= 2)
	    dbd_fbh_dump(fbh, i, 0);
    }
    imp_sth->est_width = est_width;

    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP,
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
    int debug = DBIS->debug;
    int num_fields;
    int ChopBlanks;
    int err = 0;
    int i;
    AV *av;
    D_imp_dbh_from_sth;
    D_imp_drh_from_dbh;

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
	    { dTHR; 				/* for DBIc_ACTIVE_off		*/
	      DBIc_ACTIVE_off(imp_sth);		/* eg finish			*/
	    }
	    if (imp_sth->eod_errno != 1403) {	/* was not just end-of-fetch	*/
		ora_error(sth, imp_sth->cda, imp_sth->eod_errno, "cached ofetch error");
	    } else {				/* is simply no more data	*/
		sv_setiv(DBIc_ERR(imp_sth), 0);	/* ensure errno set to 0 here	*/
		if (debug >= 3)
		    PerlIO_printf(DBILOGFP, "    dbd_st_fetch no-more-data, rc=%d, rpc=%ld\n",
			imp_sth->cda->rc, (long)imp_sth->cda->rpc);
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
	if (debug >= 4)
	    PerlIO_printf(DBILOGFP,
		"    dbd_st_fetch load-cache: prev rpc %d, new rpc %ld, in_cache %d\n",
		previous_rpc, (long)imp_sth->cda->rpc, imp_sth->in_cache);
	assert(imp_sth->in_cache > 0);
    }

    av = DBIS->get_fbav(imp_sth);
    num_fields = AvFILL(av)+1;

    if (debug >= 3)
	PerlIO_printf(DBILOGFP, "    dbd_st_fetch %d fields, rpc %ld (cache: %d/%d/%d)\n",
		num_fields, (long)imp_sth->cda->rpc, imp_sth->next_entry,
		imp_sth->in_cache, imp_sth->cache_rows);

    ChopBlanks = DBIc_has(imp_sth, DBIcf_ChopBlanks);

    for(i=0; i < num_fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	int cache_entry = imp_sth->next_entry;
	fb_ary_t *fb_ary = fbh->fb_ary;
	int rc = fb_ary->arcode[cache_entry];
	SV *sv = AvARRAY(av)[i]; /* Note: we (re)use the SV in the AV	*/
	ub4 datalen;

	if (rc == 1406 && OTYPE_IS_LONG(fbh->ftype)) {
	    /* We have a LONG field which has been truncated.		*/
	    int oraperl = DBIc_COMPAT(imp_sth);
	    if (DBIc_has(imp_sth,DBIcf_LongTruncOk) || (oraperl && SvIV(imp_drh->ora_trunc))) {
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
	    char *p;
	    if (fbh->ftype == 94 || fbh->ftype == 95) {   /* LONG VAR	*/
		p = (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl];
		datalen = *(ub4*)p;	/* XXX alignment ? */
		p += 4;
		sv_setpvn(sv, p, (STRLEN)datalen);
	    }
	    else {
		datalen = fb_ary->arlen[cache_entry];
		p = (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl];
		/* if ChopBlanks check for Oracle CHAR type (blank padded)	*/
		if (ChopBlanks && fbh->dbtype == 96) {
		    while(datalen && p[datalen - 1]==' ')
			--datalen;
		}
		sv_setpvn(sv, p, (STRLEN)datalen);
	    }

	} else if (rc == 1405) {	/* field is null - return undef	*/
	    datalen = 0;
	    (void)SvOK_off(sv);

	} else {  /* See odefin rcode arg description in OCI docs	*/
	    char buf[200];
	    char *hint = "";
	    datalen = 0;
	    /* These may get more case-by-case treatment eventually.	*/
	    if (rc == 1406) {		/* field truncated (see above)  */
		if (OTYPE_IS_LONG(fbh->ftype)) { /* double check */
		    hint = (DBIc_LongReadLen(imp_sth) > 65535)
			 ? ", DBI attribute LongTruncOk not set and/or LongReadLen too small or > 65535 max"
			 : ", DBI attribute LongTruncOk not set and/or LongReadLen too small";
		}
		else {
		    /* Copy the truncated value anyway, it may be of use,	*/
		    /* but it'll only be accessible via prior bind_column()	*/
		    sv_setpvn(sv, (char*)&fb_ary->abuf[cache_entry * fb_ary->bufl],
			      fb_ary->arlen[cache_entry]);
		}
	    }
	    else {
		(void*)SvOK_off(sv);	/* set field that caused error to undef	*/
	    }
	    ++err;	/* 'fail' this fetch but continue getting fields */
	    /* Some should probably be treated as warnings but	*/
	    /* for now we just treat them all as errors		*/
	    sprintf(buf,"ORA-%05d error on field %d of %d, ora_type %d%s",
			rc, i+1, num_fields, fbh->dbtype, hint);
	    ora_error(sth, imp_sth->cda, rc, buf);
	}

	if (debug >= 5)
	    PerlIO_printf(DBILOGFP, "        %d (rc=%d, otype %d, len %lu): %s\n",
		i, rc, fbh->dbtype, (unsigned long)datalen, neatsvpv(sv,0));
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

    if (!DBIc_ACTIVE(imp_dbh)) {
        ora_error(sth, NULL, -1, "Database disconnected");
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
    if (DBIS->debug >= 3)
	PerlIO_printf(DBILOGFP, "    dbd_st_prepare'd sql f%d\n", imp_sth->cda->ft);

    /* Describe and allocate storage for results.		*/
    if (!dbd_describe(sth, imp_sth)) {
	return 0;
    }

    DBIc_IMPSET_on(imp_sth);
    return 1;
}

int
ora_db_reauthenticate(dbh, imp_dbh, uid, pwd)
    SV *dbh;
    imp_dbh_t *imp_dbh;
    char *	uid;
    char *	pwd;
{
    ora_error(dbh, NULL, 1, "reauthenticate not possible when using Oracle OCI 7");
    return 0;
}

#endif
