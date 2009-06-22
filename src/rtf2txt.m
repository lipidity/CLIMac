#import <Cocoa/Cocoa.h>

int main (int argc, char *argv[]) {
	if ((argc == 2 && isatty(STDOUT_FILENO)) || argc == 3) {
		[NSAutoreleasePool new];
		[NSApplication sharedApplication];

		CFStringRef inPath = CFStringCreateWithFileSystemRepresentation(NULL, argv[1]);
		if (inPath) {
			NSAttributedString *str = [[NSAttributedString alloc] initWithPath:(NSString *)inPath documentAttributes:NULL];
			CFRelease(inPath);
			if (str) {
				NSData *data = [[str string] dataUsingEncoding:NSUTF8StringEncoding];
				if (argc == 3) {
					CFStringRef outPath = CFStringCreateWithFileSystemRepresentation(NULL, argv[2]);
					if (outPath && [data writeToFile:(NSString *)outPath atomically:NO]) {
						CFRelease(outPath);
						return 0;
					}
				} else {
					if (fwrite([data bytes], [data length], 1, stdout) == 1)
						return 0;
				}
				err(1, NULL);
			}
			errx(1, "%s: not a rich text document", argv[1]);
		}
		return 2;
	}
	fprintf(stderr, "usage: %s <rtf> <out>.txt\n", argv[0]);
	return 1;
}
