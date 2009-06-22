#import <ApplicationServices/ApplicationServices.h>
#import <sys/sysctl.h>
#import "CGSInternal/CGSInternal.h"

// wintransform -rotated 45 -scale 1.1,1.1 -translate 1,2 --duration 1 <wid>
// wintransform --parallel -rotate 1.2 -scale 1.1,1.1 -translate 1,2 --duration 1 <wid>

// transforms get cleared after exit;

extern OSStatus CGSSetWindowTransform(const CGSConnectionID cid, const CGSWindowID wid, CGAffineTransform transform); 
extern OSStatus CGSGetWindowTransform(const CGSConnectionID cid, const CGSWindowID wid, CGAffineTransform * outTransform); 
extern OSStatus CGSSetWindowTransforms(const CGSConnectionID cid, CGSWindowID *wids, CGAffineTransform *transform, int n); 

int main(int argc, char *argv[]) {
	if (argc > 1) {
		CGAffineTransform t = CGAffineTransformIdentity;
		int c;
		while ((c = getopt(argc, argv, "t:")) != EOF) {
			if (c == 't') {
				switch (*optarg) {
					case 'r': {
						float f;
						if (sscanf(optarg, "rot%*[ate]d(%g)", &f) == 1) {
							t = CGAffineTransformRotate(t, (float)((double)f / 180.0 * M_PI));
							break;
						} else if (sscanf(optarg, "rot%*[ater](%g)", &f) == 1) {
							t = CGAffineTransformRotate(t, f);
							break;
						}
					}
					case 's': {
						float x, y;
						if (sscanf(optarg, "scale(%g, %g)", &x, &y) == 2) {
							t = CGAffineTransformScale(t, x, y);
							break;
						}
					}
					case 't': {
						float x, y;
						if (sscanf(optarg, "translate(%g, %g)", &x, &y) == 2) {
							t = CGAffineTransformTranslate(t, x, y);
							break;
						}
					}
					case 'i': {
						if (strcmp(optarg, "inv()") == 0 || strcmp(optarg, "invert()") == 0) {
							t = CGAffineTransformInvert(t);
							break;
						}
					}
					default:
						errx(1, "'%s': unable to parse", optarg);
				}
			} else {
				goto usage;
			}
		}
		argc -= optind; argv += optind;
		if (argc == 0)
			goto usage;

		size_t len = 0;
		struct kinfo_proc *r = NULL;
		int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
		if (sysctl(name, 3, NULL, &len, NULL, 0) || ((r = malloc(len)) == NULL) || sysctl(name, 3, r, &len, NULL, 0))
			err(1, NULL);
		size_t n = len / sizeof(struct kinfo_proc);
		struct kinfo_proc *k = r;
		while (n--) {
			if (strcmp(k->kp_proc.p_comm, "Dock") == 0)
				kill(k->kp_proc.p_pid, SIGKILL);
			k++;
		}

		CGSConnectionID cid = CGSMainConnectionID();
		CGSSetUniversalOwner(cid);

		int i = 0;
		do {
			CGSWindowID w = strtol(argv[i], NULL, 10); // check
			CGAffineTransform transform; // init
			CGSGetWindowTransform(cid, w, &transform);
			CGSSetWindowTransform(cid, w, CGAffineTransformConcat(transform, t));
			i += 1;
		} while (i < argc);
		sleep(3);
	} else {
usage:
		fprintf(stderr, "usage:  %s [-t <transform>]... <wid>...\n", argv[0]);
		return 1;
	}
}