/*
   $Id: dbdimp.c,v 1.41 1998/11/29 00:14:07 timbo Exp $

   Copyright (c) 1994,1995,1996,1997,1998  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#include "Oracle.h"

#if !defined(dirty) && !defined(PL_dirty)
#define PL_dirty dirty
#endif

/* XXX DBI should provide a better version of this */
#define IS_DBI_HANDLE(h) \
    (SvROK(h) && SvTYPE(SvRV(h)) == SVt_PVHV && \
	SvRMAGICAL(SvRV(h)) && (SvMAGIC(SvRV(h)))->mg_type == 'P')

#define OCIAttrGet_stmhp(imp_sth, p, l, a) \
	OCIAttrGet(imp_sth->stmhp, OCI_HTYPE_STMT, (dvoid*)(p), (l), (a), imp_sth->errhp);
#define OCIAttrGet_parmdp(imp_sth, parmdp, p, l, a) \
	OCIAttrGet(parmdp, OCI_DTYPE_PARAM, (dvoid*)(p), (l), (a), imp_sth->errhp);

DBISTATE_DECLARE;

static SV *ora_long;
static SV *ora_trunc;
static SV *ora_pad_empty;
static SV *ora_cache;
static SV *ora_cache_o;		/* temp hack for ora_open() cache override */
static int ora_login_nomsg;	/* don't fetch real login errmsg if true  */
static int ora_fetchtest;
static int ora_sigchld_restart = 1;
static int set_sigint_handler  = 0;

static void dbd_preparse _((imp_sth_t *imp_sth, char *statement));
static int ora2sql_type _((int oratype));
static int calc_cache_rows _((int f, int ew, int cr, int hl));


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
    if (!PL_dirty && !SvTRUE(perl_get_sv("DBI::PERL_ENDING",0))) {
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



static void
fbh_dump(fbh, i, aidx)
    imp_fbh_t *fbh;
    int i;
    int aidx;	/* array index */
{
    FILE *fp = DBILOGFP;
    fprintf(fp, "    fbh %d: '%s'\t%s, ",
		i, fbh->name, (fbh->nullok) ? "NULLable" : "");
    fprintf(fp, "type %3d->%2d,  dbsize %ld/%ld, p%d s%d\n",
	    fbh->dbtype, fbh->ftype, (long)fbh->dbsize,(long)fbh->disize,
	    fbh->prec, fbh->scale);
    if (fbh->fb_ary) {
    fprintf(fp, "      out: ftype %d, bufl %d. indp %d, rlen %d, rcode %d\n",
	    fbh->ftype, fbh->fb_ary->bufl, fbh->fb_ary->aindp[aidx],
	    fbh->fb_ary->arlen[aidx], fbh->fb_ary->arcode[aidx]);
    }
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


#ifdef OCI_V8_SYNTAX
#include "oci8.h"
#else
#include "oci7.h"
#endif


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

#ifdef OCI_V8_SYNTAX
    D_imp_drh_from_dbh;

    if (!imp_drh->envhp) {
	OCIInitialize((ub4) OCI_DEFAULT, 0, 0,0,0);
	ret = OCIEnvInit( &imp_drh->envhp, OCI_DEFAULT, 0, 0 );
    }
    imp_dbh->envhp = imp_drh->envhp;

    OCIHandleAlloc(imp_dbh->envhp, (dvoid**)&imp_dbh->errhp, OCI_HTYPE_ERROR, 0,0);
    OCIHandleAlloc(imp_dbh->envhp, (dvoid**)&imp_dbh->srvhp, OCI_HTYPE_SERVER,0,0);

    /* OCI 8 does not seem to allow uid to be "name/pass" :-( */
    /* so we have to split it up ourselves */
    if (strlen(pwd)==0 && strchr(uid,'/')) {
	SV *tmpsv = sv_2mortal(newSVpv(uid,0));
	uid = SvPVX(tmpsv);
	pwd = strchr(uid, '/');
	*pwd++ = '\0';
	/* XXX look for '@', e.g. "u/p@d" and "u@d" and maybe "@d" */
    }

    ret=OCIServerAttach(imp_dbh->srvhp, imp_dbh->errhp,
		dbname, strlen(dbname), 0);
    if (ret != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, ret, "OCIServerAttach");
	OCIHandleFree(imp_dbh->srvhp, OCI_HTYPE_SERVER);
	OCIHandleFree(imp_dbh->errhp, OCI_HTYPE_ERROR);
	return 0;
    }

    OCIHandleAlloc(imp_dbh->envhp, (dvoid**)&imp_dbh->svchp, OCI_HTYPE_SVCCTX,0,0);
    OCIAttrSet( imp_dbh->svchp, OCI_HTYPE_SVCCTX, imp_dbh->srvhp, 
                 (ub4) 0, OCI_ATTR_SERVER, imp_dbh->errhp);

    OCIHandleAlloc(imp_dbh->envhp, (dvoid **)&imp_dbh->authp,
		(ub4) OCI_HTYPE_SESSION, 0,0);
    OCIAttrSet(imp_dbh->authp, OCI_HTYPE_SESSION,
                 uid, strlen(uid),
                 (ub4) OCI_ATTR_USERNAME, imp_dbh->errhp);
    OCIAttrSet(imp_dbh->authp, OCI_HTYPE_SESSION,
                 (strlen(pwd)) ? pwd : NULL, strlen(pwd),
                 (ub4) OCI_ATTR_PASSWORD, imp_dbh->errhp);

    ret=OCISessionBegin( imp_dbh->svchp, imp_dbh->errhp, imp_dbh->authp,
		OCI_CRED_RDBMS, (ub4) OCI_DEFAULT);
    if (ret != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, ret, "OCISessionBegin");
	OCIServerDetach(imp_dbh->srvhp, imp_dbh->errhp, OCI_DEFAULT );
	OCIHandleFree(imp_dbh->srvhp, OCI_HTYPE_SERVER);
	OCIHandleFree(imp_dbh->errhp, OCI_HTYPE_ERROR);
	OCIHandleFree(imp_dbh->svchp, OCI_HTYPE_SVCCTX);
	return 0;
    }
 
    OCIAttrSet(imp_dbh->svchp, (ub4) OCI_HTYPE_SVCCTX,
                   imp_dbh->authp, (ub4) 0,
                   (ub4) OCI_ATTR_SESSION, imp_dbh->errhp);

