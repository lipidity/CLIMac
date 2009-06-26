#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "../build/etc/imgview/menu.h"

@interface IKImageView (IKPrivate) - (void) setAnimates:(BOOL)a; @end
@interface S : NSObject {} @end

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	if (argc != 2) {
		fprintf(stderr, "usage:  %s [<image>]\n", argv[0]);
		return 1;
	}

	S *s = [[S allocWithZone:NULL] init];
	[[NSApplication sharedApplication] setDelegate:s];

	ProcessSerialNumber psn;
	GetCurrentProcess(&psn);
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);

	NSMenu *n = [NSUnarchiver unarchiveObjectWithData:[NSData dataWithBytesNoCopy:_g_menu length:_g_menu_len freeWhenDone:NO]];
//	NSMutableArray *a = [NSMutableArray array];
//	NSNib *n = [[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:@"/Users/ankur/Work/CLIMac/build/etc/imgview/main.xib"]];
//	[n instantiateNibWithExternalNameTable:[NSDictionary dictionaryWithObjectsAndKeys:a, NSNibTopLevelObjects, nil]];
	[NSApp setMainMenu:n];

	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSImage *img = [ws iconForFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]];
	[img setSize:NSMakeSize(512.0f, 512.0f)];
	[NSApp setApplicationIconImage:img];

	[pool release];

	[NSAutoreleasePool new];
	[NSApp run];
}

@implementation S
- (void) applicationDidFinishLaunching: (NSNotification *)aNotification {
	NSWindow *win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0.0f, 0.0f, 920.0f, 720.0f) styleMask: (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask) backing:NSBackingStoreBuffered defer:NO];
	IKImageView *b = [[IKImageView alloc] init];
	[win setContentView:b];
	[b setDelegate:self];
	[b setDoubleClickOpensImageEditPanel:YES];
	if ([b respondsToSelector:@selector(setAnimates:)])
		[b setAnimates:YES];
	[b setCurrentToolMode:IKToolModeMove];
	NSURL *url = [NSURL fileURLWithPath:[[[NSProcessInfo processInfo] arguments] lastObject]];
	[b setImageWithURL:url];
	[b zoomImageToFit:nil];
	if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]] || ![b image])
		errx(1, "Invalid image");
	[win setTitleWithRepresentedFilename:[url path]];
	[win center];
	[win setFrameAutosaveName:@"v"];
	[win makeKeyAndOrderFront:nil];
	[b release];
	[NSApp activateIgnoringOtherApps:YES];
}
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return YES; }
@end

@implementation IKImageView (i)
-(void)setMode:(id)sender {
	[self setCurrentToolMode:((NSString *[]){IKToolModeMove, IKToolModeSelect, IKToolModeCrop, IKToolModeRotate, IKToolModeAnnotate})[[sender tag]]];
}
-(void)magnifyWithEvent:(NSEvent *)anEvent {
	float new = [self zoomFactor] + ([anEvent deltaZ] / 100.0f);
	if (new <= 1e-10f) new = 1e-10f;
	[self setZoomFactor:new];
}
-(void)rotateWithEvent:(NSEvent *)anEvent {
	self.rotationAngle += ([anEvent rotation] * (float)M_PI / 180.0f);
}
@end
