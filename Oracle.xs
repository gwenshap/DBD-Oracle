#include "Oracle.h"

DBISTATE_DECLARE;
 
MODULE = DBD::Oracle    PACKAGE = DBD::Oracle

I32
constant()
    PROTOTYPE:
    ALIAS:
    OCI = 0
    ORA_VARCHAR2= 1
    ORA_NUMBER	= 2
    ORA_LONG	= 8
    ORA_ROWID	= 11
    ORA_DATE	= 12
    ORA_RAW	= 23
    ORA_LONGRAW	= 24
    ORA_CHAR	= 96
    ORA_MLSLABEL= 105
    ORA_NTY	= 108
    ORA_CLOB	= 112
    ORA_BLOB	= 113
    CODE:
    if (!ix) {
	char *what = GvNAME(CvGV(cv));
	if (strEQ(what,"OCI"))
#ifdef OCI_V8_SYNTAX
	    RETVAL = 8;
#else
	    RETVAL = 7;
#endif
	else croak("Unknown DBD::Oracle constant '%s'", what);
    }
    else RETVAL = ix;
    OUTPUT:
    RETVAL

MODULE = DBD::Oracle    PACKAGE = DBD::Oracle

INCLUDE: Oracle.xsi

MODULE = DBD::Oracle    PACKAGE = DBD::Oracle::st

void
ora_fetch(sth)
    SV *	sth
    PPCODE:
    /* fetchrow: but with scalar fetch returning NUM_FIELDS for Oraperl	*/
    /* This code is called _directly_ by Oraperl.pm bypassing the DBI.	*/
    /* as a result we have to do some things ourselves (like calling	*/
    /* CLEAR_ERROR) and we loose the tracing that the DBI offers :-(	*/
    D_imp_sth(sth);
    AV *av;
    int debug = DBIc_DEBUGIV(imp_sth);
    if (dbis->debug > debug)
	debug = dbis->debug;
    DBIh_CLEAR_ERROR(imp_sth);
    if (GIMME == G_SCALAR) {	/* XXX Oraperl	*/
	/* This non-standard behaviour added only to increase the	*/
	/* performance of the oraperl emulation layer (Oraperl.pm)	*/
	if (!imp_sth->done_desc && !dbd_describe(sth, imp_sth))
		XSRETURN_UNDEF;
	XSRETURN_IV(DBIc_NUM_FIELDS(imp_sth));
    }
    if (debug >= 2)
	fprintf(DBILOGFP, "    -> ora_fetch\n");
    av = dbd_st_fetch(sth, imp_sth);
    if (av) {
	int num_fields = AvFILL(av)+1;
	int i;
	EXTEND(sp, num_fields);
	for(i=0; i < num_fields; ++i) {
	    PUSHs(AvARRAY(av)[i]);
	}
	if (debug >= 2)
	    fprintf(DBILOGFP, "    <- (...) [%d items]\n", num_fields);
    }
    else {
	if (debug >= 2)
	    fprintf(DBILOGFP, "    <- () [0 items]\n");
    }
    if (debug >= 2 && SvTRUE(DBIc_ERR(imp_sth)))
	fprintf(DBILOGFP, "    !! ERROR: %s %s",
	    neatsvpv(DBIc_ERR(imp_sth),0), neatsvpv(DBIc_ERRSTR(imp_sth),0));

