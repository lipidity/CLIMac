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
static inline NSString *absolute_path_for_bundle_id(NSString *);
static inline NSString *cstring_to_nsstring(const char *s);
static inline void with_cstring(NSString *path, void (^act)(char *));

static NSWorkspace *ws = nil;
static NSFileManager *fm = nil;

/* one of these is used to print the final result */
static void (^b_url)(id, NSUInteger, BOOL *) = ^(id obj, NSUInteger idx __unused, BOOL *stop __unused) {
	with_cstring([obj path], ^(char *b){ puts(b); });
};
static void (^b_bundle)(id, NSUInteger, BOOL *) = ^(id obj, NSUInteger idx __unused, BOOL *stop __unused) {
	with_cstring(bid2path(obj), ^(char *b){ puts(b); });
};
static void (^ablock)(id, NSUInteger, BOOL *) = ^(id obj, NSUInteger idx __unused, BOOL *stop __unused) {
	with_cstring(obj, ^(char *b){ puts(b); });
};

int main(int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		/* list */
		{ "all", no_argument, NULL, 'l' },
		{ "active", no_argument, NULL, 'a' },
		/* find */
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
	while ((c = getopt_long_only(argc, argv, "hVlab:s:u:t:f:n:", longopts, NULL)) != EOF) {
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
						arg = cstring_to_nsstring(optarg);
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
		arg = cstring_to_nsstring(argv[0]);
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
			result = absolute_path_for_bundle_id((id)arg);
			if (result)
				result = [result copy];
			break;
		case 's':	/* by URL scheme */
			if (listAll) {
				result = (NSArray *)LSCopyAllHandlersForURLScheme((CFStringRef)arg);
				ablock = b_bundle;
			} else {
				CFStringRef bundle = LSCopyDefaultHandlerForURLScheme((CFStringRef)arg);
				if (bundle) {
					result = absolute_path_for_bundle_id((id)bundle);
					if (result)
						result = [result copy];
					CFRelease(bundle);
				}
			}
			break;
		case 'u': {	/* by URL */
			NSURL *inURL = [[NSURL alloc] initWithString:arg];
			CFURLRef outURL = NULL;
			if (inURL == nil)
				errx(1, "Invalid URL.");
			if (listAll) {
				result = (NSArray *)LSCopyApplicationURLsForURL((CFURLRef)inURL, kLSRolesAll);
				ablock = b_url;
			} else {
				if ((LSGetApplicationForURL((CFURLRef)inURL, kLSRolesAll, NULL, &outURL) == 0) && (outURL != NULL))
					result = (NSString *)CFURLCopyFileSystemPath(outURL, kCFURLPOSIXPathStyle);
			}
			[inURL release];
		}
			break;
		case 't':	/* by Uniform Type Identifier */
			if (listAll) {
				result = (NSArray *)LSCopyAllRoleHandlersForContentType((CFStringRef)arg, kLSRolesAll);
				ablock = b_bundle;
			} else {
				CFStringRef bundle = LSCopyDefaultRoleHandlerForContentType((CFStringRef)arg, kLSRolesAll);
				if (bundle) {
					result = [absolute_path_for_bundle_id((NSString *)bundle) copy];
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
				(void)_LSCopyAllApplicationURLs((CFArrayRef *)&result);
				ablock = b_url;
			}
			break;
	}
	if (arg != nil)
		[arg release];
	if (result != nil) {
		if ([result respondsToSelector:@selector(fileSystemRepresentation)]) {
			/* result is either an NSString* */
			puts([result fileSystemRepresentation]);
			[result release];
			exit(RET_SUCCESS);
		} else if ([result respondsToSelector:@selector(enumerateObjectsUsingBlock:)]) {
			/* or an NSArray* */
			if ([result count] != 0) {
				[result enumerateObjectsUsingBlock:ablock];
				[result release];
				exit(RET_SUCCESS);
			}
		}
		[result release];
	}
	exit(RET_FAILURE);
}

static inline NSString *cstring_to_nsstring(const char *s) {
	return [fm stringWithFileSystemRepresentation:s length:strlen(s)];
}

/*
 * Not using -[NSString fileSystemRepresentation]
 * because it calls -[fm fileSystemRepresentationWithPath:]
 * which can throw an exception.
 */
static inline void with_cstring(NSString *path, void (^act)(char *)) {
	if (path != nil && [path length] != 0) {
		CFIndex maxlen = CFStringGetMaximumSizeOfFileSystemRepresentation((CFStringRef)path);
		char *b = malloc(maxlen);
		if (CFStringGetFileSystemRepresentation((CFStringRef)path, b, maxlen))
			act(b);
		free(b);
	}
}

static inline NSString *absolute_path_for_bundle_id(NSString *bid) {
	NSString *retval = [ws absolutePathForAppBundleWithIdentifier:bid];
	if (retval == nil)
		with_cstring(bid, ^(char *b){ warnx("%s: not found", b); });
	return retval;
}

static inline void usage(FILE *outfile) {
	fprintf(outfile, "Usage: %s [-l] [option]\n", getprogname());
	static const struct {
		const char *long_opt;
		const char *explanation;
		char short_opt;
	} const u[] = {
		{.short_opt = 'a', .long_opt = "active",			.explanation = "frontmost app; with -l all running"},
		{.short_opt = 'n', .long_opt = "name=[App]",		.explanation = "app with name"},
		{.short_opt = 'b', .long_opt = "bundle=[BundleID]", .explanation = "app with bundle identifier"},
		{.short_opt = 's', .long_opt = "url-scheme=[Scheme]", .explanation = "for URLs of type (eg. `https')"},
		{.short_opt = 'u', .long_opt = "url=[URL]",			.explanation = "for specific URL"},
		{.short_opt = 't', .long_opt = "uti=[UTI]",			.explanation = "for files of type; see uti(1)"},
		{.short_opt = 'f', .long_opt = "file=[File]",		.explanation = "for specific file"},
	};
	for (unsigned j = 0; j < sizeof(u)/sizeof(u[0]); j++)
		fprintf(outfile, "    -%c, -%-22s%s\n", u[j].short_opt, u[j].long_opt, u[j].explanation);
}
