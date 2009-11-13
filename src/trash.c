/*
 * Move files to a Trash
 *
 * Using FileManager for 10.5 and newer
 *   and NSWorkspace for 10.4 down
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#define USAGE "usage:  %s [-v] <file>...\n"

int main(int argc, char *argv[]) {
	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ "verbose", no_argument, NULL, 'v' },
		{ NULL, 0, NULL, 0 }
	};
	int verbose = 0;
	int c;
	while ((c = getopt_long(argc, argv, "v", longopts, NULL)) != EOF) {
		switch (c) {
			case 'v':
				verbose ^= 1;
				break;
			case 'V':
				PRINT_VERSION;
				return 0;
			case 'h':
			default: {
			usage: ;
				bool error = (c != 'h');
				fprintf(error ? stderr : stdout, USAGE, argv[0]);
				return error;
			}
		}
	}
	if ((argc -= optind) != 0) {
		argv += optind;
		int retval = 0;
#ifndef __OBJC__
		char *dst = NULL;
#endif
		do {
#ifdef __OBJC__
			NSAutoreleasePool *pool = [NSAutoreleasePool new];
			NSString *s = [(NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[0]) autorelease];
			NSArray *file = [[[NSArray alloc] initWithObjects:[s lastPathComponent], nil] autorelease];
			if (![[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[s stringByDeletingLastPathComponent] destination:nil files:file tag:nil])
#else
			if (FSPathMoveObjectToTrashSync(argv[0], (verbose ? &dst : NULL), 0) != 0)
#endif
			{
				retval = 1;
				warn("%s", argv[0]);
			}
#ifndef __OBJC__
			else if (verbose) {
				puts(dst);
				free(dst);
			}
#endif
			argv += 1;
#ifdef __OBJC__
			[pool release];
#endif
		} while (argv[0] != NULL);
		return retval;
	} else {
		goto usage;
	}
}
