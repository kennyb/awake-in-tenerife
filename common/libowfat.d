module libowfat;

private import tango.stdc.time;

extern(C):

//alias char[] string;

// general hacks
alias uint ssize_t;

struct iopause_fd {
	
};
/+
struct array {
  char* p;
  long allocated;	/* buf_in bytes */
  ulong initialized;	/* buf_in bytes */

  /* p and allocated nonzero: array is allocated */
  /* p and allocated zero: array is unallocated */
  /* p zero and allocated < 0: array is failed */
};

void* array_allocate(array* x,ulong membersize,long pos);
void* array_get(array* x,ulong membersize,long pos);
void* array_start(array* x);
long array_length(array* x,ulong membersize);
long array_bytes(array* x);
void array_truncate(array* x,ulong membersize,ulong len);
void array_trunc(array* x);
void array_reset(array* x);
void array_fail(array* x);
int array_equal(array* x,array* y);
void array_cat(array* to,array* from);
void array_catb(array* to,char* from,ulong len);
void array_cats(array* to,char* from);
void array_cats0(array* to,char* from);
void array_cat0(array* to);
void array_cate(array* to,array* from,long pos,long stop);

struct buffer {
  char *x;		/* actual buffer space */
  size_t p;		/* current position */
  size_t n;		/* current size of string in buffer */
  size_t a;		/* allocated buffer size */
  int fd;		/* passed as first argument to op */
  ssize_t (*op)();	/* use read(2) or write(2) */
  enum { NOTHING, FREE, MUNMAP };
};

//#define BUFFER_INIT(op,fd,buf,len) { (buf), 0, 0, (len), (fd), (op), NOTHING }
//#define BUFFER_INIT_FREE(op,fd,buf,len) { (buf), 0, 0, (len), (fd), (op), FREE }
//#define BUFFER_INIT_READ(op,fd,buf,len) BUFFER_INIT(op,fd,buf,len) /*obsolete*/
//#define BUFFER_INSIZE 8192
//#define BUFFER_OUTSIZE 8192

void buffer_init(buffer* b,ssize_t (*op)(),int fd,char* y,size_t ylen);
void buffer_init_free(buffer* b,ssize_t (*op)(),int fd,char* y,size_t ylen);
int buffer_mmapread(buffer* b,char* filename);
void buffer_close(buffer* b);

int buffer_flush(buffer* b);
int buffer_put(buffer* b,char* x,size_t len);
int buffer_putalign(buffer* b,char* x,size_t len);
int buffer_putflush(buffer* b,char* x,size_t len);
int buffer_puts(buffer* b,char* x);
int buffer_putsalign(buffer* b,char* x);
int buffer_putsflush(buffer* b,char* x);

int buffer_putm_internal(buffer*b,...);
int buffer_putm_internal_flush(buffer*b,...);
//#define buffer_putm(b,...) buffer_putm_internal(b,__VA_ARGS__,(char*)0)
//#define buffer_putmflush(b,...) buffer_putm_internal_flush(b,__VA_ARGS__,(char*)0)

int buffer_putspace(buffer* b);
int buffer_putnlflush(buffer* b); /* put \n and flush */

//#define buffer_PUTC(s,c) \
//  ( ((s)->a != (s)->p) \
//    ? ( (s)->x[(s)->p++] = (c), 0 ) \
//    : buffer_put((s),&(c),1) \
//  )

ssize_t buffer_get(buffer* b,char* x,size_t len);
int buffer_feed(buffer* b);
int buffer_getc(buffer* b,char* x);
ssize_t buffer_getn(buffer* b,char* x,size_t len);

/* read bytes until the destination buffer is full (len bytes), end of
 * file is reached or the read char is in charset (setlen bytes).  An
 * empty line when looking for \n will write '\n' to x and return 0.  If
 * EOF is reached, \0 is written to the buffer */
ssize_t buffer_get_token(buffer* b,char* x,size_t len,char* charset,size_t setlen);
ssize_t buffer_getline(buffer* b,char* x,size_t len);

/* this predicate is given the string as currently read from the buffer
 * and is supposed to return 1 if the token is complete, 0 if not. */
typedef int (*string_predicate)(char* x,size_t len);

/* like buffer_get_token but the token ends when your predicate says so */
ssize_t buffer_get_token_pred(buffer* b,char* x,size_t len,string_predicate p);

char *buffer_peek(buffer* b);
void buffer_seek(buffer* b,size_t len);

//#define buffer_PEEK(s) ( (s)->x + (s)->p )
//#define buffer_SEEK(s,len) ( (s)->p += (len) )

//#define buffer_GETC(s,c) \
//  ( ((s)->p < (s)->n) \
//    ? ( *(c) = *buffer_PEEK(s), buffer_SEEK((s),1), 1 ) \
//    : buffer_get((s),(c),1) \
//  )

int buffer_copy(buffer* buf_out, buffer* buf_in);

int buffer_putulong(buffer *b, uint l);
int buffer_put8long(buffer *b, uint l);
int buffer_putxlong(buffer *b, uint l);
int buffer_putlong(buffer *b, int l);

int buffer_putlonglong(buffer* b, long);
int buffer_putulonglong(buffer* b, ulong l);

int buffer_puterror(buffer* b);
int buffer_puterror2(buffer* b, int errnum);

extern buffer *buffer_0;
extern buffer *buffer_0small;
extern buffer *buffer_1;
extern buffer *buffer_1small;
extern buffer *buffer_2;

/* write stralloc to buffer */
int buffer_putsa(buffer* b,stralloc* sa);
/* write stralloc to buffer and flush */
int buffer_putsaflush(buffer* b,stralloc* sa);

/* these "read token" functions return 0 if the token was complete or
 * EOF was hit or -1 on error.  In contrast to the non-stralloc token
 * functions, the separator is also put in the stralloc; use
 * stralloc_chop or stralloc_chomp to get rid of it. */

/* WARNING!  These token reading functions will not clear the stralloc!
 * They _append_ the token to the contents of the stralloc.  The idea is
 * that this way these functions can be used on non-blocking sockets;
 * when you get signalled EAGAIN, just call the functions again when new
 * data is available. */

/* read token from buffer to stralloc */
int buffer_get_token_sa(buffer* b,stralloc* sa,char* charset,size_t setlen);
/* read line from buffer to stralloc */
int buffer_getline_sa(buffer* b,stralloc* sa);

/* same as buffer_get_token_sa but empty sa first */
int buffer_get_new_token_sa(buffer* b,stralloc* sa,char* charset,size_t setlen);
/* same as buffer_getline_sa but empty sa first */
int buffer_getnewline_sa(buffer* b,stralloc* sa);

//typedef int (*sa_predicate)(stralloc* sa);

/* like buffer_get_token_sa but the token ends when your predicate says so */
int buffer_get_token_sa_pred(buffer* b,stralloc* sa,sa_predicate p);
/* same, but clear sa first */
int buffer_get_new_token_sa_pred(buffer* b,stralloc* sa,sa_predicate p);

/* make a buffer from a stralloc.
 * Do not change the stralloc after this! */
void buffer_fromsa(buffer* b,stralloc* sa);


/* byte_chr returns the smallest integer i between 0 and len-1
 * buf_inclusive such that one[i] equals needle, or len if not found. */
size_t byte_chr(void* haystack, size_t len, char needle);

