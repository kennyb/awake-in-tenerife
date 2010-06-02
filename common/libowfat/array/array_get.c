#ifdef __dietlibc__
#include <sys/cdefs.h>
#else
#define __likely(x) x
#define __unlikely(x) x
#endif
#include "safemult.h"
#include "array.h"

#if 0
      static array x;
      t *p;
      int64 pos;

      p = array_get(&x,sizeof(t),pos);

   array_get is similar to array_allocate, but it does not allocate any
   extra bytes, and it does not initialize any extra bytes. It
   returns 0 if x is unallocated, for example, or if fewer than
   (pos+1)*sizeof(t) bytes are initialized.
#endif

void* array_get(array* x,uint64 membersize,int64 pos) {
  uint64 wanted;
  if (__unlikely(pos+1<1)) return 0;
  if (__unlikely(!umult64(membersize,pos,&wanted))) return 0;

  if (__unlikely((int64)wanted >= x->allocated || wanted>=x->initialized)) return 0;
  return x->p+pos*membersize;
}
