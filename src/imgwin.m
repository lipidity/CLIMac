#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
	if (argc != 3) {
		fprintf(stderr, "Usage:  %s <wid> <out>.tiff\n", argv[0]);
		return 1;
	}

	BOOL sdw = 0;

	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	[NSApplication sharedApplication];
	int cid = CGSMainConnectionID();
	int wid = (int)strtol(argv[1], NULL, 10);

	NSShadow *s;
	CGRect cgrect;
	CGSGetWindowBounds(cid, wid, &cgrect);
	NSSize oSize = *(NSSize *)&(cgrect.size);
	cgrect.origin = (CGPoint){0.0f, 0.0f};
	if (sdw) {
		float sd, od; int ox, oy, f;
		CGSGetWindowShadowAndRimParameters(CGSMainConnectionID(), wid, &sd, &od, &ox, &oy, &f);
		oSize = (NSSize){cgrect.size.width + (int)sd*3+5, cgrect.size.height + (int)sd*3+5};
		cgrect.origin.x = (int)(sd * 3 + 5) / 2; cgrect.origin.y = (int)(sd * 3 + 5)*3/4;
		s = [[NSShadow alloc] init];
		[s setShadowOffset:(NSSize){-ox, -oy}];
		[s setShadowBlurRadius:sd*od*3.5f];
		[s setShadowColor:[NSColor colorWithCalibratedWhite:0.0f alpha:0.6f]];
	}
	NSImage *o = [[NSImage alloc] initWithSize:oSize];
	[o lockFocus];
	if (sdw)
		[s set];
	CGContextCopyWindowCaptureContentsToRect([[NSGraphicsContext currentContext] graphicsPort], cgrect, cid, wid, 0);
	[o unlockFocus];
	if (sdw)
		[s release];

	NSData *dataOut = [o TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0f];
	if (strcmp(argv[1] , "-") == 0) {
		[(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:dataOut];
	} else {
		NSString *path = NSTR(argv[2]);
		if (![[path pathExtension] isEqualToString:@"tif"] && ![[path pathExtension] isEqualToString:@"tiff"])
			path = [path stringByAppendingPathExtension:@"tiff"];
		if (![dataOut writeToFile:path atomically:0]) {
			fprintf(stderr, "Could not write image to '%s'\n", argv[2]);
			return 3;
		}
		[path release];
	}

	[o release];
	[pool release];
    return 0;
}
