#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <nanomsg/nn.h>

MODULE=NanoMsg  PACKAGE=NanoMsg

PROTOTYPES: DISABLE

# TODO: constants

int
nn_socket (domain, protocol)
    int domain
    int protocol

int
nn_close (s)
    int s

int
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
  INIT:
    RETVAL = newSV(257);
	(void)SvPOK_only(RETVAL);
  CODE:
    if (nn_getsockopt(s, level, option, SvPVX(RETVAL), &optvallen))
      XSRETURN_UNDEF;
  POSTCALL:
    SvCUR_set(RETVAL, optvallen);
    *SvEND(RETVAL) = '\0';
  OUTPUT:
    RETVAL

int
nn_bind (s, addr)
    int s
    const char *addr

int
nn_connect (s, addr)
    int s
    const char *addr

int
nn_shutdown (s, how)
    int s
    int how

int
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
    if (RETVAL < 0)
      XSRETURN_UNDEF;
    SvCUR_set(buf, RETVAL);
    *SvEND(buf) = '\0';
	(void)SvPOK_only(buf);
  OUTPUT:
    RETVAL

# TODO: sendmsg, recvmsg, allocmsg, freemsg, cmsg

# TODO: use this to set the pv part of $!
const char *
nn_strerror (errnum)
    int errnum

int
nn_device (s1, s2)
    int s1
    int s2

void
nn_term ()
