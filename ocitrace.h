#ifdef OCI_V8_SYNTAX

/* OCI functions "wrapped" to produce tracefile dumps (may be handy when giving
  diagnostic info to Oracle Support, or just learning about OCI)
  Macros are named "_log" as a mnemonic that they log to the tracefile if needed
  Macros named "_log_stat" return status in last parameter.
*/

#define DBD_OCI_TRACEON	(DBIS->debug >= 6)
#define DBD_OCI_TRACEFP	(DBILOGFP)
#define OciTp		("OCI")			/* OCI Trace Prefix */
#define OciTstr(s)	((s) ? (text*)(s) : (text*)"<NULL>")
#define ul_t(v)		((unsigned long)(v))
#define pul_t(v)	((unsigned long *)(v))
#define sl_t(v)		((signed long)(v))
#define psl_t(v)	((signed long *)(v))

/* XXX TO DO

    1.	Add parenthesis around all macro args. (or do item 4 below case-by-case)
    DMG: Partly done, sort of. At least the types all match the doc'd casts, anyway.

    2.	#define a set of OciTxxx macros for different types of parameters
	that would allow
	a: casting to be hidden
	b: casting easily changed on different platforms (64bit etc)
	c: mapping of some type values to strings,
	d: return pointed-to value instead of pointer where applicable

   How to output arguments that are handles to opaque entities (OCIEnv*, etc)?
   Output of pointer address is a quick n' dirty way of identifying
   any number of handles that may be allocated.... yuck...
   It sure would be nice to give something more mnemonic! (and meaningful!)
   XXX Turn pointers into variable names by adding a prefix letter and, where
	appropriate an &, thus: "...,&p%ld,...",
	If done well the log will read like a compilable program.
*/


#define OCIAttrGet_log_stat(th,ht,ah,sp,at,eh,stat)                    \
	stat = OCIAttrGet(th,ht,ah,sp,at,eh);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sAttrGet(%p,%lu,%p,%p,%lu,%p)=%s\n",			\
	  OciTp, (void*)th,ul_t(ht),(void*)ah,pul_t(sp),ul_t(at),(void*)eh,\
	  oci_status_name(stat)),stat : stat

#define OCIAttrGet_parmdp(imp_sth, parmdp, p, l, a, stat)              \
	OCIAttrGet_log_stat(parmdp, OCI_DTYPE_PARAM,			\
		(void*)(p), (l), (a), imp_sth->errhp, stat)

#define OCIAttrGet_stmhp_stat(imp_sth, p, l, a, stat)                  \
	OCIAttrGet_log_stat(imp_sth->stmhp, OCI_HTYPE_STMT,		\
		(void*)(p), (l), (a), imp_sth->errhp, stat)

#define OCIAttrSet_log_stat(th,ht,ah,s,a,eh,stat)                      \
	stat=OCIAttrSet(th,ht,ah,s,a,eh);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sAttrSet(%p,%u,%p,%lu,%lu,%p)=%s\n",			\
	  OciTp, (void*)th,(ht),(void*)(ah),ul_t(s),ul_t(a),(void*)eh,	\
	  oci_status_name(stat)),stat : stat

#define OCIBindByName_log_stat(sh,bp,eh,p,pl,v,vs,dt,in,al,rc,mx,cu,md,stat)  \
	stat=OCIBindByName(sh,bp,eh,p,pl,v,vs,dt,in,al,rc,mx,cu,md);	\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sBindByName(%p,%p,%p,\"%s\",%ld,%p,%ld,%u,%p,%p,%p,%lu,%p,%lu)=%s\n",\
	  OciTp, (void*)sh,(void*)bp,(void*)eh,p,sl_t(pl),(void*)(v),	\
	  sl_t(vs),(ub2)(dt),(void*)(in),(ub2*)(al),(ub2*)(rc),		\
	  ul_t((mx)),pul_t((cu)),ul_t((md)),				\
	  oci_status_name(stat)),stat : stat

#define OCIBindDynamic_log(bh,eh,icx,cbi,ocx,cbo,stat)                 \
	stat=OCIBindDynamic(bh,eh,icx,cbi,ocx,cbo);			\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sBindDynamic(%p,%p,%p,%p,%p,%p)=%s\n",			\
	  OciTp, (void*)bh,(void*)eh,(void*)icx,(void*)cbi,		\
	  (void*)ocx,(void*)cbo,					\
	  oci_status_name(stat)),stat : stat

#define OCIDefineByPos_log_stat(sh,dp,eh,p,vp,vs,dt,ip,rp,cp,m,stat)   \
	stat=OCIDefineByPos(sh,dp,eh,p,vp,vs,dt,ip,rp,cp,m);		\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sDefineByPos(%p,%p,%p,%lu,%p,%ld,%u,%p,%p,%p,%lu)=%s\n",	\
	  OciTp, (void*)sh,(void*)dp,(void*)eh,ul_t((p)),(void*)(vp),	\
	  sl_t(vs),(ub2)dt,(void*)(ip),(ub2*)(rp),(ub2*)(cp),ul_t(m),	\
	  oci_status_name(stat)),stat : stat