/* byte_rchr returns the largest integer i between 0 and len-1 inclusive
 * such that one[i] equals needle, or len if not found. */
size_t byte_rchr(void* haystack,size_t len,char needle);

/* byte_copy copies buf_in[0] to buf_out[0], buf_in[1] to buf_out[1], ... and buf_in[len-1]
 * to buf_out[len-1]. */
void byte_copy(void* buf_out, size_t len, void* buf_in);

/* byte_copyr copies buf_in[len-1] to buf_out[len-1], buf_in[len-2] to buf_out[len-2],
 * ... and buf_in[0] to buf_out[0] */
void byte_copyr(void* buf_out, size_t len, void* buf_in);

/* byte_diff returns negative, 0, or positive, depending on whether the
 * string a[0], a[1], ..., a[len-1] is lexicographically smaller
 * than, equal to, or greater than the string b[0], b[1], ...,
 * b[len-1]. When the strings are different, byte_diff does not read
 * bytes past the first difference. */
int byte_diff(void* a, size_t len, void* b);

/* byte_zero sets the bytes buf_out[0], buf_out[1], ..., buf_out[len-1] to 0 */
void byte_zero(void* buf_out, size_t len);


/* turn upper case letters to lower case letters, ASCIIZ */
void case_lowers(char *s);
/* turn upper case letters to lower case letters, binary */
void case_lowerb(void *buf,size_t len);

/* like str_diff, ignoring case */
int case_diffs(char *,char *);
/* like byte_diff, ignoring case */
int case_diffb(void *,size_t ,void *);

/* like str_start, ignoring case */
int case_starts(char *,char *);

enum { CDB_HASHSTART = 5381 };
extern uint cdb_hashadd(uint h,ubyte c);
extern uint cdb_hash(ubyte *buf,ulong len);

struct cdb {
  char *map; /* 0 if no map is available */
  long fd;
  uint size; /* buf_initialized if map is nonzero */
  uint loop; /* number of hash slots searched under this key */
  uint khash; /* buf_initialized if loop is nonzero */
  uint kpos; /* buf_initialized if loop is nonzero */
  uint hpos; /* buf_initialized if loop is nonzero */
  uint hslots; /* buf_initialized if loop is nonzero */
  uint dpos; /* buf_initialized if cdb_findnext() returns 1 */
  uint dlen; /* buf_initialized if cdb_findnext() returns 1 */
};

extern void cdb_free(cdb *);
extern void cdb_init(cdb *,long fd);

extern int cdb_read(cdb *,ubyte *,ulong,uint);

extern void cdb_findstart(cdb *);
extern int cdb_findnext(cdb *,ubyte *,ulong);
extern int cdb_find(cdb *,ubyte *,ulong);

extern int cdb_firstkey(cdb *c,uint *kpos);
extern int cdb_nextkey(cdb *c,uint *kpos);

extern int cdb_successor(cdb *c,ubyte *,ulong);

//#define cdb_datapos(c) ((c)->dpos)
//#define cdb_datalen(c) ((c)->dlen)
//#define cdb_keypos(c) ((c)->kpos)
//#define cdb_keylen(c) ((c)->dpos-(c)->kpos)

enum { CDB_HPLIST = 1000 };

struct cdb_hp { uint h; uint p; } ;

struct cdb_hplist {
  cdb_hp hp[CDB_HPLIST];
  cdb_hplist *next;
  int num;
} ;

struct cdb_make {
  char bspace[8192];
  char buf_final[2048];
  uint count[256];
  uint start[256];
  cdb_hplist *head;
  cdb_hp *split; /* buf_includes space for hash */
  cdb_hp *hash;
  uint numentries;
  buffer b;
  uint pos;
  long fd;
} ;

extern int cdb_make_start(cdb_make *,long);
extern int cdb_make_addbegin(cdb_make *,ulong,ulong);
extern int cdb_make_addend(cdb_make *,ulong,ulong,uint);
extern int cdb_make_add(cdb_make *,ubyte *,ulong,ubyte *,ulong);
extern int cdb_make_finish(cdb_make *);
+/

/*
enum {
	DNS_C_IN = "\0\1",
	DNS_C_ANY = "\0\377",
	DNS_T_A = "\0\1",
	DNS_T_NS = "\0\2",
	DNS_T_CNAME = "\0\5",
	DNS_T_SOA = "\0\6",
	DNS_T_PTR = "\0\14",
	DNS_T_HINFO = "\0\15",
	DNS_T_MX = "\0\17",
	DNS_T_TXT = "\0\20",
	DNS_T_RP = "\0\21",
	DNS_T_SIG = "\0\30",
	DNS_T_KEY = "\0\31",
	DNS_T_AAAA = "\0\34",
	DNS_T_AXFR = "\0\374",
	DNS_T_ANY = "\0\377",
}
*/

struct dns_transmit {
  char *query; /* 0, or dynamically allocated */
  uint querylen;
  char *packet; /* 0, or dynamically allocated */
  uint packetlen;
  int s1; /* 0, or 1 + an open file descriptor */
  int tcpstate;
  uint udploop;
  uint curserver;
  //taia deadline;
  uint pos;
  char *servers;
  char localip[16];
  uint scope_id;
  char qtype[2];
} ;

void dns_random_init(char *);
uint dns_random(uint);

void dns_sortip(char *,uint);
void dns_sortip6(char *,uint);

void dns_domain_free(char **);
int dns_domain_copy(char **,char *);
uint dns_domain_length(char *);
int dns_domain_equal(char *,char *);
int dns_domain_suffix(char *,char *);
uint dns_domain_suffixpos(char *,char *);
int dns_domain_fromdot(char **,char *,uint);
int dns_domain_todot_cat(stralloc *,char *);

uint dns_packet_copy(char *,uint,uint,char *,uint);
uint dns_packet_getname(char *,uint,uint,char **);
uint dns_packet_skipname(char *,uint,uint);

int dns_transmit_start(dns_transmit *,char *,int,char *,char *,char *);
void dns_transmit_free(dns_transmit *);
//void dns_transmit_io(dns_transmit *,iopause_fd *,taia *);
//int dns_transmit_get(dns_transmit *,iopause_fd *,taia *);

int dns_resolvconfip(char *);
int dns_resolve(char *,char *);
extern dns_transmit dns_resolve_tx;

int dns_ip4_packet(stralloc *,char *,uint);
int dns_ip4(stralloc *,stralloc *);
int dns_ip6_packet(stralloc *,char *,uint);
int dns_ip6(stralloc *,stralloc *);
int dns_name_packet(stralloc *,char *,uint);
void dns_name4_domain(char *,char *);
enum { DNS_NAME4_DOMAIN = 31 };
int dns_name4(stralloc *,char *);
int dns_txt_packet(stralloc *,char *,uint);
int dns_txt(stralloc *,stralloc *);
int dns_mx_packet(stralloc *,char *,uint);
int dns_mx(stralloc *,stralloc *);

int dns_resolvconfrewrite(stralloc *);
int dns_ip4_qualify_rules(stralloc *,stralloc *,stralloc *,stralloc *);
int dns_ip4_qualify(stralloc *,stralloc *,stralloc *);
int dns_ip6_qualify_rules(stralloc *,stralloc *,stralloc *,stralloc *);
int dns_ip6_qualify(stralloc *,stralloc *,stralloc *);

