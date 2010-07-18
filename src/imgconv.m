/*
 * Copies image data from one place to another,
 *  either from standard input or from an existing image file.
 *
 * The format of the destination image is determined by
 *  the extension specified (eg. .tiff, .png, .jpg).
 *
 * Handles multiple image representations (eg. can have multiple images in one tiff file)
 */

// there is also sips(1)

int main (int argc, char *argv[]) {
//	These are probably not necessary as they can be done manually in Preview.app, but command-line capability wouldn't hurt.
// MAY:	use CGImageDestinationSetProperties() to specify background color (if output doesn't handle alpha) & compression type / level
// MAY:	have option to extract all with suffixes (eg. $(fileicon / | imgconv -a out.png) makes |out-<1-5>.png|) =OR=
// MAY:	specify which image $(fileicon / | imgconv -e 3 out.png) =OR=
// MAY:	specify which size image $(fileicon / | imgconv -s 32 out.png)
	if (argc == 2) {
		CFArrayRef a = NULL;
		if (strcmp(argv[1], "-in") == 0)
			a = CGImageSourceCopyTypeIdentifiers();
		else if (strcmp(argv[1], "-out") == 0)
			a = CGImageDestinationCopyTypeIdentifiers();
		if (a != NULL) {
			[NSAutoreleasePool new];
			for (CFIndex i = 0; i < CFArrayGetCount(a); i++)
				puts([(NSString *)CFArrayGetValueAtIndex(a, i) fileSystemRepresentation]);
			return 0;
		}
	}
	if (argc != 2 && argc != 3) {
		fprintf(stderr, "usage:  %s [<src>] <dst>\n", argv[0]);
		return 1;
	}

	CGImageSourceRef src;
	CGImageDestinationRef dst;

	if (argc == 2) { // argument is destination path; source image from stdin
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		src = CGImageSourceCreateWithData((CFDataRef)[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile], NULL);
		[pool release];
	} else { // first arg is path to source image
		CFURLRef u = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[1], strlen(argv[1]), 0);
		src = CGImageSourceCreateWithURL(u, NULL);
		CFRelease(u);
	}

	if (src == NULL) {
		fputs("Failed to create image source.\n", stderr);
		return 1;
	}

	CFURLRef uDst = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[argc-1], strlen(argv[argc-1]), false);

	CFArrayRef all = CGImageDestinationCopyTypeIdentifiers();
	CFStringRef ext = CFURLCopyPathExtension(uDst);
	CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL);

	if (![(NSArray *)all containsObject:(NSString *)uti]) {
		CFRelease(uti);
		fputs("Could not determine image type from destination path extension. Using TIFF format.\n", stderr);
		uti = CFRetain(CFSTR("public.tiff"));
	}

	size_t numImages = CGImageSourceGetCount(src);
	dst = CGImageDestinationCreateWithURL(uDst, uti, numImages, NULL);
	if (dst == NULL) { // maybe destination format can't handle multiple images?
		numImages = 1;
		dst = CGImageDestinationCreateWithURL(uDst, uti, numImages, NULL);
		if (dst == NULL) { // not gonna work
			fputs("Failed to create image destination.\n", stderr);
			return 1;
		}
	}

	CFRelease(ext);
	CFRelease(all);
	CFRelease(uti);
	CFRelease(uDst);

	do {
		numImages -= 1;
		CGImageDestinationAddImageFromSource(dst, src, numImages, NULL);
	} while (numImages);

	if (CGImageDestinationFinalize(dst) != true) {
		fputs("Failed to finalize destination image.\n", stderr);
		return 1;
	}

	CFRelease(src);
	CFRelease(dst);

	return 0;
}
