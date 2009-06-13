int _LSCopyAllApplicationURLs(CFArrayRef *); // extern?

CG_EXTERN CGError CGSConnectionGetPID(int cid, pid_t *outPID);
CG_EXTERN int CGSMainConnectionID(void);
CG_EXTERN CGError CGSGetWindowOwner(int cid, int wid, int *outOwner);

static NSString *l = nil;

static void a4f(const char *);
static void a4b(const char *);
static void a4e(const char *);
static void a4w(const char *);
static void app(const char *);
static void printApp(NSDictionary *application, NSArray *opts);
static void list(BOOL a, const char opts[]);
static void asc(const char *f);

static void printCFURLPath(const void *value, void *context);

static void printCFURLPath(const void *value, void *context)
{
	UInt8 buffer[PATH_MAX];
	if (CFURLGetFileSystemRepresentation(value, true, buffer, PATH_MAX))
		puts((char *)buffer);
}

int main(int argc, const char * argv[])
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	int i;
	opterr = 0;
	while ((i = getopt(argc, (char **)argv, "aw:b:l:c:f:e:s:")) != EOF) {
		if (i != 's') {
			if (argc - optind == 0) { // no further arguments
				switch (i) {
					case 'w': a4w(optarg); break;
					case 'b': a4b(optarg); break;
					case 'f': a4f(optarg); break;
					case 'e': a4e(optarg); break;
					case 'l': list(NO, optarg); break;
					case 'c': list(YES, optarg); break;
					case 'a': {
						CFArrayRef urls;
						int retval = _LSCopyAllApplicationURLs(&urls);
						if (retval == 0) {
							CFArrayApplyFunction(urls, CFRangeMake(0, CFArrayGetCount(urls)), &printCFURLPath, NULL);
						} else {
							errx(EX_UNAVAILABLE, "_LSCopyAllApplicationURLs returned %d.", retval);
						}
					} break;
					default: goto usage;
				}
				return 0;
			} else {
				goto usage;
			}
		} else {
			if ((l = [[NSBundle bundleWithPath:[[NSWorkspace sharedWorkspace] fullPathForApplication:[NSString stringWithUTF8String:optarg]]] bundleIdentifier])) {
				int numFiles = argc - optind;
				if (numFiles) {
					argv += optind;
					do {
						asc(argv[0]);
						argv += 1;
						numFiles -= 1;
					} while (numFiles);
					return 0;
				} else {
					goto usage;
				}
			} else {
				errx(1, "%s: No such application bundle ID", optarg);
			}
		}
	}

	if (argc - optind == 1) {
		app(argv[optind]);
	} else {
usage:
		fprintf(stderr, "usage:  %s <name>\n", argv[0]);
		const char * const uses[] = {
				"-a",
				"-f <file>",
				"-b <bundle-id>",
				"-e <extension>",
				"-w <window-id>",
				"-c [nbpi]",
				"-l [nbpi]",
				"-s <app> [<file> | <uti>]..."};
		size_t j = 0;
		do {
			fputs("\t", stderr); // assume "\t" == 8 spaces
			fputs(argv[0], stderr);
			fputc(' ', stderr);
			fputs(uses[j], stderr);
			fputc('\n', stderr);
			j += 1;
		} while (j < (sizeof(uses)/sizeof(uses[0])));
		return 1;
	}

	[pool release];
	return 0;
}

static void a4f(const char *f)
{
	CFURLRef appURL = NULL;
	CFURLRef itemURL = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)f, strlen(f), false);
	UInt8 path[PATH_MAX];
	// FIXME: different errors for different points of failures
	if (LSGetApplicationForURL(itemURL, kLSRolesAll, NULL, &appURL) == 0 && appURL != NULL && CFURLGetFileSystemRepresentation(appURL, true, path, PATH_MAX) == true) {
		puts((char *)path);
		CFRelease(appURL);
	} else {
		exit(1);
	}
	CFRelease(itemURL);
}

static void a4b(const char *b)
{
	NSString *p;
	if ((p = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:[NSString stringWithUTF8String:b]]))
		puts([p fileSystemRepresentation]);
	else {
		exit(1);
	}
}

