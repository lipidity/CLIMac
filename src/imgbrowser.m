#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "../build/etc/imgbrowser/menu.h"

@interface IKImageBrowserView (IKPrivate) - (void)setCellsHaveTitle:(BOOL)a; @end
@interface I : NSObject { @public NSString *u, *t; } @end
@interface S : NSObject
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6
<NSApplicationDelegate>
#endif
{ IKImageBrowserView *b; NSUInteger x; @public NSMutableArray *items; NSMutableArray *his; }
-(void)addFromDir:(NSString*)path; -(void)addFromDir:(NSString*)path :(BOOL)upd;
- (void)up:(id)sender; - (void)down:(id)sender; - (void)goBack:(id)sender; - (void)goForward:(id)sender;
@end

static inline BOOL yesOrNo(const char *a) { return (a[0] == 'y' || a[0] == '1'); }

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSFileManager *fm = [NSFileManager defaultManager];

	NSString *initPath;
	if (argc == 1) {
		initPath = NSHomeDirectory();
		fputs("Select desired files then press Cmd-Return (or click on File->Choose)\n", stderr);
	} else if (argc != 2) {
		fprintf(stderr, "usage:  %s [<dir>]\n", argv[0]);
		return 1;
	} else {
		initPath = [fm stringWithFileSystemRepresentation:argv[1] length:strlen(argv[1])];
	}

	S *s = [[S allocWithZone:NULL] init];
	s->items = [[NSMutableArray alloc] init];
	s->his = [[NSMutableArray alloc] init];
	[s addFromDir:([initPath isAbsolutePath] ? initPath : [[fm currentDirectoryPath] stringByAppendingPathComponent:initPath])];
	[[NSApplication sharedApplication] setDelegate:s];

	ProcessSerialNumber psn;
	if (!(GetCurrentProcess(&psn) == noErr && TransformProcessType(&psn, kProcessTransformToForegroundApplication) == noErr))
		warnx("Forced to run in background");

	NSMenu *n = [NSUnarchiver unarchiveObjectWithData:[NSData dataWithBytesNoCopy:_g_menu length:_g_menu_len freeWhenDone:NO]];
	[NSApp setMainMenu:n];

	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSImage *img = [ws iconForFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]];
	[img setSize:NSMakeSize(512.0f,512.0f)];
	[NSApp setApplicationIconImage:img];
	[pool release];

	[NSApp run];
}

@implementation S

