#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "MenuPopulator.h"

@interface I : NSObject { @public NSString *u, *t; } @end
@interface S : NSObject { @public IKImageBrowserView *b; NSMutableArray *items; NSMutableArray *his; NSUInteger x; }
-(void)addFromDir:(NSString*)path;
-(void)addFromDir:(NSString*)path doHist:(BOOL)upd;
- (void)up:(id)sender;
- (void)down:(id)sender;
- (void)end:(id)sender;
@end

@implementation IKImageBrowserView (i)
-(void)swipeWithEvent:(NSEvent *)anEvent {
	S *d = [self delegate];
	if ([anEvent deltaX] > 0.0f) { // left
		if (d->x > 0) {
			d->x -= 1;
			[d addFromDir:[d->his objectAtIndex:d->x] doHist:NO];
		}
	} else if ([anEvent deltaX] < 0.0f) { // right
		if (d->x < [d->his count]-1) {
			d->x += 1;
			[d addFromDir:[d->his objectAtIndex:d->x] doHist:NO];
		}
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

static inline BOOL yesOrNo(const char *a) { return (a[0] == 'y' || a[0] == '1'); }

int main(int argc, char *argv[]) {
	[NSAutoreleasePool new];

	if (argc == 1) {
		fputs("Select desired files in browser then press Cmd-S (File->Select)\n", stderr);
	}
	if (argc != 2) {
		fprintf(stderr, "usage:  %s <dir>\n", argv[0]);
	}

	S *s = [[S allocWithZone:NULL] init];
	s->items = [[NSMutableArray alloc] init];
	s->his = [[NSMutableArray alloc] init];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *initPath = [fm stringWithFileSystemRepresentation:argv[1] length:strlen(argv[1])];
	[s addFromDir:([initPath isAbsolutePath] ? initPath : [[fm currentDirectoryPath] stringByAppendingPathComponent:initPath])];
	[[NSApplication sharedApplication] setDelegate:s];

	ProcessSerialNumber psn;
	GetCurrentProcess(&psn);
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);

	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSImage *img = [ws iconForFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]];
	[img setSize:NSMakeSize(512.0f,512.0f)];
	[NSApp setApplicationIconImage:img];
	[NSApp run];
}

@implementation S

- (NSString *)appName {
	return @"Image Browser";
}

