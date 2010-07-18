#import <err.h>
#import <getopt.h>
#import <stdio.h>

#define UTIL_VERSION 0
#import "version.h"
#import "ret_codes.h"

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QuickLook/QuickLook.h>
#import "QLPrivate.h"

// see how delicious library is using ql

static inline void usage(FILE *errfile) {
	fprintf(errfile, "usage:  %s [-f <txt|rtf|>] [-o <output>] {-s | <file>}\n", getprogname());
}

static inline id ql(CFURLRef file) {
	NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
	id str = nil;
	QLPreviewRef p = QLPreviewCreate(NULL, file, NULL);
	if (p != NULL) {
		NSData *result = nil;
		NSDictionary *prop = [[NSDictionary alloc] init];
		CFStringRef bundle = QLPreviewGetDisplayBundleID(p);
		if (bundle != NULL) {
			id nprop = (NSDictionary *)QLPreviewCopyProperties(p);
			[prop release];
			prop = nprop;
			fprintf(stderr, "QuickLook (%s)\n", [[(NSString *)bundle description] UTF8String]); // todo comment
			if ([@"com.apple.qldisplay.Web" isEqualToString:(NSString *)bundle]) {
				result = (NSData *)QLPreviewCopyData(p);
//				[webresource initWithDat];
//				[result writeToFile:@"/tmp/any2txt.out" atomically:NO];
				// save it as multipart (mb webarchive) if has attachments
				NSMutableDictionary *newProp = [prop mutableCopy];
				[newProp setObject:NSHTMLTextDocumentType forKey:NSDocumentTypeDocumentOption];
				[prop release];
				prop = newProp;
			}
		}
		NSLog(@"%@", prop);
		if (result != nil)
			str = [[NSAttributedString alloc] initWithData:result options:prop documentAttributes:NULL error:&error];
		[prop release];
		CFRelease(p);
	}
	return str;
}

int main (int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "uti", no_argument, NULL, 't' },

		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },
		{ NULL, 0, NULL, 0 }
	};
	NSData *data = nil;
	NSURL *outURL = nil;
	NSDictionary *atstr_opts = nil;
	BOOL read_stdin = 0;
	int c;
	while ((c = getopt_long(argc, argv, "hVt:svo:", longopts, NULL)) != EOF) {
		switch (c) {
			case 't': {
				NSString *s = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				atstr_opts = [[NSDictionary alloc] initWithObjectsAndKeys:s, NSFileTypeDocumentOption, nil];
				[s release];
			}	break;
			case 's':
				read_stdin ^= 1;
				break;
			case 'v':
				break;
			case 'o':
				outURL = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)optarg, strlen(optarg), false);
				break;
			case 'V':
				climac_version_info();
				exit(RET_SUCCESS);
			case 'h':
				usage(stdout);
				exit(RET_SUCCESS);
			default:
				usage(stderr);
				exit(RET_USAGE);
		}
	}
	argc -= optind; argv += optind;

	NSAutoreleasePool *pool = [NSAutoreleasePool new];
#if 0
	NSDictionary *uti_map = [[NSDictionary alloc] initWithObjectsAndKeys:
							 NSPlainTextDocumentType, @"public.plain-text",
							 NSRTFTextDocumentType, @"public.rtf",
							 NSRTFDTextDocumentType, @"com.apple.rtfd",
							 NSMacSimpleTextDocumentType, @"com.apple.traditional-mac-plain-text",
							 NSHTMLTextDocumentType, @"public.html",
							 NSDocFormatTextDocumentType, @"com.microsoft.word.doc",
							 NSWordMLTextDocumentType, @"org.openxmlformats.wordprocessingml.document",
							 NSWebArchiveTextDocumentType, @"com.apple.webarchive",
							 NSOfficeOpenXMLTextDocumentType, @"org.openxmlformats.wordprocessingml.document",
							 NSOpenDocumentTextDocumentType, @"org.oasis-open.opendocument.text",
							 nil];
#endif
	id input = nil;
	id str = nil;

	NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];

	if (read_stdin && argc == 0) {
		input = [[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] retain];
		if (input != nil) {
			str = [[PDFDocument alloc] initWithData:input];
			// can't use ql -- needs URL
			if (str == nil)
				str = [[NSAttributedString alloc] initWithData:input options:atstr_opts documentAttributes:NULL error:&error];
		}
	} else if (!read_stdin && argc == 1) {
		input = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[0], strlen(argv[0]), false);
		if (input != NULL) {
			str = [[PDFDocument alloc] initWithURL:input];
			if (str == nil)
				str = ql((CFURLRef)input);
			if (str == nil)
				str = [[NSAttributedString alloc] initWithURL:input options:atstr_opts documentAttributes:NULL error:&error];
		}
	} else {
		usage(stderr);
		exit(RET_USAGE);
	}
	if (atstr_opts != nil)
		[atstr_opts release];
//	NSLog(@"%@", [str string]);

	[input release];
	if (str != nil) {
		data = [[str string] dataUsingEncoding:NSUTF8StringEncoding];
		[str release];
	}
	if (data != nil) {
		if (outURL != nil) {
			if ([data writeToURL:outURL atomically:NO]) {
				[outURL release];
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
	exit(RET_SUCCESS);
}
