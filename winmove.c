#import <sys/types.h>
#import <sys/sysctl.h>
#import <ApplicationServices/ApplicationServices.h>
#import <stdio.h>
#import <unistd.h>

//extern CGError CGSGetWindowBounds(CGSConnectionID cid, CGSWindowID wid, CGRect *outBounds);
typedef int CGSConnectionID;
typedef int CGSWindowID;
CG_EXTERN CGSConnectionID CGSMainConnectionID(void);
CG_EXTERN CGError CGSSetUniversalOwner(CGSConnectionID cid);
CG_EXTERN CGError CGSMoveWindow(CGSConnectionID cid, CGSWindowID wid, const CGPoint *origin);
CG_EXTERN CGError CGSGetWindowBounds(CGSConnectionID cid, CGSWindowID wid, CGRect *outBounds);

CGPoint p;
bool x = false, y = false;

void mv(int w) {
	int c = CGSMainConnectionID();
	CGRect r;
	if (!CGSGetWindowBounds(c, w, &r)) {
		if (!x) p.x = r.origin.x;
		if (!y) p.y = r.origin.y;
		CGSMoveWindow(c, w, &p);
	}
}

int main (int argc, const char * argv[]) {
	if (argc < 2) {
usage:
		fprintf(stderr, "usage:  %s [-x <x-coord>] [-y <y-coord>] <wid>...\n", argv[0]);
		return 1;
	}
	int i;
	opterr = 0;
	p = CGPointZero;
	while ( (i = getopt(argc, (char**)argv, "x:y:")) > 0) {
		if (i == 'x') {
			p.x = strtof(optarg, NULL);
			x = true;
		} else if (i == 'y') {
			p.y = strtof(optarg, NULL);
			y = true;
		} else
			goto usage;
	}
	argc -= optind; argv += optind;
//	system("killall Dock 2>/dev/null");
	size_t len = 0;
	struct kinfo_proc *r = NULL;
	const int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
	if (sysctl((int *)name, 3, NULL, &len, NULL, 0) || ((r = malloc(len)) == NULL) || sysctl((int *)name, 3, r, &len, NULL, 0)) {
		perror(NULL); // MUST use |err|
		return errno;
	}
	size_t cc = len / sizeof(struct kinfo_proc);
	struct kinfo_proc *k = r;
	while (cc--) {
		if (strcmp(k->kp_proc.p_comm, "Dock") == 0)
			kill(k->kp_proc.p_pid, SIGKILL);
		k++;
	}

	CGSSetUniversalOwner(CGSMainConnectionID());
	i = 0;
	if (argc)
		while (i < argc)
			mv(strtol(argv[i++], NULL, 10));
	else
		goto usage;
	return 0;
}
