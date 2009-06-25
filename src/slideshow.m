#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface S : NSObject <IKSlideshowDataSource> {
	NSString *mode;
	NSDictionary *opts;
	NSArray *items;
}
- (id) init: (NSString *)mo : (NSDictionary *)op : (NSArray *)objs;
@end

static inline BOOL yesOrNo(const char *a) {
	return (a[0] == 'y' || a[0] == '1');
}

int main(int argc, char *argv[]) {
	[NSAutoreleasePool new];
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
				break;
		}
	}
	argc -= optind; argv += optind;

	if (argc == 0)
		errx(1, "No files to show");

	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *files = [[NSMutableArray alloc] initWithCapacity:argc];
	for (int i = 0; i < argc; i++)
		[files addObject:[fm stringWithFileSystemRepresentation:argv[i] length:strlen(argv[i])]];
	S *s = [[S allocWithZone:NULL] init:mode :opts :files];
	[opts release];
	[mode release];
	[files release];
	[[NSApplication sharedApplication] setDelegate:s];
	ProcessSerialNumber psn;
	GetCurrentProcess(&psn);
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);
	[NSApp run];
}

@implementation S

- (id) init: (NSString *)mo : (NSDictionary *)op : (NSArray *)objs {
	if ((self = [super init]) != nil) {
		mode = [mo copy];
		opts = [op copy];
		items = [objs copy];
	}
	return self;
}
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
