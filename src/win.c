#import <ApplicationServices/ApplicationServices.h>
#import "CGSInternal/CGSInternal.h"

#define SCFRelease(x) if(x)CFRelease(x)

CG_EXTERN OSStatus CGSFindWindowByGeometry(CGSConnectionID cid, int zero, int one, int zero_again, CGPoint *screen_point, CGPoint *window_coords_out, int *wid_out, int *cid_out);
CG_EXTERN CGError CGSSetWindowShape(const CGSConnectionID cid, CGSWindowID wid, const float xOffset, const float yOffset, const CGSRegionObj shape);
CG_EXTERN CGPoint CGEventGetLocation(CGEventRef event);
CG_EXTERN CGError CGSGetScreenRectForWindow(CGSConnectionID cid, CGSWindowID wid, CGRect *outRect);
CG_EXTERN CGError CGSReleaseRegion(CGSRegionObj region);
CG_EXTERN CGError CGSOrderWindow(CGSConnectionID cid, CGSWindowID wid, CGSWindowOrderingMode mode, CGSWindowID relativeToWID);
CG_EXTERN CGError CGSNewWindow(CGSConnectionID cid, CGSBackingType backingType, float left, float top, CGSRegionObj region, CGSWindowID *outWID);
CG_EXTERN CGContextRef CGWindowContextCreate(CGSConnectionID cid, CGSWindowID wid, int unknown);
CG_EXTERN CGError CGSSetWindowAlpha(CGSConnectionID cid, CGSWindowID wid, float alpha);
CG_EXTERN CGError CGSSetWindowAutofill(CGSConnectionID cid, CGSWindowID wid, bool shouldAutoFill);
CG_EXTERN CGError CGSSetWindowAutofillColor(CGSConnectionID cid, CGSWindowID wid, float red, float green, float blue);

CGEventRef p(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *r);
CGEventRef p(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *r) {
	int myWid = *(int*)r, widO = 0, cidO = 0, c = CGSMainConnectionID();
	CGPoint myPoint = CGEventGetLocation(event), oP;
	CGSFindWindowByGeometry(c, 0, 1, 0, &myPoint, &oP, &widO, &cidO);
	if(type == kCGEventLeftMouseDown) {
		CGSOrderWindow(c, myWid, kCGSOrderOut, 0);
		return NULL;
	} else if(*((int*)r+1) != widO && cidO != c) {
		CGRect t; CGSRegionObj g;
		CGSGetScreenRectForWindow(c, widO, &t);
		CGSNewRegionWithRect(&t, &g);
		CGSSetWindowShape(c, myWid, 0.0f, 0.0f, g);
		CGSReleaseRegion(g);
		CGSOrderWindow(c, myWid, kCGSOrderAbove, widO);
		*((int*)r+1) = widO;
	} else if(type == kCGEventKeyUp) {
		if(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode) == 53)
			CFRunLoopStop(CFRunLoopGetCurrent());
	}
	if(type == kCGEventLeftMouseUp) {
		printf("%d\n", widO);
		if(!(GetCurrentKeyModifiers() & (shiftKey | rightShiftKey)))
			CFRunLoopStop(CFRunLoopGetCurrent());
		return NULL;
	}
	return event; // should not let mouse over affect elements. (see screencapture -i -c)
}

int main (int argc, const char * argv[]) {
	CGSConnectionID c = CGSMainConnectionID();

	if(argc > 1 && strcmp(argv[1], "-i")==0) {
		CFMachPortRef ep; CFRunLoopSourceRef es; CFRunLoopRef rl;
		int r[2];
		ep = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventKeyUp), p, r);
		if (ep == NULL) {
			fprintf(stderr, "NULL event port\n");
			return 2;
		}
		if ( (es = CFMachPortCreateRunLoopSource(NULL, ep, 0)) == NULL )
			fprintf(stderr, "No event run loop src\n");
		if ( (rl = CFRunLoopGetCurrent()) == NULL )
			fprintf(stderr, "No run loop\n");

		CGSRegionObj g; CGRect t = CGRectMake(-10,-10,10,10);
		CGSNewRegionWithRect(&t, &g);
		CGSNewWindow(c, 2, 0, 0, g, &r[0]);
		CGSSetWindowAlpha(c, r[0], 0.5f);
		CGSSetWindowAutofill(c, r[0], true);
		CGSSetWindowAutofillColor(c, r[0], 0.75f, 0.85f, 1.0f);
		CGContextRef x = CGWindowContextCreate(c, r[0], 0);
		CGContextSetRGBFillColor(x, 0.75f, 0.85f, 1.0f, 1.0f);
		CGContextFillRect(x, t);
		CGContextFlush(x);
		CGContextRelease(x);
		CGSReleaseRegion(g);
		// todo: send one event off manually so the overlay shows before waiting for an event
		// todo: disable global hotkey mode (or whatever)... see HotKeys 'shortcut textfield' source
		CFRunLoopAddSource(rl, es, kCFRunLoopDefaultMode);
		CFRunLoopRun();

		CGSReleaseWindow(c, r[0]);
	} else {
		int u = 0;

		CGSGetOnScreenWindowCount(c, kCGSNullConnectionID, &u);
		CGSWindowID *l = (CGSWindowID *)calloc(u, sizeof(CGSWindowID));
		CGSGetOnScreenWindowList(c, kCGSNullConnectionID, u, l, &u);
		printf("    WID   APP                     TITLE\n");
		int i = -1;
		while(++i < u) {
			CFTypeRef t = NULL;
			CGSGetWindowProperty(c, l[i], CFSTR("kCGSWindowTitle"), &t);
			if(!(t && CFStringGetLength(t))) t = CFSTR("-");

			CGSConnectionID o;
			CGSGetWindowOwner(c, l[i] , &o);

			CFStringRef n = NULL;
			pid_t pid = 0; ProcessSerialNumber psn = {0, kNoProcess};
			CGSConnectionGetPID(o, &pid);
			GetProcessForPID(pid, &psn);
			CopyProcessName(&psn, &n);
			if(!(n && CFStringGetLength(n))) n = CFSTR("-");
			char j[100], k[100];
			CFStringGetCString(n, j, 100, kCFStringEncodingMacRoman);
			CFStringGetCString(t, k, 100, kCFStringEncodingMacRoman);
			printf("%7d   %-21.21s   %s\n", l[i], j, k);
			SCFRelease(n);
			SCFRelease(t);
		}
	}
	return 0;
}
