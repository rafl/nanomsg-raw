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

AV *symbol_names;

XS_INTERNAL(XS_NanoMsg_nn_constant);
XS_INTERNAL(XS_NanoMsg_nn_constant)
{
  dVAR;
  dXSARGS;
  dXSI32;
  dXSTARG;
  if (items != 0)
    croak_xs_usage(cv,  "");
  XSprePUSH;
  PUSHi((IV)ix);
  XSRETURN(1);
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
    c_buf = SvPV(buf, len);
  C_ARGS:
    s, c_buf, len, flags

int
nn_recv (s, buf, len, flags)
    int s
    SV *buf
    size_t len
    int flags
  PREINIT:
    void *c_buf;
  INIT:
    if (!SvOK(buf))
      sv_setpvs(buf, "");
    SvPV_force_nolen(buf);
    c_buf = SvGROW(buf, len+1);
  C_ARGS:
    s, c_buf, len, flags
  POSTCALL:
    if (RETVAL < 0) {
      PERL_NN_SET_ERRNO;
      XSRETURN_UNDEF;
    }
    SvCUR_set(buf, len < RETVAL ? len : RETVAL);
    *SvEND(buf) = '\0';
	(void)SvPOK_only(buf);
  OUTPUT:
    RETVAL

# TODO: allocmsg, freemsg, cmsg

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
    size_t nbytes, max;
  INIT:
    iovlen = items - 2;
    Newx(iov, iovlen, struct nn_iovec);
    for (i = 0; i < iovlen; i++) {
      SV *svbuf = ST(i + 2);
      if (!SvOK(svbuf))
        sv_setpvs(svbuf, "");
      SvPV_force_nolen(svbuf);
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
      SvCUR_set(ST(i + 2), max);
      *SvEND(ST(i + 2)) = '\0';
      if (nbytes > 0)
        nbytes -= max;
    }
  CLEANUP:
    Safefree(iov);

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
    int val, i = 0;
    const char *sym;
    char name[4096] = "NanoMsg::Raw::";
    size_t prefixlen = sizeof("NanoMsg::Raw::") - 1;
    while ((sym = nn_symbol(i++, &val)) != NULL) {
      CV *cv;
      size_t symlen = strlen(sym);
      av_push(symbol_names, newSVpv(sym, symlen));
      memcpy(name + prefixlen, sym, symlen+1);
      cv = newXS(name, XS_NanoMsg_nn_constant, file);
      XSANY.any_i32 = val;
    }
  }
