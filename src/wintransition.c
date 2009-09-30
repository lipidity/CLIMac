#import <sys/sysctl.h>
#import <ApplicationServices/ApplicationServices.h>
#import "CGSInternal/CGSInternal.h"
CG_EXTERN CGError CGSGetSystemBackgroundWindow(CGSConnectionID, CGDirectDisplayID, CGSWindowID *);

int main(int argc, char * argv[]) {
	if (argc == 1) {
usage:
		fprintf(stderr, "usage:  %s <options> <wid>...\n\n"
				"options:\n"
				"\t[-e <effect>] [-o <flag>] [-d <duration>] [-c'<r> <g> <b>']\n"
				"effects:\n"
				"\tfade, zoom, reveal, slide, warpfade, swap, cube, warpswitch, flip\n"
				"flags:\n"
				"\tleft, right, down, up, center, reverse, transparent\n", argv[0]);
		return 1;
	}

	struct option longopts[] = {
		{ "effect",  required_argument, NULL, 'e' },
		{ "option",  required_argument, NULL, 'o' },
		{ "duration",required_argument, NULL, 'd' },
		{ "color",   required_argument, NULL, 'c' },
		{ NULL, 0, NULL, 0 }
	};

	float duration = 1.0f;
	CGSWindowID backgroundWID = 0;
	bool universal = false;
	CGSTransitionSpec spec = { 0, 7, 0, 0, NULL };

	int g;
	const char *x[9] = {"fade", "zoom", "reveal", "slide", "warpfade", "swap", "cube", "warpswitch", "flip"};
	const char *z[8] = {"left", "right", "down", "up", "center", "reverse", "", "transparent"};
	while ((g = getopt_long(argc, argv, "e:o:d:c:", longopts, NULL)) != EOF) {
		switch (g) {
			case 'e': {
				unsigned int i = 0;
				do {
					if (strcasecmp(optarg, x[i])==0) {
						spec.type = (i+1);
						break;
					}
					i += 1;
				} while(i < sizeof(x)/sizeof(x[0]));
				break;
			}
			case 'o': {
				unsigned int i = (unsigned int)strtoul(optarg, NULL, 10);
				if (i != 0) {
					spec.options ^= (1<<i);
				} else {
					// i == 0 here due to if condition
					do {
						if (strcasecmp(z[i], optarg)==0) {
							spec.options ^= (1<<i);
							break;
						}
						i += 1;
					} while (i < sizeof(z)/sizeof(z[0]));
				}
				break;
			}
			case 'd': {
				char *end = NULL;
				duration = strtof(optarg, &end);
				if (end == optarg)
					errx(1, "`-%c' should have a float argument", 'd');
				break;
			}
			case 'c': {
				float c[3] = {0.0f, 0.0f, 0.0f};
				if (sscanf(optarg, "%g %g %g", &(c[0]), &(c[1]), &(c[2])) == 3)
					spec.backColor = c;
				else
					errx(1, "invalid argument to `-c' option");
				break;
			}
			default: goto usage;
		}
	}
	argc -= optind; argv += optind;

	if (argc) {
		CGSGetSystemBackgroundWindow(CGSMainConnectionID(), CGSMainDisplayID(), &backgroundWID);
		int i = 0;
		do {
			CGSWindowID w = (CGSWindowID)strtol(argv[i], NULL, 10);
			CGSTransitionID transition = 0;
			CGSConnectionID cid = CGSMainConnectionID();
			if (w == backgroundWID || w == 0) {
				spec.wid = 0;
			} else {
				if (!universal) {
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
					CGSSetUniversalOwner(cid);
					universal = true;
				}
				spec.wid = w;
			}
			CGSNewTransition(cid, &spec, &transition);
			CGSInvokeTransition(cid, transition, duration);
			usleep(duration*1000000.0f);
			CGSReleaseTransition(cid, transition);
			i += 1;
		} while (i < argc);
	} else {
		goto usage;
	}
	return 0;
}
