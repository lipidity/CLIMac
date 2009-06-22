#import <Cocoa/Cocoa.h>

@interface S : NSObject {} @end

int main(int argc, char *argv[]) {
	[NSAutoreleasePool new];
	[[NSApplication sharedApplication] setDelegate:[S new]];
	[NSApp finishLaunching];
	while (1) {
		NSEvent *e = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
		if (e)
			[NSApp sendEvent:e];
	}
#if 0
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "volume", required_argument, NULL, 'v' },
		{ "loop", no_argument, NULL, 'l' },
		{ NULL, 0, NULL, 0 }
	};
	BOOL setV = 0;
	BOOL loop = NO;
	NSString *whichSnd = nil;
	float volume = 1.0f;
	int c;
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	while ((c = getopt_long_only(argc, argv, "v:lh", longopts, NULL)) != EOF) {
		switch (c) {
			case 'v': {
				setV = 1;
				volume = strtof(optarg, NULL);
			}	break;
			case 'l': {
				loop ^= 1;
			}	break;
			case 'h':
			default:
usage:
				fprintf(stderr, "usage:  %s [-l] [-s <sound>] [-v <volume>]\n", argv[0]);
				return c != 'h';
		}
	}
	argc -= optind; argv += optind;
	if (argc == 1) {
		whichSnd = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:argv[0] length:strlen(argv[0])];
	} else if (argc != 0) {
		goto usage;
	}
	NSArray *keys = [[NSArray alloc] initWithObjects:@"com.apple.sound.beep.sound", @"com.apple.sound.beep.volume", nil];
	NSDictionary *dict = (NSDictionary *)CFPreferencesCopyMultiple((CFArrayRef)keys, CFSTR("com.apple.systemsound"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (whichSnd == nil)
		whichSnd = [dict objectForKey:@"com.apple.sound.beep.sound"];
	if (!setV) {
		id num = [dict objectForKey:@"com.apple.sound.beep.volume"];
		if (num)
			volume = [num floatValue];
	}
	NSSound *sound = [NSSound soundNamed:whichSnd] ? : [[NSSound alloc] initWithContentsOfFile:whichSnd byReference:YES];
	[pool release];
	if (sound != nil) {
		[sound setVolume:volume];
		[sound setLoops:loop];
		[sound setDelegate:[[S allocWithZone:NULL] init]];
		[sound play];
		[[NSRunLoop currentRunLoop] run];
	}
#endif
	return 1;
}

@implementation S
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
	[NSApp activateIgnoringOtherApps:YES];
	NSAlert *a = [NSAlert alertWithMessageText:@"hello" defaultButton:@"OK" alternateButton:@"alt" otherButton:@"other" informativeTextWithFormat:@"info"];
	[a runModal];
	exit(0);
}
@end
