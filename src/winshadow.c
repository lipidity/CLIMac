#include <ApplicationServices/ApplicationServices.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import "CGSInternal/CGSInternal.h"

CG_EXTERN int CGSMainConnectionID(void);
//CG_EXTERN CGError CGSSetWindowShadowAndRimParameters(const int cid, int wid, float standardDeviation, float density, int offsetX, int offsetY, unsigned int flags);
//CG_EXTERN CGError CGSGetWindowShadowAndRimParameters(const int cid, int wid, float *standardDeviation, float *density, int *offsetX, int *offsetY, unsigned int *flags);
CG_EXTERN CGError CGSGetDebugOptions(int *outCurrentOptions);
CG_EXTERN CGError CGSSetDebugOptions(int options);
CG_EXTERN CGError CGSInvalidateWindowShadow(int cid, int wid);
CG_EXTERN CGError CGSSetUniversalOwner(int cid);
#define kCGSDebugOptionNoShadows 0x4000

struct shadow {
	float s, d;
	int x, y, f;
};

int main (int argc, char *argv[]) {
	if(argc == 1) {
usage:
		fprintf(stderr, "Usage:  %s [-1 | -0]\n\t%s [-sdxyf] <wid>...\n\t%s set [-s <sd>] [-d <density>] [-x <x>] [-y <y>] [-f <flag>] <wid>...\n", argv[0], argv[0], argv[0]);
		return 1;
	}
	if (argc == 2) {
		int c;
		if (!(strcmp(argv[1], "-1") && strcmp(argv[1], "--on"))) {
			CGSGetDebugOptions(&c); // ERROR CHECKING!!!!!!!!!!!!!!!!!ERROR CHECKING!!!!!!!!!!!!!!!!!ERROR CHECKING!!!!!!!!!!!!!!!!!ERROR CHECKING!!!!!!!!!!!!!!!!!
			CGSSetDebugOptions(c & ~kCGSDebugOptionNoShadows);
			return 0;
		} else if (!(strcmp(argv[1], "-0") && strcmp(argv[1], "--off"))) {
			CGSGetDebugOptions(&c);
			CGSSetDebugOptions(c | kCGSDebugOptionNoShadows);
			return 0;
		} else if (!(strcmp(argv[1], "-s") && strcmp(argv[1], "--state"))) {
			CGSGetDebugOptions(&c);
			fprintf(stderr, "Shadows %s\n", (c & kCGSDebugOptionNoShadows) ? "off" : "on" );
			return 0;
		}
	}
	if (strcmp(argv[1], "set")==0) {
		struct shadow setit = {0}, sh = {0}; opterr = 0; argc--; argv++;
		int c;
		while((c = getopt(argc, argv, "s:d:x:y:f:")) != EOF) {
			switch(c) {
				case 's':
					sh.s = strtof(optarg, NULL); setit.s = 1.0f; break;
				case 'd':
					sh.d = strtof(optarg, NULL); setit.d = 1.0f; break;
				case 'x':
					sh.x = (int)strtol(optarg, NULL, 10); setit.x = 1; break;
				case 'y':
					sh.y = (int)strtol(optarg, NULL, 10); setit.y = 1; break;
				case 'f':
					sh.f = (unsigned int)strtoul(optarg, NULL, 10); setit.f = 1; break;
				default: goto usage;
			}
		}
		argv += optind; argc -= optind;
		if(!argc)
			goto usage;
		CGSConnectionID cid = CGSMainConnectionID();

		size_t len = 0;
		struct kinfo_proc *r = NULL;
		int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
		if (sysctl(name, 3, NULL, &len, NULL, 0) || ((r = malloc(len)) == NULL) || sysctl(name, 3, r, &len, NULL, 0))
			err(1, NULL);
		size_t num = len / sizeof(struct kinfo_proc);
		struct kinfo_proc *k = r;
		while (num--) {
			if (strcmp(k->kp_proc.p_comm, "Dock") == 0)
				kill(k->kp_proc.p_pid, SIGKILL);
			k++;
		}

		CGSSetUniversalOwner(cid);
		c = 0;
		while(c < argc) {
			CGSWindowID wid = (CGSWindowID)strtol(argv[c++], NULL, 10);
			float sd, dd; int xd, yd; unsigned int fd;
			CGSGetWindowShadowAndRimParameters(cid, wid, &sd, &dd, &xd, &yd, &fd);
			if(setit.s) sd = sh.s;
			if(setit.d) dd = sh.d;
			if(setit.x) xd = sh.x;
			if(setit.y) yd = sh.y;
			if(setit.f) fd = sh.f;
			CGSSetWindowShadowAndRimParameters(cid, wid, sd, dd, xd, yd, fd);
			CGSInvalidateWindowShadow(cid, wid);
		}
	} else {
		struct shadow setit = {0};
		int c;
		while((c = getopt(argc, (char **)argv, "sdxyf")) != EOF) {
			switch(c) {
				case 's': setit.s = 1.0f; break;
				case 'd': setit.d = 1.0f; break;
				case 'x': setit.x = 1; break;
				case 'y': setit.y = 1; break;
				case 'f': setit.f = 1; break;
				default: goto usage;
			}
		}
		argv += optind; argc -= optind;
		if(!argc)
			goto usage;
		int cid = CGSMainConnectionID();
		c = 0;
loop:
		{
			if(!(setit.s || setit.d || setit.x || setit.y || setit.f))
				setit = (struct shadow){1.0f, 1.0f, 1, 1, 1};
			int wid = (int)strtol(argv[c++], NULL, 10);
			float s, d; int x, y; unsigned int f;
			CGSGetWindowShadowAndRimParameters(cid, wid, &s, &d, &x, &y, &f);
			printf("Window ID: %d\n", wid);
			if(setit.s) printf("Std-dev:   %g\n", s);
			if(setit.d) printf("Density:   %g\n", d);
			if(setit.x) printf("X-Offset:  %d\n", x);
			if(setit.y) printf("Y-Offset:  %d\n", y);
			if(setit.f) printf("Flags:     %d\n", f);
			if(c < argc) { puts("----"); goto loop; }
		}
	}
	return 0;
}
