#import <Cocoa/Cocoa.h>

@interface QSBackgroundView : NSView {}
@end

@interface QSVanishingWindow : NSPanel {}
- (void)fadeToAlpha:(float)a;
@end
