#import <Cocoa/Cocoa.h>

// todo: specify output target size?

int main (int argc, const char * argv[]) {
	if (argc != 2 && argc != 3) {
		fprintf(stderr, "usage:  %s [<src>] <dst>\n", argv[0]);
		return 1;
	}

	CGImageSourceRef src;
	CGImageDestinationRef dst;
	if (argc == 2) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		src = CGImageSourceCreateWithData((CFDataRef)[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile], NULL);
		[pool release];
	} else {
		CFURLRef u = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[1], strlen(argv[1]), 0);
		src = CGImageSourceCreateWithURL(u, NULL);
		CFRelease(u);
	}

	if (!(src || CGImageSourceGetCount(src))) {
		fputs("Bad source image.\n", stderr);
		return 2;
	}

	CFURLRef uDst = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[argc-1], strlen(argv[argc-1]), 0);

	CFArrayRef all = CGImageDestinationCopyTypeIdentifiers();
	CFStringRef ext = CFURLCopyPathExtension(uDst);
	CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, NULL);
	CFRelease(ext);

	if (![(NSArray *)all containsObject:(NSString *)uti]) {
		CFRelease(uti);
		fputs("Unknown destination image format. Using tiff.\n", stderr);
		uti = CFStringCreateCopy(NULL, CFSTR("public.tiff"));
	}

	dst = CGImageDestinationCreateWithURL(uDst, uti, 1, NULL);

	CFRelease(all);
	CFRelease(uti);
	CFRelease(uDst);

	CGImageDestinationAddImageFromSource(dst, src, 0, NULL);

	CGImageDestinationFinalize(dst);

	CFRelease(src);
	CFRelease(dst);

	return 0;
}
