/*
   $Id: dbdimp.h,v 1.23 1998/11/29 00:14:07 timbo Exp $

   Copyright (c) 1994,1995  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/


/* try uncommenting this line if you get a syntax error on
 *	 typedef signed long  sbig_ora;
 * in oratypes.h for Oracle 7.1.3. Don't you just love Oracle!
 */
/* now changed to only define it for non ansi-ish compilers	*/
#ifndef CAN_PROTOTYPE
#define signed
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

/* This is slightly backwards because we want to auto-detect OCI8  */
/* and thus the existance of oci.h while still working for Oracle7 */
#include <oratypes.h>
#include <ocidfn.h>

#if defined(SQLT_NTY) && !defined(NO_OCI8)	/* use Oracle 8 */

#ifdef dirty
#undef dirty /* appears in OCI prototypes as parameter name */
#endif
#include <oci.h>

#else										/* use Oracle 7 */

#ifdef CAN_PROTOTYPE
# include <ociapr.h>
#else
# include <ocikpr.h>
#endif

#ifndef HDA_SIZE
#define HDA_SIZE 512
#endif

#ifndef FT_SELECT	/* old Oracle version		*/
#define FT_SELECT 4	/* from rdbms/demo/ocidem.h */
#endif

#endif


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

    Lda_Def ldabuf;
    Lda_Def *lda;		/* points to ldabuf	*/
#ifdef OCI_V8_SYNTAX
    OCIEnv *envhp;		/* copy of drh pointer	*/
    OCIError *errhp;
    OCIServer *srvhp;
    OCISvcCtx *svchp;
    OCISession *authp;
#else
    ub1     hdabuf[HDA_SIZE];
    ub1     *hda;		/* points to hdabuf	*/
#endif

    int RowCacheSize;
};


/* Define sth implementor data structure */
struct imp_sth_st {
    dbih_stc_t com;		/* MUST be first element in structure	*/

#ifdef OCI_V8_SYNTAX
    OCIError *errhp;		/* copy of dbh pointer	*/
    OCIServer *srvhp;		/* copy of dbh pointer	*/
    OCISvcCtx *svchp;		/* copy of dbh pointer	*/
    OCIStmt *stmhp;
    ub2 stmt_type;		/* OCIAttrGet OCI_ATTR_STMT_TYPE	*/
#else
    Cda_Def *cda;	/* currently just points to cdabuf below */
    Cda_Def cdabuf;
#endif

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
    imp_sth_t *imp_sth;	/* 'parent' statement */

    /* Oracle's description of the field	*/
#ifdef OCI_V8_SYNTAX
    OCIParam  *parmdp;
    OCIDefine *defnp;
    ub2  dbsize;
    ub2  dbtype;	/* actual type of field (see ftype)	*/
    ub1  prec;
    sb1  scale;
    ub1  nullok;
#else
    sb4  dbsize;
    sb2  dbtype;	/* actual type of field (see ftype)	*/
    sb2  prec;
    sb2  scale;
    sb2  nullok;
    sb4  cbufl;		/* length of select-list item 'name'	*/
#endif
    SV   *name_sv;	/* only set for OCI8			*/
    text *name;
    sb4  disize;	/* max display/buffer size		*/

    /* Our storage space for the field data as it's fetched	*/
    sword ftype;	/* external datatype we wish to get	*/
    fb_ary_t *fb_ary;	/* field buffer array			*/
};

/*	Table 6-13 Attributes Belonging to Columns of Tables or Views 

 Attribute                      Description                                                 Attribute
                                                                                            Datatype  
 OCI_ATTR_DATA_SIZE  		the maximum size of the column. This length is returned in
                                bytes and not characters for strings and raws. It returns 22 for
                                NUMBERs.  
                                                                                            ub2  
 OCI_ATTR_DATA_TYPE  
                                the data type of the column. See "Note on Datatype Codes"
                                on page 6-4.  
                                                                                            ub2  
 OCI_ATTR_PRECISION  
                                the precision of numeric columns. If a describe returns a value
                                of zero for precision or -127 for scale, this indicates that the
                                item being described is uninitialized; i.e., it is NULL in the data
                                dictionary.  
                                                                                            ub1  
 OCI_ATTR_SCALE  
                                the scale of numeric columns. If a describe returns a value of
                                zero for precision or -127 for scale, this indicates that the
                                item being described is uninitialized; i.e., it is NULL in the data
                                dictionary.  
                                                                                            sb1  
 OCI_ATTR_IS_NULL  
                                returns 0 if null values are not permitted for the column  
                                                                                            ub1  
 OCI_ATTR_TYPE_NAME  
                                returns a string which is the type name. The returned value
                                will contain the type name if the data type is SQLT_NTY or
                                SQLT_REF. If the data type is SQLT_NTY, the name of the
                                named data type's type is returned. If the data type is
                                SQLT_REF, the type name of the named data type pointed to
                                by the REF is returned  
                                                                                            text *  
 OCI_ATTR_SCHEMA_NAME  
                                returns a string with the schema name under which the type
                                has been created  
                                                                                            text *  
 OCI_ATTR_REF_TDO  
                                the REF of the TDO for the type, if the column type is an
                                object type  
                                                                                            OCIRef *  
 OCI_ATTR_CHARSET_ID  
                                the character set id, if the column is of a string/character type
                                 
                                                                                            ub2  
 OCI_ATTR_CHARSET_FORM  
                                the character set form, if the column is of a string/character
                                type  
                                                                                            ub1  
*/


typedef struct phs_st phs_t;    /* scalar placeholder   */

struct phs_st {  	/* scalar placeholder EXPERIMENTAL	*/
    sword ftype;	/* external OCI field type		*/

    SV	*sv;		/* the scalar holding the value		*/
    int sv_type;	/* original sv type at time of bind	*/
    bool is_inout;

    IV  maxlen;		/* max possible len (=allocated buffer)	*/

    ub4 aryelem_max;	/* max elements in allocated array	*/
    ub4 aryelem_cur;	/* current elements in allocated array	*/
#ifdef OCI_V8_SYNTAX
    OCIBind *bndhp;
#endif

    /* these will become an array one day */
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
