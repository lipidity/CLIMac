/*
 * Describe and manipulate running applications
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Cocoa/Cocoa.h>

#import <objc/objc-class.h>

#import "climac.h"

static inline void usage(FILE *);

@implementation NSURL (p)
- (NSString *) description { return [self absoluteString]; }
@end

@implementation NSRunningApplication (appr)
- (pid_t) pid { return [self processIdentifier]; }
- (id) activate { return [NSNumber numberWithBool:[self activateWithOptions:NSApplicationActivateIgnoringOtherApps]]; }
@end

int main(int argc, char *argv[]) {
	[NSAutoreleasePool new];

	const struct option longopts[] = {
		{ "help", no_argument, NULL, 'h' },
		{ "version", no_argument, NULL, 'V' },

		{ "current", no_argument, NULL, 'c' },
		{ "all", no_argument, NULL, 'l' },
		{ "pid", required_argument, NULL, 'i' },
		{ "bundle", required_argument, NULL, 'b' },
		{ NULL, 0, NULL, 0 }
	};

	NSMutableSet *apps = [NSMutableSet new];
	int c;
	bool null_terminate = 0;
	while ((c = getopt_long(argc, argv, "hV" "cli:b:" "0", longopts, NULL)) != EOF) {
		switch (c) {
			case 'l':
				[apps addObjectsFromArray:[[NSWorkspace sharedWorkspace] runningApplications]];
				break;
			case 'c': {
				NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:[[[[NSWorkspace sharedWorkspace] activeApplication] valueForKey:@"NSApplicationProcessIdentifier"] unsignedIntValue]];
				if (app)
					[apps addObject:app];
			}	break;
			case 'i': {
				char *endptr = optarg;
				pid_t pid = (pid_t)strtoul(optarg, &endptr, 10);
				if (*endptr != '\0') {
					warnx("invalid process ID: %s", optarg);
					fprintf(stderr,  "Try `%s --help' for more information.\n", getprogname());
					exit(RET_USAGE);
				}
				NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
				if (app)
					[apps addObject:app];
			}	break;
			case 'b': {
				NSString *bid = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, optarg);
				NSArray *found_apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bid];
				CFRelease(bid);
				[apps addObjectsFromArray:found_apps];
			}	break;
			case '0':
				null_terminate = 1;
				break;
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

	if ([apps count] == 0) {
		warnx("no matching applications");
		if (optind == 1) {
			fprintf(stderr, "Try `%s --help' for more information.\n", getprogname());
			exit(RET_USAGE);
		} else {
			exit(RET_FAILURE);
		}
	}

	NSString *arg;
	if (argc == 0) {
		usage(stderr);
		exit(RET_USAGE);
	} else {
		char *act = argv[0];
		size_t len = strlen(act);
		if (len == 0) {
			usage(stderr);
			exit(RET_USAGE);
		}
	try_is_prefix:
		arg = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, act);
		SEL action = NSSelectorFromString(arg);
		if (action == NULL || ![NSRunningApplication instancesRespondToSelector:action] || [NSObject instancesRespondToSelector:action]) {
			if (act == argv[0]) {
				char *new = malloc(len+3);
				new[0] = 'i';
				new[1] = 's';
				strcpy(new + 2, act);
				new[2] = new[2] & ~0x20;
				act = new;
				[arg release];
				goto try_is_prefix;
			}
			usage(stderr);
			exit(RET_USAGE);
		}
	}

	NSArray *val = [apps valueForKey:arg];
	if (null_terminate == 0)
		for (id i in val)
			puts([[i description] fileSystemRepresentation]);
	else
		for (id i in val)
			printf("%s%c", [[i description] fileSystemRepresentation], '\0');

	[arg release];
	[apps release];
	exit(RET_SUCCESS);
}

static inline void usage(FILE *outfile) {
	fprintf(outfile, "Usage: %s {property | action} {-c | -l | -i <PID> | -b <BID>}\n", getprogname());
	struct {
		const char *opt;
		const char *exp;
	} u[] = {
		{ "c" "current",		"frontmost app"},
		{ "l" "all",			"all running apps"},
		{ "i" "pid=<PID>",		"app with process ID"},
		{ "b" "bundle-id=<BID>","app with bundle ID"},
	};
	for (unsigned j = 0; j < sizeof(u)/sizeof(u[0]); j++)
		fprintf(outfile, "    -%c, --%-22s%s\n", u[j].opt[0], u[j].opt + 1, u[j].exp);
	fputs("Actions:\n", outfile);
	unsigned int count = 0;
	Method *methods = class_copyMethodList([NSRunningApplication class], &count);
	const char *hide[] = {"dealloc", "applyPendingPropertyChanges", "observationInfo", "description", "applicationSerialNumber"};
	unsigned i = 0;
	for (unsigned int j = 0; j < count; j++) {
		const char *n = sel_getName(method_getName(*methods++));
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
