#import <sys/sysctl.h>
#import <sys/types.h>
#import <stdlib.h>
#import <errno.h>

int main (int argc, const char * argv[]) {
	if (argc == 2) {
		size_t len = 0;
		struct kinfo_proc *r = NULL;

		int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
		if (sysctl(name, 3, NULL, &len, NULL, 0) || ((r = malloc(len)) == NULL) || sysctl(name, 3, r, &len, NULL, 0)) {
			err(1, NULL);
		}

		size_t c = len / sizeof(struct kinfo_proc);

		if (strcmp(argv[1], "-l") == 0) {
	//		puts("    PID Process");
			struct kinfo_proc *k = r;
			while (c--) {
				printf("%7d %s\n", k->kp_proc.p_pid, k->kp_proc.p_comm);
				k++;
			}
		} else {
			struct kinfo_proc *k = r;
			while (c--) {
				if (strcmp(k->kp_proc.p_comm, argv[1]) == 0) {
					printf("%d\n", k->kp_proc.p_pid);
					return 0;
				}
				k++;
			}
			errx(2, "'%s': Process not found\n", argv[1]);
		}
		return 0;
	} else {
		fprintf(stderr, "usage:  %s <process-name>\n"
				"\t%s -l\n", argv[0], argv[0]);
		return 1;
	}
}