static void a4e(const char *e)
{
	CFURLRef u = NULL;
	/* OSStatus er = */ LSGetApplicationForInfo(kLSUnknownType, kLSUnknownCreator, (CFStringRef)[NSString stringWithUTF8String:e], kLSRolesAll, NULL, &u);
	if (u) {
		printCFURLPath(u, NULL);
		CFRelease(u);
	} else {
//		fprintf(stderr, "'%s': LS Error %d\n", e, (int)er);
		exit(1);
	}
}

static void a4w(const char *wid)
{
	int w = (int)strtol(wid, NULL, 10);
	int c, p; ProcessSerialNumber s;
	CGError retval = CGSGetWindowOwner(CGSMainConnectionID(), w, &c);
	if (retval == 0) {
		CGSConnectionGetPID(c, &p);
		GetProcessForPID(p, &s);
		CFStringRef m = NULL;
		OSStatus cperr = CopyProcessName(&s, &m);
		if (m != NULL) {
			puts([[[NSWorkspace sharedWorkspace] fullPathForApplication:(NSString *)m] fileSystemRepresentation]);
			CFRelease(m);
		} else {
			// better error message?
			if (cperr)
				errx(1, "CopyProcessName returned %d", cperr);
			errx(1, "%d: Owner has no name", w);
		}
	} else {
		errx(1, "%d: Couldn't determine window owner", w);
	}
}

static void app(const char *n)
{
	CFStringRef application = CFStringCreateWithFileSystemRepresentation(NULL, n);
	NSString *p = [[NSWorkspace sharedWorkspace] fullPathForApplication:(NSString *)application];
	if (p != nil) {
		puts([p fileSystemRepresentation]);
	} else {
		exit(1);
	}
	CFRelease(application);
}

static void printApp(NSDictionary *application, NSArray *opts)
{
	NSEnumerator *e = [opts objectEnumerator];
	NSString *key;
	while ((key = [e nextObject]))
		puts([[[application objectForKey:key] description] fileSystemRepresentation]);
}

static void list(BOOL a, const char opts[])
{
	NSMutableArray *k = [[NSMutableArray alloc] init];
	int i = 0;
	while (opts[i]) {
		switch (opts[i++]) {
			case 'p': [k addObject:@"NSApplicationPath"]; break;
			case 'n': [k addObject:@"NSApplicationName"]; break;
			case 'b': [k addObject:@"NSApplicationBundleIdentifier"]; break;
			case 'i': [k addObject:@"NSApplicationProcessIdentifier"]; break;
			default:
				fprintf(stderr, "No such option '%c'.\n", opts[i-1]);
				exit(1);
		}
	}
	int kc = [k count];
	if (!kc) {
		[k addObject:@"NSApplicationName"];
		kc = 1;
	}
	if (a) {
		printApp([[NSWorkspace sharedWorkspace] activeApplication], k);
	} else {
		NSEnumerator *e = [[[NSWorkspace sharedWorkspace] launchedApplications] objectEnumerator];
		NSDictionary *d = [e nextObject];
		if (!d)
			exit(0);
loop:
		printApp(d, k);
		if ((d = [e nextObject])) {
			if (kc > 1)
				putchar('\n');
			goto loop;
		}
	}
	[k release];
}

static void asc(const char *f)
{
	FSRef r;
	OSStatus er;
	if ((er = FSPathMakeRef((const UInt8 *)f, &r, NULL))) {
		// not path, try setting UTI
		CFStringRef ff = CFStringCreateWithFileSystemRepresentation(NULL, f);
		er = LSSetDefaultRoleHandlerForContentType(ff, kLSRolesAll, (CFStringRef)l);
		if (er != 0) {
			errx(1, "%s: LSSetDefaultRoleHandlerForContentType returned %d", f, er);
		}
		CFRelease(ff);
	} else {
		// path
		CFStringRef t = NULL;
		if (LSCopyItemAttribute(&r, kLSRolesNone, kLSItemContentType, (CFTypeRef *)&t) || LSSetDefaultRoleHandlerForContentType(t, kLSRolesAll, (CFStringRef)l)) {
			errx(EX_UNAVAILABLE, "%s: Failed to associate with %s", f, [l UTF8String]);
		} else {
			CFRelease(t);
		}
	}
}
