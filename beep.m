#import <Cocoa/Cocoa.h>

@interface S : NSObject {} @end

int main(int argc, char *argv[]) {
#if 1
	const struct option longopts[] = {
		{ "sound", required_argument, NULL, 's' },
		{ "volume", required_argument, NULL, 'v' },
		{ "loop", no_argument, NULL, 'l' },
		{ NULL, 0, NULL, 0 }
	};
	BOOL setS = 0, setV = 0;
	BOOL loop = NO;
	NSString *whichSnd = nil;
	float volume = 1.0f;
	int c;
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	while ((c = getopt_long_only(argc, argv, "s:v:l", longopts, NULL)) != EOF) {
		switch (c) {
			case 's':
				setS = 1;
				whichSnd = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:optarg length:strlen(optarg)];
				break;
			case 'v': {
				setV = 1;
				volume = strtof(optarg, NULL);
			}	break;
			case 'l': {
				loop ^= 1;
			}	break;
			default:
				break;
		}
	}
	NSArray *keys = [[NSArray alloc] initWithObjects:@"com.apple.sound.beep.sound", @"com.apple.sound.beep.volume", nil];
	NSDictionary *dict = (NSDictionary *)CFPreferencesCopyMultiple((CFArrayRef)keys, CFSTR("com.apple.systemsound"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (!setS) {
		whichSnd = [dict objectForKey:@"com.apple.sound.beep.sound"];
	}
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
	return 1;
#else
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSString *whichSnd = nil;
	float volume = 1.0f;
	if (argc == 2) {
		whichSnd = [(NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[1]) autorelease];
	}
	if (whichSnd == nil) {
		NSArray *keys = [[NSArray alloc] initWithObjects:@"com.apple.sound.beep.sound", @"com.apple.sound.beep.volume", nil];
		NSDictionary *dict = (NSDictionary *)CFPreferencesCopyMultiple((CFArrayRef)keys, CFSTR("com.apple.systemsound"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
		if (dict != nil) {
			whichSnd = [dict objectForKey:@"com.apple.sound.beep.sound"];
			id num = [dict objectForKey:@"com.apple.sound.beep.volume"];
			if (num)
				volume = [num floatValue];
			CFRelease(dict);
		}
		[keys release];
	}
	NSSound *sound = [NSSound soundNamed:whichSnd] ? : [[NSSound alloc] initWithContentsOfFile:whichSnd byReference:YES];
	[pool release];
	if (sound != nil) {
		[sound setVolume:volume];
		[sound setDelegate:[[S allocWithZone:NULL] init]];
		[sound play];
		[[NSRunLoop currentRunLoop] run];
	}
	return 1;
#endif
}

@implementation S
- (void) sound:(NSSound *)s didFinishPlaying:(BOOL)success {
	exit(!success);
}
@end
