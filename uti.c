#import <CoreServices/CoreServices.h>
#import <getopt.h>

static inline void pS(CFStringRef str) {
	CFIndex len = CFStringGetMaximumSizeOfFileSystemRepresentation(str);
	char *buffer = malloc(len);
	if (CFStringGetFileSystemRepresentation(str, buffer, len))
		puts(buffer);
//	else
//		; // error
	free(buffer);
}

int main (int argc, const char * argv[]) {
	if (argc > 1) {
		// TODO: UTTypeCopyPreferredTagWithClass and UTTypeConformsTo and UTTypeEqual
		// SHOULD: allow -c on -lmOe
		// Return 1 if UTI not found; error messages
		static const struct option longopts[] = {
			{ "all", no_argument, NULL, 'l' }, // show all (not just preferred)
			{ "mime", required_argument, NULL, 'm' },
			{ "OSType", required_argument, NULL, 'O' },
			{ "extension", required_argument, NULL, 'e' },
			{ "describe", required_argument, NULL, 'i' },
			{ "locate", required_argument, NULL, 'b' },
			{ "define", required_argument, NULL, 'd' },
//			{ "conforms", required_argument, NULL, 'c' },
//			{ "equals", required_argument, NULL, '=' },
			{ NULL, 0, NULL, 0 }
		};
		int c;
		CFStringRef arg = NULL;
		char action = 0;
		BOOL listAll = NO;
		while ((c = getopt_long(argc, (char **)argv, "lm:O:e:i:b:d:", longopts, NULL)) != EOF) {
			switch (c) {
				case 'm':
				case 'O':
				case 'e':
				case 'i':
				case 'b':
				case 'd':
					if (action != 0) {
						fputs("You may not specify more than one `-mOeibd' option", stderr);
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
		if (argc != optind && argc != 2)
			goto usage;
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
			case 'i': {
				CFStringRef desc = UTTypeCopyDescription(arg);
				if (desc) {
					CFShow(desc);
					CFRelease(desc);
				} // chk properly
				return EX_OK;
			} break;
			case 'b': {
				CFURLRef url = UTTypeCopyDeclaringBundleURL(arg);
				if (url) {
					one = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
					CFRelease(url);
				}
			} break;
			case 'd': {
				CFDictionaryRef dict = UTTypeCopyDeclaration(arg);
				if (dict) {
					one = CFCopyDescription(dict);
					CFRelease(dict);
				}
			} break;
			default: {
				arg = CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
				CFURLRef url = CFURLCreateWithFileSystemPath(NULL, arg, kCFURLPOSIXPathStyle, false);
				if (url) {
					FSRef ref = {{0}};
					CFURLGetFSRef(url, &ref); // chk
					LSCopyItemAttribute(&ref, kLSRolesNone, kLSItemContentType, (CFTypeRef *)&one); // chk
				}
			}
		}
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
			return 0;
		} else {
			return 1;
		}
	} else {
usage:
		fprintf(stderr, "usage:  %s <file>\n", argv[0]);
		return 1;
	}
}
