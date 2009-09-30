#import <sys/types.h>
#import <sys/sysctl.h>
#import <ApplicationServices/ApplicationServices.h>
#import <stdio.h>
#import <unistd.h>
#import "CGSInternal/CGSInternal.h"

CG_EXTERN CGError CGSGetWindowBounds(CGSConnectionID cid, CGSWindowID wid, CGRect *outBounds);

int main (int argc, char *argv[]) {
	if (argc == 1) {
usage:
		fprintf(stderr, "usage:  %s [-x <x-coord>] [-y <y-coord>] <wid>...\n", argv[0]);
		return 1;
	}
	CGPoint p = CGPointZero;
	bool xset = 0, yset = 0;
	int i;
	while ((i = getopt(argc, argv, "x:y:")) != EOF) {
		if (i == 'x') {
			p.x = strtof(optarg, NULL);
			xset = 1;
		} else if (i == 'y') {
			p.y = strtof(optarg, NULL);
			yset = 1;
		} else
			goto usage;
	}
	argc -= optind; argv += optind;

	size_t len = 0;
	struct kinfo_proc *r = NULL;
	int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
	if (sysctl(name, 3, NULL, &len, NULL, 0) || ((r = malloc(len)) == NULL) || sysctl(name, 3, r, &len, NULL, 0))
		err(1, NULL);
	size_t cc = len / sizeof(struct kinfo_proc);
	struct kinfo_proc *k = r;
	while (cc--) {
		if (strcmp(k->kp_proc.p_comm, "Dock") == 0)
			kill(k->kp_proc.p_pid, SIGKILL);
		k++;
	}

	CGSConnectionID cid = CGSMainConnectionID();
	CGSSetUniversalOwner(cid);
	i = 0;
	if (argc)
		while (i < argc) {
			CGSWindowID w = (CGSWindowID)strtol(argv[i++], NULL, 10);
			CGRect rect;
			if (CGSGetWindowBounds(cid, w, &rect) == noErr) {
				if (!xset) p.x = rect.origin.x;
				if (!yset) p.y = rect.origin.y;
				CGSMoveWindow(cid, w, &p);
			}
		}
	else
		goto usage;
	return 0;
}
