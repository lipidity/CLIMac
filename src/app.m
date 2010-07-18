/*
 * Find or list applications
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Cocoa/Cocoa.h>

#import "climac.h"

/* Get NSArray * of all apps registered with LaunchServices */
extern OSStatus _LSCopyAllApplicationURLs(CFArrayRef *);

static inline void usage(FILE *);

int main(int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ "all", no_argument, NULL, 'l' },

		{ "name", required_argument, NULL, 'n' },
		{ "bundle", required_argument, NULL, 'b' },
		{ "url-scheme", required_argument, NULL, 's' },
		{ "url", required_argument, NULL, 'u' },
		{ "uti", required_argument, NULL, 't' },
		{ "file", required_argument, NULL, 'f' },
		{ NULL, 0, NULL, 0 }
	};

	char action = 0;
	BOOL listAll = 0;
	NSString *arg = nil;

	int c;
	while ((c = getopt_long(argc, argv, "hVlb:s:u:t:f:n:", longopts, NULL)) != EOF) {
		switch (c) {
			case 'l':
				listAll = 1;
				break;
			case 'b':
			case 'f':
			case 'n':
			case 's':
			case 't':
			case 'u':
				if (action == 0) {
					action = c;
					arg = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				} else {
					warnx("Can't specify both -%c and -%c", action, c);
					fprintf(stderr,  "Try `%s --help' for more information.\n", getprogname());
					exit(RET_USAGE);
				}
				break;
			case 'V':
				climac_version_info();
				exit(RET_SUCCESS);
			case 'h':
				usage(stdout);
				exit(RET_SUCCESS);
			default:
				fprintf(stderr, "Try `%s --help' for more information.\n", getprogname());
				exit(RET_USAGE);
		}
	}
	argc -= optind; argv += optind;
	if (action == 0 && argc == 1) {
		/* default is to search by name */
		action = 'n';
		arg = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
	} else if (((action | listAll) == 0) || argc != 0) {
		/* nothing to be done OR too many arguments given */
		usage(stderr);
		exit(RET_USAGE);
	}

	[NSAutoreleasePool new];

	NSWorkspace *ws = [NSWorkspace sharedWorkspace];

	id result = nil;
	switch (action) {
		case 'b':	/* by bundle ID */
			result = [ws URLForApplicationWithBundleIdentifier:(NSString *)arg];
			if (result) {
				result = [result path];
				if (listAll)
					result = [NSArray arrayWithObject:result];
				result = [result copy];
			}
			break;
		case 's':	/* by URL scheme */
			if (listAll) {
				NSArray *bundles = (NSArray *)LSCopyAllHandlersForURLScheme((CFStringRef)arg);
				result = [[NSMutableArray alloc] initWithCapacity:[bundles count]];
				for (NSString *bundle in bundles) {
					NSURL *url = [ws URLForApplicationWithBundleIdentifier:bundle];
					if (url)
						[result addObject:[url path]];
				}
			} else {
				NSString *bundle = (NSString *)LSCopyDefaultHandlerForURLScheme((CFStringRef)arg);
				if (bundle) {
					result = [[ws URLForApplicationWithBundleIdentifier:bundle] path];
					if (result) {
						if (listAll)
							result = [NSArray arrayWithObject:result];
						result = [result copy];
					}
					CFRelease(bundle);
				}
			}
			break;
		case 'u': {	/* by URL */
			NSURL *inURL = [[NSURL alloc] initWithString:arg];
			if (inURL == nil)
				errx(1, "Invalid URL.");
			if (listAll) {
				id apps = (NSArray *)LSCopyApplicationURLsForURL((CFURLRef)inURL, kLSRolesAll);
				result = [[apps valueForKey:@"path"] copy];
				[apps release];
			} else {
				result = [[[ws URLForApplicationToOpenURL:inURL] path] copy];
			}
			[inURL release];
		}
			break;
		case 't':	/* by Uniform Type Identifier */
			if (listAll) {
				id bundles = (NSArray *)LSCopyAllRoleHandlersForContentType((CFStringRef)arg, kLSRolesAll);
				result = [[NSMutableArray alloc] initWithCapacity:[bundles count]];
				for (NSString *bundle in bundles) {
					NSURL *url = [ws URLForApplicationWithBundleIdentifier:bundle];
					if (url)
						[result addObject:[url path]];
				}
				[bundles release];
			} else {
				NSString *bundle = (NSString *)LSCopyDefaultRoleHandlerForContentType((CFStringRef)arg, kLSRolesAll);
				if (bundle) {
					result = [[[ws URLForApplicationWithBundleIdentifier:bundle] path] copy];
					CFRelease(bundle);
				}
			}
			break;
		case 'f': { /* by file */
			if (listAll)
				errx(1, "-lf doesn't make sense. use -lt instead.");
			NSString *absPath = [arg isAbsolutePath] ? arg : [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:arg];
			NSString *appName = nil, *fileType = nil;
			[ws getInfoForFile:absPath application:&appName type:&fileType];
			if (appName)
				result = [appName copy];
		}
			break;
		case 'n':	/* by name */
			result = [ws fullPathForApplication:arg];
			if (result)
				result = [result copy];
			break;
		case 0:	/* all applications */
			if (listAll) {
				CFArrayRef apps = NULL;
				(void)_LSCopyAllApplicationURLs(&apps);
				result = [(NSArray *)apps valueForKey:@"path"];
				CFRelease(apps);
			}
			break;
	}
	if (arg != nil)
		[arg release];

	if (result != nil) {
		if (listAll) {
			if ([result count] != 0) {
				for (NSString *str in result)
					puts([str fileSystemRepresentation]);
				[result release];
				exit(RET_SUCCESS);
			}
		} else {
			puts([result fileSystemRepresentation]);
			[result release];
			exit(RET_SUCCESS);
		}
		[result release];
	}
	exit(RET_FAILURE);
}

static inline void usage(FILE *outfile) {
	fprintf(outfile, "Usage: %s [-l] [option]\n", getprogname());
	struct {
		const char *opt;
		const char *exp;
	} u[] = {
		{ "n" "name=[App]",			 "app with name"},
		{ "b" "bundle=[BundleID]",	 "app with bundle identifier"},
		{ "s" "url-scheme=[Scheme]", "for URLs of type (eg. `https')"},
		{ "u" "url=[URL]",			 "for specific URL"},
		{ "t" "uti=[UTI]",			 "for files of type; see uti(1)"},
		{ "f" "file=[File]",		 "for specific file"},
	};
	for (unsigned j = 0; j < sizeof(u)/sizeof(u[0]); j++)
		fprintf(outfile, "    -%c, --%-22s%s\n", u[j].opt[0], u[j].opt + 1, u[j].exp);
}
