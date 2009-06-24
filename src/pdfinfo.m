#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

int main (int argc, char *argv[]) {
	if (argc == 2) {
		[NSAutoreleasePool new];
		CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[1], strlen(argv[1]), false);
		PDFDocument *pdf;
		if ((pdf = [[PDFDocument alloc] initWithURL:(NSURL *)url]) != nil) {
			printf("No. of Pages:\t%"
#ifdef __LP64__
				   "l"
#endif
				   "u\n", [pdf pageCount]);
			if ([pdf isEncrypted])
				printf("Encrypted (%socked)\n", ([pdf isLocked]) ? "L" : "Unl");
			NSDictionary *d = [pdf documentAttributes];
			for (NSString *key in d)
				printf("%s:\t%s\n", [key fileSystemRepresentation], [[[d objectForKey:key] description] fileSystemRepresentation]);
			return 0;
		}
		if (errno)
			err(1, NULL);
		errx(1, "%s: Not a PDF document", argv[1]);
	}
//usage:
	fprintf(stderr, "usage:  %s <file>\n", argv[0]);
	return 1;
}