void dns_name6_domain(char *,char *);
enum { DNS_NAME6_DOMAIN = (4*16+11) };
int dns_name6(stralloc *,char *);


/* These use file descriptor 2, not buffer_2!
 * Call buffer_flush(buffer_2) before calling these! */

extern char* argv0;

void errmsg_iam(char* who);	/* set argv0 */

/* terminate with NULL. */
/* newline is appended automatically. */
void errmsg_warn(char* message, ...);
void errmsg_warnsys(char* message, ...);

void errmsg_info(char* message, ...);
void errmsg_infosys(char* message, ...);

//#define carp(...) errmsg_warn(__VA_ARGS__,(char*)0)
//#define carpsys(...) errmsg_warnsys(__VA_ARGS__,(char*)0)
//#define die(n,...) do { errmsg_warn(__VA_ARGS__,(char*)0); exit(n); } while (0)
//#define diesys(n,...) do { errmsg_warnsys(__VA_ARGS__,(char*)0); exit(n); } while (0)
//#define msg(...) errmsg_info(__VA_ARGS__,(char*)0);
//#define msgsys(...) errmsg_infosys(__VA_ARGS__,(char*)0);


void errmsg_puts(int fd,char* s);
void errmsg_flush(int fd);
void errmsg_start(int fd);

//void errmsg_write(int fd,char* err,char* message,va_list list);

enum {
	FMT_LONG = 41, /* enough space to hold -2^127 in decimal, plus \0 */
	FMT_ULONG = 40, /* enough space to hold 2^128 - 1 in decimal, plus \0 */
	FMT_8LONG = 44, /* enough space to hold 2^128 - 1 in octal, plus \0 */
	FMT_XLONG = 33, /* enough space to hold 2^128 - 1 in hexadecimal, plus \0 */
}
//FMT_LEN ((char *) 0) /* convenient abbreviation */
/+
/* The formatting routines do not append \0!
 * Use them like this: buf[fmt_ulong(buf,number)]=0; */

/* convert signed src integer -23 to ASCII '-','2','3', return length.
 * If dest is not NULL, write result to dest */
size_t fmt_long(char *dest, int src);

/* convert unsigned src integer 23 to ASCII '2','3', return length.
 * If dest is not NULL, write result to dest */
size_t fmt_ulong(char *dest,uint src);

/* convert unsigned src integer 0x23 to ASCII '2','3', return length.
 * If dest is not NULL, write result to dest */
size_t fmt_xlong(char *dest,uint src);

/* convert unsigned src integer 023 to ASCII '2','3', return length.
 * If dest is not NULL, write result to dest */
size_t fmt_8long(char *dest,uint src);

size_t fmt_longlong(char *dest,long src);
size_t fmt_ulonglong(char *dest,ulong src);
size_t fmt_xlonglong(char *dest,ulong src);

alias fmt_ulong fmt_uint;
alias fmt_long fmt_int;
alias fmt_xlong fmt_xint;
alias fmt_8long fmt_8int;

/* Like fmt_ulong, but prepend '0' while length is smaller than padto.
 * Does not truncate! */
size_t fmt_ulong0(char *,uint src,size_t padto);

alias fmt_ulong0 fmt_uint0;

/* convert src double 1.7 to ASCII '1','.','7', return length.
 * If dest is not NULL, write result to dest */
size_t fmt_double(char *dest, double d,int max,int prec);

/* if src is negative, write '-' and return 1.
 * if src is positive, write '+' and return 1.
 * otherwise return 0 */
size_t fmt_plusminus(char *dest,int src);

/* if src is negative, write '-' and return 1.
 * otherwise return 0. */
size_t fmt_minus(char *dest,int src);

/* copy str to dest until \0 byte, return number of copied bytes. */
size_t fmt_str(char *dest,char *src);

/* copy str to dest until \0 byte or limit bytes copied.
 * return number of copied bytes. */
size_t fmt_strn(char *dest,char *src,size_t limit);

/* "foo" -> "  foo"
 * write padlen-srclen spaces, if that is >= 0.  Then copy srclen
 * characters from src.  Truncate only if total length is larger than
 * maxlen.  Return number of characters written. */
size_t fmt_pad(char* dest,char* src,size_t srclen,size_t padlen,size_t maxlen);

/* "foo" -> "foo  "
 * append padlen-srclen spaces after dest, if that is >= 0.  Truncate
 * only if total length is larger than maxlen.  Return number of
 * characters written. */
size_t fmt_fill(char* dest,size_t srclen,size_t padlen,size_t maxlen);

/* 1 -> "1", 4900 -> "4.9k", 2300000 -> "2.3M" */
size_t fmt_human(char* dest,ulong l);

/* 1 -> "1", 4900 -> "4.8k", 2300000 -> "2.2M" */
size_t fmt_humank(char* dest,ulong l);

/* "Sun, 06 Nov 1994 08:49:37 GMT" */
size_t fmt_httpdate(char* dest,time_t t);

/* buf_internal functions, may be independently useful */
char fmt_tohex(char c);
+/

/* like open(s,O_RDONLY) */
/* return 1 if ok, 0 on error */
int io_readfile(long* d,char* s);
/* like open(s,O_WRONLY|O_CREAT|O_TRUNC,0600) */
/* return 1 if ok, 0 on error */
int io_createfile(long* d,char* s);
/* like open(s,O_RDWR) */
/* return 1 if ok, 0 on error */
int io_readwritefile(long* d,char* s);
/* like open(s,O_WRONLY|O_APPEND|O_CREAT,0600) */
/* return 1 if ok, 0 on error */
int io_appendfile(long* d,char* s);
/* like pipe(d) */
/* return 1 if ok, 0 on error */
int io_pipe(long* d);
/* like socketpair() */
/* return 1 if ok, 0 on error */
int io_socketpair(long* d);

/* non-blocking read(), -1 for EAGAIN and -3+errno for other errors */
long io_tryread(long d,char* buf,ulong len);

/* blocking read(), with -3 instead of -1 for errors */
long io_waitread(long d,char* buf,ulong len);

/* non-blocking write(), -1 for EAGAIN and -3+errno for other errors */
long io_trywrite(long d,char* buf,ulong len);

/* blocking write(), with -3 instead of -1 for errors */
long io_waitwrite(long d,char* buf,ulong len);

/* modify timeout attribute of file descriptor */
//void io_timeout(long d,tai6464 t);

/* like io_tryread but will return -2,errno=ETIMEDOUT if d has a timeout
 * associated and it is passed without input being there */
long io_tryreadtimeout(long d,char* buf,ulong len);

/* like io_trywrite but will return -2,errno=ETIMEDOUT if d has a timeout
 * associated and it is passed without being able to write */
long io_trywritetimeout(long d,char* buf,ulong len);

void io_wantread(long d);
void io_wantwrite(long d);
void io_dontwantread(long d);
void io_dontwantwrite(long d);

void io_wait();
//void io_waituntil(tai6464 t);
long io_waituntil2(long milliseconds);
void io_check();

/* signal that read/accept/whatever returned EAGAIN */
/* needed for SIGIO */
void io_eagain(long d);

/* return next descriptor from io_wait that can be read from */
long io_canread();
/* return next descriptor from io_wait that can be written to */
long io_canwrite();

