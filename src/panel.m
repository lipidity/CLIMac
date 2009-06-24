#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "/Users/ankur/src/undocumented-goodness/CoreProcess/CPSPrivate.h"

@implementation NSWindow (p)
- (BOOL) hidesOnDeactivate { return NO; }
@end

@interface P : NSObject {} @end

int main(int argc, const char *argv[]) {
	// disas -- LSSetCurrentApplicationInformation
	[NSAutoreleasePool new];
	[[NSApplication sharedApplication] setDelegate:[P new]];
//	NSApplicationMain(argc, argv);
	//	NSLog(@"%d", [self stealKeyFocus]);
	CPSProcessSerNum psn;
	CPSGetCurrentProcess(&psn);
//	TransformProcessType(kCurrentProcess, kProcessTransformToForegroundApplication);
	CPSEnableForegroundOperation(&psn);
	CPSSetProcessName(&psn, "Picture Taker");
	//	CPSSetFrontProcess(&psn);
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp run];
	return 1;
}

@implementation P

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a {
	return YES;
}
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
//	[NSApp orderFrontFontPanel:nil];
//	[NSApp orderFrontColorPanel:nil];
//	[[NSColorPanel sharedColorPanel] orderFront:nil];
//	[[IKPictureTaker pictureTaker] center];
//	[[IKPictureTaker pictureTaker] setLevel: NSFloatingWindowLevel];
//	[[IKPictureTaker pictureTaker] makeKeyAndOrderFront: nil];
	[[IKPictureTaker pictureTaker] runModal];
}

@end
