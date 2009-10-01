#if _10_4

// need to have Slideshow.h from iMac

#import <Cocoa/Cocoa.h>

static id r;

@interface S : NSObject {} @end
@implementation S
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return YES; }
- (int)numberOfObjectsInSlideshow { return [r count]; }
- (id)slideshowObjectAtIndex:(int)i { return [r objectAtIndex:i]; }
//- (NSString *)slideshowObjectNameAtIndex:(int)i { return [[[r objectAtIndex:i] lastPathComponent] stringByDeletingPathExtension]; }
@end

int main(int argc, const char *argv[]) {
	if(argc == 1) {
	usage:
		fprintf(stderr, "Usage:  %s\n"
				"\t[-s <start-idx>] [-d <delay>] <files>...\n"
				"\t-p <pdf-file>\n", argv[0]);
		return 1;
	}
	int c; opterr = 0; float d = 2.0f; int s = 0;
	while((c = getopt(argc, (char**)argv, "d:s:p")) != EOF) {
		switch(c) {
			case 'd': d = strtof(optarg, NULL); break;
			case 's': s = (int)strtol(optarg, NULL, 10)-1; break;
			case 'p': s = -1; break;
			default: goto usage;
		}
	}
	argc -= optind; argv += optind;
	
	[[NSAutoreleasePool alloc] init];
	Slideshow *l = [Slideshow sharedSlideshow];
	S *h = [[S alloc] init];
	NSDictionary *opt = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:s], @"startIndex", [NSNumber numberWithFloat:d], @"autoPlayDelay", nil];
	r = [[NSMutableArray alloc] init];
	if(s >= 0) {
		if(argc) {
			int i = 0;
			while(i < argc) {
				NSString *aStr = NSTR(argv[i++]);
				[r addObject:aStr];
				[aStr release];
			}
		} else {
			goto usage;
		}
		r = [r pathsMatchingExtensions:[NSImage imageFileTypes]];
		if(![r count]) // error message?
			return 2;
		[l runSlideshowWithDataSource:h options:opt];
	} else {
		NSURL *u = NURL(argv[0], 0);
		if(u)
			[l runSlideshowWithPDF:u options:opt];
		else
			return 2;
	}
	[[NSApplication sharedApplication] setDelegate:h];
	[NSApp run];
	return 0;
}

#else // !_10_4

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface S : NSObject <IKSlideshowDataSource
#if _10_6_PLUS
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

#endif // !_10_4