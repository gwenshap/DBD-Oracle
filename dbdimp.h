/*
   $Id: dbdimp.h,v 1.38 2001/06/05 22:46:50 timbo Exp $

   Copyright (c) 1994,1995,1996,1997,1998,1999  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/


#if defined(get_no_modify) && !defined(no_modify)
#define no_modify PL_no_modify
#endif


/* ====== Include Oracle Header Files ====== */

#ifndef CAN_PROTOTYPE
#define signed	/* Oracle headers use signed */
#endif

/* The following define avoids a problem with Oracle >=7.3 where
 * ociapr.h has the line:
 *	sword  obindps(struct cda_def *cursor, ub1 opcode, text *sqlvar, ...
 * In some compilers that clashes with perls 'opcode' enum definition.
 */
#define opcode opcode_redefined

/* Hack to fix broken Oracle oratypes.h on OSF Alpha. Sigh.	*/
#if defined(__osf__) && defined(__alpha)
#ifndef A_OSF
#define A_OSF
#endif
#endif

/* egcs-1.1.2 does not have _int64 */
#if defined(__MINGW32__) || defined(__CYGWIN32__)
#define _int64 long long
#endif


/* This is slightly backwards because we want to auto-detect OCI8  */
/* and thus the existance of oci.h while still working for Oracle7 */
#include <oratypes.h>
#include <ocidfn.h>

#if defined(SQLT_NTY) && !defined(NO_OCI8)	/* === use Oracle 8 === */

/* ori.h uses 'dirty' as an arg name in prototypes so we use this */
/* hack to prevent ori.h being read (since we don't need it)	  */
#define ORI_ORACLE

#include <oci.h>

#else						/* === use Oracle 7 === */

#ifdef CAN_PROTOTYPE
# include <ociapr.h>
#else
# include <ocikpr.h>
#endif

#ifndef HDA_SIZE
#define HDA_SIZE 512
#endif

#endif						/* === ------------ === */

/* ------ end of Oracle include files ------ */



/* ====== define data types ====== */

typedef struct imp_fbh_st imp_fbh_t;


struct imp_drh_st {
    dbih_drc_t com;		/* MUST be first element in structure	*/
#ifdef OCI_V8_SYNTAX
    OCIEnv *envhp;
#endif
};


/* Define dbh implementor data structure */
struct imp_dbh_st {
    dbih_dbc_t com;		/* MUST be first element in structure	*/

#ifdef OCI_V8_SYNTAX
    void *(*get_oci_handle) _((imp_dbh_t *imp_dbh, int handle_type, int flags));
    OCIEnv *envhp;		/* copy of drh pointer	*/
    OCIError *errhp;
    OCIServer *srvhp;
    OCISvcCtx *svchp;
    OCISession *authp;
#else
    Lda_Def ldabuf;
    Lda_Def *lda;		/* points to ldabuf	*/
    ub1     hdabuf[HDA_SIZE];
    ub1     *hda;		/* points to hdabuf	*/
#endif

    int RowCacheSize;
    int ph_type;		/* default oratype for placeholders */
};


typedef struct lob_refetch_st lob_refetch_t;

/* Define sth implementor data structure */
struct imp_sth_st {
    dbih_stc_t com;		/* MUST be first element in structure	*/

#ifdef OCI_V8_SYNTAX
    void *(*get_oci_handle) _((imp_dbh_t *imp_dbh, int handle_type, int flags));
    OCIEnv	*envhp;		/* copy of dbh pointer	*/
    OCIError	*errhp;		/* copy of dbh pointer	*/
    OCIServer	*srvhp;		/* copy of dbh pointer	*/
    OCISvcCtx	*svchp;		/* copy of dbh pointer	*/
    OCIStmt	*stmhp;
    ub2 	stmt_type;	/* OCIAttrGet OCI_ATTR_STMT_TYPE	*/
    U16		auto_lob;
    int  	has_lobs;
    lob_refetch_t *lob_refetch;
#else
    Cda_Def *cda;	/* normally just points to cdabuf below */
    Cda_Def cdabuf;
#endif
    int  	disable_finish; /* fetched cursors can core dump in finish */

