#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
// disas -- LSSetCurrentApplicationInformation (to maybe make us UIElement after activating.
// will have to over-ride some NSPanel methods to allow other panels (eg font / color panels) to be shown properly and not hide on deactivate

@interface P : NSObject { @public NSURL *o; } @end

int main(int argc, const char *argv[]) {
	[NSAutoreleasePool new];
	int i = 1;
	P *p = [[P allocWithZone:NULL] init];
	NSURL *input = nil;
	while (i < argc) {
		if (strcmp("-o", argv[i]) != 0) {
			if (input != nil)
				goto usage;
			input = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[i], strlen(argv[i]), false);
		} else {
			i += 1;
			if (p->o != nil)
				goto usage;
			if (!(i < argc && (p->o = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)argv[i], strlen(argv[i]), false)))) {
				warnx("Option `-o' needs path argument.");
				goto usage;
			}
		}
		i += 1;
	}
	if (p->o == nil && isatty(STDOUT_FILENO))
		errx(1, "Refusing to dump TIFF data to a Terminal");
	IKPictureTaker *pic = [IKPictureTaker pictureTaker];
	if (input) {
		NSImage *img = [[NSImage alloc] initWithContentsOfURL:input];
		if (img == nil) {
			warnx("Ignoring invalid input image");
		} else {
			[pic setInputImage:img];
			[img release];
		}
		CFRelease(input);
	}
	[pic setLevel:NSFloatingWindowLevel];
	[[NSApplication sharedApplication] setDelegate:p];
	ProcessSerialNumber psn;
	GetCurrentProcess(&psn);
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);
	[NSApp run];
//	NSApplicationMain(argc, argv);
usage:
	fprintf(stderr, "usage:  %s [<input>] [-o <output>]\n", argv[0]);
	return 1;
}

@implementation P

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification {
//	SetFrontProcess(&psn);
	[NSApp activateIgnoringOtherApps:YES];
	IKPictureTaker *pic = [IKPictureTaker pictureTaker];
	if ([pic runModal] == NSOKButton) {
		NSData *tiff = [[pic outputImage] TIFFRepresentation];
		if (tiff) {
			if (o != nil) {
				NSError *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
				if (![tiff writeToURL:o options:0 error:&error])
					errx(1, "%s", [error localizedFailureReason]);
				CFRelease(o);
			} else {
				if (fwrite([tiff bytes], [tiff length], 1, stdout) != 1)
					err(1, "Couldn't write image.");
			}
			exit(0);
		}
		errx(1, "No TIFF data in image");
	}
	exit(0);
}
//- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)a { return YES; }

@end
