/*
 * Look up words in system dictionaries
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <CoreServices/CoreServices.h>

#import "climac.h"

static void usage(FILE *);

static const struct option longopts[] = {
	{ "help", no_argument, NULL, 'h' },
	{ "version", no_argument, NULL, 'V' },

	{ NULL, 0, NULL, 0 }
};

int main(int argc, char *argv[]) {
	int c;
	while ((c = getopt_long(argc, argv, "hV", longopts, NULL)) != EOF) {
		switch (c) {
			case 'V':
				climac_version_info();
				exit(RET_SUCCESS);
			case 'h':
				usage(stdout);
				exit(RET_USAGE);
			default:
				usage(stderr);
				exit(RET_USAGE);
		}
	}

	argc -= optind;
	argv += optind;

	if (argc != 1) {
		usage(stderr);
		exit(RET_USAGE);
	}

	// following objects are leaked

	CFStringRef word = CFStringCreateWithFileSystemRepresentation(NULL, argv[0]);
	if (word == NULL)
		errx(RET_ERROR, "bad string");
	CFRange range = CFRangeMake(0, CFStringGetLength(word));

	CFStringRef def = DCSCopyTextDefinition(NULL, word, range);
	if (def != NULL) {
		CFIndex n = CFStringGetMaximumSizeOfFileSystemRepresentation(def);
		char *str = xmalloc(n);
		if (CFStringGetFileSystemRepresentation(def, str, n) == true) {
			puts(str);
			exit(RET_SUCCESS);
		}
	}
	exit(RET_FAILURE);
}

static void usage(FILE *outfile) {
	fprintf(outfile, "Usage: %s <word>\n", getprogname());
}
