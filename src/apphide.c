#import <ApplicationServices/ApplicationServices.h>

// todo: get hidden status; toggle; list hidden apps

int main (int argc, const char * argv[]) {
	if (argc == 1) {
		fprintf(stderr, "Usage:  %s [-s] <pid>...\n", argv[0]);
		return 1;
	}
	Boolean v;
	if ((v = (argc > 2 && strcmp(argv[1], "-s") == 0))) {
		++argv; --argc;
	}
	while (--argc) {
		++argv;
		ProcessSerialNumber n;
		GetProcessForPID((int)strtol(argv[0], NULL, 10), &n);
		ShowHideProcess(&n, v); // todo: error msg if failed
	}
	return 0;
}