/* XXX to be removed */
    imp_dbh->lda = &imp_dbh->ldabuf;
    OCISvcCtxToLda( imp_dbh->svchp, imp_dbh->errhp, imp_dbh->lda);
    OCILdaToSvcCtx(&imp_dbh->svchp, imp_dbh->errhp, imp_dbh->lda);

#else
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

    if (!set_sigint_handler) {
	set_sigint_handler = 1;
	/* perl's sign handler is sighandler */
	/* osnsui(??, sighandler, NULL?) */
	/* OCI8: osnsui(word *handlp, void (*astp), char * ctx)
	** osnsui: Operating System dependent Network Set User-side
	** Interrupt. Add an interrupt handling procedure astp. 
	** Whenever a user interrupt(such as a ^C) occurs, call astp
	** with argument ctx. Put in *handlp handle for this 
	** handler so that it may be cleared with osncui.
	** Note that there may be many handlers; each should 
	** be cleared using osncui. An error code is 
	** returned if an error occurs.
	*/
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
#endif	/* HAS_SIGACTION */

#endif	/* OCI_V8_SYNTAX */

    DBIc_IMPSET_on(imp_dbh);	/* imp_dbh set up now			*/
    DBIc_ACTIVE_on(imp_dbh);	/* call disconnect before freeing	*/
    return 1;
}


int
dbd_db_commit(dbh, imp_dbh)
    SV *dbh;
    imp_dbh_t *imp_dbh;
{
#ifdef OCI_V8_SYNTAX
    sword status = OCITransCommit(imp_dbh->svchp, imp_dbh->errhp, OCI_DEFAULT);
    if (status != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, status, "OCITransCommit");
#else
    if (ocom(imp_dbh->lda)) {
	ora_error(dbh, imp_dbh->lda, imp_dbh->lda->rc, "commit failed");
#endif
	return 0;
    }
    return 1;
}

