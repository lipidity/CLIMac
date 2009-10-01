#import "LargeType.h"
#import <unistd.h>

#define EDGEINSET 16
#define RADIUS 32

static inline NSRect centerRectInRect(NSRect r, NSRect m) {
	return NSOffsetRect(r, NSMidX(m) - NSMidX(r), NSMidY(m) - NSMidY(r));
}

@implementation QSVanishingWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)sendEvent:(NSEvent *)theEvent {
	int t = (int)[theEvent type];
	if(t < 3 || t == 10 || t == 11 || (t > 24 && t < 28)) {
		[self fadeToAlpha:0];
		[self close];
		[NSApp terminate:nil];
	}
}
- (void)fadeToAlpha:(float)a {
	float f = [self alphaValue];
	if (f < a) {
		while ((f += 0.01f) <= a) {
			[self setAlphaValue:f];
			usleep(2000);
		}
	} else if (f > a) {
		while ((f -= 0.01f) >= a) {
			[self setAlphaValue:f];
			usleep(2000);
		}
	}
}
@end

static void fadE(void *info, const float *in, float *out);
static void fadE(void *info, const float *in, float *out) {
	float v = *in, *c = info; int i;
	for (i = 0; i < 4; i++)
		*out++ = c[i] * (1 - v) + c[i + 4] * (v);
}

