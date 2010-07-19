/*
 * Describe a bundle
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Cocoa/Cocoa.h>

#import <objc/objc-class.h>

#import "climac.h"

static inline void usage(FILE *outfile);

@implementation NSURL (p)
- (NSString *) description { return [self absoluteString]; }
@end

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
				fprintf(stderr, "Try `%s --help' for more information.\n", getprogname());
				exit(RET_USAGE);
		 }
	}
	argc -= optind;
	argv += optind;
	if (argc != 2 || strchr(argv[1], ':') != NULL) {
		 usage(stderr);
		 exit(RET_USAGE);
	}
	[NSAutoreleasePool new];
	NSURL *url = (NSURL *)CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[0], strlen(argv[0]), true);
	NSBundle *bundle = [[NSBundle alloc] initWithURL:url];
	NSString *arg = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[1]);
	SEL action = NSSelectorFromString(arg);
	if (action == NULL || ![NSBundle instancesRespondToSelector:action] || [NSObject instancesRespondToSelector:action]) {
		usage(stderr);
		exit(RET_USAGE);
	}
	id val = [bundle performSelector:action];
	puts([[val description] fileSystemRepresentation]);
	CFRelease(url);
	[bundle release];
}

static inline void usage(FILE *outfile) {
	fprintf(outfile, "Usage: %s {path | id} {property}\n", getprogname());
	fputs("Properties:\n", outfile);
	unsigned int count = 0;
	Method *methods = class_copyMethodList([NSBundle class], &count);
	const char *hide[] = {"isLoaded", "invalidateResourceCache", "unload", "load", "principalClass"};
	unsigned i = 0;
	for (unsigned int j = 0; j < count; j++) {
		SEL selector = method_getName(*methods++);
		if ([NSObject instancesRespondToSelector:selector])
			continue;
		const char *n = sel_getName(selector);
		if (n[0] != '\0' && n[0] != '_' && !index(n, ':')) {
			for (unsigned k = 0; k < sizeof(hide)/sizeof(hide[0]); k++) {
				if (strcmp(hide[k], n) == 0)
					goto end;
			}
			const char *fmt;
			switch (i) {
				case 0:
					fmt = "    %-24s";
					break;
				case 1:
					fmt = "%-24s";
					break;
				default:
					fmt = "%s";
					break;
			}
			fprintf(outfile, fmt, n);
			i = (i+1) % 3;
			if (i == 0)
				putc('\n', outfile);
		end: ;
		}
	}
	if (i != 0)
		putc('\n', outfile);
}
