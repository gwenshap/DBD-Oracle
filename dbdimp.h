/*
   $Id: dbdimp.h,v 1.19 1997/09/08 22:43:59 timbo Exp $

   Copyright (c) 1994,1995  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

/* #define MAX_COLS 1025 */

/* try uncommenting this line if you get a syntax error on
 *	typedef signed long  sbig_ora;
 * in oratypes.h for Oracle 7.1.3. Don't you just love Oracle!
 */
/* #define signed */

/* Hack to fix broken Oracle oratypes.h on OSF Alpha. Sigh.	*/
#if defined(__osf__) && defined(__alpha)
#ifndef A_OSF
#define A_OSF
#endif
#endif

#include <oratypes.h>
#include <ocidfn.h>
#ifdef CAN_PROTOTYPE
# include <ociapr.h>
#else
# include <ocikpr.h>
#endif
#ifndef HDA_SIZE
#define HDA_SIZE 512
#endif

#ifndef FT_SELECT
#define FT_SELECT 4	/* from rdbms/demo/ocidem.h */
#endif


typedef struct imp_fbh_st imp_fbh_t;

struct imp_drh_st {
    dbih_drc_t com;		/* MUST be first element in structure	*/
};

/* Define dbh implementor data structure */
struct imp_dbh_st {
    dbih_dbc_t com;		/* MUST be first element in structure	*/

    Lda_Def lda;
    ub1     hda[HDA_SIZE];

	int autocommit;		/* we assume autocommit is off initially   */
};


/* Define sth implementor data structure */
struct imp_sth_st {
    dbih_stc_t com;		/* MUST be first element in structure	*/

    Cda_Def *cda;	/* currently just points to cdabuf below */
    Cda_Def cdabuf;

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

    /* Select Row Cache Details */
    int       cache_size;
    int       in_cache;
    int       next_entry;
    int       eod_errno;

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
    imp_sth_t *imp_sth;	/* 'parent' statement */

    /* Oracle's description of the field	*/
    sb4  dbsize;
    sb2  dbtype;	/* actual type of field (see ftype)	*/
    sb1  *cbuf;		/* ptr to name of select-list item	*/
    sb4  cbufl;		/* length of select-list item name	*/
    sb4  dsize;		/* max display size if field is a char */
    sb2  prec;
    sb2  scale;
    sb2  nullok;

    /* Our storage space for the field data as it's fetched	*/
    sword ftype;	/* external datatype we wish to get	*/
    fb_ary_t *fb_ary;	/* field buffer array			*/
};


typedef struct phs_st phs_t;    /* scalar placeholder   */

struct phs_st {  	/* scalar placeholder EXPERIMENTAL	*/
    sword ftype;	/* external OCI field type		*/

    SV	*sv;		/* the scalar holding the value		*/
    int sv_type;	/* original sv type at time of bind	*/
    bool is_inout;

    IV  maxlen;		/* max possible len (=allocated buffer)	*/

    /* these will become an array */
    sb2 indp;		/* null indicator			*/
    char *progv;
    ub2 arcode;
    ub2 alen;		/* effective length ( <= maxlen )	*/

    int alen_incnull;	/* 0 or 1 if alen should include null	*/
    char name[1];	/* struct is malloc'd bigger as needed	*/
};


/* These defines avoid name clashes for multiple statically linked DBD's	*/

#define dbd_init		ora_init
#define dbd_db_login		ora_db_login
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
