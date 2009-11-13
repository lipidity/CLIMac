/*
 * "Always open with..." for files, file types and URLs.
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

extern OSStatus _LSSetWeakBindingForType(OSType        inType,			// kLSUnknownType if no type binding performed
										 OSType        inCreator,		// always kLSUnknownCreator
										 CFStringRef   inExtension,	// or NULL if no extension binding is done
										 LSRolesMask   inRole,			// role for the binding
										 FSRef *       inAppRefOrNil);	// bound app or NULL to clear the binding

extern OSStatus _LSGetStrongBindingForRef(const FSRef *  inItemRef,
										  FSRef *        outAppRef);

extern OSStatus _LSSetStrongBindingForRef(const FSRef *  inItemRef,
										  FSRef *        inAppRefOrNil);	// NULL to clear the strong binding

extern OSStatus _LSCopyAllApplicationURLs(CFArrayRef * outURLs);

int main(int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ "verbose", no_argument, NULL, 'v' },
		{ "role", required_argument, NULL, 'r' },

		{ "type", no_argument, NULL, 't' },
		{ "url-scheme", no_argument, NULL, 'u' },
		{ "file", no_argument, NULL, 'f' },
		{ NULL, 0, NULL, 0 }
	};
	char verbose = 0;
	LSRolesMask roles = 0;
	char set_for = 't';
	int c;
	while ((c = getopt_long_only(argc, argv, "hvtufr:", longopts, NULL)) != EOF) {
		switch (c) {
			case 't':
			case 'u':
			case 'f':
				set_for = c;
				break;
			case 'v':
				verbose++;
				break;
			case 'r':
				if (strcasecmp(optarg, "all") == 0) {
					roles |= kLSRolesAll;
				} else {
					static const char *the_roles[] = {"none", "viewer", "editor", "shell"};
					for (unsigned i = 0u; i < sizeof(the_roles)/sizeof(the_roles[0]); i++) {
						if (strcasecmp(the_roles[i], optarg) == 0) {
							roles |= (1 << i);
							break;
						}
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
	argc -= optind;

	if (argc >= 2) {
		argv += optind;
		CFStringRef appID = NULL;
		FSRef appRef;
		FSRef *appRefP = &appRef;
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		if ((argv[0][0] == '\0' && set_for == 'f')) {
			appRefP = NULL; // removing
		} else {
			CFStringRef appName = CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
			if (appName == NULL) // shouldn't happen
				errx(1, NULL);
			NSString *appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:(NSString *)appName];
			if (appPath == nil)
				errx(1, "Couldn't find application '%s'", argv[0]);
			const char *pathStr = [appPath fileSystemRepresentation];
			if (verbose != 0)
				printf("Application: %s\n", pathStr);
			if (set_for == 'f') {
				if (FSPathMakeRef((const UInt8 *)pathStr, appRefP, NULL) != noErr)
					errx(1, NULL);
			} else {
				NSBundle *appBundle = [[NSBundle alloc] initWithPath:appPath];
				if (appBundle == nil)
					errx(1, "Couldn't find bundle for '%s'", argv[0]);
				appID = (CFStringRef)[[appBundle bundleIdentifier] copy];
				[appBundle release];
			}
			CFRelease(appName);
		}
		[pool release];

		if (roles == 0)
			roles = kLSRolesAll;

		pool = [NSAutoreleasePool new]; // for _LSSetStrongBindingForRef
		int retval = 0;
		while ((++argv)[0] != NULL) {
			CFStringRef arg = CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
			if (arg != NULL) {
				switch (set_for) {
					case 'f': {
						FSRef r;
						if ((FSPathMakeRef((const UInt8 *)[(NSString *)arg UTF8String], &r, NULL) != noErr) || (_LSSetStrongBindingForRef(&r, appRefP) != noErr))
							warnx("%s: failed", argv[0]);
					}	break;
					case 'u':
						if (LSSetDefaultHandlerForURLScheme(arg, appID) != 0) {
							warnx("%s: failed", argv[0]);
							retval = 1;
						}
						break;
					default:
						if (LSSetDefaultRoleHandlerForContentType(arg, roles, appID) != 0) {
							warnx("%s: failed", argv[0]);
							retval = 1;
						}
						break;
				}
				CFRelease(arg);
			} else {
				exit(1); // shouldn't happen
			}
		}
		[pool release];
		if (appID != NULL)
			CFRelease(appID);

		return retval;
	} else {
	usage:
		fprintf(stderr, "usage:  %s <application> {-t <UTI> | -f <file> | -u <url-scheme>}\n", argv[0]);
		return 1;
	}
}
