#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <err.h>

#import "../build/etc/imgview/menu.h"

// ADD option to select which rep to use (eg. if tiff, which image index)

@interface IKImageView (IKPrivate) - (void) setAnimates:(BOOL)a; @end
@interface S : NSObject <NSApplicationDelegate> {}
@end

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	if (argc != 2) {
		fprintf(stderr, "usage:  %s <image>\n", argv[0]);
		return 1;
	}

	S *s = [[S allocWithZone:NULL] init];
	[[NSApplication sharedApplication] setDelegate:s];

	ProcessSerialNumber psn;
	if (!(GetCurrentProcess(&psn) == noErr && TransformProcessType(&psn, kProcessTransformToForegroundApplication) == noErr))
		warnx("Forced to run in background");

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
	[b setAutoresizes:YES];
	[b setCurrentToolMode:IKToolModeMove];
	NSString *path = [[[NSProcessInfo processInfo] arguments] lastObject];
	if (![path isEqualToString:@"-"]) {
		if (![[NSFileManager defaultManager] fileExistsAtPath:path])
			errc(1, ENOENT, NULL);
		NSURL *url = [NSURL fileURLWithPath:path];
		[b setImageWithURL:url];
		[win setTitleWithRepresentedFilename:[url path]];
	} else {
		NSDictionary *mImageProperties = nil;
		CGImageRef image = NULL;
		CGImageSourceRef isr = CGImageSourceCreateWithData((CFDataRef)[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile], NULL);
		if (isr) {
			image = CGImageSourceCreateImageAtIndex(isr, 0, NULL);
			if (image)
				mImageProperties = (NSDictionary*)CGImageSourceCopyPropertiesAtIndex(isr, 0, (CFDictionaryRef)mImageProperties);
			CFRelease(isr);
		}
		if (image) {
			[b setImage:image imageProperties:mImageProperties];
			CGImageRelease(image);
			[mImageProperties release];
		} else {
			errx(1, "Invalid image");
		}
	}
	NSSize size = [b imageSize];
	if (NSContainsRect(NSMakeRect(0.0f, 0.0f, size.width, size.height), [b bounds]))
		[b zoomImageToFit:nil];
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
	for (NSMenuItem *item in [[sender menu] itemArray])
		[item setState:NSOffState];
	[sender setState:NSOnState];
}
-(void)magnifyWithEvent:(NSEvent *)anEvent {
	CGFloat new = [self zoomFactor] + [anEvent magnification];
	if (new <= 1e-10f) new = 1e-10f;
//	[self setImageZoomFactor:new centerPoint:[self convertPoint:[anEvent locationInWindow] fromView:nil]];
	[self setZoomFactor:new];
}
-(void)rotateWithEvent:(NSEvent *)anEvent {
	float new = ([anEvent rotation] * (float)M_PI / 180.0f);
	self.rotationAngle += new;
//	[self setRotationAngle:new centerPoint:[self convertPoint:[anEvent locationInWindow] fromView:nil]];
}
@end