#define OCIDescribeAny_log_stat(sh,eh,op,ol,opt,il,ot,dh,stat)         \
	stat=OCIDescribeAny(sh,eh,op,ol,opt,il,ot,dh);			\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sDescribeAny(%p,%p,%p,%lu,%u,%u,%u,%p)=%s\n",     		\
	  OciTp, (void*)sh,(void*)eh,(void*)op,ul_t(ol),		\
	  (ub1)opt,(ub1)il,(ub1)ot,(void*)dh,				\
	  oci_status_name(stat)),stat : stat

#define OCIDescriptorAlloc_ok(envhp, p, t)                             \
	if (DBD_OCI_TRACEON) fprintf(DBD_OCI_TRACEFP,			\
	  "%sDescriptorAlloc(%p,%p,%lu,0,0)\n",        			\
	  OciTp,(void*)envhp,(void*)(p),ul_t(t));			\
	if (OCIDescriptorAlloc((envhp), (void**)(p), (t), 0, 0)==OCI_SUCCESS);	\
	else croak("OCIDescriptorAlloc (type %ld) failed",t)

#define OCIDescriptorFree_log(d,t)                                     \
	if (DBD_OCI_TRACEON) fprintf(DBD_OCI_TRACEFP,			\
	  "%sDescriptorFree(%p,%lu)\n", OciTp, (void*)d,ul_t(t));	\
	OCIDescriptorFree(d,t)

#define OCIEnvInit_log_stat(ev,md,xm,um,stat)                          \
	stat=OCIEnvInit(ev,md,xm,um);					\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sEnvInit(%p,%lu,%lu,%p)=%s\n",				\
	  OciTp, (void*)ev,ul_t(md),ul_t(xm),(void*)um,			\
	  oci_status_name(stat)),stat : stat

