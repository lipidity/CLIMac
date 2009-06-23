#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QuickLook/QuickLook.h>

typedef void *QLPreviewRef;
extern QLPreviewRef QLPreviewCreate(void *unknownNULL, CFURLRef fileURL, CFDictionaryRef options);
extern CFDataRef QLPreviewCopyData(QLPreviewRef thumbnail);
extern CFURLRef QLPreviewCopyURLRepresentation(QLPreviewRef);
extern CFDictionaryRef QLPreviewCopyOptions(QLPreviewRef);
extern CFDictionaryRef QLPreviewCopyProperties(QLPreviewRef);
extern CFTypeRef QLPreviewGetPreviewType(QLPreviewRef); // eg. public.webcontent; public.text; public.image; public.pdf
extern void QLPreviewSetPreviewType(QLPreviewRef, CFStringRef);
//extern void QLPreviewSetForceContentTypeUTI(QLPreviewRef, CFStringRef);

int main (int argc, char *argv[]) {
	if (argc == 2 || argc == 3) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		CFURLRef inURL = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[1], strlen(argv[1]), false);
		if (inURL != NULL) {
			NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
			NSData *data = nil;
			id str = [[NSAttributedString alloc] initWithURL:(NSURL *)inURL options:nil documentAttributes:NULL error:&error];
			if (str == nil)
				str = [[PDFDocument alloc] initWithURL:(NSURL *)inURL];
			if (str == nil && &QLPreviewCreate != NULL) {
				QLPreviewRef p = QLPreviewCreate(NULL, inURL, NULL);
				if (p != NULL) {
					if (UTTypeConformsTo(QLPreviewGetPreviewType(p), kUTTypeText)) {
						NSData *rtf = (NSData *)QLPreviewCopyData(p);
						NSDictionary *prop = (NSDictionary *)QLPreviewCopyProperties(p);
						str = [[NSAttributedString alloc] initWithData:rtf options:prop documentAttributes:NULL error:&error];
						CFRelease(prop);
						[rtf release];
					}
					CFRelease(p);
				}
			}
			CFRelease(inURL);
			if (str != nil) {
				data = [[str string] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
				[str release];
			}
			if (data != nil) {
				if (argc == 3) {
					CFStringRef outPath = CFStringCreateWithFileSystemRepresentation(NULL, argv[2]);
					if (outPath && [data writeToFile:(NSString *)outPath atomically:NO]) {
						CFRelease(outPath);
						return 0;
					}
				} else {
					if (fwrite([data bytes], [data length], 1, stdout) == 1)
						return 0;
				}
				err(1, NULL);
			}
			fputs([[error localizedFailureReason] fileSystemRepresentation], stderr);
			putchar('\n');
		}
		[pool release];
		return 1;
	}
	fprintf(stderr, "usage:  %s <file> [<out>.txt]\n", argv[0]);
	return 1;
}
