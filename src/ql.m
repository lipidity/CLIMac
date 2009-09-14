#import <Cocoa/Cocoa.h>
#import <QuickLook/QuickLook.h>

typedef void *QLPreviewRef;
extern QLPreviewRef QLPreviewCreate(void *unknownNULL, CFTypeRef item, CFDictionaryRef options);
extern CFDataRef QLPreviewCopyData(QLPreviewRef thumbnail);
extern CFURLRef QLPreviewCopyURLRepresentation(QLPreviewRef);
extern CFDictionaryRef QLPreviewCopyOptions(QLPreviewRef);
extern CFDictionaryRef QLPreviewCopyProperties(QLPreviewRef);
extern CFStringRef QLPreviewGetPreviewType(QLPreviewRef); // eg. public.webcontent; public.text; public.image; public.pdf
extern void QLPreviewSetPreviewType(QLPreviewRef, CFStringRef);
extern void QLPreviewSetForceContentTypeUTI(QLPreviewRef, CFStringRef);

typedef void *QLThumbnailRef;
#if 0
extern const NSString *kQLThumbnailOptionContentTypeUTI;
//extern const NSString *kQLThumbnailOptionIconModeKey;
extern QLThumbnailRef QLThumbnailCreate(void *unknownNULL, CFURLRef fileURL, CGSize iconSize, CFDictionaryRef options);
extern CGImageRef QLThumbnailCopyImage(QLThumbnailRef thumbnail);
_QLThumbnailSupportsContentUTIAtSize
_QLThumbnailCopySpecialGenericImage
_QLThumbnailGetMaximumSize
_QLThumbnailGetMinimumUsefulSize
_QLThumbnailSetForceContentTypeUTI
#endif

int main (int argc, char *argv[]) {
	if (argc > 1) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		const struct option longopts[] = {
			// actions
			{ "preview", no_argument, NULL, 'p' },
			{ "thumbnail", no_argument, NULL, 't' },
			// thumbnail options
			{ "width", required_argument, NULL, 'w' },
			{ "height", required_argument, NULL, 'h' },
			{ "icon-mode", no_argument, NULL, 'm' },
			{ "scale", required_argument, NULL, 's' },
			// output
			{ "output", required_argument, NULL, 'o' },
			{ NULL, 0, NULL, 0 }
		};
		int c;
		char action = 0;
		NSURL *oURL = nil;
		CGSize size = {128.0f, 128.0f};
		float scale = 0.0f;
		BOOL icon = NO;
		while ((c = getopt_long_only(argc, (char **)argv, "pto:w:h:s:m", longopts, NULL)) != EOF) {
			switch (c) {
				case 't':
				case 'p':
					if (action == 0)
						action = c;
					else
						errx(1, "Only one %s option may be specified", "-thumbnail or -preview");
					break;
				case 'o':
					if (oURL == nil)
						oURL = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)optarg, strlen(optarg), false);
					else
						errx(1, "Only one %s option may be specified", "-output");
					break;
				case 'h': {
					char *ptr;
					size.height = strtof(optarg, &ptr);
					if (ptr == optarg)
						errx(1, "Invalid argument to %s option", "-height");
					break;
				}
				case 'w': {
					char *ptr;
					size.width = strtof(optarg, &ptr);
					if (ptr == optarg)
						errx(1, "Invalid argument to %s option", "-width");
					break;
				}
				case 's': {
					char *ptr;
					scale = strtof(optarg, &ptr);
					if (ptr == optarg)
						errx(1, "Invalid argument to %s option", "-scale");
					break;
				}
				case 'm':
					icon ^= YES;
					break;
				default: goto usage;
			}
		}
		if (action == 0)
			errx(1, "One of -preview or -thumbnail must be specified");
		if (oURL == nil && isatty(STDOUT_FILENO))
			errx(1, "Refusing to dump data to a terminal");
		argc -= optind;
		if (argc == 1) {
			argv += optind;
			NSData *tiff = nil;
			CFTypeRef item = NULL;
			if (action == 'p' && argv[0][0] == '-' && argv[0][1] == '\0') {
				item = (CFDataRef)[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
			} else {
				item = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[0], strlen(argv[0]), false);
			}
			if (action == 'p') {
				QLPreviewRef ql = QLPreviewCreate(NULL, item, NULL);
				tiff = (NSData *)QLPreviewCopyData(ql);
				if (tiff != nil) {
					fprintf(stderr, "Generated Preview: %s\n", [(NSString *)QLPreviewGetPreviewType(ql) fileSystemRepresentation]);
					NSDictionary *props = (NSDictionary *)QLPreviewCopyProperties(ql);
					NSUInteger numAttachments = [[props objectForKey:@"Attachments"] count];
					if (numAttachments != 0)
						fprintf(stderr, "%u attachments\n", numAttachments);
				}
			} else {
				NSMutableDictionary *opts = [NSMutableDictionary dictionary];
				if (scale)
					[opts setObject:[NSNumber numberWithFloat:scale] forKey:(NSString *)kQLThumbnailOptionScaleFactorKey];
				if (icon)
					[opts setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kQLThumbnailOptionIconModeKey];
				CGImageRef img = QLThumbnailImageCreate(NULL, item, size, (CFDictionaryRef)opts);
				if (img != NULL) {
					NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:img];
					tiff = [[bitmap TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0f] retain];
					[bitmap release];
					CGImageRelease(img);
				}
			}
			if (tiff != nil) {
				if (oURL != nil) {
					NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:0 userInfo:nil];
					if (![tiff writeToURL:oURL options:0U error:&error])
						errx(1, "Write failed: %s", [[error localizedFailureReason] fileSystemRepresentation]);
				} else {
					if (fwrite([tiff bytes], [tiff length], 1, stdout) != 1)
						err(1, NULL);
				}
				return 0;
			}
		} else
			goto usage;
		[pool release];
		return 1;
	}
usage:
	fprintf(stderr, "usage:  %s -p <file> [-o <out>]\n\t%s -t [-w <width>] [-h <height>] [-s <scale>] <file> [-o <out>.tiff]\n", argv[0], argv[0]);
	return 1;
}
