#import <sys/select.h>
#import <sys/xattr.h>
#import <ctype.h>
#import <err.h>
#import <errno.h>
#import <getopt.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

static int options = XATTR_NOFOLLOW;
static long cols = 16;
static char action = '\0';
static signed char multiple = 0;

static void xcat(const char * restrict path, const char * restrict name);
static inline void xls(const char *path);
static inline void xrm(const char * restrict path, const char * restrict name);
static inline void xrmfr(const char *path);

int main(int argc, char *argv[]) {
	int c;
	const char *attr = NULL;
	while ((c = getopt(argc, argv, "Dlo:p:d:w:RCLc:")) != EOF) {
		switch (c) {
			case 'l':
			case 'o':
			case 'p':
			case 'd':
			case 'w':
			case 'D':
				if (action) {
					fputs("You may not specify more than one `-lopdwD' option.\n", stderr);
					goto usage;
				} else {
					action = c;
					if (c != 'l' && c != 'D')
						attr = optarg;
				}
				break;
			case 'R':
				options ^= XATTR_REPLACE;
				break;
			case 'C':
				options ^= XATTR_CREATE;
				break;
			case 'L':
				options ^= XATTR_NOFOLLOW;
				break;
			case 'c': {
				long acols = strtol(optarg, NULL, 0);
				if (acols > 0 && errno == 0)
					cols = acols;
				else
					err(1, NULL);
			} break;
			default:
				goto usage;
		}
	}
	if ((argc -= optind) == 0) {
usage:
		// or					 %s [-L] [-c <num>] ACTION [ARG] <file>...
		fprintf(stderr, "usage:  %s [<action>] [<options>] <file>...\n"
				"ACTIONS\n"
				" (default)\n"
				"    List names of xattrs associated with <file>.\n"
				" -l\n"
				"    List xattr names and data.\n"
				" -p <name>\n"
				"    Print data for given xattr (hex).\n"
				" -o <name>\n"
				"    Output data for given xattr (raw).\n"
				" -d <name>\n"
				"    Delete given xattr.\n"
				"    Pass `-' to read names from stdin.\n"
				" -w <name> [-R | -C]\n"
				"    Write xattr <name>. Data for xattr taken from stdin.\n"
				"    With `-C', fail if xattr exists (create).\n"
				"    With `-R', fail if xattr doesn't exist (replace).\n"
				" -D\n"
				"    Delete ALL xattrs associated with <file>.\n"
				"OPTIONS\n"
				" -L\n"
				"    Follow symlinks.\n"
				" -c <num>\n"
				"    Show <num> bytes per line in hex output.\n"
				, argv[0]);
		return 1;
	} else if (argc > 1) {
		multiple = 1;
	}
	argv += optind;

	switch (action) {
		case '\0':
		case 'l': // list xattrs
			do {
				xls(argv[0]);
			} while (++argv, --argc);
			break;
		case 'w': { // write xattr
			// Read data from stdin
			// 4096 bytes is max size for all xattrs except resource fork
			unsigned int n = 0;
			char *value = malloc(4096);
			size_t lastReadSize = 0;
			// Accumulate data into buffer, expanding as needed
			while (value && (lastReadSize = fread(value + (n*4096), 1, 4096, stdin)) == 4096)
				value = reallocf(value, (++n + 1)*4096);
			if (value == NULL)
				err(1, NULL);
			size_t totalSize = (n*4096)+lastReadSize;
			do {
				if (setxattr(argv[0], attr, value, totalSize, 0, options) != 0)
					perror(argv[0]);
			} while (++argv, --argc);
			free(value);
		}
			break;
		case 'd': // delete xattrs
			if (strcmp(attr, "-") == 0) {
				// read (newline-separated) xattr names to delete from stdin
				char *dattr = NULL;
				do {
					size_t len = 0;
					dattr = fgetln(stdin, &len);
					if (dattr && len > 0) {
						// null-terminate the string (replacing '\n' or '\0')
						*(dattr + len - 1) = '\0';
						if (*dattr != '\0') {
							for (int i = 0; i < argc; i++)
								xrm(argv[i], dattr);
						}
					}
				} while (dattr != NULL);
			} else {
				do {
					xrm(argv[0], attr);
				} while (++argv, --argc);
			}
			break;
		case 'D': // delete all XAs
			do {
				xrmfr(argv[0]);
			} while (++argv, --argc);
			break;
		case 'o':
		case 'p': // print xattr data
			do {
				xcat(argv[0], attr);
			} while (++argv, --argc);
			break;
	}
	return (errno != 0);
}

static void xcat(const char * restrict path, const char * restrict name)
{
	ssize_t n = getxattr(path, name, NULL, 0, 0, options);
	if (n >= 0) {
		unsigned char buf[n];
		n = getxattr(path, name, buf, n, 0, options);
		if (n >= 0) {
			// if multiple files, print filenames
			if (multiple && action == 'p') {
				fputs(path, stdout);
				puts(":");
			}
			if (action == 'o') {
				// raw data
				if (write(1, buf, n) != n)
					perror(path);
			} else {
				// print in hex
				long i = 0;
				while (i++ < n) {
					printf("%.2X ", buf[i-1]);
					if (i % cols == 0) {
						putchar(' ');
						for (long j = i - cols; j < i; j++)
							putchar(isprint(buf[j]) ? buf[j] : '.');
						putchar('\n');
					}
				}
				// pad the last row if needed
				if (--i % cols != 0) {
					for (long j = 0; j < cols - (i % cols); j++)
						fputs("   ", stdout);
					putchar(' ');
					for (long j = i - (i % cols); j < i; j++)
						putchar(isprint(buf[j]) ? buf[j] : '.');
					putchar('\n');
				}
			}
		}
	} else {
		perror(path);
	}
}

static inline void xrmfr(const char *path) {
	ssize_t n;
	// n = size of buffer needed
	n = listxattr(path, NULL, 0, options);
	if (n == 0) {
		return; // no xattrs
	} else if (n > 0) {
		char *buf = malloc(n); // could just use VA or alloca
		if (buf == NULL)
			err(1, NULL);
		n = listxattr(path, buf, n, options);
		if (n > 0) {
			char *ptr = buf;
			while (ptr < buf + n) {
				if (removexattr(path, ptr, options) != 0)
					warn("%s (%s)", path, ptr);
				ptr += strlen(ptr) + 1;
			}
		} // else?
		free(buf);
	} else {
		perror(path);
	}
}

static inline void xls(const char *path) {
	static signed char firstRun = 0;
	ssize_t n;
	// n = size of buffer needed
	n = listxattr(path, NULL, 0, options);
	if (n == 0) {
		return; // no xattrs
	} else if (n > 0) {
		char *buf = malloc(n); // could just use VA or alloca
		if (buf == NULL)
			err(1, NULL);
		n = listxattr(path, buf, n, options);
		if (n > 0) {
			if (multiple) { // print filenames
				if (firstRun)
					putchar('\n');
				else
					firstRun = 1;
				fputs(path, stdout);
				puts(":");
			}
			char *ptr = buf;
			while (ptr < buf + n) {
				puts(ptr);
				if (action == 'l') // print xattr data
					xcat(path, ptr);
				ptr += strlen(ptr) + 1;
			}
		} // else?
		free(buf);
	} else {
		perror(path);
	}
}

static inline void xrm(const char * restrict path, const char * restrict name)
{
	if (removexattr(path, name, options) != 0) {
		if (!(multiple && errno == ENOATTR))
			perror(path);
	}
}
