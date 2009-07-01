#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

int main (int argc, char *argv[]) {
	if (argc > 2) {
		[NSAutoreleasePool new];
		CFURLRef inURL = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[1], strlen(argv[1]), false);
		PDFDocument *file = [[PDFDocument alloc] initWithURL:(NSURL *)inURL];
		CFRelease(inURL);
		CFURLRef oURL = NULL;
		PDFDocument *pdf = [[PDFDocument alloc] init];
		if (file == nil)
			errx(1, "%s: Not a pdf document", argv[1]);
		argv += 1; argc -= 1;
		struct option longopts[] = {
			{ "range", required_argument, NULL, 'r' },
			{ "page", required_argument, NULL, 'p' },
			{ "output", required_argument, NULL, 'o' },
			{ NULL, 0, NULL, 0 }
		};
		int c;
		while ((c = getopt_long_only(argc, argv, "r:p:o:", longopts, NULL)) != EOF) {
			switch (c) {
				case 'p': {
					NSUInteger idx = (NSUInteger)strtoul(optarg, NULL, 10);
					if (idx == 0)
						errx(1, "'%s': Invalid page number", optarg);
					if (idx-1 >= [file pageCount])
						errx(1, "Page number %lu doesn't exist", idx);
					[pdf insertPage:[file pageAtIndex:idx-1] atIndex:[pdf pageCount]];
				}
					break;
				case 'r': {
					NSUInteger from = 0, to = 0;
					char *end;
					from = strtoul(optarg, &end, 10);
					if (end != optarg) {
						while (isspace(*end))
							end += 1;
						if (*end == ',') {
							end += 1;
							if (*end == '-') {
								to = [file pageCount];
							} else {
								char *last;
								to = strtol(end, &last, 10);
								if (*last != '\0' || *end == '\0') {
									errx(1, "Invalid range");
								}
							}
							NSUInteger total = [pdf pageCount];
							while (from <= to)
								[pdf insertPage:[file pageAtIndex:(from++)-1] atIndex:total++];
							break;
						}
					}
					errx(1, "Invalid range");
				}
				case 'o':
					if (oURL != NULL)
						oURL = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)optarg, strlen(optarg), false);
					else
						errx(1, "Only one -output option allowed");
					break;
				default:
					goto usage;
			}
		}
		[file release];

		if ([pdf pageCount] == 0)
			errx(1, "Not writing empty document");

		if (oURL == NULL && isatty(STDOUT_FILENO))
			errx(1, "Refusing to dump pdf data to a terminal");

		NSData *data;
		if ((oURL != NULL && [pdf writeToURL:(NSURL *)oURL]) || ((data = [pdf dataRepresentation]) && fwrite([data bytes], [data length], 1, stdout) == 1))
			return 0;

//		[pdf release];
		err(1, NULL);
	}
usage:
	fprintf(stderr, "usage:  %s <file> [-p <n> | -r <start>,<end>]... [-o <out>.pdf]\n", argv[0]);
	return 1;
}