static void QSFillRectWithGradient(NSRect rect, NSColor *a, NSColor *b);
static void QSFillRectWithGradient(NSRect rect, NSColor *a, NSColor *b) {
	CGColorSpaceRef c = CGColorSpaceCreateDeviceRGB();
	a = [a colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	b = [b colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	static const float d[2] = { 0, 1 };
	static const float r[10] = { 0, 1, 0, 1, 0, 1, 0, 1, 0, 1 };
	static const CGFunctionCallbacks l = { 0, &fadE, NULL };
	float o[8] = { [a redComponent], [a greenComponent], [a blueComponent], [a alphaComponent],
		[b redComponent], [b greenComponent], [b blueComponent], [b alphaComponent] };
	CGFunctionRef f = CGFunctionCreate(o, 1, d, 1 + CGColorSpaceGetNumberOfComponents(c), r, &l);
	CGShadingRef s = CGShadingCreateAxial(c, CGPointMake(0, NSMaxY(rect)), CGPointMake(0, NSMinY(rect)), f, NO, NO);
	CGContextDrawShading((CGContextRef) [[NSGraphicsContext currentContext] graphicsPort], s);
	CGFunctionRelease(f);
	CGShadingRelease(s);
	CGColorSpaceRelease(c);
}

@implementation QSBackgroundView
- (void)drawRect:(NSRect)rect {
	NSRect aRect = [self frame];
	NSBezierPath *cornerEraser = [NSBezierPath bezierPath];
	NSPoint topLeft = NSMakePoint(aRect.origin.x, NSMaxY(aRect)), topRight = NSMakePoint(NSMaxX(aRect), NSMaxY(aRect)), bottomRight = NSMakePoint(NSMaxX(aRect), aRect.origin.y);
	[cornerEraser moveToPoint:NSMakePoint(NSMidX(aRect), NSMaxY(aRect))];
	[cornerEraser appendBezierPathWithArcFromPoint:topLeft toPoint:aRect.origin radius:RADIUS];
	[cornerEraser appendBezierPathWithArcFromPoint:aRect.origin toPoint:bottomRight radius:RADIUS];
	[cornerEraser appendBezierPathWithArcFromPoint:bottomRight toPoint:topRight radius:RADIUS];
	[cornerEraser appendBezierPathWithArcFromPoint:topRight toPoint:topLeft radius:RADIUS];
	[cornerEraser closePath];
	[cornerEraser addClip];

	NSRect topRect, bottomRect, fullRect = [self convertRect:[self frame] fromView:[self superview]];
	[[NSColor blackColor] set];
	NSRectFill(fullRect);
	NSDivideRect(fullRect, &topRect, &bottomRect, fullRect.size.height / 2, NSMaxYEdge);
	QSFillRectWithGradient(topRect, [NSColor colorWithDeviceWhite:1.0 alpha:0.5], [NSColor colorWithDeviceWhite:1.0 alpha:0.1]);
//	QSFillRectWithGradientFromEdge(bottomRect, backgroundColor, backgroundColor, NSMinYEdge);
}
@end

int main (int argc, const char * argv[]) {
	if(argc < 2) {
		fprintf(stderr, "usage: %s <string>...\n", argv[0]);
		return 1;
	} else {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		[NSApplication sharedApplication];
		NSString *s;
		if(strcmp(argv[1], "-")) {
			int i = 1; NSMutableArray *a = [[NSMutableArray alloc] initWithCapacity:argc-1];
			while(i < argc)
				[a addObject:[NSString stringWithUTF8String:argv[i++]]];
			s = [a componentsJoinedByString:@" "];
			[a release];
		} else {
			/*NSString *t =*/ s = [[[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
//			s = [t substringToIndex:[t length]-1];
		}

		if (![s length])
			return 2;

		NSRect screenRect = [[NSScreen mainScreen] frame];

		float displayWidth = NSWidth(screenRect) * 11 / 12 - 2 * EDGEINSET;
		NSRange fullRange = NSMakeRange(0, [s length]);
		NSMutableAttributedString *formattedNumber = [[NSMutableAttributedString alloc] initWithString:s];
		int size;
		NSSize textSize;
		NSFont *textFont;
		for (size = 24; size < 300; size++) {
//			textFont = [NSFont boldSystemFontOfSize:size+1];
			textFont = [NSFont userFixedPitchFontOfSize:size+1];
			textSize = [s sizeWithAttributes:[NSDictionary dictionaryWithObject:textFont forKey:NSFontAttributeName]];
			if (textSize.width > displayWidth + [textFont descender] * 2) break;
		}
		[formattedNumber addAttribute:NSFontAttributeName value:[NSFont userFixedPitchFontOfSize:size] range:fullRange];
		[formattedNumber addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:fullRange];

		NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		if ([s rangeOfString:@"\n"].location == NSNotFound && [s rangeOfString:@"\r"].location == NSNotFound)
			[style setAlignment:NSCenterTextAlignment];
		[style setLineBreakMode: NSLineBreakByWordWrapping];

		[formattedNumber addAttribute:NSParagraphStyleAttributeName value:style range:fullRange];
		[style release];

		NSShadow *textShadow = [[NSShadow alloc] init];
		[textShadow setShadowOffset:NSMakeSize(5, -5)];
		[textShadow setShadowBlurRadius:10];
		[textShadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.64]];
		[formattedNumber addAttribute:NSShadowAttributeName value:textShadow range:fullRange];
		[textShadow release];
		
		NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, displayWidth, 0)];
		[textView setEditable:NO];
		[textView setSelectable:NO];
		[textView setDrawsBackground:NO];
		[[textView textStorage] setAttributedString:formattedNumber];
		[formattedNumber release];
		[textView sizeToFit];
		
		NSRect textFrame = [textView frame];
		
		NSLayoutManager *layoutManager = [textView layoutManager];
		unsigned numberOfLines, i, numberOfGlyphs = [layoutManager numberOfGlyphs];
		NSRange lineRange;
		float height;
		for (numberOfLines = 0, i = 0; i < numberOfGlyphs; numberOfLines++) {
			NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:i effectiveRange:&lineRange];
			height += NSHeight(rect);
			i = NSMaxRange(lineRange);
		}
		textFrame.size.height = (numberOfLines+0.1) * [layoutManager defaultLineHeightForFont:[NSFont userFixedPitchFontOfSize:size]];
		textFrame.size.height = MIN(NSHeight(screenRect) - 80, NSHeight(textFrame));
		[textView setFrame:textFrame];
		NSRect wRect = centerRectInRect(textFrame, screenRect);
		wRect = NSInsetRect(wRect, -EDGEINSET, -EDGEINSET);
		wRect = NSIntegralRect(wRect);
		QSVanishingWindow *w = [[QSVanishingWindow alloc] initWithContentRect:wRect styleMask:NSBorderlessWindowMask | NSNonactivatingPanelMask backing:NSBackingStoreBuffered defer:NO];
		[w setFrame:centerRectInRect(wRect, screenRect) display:YES];
		[w setBackgroundColor:[NSColor clearColor]];
		[w setOpaque:NO];
		[w setLevel:NSFloatingWindowLevel];

		QSBackgroundView *content = [[QSBackgroundView alloc] initWithFrame:NSZeroRect];
		[w setContentView:content];
		[textView setFrame:centerRectInRect([textView frame], [content frame])];
		[content addSubview:textView];
		[textView release];
		[content release];

		[w setAlphaValue:0];
		[w makeKeyAndOrderFront:nil];
		[w fadeToAlpha:1];

		[NSApp run];
		[pool release];
		return 0;
	}
}