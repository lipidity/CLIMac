/*
 * Sets icon for files.
 */
int main(int argc, const char *argv[]) {
	if (argc > 2) {
		[NSAutoreleasePool new];
		[NSApplication sharedApplication]; // connect to window server
		NSWorkspace *ws = [NSWorkspace sharedWorkspace];
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *cwd = [fm currentDirectoryPath];

		BOOL removing = NO;

		NSImage *icon = nil;
		if (argv[1][0] == '-') {
			if (argv[1][1] == '\0') {
				icon = [[NSImage alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile]];
			} else if (argv[1][1] == 'r' && argv[1][2] == '\0') {
//				icon = nil;
				removing = YES;
			} else {
				NSString *imgfile = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[1]);
				if (imgfile) {
					icon = [[NSImage alloc] initWithContentsOfFile:imgfile];
					CFRelease(imgfile);
				}
			}
		}
		if (icon != nil || removing) {
			int retval = 0;
			int i = 2;
			do {
				NSString *path = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[i]);
				if (![ws setIcon:icon forFile:([path isAbsolutePath] ? path : [cwd stringByAppendingPathComponent:path]) options:0]) {
					retval = 1;
					warn("%s: Couldn't set icon", argv[i]);
				}
				CFRelease(path);
				i += 1;
			} while (i < argc);
			if (!removing)
				[icon release];
			return retval;
		} else {
			errx(1, "%s: Not an image", argv[1][0] == '-' && argv[1][1] == '\0' ? "stdin" : argv[1]);
		}
	} else {
		fprintf(stderr, "usage:  %s <image> <file>...\n\t%s -r <file>...\n", argv[0], argv[0]);
		return 1;
	}
}
