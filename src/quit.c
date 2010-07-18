#import <Carbon/Carbon.h>

int main (int argc, const char * argv[]) {
	if (argc > 1) {
		bool relaunch = (strcmp(argv[1], "-relaunch") == 0);
		if (relaunch) {
			argc -= 1; argv += 1;
			if (argc == 1)
				goto usage;
		}
		int retval = 0;
		int i = 1;
		do {
			pid_t pid = (pid_t)strtol(argv[i], NULL, 10);
			ProcessSerialNumber p;
			if (GetProcessForPID(pid, &p) != noErr) {
				warnx("%d: invalid process", pid);
				retval = 1;
			} else {
				AppleEvent e = {typeNull, 0};
				AEBuildError o;
				OSStatus r = AEBuildAppleEvent(kCoreEventClass, kAEQuitApplication, typeProcessSerialNumber, &p, sizeof(ProcessSerialNumber), kAutoGenerateReturnID, kAnyTransactionID, &e, &o, "");
				if (r) {
					warnx("%d: event error %d", pid, (int)r);
					retval = 1;
				} else {
					FSRef f;
					if (relaunch) {
						if (GetProcessBundleLocation(&p, &f) != noErr) {
							warnx("%d: won't relaunch (can't find bundle)", pid);
							retval = 1;
						}
					}
					if (AESend(&e, NULL, kAEWaitReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL) != noErr) {
						warnx("%d: event error %d", pid, (int)r);
						retval = 1;
					}
					AEDisposeDesc(&e);
					if (relaunch && FSIsFSRefValid(&f)) {
						do {
							r = GetProcessPID(&p, &pid);
							usleep(250000);
						} while (!(r == 0 || r == -600));
//						usleep(500000);
						if (LSOpenFSRef(&f, NULL) != noErr)
							warnx("%d: couldn't relaunch", pid);
					}
				}
			}
			i += 1;
		} while (i < argc);
		return retval;
	} else {
usage:
		fprintf(stderr, "usage:  %s [-relaunch] <pid>...\n", argv[0]);
		return 1;
	}
}	
