/*
 * Find or list applications
 * gcc -std=c99 -framework Cocoa -o app app.m
 */

#import <Cocoa/Cocoa.h>
#import <err.h>
#import <getopt.h>

#import "version.h"
#import "ret_codes.h"

/* Get NSArray * of all apps registered with LaunchServices */
extern OSStatus _LSCopyAllApplicationURLs(CFArrayRef *);

static inline void usage(FILE *);

static NSWorkspace *ws = nil;
static NSFileManager *fm = nil;

int main(int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ "all", no_argument, NULL, 'l' },

		{ "active", no_argument, NULL, 'a' },
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
	while ((c = getopt_long(argc, argv, "hVlab:s:u:t:f:n:", longopts, NULL)) != EOF) {
		switch (c) {
			case 'l':
				listAll = 1;
				break;
			case 'a':
			case 'b':
			case 'f':
			case 'n':
			case 's':
			case 't':
			case 'u':
				if (action == 0) {
					action = c;
					if (action != 'a')
						arg = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				} else {
					warnx("Can't specify both -%c and -%c", action, c);
					fprintf(stderr,  "Try `%s --help' for more information.\n", argv[0]);
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
				fprintf(stderr, "Try `%s --help' for more information.\n", argv[0]);
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

	fm = [NSFileManager defaultManager];
	ws = [NSWorkspace sharedWorkspace];

	id result = nil;
	switch (action) {
		case 'a':	/* by launched/active */
			if (listAll)
				result = [[[ws launchedApplications] valueForKey:@"NSApplicationPath"] copy];
			else
				result = [[[ws activeApplication] valueForKey:@"NSApplicationPath"] copy];
			break;
		case 'b':	/* by bundle ID */
			result = [ws URLForApplicationWithBundleIdentifier:(NSString *)arg];
			if (result) {
				if (listAll)
					result = [[NSArray alloc] initWithObjects:[result path], nil];
				else
					result = [[result path] copy];
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
							result = [[NSArray alloc] initWithObjects:result, nil];
						else
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
				id apps = (NSArray *)LSCopyAllRoleHandlersForContentType((CFStringRef)arg, kLSRolesAll);
				result = [[apps valueForKey:@"path"] copy];
				[apps release];
			} else {
				NSString *bundle = (NSString *)LSCopyDefaultRoleHandlerForContentType((CFStringRef)arg, kLSRolesAll);
				if (bundle) {
					result = [[[ws URLForApplicationWithBundleIdentifier:bundle] path] copy];
					CFRelease(bundle);
				}
			}
			break;
		case 'f': { /* by file */
			NSString *absPath = [arg isAbsolutePath] ? arg : [[fm currentDirectoryPath] stringByAppendingPathComponent:arg];
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
				id apps = nil;
				(void)_LSCopyAllApplicationURLs((CFArrayRef *)&apps);
				result = [apps valueForKey:@"path"];
				[apps release];
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
	static const struct {
		char short_opt;
		const char *long_opt;
		const char *explanation;
	} const u[] = {
		{ 'a', "active",			 "frontmost app; with -l all running"},
		{ 'n', "name=[App]",		 "app with name"},
		{ 'b', "bundle=[BundleID]",  "app with bundle identifier"},
		{ 's', "url-scheme=[Scheme]","for URLs of type (eg. `https')"},
		{ 'u', "url=[URL]",			 "for specific URL"},
		{ 't', "uti=[UTI]",			 "for files of type; see uti(1)"},
		{ 'f', "file=[File]",		 "for specific file"},
	};
	for (unsigned j = 0; j < sizeof(u)/sizeof(u[0]); j++)
		fprintf(outfile, "    -%c, --%-22s%s\n", u[j].short_opt, u[j].long_opt, u[j].explanation);
}
