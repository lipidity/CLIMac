#import <Foundation/Foundation.h>

int main(int argc, char *argv[]) {
	if (argc == 1) {
usage:
		fprintf(stderr, "%s [-k] [-c | -d] <file> [-o <out>]\n", argv[0]);
		return 1;
	}

	unsigned char opts = 0;
#define MASK(C) (1 << ((((C) - 'a' + 1) >> 1) - 1))
#define GET(OPT) (opts & MASK(OPT))
#define SET(OPT) (opts |= MASK(OPT))
#define OPT_C MASK('c')
#define OPT_D MASK('d')
#define OPT_K MASK('k')
	char *outFile = NULL;
	int c;
	while ((c = getopt(argc, argv, "kcdo:")) != EOF) {
		switch (c) {
			case 'c':
			case 'd':
			case 'k':
				SET(c);
				break;
			case 'o':
				outFile = optarg;
				break;
			default:
				goto usage;
				break;
		}
	}
	if ((argc - optind) != 1)
		goto usage;
	argc -= optind; argv += optind;
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	CFStringRef aFile = CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
	if (aFile == NULL)
		errx(1, "Bad file path");
	NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
	NSStringEncoding encoding = NSUTF8StringEncoding;
	NSString *string = [[NSString alloc] initWithContentsOfFile:(NSString *)aFile usedEncoding:&encoding error:&error];
	if (string == nil)
		errx(1, "%s", [[error localizedFailureReason] fileSystemRepresentation]);
	CFRelease(aFile);
	fprintf(stderr, "Used encoding: %s\n", [(NSString *)CFStringGetNameOfEncoding(CFStringConvertNSStringEncodingToEncoding(encoding)) fileSystemRepresentation]);
	SEL form = NULL;
	switch (opts) {
		case OPT_C:
			form = @selector(precomposedStringWithCanonicalMapping);
			break;
		case OPT_D:
			form = @selector(decomposedStringWithCanonicalMapping);
			break;
		case OPT_K | OPT_C:
			form = @selector(precomposedStringWithCompatibilityMapping);
			break;
		case OPT_K | OPT_D:
			form = @selector(decomposedStringWithCompatibilityMapping);
			break;
		default:
			goto usage;
			break;
	}
	NSString *outString = [string performSelector:form];
	if (outString == nil)
		errx(1, "Couldn't normalize file");
	NSData *data = [outString dataUsingEncoding:encoding allowLossyConversion:NO];
	if (outFile) {
		CFStringRef outPath = CFStringCreateWithFileSystemRepresentation(NULL, outFile);
		if (outPath != NULL) {
			if (![data writeToFile:(NSString *)outPath options:0 error:&error])
				errx(1, "%s", [error localizedFailureReason]);
			CFRelease(outPath);
		} else {
			errx(1, "Bad output file path");
		}
	} else {
		write(STDOUT_FILENO, [data bytes], [data length]);
		if (isatty(STDOUT_FILENO) && [outString characterAtIndex:[outString length]-1] != '\n')
			warnx("no newline");
	}
	[string release];
	[pool release];
	return 0;
}