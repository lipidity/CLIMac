#import <getopt.h>

CG_EXTERN OSStatus _LSCopyAllApplicationURLs(CFArrayRef *);
CG_EXTERN CGError CGSConnectionGetPID(int cid, pid_t *outPID);
CG_EXTERN int CGSMainConnectionID(void);
CG_EXTERN CGError CGSGetWindowOwner(int cid, int wid, int *outOwner);

/* LSCopyDefault(Role)?Handler functions are only valid for explicitly set associations. */

@interface NSString (aBID) - (NSString *) cp4bid; @end
@implementation NSString (aBID)
- (NSString *) cp4bid; {
	NSString *retval = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:self];
	if (retval == nil)
		warnx("No path for bundle ID '%s'", [self fileSystemRepresentation]);
	return retval;
}
@end

int main(int argc, const char * argv[]) {
	if (argc > 1) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		const struct option longopts[] = {
			/* list */
			{ "all", no_argument, NULL, 'l' },
			{ "active", no_argument, NULL, 'a' },
			/* find */
			{ "bundle", required_argument, NULL, 'b' },
			{ "window", required_argument, NULL, 'w' },
			{ "scheme", required_argument, NULL, 'u' },
			{ "type", required_argument, NULL, 't' },
			{ "file", required_argument, NULL, 'f' },
			{ NULL, 0, NULL, 0 }
		};
		int c;
		char action = 0;
		NSString *arg = NULL;
		BOOL listAll = NO;
		while ((c = getopt_long(argc, (char **)argv, "lab:w:u:t:f:", longopts, NULL)) != EOF) {
			switch (c) {
				case 'l':
					listAll ^= 1;
					break;
				case 'a':
				case 'b':
				case 'w':
				case 'u':
				case 't':
				case 'f':
					if (action != 0) {
						fputs("You may not specify more than one `-bwuta' option", stderr);
						goto usage;
					} else {
						action = c;
						if (action != 'a') {
							arg = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, optarg);
							if (arg == NULL)
								errc(1, EINVAL, "Argument for -%c", action);
						}
					}
					break;
				default:
					goto usage;
			}
		}
		if (argc != optind && argc != 2)
			goto usage;

		NSWorkspace *ws = [NSWorkspace sharedWorkspace];

		NSArray *all = NULL;
		NSString *str = nil;
		switch (action) {
			case 'a':
				if (listAll)
					all = [[[ws launchedApplications] valueForKey:@"NSApplicationPath"] copy];
				else
					str = [[[ws activeApplication] objectForKey:@"NSApplicationPath"] copy];
				break;
			case 'b':
				str = [[arg cp4bid] copy];
				break;
			case 'w': {
				NSScanner *scan = [NSScanner scannerWithString:arg];
				int wid = 0;
				int appConnection = 0;
				int appPid = 0;
				[scan scanInt:&wid];
				ProcessSerialNumber s = {0u, 0u};
				if (CGSGetWindowOwner(CGSMainConnectionID(), wid, &appConnection) == 0) {
					CGSConnectionGetPID(appConnection, &appPid);
					GetProcessForPID(appPid, &s);
					FSRef ref = {{0}};
					GetProcessBundleLocation(&s, &ref);
					CFURLRef appURL = CFURLCreateFromFSRef(NULL, &ref);
					if (appURL != NULL) {
						str = (NSString *)CFURLCopyFileSystemPath(appURL, kCFURLPOSIXPathStyle);
						CFRelease(appURL);
					}
				}
			}
				break;
			case 'u':
				if (listAll) {
					CFArrayRef bids = LSCopyAllHandlersForURLScheme((CFStringRef)arg);
					if (bids) {
						all = [[(NSArray *)bids valueForKey:@"cp4bid"] copy];
						CFRelease(bids);
					}
				} else {
					NSURL *inURL = [[NSURL alloc] initWithScheme:arg host:@"" path:@"/"];
					CFURLRef outURL = NULL;
					if ((LSGetApplicationForURL((CFURLRef)inURL, kLSRolesAll, NULL, (CFURLRef *)&outURL) == 0) && (outURL != NULL))
						str = (NSString *)CFURLCopyFileSystemPath(outURL, kCFURLPOSIXPathStyle);
					[inURL release];
#if 0
					CFStringRef bundle = LSCopyDefaultHandlerForURLScheme((CFStringRef)arg);
					if (bundle) {
						str = [[(NSString *)bundle cp4bid] copy];
						CFRelease(bundle);
					}
#endif
				}
				break;
			case 't':
				if (listAll) {
					CFArrayRef bids = LSCopyAllRoleHandlersForContentType((CFStringRef)arg, kLSRolesAll);
					if (bids) {
						all = [[(NSArray *)bids valueForKey:@"cp4bid"] copy];
						CFRelease(bids);
					}
				} else {
					CFStringRef bundle = LSCopyDefaultRoleHandlerForContentType((CFStringRef)arg, kLSRolesAll);
					if (bundle) {
						str = [[(NSString *)bundle cp4bid] copy];
						CFRelease(bundle);
					}
					if (str == NULL) {
						CFURLRef outURL = NULL;
						CFStringRef tag = UTTypeCopyPreferredTagWithClass((CFStringRef)arg, kUTTagClassMIMEType); // leak
						if (tag) {
							LSCopyApplicationForMIMEType(tag, kLSRolesAll, &outURL);
							if (outURL != NULL) {
								str = (NSString *)CFURLCopyFileSystemPath(outURL, kCFURLPOSIXPathStyle);
								CFRelease(outURL);
							}
						}
						if (str == NULL) {
							tag = UTTypeCopyPreferredTagWithClass((CFStringRef)arg, kUTTagClassFilenameExtension);
							if (tag) {
								LSGetApplicationForInfo(kLSUnknownType, kLSUnknownCreator, tag, kLSRolesAll, NULL, &outURL);
								if (outURL != NULL) {
									str = (NSString *)CFURLCopyFileSystemPath(outURL, kCFURLPOSIXPathStyle);
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
					str = [appName copy];
			}
				break;
			default: {
				if (listAll) {
					CFArrayRef appURLs = NULL;
					if (_LSCopyAllApplicationURLs(&appURLs) == 0) {
						all = [[(NSArray *)appURLs valueForKey:@"path"] copy];
						CFRelease(appURLs);
					}
				} else {
					arg = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[1]);
					if (arg) {
						str = [[ws fullPathForApplication:arg] copy];
					}
				}
				break;
			}
		}
		if (arg != NULL)
			CFRelease(arg);
		if (str != nil) {
			puts([str fileSystemRepresentation]);
			CFRelease(str);
		} else if (all != nil) {
			NSEnumerator *e = [all objectEnumerator];
			NSString *obj;
			while ((obj = [e nextObject]) != nil)
				if ([obj respondsToSelector:@selector(fileSystemRepresentation)])
					puts([obj fileSystemRepresentation]);
			CFRelease(all);
		} else {
			exit(1);
		}
		[pool release];
		return 0;
	} else {
usage:
		fprintf(stderr, "usage:  %s <name>\n", argv[0]);
		const char * const uses[] = {
			"-l", "-a", "-b <bundle-id>", "-w <window-id>", "-u <url-scheme>", "-t <UTI>", "-f <file>"
		};
		size_t j = 0;
		do {
			fprintf(stderr, "\t%s %s\n", argv[0], uses[j]);
			j += 1;
		} while (j < (sizeof(uses)/sizeof(uses[0])));
		return 1;
	}
}
