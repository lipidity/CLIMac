size_t pr(void *info, const void *buffer, size_t count);

size_t pr(void *info, const void *buffer, size_t count) {
//	return write(fileno(stdout), buffer, count);
	return fwrite(buffer, 1, count, stdout);
}
/*
 * Gets icon of file in TIFF format.
 * If no destination path, dump to stdout (if not tty).
*/
// TODO:
// % fileicon file1 file2	# use iconForFiles:
// % fileicon -t 'txt'		# use iconForFileType:
int main(int argc, const char *argv[]) {
	if (argc != 2 && argc != 3) {
		fprintf(stderr, "usage:  %s <src> [<dst>.tiff]\n", argv[0]);
		return 1;
	}

	if (argc == 2 && isatty(STDOUT_FILENO)) {
		fputs("Please provide a path to save the image to (or pipe stdout to a file / command).\n", stderr);
		return 1;
	}

//	if (access(argv[1], F_OK) != 0) {
//		warn(argv[1]);
//	}

	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *p = [fm stringWithFileSystemRepresentation:argv[1] length:strlen(argv[1])];
	if (![p isAbsolutePath])
		p = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:p];
	NSImage *img = [[NSWorkspace sharedWorkspace] iconForFile:p];
	CGImageSourceRef src = CGImageSourceCreateWithData((CFDataRef)[img TIFFRepresentation], NULL);

	if (src == NULL) {
		fputs("Failed to create image source.\n", stderr);
		return 1;
	}

	NSUInteger num = CGImageSourceGetCount(src);

	[pool release];

	CGImageDestinationRef dst;
	if (argc == 3) {
		CFURLRef uDst = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[2], strlen(argv[2]), false);
		dst = CGImageDestinationCreateWithURL(uDst, CFSTR("public.tiff"), num, NULL);
		CFRelease(uDst);
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

	NSUInteger i = 0;
	do {
		CGImageDestinationAddImageFromSource(dst, src, i, NULL);
		i += 1;
	} while (i < num);

	if (CGImageDestinationFinalize(dst) != true) {
		fputs("Failed to finalize destination image.\n", stderr);
		return 1;
	}

	CFRelease(src);
	CFRelease(dst);

	return EX_OK;
}