/* return next descriptor with expired timeout */
long io_timeouted();

/* put d on internal data structure, return 1 on success, 0 on error */
int io_fd(long d);

void io_setcookie(long d,void* cookie);
void* io_getcookie(long d);

/* put descriptor in non-blocking mode */
void io_nonblock(long d);
/* put descriptor in blocking mode */
void io_block(long d);
/* put descriptor in close-on-exec mode */
void io_closeonexec(long d);

void io_close(long d);

/* Free the internal data structures from libio.
 * This only makes sense if you run your program in a malloc checker and
 * these produce false alarms.  Your OS will free these automatically on
 * process termination. */
void io_finishandshutdown();

/* send n bytes from file fd starting at offset off to socket s */
/* return number of bytes written */
long io_sendfile(long s,long fd,ulong off,ulong n);

/* Pass fd over sock (must be a unix domain socket) to other process.
 * Return 0 if ok, -1 on error, setting errno. */
int io_passfd(long sock,long fd);

/* Receive fd over sock (must be a unix domain socket) from other
 * process.  Return sock if ok, -1 on error, setting errno. */
long io_receivefd(long sock);

typedef long (*io_write_callback)(long s,void* buf,ulong n);

/* used internally, but hey, who knows */
long io_mmapwritefile(long buf_out,long buf_in,ulong off,ulong bytes,io_write_callback writecb);


struct io_entry {
/*
  tai6464 timeout;
  uint wantread:1;
  uint wantwrite:1;
  uint canread:1;
  uint canwrite:1;
  uint nonblock:1;
  uint inuse:1;
#ifdef __MINGW32__
  uint readqueued:2;
  uint writequeued:2;
  uint acceptqueued:2;
  uint connectqueued:2;
  uint sendfilequeued:2;
  uint listened:1;
#endif
  long next_read;
  long next_write;
  void* cookie;
  void* mmapped;
  long maplen;
  ulong mapofs;
#ifdef __MINGW32__
  OVERLAPPED or,ow,os;	// overlapped for read+accept, write+connect, sendfile
  HANDLE  mh;
  char inbuf[8192];
  int bytes_read,bytes_written;
  DWORD errorcode;
  SOCKET next_accept;
#endif
*/
};

//extern array io_fds;
//extern ulong io_wanted_fds;
//extern array io_pollfds;

extern long first_readable;
extern long first_writeable;

/*
extern enum __io_waitmode {
  UNDECIDED,
  POLL
#ifdef HAVE_KQUEUE
  ,KQUEUE
#endif
#ifdef HAVE_EPOLL
  ,EPOLL
#endif
#ifdef HAVE_SIGIO
  ,_SIGIO
#endif
#ifdef HAVE_DEVPOLL
  ,DEVPOLL
#endif
#ifdef __MINGW32__
  ,COMPLETIONPORT
#endif
} io_waitmode;
*/

// only linux!
//#if defined(HAVE_KQUEUE) || defined(HAVE_EPOLL) || defined(HAVE_DEVPOLL)
extern int io_master;
//#endif

void io_sigpipe();

/+
/* These functions can be used to create a queue of small (or large)
 * buffers and parts of files to be sent out over a socket.  It is meant
 * for writing HTTP servers or the like. */

/* This API works with non-blocking I/O.  Simply call iob_send until it
 * returns 0 (or -1).  The implementation uses sendfile for zero-copy
 * TCP and it will employ writev (or the built-in sendfile writev on
 * BSD) to make sure the output fragments are coalesced into as few TCP
 * frames as possible.  On Linux it will also use the TCP_CORK socket
 * option. */

struct io_batch {
  array b;
  ulong bytesleft;
  long next,bufs,files;
};

io_batch* iob_new(int hint_entries);
int iob_addbuf(io_batch* b,void* buf,ulong n);
int iob_addbuf_free(io_batch* b,void* buf,ulong n);
int iob_adds(io_batch* b,char* s);
int iob_adds_free(io_batch* b,char* s);
int iob_addfile(io_batch* b,long fd,ulong off,ulong n);
int iob_addfile_close(io_batch* b,long fd,ulong off,ulong n);
long iob_send(long s,io_batch* b);
long iob_write(long s,io_batch* b,io_write_callback cb);
void iob_reset(io_batch* b);
void iob_free(io_batch* b);
void iob_prefetch(io_batch* b,ulong bytes);
ulong iob_bytesleft(io_batch* b);


struct iob_entry {
  enum { FROMBUF, FROMBUF_FREE, FROMFILE, FROMFILE_CLOSE };
  long fd;
  char* buf;
  ulong offset,n;
};

int iob_addbuf_internal(io_batch* b,void* buf,ulong n,int free);


uint scan_ip4(char *src,char *ip);
uint fmt_ip4(char *dest,char *ip);

extern char ip4loopback[4]; /* = {127,0,0,1};*/

uint scan_ip6(char* src,char* ip);
uint fmt_ip6(char* dest,char* ip);
uint fmt_ip6c(char* dest,char* ip);

uint scan_ip6if(char* src,char* ip,uint* scope_id);
uint fmt_ip6if(char* dest,char* ip,uint scope_id);
uint fmt_ip6ifc(char* dest,char* ip,uint scope_id);

uint scan_ip6_flat(char *src,char *);
uint fmt_ip6_flat(char *dest,char *);

/*
 ip6 address syntax: (h = hex digit), no leading '0' required
   1. hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh:hhhh
   2. any number of 0000 may be abbreviated as "::", but only once
 flat ip6 address syntax:
   hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh
 */

 enum {
	 IP4_FMT = 20,
	 FMT_IP4 = 20,
	 IP6_FMT = 40,
	 FMT_IP6 = 40,
 }

extern char V4mappedprefix[12]; /*={0,0,0,0,0,0,0,0,0,0,0xff,0xff}; */
extern char V6loopback[16]; /*={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1}; */
extern char V6any[16]; /*={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}; */

//#define ip6_isv4mapped(ip) (byte_equal(ip,12,V4mappedprefix))
+/
/* open file for reading, mmap whole file, close file, write length of
 * map in filesize and return pointer to map. */
char* mmap_read(char *filename,size_t* filesize);

/* open file for writing, mmap whole file privately (copy on write),
 * close file, write length of map in filesize and return pointer to
 * map. */
char* mmap_private(char *filename,size_t* filesize);

/* open file for writing, mmap whole file shared, close file, write
 * length of map in filesize and return pointer to map. */
char* mmap_shared(char *filename,size_t* filesize);

/* unmap a mapped region */
int mmap_unmap(char* mapped,size_t maplen);

/+
int ndelay_on(int);
int ndelay_off(int);


/* open filename for reading and return the file handle or -1 on error */
int open_read(char* filename);

/* create filename for exclusive write only use (mode 0600) and return
 * the file handle or -1 on error */
int open_excl(char* filename);

/* open filename for appending  write only use (mode 0600)
 * and return the file handle or -1 on error.
 * All write operation will append after the last byte, regardless of
 * seeking or other processes also appending to the file.  The file will
 * be created if it does not exist. */
int open_append(char* filename);

/* open filename for writing (mode 0644).  Create the file if it does
 * not exist, truncate it to zero length otherwise.  Return the file
 * handle or -1 on error. */
int open_trunc(char* filename);

