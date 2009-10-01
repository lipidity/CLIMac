#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#if _10_6_PLUS
#import <QuickLook/QuickLook.h>
#import "QLPrivate.h"
#endif

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
#if _10_6_PLUS
		if (str == nil && &QLPreviewCreate != NULL) {
			QLPreviewRef p = QLPreviewCreate(NULL, (CFTypeRef)input, NULL);
			if (p != NULL) {
				CFStringRef bundle = QLPreviewGetDisplayBundleID(p);
				NSDictionary *prop = (NSDictionary *)QLPreviewCopyProperties(p) ? : [[NSDictionary alloc] init];
				fprintf(stderr, "QuickLook (%s)\n", [[(NSString *)bundle description] UTF8String]);
				if ([@"com.apple.qldisplay.Web" isEqualToString:(NSString *)bundle]) {
					input = (NSData *)QLPreviewCopyData(p);
					NSMutableDictionary *newProp = [prop mutableCopy];
					[newProp setObject:NSHTMLTextDocumentType forKey:NSDocumentTypeDocumentOption];
					[prop release];
					prop = newProp;
					str = [[NSAttributedString alloc] initWithData:input options:prop documentAttributes:NULL error:&error];
					[prop release];
				}
				CFRelease(p);
			}
		}
#endif
		if (str == nil) {
			if ([input isKindOfClass:[NSURL class]])
				str = [[PDFDocument alloc] initWithURL:input] ? : [[NSAttributedString alloc] initWithURL:input options:nil documentAttributes:NULL error:&error];
			else
				str = [[PDFDocument alloc] initWithData:input] ? : [[NSAttributedString alloc] initWithData:input options:nil documentAttributes:NULL error:&error];
			NSLog(@"str: %@", str);
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
