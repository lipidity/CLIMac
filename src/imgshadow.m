#import <Cocoa/Cocoa.h>

int main (int argc, char * argv[]) {
	if (argc > 1) {

		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		[NSApplication sharedApplication];

		static struct option longopts[] = {
			{ "blur", required_argument, NULL, 'b' },
			{ "color", required_argument, NULL, 'c' },
			{ "x-offset", required_argument, NULL, 'x' },
			{ "y-offset", required_argument, NULL, 'y' },
			{ "output", required_argument, NULL, 'o' },
			{ NULL, 0, NULL, 0 }
		};
		const char *outPath = NULL;
		int ch; opterr = 0; float x, y = x = 0.0f, blur = 10.0f; NSColor *color = [NSColor shadowColor];
		while ((ch = getopt_long(argc, argv, "b:c:x:y:o:", longopts, NULL)) != EOF) {
			switch (ch) {
				case 'b': {
					char *end = NULL;
					blur = strtof(optarg, &end);
					if (end == optarg)
						errx(1, "`-%c' should have a float argument", 'b');
					break;
				}
				case 'x': {
					char *end = NULL;
					x = strtof(optarg, &end);
					if (end == optarg)
						errx(1, "`-%c' should have a float argument", 'x');
					break;
				}
				case 'y': {
					char *end = NULL;
					y = strtof(optarg, &end);
					if (end == optarg)
						errx(1, "`-%c' should have a float argument", 'y');
					break;
				}
				case 'c': {
					float rgb[3] = {0.0f, 0.0f, 0.0f}, alpha = 1.0f;
					if (sscanf(optarg, "%g %g %g %g", &rgb[0], &rgb[1], &rgb[2], &alpha) < 3)
						errx(1, "invalid argument to `-c' option");
					color = [NSColor colorWithCalibratedRed:rgb[0] green:rgb[1] blue:rgb[2] alpha:alpha];
					break;
				}
				case 'o':
					outPath = optarg;
					break;
				default:
					goto usage;
			}
		}
		argv += optind; argc -= optind;

		const char *inPath;
		if (argc == 1) {
			if (outPath == NULL && isatty(STDOUT_FILENO))
				goto usage;
			inPath = argv[0];
		} else if (argc == 3) {
			if (strcmp(argv[0], "-o") == 0) {
				outPath = argv[1];
				inPath = argv[2];
			} else if (strcmp(argv[1], "-o") == 0) {
				outPath = argv[2];
				inPath = argv[0];
			} else {
				goto usage;
			}
		} else {
			goto usage;
		}

		NSString *path = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, inPath);
		NSImage *src = [[NSImage alloc] initWithContentsOfFile:path];
		if (src == nil)
			errx(1, "%s: not an image", inPath);
		[path release];

		NSShadow *s = [[NSShadow alloc] init];
		[s setShadowOffset:NSMakeSize(x, y)];
		[s setShadowBlurRadius:blur];
		[s setShadowColor:color];

		NSSize z = [src size];

		NSImage *o = [[NSImage alloc] initWithSize:NSMakeSize(z.width + (2.0f * blur) + fabsf(x), z.height + (2.0f * blur) + fabsf(y))];
		[o lockFocus];
		[s set];
		[src compositeToPoint:NSMakePoint(blur - (x < 0.0f) *x, blur - (y < 0.0f)*y) operation:NSCompositeSourceOver];
		[o unlockFocus];

		[s release];
		[src release];

		NSData *tiff = [o TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0f];
		if (tiff == nil)
			errx(2, "Couldn't get TIFF representation of icon.");

		if (outPath != NULL) {
			CFStringRef oPath = CFStringCreateWithFileSystemRepresentation(NULL, outPath);
			if (![tiff writeToFile:(NSString *)oPath atomically:0])
				errx(2, "Couldn't write image");
			CFRelease(oPath);
		} else {
			if (fwrite([tiff bytes], [tiff length], 1, stdout) != 1)
				err(2, NULL);
	//		[(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:tiff];
		}

		[pool release];
		return 0;
	} else {
usage:
		fprintf(stderr, "usage:  %s [<options>] <image> -o <out>.tiff\n\tOptions: -c/--color, -b/--blur, -x/--x-offset, -y/--y-offset\n", argv[0]);
		return 1;
	}
}