#define OCIErrorGet_log_stat(hp,rn,ss,ep,bp,bs,t, stat)			\
	((stat = OCIErrorGet(hp,rn,ss,ep,bp,bs,t)),			\
	((DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sErrorGet(%p,%lu,\"%s\",%p,\"%s\",%lu,%lu)=%s\n",		\
	  OciTp, (void*)hp,ul_t(rn),OciTstr(ss),psl_t(ep),		\
	  bp,ul_t(bs),ul_t(t), oci_status_name(stat)),stat : stat))

#define OCIHandleAlloc_log_stat(ph,hp,t,xs,ump,stat)                   \
	stat=OCIHandleAlloc(ph,hp,t,xs,ump);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sHandleAlloc(%p,%p,%lu,%lu,%p)=%s\n",			\
	  OciTp, (void*)ph,(void*)hp,ul_t(t),ul_t(xs),(void*)ump,	\
	  oci_status_name(stat)),stat : stat

#define OCIHandleAlloc_ok(envhp, p, t, stat)                           \
	OCIHandleAlloc_log_stat((envhp),(void**)(p),(t),0,0, stat);	\
	if (stat==OCI_SUCCESS) ;					\
	else croak("OCIHandleAlloc (type %lu) failed",ul_t(t))

#define OCIHandleFree_log_stat(hp,t,stat)                              \
	stat=OCIHandleFree(  (hp), (t));				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sHandleFree(%p,%lu)=%s\n",OciTp,(void*)hp,ul_t(t),		\
	  oci_status_name(stat)),stat : stat

#define OCIInitialize_log_stat(md,cp,mlf,rlf,mfp,stat)                 \
	stat=OCIInitialize(md,cp,mlf,rlf,mfp);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sInitialize(%lu,%p,%p,%p,%p)=%s\n",				\
	  OciTp, ul_t(md),(void*)cp,(void*)mlf,(void*)rlf,(void*)mfp,	\
	  oci_status_name(stat)),stat : stat

#define OCILobGetLength_log_stat(sh,eh,lh,l,stat)                      \
	stat=OCILobGetLength(sh,eh,lh,l);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sLobGetLength(%p,%p,%p,%p)=%s\n",				\
	  OciTp, (void*)sh,(void*)eh,(void*)lh,pul_t(l),		\
	  oci_status_name(stat)),stat : stat

#define OCILobRead_log_stat(sv,eh,lh,am,of,bp,bl,cx,cb,csi,csf,stat)   \
	stat=OCILobRead(sv,eh,lh,am,of,bp,bl,cx,cb,csi,csf);		\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sLobRead(%p,%p,%p,%p,%lu,%p,%lu,%p,%p,%u,%u)=%s\n",		\
	  OciTp, (void*)sv,(void*)eh,(void*)lh,pul_t(am),ul_t(of),	\
	  (void*)bp,ul_t(bl),(void*)cx,(void*)cb,(ub2)csi,(ub1)csf,	\
	  oci_status_name(stat)),stat : stat

#define OCILobTrim_log_stat(sv,eh,lh,l,stat)                           \
	stat=OCILobTrim(sv,eh,lh,l);					\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sLobtrim(%p,%p,%p,%lu)=%s\n",				\
	  OciTp, (void*)sv,(void*)eh,(void*)lh,ul_t(l),			\
	  oci_status_name(stat)),stat : stat

#define OCILobWrite_log_stat(sv,eh,lh,am,of,bp,bl,p,cx,cb,csi,csf,stat) \
	stat=OCILobWrite(sv,eh,lh,am,of,bp,bl,p,cx,cb,csi,csf);		\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sLobWrite(%p,%p,%p,%p,%lu,%p,%lu,%u,%p,%p,%u,%u)=%s\n",	\
	  OciTp, (void*)sv,(void*)eh,(void*)lh,pul_t(am),ul_t(of),	\
	  (void*)bp,ul_t(bl),(ub1)p,					\
	  (void*)cx,(void*)cb,(ub2)csi,(ub1)csf,			\
	  oci_status_name(stat)),stat : stat

#define OCIParamGet_log_stat(hp,ht,eh,pp,ps,stat)                      \
	stat=OCIParamGet(hp,ht,eh,pp,ps);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sParamGet(%p,%lu,%p,%p,%lu)=%s\n",				\
	  OciTp, (void*)hp,ul_t((ht)),(void*)eh,(void*)pp,ul_t(ps),	\
	  oci_status_name(stat)),stat : stat

#define OCIServerAttach_log_stat(imp_dbh, dbname,stat)                 \
	stat=OCIServerAttach( imp_dbh->srvhp, imp_dbh->errhp,		\
	  (text*)dbname, strlen(dbname), 0);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sServerAttach(%p, %p, \"%s\", %d, 0)=%s\n",			\
	  OciTp, (void*)imp_dbh->srvhp,(void*)imp_dbh->errhp, dbname,	\
	  strlen(dbname), oci_status_name(stat)),stat : stat

#define OCIStmtExecute_log_stat(sv,st,eh,i,ro,si,so,md,stat)           \
	stat=OCIStmtExecute(sv,st,eh,i,ro,si,so,md);			\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sStmtExecute(%p,%p,%p,%lu,%lu,%p,%p,%lu)=%s\n",		\
	  OciTp, (void*)sv,(void*)st,(void*)eh,ul_t((i)),		\
	  ul_t((ro)),(void*)(si),(void*)(so),ul_t((md)),		\
	  oci_status_name(stat)),stat : stat

#define OCIStmtFetch_log_stat(sh,eh,nr,or,md,stat)                     \
	stat=OCIStmtFetch(sh,eh,nr,or,md);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sStmtFetch(%p,%p,%lu,%u,%lu)=%s\n",				\
	  OciTp, (void*)sh,(void*)eh,ul_t(nr),(ub2)or,ul_t(md),		\
	  oci_status_name(stat)),stat : stat

#define OCIStmtPrepare_log_stat(sh,eh,s,sl,l,m,stat)                   \
	stat=OCIStmtPrepare(sh,eh,s,sl,l,m);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sStmtPrepare(%p,%p,'%s',%lu,%lu,%lu)=%s\n",			\
	  OciTp, (void*)sh,(void*)eh,s,ul_t(sl),ul_t(l),ul_t(m),	\
	  oci_status_name(stat)),stat : stat

#define OCIServerDetach_log_stat(sh,eh,md,stat)                        \
	stat=OCIServerDetach(sh,eh,md);					\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sServerDetach(%p,%p,%lu)=%s\n",				\
	  OciTp, (void*)sh,(void*)eh,ul_t(md),				\
	  oci_status_name(stat)),stat : stat

#define OCISessionBegin_log_stat(sh,eh,uh,cr,md,stat)                  \
	stat=OCISessionBegin(sh,eh,uh,cr,md);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sSessionBegin(%p,%p,%p,%lu,%lu)=%s\n",			\
	  OciTp, (void*)sh,(void*)eh,(void*)uh,ul_t(cr),ul_t(md),	\
	  oci_status_name(stat)),stat : stat

#define OCISessionEnd_log_stat(sh,eh,ah,md,stat)                       \
	stat=OCISessionEnd(sh,eh,ah,md);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sSessionEnd(%p,%p,%p,%lu)=%s\n",				\
	  OciTp, (void*)sh,(void*)eh,(void*)ah,ul_t(md),		\
	  oci_status_name(stat)),stat : stat

#define OCITransCommit_log_stat(sh,eh,md,stat)                         \
	stat=OCITransCommit(sh,eh,md);					\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sTransCommit(%p,%p,%lu)=%s\n",				\
	  OciTp, (void*)sh,(void*)eh,ul_t(md),				\
	  oci_status_name(stat)),stat : stat

#define OCITransRollback_log_stat(sh,eh,md,stat)                       \
	stat=OCITransRollback(sh,eh,md);				\
	(DBD_OCI_TRACEON) ? fprintf(DBD_OCI_TRACEFP,			\
	  "%sTransRollback(%p,%p,%lu)=%s\n",				\
	  OciTp, (void*)sh,(void*)eh,ul_t(md),				\
	  oci_status_name(stat)),stat : stat

#endif /* OCI_V8_SYNTAX */
