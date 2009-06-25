#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "MenuPopulator.h"

@interface I : NSObject { @public NSString *u, *t; } @end
@interface S : NSObject { @public NSMutableArray *items; IKImageBrowserView *b; } @end

static inline BOOL yesOrNo(const char *a) { return (a[0] == 'y' || a[0] == '1'); }

int main(int argc, char *argv[]) {
	[NSAutoreleasePool new];

	if (argc == 1)
		errx(1, "No files to show");

	NSMutableArray *files = [[NSMutableArray alloc] initWithCapacity:argc];
	for (int i = 1; i < argc; i++) {
		I *a = [[I allocWithZone:NULL] init];
		a->u = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[i]);
		a->t = [a->u lastPathComponent];
		[files addObject:a];
		[a release];
	}
	S *s = [[S allocWithZone:NULL] init];
	s->items = [files mutableCopy];
	[files release];
	[[NSApplication sharedApplication] setDelegate:s];
	ProcessSerialNumber psn;
	GetCurrentProcess(&psn);
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);
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
