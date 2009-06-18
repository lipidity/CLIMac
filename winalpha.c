#import <sys/types.h>
#import <sys/sysctl.h>
#import <ApplicationServices/ApplicationServices.h>
#import <unistd.h>

float alpha = 0.8, duration = 3.0;

void fade(int wid) {
	float x, t; int c = CGSMainConnectionID();
	CGSGetWindowAlpha(c, wid, &x);
	t = duration * 1000000 / (fabsf(x - alpha) / 0.008);
	while ((x -= 0.008) > alpha) {
		CGSSetWindowAlpha(c, wid, x); usleep(t);
	}
	while ((x += 0.008) < alpha) {
		CGSSetWindowAlpha(c, wid, x); usleep(t);
	}
	CGSSetWindowAlpha(c, wid, alpha);
}

#define str2f(x) strtof(x, NULL)

int main (int argc, const char * argv[]) {
	if (argc < 2) {
error:
		fprintf(stderr, "Usage:  %s [-a <alpha>] [-d <duration>] [<wid>...]\n", argv[0]); return 1;
	}

	CGSConnectionID d = CGSMainConnectionID();
	int c;
	opterr = 0;
	while ((c = getopt(argc, (char**)argv, "a:d:")) > 0) {
		switch(c) {
			case 'a': alpha = str2f(optarg); break;
			case 'd': duration = str2f(optarg); break;
			default: goto error; break;
		}
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

	CGSSetUniversalOwner(d);

	if (argc) {
		int i = 0;
		while (i < argc)
			fade((int)strtol(argv[i++],NULL,10));
	} else {
		int windowCount = 0, lastErr = noErr;
		CGSWindowID *windowList;

		lastErr = CGSGetOnScreenWindowCount(d, kCGSNullConnectionID, &windowCount);
		assert(!lastErr && "Error getting the on screen window count.");

		windowList = (CGSWindowID*)calloc(windowCount, sizeof(CGSWindowID));
		assert(windowList && "Error allocating window list.");

		lastErr = CGSGetOnScreenWindowList(d, kCGSNullConnectionID, windowCount, windowList, &windowCount);
		assert(!lastErr && "Error getting on screen window list.");

		CGSSetWindowListAlpha(d, windowList, windowCount, alpha, duration);
		free(windowList);
	}
	CGSWindowID backgroundWID = 0;
	CGSGetSystemBackgroundWindow(d, CGSMainDisplayID(), &backgroundWID);
	CGSSetWindowAlpha(d, backgroundWID, 1.0);	
	return 0;
}
