#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface S : NSObject <IKSlideshowDataSource> {
	NSString *mode;
	NSDictionary *opts;
	NSArray *items;
}
- (id) init: (NSString *)mo : (NSDictionary *)op : (NSArray *)objs;
@end

int main(int argc, char *argv[]) {
	[NSAutoreleasePool new];
	struct option longopts[] = {
		{ "mode", no_argument, NULL, 'm' },
		{ "wrap-around", no_argument, NULL, 'w' },
		{ "start-paused", no_argument, NULL, 'p' },
		{ "start-index", required_argument, NULL, 'i' },
		{ "pdf-box", required_argument, NULL, 'x' },
		{ "pdf-display-mode", required_argument, NULL, 'd' },
		{ "pdf-display-book", no_argument, NULL, 'b' },
		{ NULL, 0, NULL, 0 }
	};
	NSString *mode = IKSlideshowModePDF;
	NSMutableDictionary *opts = [[NSMutableDictionary alloc] init];
	int c;
	while ((c = getopt_long(argc, argv, "wpi:x:m:b", longopts, NULL)) != EOF) {
		switch (c) {
			case 'w': {
				NSNumber *n = [[NSNumber alloc] initWithBool:(![opts objectForKey:IKSlideshowWrapAround])];
				[opts setObject:n forKey:IKSlideshowWrapAround];
				[n release];
			}	break;
			case 'p': {
				NSNumber *n = [[NSNumber alloc] initWithBool:(![opts objectForKey:IKSlideshowStartPaused])];
				[opts setObject:n forKey:IKSlideshowStartPaused];
				[n release];
			}	break;
			case 'i': {
				NSNumber *n = [[NSNumber alloc] initWithUnsignedLong:strtoul(optarg, NULL, 0)];
				[opts setObject:n forKey:IKSlideshowStartIndex];
				[n release];
			}	break;
			case 'x': {
				const char *a[] = {"media", "crop", "bleed", "trim", "art"};
				PDFDisplayBox boxType = 0;
				do {
					if (strcasecmp(a[boxType], optarg) == 0)
						break;
					boxType += 1;
				} while (boxType < sizeof(a)/sizeof(a[0]));
				if (boxType < sizeof(a)/sizeof(a[0])) {
					NSNumber *n = [[NSNumber alloc] initWithInteger:boxType];
					[opts setObject:n forKey:IKSlideshowPDFDisplayBox];
					[n release];
				} else {
					fprintf(stderr, "Invalid argument '%s' to -x option\nValid options are %s", optarg, a[0]);
					for (int i = 1; i < sizeof(a)/sizeof(a[0]); i++)
						fprintf(stderr, ", %s", a[i]);
					fputc('\n', stderr);
					return 1;
				}
			}	break;
			case 'm': {
				const char *a[] = {"single", "single-c", "twoup", "twoup-c"};
				PDFDisplayMode modeType = 0;
				do {
					if (strcasecmp(a[modeType], optarg) == 0)
						break;
					modeType += 1;
				} while (modeType < sizeof(a)/sizeof(a[0]));
				if (modeType < sizeof(a)/sizeof(a[0])) {
					NSNumber *n = [[NSNumber alloc] initWithInteger:modeType];
					[opts setObject:n forKey:IKSlideshowPDFDisplayBox];
					[n release];
				} else {
					fprintf(stderr, "Invalid argument '%s' to -m option\nValid options are %s", optarg, a[0]);
					for (int i = 1; i < sizeof(a)/sizeof(a[0]); i++)
						fprintf(stderr, ", %s", a[i]);
					fputc('\n', stderr);
					return 1;
				}
			}	break;
			default:
				break;
		}
	}
	argc -= optind; argv += optind;

	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *files = [[NSMutableArray alloc] initWithCapacity:argc];
	for (int i = 0; i < argc; i++) {
		[files addObject:[fm stringWithFileSystemRepresentation:argv[0] length:strlen(argv[0])]];
	}
	[IKSlideshow sharedSlideshow];
	S *s = [[S alloc] init:mode :opts :files];
	[opts release];
	[mode release];
	[files release];
	[[NSApplication sharedApplication] setDelegate:s];
	[NSApp finishLaunching];
//	[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantPast]];
	while (1) {
		NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
		if (event)
			[NSApp sendEvent:event];
	}
//	[NSApp run];
	return 0;
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

- (void) applicationDidFinishLaunching: (NSNotification *)aNotification {
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
