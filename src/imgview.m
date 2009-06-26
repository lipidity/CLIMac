#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "MenuPopulator.h"

@interface IKImageView (IKPrivate) - (void) setAnimates:(BOOL)a; @end
@interface S : NSObject { @public IKImageView *b; } @end

int main(int argc, char *argv[]) {
	[NSAutoreleasePool new];

	if (argc != 2) {
		fprintf(stderr, "usage:  %s [<image>]\n", argv[0]);
		return 1;
	}

	S *s = [[S allocWithZone:NULL] init];
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
	return @"Image View";
}

- (void) applicationWillFinishLaunching: (NSNotification *)aNotification {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	populateMainMenu();
	[pool release];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return YES; }
- (void) applicationDidFinishLaunching: (NSNotification *)aNotification {
	NSWindow *win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 920, 720) styleMask: (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask) backing:NSBackingStoreBuffered defer:NO];
	b = [[IKImageView alloc] init];
	[win setContentView:b];
	[b setDelegate:self];
	[b setDoubleClickOpensImageEditPanel:YES];
	[b setAnimates:YES];
	[b setCurrentToolMode:IKToolModeMove];
	NSURL *url = [NSURL fileURLWithPath:[[[NSProcessInfo processInfo] arguments] lastObject]];
#if 0
		NSDictionary *mImageProperties = NULL;
		CGImageRef          image = NULL;
		CGImageSourceRef    isr = CGImageSourceCreateWithURL( (CFURLRef)url, NULL);
		if (isr) {
			image = CGImageSourceCreateImageAtIndex(isr, 0, NULL);
			if (image) {
				mImageProperties = (NSDictionary*)CGImageSourceCopyPropertiesAtIndex(isr, 0, (CFDictionaryRef)mImageProperties);
			}
			CFRelease(isr);
		}
		if (image) {
			[b setImage: image imageProperties: mImageProperties];
			CGImageRelease(image);
		}
#else
	[b setImageWithURL:url];
#endif
	if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]] || ![b image])
		errx(1, "Invalid image");
	[win setTitleWithRepresentedFilename:[url path]];
	[b zoomImageToFit:self];
	[b release];
	[win center];
	[win setFrameAutosaveName:@"v"];
	[win makeKeyAndOrderFront:nil];

	[NSApp activateIgnoringOtherApps:YES];
}
@end

@implementation IKImageView (i)
-(void)rotateWithEvent:(NSEvent *)anEvent {
	self.rotationAngle += ([anEvent rotation] * (float)M_PI / 180.0f);
}
-(void)magnifyWithEvent:(NSEvent *)anEvent {
	float new = [self zoomFactor] + ([anEvent deltaZ] / 100.0f);
	if (new <= 0.1f) new = 0.1f;
	[self setZoomFactor:new];
}
@end



