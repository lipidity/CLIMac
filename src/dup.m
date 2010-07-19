/*
 * Duplicate files
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Cocoa/Cocoa.h>

#import "climac.h"

static inline void usage(FILE *outfile);

int main(int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ NULL, 0, NULL, 0 }
	};

	int c;
	while ((c = getopt_long(argc, argv, "hV", longopts, NULL)) != EOF) {
		switch (c) {
			case 'V':
				climac_version_info();
				exit(RET_SUCCESS);
			case 'h':
				usage(stdout);
				exit(RET_SUCCESS);
			default:
				usage(stderr);
				exit(RET_USAGE);
		}
	}
	argc -= optind; argv += optind;

	if (argc == 0) {
		usage(stderr);
		exit(RET_USAGE);
	}

	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	NSMutableArray *urls = [[NSMutableArray alloc] initWithCapacity:argc];
	do {
		id u = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[0], strlen(argv[0]), 0);
		if (u != nil) {
			[urls addObject:u];
			CFRelease(u);
		} else {
			warnx("%s: couldn't make url", argv[0]);
		}
	} while ((++argv)[0] != NULL);

	[[NSWorkspace sharedWorkspace] duplicateURLs:urls completionHandler:(^(NSDictionary *map, NSError *error){
		if (error != nil) {
			fputs([[error localizedDescription] fileSystemRepresentation], stderr);
			fputc('\n', stderr);
			for (id u in map)
				[urls removeObject:u];
			for (id u in urls)
				fprintf(stderr, "  %s\n", [[u path] fileSystemRepresentation]);
			exit(RET_FAILURE);
		}
		exit(RET_SUCCESS);
	})];

	[[NSApplication sharedApplication] run];

	[pool release];
	exit(RET_ERROR);
}

static inline void usage(FILE *outfile) {
	fprintf(outfile, "Usage: %s <file>...\n", getprogname());
}