int
dbd_db_rollback(dbh, imp_dbh)
    SV *dbh;
    imp_dbh_t *imp_dbh;
{
#ifdef OCI_V8_SYNTAX
    sword status = OCITransRollback(imp_dbh->svchp, imp_dbh->errhp, OCI_DEFAULT);
    if (status != OCI_SUCCESS) {
	oci_error(dbh, imp_dbh->errhp, status, "OCITransRollback");
#else
    if (orol(imp_dbh->lda)) {
	ora_error(dbh, imp_dbh->lda, imp_dbh->lda->rc, "rollback failed");
#endif
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

    /* Oracle will commit on an orderly disconnect.	*/
    /* See DBI Driver.xst file for the DBI approach.	*/

#ifdef OCI_V8_SYNTAX
    {
	sword s_se = OCISessionEnd(  imp_dbh->svchp, imp_dbh->errhp, imp_dbh->authp, OCI_DEFAULT);
	sword s_sd = OCIServerDetach(imp_dbh->srvhp, imp_dbh->errhp, OCI_DEFAULT );
	if (s_se)
	    oci_error(dbh, imp_dbh->errhp, s_se, "OCISessionEnd");
	if (s_sd)
	    oci_error(dbh, imp_dbh->errhp, s_sd, "OCIServerDetach");
	OCIHandleFree(imp_dbh->srvhp, OCI_HTYPE_SERVER);
	OCIHandleFree(imp_dbh->svchp, OCI_HTYPE_SVCCTX);
	OCIHandleFree(imp_dbh->errhp, OCI_HTYPE_ERROR);
	if (s_se || s_sd)
	    return 0;
    }
#else
    if (ologof(imp_dbh->lda)) {
	ora_error(dbh, imp_dbh->lda, imp_dbh->lda->rc, "disconnect error");
	return 0;
    }
#endif
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
#ifndef OCI_V8_SYNTAX
	if ( (on) ? ocon(imp_dbh->lda) : ocof(imp_dbh->lda) ) {
	    ora_error(dbh, imp_dbh->lda, imp_dbh->lda->rc, "ocon/ocof failed");
	    /* XXX um, we can't return FALSE and true isn't acurate so we croak */
	    croak(SvPV(DBIc_ERRSTR(imp_dbh),na));
	}
#endif	/* OCI V8 handles this as OCIExecuteStmt	*/
	DBIc_set(imp_dbh,DBIcf_AutoCommit, on);
    }
    else if (kl==12 && strEQ(key, "RowCacheSize")) {
	imp_dbh->RowCacheSize = SvIV(valuesv);
    }
    else {
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
    else if (kl==12 && strEQ(key, "RowCacheSize")) {
	retsv = newSViv(imp_dbh->RowCacheSize);
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


int
dbd_st_prepare(sth, imp_sth, statement, attribs)
    SV *sth;
    imp_sth_t *imp_sth;
    char *statement;
    SV *attribs;
{
    D_imp_dbh_from_sth;
    ub4   oparse_lng   = 1;  /* auto v6 or v7 as suits db connected to	*/
#ifdef OCI_V8_SYNTAX
    sword status = 0;
#endif

    imp_sth->done_desc = 0;

    if (DBIc_COMPAT(imp_sth)) {
	imp_sth->ora_pad_empty = (SvOK(ora_pad_empty)) ? SvIV(ora_pad_empty) : 0;
    }

    if (attribs) {
	SV **svp;
	DBD_ATTRIB_GET_IV(  attribs, "ora_parse_lang", 14, svp, oparse_lng);
    }

    /* scan statement for '?', ':1' and/or ':foo' style placeholders	*/
    dbd_preparse(imp_sth, statement);

#ifdef OCI_V8_SYNTAX

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

    OCIHandleAlloc(imp_dbh->envhp, (dvoid**)&imp_sth->stmhp, OCI_HTYPE_STMT, 0,0);
    status = OCIStmtPrepare(imp_sth->stmhp, imp_sth->errhp,
	       imp_sth->statement, (ub4)strlen(imp_sth->statement),
	       oparse_lng, OCI_DEFAULT);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCIStmtPrepare");
	OCIHandleFree(imp_sth->stmhp, OCI_HTYPE_STMT);
	return 0;
    }

    OCIAttrGet_stmhp(imp_sth, &imp_sth->stmt_type, 0, OCI_ATTR_STMT_TYPE);
    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "    dbd_st_prepare'd sql %s\n",
		oci_stmt_type_name(imp_sth->stmt_type));

#else

    if (!get_cursor(imp_dbh, sth, imp_sth))
        return 0;

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
	free_cursor(sth, imp_sth);
	return 0;
    }
    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "    dbd_st_prepare'd sql f%d\n", imp_sth->cda->ft);

    /* Describe and allocate storage for results.		*/
    if (!dbd_describe(sth, imp_sth)) {
	return 0;
    }
#endif

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
    phs_tpl.aryelem_max = 0;
    phs_tpl.aryelem_cur = 1;

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


static int
calc_cache_rows(num_fields, est_width, cache_rows, has_longs)
    int num_fields, est_width, cache_rows, has_longs;
{
    /* Use guessed average on-the-wire row width calculated above	*/
    /* and add in overhead of 5 bytes per field plus 8 bytes per row.	*/
    /* The n*5+8 was determined by studying SQL*Net v2 packets.		*/
    /* It could probably benefit from a more detailed analysis.		*/
    est_width += num_fields*5 + 8;

    if (has_longs)			/* override/disable caching	*/
	cache_rows = 1;			/* else read_blob can't work	*/

    else if (cache_rows < 1) {		/* automatically size the cache	*/
	int txfr_size;
	/*  0 == try to pick 'optimal' cache for this query (default)	*/
	/* <0 == base cache on target transfer size of -n bytes.	*/
	if (cache_rows == 0) {
	    /* Oracle packets on ethernet have max size of around 1460.	*/
	    /* We'll aim to fill our row cache with slightly less than	*/
	    /* two packets (to err on the safe side and avoid a third	*/
	    /* almost empty packet being generated in some cases).	*/
	    txfr_size = 1460 * 3.6;	/* default transfer/cache size	*/
	}
	else {	/* user is specifying desired transfer size in bytes	*/
	    txfr_size = -cache_rows;
	}
	cache_rows = txfr_size / est_width;	/* maybe 1 or 0	*/
	/* To ensure good performance with large rows (near or larger	*/
	/* than our target transfer size) we set a minimum cache size.	*/
	if (cache_rows < 6)	/* is cache a 'useful' size?	*/
	    cache_rows = (cache_rows>0) ? 6 : 4;
    }
    if (cache_rows > 32767)	/* keep within Oracle's limits  */
	cache_rows = 32767;

    return cache_rows;
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
	fprintf(DBILOGFP, "       bind %s <== '%.*s' (size %d/%ld, otype %d, indp %d)\n",
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
#ifndef OCI_V8_SYNTAX
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
#else
    die("Cursor variables not yet supported");
#endif
}
#endif


static int 
_dbd_rebind_ph(sth, imp_sth, phs) 
    SV *sth;
    imp_sth_t *imp_sth;
    phs_t *phs;
{
    ub2 *alen_ptr = NULL;
#ifdef OCI_V8_SYNTAX
    sword status;
    ub4 *aryelem_cur_ptr = NULL;
#endif

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

#ifdef OCI_V8_SYNTAX
    status = OCIBindByName(imp_sth->stmhp, &phs->bndhp, imp_sth->errhp,
	    phs->name, strlen(phs->name),
	    phs->progv, phs->maxlen,
	    phs->ftype, &phs->indp,
	    alen_ptr, &phs->arcode,
	    phs->aryelem_max,	/* max elements that can fit in allocated array	*/
	    aryelem_cur_ptr,	/* (ptr to) current number of elements in array	*/
	    OCI_DEFAULT);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCIBindByName");
	return 0;
    }

#else
    if (obndra(imp_sth->cda, (text *)phs->name, -1,
	    (ub1*)phs->progv, (sword)phs->maxlen, /* cast reduces max size */
	    (sword)phs->ftype, -1,
	    &phs->indp, alen_ptr, &phs->arcode, 0, (ub4 *)0,
	    (text *)0, -1, -1)) {
	D_imp_dbh_from_sth;
	ora_error(sth, imp_dbh->lda, imp_sth->cda->rc, "obndra failed");
	return 0;
    }
#endif
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
	fprintf(DBILOGFP, "       bind %s <== %s (type %ld",
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

    }	/* was first bind for this placeholder  */

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
    ub4 row_count = 0;
    int debug = dbis->debug;
    int outparams = (imp_sth->out_params_av) ? AvFILL(imp_sth->out_params_av)+1 : 0;

#ifdef OCI_V8_SYNTAX
    D_imp_dbh_from_sth;
    sword status;
    int is_select = (imp_sth->stmt_type == OCI_STMT_SELECT);

    if (debug >= 2)
	fprintf(DBILOGFP, "    dbd_st_execute %s (out%d)...\n",
		    oci_stmt_type_name(imp_sth->stmt_type), outparams);
#else

    if (!imp_sth->done_desc) {
	/* describe and allocate storage for results (if any needed)	*/
	if (!dbd_describe(sth, imp_sth))
	    return -2; /* dbd_describe already called ora_error()	*/
    }
    if (debug >= 2)
	fprintf(DBILOGFP,
	    "    dbd_st_execute (for sql f%d after oci f%d, out%d)...\n",
			imp_sth->cda->ft, imp_sth->cda->fc, outparams);
#endif

    if (outparams) {	/* check validity of bind_param_inout SV's	*/
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

#ifdef OCI_V8_SYNTAX

    status = OCIStmtExecute(imp_sth->svchp, imp_sth->stmhp, imp_sth->errhp,
		(is_select) ? 0 : 1,
		0, 0, 0,
		(DBIc_has(imp_dbh,DBIcf_AutoCommit))
			? OCI_COMMIT_ON_SUCCESS : OCI_DEFAULT);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCIStmtExecute");
	return -2;
    }
    if (is_select) {
	DBIc_ACTIVE_on(imp_sth);
	DBIc_ROW_COUNT(imp_sth) = 0; /* reset (possibly re-exec'ing) */
	row_count = 0;
    }
    else {
	OCIAttrGet_stmhp(imp_sth, &row_count, 0, OCI_ATTR_ROW_COUNT);
    }

    if (debug >= 2) {
	ub2 sqlfncode;
	OCIAttrGet_stmhp(imp_sth, &sqlfncode, 0, OCI_ATTR_SQLFNCODE);
	fprintf(DBILOGFP,
	    "    dbd_st_execute %s ok (%s, rpc%ld, fn%d, out%d)\n",
		oci_stmt_type_name(imp_sth->stmt_type),
		oci_status_name(status),
		row_count, sqlfncode, imp_sth->has_inout_params);
    }

    if (is_select && !imp_sth->done_desc) {
	/* describe and allocate storage for results (if any needed)	*/
	if (!dbd_describe(sth, imp_sth))
	    return -2; /* dbd_describe already called ora_error()	*/
    }

#else

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
	DBIc_ACTIVE_on(imp_sth);
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
    row_count = (imp_sth->cda) ? 0 : imp_sth->cda->rpc;

    if (debug >= 2)
	fprintf(DBILOGFP,
	    "    dbd_st_execute complete (rc%d, w%02x, rpc%ld, eod%d, out%d)\n",
		imp_sth->cda->rc,  imp_sth->cda->wrn,
		row_count, imp_sth->eod_errno,
		imp_sth->has_inout_params);
#endif

    if (outparams) {	/* check validity of bound output SV's	*/
	int i = outparams;
	while(--i >= 0) {
	    phs_t *phs = (phs_t*)(void*)SvPVX(AvARRAY(imp_sth->out_params_av)[i]);
	    SV *sv = phs->sv;
#ifndef OCI_V8_SYNTAX
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
#endif
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

    return row_count;	/* row count (0 will be returned as "0E0")	*/
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
#ifdef OCI_V8_SYNTAX
    croak("blob_read not currently supported with OCI 8");
#else
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
#endif

    return 1;
}


int
dbd_st_rows(sth, imp_sth)
    SV *sth;
    imp_sth_t *imp_sth;
{
#ifdef OCI_V8_SYNTAX
    ub4 row_count = 0;
    sword status;
    status = OCIAttrGet_stmhp(imp_sth, &row_count, 0, OCI_ATTR_ROW_COUNT);
    if (status != OCI_SUCCESS) {
	oci_error(sth, imp_sth->errhp, status, "OCIAttrGet OCI_ATTR_ROW_COUNT");
	return -1;
    }
    return row_count;
#else
    /* spot common mistake of checking $h->rows just after ->execute	*/
    if (   imp_sth->in_cache > 0		 /* has unfetched rows	*/
	&& imp_sth->in_cache== imp_sth->cda->rpc /* NO rows fetched yet	*/
	&& DBIc_WARN(imp_sth)	/* provide a way to disable warning	*/
    ) {
	warn("$h->rows count is incomplete before all rows fetched.\n");
    }
    /* imp_sth->in_cache should always be 0 for non-select statements	*/
    return imp_sth->cda->rpc - imp_sth->in_cache;	/* fetched rows	*/
#endif
}


int
dbd_st_finish(sth, imp_sth)
    SV *sth;
    imp_sth_t *imp_sth;
{
    dTHR;

    if (!DBIc_ACTIVE(imp_sth))
	return 1;

    /* Cancel further fetches from this cursor.                 */
    /* We don't close the cursor till DESTROY (dbd_st_destroy). */
    /* The application may re execute(...) it.                  */
#ifdef OCI_V8_SYNTAX
    /* OCI 8 manual says there's no equiv of OCI7 ocan()	*/
    /* An OCIBreak() might be relevant */
#else
    if (ocan(imp_sth->cda) ) {
	/* oracle 7.3 code can core dump looking up an error message	*/
	/* if we have logged out of the database. This typically	*/
	/* happens during global destruction. This should catch most:	*/
	if (PL_dirty && imp_sth->cda->rc == 3114)
	    ora_error(sth, NULL, imp_sth->cda->rc,
		"ORA-03114: not connected to ORACLE (ocan)");
	else
	    ora_error(sth, imp_sth->cda, imp_sth->cda->rc, "ocan error");
	return 0;
    }
#endif
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
#ifdef OCI_V8_SYNTAX
	/* nothing to do here ? */
#else
	free_cursor(sth, imp_sth);		/* ignore errors here	*/
#endif
	/* fall through anyway to free up our memory */
    } 

#ifdef OCI_V8_SYNTAX
    {
	sword status = OCIHandleFree(imp_sth->stmhp, OCI_HTYPE_STMT);
	if (status != OCI_SUCCESS)
	    oci_error(sth, imp_sth->errhp, status, "OCIHandleFree");
    }
#endif

    /* Free off contents of imp_sth	*/

    fields = DBIc_NUM_FIELDS(imp_sth);
    imp_sth->in_cache  = 0;
    imp_sth->eod_errno = 1403;
    for(i=0; i < fields; ++i) {
	imp_fbh_t *fbh = &imp_sth->fbh[i];
	if (fbh->fb_ary)
	    fb_ary_free(fbh->fb_ary);
	sv_free(fbh->name_sv);
    }
    Safefree(imp_sth->fbh);
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
	    av_store(av, i, newSViv(ora2sql_type(imp_sth->fbh[i].dbtype)));

    } else if (kl==5 && strEQ(key, "SCALE")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv(imp_sth->fbh[i].scale));

    } else if (kl==9 && strEQ(key, "PRECISION")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSViv(imp_sth->fbh[i].prec));

#ifndef OCI_V8_SYNTAX
#ifdef XXXXX
    } else if (kl==9 && strEQ(key, "ora_rowid")) {
	/* return current _binary_ ROWID (oratype 11) uncached	*/
	/* Use { ora_type => 11 } when binding to a placeholder	*/
	retsv = newSVpv((char*)&imp_sth->cda->rid, sizeof(imp_sth->cda->rid));
	cacheit = FALSE;
#endif
#endif

    } else if (kl==17 && strEQ(key, "ora_est_row_width")) {
	retsv = newSViv(imp_sth->est_width);
	cacheit = TRUE;

    } else if (kl==4 && strEQ(key, "NAME")) {
	AV *av = newAV();
	retsv = newRV(sv_2mortal((SV*)av));
	while(--i >= 0)
	    av_store(av, i, newSVpv((char*)imp_sth->fbh[i].name,0));

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

static int
ora2sql_type(oratype)
   int oratype;
{
    switch(oratype) {	/* oracle Internal (not external) types */
    case SQLT_CHR:  return SQL_VARCHAR;
    case SQLT_NUM:  return SQL_DECIMAL;
    case SQLT_LNG:  return SQL_LONGVARCHAR;	/* long */
    case SQLT_DAT:  return SQL_DATE;
    case SQLT_BIN:  return SQL_BINARY;		/* raw */
    case SQLT_LBI:  return SQL_LONGVARBINARY;	/* long raw */
    case SQLT_AFC:  return SQL_CHAR;		/* Ansi fixed char */
    }
    /* else map type into DBI reserved standard range */
    return -9000 - oratype;
}
