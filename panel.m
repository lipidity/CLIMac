#import <Cocoa/Cocoa.h>

@interface P : NSObject {} @end

int main(int argc, const char *argv[]) {
	[NSAutoreleasePool new];
	if (NSApplicationLoad()) {
		[[NSApplication sharedApplication] setDelegate:[P new]];
		[NSApp activateIgnoringOtherApps:YES];
		NSApplicationMain(0, NULL);
//		[NSApp finishLaunching];
//		while (1) {
//			NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
//			if (event) [NSApp sendEvent:event];
//		}
	}
	return 1;
}

@implementation P

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a {
	return YES;
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@"fin");
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontFontPanel:nil];
	[NSApp orderFrontColorPanel:nil];
	[[NSColorPanel sharedColorPanel] orderFront:nil];
}

@end
