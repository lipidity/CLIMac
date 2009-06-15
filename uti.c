#import <CoreServices/CoreServices.h>
#import <getopt.h>

static inline void pS(CFStringRef str) {
	CFIndex len = CFStringGetMaximumSizeOfFileSystemRepresentation(str);
	char *buffer = alloca(len);
	if (CFStringGetFileSystemRepresentation(str, buffer, len))
		puts(buffer);
//	else
//		; // error
}

int main (int argc, const char * argv[]) {
	if (argc > 1) {
		// TODO: UTTypeCopyPreferredTagWithClass and UTTypeConformsTo and UTTypeEqual
		// SHOULD: allow -c on -lmOe
		// Return 1 if UTI not found; error messages
		static struct option longopts[] = {
			{ "all", no_argument, NULL, 'l' }, // show all (not just preferred)
			{ "mime", required_argument, NULL, 'm' },
			{ "OSType", required_argument, NULL, 'O' },
			{ "extension", required_argument, NULL, 'e' },
			{ "file", required_argument, NULL, 'f' },
			{ "where", required_argument, NULL, 'b' },
			{ "define", required_argument, NULL, 'd' },
//			{ "conforms", required_argument, NULL, 'c' },
//			{ "equals", required_argument, NULL, '=' },
			{ NULL, 0, NULL, 0 }
		};
		int c;
		CFStringRef arg = NULL;
		char action = 0;
		BOOL listAll = NO;
		while ((c = getopt_long(argc, (char **)argv, "lm:O:e:f:b:d:", longopts, NULL)) != EOF) {
			switch (c) {
				case 'm':
				case 'O':
				case 'e':
				case 'f':
				case 'b':
				case 'd':
					if (action != 0) {
						fputs("You may not specify more than one `-mOefbd' option", stderr);
						goto usage;
					} else {
						action = c;
						arg = CFStringCreateWithFileSystemRepresentation(NULL, optarg);
					}
					break;
				case 'l':
					listAll ^= 1;
					break;
				default:
					goto usage;
			}
		}
		argv += optind; argc -= optind;
		CFStringRef one = NULL;
		CFStringRef tag = NULL;
		switch (action) {
			case 'm':
				tag = kUTTagClassMIMEType;
				break;
			case 'O':
				tag = kUTTagClassOSType;
				break;
			case 'e':
				tag = kUTTagClassFilenameExtension;
				break;
			case 'f': {
				CFURLRef url = CFURLCreateWithFileSystemPath(NULL, arg, kCFURLPOSIXPathStyle, false);
				FSRef ref;
				CFURLGetFSRef(url, &ref); // chk
				LSCopyItemAttribute(&ref, kLSRolesNone, kLSItemContentType, (CFTypeRef *)&one); // chk
			} break;
			case 'b': {
				CFURLRef url = UTTypeCopyDeclaringBundleURL(arg);
				one = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
				CFRelease(url);
			} break;
			case 'd': {
				CFDictionaryRef dict = UTTypeCopyDeclaration(arg);
				one = CFCopyDescription(dict);
				CFRelease(dict);
			} break;
			default: {
				if (argc != 1)
					goto usage;
				arg = CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
				CFStringRef desc = UTTypeCopyDescription(arg);
				if (desc) {
					CFShow(desc);
					CFRelease(desc);
				} // chk properly
				return EX_OK;
			}
		}
		if (argc)
			goto usage;
		if (tag) {
			if (listAll) {
				CFArrayRef all = UTTypeCreateAllIdentifiersForTag(tag, arg, NULL); // chk; SHOULD: third argument
				CFIndex len = CFArrayGetCount(all);
				for (CFIndex i = 0; i < len; i++) {
					pS((CFStringRef)CFArrayGetValueAtIndex(all, i));
				}
				CFRelease(all);
			} else {
				one = UTTypeCreatePreferredIdentifierForTag(tag, arg, NULL); // chk
			}
		}
		if (one != NULL) {
			pS(one);
			CFRelease(one);
		} else {
			// error
		}
		return 0;
	} else {
usage:
		fprintf(stderr, "usage:  %s <UTI>...\n", getprogname());
		return 1;
	}
}