    /* Input Details	*/
    char      *statement;	/* sql (see sth_scan)		*/
    HV        *all_params_hv;	/* all params, keyed by name	*/
    AV        *out_params_av;	/* quick access to inout params	*/
    int        ora_pad_empty;	/* convert ""->" " when binding	*/

    /* Select Column Output Details	*/
    int        done_desc;   /* have we described this sth yet ?	*/
    imp_fbh_t *fbh;	    /* array of imp_fbh_t structs	*/
    char      *fbh_cbuf;    /* memory for all field names       */
    int       t_dbsize;     /* raw data width of a row		*/
    IV        long_readlen; /* local copy to handle oraperl	*/

    /* Select Row Cache Details */
    int       cache_rows;
    int       in_cache;
    int       next_entry;
    int       eod_errno;
    int       est_width;    /* est'd avg row width on-the-wire	*/

    /* (In/)Out Parameter Details */
    bool  has_inout_params;
};
#define IMP_STH_EXECUTING	0x0001


typedef struct fb_ary_st fb_ary_t;    /* field buffer array	*/
struct fb_ary_st { 	/* field buffer array EXPERIMENTAL	*/
    ub2  bufl;		/* length of data buffer		*/
    sb2  *aindp;	/* null/trunc indicator variable	*/
    ub1  *abuf;		/* data buffer (points to sv data)	*/
    ub2  *arlen;	/* length of returned data		*/
    ub2  *arcode;	/* field level error status		*/
};

struct imp_fbh_st { 	/* field buffer EXPERIMENTAL */
    imp_sth_t *imp_sth;	/* 'parent' statement	*/
    int field_num;	/* 0..n-1		*/

    /* Oracle's description of the field	*/
#ifdef OCI_V8_SYNTAX
    OCIParam  *parmdp;
    OCIDefine *defnp;
    void *desc_h;	/* descriptor if needed (LOBs etc)	*/
    ub4   desc_t;	/* OCI type of descriptorh		*/
    int  (*fetch_func) _((SV *sth, imp_sth_t *imp_sth, imp_fbh_t *fbh, SV *dest_sv));
    ub2  dbsize;
    ub2  dbtype;	/* actual type of field (see ftype)	*/
    ub2  prec;		/* XXX docs say ub1 but ub2 is needed	*/
    sb1  scale;
    ub1  nullok;
    void *special;	/* hook for special purposes (LOBs etc)	*/
#else
    sb4  dbsize;
    sb2  dbtype;	/* actual type of field (see ftype)	*/
    sb2  prec;
    sb2  scale;
    sb2  nullok;
    sb4  cbufl;		/* length of select-list item 'name'	*/
#endif
    SV   *name_sv;	/* only set for OCI8			*/
    char *name;
    sb4  disize;	/* max display/buffer size		*/

    /* Our storage space for the field data as it's fetched	*/
    sword ftype;	/* external datatype we wish to get	*/
    fb_ary_t *fb_ary;	/* field buffer array			*/
};


typedef struct phs_st phs_t;    /* scalar placeholder   */

struct phs_st {  	/* scalar placeholder EXPERIMENTAL	*/
    imp_sth_t *imp_sth; /* 'parent' statement  			*/
    sword ftype;	/* external OCI field type		*/

    SV	*sv;		/* the scalar holding the value		*/
    int sv_type;	/* original sv type at time of bind	*/
    bool is_inout;

    IV  maxlen;		/* max possible len (=allocated buffer)	*/
    sb4 maxlen_bound;	/* and Oracle bind has been called	*/

#ifdef OCI_V8_SYNTAX
    OCIBind *bndhp;
    void *desc_h;	/* descriptor if needed (LOBs etc)	*/
    ub4   desc_t;	/* OCI type of desc_h			*/
    ub4   alen;
#else
    ub2   alen;		/* effective length ( <= maxlen )	*/
#endif
    ub2 arcode;

    sb2 indp;		/* null indicator			*/
    char *progv;

