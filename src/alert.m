#import <Cocoa/Cocoa.h>

#define HELP_NOT_WORKING 1

@interface S : NSObject {
#ifndef HELP_NOT_WORKING
	id help;
#endif
	NSAlert *a;
} @end

// Message should be just typed without an option flag

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	const struct option longopts[] = {
		{ "style", required_argument, NULL, 's' },
#ifndef HELP_NOT_WORKING
		{ "help-file", required_argument, NULL, 'h' },
#endif
		{ "message", required_argument, NULL, 'm' },
		{ "information", required_argument, NULL, 'i' },
		{ "icon", required_argument, NULL, 'b' },
		{ "supression-button", no_argument, NULL, 'p' },
		{ NULL, 0, NULL, 0 }
	};
	S *s = [S new];
	[[NSApplication sharedApplication] setDelegate:s];
	int c;
	NSAlert *alert = [NSAlert new];
	while ((c = getopt_long(argc, (char **)argv, "s:m:i:b:p", longopts, NULL)) != EOF) { // #ifndef HELP_NOT_WORKING "h:" #endif
		switch (c) {
			case 's': {
				const char *styles[] = {"warn", "info", "critical"};
				for (size_t i = 0; i < sizeof(styles)/sizeof(styles[0]); i++) {
					if (strncasecmp(optarg, styles[i], strlen(styles[i])) == 0) {
						[alert setAlertStyle:i];
						break;
					}
				}
			}
				break;
#ifndef HELP_NOT_WORKING
			case 'h': {
				[alert setShowsHelp:YES];
				if (optarg[0] == '@') {
					((struct {@defs(S)} *)s)->help = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *) optarg + 1, strlen(optarg + 1), false);
				} else if (optarg[0] == '<') {
					CFStringRef file = CFStringCreateWithFileSystemRepresentation(NULL, optarg + 1);
					if (file != NULL) {
						NSStringEncoding enc; NSError *error;
						((struct {@defs(S)} *)s)->help = [[NSString alloc] initWithContentsOfFile:(NSString *)file usedEncoding:&enc error:&error];
						CFRelease(file);
					}
				} else if (optarg[0] == '+') {
					CFStringRef anchor = CFStringCreateWithFileSystemRepresentation(NULL, optarg + 1);
					if (anchor != NULL) {
						[alert setHelpAnchor:(NSString *)anchor];
						CFRelease(anchor);
					}
				} else if (optarg[0] == '-' && optarg[1] == '\0') {
					((struct {@defs(S)} *)s)->help = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
				} else {
					((struct {@defs(S)} *)s)->help = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				}
			}
				break;
#endif
			case 'm': {
				CFStringRef msg = CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				if (msg != NULL) {
					[alert setMessageText:(NSString *)msg];
					CFRelease(msg);
				}
			}
				break;
			case 'i': {
				CFStringRef msg = CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				if (msg != NULL) {
					[alert setInformativeText:(NSString *)msg];
					CFRelease(msg);
				}
			}
				break;
			case 'b': {
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
			case 'p':
				[alert setShowsSuppressionButton:YES];
				break;
			default:
				fprintf(stderr, "usage:  %s [-m message] [-i info] [-h help] [-b icon] [-s style] buttons ...\n", argv[0]);
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
	((struct {@defs(S)} *)s)->a = alert;
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
	if ([[a suppressionButton] state] == NSOnState)
		fputs("suppress", stdout);
	exit(ret ? ret - 1000 : 0);
}
#ifndef HELP_NOT_WORKING
- (BOOL)alertShowHelp:(NSAlert *)alert {
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
