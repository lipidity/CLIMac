#import <err.h>
#import <stdlib.h>

static inline void *xmalloc(size_t n) {
	void *r;
	if ((r = malloc(n)) == NULL)
		err(1, NULL);
	return r;
}
static inline void *xcalloc(size_t n, size_t m) {
	void *r;
	if ((r = calloc(n, m)) == NULL)
		err(1, NULL);
	return r;
}
static inline void *xrealloc(void *ptr, size_t n) {
	void *r;
	if ((r = reallocf(ptr, n)) == NULL)
		err(1, NULL);
	return r;
}

#if 0
#import <sys/errno.h>
#import <err.h>
#import <getopt.h>
#import <libc.h>
#import <stdbool.h>
#import <sysexits.h>
#ifdef __OBJC__
#	import <Cocoa/Cocoa.h>
#endif
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <ApplicationServices/ApplicationServices.h>
#endif