- (void) applicationWillFinishLaunching: (NSNotification *)aNotification {
#if 0
	NSMenuItem *item;
	NSMenu *submenu;

	NSMenu *mmain = [[NSMenu alloc] initWithTitle:@"MainMenu"];

	item = [mmain addItemWithTitle:@"Apple" action:NULL keyEquivalent:@""];
	submenu = [[NSMenu alloc] initWithTitle:@"Apple"];
	[NSApp performSelector:@selector(setAppleMenu:) withObject:submenu];

	NSMenuItem *it = [submenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
	[it setTarget:NSApp];

	[mmain setSubmenu:submenu forItem:item];
	
	NSLog(@"%@", [NSApp mainMenu]);
	[NSApp setMainMenu:mmain];
	NSLog(@"%@", [NSApp mainMenu]);
#endif
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	populateMainMenu();
	[pool release];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return YES; }
- (void) applicationDidFinishLaunching: (NSNotification *)aNotification {
	NSScrollView *sc = [[NSScrollView alloc] init];
	[sc setHasVerticalScroller:YES];
	b = [[IKImageBrowserView alloc] init];
	[b setDataSource:self];
	[b setDelegate:self];
	[b setAnimates:YES];
	[b setCellsHaveTitle:YES];
//	[b setAllowsMultipleSelection:YES];
	NSWindow *win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 500) styleMask: (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask) backing:NSBackingStoreBuffered defer:NO];
	[sc setDocumentView:b];
	[b release];
	[win setContentView:sc];
	[sc release];
	[b reloadData];
	[win center];
	[win setFrameAutosaveName:@"br"];
	[win makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
//	[b performSelector:@selector(testAnimationPerformances) withObject:b afterDelay:100.0];
	NSMenuItem *it = [[NSMenuItem alloc] initWithTitle:@"Start slideshow" action:@selector(s:) keyEquivalent:@"\r"];
	[it setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
	[it setTarget:self];
	NSMenu *fileSubmenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];
	[fileSubmenu insertItem:[NSMenuItem separatorItem] atIndex:9];
	[fileSubmenu insertItem:it atIndex:10];
	[it release];

	it = [fileSubmenu itemWithTitle:@"Save"];
	[it setTarget:self];
	[it setAction:@selector(end:)];
	[it setTitle:@"Select"];

	id a1 = [fileSubmenu itemWithTitle:@"Save As..."];
	id a2 = [fileSubmenu itemWithTitle:@"Revert"];
	id a3 = [fileSubmenu itemWithTitle:@"Page Setup..."];
	id a4 = [fileSubmenu itemWithTitle:@"Print..."];
	[fileSubmenu removeItem:a1];
	[fileSubmenu removeItem:a2];
	[fileSubmenu removeItem:a3];
	[fileSubmenu removeItem:a4];

	unichar ch = NSUpArrowFunctionKey;
	NSMenuItem *it1 = [[NSMenuItem alloc] initWithTitle:@"Parent directory" action:@selector(up:) keyEquivalent:[NSString stringWithCharacters:&ch length:1u]];
	ch = NSDownArrowFunctionKey;
	NSMenuItem *it2 = [[NSMenuItem alloc] initWithTitle:@"Enter directory" action:@selector(down:) keyEquivalent:[NSString stringWithCharacters:&ch length:1u]];
	[it1 setKeyEquivalentModifierMask:NSCommandKeyMask];
	[it2 setKeyEquivalentModifierMask:NSCommandKeyMask];
	[it1 setTarget:self];
	[it2 setTarget:self];
	[fileSubmenu insertItem:it2 atIndex:10];
	[fileSubmenu insertItem:it1 atIndex:10];
	[it1 release];
	[it2 release];
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
	NSFileManager *fm = [NSFileManager defaultManager];
	SEL sel = [item action];
	if (sel == @selector(down:)) {
		BOOL isDir = NO;
		return ([[b selectionIndexes] count] == 1 && [fm fileExistsAtPath:[[items objectAtIndex:[[b selectionIndexes] firstIndex]] imageUID] isDirectory:&isDir] && isDir);
	}
	if (sel == @selector(end:))
		return [[b selectionIndexes] count] != 0;
	return YES;
}
- (void)down:(id)sender {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSUInteger idx = [[b selectionIndexes] firstIndex];
	if (idx != NSNotFound) {
		NSString *path = [[items objectAtIndex:idx] imageUID];
		BOOL isDir = NO;
		if ([[b selectionIndexes] count] == 1 && [fm fileExistsAtPath:path isDirectory:&isDir] && isDir) {
			[self addFromDir:path];
		}
	}
}
- (void)up:(id)sender {
	[self addFromDir:[[his objectAtIndex:x] stringByAppendingPathComponent:@".." ]];
}
- (void) end:(id)sender {
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
	[self addFromDir:path doHist:YES];
}
-(void)addFromDir:(NSString*)path doHist:(BOOL)upd {
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
#if 0
- (void) imageBrowser:(id)a1 titleOfCellAtIndex:(NSUInteger)a2 didBeginEditing:(BOOL)a3 {
	NSLog(@"%@", a1);
	NSLog(@"%u", a2);
	NSLog(@"%d", a3);
}
- (BOOL) imageBrowser:(id)a1 titleOfCellAtIndex:(NSUInteger)a2 shouldBeginEditing:(BOOL)a3 {
	NSLog(@"%@", a1);
	NSLog(@"%u", a2);
	NSLog(@"%d", a3);
	return YES;
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[b stopEditing];
}
#endif
- (void)s:(id)sender {
	[b performSelector:@selector(startSlideShow:) withObject:nil];
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