/* open filename for writing.  Create the file if it does not exist.
 * Return the file handle or -1 on error. */
int open_write(char* filename);

/* open filename for reading and writing.  Create file if not there.
 * Return file handle or -1 on error. */
int open_rw(char* filename);


int openreadclose(char *filename,stralloc *buf,size_t initiallength);

/* return 0 for range error / overflow, 1 for ok */

/*#if defined(__GNUC__) && defined(__OPTIMIZE__)
#define __static extern
#else
#define __static static
#endif*/

/* does ptr point to one of buf[0], buf[1], ... buf[len-1]? */
int range_ptrinbuf(void* buf,size_t len,void* ptr) {
  register char* c=(char*)buf;	/* no pointer arithmetic on void* */
  return (c &&		/* is buf non-NULL? */
	  ((uintptr_t)c)+len>(uintptr_t)c &&	/* gcc 4.1 miscompiles without (uintptr_t) */
			/* catch integer overflows and fail if buffer is 0 bytes long */
			/* because then ptr can't point _in_ the buffer */
	  (uintptr_t)((char*)ptr-c)<len);	/* this one is a little tricky.
     "ptr-c" checks the offset of ptr in the buffer is inside the buffer size.
     Now, ptr-c can underflow; say it is -1.  When we cast it to uintptr_t, it becomes
     a very large number. */
}

/* Is this a plausible buffer?
 * Check whether buf is NULL, and whether buf+len overflows.
 * Does NOT check whether buf has a non-zero length! */
int range_validbuf(void* buf,size_t len) {
  return (buf && (uintptr_t)buf+len>=(uintptr_t)buf);
}

/* is buf2[0..len2-1] inside buf1[0..len-1]? */
int range_bufinbuf(void* buf1,size_t len1,void* buf2,size_t len2) {
  return range_validbuf(buf1,len1) &&
         range_validbuf(buf2,len2) &&
	 buf1<=buf2 &&
	 (ptrdiff_t)buf1+len1>=(ptrdiff_t)buf2+len2;
}

/* does an array of "elements" members of size "membersize" starting at
 * "arraystart" lie inside buf1[0..len-1]? */
int range_arrayinbuf(void* buf,size_t len,
		     void* arraystart,size_t elements,size_t membersize);

/* does an ASCIIZ string starting at "ptr" lie in buf[0..len-1]? */
int range_strinbuf(void* buf,size_t len,void* stringstart);

/* does an UTF-16 string starting at "ptr" lie in buf[0..len-1]? */
int range_str2inbuf(void* buf,size_t len,void* stringstart);

/* does an UTF-32 string starting at "ptr" lie in buf[0..len-1]? */
int range_str4inbuf(void* buf,size_t len,void* stringstart);


int readclose_append(int fd,stralloc *buf,size_t initlen);
int readclose(int fd,stralloc *buf,size_t initlen);


/* return 0 for overflow, 1 for ok */
int umult16(ushort a,ushort b,ushort* c);
int imult16( short a, short b, short* c);

int umult32(uint a,uint b,uint* c);
int imult32( int a, int b, int* c);

int umult64(ulong a,ulong b,ulong* c);
int imult64( long a, long b, long* c);


/* buf_interpret src as ASCII decimal number, write number to dest and
 * return the number of bytes that were parsed */
size_t scan_ulong(char *src,uint *dest);

/* buf_interpret src as ASCII hexadecimal number, write number to dest and
 * return the number of bytes that were parsed */
size_t scan_xlong(char *src,uint *dest);

/* buf_interpret src as ASCII octal number, write number to dest and
 * return the number of bytes that were parsed */
size_t scan_8long(char *src,uint *dest);

/* buf_interpret src as signed ASCII decimal number, write number to dest
 * and return the number of bytes that were parsed */
size_t scan_long(char *src,long *dest);

size_t scan_longlong(char *src,long *dest);
size_t scan_ulonglong(char *src,ulong *dest);
size_t scan_xlonglong(char *src,ulong *dest);
size_t scan_8longlong(char *src,ulong *dest);

size_t scan_uint(char *src,uint *dest);
size_t scan_xint(char *src,uint *dest);
size_t scan_8int(char *src,uint *dest);
size_t scan_int(char *src,int *dest);

size_t scan_ushort(char *src,ushort *dest);
size_t scan_xshort(char *src,ushort *dest);
size_t scan_8short(char *src,ushort *dest);
size_t scan_short(char *src,short *dest);

/* buf_interpret src as double precision floating point number,
 * write number to dest and return the number of bytes that were parsed */
size_t scan_double(char *buf_in, double *dest);

/* if *src=='-', set *dest to -1 and return 1.
 * if *src=='+', set *dest to 1 and return 1.
 * otherwise set *dest to 1 return 0. */
size_t scan_plusminus(char *src,int *dest);

/* return the highest integer n<=limit so that isspace(in[i]) for all 0<=i<=n */
size_t scan_whitenskip(char *buf_in,size_t limit);

/* return the highest integer n<=limit so that !isspace(in[i]) for all 0<=i<=n */
size_t scan_nonwhitenskip(char *buf_in,size_t limit);

/* return the highest integer n<=limit so that in[i] is element of
 * charset (ASCIIZ string) for all 0<=i<=n */
size_t scan_charsetnskip(char *buf_in,char *charset,size_t limit);

/* return the highest integer n<=limit so that in[i] is not element of
 * charset (ASCIIZ string) for all 0<=i<=n */
size_t scan_noncharsetnskip(char *buf_in,char *charset,size_t limit);

/* try to parse ASCII GMT date; does not understand time zones. */
/* example dates:
 *   "Sun, 06 Nov 1994 08:49:37 GMT"
 *   "Sunday, 06-Nov-94 08:49:37 GMT"
 *   "Sun Nov  6 08:49:37 1994"
 */
size_t scan_httpdate(char *buf_in,time_t *t);

/* a few internal function that might be useful independently */
/* convert from hex ASCII, return 0 to 15 for success or -1 for failure */
int scan_fromhex(ubyte c);

+/
int socket_tcp4();
int socket_tcp4b();
int socket_udp4();
int socket_tcp6();
int socket_tcp6b();
int socket_udp6();

alias socket_tcp4 socket_tcp;
alias socket_udp4 socket_udp;

int socket_connect4(int s,char* ip,ushort port);
int socket_connect6(int s,char* ip,ushort port,uint scope_id);
int socket_connected(int s);
int socket_bind4(int s,char* ip,ushort port);
int socket_bind4_reuse(int s,ubyte* ip,ushort port);
int socket_bind6(int s,char* ip,ushort port,uint scope_id);
int socket_bind6_reuse(int s,char* ip,ushort port,uint scope_id);
int socket_listen(int s,uint backlog);
int socket_accept4(int s,char* ip,ushort* port);
int socket_accept6(int s,char* ip,ushort* port,uint* scope_id);
ssize_t socket_recv4(int s,char* buf,size_t len,char* ip,ushort* port);
ssize_t socket_recv6(int s,char* buf,size_t len,char* ip,ushort* port,uint* scope_id);
ssize_t socket_send4(int s,char* buf,size_t len,char* ip,ushort port);
ssize_t socket_send6(int s,char* buf,size_t len,char* ip,ushort port,uint scope_id);
int socket_local4(int s,char* ip,ushort* port);
int socket_local6(int s,char* ip,ushort* port,uint* scope_id);
int socket_remote4(int s,char* ip,ushort* port);
int socket_remote6(int s,char* ip,ushort* port,uint* scope_id);

