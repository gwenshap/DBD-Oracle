/*
   $Id: dbdimp.h,v 1.16 1996/10/29 18:17:23 timbo Exp $

   Copyright (c) 1994,1995  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file.

*/

/* #define MAX_COLS 1025 */

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

    /* Select Column Output Details	*/
    int        done_desc;   /* have we described this sth yet ?	*/
    imp_fbh_t *fbh;	    /* array of imp_fbh_t structs	*/
    char      *fbh_cbuf;    /* memory for all field names       */
    int       t_dbsize;     /* raw data width of a row		*/
    sb4   long_buflen;      /* length for long/longraw (if >0)	*/
    bool  long_trunc_ok;    /* is truncating a long an error	*/

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
    sb2  dbtype;
    sb1  *cbuf;		/* ptr to name of select-list item */
    sb4  cbufl;		/* length of select-list item name */
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

    sb2 indp;		/* null indicator			*/
    char *progv;
    ub2 arcode;
    ub2 alen;

    bool is_inout;
    int alen_incnull;	/* 0 or 1 if alen should include null	*/
    char name[1];	/* struct is malloc'd bigger as needed	*/
};


void	ora_error _((SV *h, Lda_Def *lda, int rc, char *what));
void	fbh_dump _((imp_fbh_t *fbh, int i, int cacheidx));

void	dbd_init _((dbistate_t *dbistate));
void	dbd_preparse _((imp_sth_t *imp_sth, char *statement));
int 	dbd_describe _((SV *h, imp_sth_t *imp_sth));
int 	dbd_st_blob_read _((SV *sth, int field, long offset, long len,
			SV *destrv, long destoffset));

/* end */
