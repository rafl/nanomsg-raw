#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <nanomsg/nn.h>
#include <nanomsg/pair.h>

#define PERL_NN_SET_ERRNO STMT_START { \
  SV *errsv = get_sv("!", GV_ADD); \
  sv_setiv(errsv, errno); \
  sv_setpv(errsv, nn_strerror(errno)); \
} STMT_END

typedef int perl_nn_int;
typedef int perl_nn_int_bool;
typedef void * perl_nn_messagebuf;

AV *symbol_names;

XS_INTERNAL(XS_NanoMsg_nn_constant);
XS_INTERNAL(XS_NanoMsg_nn_constant)
{
  dVAR;
  dXSARGS;
  IV ix = XSANY.any_iv;
  dXSTARG;
  if (items != 0)
    croak_xs_usage(cv,  "");
  XSprePUSH;
  PUSHi((IV)ix);
  XSRETURN(1);
}

static SV *
perl_nn_upgrade_to_message (pTHX_ SV *sv)
{
  SV *obj = newSV(0);
  sv_upgrade(sv, SVt_RV);
  if (SvROK(sv))
    SvREFCNT_dec(SvRV(sv));
  SvRV_set(sv, obj);
  SvROK_on(sv);
  sv_upgrade(obj, SVt_PV);
  SvPOK_on(obj);
  SvCUR_set(obj, 0);
  SvLEN_set(obj, 0);
  sv_bless(sv, gv_stashpvs("NanoMsg::Raw::Message", GV_ADD));
  SvREADONLY_on(obj);
  return obj;
}

static void *
perl_nn_invalidate_message (pTHX_ SV *sv)
{
  SV *obj = SvRV(sv);
  void *ret = SvPVX(obj);
  SvREADONLY_off(obj);
  SvPOK_off(obj);
  SvPVX(obj) = NULL;
  sv_bless(sv, gv_stashpvs("NanoMsg::Raw::Message::Freed", GV_ADD));
  return ret;
}

MODULE=NanoMsg  PACKAGE=NanoMsg::Raw

PROTOTYPES: DISABLE

perl_nn_int
nn_socket (domain, protocol)
    int domain
    int protocol

perl_nn_int_bool
nn_close (s)
    int s

perl_nn_int_bool
nn_setsockopt (s, level, option, optval)
    int s
    int level
    int option
    SV *optval
  PREINIT:
    const void *c_optval;
    size_t c_optvallen;
    int a_int; /* needed at this scope so we can pass a pointer to it in the
                  generated CODE section */
  INIT:
    if (SvPOKp(optval)) {
      c_optval = SvPV_const(optval, c_optvallen);
    }
    else {
      a_int = (int)SvIV(optval);
      c_optval = &a_int;
      c_optvallen = sizeof(int);
    }
  C_ARGS:
    s, level, option, c_optval, c_optvallen

SV *
nn_getsockopt (s, level, option)
    int s
    int level
    int option
  PREINIT:
    size_t optvallen;
    int ret;
  INIT:
    RETVAL = newSV(257);
	(void)SvPOK_only(RETVAL);
  CODE:
    ret = nn_getsockopt(s, level, option, SvPVX(RETVAL), &optvallen);
  POSTCALL:
    if (ret < 0) {
      PERL_NN_SET_ERRNO;
      XSRETURN_UNDEF;
    }
    SvCUR_set(RETVAL, optvallen);
    *SvEND(RETVAL) = '\0';
  OUTPUT:
    RETVAL

perl_nn_int
nn_bind (s, addr)
    int s
    const char *addr

perl_nn_int
nn_connect (s, addr)
    int s
    const char *addr

perl_nn_int_bool
nn_shutdown (s, how)
    int s
    int how

perl_nn_int
nn_send (s, buf, flags)
    int s
    SV *buf
    int flags
  PREINIT:
    void *c_buf;
    size_t len;
  INIT:
    if (sv_isobject(buf) && sv_isa(buf, "NanoMsg::Raw::Message")) {
      c_buf = &SvPVX(SvRV(buf));
      len = NN_MSG;
    }
    else {
      c_buf = SvPV(buf, len);
    }
  C_ARGS:
    s, c_buf, len, flags
  POSTCALL:
    if (len == NN_MSG)
      perl_nn_invalidate_message(aTHX_ buf);

