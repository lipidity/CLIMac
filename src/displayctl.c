#import "CGSInternal/CGSInternal.h"
#import <ApplicationServices/ApplicationServices.h>
#import <unistd.h>
#import <stdio.h>

#if 0
#import <ApplicationServices/ApplicationServices.h>
#import <unistd.h>

int main (int argc, const char * argv[]) {
	int c;
	opterr = 0;
	float d = 1.0f, a = 0.0f;
	float rgb[3] = {1.0f, 1.0f, 1.0f};
	while ((c = getopt(argc, (char **)argv, "a:d:c:")) != EOF) {
		switch (c) {
			case 'd': d = strtof(optarg, NULL); break;
			case 'a': a = strtof(optarg, NULL); break;
			case 'c': sscanf(optarg, "%g %g %g", &rgb[0], &rgb[1], &rgb[2]); break;
			default:
				fprintf(stderr, "Usage:  %s [-d <duration>] [-c '<r> <g> <b>']\n", argv[0]);
				return 1;
		}
	}
	if (!a)
		a = d = d / 2.0f;
	CGDisplayFadeReservationToken token;
	if (CGAcquireDisplayFadeReservation(a+d+1.0f, &token) == kCGErrorSuccess) {
		CGDisplayFade(token, a, kCGDisplayBlendNormal, kCGDisplayBlendSolidColor, rgb[0], rgb[1], rgb[2], true);
		CGDisplayFade(token, d, kCGDisplayBlendSolidColor, kCGDisplayBlendNormal, rgb[0], rgb[1], rgb[2], false);
		CGReleaseDisplayFadeReservation(token);
	} else {
		fputs("Error: Couldn't acquire display.\n", stderr);
	}
	return 0;
}

#include <ApplicationServices/ApplicationServices.h>
#include <string.h>

/*! Gets whether the display is zoomed. I'm not sure why there's two calls that appear to do the same thing - I think CGSIsZoomed calls through to CGSDisplayIsZoomed. */
CG_EXTERN bool CGSDisplayIsZoomed(void);
CG_EXTERN CGError CGSIsZoomed(int cid, bool *outIsZoomed);
//CG_EXTERN CGError CGSGetZoomParameters(int cidq, int *r29, int *r28, int *r27);

/*! Gets and sets the cursor scale. The largest the Universal Access prefpane allows you to go is 4.0. */
CG_EXTERN CGError CGSGetCursorScale(int cid, float *outScale);
CG_EXTERN CGError CGSSetCursorScale(int cid, float scale);

/*! Gets and sets the state of screen inversion. */
CG_EXTERN bool CGDisplayUsesInvertedPolarity(void);
CG_EXTERN void CGDisplaySetInvertedPolarity(bool invertedPolarity);

/*! Gets and sets whether the screen is grayscale. */
CG_EXTERN bool CGDisplayUsesForceToGray(void);
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);

/*! Sets the display's contrast. There doesn't seem to be a get version of this function. */
CG_EXTERN CGError CGSSetDisplayContrast(float contrast);

#if 0

todo:
voiceover

access -s ... to set prefs in default database com.apple.universalaccess
contrast:	contrast
cursor:		mouseDriverCursorSize
voiceover:	voiceOverOnOffKey, voiceOverOnOffKey
keyboard:	stickyKey, stickyKeyShowWindow, stickyKeyBeepOnModifier, slowKey, useStickyKeysShortcutKeys, slowKeyDelay, slowKeyBeepOn, 
mouse:		mouseDriverInitialDelay, mouseDriverMaxSpeed, useMouseKeysShortcutKeys, mouseDriverIgnoreTrackPad, mouseDriverPrevOptionKeyToggle
zoomin:		closeViewNearPoint, closeViewFarPoint, closeViewSmoothImages, closeViewZoomFollowsFocus, closeViewPanningMode, closeViewDriver, closeViewZoomFactor
#endif

#else

int main (int argc, const char * argv[]) {
	if (argc == 1) {
	usage:
		// todo: thingy 1/0/t
		fprintf(stderr, "Usage:  %s\n\t[invert 1/0] [gray 1/0] [contrast <contrast>] [cursor <scale>]\n\t-g [invert | gray | cursor]\n"
				"Example: %s invert 1 contrast 0.5\n", argv[0], argv[0]);
	} else {
		if (strcmp(argv[1], "-g") == 0) {
			++argv; --argc;
			while (++argv, --argc) {
				if (strcmp(argv[0], "invert") == 0)
					putchar('0' + CGDisplayUsesInvertedPolarity());
				else if (strcmp(argv[0], "gray") == 0)
					putchar('0' + CGDisplayUsesForceToGray());
				else if (strcmp(argv[0], "contrast") == 0)
					puts("Unsure");
				else if (strcmp(argv[0], "cursor") == 0) {
					float scale;
					CGSGetCursorScale(CGSMainConnectionID(), &scale);
					printf("%g", scale);
				} else
					goto usage;
				putchar('\n');
			}
		} else if (argc & 0x1) { // odd argc means even arguments
			int i = 0;
			while (i < (argc - 2)) {
				const char *thing = argv[++i], *arg = argv[++i];
				if (arg[0] == '\0')
					continue;
				if (strcmp(thing, "invert") == 0)
					CGDisplaySetInvertedPolarity((arg[0] == '1'));
				else if (strcmp(thing, "gray") == 0)
					CGDisplayForceToGray((arg[0] == '1'));
				else if (strcmp(thing, "cursor") == 0)
					CGSSetCursorScale(CGSMainConnectionID(), strtof(arg, NULL));
				else if (strcmp(thing, "contrast") == 0)
					CGSSetDisplayContrast(strtof(arg, NULL));
			}
		} else
			goto usage;
	}
	return 0;
}

#endif