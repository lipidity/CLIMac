/*
 * Find or list applications
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

extern OSStatus _LSCopyAllApplicationURLs(CFArrayRef *);
extern CGError CGSConnectionGetPID(int cid, pid_t *outPID);
extern int CGSMainConnectionID(void);
extern CGError CGSGetWindowOwner(int cid, int wid, int *outOwner);

static NSWorkspace *ws = nil;

/* LSCopyDefault(Role)?Handler functions are only valid for explicitly set associations. */
static inline NSString *pathForBundle(CFStringRef bundle);
static inline NSString *pathForBundle(CFStringRef bundle) {
	if (bundle != NULL) {
		NSString *retval = [ws absolutePathForAppBundleWithIdentifier:(NSString *)bundle];
		if (retval == nil)
			warnx("No path for bundle ID '%s'", [(NSString *)bundle fileSystemRepresentation]);
		return retval;
	} else {
		return NULL;
	}
}
static NSArray *bundlesToPaths(CFArrayRef bids);
static NSArray *bundlesToPaths(CFArrayRef bids) {
	NSUInteger n = CFArrayGetCount(bids);
	NSMutableArray *a = [[NSMutableArray alloc] initWithCapacity:n];
	NSEnumerator *e = [(NSArray *)bids objectEnumerator];
	NSString *b;
	while ((b = [e nextObject]) != nil) {
		b = pathForBundle((CFStringRef)b);
		if (b != nil) {
			[a addObject:b];
		}
	}
	return a;
}