/* enable sending udp packets to the broadcast address */
int socket_broadcast(int s);
/* join a multicast group on the given interface */
int socket_mcjoin4(int s,char* groupip,char* _interface);
int socket_mcjoin6(int s,char* groupip,int _interface);
/* leave a multicast group on the given interface */
int socket_mcleave4(int s,char* groupip);
int socket_mcleave6(int s,char* groupip);
/* set multicast TTL/hop count for outgoing packets */
int socket_mcttl4(int s,char hops);
int socket_mchopcount6(int s,char hops);
/* enable multicast loopback */
int socket_mcloop4(int s,char hops);
int socket_mcloop6(int s,char hops);

void socket_tryreservein(int s,int size);

char* socket_getifname(uint _interface);
uint socket_getifidx(char* ifname);

extern int noipv6;
/+
/* str_copy copies leading bytes from in to buf_out until \0.
 * return number of copied bytes. */
size_t str_copy(char *buf_out,char *buf_in);

/* str_diff returns negative, 0, or positive, depending on whether the
 * string a[0], a[1], ..., a[n]=='\0' is lexicographically smaller than,
 * equal to, or greater than the string b[0], b[1], ..., b[m-1]=='\0'.
 * If the strings are different, str_diff does not read bytes past the
 * first difference. */
int str_diff(char *a,char *b);

/* str_diffn returns negative, 0, or positive, depending on whether the
 * string a[0], a[1], ..., a[n]=='\0' is lexicographically smaller than,
 * equal to, or greater than the string b[0], b[1], ..., b[m-1]=='\0'.
 * If the strings are different, str_diffn does not read bytes past the
 * first difference. The strings will be considered equal if the first
 * limit characters match. */
int str_diffn(char *a,char *b,size_t limit);


/* str_chr returns the index of the first occurance of needle or \0 in haystack */
size_t str_chr(char *haystack,char needle);

/* str_rchr returns the index of the last occurance of needle or \0 in haystack */
size_t str_rchr(char *haystack,char needle);

/* str_start returns 1 if the b is a prefix of a, 0 otherwise */
int str_start(char *a,char *b);

+/

/* stralloc is the internal data structure all functions are working on.
 * s is the string.
 * len is the used length of the string.
 * a is the allocated length of the string.
 */
struct stralloc {
  char* s;
  size_t len;
  size_t a;
};
/* stralloc_init will initialize a stralloc.
 * Previously allocated memory will not be freed; use stralloc_free for
 * that.  To assign an empty string, use stralloc_copys(sa,""). */
void stralloc_init(stralloc* sa);

/* stralloc_ready makes sure that sa has enough space allocated to hold
 * len bytes: If sa is not allocated, stralloc_ready allocates at least
 * len bytes of space, and returns 1. If sa is already allocated, but
 * not enough to hold len bytes, stralloc_ready allocates at least len
 * bytes of space, copies the old string into the new space, frees the
 * old space, and returns 1. Note that this changes sa.s.  If the
 * allocation fails, stralloc_ready leaves sa alone and returns 0. */
int stralloc_ready(stralloc* sa,size_t len);

/* stralloc_readyplus is like stralloc_ready except that, if sa is
 * already allocated, stralloc_readyplus adds the current length of sa
 * to len. */
int stralloc_readyplus(stralloc* sa,size_t len);

/* stralloc_copyb copies the string buf[0], buf[1], ..., buf[len-1] into
 * sa, allocating space if necessary, and returns 1. If it runs out of
 * memory, stralloc_copyb leaves sa alone and returns 0. */
int stralloc_copyb(stralloc* sa,char* buf,size_t len);

/* stralloc_copys copies a \0-terminated string from buf into sa,
 * without the \0. It is the same as
 * stralloc_copyb(&sa,buf,str_len(buf)). */
int stralloc_copys(stralloc* sa,char* buf);

/* stralloc_copy copies the string stored in sa2 into sa. It is the same
 * as stralloc_copyb(&sa,sa2.s,sa2.len). sa2 must already be allocated. */
int stralloc_copy(stralloc* sa,stralloc* sa2);

/* stralloc_catb adds the string buf[0], buf[1], ... buf[len-1] to the
 * end of the string stored in sa, allocating space if necessary, and
 * returns 1. If sa is unallocated, stralloc_catb is the same as
 * stralloc_copyb. If it runs out of memory, stralloc_catb leaves sa
 * alone and returns 0. */
int stralloc_catb(stralloc* sa,char* buf_in,size_t len);

/* stralloc_cats is analogous to stralloc_copys */
int stralloc_cats(stralloc* sa,char* buf_in);

void stralloc_zero(stralloc* sa);

/* like stralloc_cats but can cat more than one string at once */
int stralloc_catm_internal(stralloc* sa,...);

//#define stralloc_catm(sa,...) stralloc_catm_internal(sa,__VA_ARGS__,(char*)0)
//#define stralloc_copym(sa,...) (stralloc_zero(sa) && stralloc_catm_internal(sa,__VA_ARGS__,(char*)0))

/* stralloc_cat is analogous to stralloc_copy */
int stralloc_cat(stralloc* sa,stralloc* buf_in);

/* stralloc_append adds one byte in[0] to the end of the string stored
 * buf_in sa. It is the same as stralloc_catb(&sa,in,1). */
int stralloc_append(stralloc* sa,char* buf_in); /* beware: this takes a pointer to 1 char */

/* stralloc_starts returns 1 if the \0-terminated string in "in", without
 * the terminating \0, is a prefix of the string stored in sa. Otherwise
 * it returns 0. sa must already be allocated. */
int stralloc_starts(stralloc* sa,char* buf_in);

/* stralloc_diff returns negative, 0, or positive, depending on whether
 * a is lexicographically smaller than, equal to, or greater than the
 * string b. */
int stralloc_diff(stralloc* a,stralloc* b);

/* stralloc_diffs returns negative, 0, or positive, depending on whether
 * a is lexicographically smaller than, equal to, or greater than the
 * string b[0], b[1], ..., b[n]=='\0'. */
int stralloc_diffs(stralloc* a,char* b);

/+
//#define stralloc_equal(a,b) (!stralloc_diff((a),(b)))
//#define stralloc_equals(a,b) (!stralloc_diffs((a),(b)))

/* stralloc_0 appends \0 */
//#define stralloc_0(sa) stralloc_append(sa,"")

/* stralloc_catulong0 appends a '0' padded ASCII representation of in */
int stralloc_catulong0(stralloc* sa,ulong buf_in,size_t n);

/* stralloc_catlong0 appends a '0' padded ASCII representation of in */
int stralloc_catlong0(stralloc* sa,long buf_in,size_t n);

/* stralloc_free frees the storage associated with sa */
void stralloc_free(stralloc* sa);

//#define stralloc_catlong(sa,l) (stralloc_catlong0((sa),(l),0))
//#define stralloc_catuint0(sa,i,n) (stralloc_catulong0((sa),(i),(n)))
//#define stralloc_catint0(sa,i,n) (stralloc_catlong0((sa),(i),(n)))
//#define stralloc_catint(sa,i) (stralloc_catlong0((sa),(i),0))

