/*
 * Sets icon for files.
 */
int main(int argc, const char *argv[]) {
	if (argc > 2) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];

		// connect to widow server
		[NSApplication sharedApplication];

		NSWorkspace *ws = [NSWorkspace sharedWorkspace];
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *cwd = [fm currentDirectoryPath];

		NSImage *icon = [[NSImage alloc] initWithContentsOfFile:[fm stringWithFileSystemRepresentation:argv[1] length:strlen(argv[1])]];
		if (icon != nil) {
			int retval = 0;
			int i = 2;
			do {
				NSString *path = [fm stringWithFileSystemRepresentation:argv[i] length:strlen(argv[i])];
				if (![path isAbsolutePath])
					path = [cwd stringByAppendingPathComponent:path];
				if (![ws setIcon:icon forFile:path options:0]) {
					retval = 1;
					warnx("%s: Couldn't set icon", argv[i]);
				}
				i += 1;
			} while (i < argc);
			[icon release];
			return retval;
		} else {
			errx(1, "%s: Not an image file", argv[1]);
		}
	} else {
		fprintf(stderr, "%s <image> <file>...\n", argv[0]);
		return 1;
	}
}
