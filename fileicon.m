/*
 * Gets icon of file or file type in TIFF format (with LZW compression).
 * If no destination path (and not tty), dump to stdout.
 *
 * Also sets icon for files.
 */
int main(int argc, const char *argv[]) {
	if (argc > 1) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];

		NSWorkspace *ws = [NSWorkspace sharedWorkspace];
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *cwd = [fm currentDirectoryPath];

		if ((argc != 4) || (strcmp("-s", argv[1]) != 0)) { // get icon from file (or file type)
			BOOL useType = NO;
			CFURLRef oURL = NULL;
			NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:argc-1];
			
			int i = 1;
			if (strcmp("-t", argv[1]) == 0) {
				useType = YES;
				i += 1;
				if (i >= argc)
					goto usage;
			}

			while (i < argc) {
				if (strcmp("-o", argv[i]) != 0) {
					NSString *s = [fm stringWithFileSystemRepresentation:argv[i] length:strlen(argv[i])];
					if (!useType && ![s isAbsolutePath])
						s = [cwd stringByAppendingPathComponent:s];
					[args addObject:s];
				} else {
					i += 1;
					if (oURL != NULL)
						CFRelease(oURL);
					if (!(i < argc && (oURL = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[i], strlen(argv[i]), false)))) {
						warnx("Option `-o' needs a path argument.");
						goto usage;
					}
				}
				i += 1;
			}

			// Only one file type allowed
			if (useType && ([args count] != 1u))
				goto usage;
			// Don't dump data to a Terminal
			if ((oURL == NULL) && isatty(STDOUT_FILENO))
				goto usage;

			NSImage *img = useType ?  [ws iconForFileType:[args objectAtIndex:0u]] : [ws iconForFiles:args];

			NSData *tiff = [img TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0f];
			if (tiff == nil)
				errx(1, "Couldn't get TIFF representation of icon.");

			if (oURL != NULL) {
				if (![tiff writeToURL:(NSURL *)oURL atomically:NO])
					err(1, "Couldn't write image.");
			} else {
				if (fwrite([tiff bytes], [tiff length], 1, stdout) != 1)
					err(1, NULL);
			}

			[pool release];

			return EX_OK;
		} else { // set icon on file(s)
			[NSApplication sharedApplication];
			NSImage *icon = [[NSImage alloc] initWithContentsOfFile:[fm stringWithFileSystemRepresentation:argv[2] length:strlen(argv[2])]];
			BOOL retval = 0;
			int i = 3;
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
			return retval;
		}
	} else {
usage:
		fprintf(stderr, "usage:  %s <file>... -o <dst>.tiff\n\t%s -t <type> -o <dst.tiff>\n\t%s -s <image> <file>...\n", argv[0], argv[0], argv[0]);
		return 1;
	}
}
