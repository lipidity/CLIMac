/*
 * Display an alert dialog
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Cocoa/Cocoa.h>

#import "climac.h"

@interface S : NSObject <NSApplicationDelegate> {
	@public NSAlert *a;
} - (void) applicationDidFinishLaunching:(NSNotification *)aNotification __attribute((noreturn)); @end

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ "style", required_argument, NULL, 's' },
		{ "message", required_argument, NULL, 'm' },
		{ "information", required_argument, NULL, 'i' },
		{ "icon", required_argument, NULL, 'I' },
		{ "supression-button", no_argument, NULL, 'p' },
		{ NULL, 0, NULL, 0 }
	};
	S *s = [S new];
	[[NSApplication sharedApplication] setDelegate:s];
	int c;
	NSAlert *alert = [NSAlert new];
	while ((c = getopt_long(argc, argv, "hVs:m:i:I:p", longopts, NULL)) != EOF) {
		switch (c) {
			case 's': {
				const char *styles[] = {"warn", "info", "critical"};
				for (size_t i = 0; i < sizeof(styles)/sizeof(styles[0]); i++) {
					if (strncasecmp(optarg, styles[i], strlen(styles[i])) == 0) {
						[alert setAlertStyle:i];
						goto end;
					}
				}
				errx(RET_USAGE, "Style should be one of 'warn', 'info' or 'critical'");
			}
				break;
			case 'm': {
				CFStringRef msg = NULL;
				if (optarg != NULL)
					msg = CFStringCreateWithFileSystemRepresentation(NULL, optarg);
//				else
//					msg = (CFStringRef)[[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
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
			case 'p':
				[alert setShowsSuppressionButton:YES];
				break;
			case 'V':
				climac_version_info();
				exit(RET_SUCCESS);
			case 'h':
			default:
				fprintf(stderr, "usage:  %s [-m message] [-i info] [-I icon] [-s warn|info|critical] buttons ...\n", argv[0]);
				exit(c != 'h' ? RET_USAGE : RET_SUCCESS);
			end:;
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
	if (![NSApp setActivationPolicy:NSApplicationActivationPolicyRegular])
		fputs("Forced to run in background.\n", stderr);
	[pool release];

	[NSApp run];
	exit(RET_FAILURE);
}

@implementation S
- (void) applicationDidFinishLaunching:(NSNotification *) __attribute((unused)) aNotification {
	[NSApp activateIgnoringOtherApps:YES];
	NSInteger ret = [a runModal];
	if ([[a suppressionButton] state] == NSOnState)
		fputs("suppress\n", stdout);
	exit((int)(ret ? ret - 1000 : 0));
}
@end
