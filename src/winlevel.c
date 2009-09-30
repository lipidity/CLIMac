#import <sys/sysctl.h>
#import <ApplicationServices/ApplicationServices.h>
#import "CGSInternal/CGSInternal.h"

int main(int argc, const char *argv[]) {
	const char *levels[] = {"Base", "Minimum", "Desktop", "Backstop", "Normal", "Floating", "TornOffMenu", "Dock", "MainMenu", "Status", "ModalPanel", "PopUpMenu", "Dragging", "ScreenSaver", "Maximum", "Overlay", "Help", "Utility", "DesktopIcon", "Cursor", "AssistiveTechHigh"};
	if (argc < 2) {
usage:
		fprintf(stderr, "usage:  %s [-s <level>] <wid>\n"
				"Levels: Base Minimum Desktop Backstop Normal Floating TornOffMenu Dock MainMenu Status ModalPanel PopUpMenu Dragging ScreenSaver Maximum Overlay Help Utility DesktopIcon Cursor AssistiveTechHigh\n"
				, argv[0]);
		return 1;
	}

	CGSConnectionID cid = CGSMainConnectionID();
//	CGSWindowID wid = (int)strtol(argv[1], NULL, 10);
#if 0
	CGSConnectionID owner = 0;
	CGSSharingState sh;
	if (!((CGSGetWindowOwner(cid, wid, &owner) == 0 && owner == cid) || (CGSGetWindowSharingState(cid, wid, &sh) == 0 && sh == kCGSSharingReadWrite))) {
#endif
		size_t len = 0;
		struct kinfo_proc *r = NULL;
		int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
		if (sysctl(name, 3, NULL, &len, NULL, 0) || ((r = malloc(len)) == NULL) || sysctl(name, 3, r, &len, NULL, 0))
			err(1, NULL);
		size_t c = len / sizeof(struct kinfo_proc);
		struct kinfo_proc *k = r;
		while (c--) {
			if (strcmp(k->kp_proc.p_comm, "Dock") == 0)
				kill(k->kp_proc.p_pid, SIGKILL);
			k++;
		}
#if 0
	}
#endif

	CGSSetUniversalOwner(cid);

	CGWindowLevel level = 0;
	if ((strcmp(argv[1], "-s") == 0) && (argc > 3)) {
		char *endptr;
		level = (int)strtol(argv[2], &endptr, 10);
		if (endptr == argv[2]) {
			unsigned int i = 0;
			do {
				if (strcasecmp(argv[2], levels[i]) == 0) {
					level = CGWindowLevelForKey(i);
					break;
				}
				i += 1;
			} while (i < sizeof(levels)/sizeof(levels[0]));
			if (i == sizeof(levels)/sizeof(levels[0])) {
				fprintf(stderr, "%s: Unknown level\n", argv[2]);
				goto usage;
			}
		}
		for (int i = 3; i < argc; i++) {
			if (CGSSetWindowLevel(cid, (CGSWindowID)strtol(argv[i], NULL, 10), level) != noErr)
				warnx("%d: failed", argv[i]);
		}
	} else {
		for (int j = 1; j < argc; j++) {
			CGSGetWindowLevel(cid, (CGSWindowID)strtol(argv[j], NULL, 10), &level);
			unsigned int i = 0;
			do { // todo: option to just print number
				if (level == CGWindowLevelForKey(i)) {
					puts(levels[i]);
					break;
				}
			} while (++i < sizeof(levels)/sizeof(levels[0]));
			// TODO: if multiple wids, format |wid: level|
			if (i == sizeof(levels)/sizeof(levels[0]))
				printf("%d\n", level);
		}
	}
	return 0;
}