int
nn_recv (s, buf, len, flags)
    int s
    SV *buf
    size_t len
    int flags
  PREINIT:
    void *c_buf;
  INIT:
    if (len == NN_MSG) {
      c_buf = &SvPVX(perl_nn_upgrade_to_message(aTHX_ buf));
    }
    else {
      if (!SvOK(buf))
        sv_setpvs(buf, "");
      SvPV_force_nolen(buf);
      c_buf = SvGROW(buf, len+1);
    }
  C_ARGS:
    s, c_buf, len, flags
  POSTCALL:
    if (RETVAL < 0) {
      PERL_NN_SET_ERRNO;
      XSRETURN_UNDEF;
    }
    if (len == NN_MSG) {
      SvPOK_on(SvRV(buf));
      SvCUR_set(SvRV(buf), RETVAL);
    }
    else {
      SvCUR_set(buf, (int)len < RETVAL ? (int)len : RETVAL);
      *SvEND(buf) = '\0';
      (void)SvPOK_only(buf);
    }

# TODO: cmsg

perl_nn_int
nn_sendmsg (s, flags, ...)
    int s
    int flags
  PREINIT:
    struct nn_msghdr hdr;
    struct nn_iovec *iov;
    int iovlen, i;
  INIT:
    iovlen = items - 2;
    Newx(iov, iovlen, struct nn_iovec);
    for (i = 0; i < iovlen; i++)
      iov[i].iov_base = SvPV(ST(i + 2), iov[i].iov_len);
    memset(&hdr, 0, sizeof(hdr));
    hdr.msg_iov = iov;
    hdr.msg_iovlen = iovlen;
  C_ARGS:
    s, &hdr, flags
  CLEANUP:
    Safefree(iov);

perl_nn_int
nn_recvmsg (s, flags, ...)
    int s
    int flags
  PREINIT:
    struct nn_msghdr hdr;
    struct nn_iovec *iov;
    int iovlen, i;
    size_t nbytes;
  INIT:
    iovlen = items - 2;
    Newx(iov, iovlen, struct nn_iovec);
    for (i = 0; i < iovlen; i += 2) {
      SV *len = ST(i + 2);
      SV *svbuf = ST(i + 3);
      if (!SvOK(svbuf))
        sv_setpvs(svbuf, "");
      SvPV_force_nolen(svbuf);
      SvGROW(svbuf, SvIV(len));
      iov[i].iov_base = SvPVX(svbuf);
      iov[i].iov_len = SvLEN(svbuf) - 1;
    }
    memset (&hdr, 0, sizeof (hdr));
    hdr.msg_iov = iov;
    hdr.msg_iovlen = iovlen;
  C_ARGS:
    s, &hdr, flags
  POSTCALL:
    nbytes = RETVAL;
    for (i = 0; i < iovlen; i++) {
      size_t max = iov[i].iov_len < nbytes ? iov[i].iov_len : nbytes;
      SvCUR_set(ST(i + 3), max);
      if (nbytes > 0)
        nbytes -= max;
    }
  CLEANUP:
    Safefree(iov);

perl_nn_messagebuf
nn_allocmsg (size, type)
    size_t size
    int type

const char *
nn_strerror (errnum)
    int errnum

perl_nn_int
nn_device (s1, s2)
    int s1
    int s2

void
nn_term ()

void
_symbols ()
  PREINIT:
    int i;
  PPCODE:
    for (i = 0; i <= av_len(symbol_names); i++)
      mPUSHs(SvREFCNT_inc(*av_fetch(symbol_names, i, 0)));

BOOT:
  symbol_names = newAV();
  {
    CV *cv;
    const char *sym;
    int val, i = 0;
    char name[4096] = "NanoMsg::Raw::";
    size_t prefixlen = sizeof("NanoMsg::Raw::") - 1;
    while ((sym = nn_symbol(i++, &val)) != NULL) {
      size_t symlen = strlen(sym);
      av_push(symbol_names, newSVpv(sym, symlen));
      memcpy(name + prefixlen, sym, symlen+1);
      cv = newXS(name, XS_NanoMsg_nn_constant, file);
      XSANY.any_iv = val;
    }

    memcpy(name + prefixlen, "NN_MSG", sizeof("NN_MSG"));
    cv = newXS(name, XS_NanoMsg_nn_constant, file);
    XSANY.any_iv = NN_MSG;
  }

MODULE=NanoMsg  PACKAGE=NanoMsg::Raw::Message

void
copy (sv, src)
    SV *sv
    SV *src
  PREINIT:
    const void *buf;
    STRLEN len;
    SV *obj;
  INIT:
    obj = SvRV(sv);
    buf = SvPV(src, len);
  CODE:
    memcpy(SvPVX(obj), buf, len);
    SvCUR_set(obj, len);

void
DESTROY (sv)
    SV *sv
  CODE:
    nn_freemsg(perl_nn_invalidate_message(aTHX_ sv));
