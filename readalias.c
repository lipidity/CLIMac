#include <Carbon/Carbon.h>
#include <unistd.h>

Boolean f = 0;

static Boolean p(const UInt8 *path) {
	// FIX: convert to / from FSRef and CFURLRef
	FSRef ref;
	FSPathMakeRef(path, &ref, NULL);
	Boolean wasAlias = 0, isDir = 0;
	()FSResolveAliasFile(&ref, f, &isDir, &wasAlias);
	if (wasAlias) {
		UInt8 filepath[PATH_MAX];
		FSRefMakePath(&ref, (UInt8*)&filepath, PATH_MAX);
		puts((char*)filepath);
		return 1;
	} else
		return 0;
}

int main(int argc, const char *argv[]) {
	if (argc == 1) {
usage:
		fprintf(stderr, "Usage:  %s [-f] <path>...\n", argv[0]);
		return 1;
	}
	int c = 0;
	while ((c = getopt(argc, (char **)argv, "f")) != EOF) {
		switch (c) {
			case 'f':
				f ^= 1;
				break;
			default:
				goto usage;
		}
	}
	argc -= optind; argv += optind;

	Boolean err = 0;
	while (argc--) {
		err |= p((UInt8 *) ((argv++)[0]));
	}
    return !err;
}
