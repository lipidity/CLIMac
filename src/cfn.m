//#import <Cocoa/Cocoa.h>
#import <libc.h>
#import <dlfcn.h>

int main(int argc, char *argv[]) {
	void *s = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
	if (s == NULL)
		errx(1, "%s", dlerror());

	void (*f)() = dlsym(s, argv[2]);
	int a[6] = {0};
	int numArgs = argc;
	switch (numArgs) {
		case 0:
			f();
			break;
		case 1:
			f(a[0]);
			break;
		case 2:
			f(a[0], a[1]);
			break;
		case 3:
			f(a[0], a[1], a[2]);
			break;
		case 4:
			f(a[0], a[1], a[2], a[3]);
			break;
		case 5:
			f(a[0], a[1], a[2], a[3], a[4]);
			break;
		case 6:
			f(a[0], a[1], a[2], a[3], a[4], a[5]);
			break;
		case 7:
			f(a[0], a[1], a[2], a[3], a[4], a[5], a[6]);
			break;
	}
	// --args 101 -p4 -p4
	return 0;
}
