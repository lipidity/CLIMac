#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

int main (int argc, char *argv[]) {
	if (argc > 1) {
		[NSAutoreleasePool new];

		PDFDocument *pdf = [[PDFDocument alloc] init];
		CFURLRef oURL = NULL;
		int i = 1;
		do {
			if (strcmp(argv[i], "-o") == 0) {
				i += 1;
				if (!(oURL == NULL && i < argc && (oURL = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[i], strlen(argv[i]), false)) != NULL))
					goto usage;
			} else if (strcmp(argv[i], "-") == 0) {
				NSData *d = [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
				if (d != nil) {
					PDFDocument *file = [[PDFDocument alloc] initWithData:d];
					if (file != nil) {
						NSUInteger filePages = [file pageCount];
						NSUInteger totalPages = [pdf pageCount];
						NSUInteger j = 0;
						while (j < filePages)
							[pdf insertPage:[file pageAtIndex:j++] atIndex:totalPages++];
						[file release];
					} else {
						warnx("%s: Not a pdf document", "stdin");
					}
				}
			} else {
				CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[i], strlen(argv[i]), false);
				if (url != NULL) {
					PDFDocument *file = [[PDFDocument alloc] initWithURL:(NSURL *)url];
					if (file != nil) {
						NSUInteger filePages = [file pageCount];
						NSUInteger totalPages = [pdf pageCount];
						NSUInteger j = 0;
						while (j < filePages)
							[pdf insertPage:[file pageAtIndex:j++] atIndex:totalPages++];
						[file release];
					} else {
						warnx("%s: Not a pdf document", argv[i]);
					}
					CFRelease(url);
				}
			}
			i += 1;
		} while (i < argc);

		if ([pdf pageCount] == 0)
			errx(1, "Not writing empty document");

		if (oURL == NULL && isatty(STDOUT_FILENO))
			errx(1, "Refusing to dump pdf data to a terminal");

		NSData *data;
		if ((oURL != NULL && [pdf writeToURL:(NSURL *)oURL]) || ((data = [pdf dataRepresentation]) && fwrite([data bytes], [data length], 1, stdout) == 1))
			return 0;

		err(1, NULL);
	}
usage:
	fprintf(stderr, "usage:  %s <file>... [-o <out>.pdf]\n", argv[0]);
	return 1;
}
