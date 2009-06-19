#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
	if (argc > 2) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		CFStringRef appName = CFStringCreateWithFileSystemRepresentation(NULL, argv[1]);
		if (appName == NULL) // shouldn't happen
			errx(1, "Bad application name");
		NSString *appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:(NSString *)appName];
		if (appPath == nil)
			errx(1, "Couldn't find application '%s'", argv[1]);
		NSBundle *appBundle = [[NSBundle alloc] initWithPath:appPath];
		CFStringRef appID;
		if (appBundle == nil)
			errx(1, "Couldn't find bundle for application '%s'", argv[1]);
		appID = (CFStringRef)[[appBundle bundleIdentifier] copy];
		CFRelease(appName);
		CFRelease(appBundle);
		[pool release];

		int retval = 0;
		char currentFlag = 0;
		int i = 2;
		do {
			if (strcmp("-f", argv[i]) == 0) {
				currentFlag = 'f';
			} else if (strcmp("-u", argv[i]) == 0) {
				currentFlag = 'u';
			} else {
				CFStringRef arg = CFStringCreateWithFileSystemRepresentation(NULL, argv[i]);
				if (arg) {
					switch (currentFlag) {
						case 'f':
							// todo: set for single file.
							break;
						case 'u': {
							if (LSSetDefaultHandlerForURLScheme(arg, appID) != 0) {
								warnx("%s: failed", argv[i]);
								retval = 1;
							}
						} break;
						default:
							if (LSSetDefaultRoleHandlerForContentType(arg, kLSRolesAll, appID) != 0) {
								warnx("%s: failed", argv[i]);
								retval = 1;
							}
					}
					CFRelease(arg);
				} else {
					exit(1); // shouldn't happen
				}
				currentFlag = 0;
			}
			i += 1;
		} while (i < argc);
		if (currentFlag != 0)
			warnx("Last -%c flag ignored (has no argument).", currentFlag);

		CFRelease(appID);

		return retval;
	} else {
		errx(1, "usage:  %s <application> [<UTI>" /* " | -f <file>" */ " | -u <url-scheme>]\n", argv[0]);
	}
}