    int (*out_prepost_exec)_((SV *, imp_sth_t *, phs_t *, int pre_exec));
    SV	*ora_field;	/* from attribute (for LOB binds)	*/
    int alen_incnull;	/* 0 or 1 if alen should include null	*/
    char name[1];	/* struct is malloc'd bigger as needed	*/
};


/* ------ define functions and external variables ------ */

extern int ora_fetchtest;

void dbd_init_oci _((dbistate_t *dbistate));
void dbd_preparse _((imp_sth_t *imp_sth, char *statement));
void dbd_fbh_dump _((imp_fbh_t *fbh, int i, int aidx));
void ora_free_fbh_contents _((imp_fbh_t *fbh));
int ora_dbtype_is_long _((int dbtype));
int calc_cache_rows _((int num_fields, int est_width, int cache_rows, int has_longs));
fb_ary_t *fb_ary_alloc _((int bufl, int size));
int ora_db_reauthenticate _((SV *dbh, imp_dbh_t *imp_dbh, char *uid, char *pwd));

#define OTYPE_IS_LONG(t)  ((t)==8 || (t)==24 || (t)==94 || (t)==95)

#ifdef OCI_V8_SYNTAX

int oci_error _((SV *h, OCIError *errhp, sword status, char *what));
char *oci_stmt_type_name _((int stmt_type));
char *oci_status_name _((sword status));
int dbd_rebind_ph_lob _((SV *sth, imp_sth_t *imp_sth, phs_t *phs));
void ora_free_lob_refetch _((SV *sth, imp_sth_t *imp_sth));
void dbd_phs_avsv_complete _((phs_t *phs, I32 index, I32 debug));
void dbd_phs_sv_complete _((phs_t *phs, SV *sv, I32 debug));
int post_execute_lobs _((SV *sth, imp_sth_t *imp_sth, ub4 row_count));
ub4 ora_parse_uid _((imp_dbh_t *imp_dbh, char **uidp, char **pwdp));
char *ora_sql_error _((imp_sth_t *imp_sth, char *msg));

sb4 dbd_phs_in _((dvoid *octxp, OCIBind *bindp, ub4 iter, ub4 index,
              dvoid **bufpp, ub4 *alenp, ub1 *piecep, dvoid **indpp));
sb4 dbd_phs_out _((dvoid *octxp, OCIBind *bindp, ub4 iter, ub4 index,
             dvoid **bufpp, ub4 **alenpp, ub1 *piecep,
             dvoid **indpp, ub2 **rcodepp));
int dbd_rebind_ph_rset _((SV *sth, imp_sth_t *imp_sth, phs_t *phs));

void * oci_db_handle(imp_dbh_t *imp_dbh, int handle_type, int flags);
void * oci_st_handle(imp_sth_t *imp_sth, int handle_type, int flags);

#else	/* is OCI 7 */

void ora_error _((SV *h, Lda_Def *lda, int rc, char *what));

#endif /* OCI_V8_SYNTAX */

#include "ocitrace.h"



/* These defines avoid name clashes for multiple statically linked DBD's	*/

#define dbd_init		ora_init
#define dbd_db_login		ora_db_login
#define dbd_db_login6		ora_db_login6
#define dbd_db_do		ora_db_do
#define dbd_db_commit		ora_db_commit
#define dbd_db_rollback		ora_db_rollback
#define dbd_db_disconnect	ora_db_disconnect
#define dbd_db_destroy		ora_db_destroy
#define dbd_db_STORE_attrib	ora_db_STORE_attrib
#define dbd_db_FETCH_attrib	ora_db_FETCH_attrib
#define dbd_st_prepare		ora_st_prepare
#define dbd_st_rows		ora_st_rows
#define dbd_st_execute		ora_st_execute
#define dbd_st_fetch		ora_st_fetch
#define dbd_st_finish		ora_st_finish
#define dbd_st_destroy		ora_st_destroy
#define dbd_st_blob_read	ora_st_blob_read
#define dbd_st_STORE_attrib	ora_st_STORE_attrib
#define dbd_st_FETCH_attrib	ora_st_FETCH_attrib
#define dbd_describe		ora_describe
#define dbd_bind_ph		ora_bind_ph

/* end */
