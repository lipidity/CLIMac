#import <sys/sysctl.h>
#import <sys/types.h>
#import <stdlib.h>
#import <errno.h>

int main (int argc, const char * argv[]) {
	if (argc > 1) {
		size_t len = 0;
		struct kinfo_proc *r = NULL;

		int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
		EIF (sysctl(name, 3, NULL, &len, NULL, 0) || ((r = malloc(len)) == NULL) || sysctl(name, 3, r, &len, NULL, 0), err(2, NULL));

		size_t c = len / sizeof(struct kinfo_proc);

		struct kinfo_proc *k = r;
		if (strcmp(argv[1], "-l") == 0) {
			if (argc == 2) {
//				puts("    PID Process");
				while (c--) {
					printf("%8d %s\n", k->kp_proc.p_pid, k->kp_proc.p_comm);
					k++;
				}
				return 0;
			} else if (argc == 3) {
				int retval = 1;
				while (c--) {
					if (strcmp(k->kp_proc.p_comm, argv[2]) == 0) {
						printf("%d\n", k->kp_proc.p_pid);
						retval = 0;
					}
					k++;
				}
				return retval;
			}
		} else if (argc == 2) {
			while (c--) {
				if (strcmp(k->kp_proc.p_comm, argv[1]) == 0) {
					printf("%d\n", k->kp_proc.p_pid);
					return 0;
				}
				k++;
			}
			return 1;
		}
	}
	fprintf(stderr, "usage:  %s <process-name>\n"
			"\t%s -l [<process-name>]\n", argv[0], argv[0]);
	return 1;
}