- (void)goBack:(id)sender {
	if (x > 0) {
		x -= 1;
		[self addFromDir:[his objectAtIndex:x] :NO];
	}
}
- (void)goForward:(id)sender {
	if (x < [his count]-1) {
		x += 1;
		[self addFromDir:[his objectAtIndex:x] :NO];
	}
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return YES; }
- (void) applicationDidFinishLaunching: (NSNotification *)aNotification {
	NSScrollView *sc = [[NSScrollView alloc] init];
	[sc setHasVerticalScroller:YES];
	b = [[IKImageBrowserView alloc] init];
	[b setDataSource:self];
	[b setDelegate:self];
	[b setAnimates:YES];
	if ([b respondsToSelector:@selector(setCellsHaveTitle:)])
		[b setCellsHaveTitle:YES];
	NSWindow *win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 920, 720) styleMask: (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask) backing:NSBackingStoreBuffered defer:NO];
	[sc setDocumentView:b];
	[b release];
	[win setContentView:sc];
	[sc release];
	[b reloadData];
	[win center];
	[win setFrameAutosaveName:@"b"];
	[win makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
//	[b performSelector:@selector(testAnimationPerformances) withObject:b afterDelay:100.0];
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL sel = [item action];
	if (sel == @selector(down:))
		return [[b selectionIndexes] count] != 0;
	if (sel == @selector(openDocument:) || sel == @selector(reveal:))
		return [[b selectionIndexes] count] != 0;
	if (sel == @selector(goBack:))
		return x > 0;
	if (sel == @selector(goForward:)) {
		NSUInteger histSize = [his count];
		return histSize != 0 && x < histSize-1;
	}
	return YES;
}
- (void)down:(id)sender {
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir = NO;
	NSString *path = nil;
	NSIndexSet *selections = [b selectionIndexes];
	if ([selections count] == 1 && [fm fileExistsAtPath:(path=[[items objectAtIndex:[selections firstIndex]] imageUID]) isDirectory:&isDir] && isDir)
		[self addFromDir:path];
	else
		for (path in [[items objectsAtIndexes:[b selectionIndexes]] valueForKey:@"imageUID"])
			[ws openFile:path];
}
- (void)up:(id)sender {
	[self addFromDir:[[his objectAtIndex:x] stringByAppendingPathComponent:@".." ]];
}
- (void) openDocument:(id)sender {
	for (NSString *item in [[items objectsAtIndexes:[b selectionIndexes]] valueForKey:@"imageUID"])
		puts([item fileSystemRepresentation]);
	exit(0);
}
- (void) imageBrowser:(id)a1 cellWasDoubleClickedAtIndex:(NSUInteger)a2 {
	BOOL isDir = NO;
	NSString *path = ((I *)[items objectAtIndex:a2])->u;
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
	if (exists) {
		if (isDir) {
			[self addFromDir:path];
		} else {
			[[NSWorkspace sharedWorkspace] openFile:path];
		}
	}
}
-(void)addFromDir:(NSString*)path {
	[self addFromDir:path :YES];
}
-(void)addFromDir:(NSString*)path :(BOOL)upd {
	[items removeAllObjects];
	NSFileManager *fm = [NSFileManager defaultManager];
	path =  [path stringByStandardizingPath];
	for (NSString *f in [fm directoryContentsAtPath:path]) {
		I *a = [[I allocWithZone:NULL] init];
		a->u = [[path stringByAppendingPathComponent:f] copy];
		a->t = [[a->u lastPathComponent] copy];
		[items addObject:a];
		[a release];
	}
	[b reloadData];
	// the history should really be a /fixed size/ array or doubly linked list, but we're not going to use that many entries so array is fine.
	if (upd && ![[his lastObject] isEqualToString:path]) {
		NSUInteger all = [his count];
		if (all > x+1)
			[his removeObjectsInRange:NSMakeRange(x+1, all - x - 1)];
		[his addObject:path];
		if ([his count] == 1)
			x = 0;
		else
			x += 1;
	}
}

- (NSUInteger) numberOfItemsInImageBrowser: (IKImageBrowserView *)aBrowser; {
	return [items count];
}
- (id) imageBrowser: (IKImageBrowserView *)aBrowser itemAtIndex: (NSUInteger)idx; {
	return [items objectAtIndex:idx];
}
- (void) dealloc {
	[items release];
	[super dealloc];
}
@end

@implementation I
- (NSString *) imageRepresentationType; {
	return IKImageBrowserPathRepresentationType;
}
- (id) imageRepresentation; {
	return u;
}
- (NSString *) imageUID; {
	return u;
}
- (NSString *) imageTitle; {
	return t;
}
- (void) dealloc {
	[t release];
	[u release];
	[super dealloc];
}
@end

@implementation IKImageBrowserView (i)
-(void)swipeWithEvent:(NSEvent *)anEvent {
	S *d = [self delegate];
	if ([anEvent deltaX] > 0.0f) { // left
		[d goBack:nil];
	} else if ([anEvent deltaX] < 0.0f) { // right
		[d goForward:nil];
	} else if ([anEvent deltaY] > 0.0f) { // up
		[d up:nil];
	} else if ([anEvent deltaY] < 0.0f) { // down
		[d down:nil];
	}
}
-(void)magnifyWithEvent:(NSEvent *)anEvent {
	float new = [self zoomValue] + [[anEvent valueForKey:@"magnification"] floatValue];
	if (new < 0.0f) new = 0.0f;
	else if (new > 1.0f) new = 1.0f;
	[self setZoomValue:new];
}
@end
