//#import <Cocoa/Cocoa.h>
#import <libc.h>
#import <dlfcn.h>

int main(int argc, char *argv[]) {
	void *s = dlopen(argv[1], RTLD_LAZY | RTLD_LOCAL);
	if (s == NULL)
		errx(1, "%s", dlerror());
	printf("%p\n", dlsym(s, argv[2]));
	// --args 101 -p4 -p4
	return 0;
}