int main(int argc, char *argv[]) {
	if (argc > 1) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		const struct option longopts[] = {
			{ "help", no_argument, NULL, 'h' },
			{ "version", no_argument, NULL, 'V' },

			/* list */
			{ "all", no_argument, NULL, 'l' },
			{ "active", no_argument, NULL, 'a' },
			/* find */
			{ "name", required_argument, NULL, 'n' },
			{ "bundle", required_argument, NULL, 'b' },
			{ "window", required_argument, NULL, 'w' },
			{ "scheme", required_argument, NULL, 'u' }, // TODO: url and url scheme are different; LSGetApplicationForURL vs LSCopyDefaultHandlerForURLScheme
//			{ "url", required_argument, NULL, 'U' },
			{ "type", required_argument, NULL, 't' },
			{ "file", required_argument, NULL, 'f' },
			{ NULL, 0, NULL, 0 }
		};
		int c;
		char action = 0;
		CFStringRef arg = NULL;
		BOOL listAll = 0;
		while ((c = getopt_long_only(argc, argv, "lab:w:u:t:f:n:h", longopts, NULL)) != EOF) {
			switch (c) {
				case 'l':
					listAll ^= 1;
					break;
				case 'a':
				case 'n':
				case 'b':
				case 'w':
				case 'u':
				case 't':
				case 'f':
					if (action != 0) {
						fputs("You may not specify more than one `-nbwuta' option", stderr);
						fprintf(stderr,  "Try `%s --help' for more information.\n", argv[0]);
						return 2;
					} else {
						action = c;
						if (action != 'a') {
							arg = CFStringCreateWithFileSystemRepresentation(NULL, optarg);
							if (arg == NULL)
								errc(1, EINVAL, "Argument for -%c", action);
						}
					}
					break;
				case 'V':
					PRINT_VERSION;
					return 0;
				case 'h':
					goto usage;
				default:
					fprintf(stderr,  "Try `%s --help' for more information.\n", argv[0]);
					return 2;
			}
		}
		argc -= optind; argv += optind;
		if (action == 0 && argc == 1) {
			action = 'n';
			arg = CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
			if (arg == NULL)
				errc(1, EINVAL, NULL);
		} else if (((action | listAll) == 0) || argc != 0) {
			goto usage;
		}

		ws = [NSWorkspace sharedWorkspace];

		id result = nil;
		switch (action) {
			case 'a':
				if (listAll)
					result = [[[ws launchedApplications] valueForKey:@"NSApplicationPath"] copy];
				else
					result = [[[ws activeApplication] objectForKey:@"NSApplicationPath"] copy];
				break;
			case 'b':
				result = [pathForBundle(arg) copy];
				break;
			case 'w': {
				int wid = 0;
				int appCid = 0;
				int appPid = 0;
				if (sscanf([(NSString *)arg fileSystemRepresentation], "%u", &wid) != 1)
					errc(1, EINVAL, "Argument for -%c", 'w');
				ProcessSerialNumber s = {0u, 0u};
				if (CGSGetWindowOwner(CGSMainConnectionID(), wid, &appCid) == 0) {
					CGSConnectionGetPID(appCid, &appPid);
					GetProcessForPID(appPid, &s);
					FSRef ref = {{0}};
					GetProcessBundleLocation(&s, &ref);
					UInt8 path[PATH_MAX];
					if (FSRefMakePath(&ref, path, PATH_MAX) == noErr)
						result = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, (char *)path);
				}
			}
				break;
			case 'u':
				if (listAll) {
					CFArrayRef bids = LSCopyAllHandlersForURLScheme(arg);
					if (bids) {
						result = bundlesToPaths(bids);
					}
				} else {
#if 0
					NSURL *inURL = [[NSURL alloc] initWithScheme:arg host:@"" path:@"/"];
					CFURLRef outURL = NULL;
					if ((LSGetApplicationForURL((CFURLRef)inURL, kLSRolesAll, NULL, (CFURLRef *)&outURL) == 0) && (outURL != NULL))
						result = (NSString *)CFURLCopyFileSystemPath(outURL, kCFURLPOSIXPathStyle);
					[inURL release];
#else
					CFStringRef bundle = LSCopyDefaultHandlerForURLScheme(arg);
					if (bundle) {
						result = [pathForBundle(bundle) copy];
						CFRelease(bundle);
					}
#endif
				}
				break;
			case 't':
				if (listAll) {
					CFArrayRef bids = LSCopyAllRoleHandlersForContentType((CFStringRef)arg, kLSRolesAll);
					if (bids) {
						result = bundlesToPaths(bids);
						CFRelease(bids);
					}
				} else {
					CFStringRef bundle = LSCopyDefaultRoleHandlerForContentType((CFStringRef)arg, kLSRolesAll);
					if (bundle) {
						result = [pathForBundle(bundle) copy];
						CFRelease(bundle);
					}
					if (result == NULL) {
						warnx("Searching further...");
						CFURLRef outURL = NULL;
						CFStringRef tag = UTTypeCopyPreferredTagWithClass((CFStringRef)arg, kUTTagClassMIMEType); // leak
						if (tag) {
							LSCopyApplicationForMIMEType(tag, kLSRolesAll, &outURL);
							if (outURL != NULL) {
								result = (NSString *)CFURLCopyFileSystemPath(outURL, kCFURLPOSIXPathStyle);
								CFRelease(outURL);
							}
						}
						if (result == NULL) {
							tag = UTTypeCopyPreferredTagWithClass((CFStringRef)arg, kUTTagClassFilenameExtension);
							if (tag) {
								LSGetApplicationForInfo(kLSUnknownType, kLSUnknownCreator, tag, kLSRolesAll, NULL, &outURL);
								if (outURL != NULL) {
									result = (NSString *)CFURLCopyFileSystemPath(outURL, kCFURLPOSIXPathStyle);
								}
							}
						}
					}
				}
				break;
			case 'f': {
				NSString *absPath = ([(NSString *)arg isAbsolutePath]) ? (NSString *)arg : [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:(NSString *)arg];
				NSString *appName = nil, *fileType = nil;
				[ws getInfoForFile:absPath application:&appName type:&fileType];
				if (appName)
					result = [appName copy];
			}
				break;
			case 'n': {
				result = [[ws fullPathForApplication:(NSString *)arg] copy];
			}
				break;
			case 0:
				if (listAll) {
					CFArrayRef appURLs = NULL;
					if (_LSCopyAllApplicationURLs(&appURLs) == 0) {
						result = [[(NSArray *)appURLs valueForKey:@"path"] copy];
						CFRelease(appURLs);
					}
				}
				break;
			default: {
				// shouldn't happen
				exit(1);
			}
		}
		if (arg != NULL)
			CFRelease(arg);
		if ([result respondsToSelector:@selector(fileSystemRepresentation)]) {
			puts([result fileSystemRepresentation]);
			CFRelease(result);
		} else if ([result respondsToSelector:@selector(objectEnumerator)]) {
			NSEnumerator *e = [result objectEnumerator];
			NSString *obj;
			while ((obj = [e nextObject]) != nil)
				if ([obj respondsToSelector:@selector(fileSystemRepresentation)])
					puts([obj fileSystemRepresentation]);
			CFRelease(result);
		} else {
			exit(1);
		}
		[pool release];
		return 0;
	} else {
usage:
		fprintf(stderr, "Usage:  %s [--all] [criterion]\nCriterion is one of:\n", argv[0]);
		const char * const uses[] = {
			"active",				"",
			"name <app-name>",		"eg. Chess",
			"bundle <bundle-id>",	"eg. com.apple.Chess",
			"window <window-id>",	"see wid(1)",
			"url-scheme <scheme>",	"eg. https",
			"type <UTI>",			"see uti(1)",
			"file <file>",			"eg. readme.txt",
		};
		unsigned short j = 1;
		do {
			fprintf(stderr, "%9s%-25s%s\n", "-", uses[j-1], uses[j]);
			j += 2;
		} while (j < (sizeof(uses)/sizeof(uses[0])));
		return 1;
	}
}