/* remove last char.  Return removed byte as ubyte (or -1 if stralloc was empty). */
int stralloc_chop(stralloc* sa);

/* remove trailing "\r\n", "\n" or "\r".  Return number of removed chars (0,1 or 2) */
int stralloc_chomp(stralloc* sa);

/* write stralloc to buffer */
int buffer_putsa(buffer* b,stralloc* sa);
/* write stralloc to buffer and flush */
int buffer_putsaflush(buffer* b,stralloc* sa);

/* these "read token" functions return 0 if the token was complete or
 * EOF was hit or -1 on error.  In contrast to the non-stralloc token
 * functions, the separator is also put in the stralloc; use
 * stralloc_chop or stralloc_chomp to get rid of it. */

/* WARNING!  These token reading functions will not clear the stralloc!
 * They _append_ the token to the contents of the stralloc.  The idea is
 * that this way these functions can be used on non-blocking sockets;
 * when you get signalled EAGAIN, just call the functions again when new
 * data is available. */

/* read token from buffer to stralloc */
int buffer_get_token_sa(buffer* b,stralloc* sa,char* charset,size_t setlen);
/* read line from buffer to stralloc */
int buffer_getline_sa(buffer* b,stralloc* sa);

/* same as buffer_get_token_sa but empty sa first */
int buffer_get_new_token_sa(buffer* b,stralloc* sa,char* charset,size_t setlen);
/* same as buffer_getline_sa but empty sa first */
int buffer_getnewline_sa(buffer* b,stralloc* sa);

typedef int (*sa_predicate)(stralloc* sa);

/* like buffer_get_token_sa but the token ends when your predicate says so */
int buffer_get_token_sa_pred(buffer* b,stralloc* sa,sa_predicate p);
/* same, but clear sa first */
int buffer_get_new_token_sa_pred(buffer* b,stralloc* sa,sa_predicate p);


/* make a buffer from a stralloc.
 * Do not change the stralloc after this! */
void buffer_fromsa(buffer* b,stralloc* sa);

/* A struct tai value is an integer between 0 inclusive and 2^64
 * exclusive. The format of struct tai is designed to speed up common
 * operations; applications should not look inside struct tai.
 *
 * A struct tai variable is commonly used to store a TAI64 label. Each
 * TAI64 label refers to one second of real time. TAI64 labels span a
 * range of hundreds of billions of years.
 *
 * A struct tai variable may also be used to store the numerical
 * difference between two TAI64 labels.
 * See http://cr.yp.to/libtai/tai64.html */

struct tai {
  ulong x;
};

alias tai tai64;


//#define tai_unix(t,u) (() ((t)->x = 4611686018427387914ULL + (ulong) (u)))

/* tai_now puts the current time into t. More precisely: tai_now puts
 * buf_into t its best guess as to the TAI64 label for the 1-second interval
 * that contains the current time.
 *
 * This implementation of tai_now assumes that the time_t returned from
 * the time function represents the number of TAI seconds since
 * 1970-01-01 00:00:10 TAI. This matches the convention used by the
 * Olson tz library in ``right'' mode. */
void tai_now(tai *);

/* tai_approx returns a double-precision approximation to t. The result
 * of tai_approx is always nonnegative. */
//#define tai_approx(t) ((double) ((t)->x))

/* tai_add adds a to b modulo 2^64 and puts the result into t. The
 * buf_inputs and output may overlap. */
void tai_add(tai *,tai *,tai *);
/* tai_sub subtracts b from a modulo 2^64 and puts the result into t.
 * The inputs and output may overlap. */
void tai_sub(tai *,tai *,tai *);
/* tai_less returns 1 if a is less than b, 0 otherwise. */
//#define tai_less(t,u) ((t)->x < (u)->x)

enum { TAI_PACK = 8 };
/* tai_pack converts a TAI64 label from internal format in t to external
 * TAI64 format in buf. */
void tai_pack(char *,tai *);
/* tai_unpack converts a TAI64 label from external TAI64 format in buf
 * to internal format in t. */
void tai_unpack(char *,tai *);

void tai_uint(tai *,uint);


/* A struct taia value is a number between 0 inclusive and 2^64
 * exclusive. The number is a multiple of 10^-18. The format of struct
 * taia is designed to speed up common operations; applications should
 * not look inside struct taia. */
struct taia {
  tai sec;
  uint nano; /* 0...999999999 */
  uint atto; /* 0...999999999 */
};

alias taia tai6464;

/* extract seconds */
void taia_tai(tai6464 *source,tai64 *dest);

/* get current time */
void taia_now(taia *);

/* return double-precision approximation; always nonnegative */
double taia_approx(tai6464 *);
/* return double-precision approximation of the fraction part;
 * always nonnegative */
double taia_frac(tai6464 *);

/* add source1 to source2 modulo 2^64 and put the result in dest.
 * The inputs and output may overlap */
void taia_add(tai6464 *dest,tai6464 *source1,tai6464 *source2);
/* add secs seconds to source modulo 2^64 and put the result in dest. */
void taia_addsec(tai6464 *dest,tai6464 *source,long secs);
/* subtract source2 from source1 modulo 2^64 and put the result in dest.
 * The inputs and output may overlap */
void taia_sub(tai6464 *,tai6464 *,tai6464 *);
/* divide source by 2, rouding down to a multiple of 10^-18, and put the
 * result into dest.  The input and output may overlap */
void taia_half(tai6464 *dest,tai6464 *source);
/* return 1 if a is less than b, 0 otherwise */
int taia_less(tai6464 *a,tai6464 *b);

enum { TAIA_PACK = 16 };
/* char buf[TAIA_PACK] can be used to store a TAI64NA label in external
 * representation, which can then be used to transmit the binary
 * representation over a network or store it on disk in a byte order
 * buf_independent fashion */

/* convert a TAI64NA label from internal format in src to external
 * TAI64NA format in buf. */
void taia_pack(char *buf,tai6464 *src);
/* convert a TAI64NA label from external TAI64NA format in buf to
 * buf_internal format in dest. */
void taia_unpack(char *buf,tai6464 *dest);

enum { TAIA_FMTFRAC = 19 };
/* print the 18-digit fraction part of t in decimal, without a decimal
 * point but with leading zeros, into the character buffer s, without a
 * terminating \0. It returns 18, the number of characters written. s
 * may be zero; then taia_fmtfrac returns 18 without printing anything.
 * */
uint taia_fmtfrac(char *s,tai6464 *t);

/* buf_initialize t to secs seconds. */
void taia_uint(tai6464 *t,uint secs);

/* These take len bytes from src and write them in encoded form to
 * dest (if dest != NULL), returning the number of bytes written. */

