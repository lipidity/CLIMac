//
// ~~~~~~ BOTTOM UP ~~~~~~~
//
#if 0
if ~UNSIGN & STRIP & codesigned, then warn and confirm.
MACHO = STRIP | LIPO | UNSIGN
LANG_KEEPS = best 'n' langs.
foreach $arg
	if MACHO && isMachO
		if STRIP
			/usr/bin/strip (depending on mach_header filetype)
		if UNSIGN
			replace one byte in LC_WHATEVER (signing command name) with something else
		if LIPO
			thin to best arch
	else if JUNK
		if broken symlink
		if match (.DS_Store | *.nib/((classes|info|designer).nib|data.dependency))
		if Headers/ or PrivateHeaders/
			delete it
	else if LANG
		if .lproj/ & ~(match LANG_KEEPS), delete it
	else if TIFF & isTiff (check magic) & ~(isLZW | Packbits | other compression)
		compress w/ LZW
		if compressed smaller, replace orig else delete compressed
	if XATTRS & hasXAs
		delete XAs
#endif

// Don't need to do fts -- just take paths from arguments (then can use zargs/xargs)
// GET SOME CODE FROM monolingual (helper)

#import <Cocoa/Cocoa.h>
#import <fts.h>
#import <sys/xattr.h>
#include <mach-o/arch.h>
#include <mach-o/loader.h>
#include <mach-o/swap.h>
#include <mach-o/fat.h>
#import <architecture/byte_order.h> //NXSwapBigLongToHost(x)

#define FAIL fail(strerror(errno));
static void op_delete(const char *path);
static void op_xattr(const char *path);
static void fail(const char *format, ...);

int main(int argc, char *argv[]) {
	struct option longopts[] = {
		{ "junk", no_argument, NULL, 'j' },	// implies --headers --broken-symlinks
		{ "headers", no_argument, NULL, 'h' },	// delete Headers/*.h
		{ "broken-symlinks", no_argument, NULL, 'L' }, // delete symlinks which point to non-existent file
		{ "tiff", no_argument, NULL, 't' },		// compress tiffs
		{ "unsign", no_argument, NULL, 's' },	// remove code-signing
		{ "strip", no_argument, NULL, 'p' },	// implies --unsign
		{ "lipo", no_argument, NULL, 'a' },	// keep only native arch
		{ "arch", required_argument, NULL, 'r' },// keep specified arch(es)
		{ "xattr", no_argument, NULL, 'x' },	// implies --rsrc
		{ "rsrc", no_argument, NULL, 'c' },	// resource forks
		{ "lang", optional_argument, NULL, 'l' },	// language(s) to keep
		{ NULL, 0, NULL, 0 }
	};
	int c;
	while ((c = getopt_long_only(argc, argv, "", longopts, NULL)) != EOF) {
		
	}
	argc -= optind; argv += optind;

	FTS *fts = fts_open(&argv[0], FTS_PHYSICAL, NULL);
	if (fts == NULL)
		err(1, "fts_open");
#define JUNK 1
#define LIPO 1
#define UNSIGN 1
#define STRIP 1
#define LANG 1
#define TIFF 1
#define XATTRS 1 // refine which ones to keep/delete
	FTSENT *p;
	while ((p = fts_read(fts)) != NULL) {
		switch (p->fts_info) {
			case FTS_F:
				if (JUNK) {
					if (strcmp(p->fts_name, ".DS_Store") == 0) {
						op_delete(p->fts_accpath);
						break;
					}
				}
				if (LIPO || STRIP || UNSIGN) {
					// is it mach-o file?
					if (p->fts_statp->st_size > 128) { // TODO: FIXME: what's the smallest mach-o possible?
						int fd = open(p->fts_accpath, O_RDONLY); // LOCK?
						if (fd == -1)
							FAIL;
						struct fat_header f = {0};
						ssize_t r = read(fd, &f, sizeof(struct fat_header));
						if (r == -1)
							FAIL;
						if (f.magic ==
#ifdef __BIG_ENDIAN__
							FAT_MAGIC
#endif
#ifdef __LITTLE_ENDIAN__
							FAT_CIGAM
#endif
							) {
							
						}
					}
				}
				if (LIPO) {
				}
				if (XATTRS) {
					ssize_t n = listxattr(p->fts_accpath, NULL, 0, 0);
					if (n > 0) {
						op_xattr(p->fts_accpath);
					} else if (n == -1) {
						FAIL;
					}
				}
				break;
		}
	}
}

static void fail(const char *format, ...) {
	verrx(1, format, NULL); // and va_list
}
static void op_delete(const char *path) {
	if (1) { // delete file
		fprintf(stderr, "\t%s\n", path);
	} else {
		fail("Couldn't delete %s", path);
	}
}
static void op_xattr(const char *path) {
	if (1) { // delete file
		fprintf(stderr, "\t%s\n", path);
	} else {
		fail("Couldn't delete xattrs from %s", path);
	}
}

/*
 For dealing with lproj's, show tableview of |CFBundleCopyLocalizationsForURL()| with checkboxes
 Tick all of |CFBundleCopyLocalizationsForPreferences| and first present object of |CFLocaleCopyPreferredLanguages()|
 If more than two lproj's, and less than SETTING lproj's ticked, keep ticking from top of |CFLocaleCopyPreferredLanguages()| until exhaust list (display alert) or have SETTING ticked (where SETTING is one by default, but configurable)
 CFLocaleCopyPreferredLanguages() checks AppleLanguages AND NSLanguages
 
 Need to check localizations of each bundle contained within main bundle?
 */
#if 0
[NSAutoreleasePool new];
CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, argv[1], strlen(argv[1]), false);
CFArrayRef locs = CFBundleCopyLocalizationsForURL(url);
NSLog(@"localizations: %@", locs);
NSLog(@"preferred languages: %@", CFLocaleCopyPreferredLanguages()); // leopard
NSLog(@"preferred languages: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"]); // tiger
NSLog(@"fromArrayForPrefs: %@", CFBundleCopyLocalizationsForPreferences(locs, NULL));
#endif