/*
 * "Always open with..." for files, file types and URLs.
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Cocoa/Cocoa.h>

#import "climac.h"

extern OSStatus _LSGetStrongBindingForRef(const FSRef *inItemRef, FSRef *outAppRef);
extern OSStatus _LSSetStrongBindingForRef(const FSRef *inItemRef, FSRef *inAppRefOrNull);

static inline void usage(FILE *);

int main(int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ "role", required_argument, NULL, 'r' },

		{ "uti", no_argument, NULL, 'u' },
		{ "url-scheme", no_argument, NULL, 's' },
		{ "file", no_argument, NULL, 'f' },
		{ NULL, 0, NULL, 0 }
	};
	LSRolesMask roles = 0;
	char set_for = 't';
	int c;
	while ((c = getopt_long_only(argc, argv, "hV" "tufr:", longopts, NULL)) != EOF) {
		switch (c) {
			case 't':
			case 's':
			case 'f':
				set_for = c;
				break;
			case 'r':
				if (strcasecmp(optarg, "all") == 0) {
					roles |= kLSRolesAll;
				} else {
					static const char *the_roles[] = {"none", "viewer", "editor", "shell"};
					for (unsigned i = 0u; i < sizeof(the_roles)/sizeof(the_roles[0]); i++) {
						if (strcasecmp(the_roles[i], optarg) == 0) {
							roles |= (1 << i);
							goto end;
						}
					}
					errx(RET_USAGE, "no such role: %s", optarg);
				}
				break;
			case 'V':
				climac_version_info();
				exit(RET_SUCCESS);
			case 'h':
				usage(stdout);
				exit(RET_SUCCESS);
			default:
				fprintf(stderr,  "Try `%s --help' for more information.\n", getprogname());
				exit(RET_USAGE);
		}
	end:
		;
	}
	argc -= optind;
	if (argc < 2) {
		warnx("Not enough arguments");
		fprintf(stderr,  "Try `%s --help' for more information.\n", getprogname());
		exit(RET_USAGE);
	}
	argv += optind;
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	int retval = 0;
	if (set_for == 'f') {
		FSRef appRef;
		FSRef *appRefP = &appRef;
		if (argv[0][0] == '\0' || (argv[0][0] == '-' && argv[0][1] == '\0'))
			appRefP = NULL; // removing strong binding
		else if (FSPathMakeRef((const UInt8 *)argv[0], appRefP, NULL) != noErr)
			errx(RET_FAILURE, "not found: %s", argv[0]);
		while ((++argv)[0]) {
			FSRef r;
			if ((FSPathMakeRef((const UInt8 *)argv[0], &r, NULL) != noErr) || (_LSSetStrongBindingForRef(&r, appRefP) != noErr)) {
				warnx("%s: failed", argv[0]);
				retval = RET_FAILURE;
			}
		}
	} else {
		CFStringRef appID = NULL;
		NSString *appPath;
		NSBundle *appBundle;
		if (((appPath = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[0])) == nil)
			|| ((appBundle = [NSBundle bundleWithPath:appPath]) == nil)
			|| ((appID = (CFStringRef)[[appBundle bundleIdentifier] copy]) == nil))
			err(1, NULL);
		while ((++argv)[0]) {
			CFStringRef arg = CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
			if (arg == NULL)
				errx(RET_FAILURE, "bad string \"%s\"", argv[0]);
			if ((set_for == 'u' && LSSetDefaultHandlerForURLScheme(arg, appID) != 0)
				|| (set_for == 't' && LSSetDefaultRoleHandlerForContentType(arg, roles || kLSRolesAll, appID) != 0)) {
				warnx("%s: failed", argv[0]);
				retval = RET_FAILURE;
			}
			CFRelease(arg);
		}
		CFRelease(appID);
	}

	[pool release];

	return retval;
}

static inline void usage(FILE *outfile) {
	fprintf(outfile, "Usage: %s <abs-path> {-t <UTI> | -f <file> | -u <url-scheme>}\n", getprogname());
}
