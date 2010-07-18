/*
 * Play a sound, or system beep
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Cocoa/Cocoa.h>

#import "climac.h"

static void usage(FILE *outfile);

@interface S : NSObject <NSSoundDelegate> {
@public
	NSSound *s;
}
- (void) fire:(NSTimer *)timer;
- (void) sound:(NSSound *)sound didFinishPlaying:(BOOL)success;
@end

int main(int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ "volume", required_argument, NULL, 'v' },
		{ "loop", no_argument, NULL, 'l' },
		{ "delay", required_argument, NULL, 'd' },
		{ NULL, 0, NULL, 0 }
	};
	NSString *whichSnd = nil;
	int c;
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	bool volume_set = 0;
	bool loop = 0;
	float volume = 0.0f;
	double delay = 0.0;
	while ((c = getopt_long_only(argc, argv, "hVv:ld:", longopts, NULL)) != EOF) {
		switch (c) {
		case 'v':
			volume_set = 1;
			volume = strtof(optarg, NULL);
			break;
		case 'l':
			loop = 1;
			break;
		case 'd':
			delay = strtod(optarg, NULL);
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
	if (argc == 1) {
		whichSnd = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:argv[0] length:strlen(argv[0])];
	} else if (argc != 0) {
		usage(stderr);
		exit(RET_USAGE);
	}

	NSArray *keys = [[NSArray alloc] initWithObjects:@"com.apple.sound.beep.sound", @"com.apple.sound.beep.volume", nil];
	NSDictionary *dict = (NSDictionary *)CFPreferencesCopyMultiple((CFArrayRef)keys, CFSTR("com.apple.systemsound"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost); // leak
	if (dict != nil) {
		if (whichSnd == nil)
			if ((whichSnd = [dict objectForKey:@"com.apple.sound.beep.sound"]) == nil)
				errx(RET_ERROR, "sound not found");
		if (!volume_set) {
			id num = [dict objectForKey:@"com.apple.sound.beep.volume"];
			if (num != nil) {
				volume = [num floatValue];
				volume_set = 1;
			}
		}
		CFRelease(dict);
	}
	[keys release];

	S *s = [S new];
	s->s = [NSSound soundNamed:whichSnd] ? : [[NSSound alloc] initWithContentsOfFile:whichSnd byReference:YES];
	[pool release];
	[NSAutoreleasePool new];
	if (s->s != nil) {
		if (volume_set)
			[s->s setVolume:volume];
		if (loop) {
			[NSTimer scheduledTimerWithTimeInterval:delay target:s selector:@selector(fire:) userInfo:nil repeats:YES];
		} else {
			[s->s setDelegate:s];
			[NSTimer scheduledTimerWithTimeInterval:delay target:s selector:@selector(fire:) userInfo:nil repeats:NO];
		}
		[[NSRunLoop currentRunLoop] run];
	}
	return RET_ERROR;
}

static void usage(FILE *outfile) {
	fprintf(outfile, "Usage: %s [options] [<sound>]\nOptions:\n"
			"--loop/-l\n"
			"--delay/-d <delay>\n"
			"--volume/-v <volume>\n", getprogname());
}

@implementation S
- (void) fire:(NSTimer *) __unused t {
	[s play];
}
- (void) sound:(NSSound *) __unused sound didFinishPlaying:(BOOL)success {
	exit(!success);
}
@end
