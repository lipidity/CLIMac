#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QuickLook/QuickLook.h>

typedef void *QLPreviewRef;
extern QLPreviewRef QLPreviewCreate(void *unknownNULL, CFTypeRef item, CFDictionaryRef options);
extern CFDataRef QLPreviewCopyData(QLPreviewRef thumbnail);
extern CFURLRef QLPreviewCopyURLRepresentation(QLPreviewRef);
extern CFDictionaryRef QLPreviewCopyOptions(QLPreviewRef);
extern CFDictionaryRef QLPreviewCopyProperties(QLPreviewRef);
extern CFStringRef QLPreviewGetPreviewType(QLPreviewRef); // eg. public.webcontent; public.text; public.image; public.pdf
extern void QLPreviewSetPreviewType(QLPreviewRef, CFStringRef);
//extern void QLPreviewSetForceContentTypeUTI(QLPreviewRef, CFStringRef);

int main (int argc, char *argv[]) {
	if (argc == 2 || argc == 3) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		id input = nil;
		id str = nil;
		NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
		NSData *data = nil;
		if (strcmp(argv[1], "-") == 0)
			input = [[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] retain];
		else
			input = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[1], strlen(argv[1]), false);
		if (str == nil && &QLPreviewCreate != NULL) {
			QLPreviewRef p = QLPreviewCreate(NULL, (CFTypeRef)input, NULL);
			if (p != NULL) {
				QLPreviewSetPreviewType(p, kUTTypeText);
				CFStringRef type = QLPreviewGetPreviewType(p);
				if (UTTypeConformsTo(type, kUTTypeText) || [@"public.webcontent" isEqualToString:(NSString *)type]) {
					NSData *rtf = (NSData *)QLPreviewCopyData(p);
					NSDictionary *prop = (NSDictionary *)QLPreviewCopyProperties(p) ? : [[NSDictionary alloc] init];
					if ([@"public.webcontent" isEqualToString:(NSString *)type]) {
						NSMutableDictionary *newProp = [prop mutableCopy];
						[newProp setObject:NSHTMLTextDocumentType forKey:NSDocumentTypeDocumentOption];
						[prop release];
						prop = newProp;
					}
					str = [[NSAttributedString alloc] initWithData:rtf options:prop documentAttributes:NULL error:&error];
					if (prop)
						CFRelease(prop);
					[rtf release];
				}
				CFRelease(p);
			}
		}
		if (str == nil) {
			if ([input isKindOfClass:[NSURL class]])
				str = [[NSAttributedString alloc] initWithURL:input options:nil documentAttributes:NULL error:&error] ? : [[PDFDocument alloc] initWithURL:input];
			else
				str = [[NSAttributedString alloc] initWithData:input options:nil documentAttributes:NULL error:&error] ? : [[PDFDocument alloc] initWithData:input];
		}
		[input release];
		if (str != nil) {
			data = [[str string] dataUsingEncoding:NSUTF8StringEncoding];
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
		[pool release];
		return 1;
	}
	fprintf(stderr, "usage:  %s <file> [<out>.txt]\n", argv[0]);
	return 1;
}
