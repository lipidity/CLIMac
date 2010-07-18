#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

// todo: -f <path> to read lines from file
// todo: -e '...' to specify individual lines
// todo: able to read image from stdin

#define FAIL(format, args...) errx(1, "Line %d: " format , c, ## args)

int main(int argc, char *argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	if ((argc > 1) && strcmp("-l", argv[1]) == 0) {
		NSString *t;
#if 0
		NSMutableArray *a = nil;
		a = [[NSMutableArray alloc] initWithCapacity:argc];
		while (--argc > 1) {
			t = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[argc]);
			if ([t hasPrefix:@"kCI"])
				t = [t substringFromIndex:1];
			[a addObject:t];
			CFRelease(t);
		}
#else
		NSArray *b = [[NSProcessInfo processInfo] arguments];
		NSArray *a = [b subarrayWithRange:NSMakeRange(2, [b count] - 2)];
#endif
		NSEnumerator *e = [[CIFilter filterNamesInCategories:a] objectEnumerator];
		while ((t = [e nextObject]))
			puts([t UTF8String]);
		return 0;
	} else if (argc == 2) {
		CIFilter *y;
		NSString *l = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[1]); //leaked since impending exit
		if (((y = [CIFilter filterWithName:l])||(y = [CIFilter filterWithName:[@"CI" stringByAppendingString:l]]))) {
			puts([[[y attributes] description] fileSystemRepresentation]);
			return 0;
		} else {
			fprintf(stderr, "Filter '%s' not found\n", argv[1]);
			return 2;
		}
	} else if (argc != 3) {
		fprintf(stderr, "usage:  %s\n\t<src> <out>.tiff\n\t<filter>\n\t-l <category>...\n", argv[0]);
		return 1;
	}

	NSString *s = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	NSArray *lines = [[s componentsSeparatedByString:@"\n"] copy];
	[s release];

	[NSApplication sharedApplication];

	[pool release];
	pool = [NSAutoreleasePool new];

	CIFilter *currentFilter = nil, *lastFilter = nil;
	NSMutableString *l = nil;
	unsigned int c = 0;
	while (c < [lines count]) {
		NSAutoreleasePool *subpool = [NSAutoreleasePool new];
		[l release];
		l = [[NSMutableString alloc] initWithString:[lines objectAtIndex:c++]];
		CFStringTrimWhitespace((CFMutableStringRef)l);
		NSRange w = [l rangeOfString:@"#"];
		if (w.location != NSNotFound) {
			[l setString:[l substringToIndex:w.location]];
			CFStringTrimWhitespace((CFMutableStringRef)l);
		}
		if (![l length]) {
			[subpool release];
			continue;
		}
		CIFilter *newFilter = [CIFilter filterWithName:l] ? : [CIFilter filterWithName:[@"CI" stringByAppendingString:l]];
		if (newFilter != nil) {
			currentFilter = newFilter;
			[currentFilter setDefaults];
			if ([[currentFilter inputKeys] containsObject:@"inputImage"]) {
				if (lastFilter) {
					[currentFilter setValue:[lastFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
				} else {
//					fprintf(stderr, "Filter has no inputImage on line %d\n", c); return 4;
					CIImage *i;
					NSURL *aURL = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[1], strlen(argv[1]), false);
					if (aURL && (i = [CIImage imageWithContentsOfURL:aURL])) {
						[currentFilter setValue:i forKey:@"inputImage"];
					} else {
						errx(1, "Invalid input image.");
					}
					[aURL release];
				}
			}
			if (lastFilter)
				[lastFilter release];
			lastFilter = [currentFilter retain];
		} else {
			NSArray *a = [l componentsSeparatedByString:@"="];
			if ([a count] != 2) {
				FAIL("Too many ='s");
			}
			NSMutableString *k = [[NSMutableString alloc] initWithString:[a objectAtIndex:0]];
			CFStringTrimWhitespace((CFMutableStringRef)k);
			NSDictionary *d;
			if (!(d = [[currentFilter attributes] objectForKey:k])) {
				if (![k hasPrefix:@"input"]) {
					[k replaceCharactersInRange:NSMakeRange(0, 1) withString:[[k substringToIndex:1] uppercaseString]];
					[k insertString:@"input" atIndex:0];
					if ((d = [[currentFilter attributes] objectForKey:k]))
						goto parse;
					else
						goto nope;
				} else {
nope:
					FAIL("No such parameter '%s'", [k fileSystemRepresentation]);
				}
			} else {
parse: ;
				NSMutableString *v = [[NSMutableString alloc] initWithString:[a objectAtIndex:1]];
				CFStringTrimWhitespace((CFMutableStringRef)v);
				id z;
				NSString *r = [d objectForKey:@"CIAttributeClass"];
				if ([r isEqualToString:@"NSNumber"]) {
					NSScanner *sc = [NSScanner scannerWithString:v];
					float o;
					[sc scanFloat:&o];
					[currentFilter setValue:[NSNumber numberWithFloat:o] forKey:k];
				} else if ([r isEqualToString:@"CIVector"]) {
					if ((z = [CIVector vectorWithString:v]))
						[currentFilter setValue:z forKey:k];
					else {
						FAIL("Bad CIVector");
					}
				} else if ([r isEqualToString:@"CIColor"]) {
					if ((z = [CIColor colorWithString:v]))
						[currentFilter setValue:z forKey:k];
					else {
						FAIL("Bad CIColor");
					}
				} else if ([r isEqualToString:@"CIImage"]) {
					if ((z = [CIImage imageWithContentsOfURL:[NSURL fileURLWithPath:[v stringByStandardizingPath]]]))
						[currentFilter setValue:z forKey:[NSString stringWithUTF8String:[k UTF8String]]];
					else {
						FAIL("Not an image: '%s'", [v UTF8String]);
					}
				} else if ([r isEqualToString:@"NSAffineTransform"]) {
					NSAffineTransform *xfrm = [[[NSAffineTransform alloc] initWithTransform:[currentFilter valueForKey:k]] autorelease] ? : [NSAffineTransform transform];
					NSString *fn;
					NSMutableArray *args;
					NSCharacterSet *lo = [NSCharacterSet lowercaseLetterCharacterSet];
					NSScanner *sc = [NSScanner scannerWithString:v];
					args = [[NSMutableArray alloc] init];
					do {
						fn = nil;
						if ([sc scanCharactersFromSet:lo intoString:&fn]) {
							if (![sc scanString:@"(" intoString:NULL])
								FAIL("%s: function needs arguments", [fn fileSystemRepresentation]);
							do {
								double dbl;
								if ([sc scanDouble:&dbl]) {
									NSNumber *n = [[NSNumber alloc] initWithDouble:dbl];
									[args addObject:n];
									[n release];
								} else {
									FAIL("Arguments to %s should be floating-point numbers", [fn fileSystemRepresentation]);
								}
							} while ([sc scanString:@"," intoString:NULL]);
							if (![sc scanString:@")" intoString:NULL])
								FAIL("No closing parenthesis");
							if ([fn isEqualToString:@"rotated"] || [fn isEqualToString:@"rotd"]) {
								if ([args count] == 1)
									[xfrm rotateByDegrees:(CGFloat)[[args objectAtIndex:0] doubleValue]];
								else
									FAIL("rotated needs one argument");
							} else if ([fn hasPrefix:@"rot"]) {
								if ([args count] == 1)
									[xfrm rotateByRadians:(CGFloat)[[args objectAtIndex:0] doubleValue]];
								else
									FAIL("rotater needs one argument");
							} else if ([fn hasPrefix:@"sca"]) {
								if ([args count] == 2)
									[xfrm scaleXBy:(CGFloat)[[args objectAtIndex:0] doubleValue] yBy:(CGFloat)[[args objectAtIndex:1] doubleValue]];
								else
									FAIL("scale needs two arguments");
							} else if ([fn hasPrefix:@"tra"]) {
								if ([args count] == 2)
									[xfrm translateXBy:(CGFloat)[[args objectAtIndex:0] doubleValue] yBy:(CGFloat)[[args objectAtIndex:1] doubleValue]];
								else
									FAIL("translate needs two arguments");
							} else if ([fn hasPrefix:@"mat"]) {
								if ([args count] == 6) {
									NSAffineTransformStruct mx = {[[args objectAtIndex:0] floatValue], [[args objectAtIndex:1] floatValue], [[args objectAtIndex:2] floatValue], [[args objectAtIndex:3] floatValue], [[args objectAtIndex:4] floatValue], [[args objectAtIndex:5] floatValue]};
									[xfrm setTransformStruct:mx];
								} else
									FAIL("matrix needs six arguments");
							} else {
								FAIL("Unknown tranformation function '%s'", [fn fileSystemRepresentation]);
							}
							[args removeAllObjects];
						} else {
							break;
						}
					} while ([sc scanString:@"," intoString:NULL]);
					[args release];
					[currentFilter setValue:xfrm forKey:k];
				} else {
					FAIL("Don't know how to handle input type '%s'", [r fileSystemRepresentation]);
				}
				[v release];
			}
			[k release];
		}
		[subpool release];
	}
	[l release];
	[lines release];

	CIImage *q = [currentFilter valueForKey:@"outputImage"];
	CGRect n = [q extent];

	if (CGRectEqualToRect(n, CGRectInfinite)) {
		fputs("Image has infinite size; Cropping...\n", stderr);
		q = [[CIFilter filterWithName:@"CICrop" keysAndValues:@"inputRectangle", [CIVector vectorWithString:@"[0 0 1024 1024]"], @"inputImage", q, nil] valueForKey:@"outputImage"];
		n = [q extent];
	}
#if 1
	NSCIImageRep *cir = [[NSCIImageRep alloc] initWithCIImage:q];
	NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(n.size.width, n.size.height)];
	[image addRepresentation:cir];
	[cir release];
	NSData *dataOut = [image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0f];
	[image release];
#else
	NSBitmapImageRep *b = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:n.size.width pixelsHigh:n.size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
	NSGraphicsContext *x;
	if (!(x = [NSGraphicsContext graphicsContextWithBitmapImageRep:b])) {
		errx(2, "No graphics context");
	}
	[NSGraphicsContext setCurrentContext:x];
	[[x CIContext] drawImage:q atPoint:CGPointZero fromRect:n];

	NSData *dataOut = [b TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:0.0f];
	[b release];
#endif
	if (strcmp(argv[2] , "-") == 0) {
		[(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:dataOut];
	} else {
		NSString *path = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[2]);
		if (![[path pathExtension] isEqualToString:@"tif"] && ![[path pathExtension] isEqualToString:@"tiff"]) {
			NSString *tmp = path;
			path = [[tmp stringByAppendingPathExtension:@"tiff"] retain];
			[tmp release];
		}
		if (![dataOut writeToFile:path atomically:0]) {
			errx(2, "Could not write image to '%s'\n", argv[2]);
		}
		[path release];
	}
	[pool release];
    return 0;
}