/* needs len/3*4 bytes */
size_t fmt_uuencoded(char* dest,char* src,size_t len);
/* needs len/3*4 bytes */
size_t fmt_base64(char* dest,char* src,size_t len);
/* worst case: len*3 */
size_t fmt_quotedprintable(char* dest,char* src,size_t len);
/* worst case: len*3 */
size_t fmt_quotedprintable2(char* dest,char* src,size_t len,char* escapeme);
/* worst case: len*3 */
size_t fmt_urlencoded(char* dest,char* src,size_t len);
/* worst case: len*3 */
size_t fmt_urlencoded2(char* dest,char* src,size_t len,char* escapeme);
/* worst case: len*2 */
size_t fmt_yenc(char* dest,char* src,size_t len);
/* needs len*2 bytes */
size_t fmt_hexdump(char* dest,char* src,size_t len);
/* change '<' to '&lt;' and '&' to '&amp;'; worst case: len*5 */
size_t fmt_html(char* dest,char* src,size_t len);
/* change '\' to "\\", '\n' to "\n", ^A to "\x01" etc; worst case: len*4 */
size_t fmt_cescape(char* dest,char* src,size_t len);
/* worst case: len*4 */
size_t fmt_cescape2(char* dest,char* src,size_t len,char* escapeme);
/* fold awk whitespace to '_'; this is great for writing fields with
 * white spaces to a log file and still allow awk to do log analysis */
/* worst case: same size */
size_t fmt_foldwhitespace(char* dest,char* src,size_t len);
/* worst case: len*3 */
size_t fmt_ldapescape(char* dest,char* src,size_t len);

/* These read one line from src, decoded it, and write the result to
 * dest.  The number of decoded bytes is written to destlen.  dest
 * should be able to hold strlen(src) bytes as a rule of thumb. */
size_t scan_uuencoded(char *src,char *dest,size_t *destlen);
size_t scan_base64(char *src,char *dest,size_t *destlen);
size_t scan_quotedprintable(char *src,char *dest,size_t *destlen);
size_t scan_urlencoded(char *src,char *dest,size_t *destlen);
size_t scan_urlencoded2(char *src,char *dest,size_t *destlen);
size_t scan_yenc(char *src,char *dest,size_t *destlen);
size_t scan_hexdump(char *src,char *dest,size_t *destlen);
size_t scan_html(char *src,char *dest,size_t *destlen);
size_t scan_cescape(char *src,char *dest,size_t *destlen);
size_t scan_ldapescape(char* src,char* dest,size_t *destlen);

/* WARNING: these functions _append_ to the stralloc, not overwrite! */
/* stralloc wrappers; return 1 on success, 0 on failure */
/* arg 1 is one of the fmt_* functions from above */
int fmt_to_sa(size_t (*func)(char*,char*,size_t),
	      stralloc* sa,char* src,size_t len);

int fmt_to_sa2(size_t (*func)(char*,char*,size_t,char*),
	      stralloc* sa,char* src,size_t len,char* escapeme);

/* arg 1 is one of the scan_* functions from above */
/* return number of bytes scanned */
size_t scan_to_sa(size_t (*func)(char*,char*,size_t*),
			 char* src,stralloc* sa);

//#define fmt_uuencoded_sa(sa,src,len) fmt_to_sa(fmt_uuencoded,sa,src,len)
//#define fmt_base64_sa(sa,src,len) fmt_to_sa(fmt_base64,sa,src,len)
//#define fmt_quotedprintable_sa(sa,src,len) fmt_to_sa(fmt_quotedprintable,sa,src,len)
//#define fmt_urlencoded_sa(sa,src,len) fmt_to_sa(fmt_urlencoded,sa,src,len)
//#define fmt_yenc_sa(sa,src,len) fmt_to_sa(fmt_yenc,sa,src,len)
//#define fmt_hexdump_sa(sa,src,len) fmt_to_sa(fmt_hexdump,sa,src,len)
//#define fmt_html_sa(sa,src,len) fmt_to_sa(fmt_html,sa,src,len)
//#define fmt_cescape_sa(sa,src,len) fmt_to_sa(fmt_cescape,sa,src,len)

//#define fmt_quotedprintable2_sa(sa,src,len,escapeme) fmt_to_sa2(fmt_quotedprintable2,sa,src,len,escapeme)
//#define fmt_urlencoded2_sa(sa,src,len,escapeme) fmt_to_sa2(fmt_urlencoded2,sa,src,len,escapeme)
//#define fmt_cescape2_sa(sa,src,len,escapeme) fmt_to_sa2(fmt_cescape2,sa,src,len,escapeme)

//#define scan_uuencoded_sa(src,sa) scan_to_sa(scan_uuencoded,src,sa)
//#define scan_base64_sa(src,sa) scan_to_sa(scan_base64,src,sa)
//#define scan_quotedprintable_sa(src,sa) scan_to_sa(scan_quotedprintable,src,sa)
//#define scan_urlencoded_sa(src,sa) scan_to_sa(scan_urlencoded,src,sa)
//#define scan_yenc_sa(src,sa) scan_to_sa(scan_yenc,src,sa)
//#define scan_hexdump_sa(src,sa) scan_to_sa(scan_hexdump,src,sa)
//#define scan_html_sa(src,sa) scan_to_sa(scan_html,src,sa)
//#define scan_cescape_sa(src,sa) scan_to_sa(scan_cescape,src,sa)

void fmt_to_array(size_t (*func)(char*,char*,size_t),
		  array* a,char* src,size_t len);

void fmt_tofrom_array(size_t (*func)(char*,char*,size_t),
		      array* dest,array* src);

void fmt_to_array2(size_t (*func)(char*,char*,size_t,char*),
		  array* a,char* src,size_t len,char* escapeme);

void fmt_tofrom_array2(size_t (*func)(char*,char*,size_t,char*),
		      array* dest,array* src,char* escapeme);

size_t scan_to_array(size_t (*func)(char*,char*,size_t*),
			    char* src,array* dest);

size_t scan_tofrom_array(size_t (*func)(char*,char*,size_t*),
			        array* src,array* dest);

extern char base64[64];

#if defined(__i386__) && !defined(NO_UINT16_MACROS)
#define ushort_pack(out,in) (*(ushort*)(out)=(in))
#define ushort_unpack(in,out) (*(out)=*(ushort*)(in))
#define ushort_read(in) (*(ushort*)(in))
void ushort_pack_big(char *buf_out,ushort in);
void ushort_unpack_big(char *buf_in,ushort* buf_out);
ushort ushort_read_big(char *buf_in);
#else

void ushort_pack(char *buf_out,ushort in);
void ushort_pack_big(char *buf_out,ushort in);
void ushort_unpack(char *buf_in,ushort* buf_out);
void ushort_unpack_big(char *buf_in,ushort* buf_out);
ushort ushort_read(char *buf_in);
ushort ushort_read_big(char *buf_in);

#endif

#if defined(__i386__) && !defined(NO_UINT32_MACROS)
#define uint_pack(out,in) (*(uint*)(out)=(in))
#define uint_unpack(in,out) (*(out)=*(uint*)(in))
#define uint_read(in) (*(uint*)(in))
void uint_pack_big(char *buf_out,uint in);
void uint_unpack_big(char *buf_in,uint* buf_out);
uint uint_read_big(char *buf_in);
#else

void uint_pack(char *buf_out,uint in);
void uint_pack_big(char *buf_out,uint in);
void uint_unpack(char *buf_in,uint* buf_out);
void uint_unpack_big(char *buf_in,uint* buf_out);
uint uint_read(char *buf_in);
uint uint_read_big(char *buf_in);

#endif

#ifdef __MINGW32__

/* set errno to WSAGetLastError() */
int winsock2errno(long l);
void __winsock_init();

#else

#define winsock2errno(fnord) (fnord)
#define __winsock_init()

#endif
+/
