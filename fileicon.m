size_t pr(void *info, const void *buffer, size_t count);

size_t pr(void *info, const void *buffer, size_t count) {
//	return write(fileno(stdout), buffer, count);
	return fwrite(buffer, 1, count, stdout);
}
/*
 * Gets icon of file or file type in TIFF format.
 * If no destination path (and not tty), dump to stdout.
 */
int main(int argc, const char *argv[]) {
	if (argc > 1) {
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

		NSAutoreleasePool *pool = [NSAutoreleasePool new];

		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *cwd = [fm currentDirectoryPath];
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
		if (useType && [args count] != 1u)
			goto usage;
		// Don't dump data to a Terminal
		if (oURL == NULL && isatty(STDOUT_FILENO))
			goto usage;

		NSWorkspace *ws = [NSWorkspace sharedWorkspace];
		NSImage *img = useType ?  [ws iconForFileType:[args objectAtIndex:0u]] : [ws iconForFiles:args];

		CGImageSourceRef src = CGImageSourceCreateWithData((CFDataRef)[img TIFFRepresentation], NULL);

		[pool release];
		
		if (src == NULL) {
			fputs("Failed to create image source.\n", stderr);
			return 1;
		}

		NSUInteger num = CGImageSourceGetCount(src);

		CGImageDestinationRef dst;
		if (oURL != NULL) {
			dst = CGImageDestinationCreateWithURL(oURL, CFSTR("public.tiff"), num, NULL);
			CFRelease(oURL);
		} else {
			CGDataConsumerCallbacks c = {&pr, NULL};
			CGDataConsumerRef cons = CGDataConsumerCreate(NULL, &c);
			dst = CGImageDestinationCreateWithDataConsumer(cons, CFSTR("public.tiff"), num, NULL);
			CFRelease(cons);
		}

		if (dst == NULL) {
			fputs("Failed to create image destination.\n", stderr);
			return 1;
		}

		NSUInteger k = 0u;
		do {
			CGImageDestinationAddImageFromSource(dst, src, k, NULL);
			k += 1u;
		} while (k < num);

		if (CGImageDestinationFinalize(dst) != true) {
			fputs("Failed to finalize destination image.\n", stderr);
			return 1;
		}

		CFRelease(src);
		CFRelease(dst);

		return EX_OK;
	} else {
usage:
		fprintf(stderr, "usage:  %s <file>... -o <dst>.tiff\n\t%s -t <type> -o <dst.tiff>\n", argv[0], argv[0]);
		return 1;
	}
}
