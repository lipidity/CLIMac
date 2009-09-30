#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface S : NSObject <IKSlideshowDataSource
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6
, NSApplicationDelegate
#endif
> {
@public
	NSString *mode;
	NSDictionary *opts;
	NSArray *items;
}
@end

static inline BOOL yesOrNo(const char *a) {
	return (a[0] == 'y' || a[0] == '1');
}

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	struct option longopts[] = {
		{ "pdf", no_argument, NULL, 'p' },
		{ "quick-look", no_argument, NULL, 'q' },
		{ "images", no_argument, NULL, 'i' },
		{ "wrap-around", required_argument, NULL, 'w' },
		{ "start-paused", required_argument, NULL, 'u' },
		{ "start-index", required_argument, NULL, 's' },
		{ NULL, 0, NULL, 0 }
	};
	NSString *mode = IKSlideshowModeOther;
	NSMutableDictionary *opts = [[NSMutableDictionary alloc] init];
	int c;
	while ((c = getopt_long_only(argc, argv, "pqiw", longopts, NULL)) != EOF) {
		switch (c) {
			case 'p':
				mode = IKSlideshowModePDF;
				break;
			case 'q':
				mode = IKSlideshowModeOther;
				break;
			case 'i':
				mode = IKSlideshowModeImages;
				break;
			case 'w': {
				NSNumber *n = [[NSNumber alloc] initWithBool:yesOrNo(optarg)];
				[opts setObject:n forKey:IKSlideshowWrapAround];
				[n release];
			}	break;
			case 'u': {
				NSNumber *n = [[NSNumber alloc] initWithBool:yesOrNo(optarg)];
				[opts setObject:n forKey:IKSlideshowStartPaused];
				[n release];
			}	break;
			case 's': {
				NSNumber *n = [[NSNumber alloc] initWithUnsignedLong:strtoul(optarg, NULL, 0)];
				[opts setObject:n forKey:IKSlideshowStartIndex];
				[n release];
			}	break;
			default:
				goto usage;
				break;
		}
	}
	argc -= optind;
	if (argc == 0) {
		warnx("No files to show");
usage:
		fprintf(stderr, "usage:  %s [-p | -q | -i] <file>...\n", argv[0]);
	}
	argv += optind;

	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *files = [[NSMutableArray alloc] initWithCapacity:argc];
	for (int i = 0; i < argc; i++)
		[files addObject:[fm stringWithFileSystemRepresentation:argv[i] length:strlen(argv[i])]];
	S *s = [[S allocWithZone:NULL] init];
	s->mode = mode;
	s->opts=opts;
	s->items = files;
	[[NSApplication sharedApplication] setDelegate:s];

	ProcessSerialNumber psn;
	if (!(GetCurrentProcess(&psn) == noErr && TransformProcessType(&psn, kProcessTransformToForegroundApplication) == noErr))
		warnx("Forced to run in background");

	[pool release];
	[NSApp run];
}

@implementation S
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return YES; }
- (void) applicationDidFinishLaunching: (NSNotification *)aNotification {
	[NSApp activateIgnoringOtherApps:YES];
	[[IKSlideshow sharedSlideshow] runSlideshowWithDataSource:self inMode:mode options:opts];
	[mode release];
	[opts release];
}

- (NSString*)nameOfSlideshowItemAtIndex: (NSUInteger)idx; {
	return [[[items objectAtIndex:idx] lastPathComponent] stringByDeletingPathExtension];
}

- (NSUInteger) numberOfSlideshowItems; {
	return [items count];
}

- (id) slideshowItemAtIndex: (NSUInteger)idx; {
	return [items objectAtIndex:idx];
}

- (void) dealloc {
	[items release];
	[super dealloc];
}

@end
