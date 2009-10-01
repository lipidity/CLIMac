#import <Cocoa/Cocoa.h>

#define ENABLE_HELP 0

@interface S : NSObject
#if _10_6_PLUS
<NSApplicationDelegate, NSAlertDelegate>
#endif
{
@public
#if ENABLE_HELP
	id help;
#endif
	NSAlert *a;
} @end

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	const struct option longopts[] = {
		{ "style", required_argument, NULL, 's' },
#if ENABLE_HELP
		{ "help-file", required_argument, NULL, 'h' },
#endif
		{ "message", optional_argument, NULL, 'm' }, // from stdin if no arg
		{ "information", required_argument, NULL, 'i' },
		{ "icon", required_argument, NULL, 'I' },
#if _10_5_PLUS
		{ "supression-button", no_argument, NULL, 'p' },
#endif
		{ NULL, 0, NULL, 0 }
	};
	S *s = [S new];
	[[NSApplication sharedApplication] setDelegate:s];
	int c;
	NSAlert *alert = [NSAlert new];
	while ((c = getopt_long(argc, (char **)argv, "s:m::i:I:"
#if _10_5_PLUS
							"p"
#endif
#if ENABLE_HELP
							"h:"
#endif
							, longopts, NULL)) != EOF) { // #if ENABLE_HELP "h:" #endif
		switch (c) {
			case 's': {
				const char *styles[] = {"warn", "info", "critical"};
				for (size_t i = 0; i < sizeof(styles)/sizeof(styles[0]); i++) {
					if (strncasecmp(optarg, styles[i], strlen(styles[i])) == 0) {
						[alert setAlertStyle:i];
						break;
					}
				} // anything else ignored
			}
				break;
#if ENABLE_HELP
			case 'h': {
				[alert setShowsHelp:YES];
				if (optarg[0] == '@') {
					s->help = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *) optarg + 1, strlen(optarg + 1), false);
				} else if (optarg[0] == '<') {
					CFStringRef file = CFStringCreateWithFileSystemRepresentation(NULL, optarg + 1);
					if (file != NULL) {
						NSStringEncoding enc; NSError *error;
						s->help = [[NSString alloc] initWithContentsOfFile:(NSString *)file usedEncoding:&enc error:&error];
						CFRelease(file);
					}
				} else if (optarg[0] == '+') {
					CFStringRef anchor = CFStringCreateWithFileSystemRepresentation(NULL, optarg + 1);
					if (anchor != NULL) {
						[alert setHelpAnchor:(NSString *)anchor];
						CFRelease(anchor);
					}
				} else if (optarg[0] == '-' && optarg[1] == '\0') {
					s->help = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
				} else {
					s->help = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				}
			}
				break;
#endif
			case 'm': {
				CFStringRef msg = NULL;
				if (optarg != NULL)
					msg = CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				else
					msg = (CFStringRef)[[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
				if (msg != NULL) {
					NSUInteger len = [(NSString *)msg length];
					if (len != 0) {
						if ([[NSCharacterSet newlineCharacterSet] characterIsMember:[(NSString *)msg characterAtIndex:len-1]]) {
							CFStringRef tmp = msg;
							msg = CFRetain([(NSString *)msg substringToIndex:len-1]);
							CFRelease(tmp);
						}
					}
					[alert setMessageText:(NSString *)msg];
					CFRelease(msg);
				}
			}
				break;
			case 'i': {
				CFStringRef info = CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				if (info != NULL) {
					[alert setInformativeText:(NSString *)info];
					CFRelease(info);
				}
			}
				break;
			case 'I': {
				CFStringRef msg = CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				if (msg != NULL) {
					if (![(NSString *)msg isAbsolutePath]) {
						NSString *absPath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:(NSString *)msg];
						CFRelease(msg);
						msg = CFRetain(absPath);
					}
					NSImage *img = [NSImage imageNamed:(NSString *)msg];
					if (img == nil)
						img = [[[NSImage alloc] initWithContentsOfFile:(NSString *)msg] autorelease];
					if (img == nil)
						img = [[NSWorkspace sharedWorkspace] iconForFile:(NSString *)msg];
					[alert setIcon:img];
					CFRelease(msg);
				}
			}
				break;
#if _10_5_PLUS
			case 'p':
				[alert setShowsSuppressionButton:YES];
				break;
#endif
			default:
				fprintf(stderr, "usage:  %s [-m message] [-i info]"
#if ENABLE_HELP
						" [-h help]"
#endif
						" [-I icon] [-s warn|info|critical] buttons ...\n", argv[0]);
				return 1;
		}
	}
	argv += optind; argc -= optind;
	for (int i = 0; i < argc; i++) {
		CFStringRef msg = CFStringCreateWithFileSystemRepresentation(NULL, argv[i]);
		if (msg != NULL) {
			[alert addButtonWithTitle:(NSString *)msg];
			CFRelease(msg);
		}
	}
	s->a = alert;
	ProcessSerialNumber psn;
	if (!(GetCurrentProcess(&psn) == noErr && TransformProcessType(&psn, kProcessTransformToForegroundApplication) == noErr))
		warnx("Forced to run in background");
	[pool release];

	[NSApp run];
	return 1;
}

@implementation S
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
	[NSApp activateIgnoringOtherApps:YES];
	NSInteger ret = [a runModal];
#if _10_5_PLUS
	if ([[a suppressionButton] state] == NSOnState)
		fputs("suppress\n", stdout);
#endif
	exit((int)(ret ? ret - 1000 : 0));
}
#if ENABLE_HELP
- (BOOL) alertShowHelp:(NSAlert *)alert {
	NSLog(@"HELP!");
	if ([help isKindOfClass:[NSString class]])
		puts([help fileSystemRepresentation]);
	else if ([help isKindOfClass:[NSURL class]])
		[[NSWorkspace sharedWorkspace] openURL:help];
	else
		return NO;
	return YES;
}
#endif
@end
