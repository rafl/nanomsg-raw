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

#define PERL_NN_HANDLE_FAILURE_RETVAL PERL_NN_HANDLE_FAILURE(RETVAL)

#define PERL_NN_HANDLE_FAILURE(ret) STMT_START { \
  if (ret < 0) { \
    PERL_NN_SET_ERRNO; \
    XSRETURN_UNDEF; \
  } \
} STMT_END

MODULE=NanoMsg  PACKAGE=NanoMsg

PROTOTYPES: DISABLE

# TODO: constants

int
nn_socket (domain, protocol)
    int domain
    int protocol
  POSTCALL:
    PERL_NN_HANDLE_FAILURE_RETVAL;
    if (RETVAL < 0)
      XSRETURN_UNDEF;

int
nn_close (s)
    int s
  POSTCALL:
    PERL_NN_HANDLE_FAILURE_RETVAL;
    RETVAL = !RETVAL;

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
  POSTCALL:
    PERL_NN_HANDLE_FAILURE_RETVAL;
    RETVAL = !RETVAL;

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
    PERL_NN_HANDLE_FAILURE(ret);
    SvCUR_set(RETVAL, optvallen);
    *SvEND(RETVAL) = '\0';
  OUTPUT:
    RETVAL

int
nn_bind (s, addr)
    int s
    const char *addr
  POSTCALL:
    PERL_NN_HANDLE_FAILURE_RETVAL;

int
nn_connect (s, addr)
    int s
    const char *addr
  POSTCALL:
    PERL_NN_HANDLE_FAILURE_RETVAL;

int
nn_shutdown (s, how)
    int s
    int how
  POSTCALL:
    PERL_NN_HANDLE_FAILURE_RETVAL;
    RETVAL = !RETVAL;

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
  POSTCALL:
    PERL_NN_HANDLE_FAILURE_RETVAL;

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
    PERL_NN_HANDLE_FAILURE_RETVAL;
    SvCUR_set(buf, RETVAL);
    *SvEND(buf) = '\0';
	(void)SvPOK_only(buf);
  OUTPUT:
    RETVAL

# TODO: sendmsg, recvmsg, allocmsg, freemsg, cmsg

const char *
nn_strerror (errnum)
    int errnum

int
nn_device (s1, s2)
    int s1
    int s2
  POSTCALL:
    PERL_NN_HANDLE_FAILURE_RETVAL;


void
nn_term ()

int
AF_SP ()
  CODE:
    RETVAL = AF_SP;
  OUTPUT:
    RETVAL

int
NN_PAIR ()
  CODE:
    RETVAL = NN_PAIR;
  OUTPUT:
    RETVAL
