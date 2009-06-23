#import <sys/select.h>
#import <sys/xattr.h>
#import <ctype.h>
#import <err.h>
#import <errno.h>
#import <getopt.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

static inline void *xmalloc(size_t n);
static inline void *xmalloc(size_t n) {
	void *r;
	if ((r = malloc(n)) == NULL)
		err(1, NULL);
	return r;
}

static int options = XATTR_NOFOLLOW;
static long gCols = 16;
static char action = '\0';

static inline void x(const char *path);
static inline void xD(const char *path);
static inline void xd(const char * restrict path, const char * restrict name);
static inline void xO(const char *path);
static void xo(const char * restrict path, const char * restrict name);
static inline void xP(const char *path);
static void xp(const char * restrict path, const char * restrict name);
static inline ssize_t xtotalsize(const char *path);
static inline ssize_t xsize(const char * restrict path, const char * restrict name);
static inline void hexdump(const unsigned char *data, size_t n);
static char **readList(size_t *n);
static unsigned char *xCopyData(const char * restrict path, const char * restrict name, ssize_t *n);
static char *xCopyList(const char *path, ssize_t *n);

int main(int argc, char *argv[]) {
	int c;
	char *attr = NULL;
	char *value = NULL;
	// todo: -s <> and -S options to get XA sizes?
	// todo: -w <> -f <> ?
	while ((c = getopt(argc, argv, "lDd:Oo:Pp:w:RCLc:h")) != EOF) {
		switch (c) {
			case 'l':
				c = 'P'; // compatibility
			case 'o':
			case 'O':
			case 'p':
			case 'P':
			case 'd':
			case 'D':
			case 'w':
				if (action) {
					warnx("You may not specify more than one `-DdOoPpw' option");
					fprintf(stderr, "Try `%s -h' for usage information\n", argv[0]);
					return 1;
				} else {
					action = c;
					if (!isupper(c)) {
						size_t l = strlen(optarg) + 1;
						attr = xmalloc(l);
						memcpy(attr, optarg, l);
					}
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
					gCols = acols;
				else
					err(1, NULL);
			} break;
			case '?':
				fprintf(stderr, "Try `%s -h' for usage information\n", argv[0]);
				return 1;
//			case 'h':
			default:
				goto usage;
		}
	}
	if ((argc -= optind) == 0) {
//		warnx("No files to act on");
usage:
		// or					 %s [-L] [-c <num>] ACTION [ARG] <file>...
		fprintf(stderr, "usage:  %s [<action>] [<options>] <file>...\n"
				"ACTIONS\n"
				" (default)\t"
				"List names of xattrs\n"
				" -p <name>\t"
				"Hexdump of data for given xattr\n"
				" -o <name>\t"
				"Output raw data for given xattr\n"
				" -d <name>\t"
				"Delete given xattr\n"
				" -w <name>\t"
				"Write xattr (data taken from stdin)\n"
				" -P, -O, -D\t"
				"Like small letter, but act on ALL xattrs\n"
				"OPTIONS\n"
				" -L\t"
				"Follow symlinks.\n"
//				" -c <n>\t"
//				"Show <n> bytes per line in hex output\n"
				" -C\t"
				"Fail if xattr exists (create)\n"
				" -R\t"
				"Fail if xattr doesn't exist (replace)\n"
				, argv[0]);
		return 1;
	}
	argv += optind;

	switch (action) {
		case '\0':
			if (argc == 1)
				x(argv[0]);
			else {
				printf("%s:\n", argv[0]);
				x(argv[0]);
				argv += 1;
				do {
					printf("\n%s:\n", argv[0]);
					x(argv[0]);
				} while (++argv, --argc);
			}
			break;
		case 'o':
			if (strcmp("-", attr) != 0) {
				if (argc == 1)
					xo(argv[0], attr);
				else {
					printf("%s:\n", argv[0]);
					xo(argv[0], attr);
					argv += 1; argc -= 1;
					do {
						printf("\n%s:\n", argv[0]);
						xo(argv[0], attr);
					} while (++argv, --argc);
				}
			} else {
				size_t n;
				char **list = readList(&n); // check
				goto oloopInit;
			oloop:
				putchar('\n');
			oloopInit:
				printf("%s:\n", argv[0]);
				for (size_t i = 0; i < n; i++) {
					printf("%s:\n", list[i]);
					xo(argv[0], list[i]);
				}
				argv += 1; argc -= 1;
				if (argc)
					goto oloop;
				// fixme: ? leaking each list item
				free(list);
			}
			break;
		case 'p':
			if (strcmp("-", attr) != 0) {
				if (argc == 1)
					xp(argv[0], attr);
				else {
					printf("%s:\n", argv[0]);
					xp(argv[0], attr);
					argv += 1; argc -= 1;
					do {
						printf("\n%s:\n", argv[0]);
						xp(argv[0], attr);
					} while (++argv, --argc);
				}
			} else {
				size_t n;
				char **list = readList(&n); // check
				goto ploopInit;
			ploop:
				putchar('\n');
			ploopInit:
				printf("%s:\n", argv[0]);
				for (size_t i = 0; i < n; i++) {
					printf("%s:\n", list[i]);
					xp(argv[0], list[i]);
				}
				argv += 1; argc -= 1;
				if (argc)
					goto ploop;
				// fixme: ? leaking each list item
				free(list);
			}
			break;
		case 'O':
			if (argc == 1)
				xO(argv[0]);
			else
				do {
					printf("%s:\n", argv[0]);
					xO(argv[0]);
				} while (++argv, --argc);
			break;
		case 'P':
			if (argc == 1)
				xP(argv[0]);
			else {
				printf("%s:\n", argv[0]);
				xP(argv[0]);
				argv += 1; argc -= 1;
				do {
					printf("\n%s:\n", argv[0]);
					xP(argv[0]);
				} while (++argv, --argc);
			}
			break;
		case 'w': { // write xattr
			// Read data from stdin
			// 4096 bytes is max size for all xattrs except resource fork
			size_t totalSize;
//			if (value == NULL) {
				value = malloc(4096);
				size_t lastReadSize = 0;
				unsigned int n = 0;
				// Accumulate data into buffer, expanding as needed
				while (value && (lastReadSize = fread(value + (n*4096), 1, 4096, stdin)) == 4096)
					value = realloc(value, (++n + 1)*4096);
				if (value == NULL)
					err(1, NULL);
				totalSize = (n*4096)+lastReadSize;
//			} else {
//				totalSize = strlen(value);
//			}
			do {
				if (setxattr(argv[0], attr, value, totalSize, 0, options) != 0)
					warn("%s", argv[0]);
			} while (++argv, --argc);
			free(value);
		}
			break;
		case 'd': // delete xattrs
			if (strcmp("-", attr) != 0) {
				do {
					xd(argv[0], attr);
				} while (++argv, --argc);
			} else {
				size_t n;
				char **list = readList(&n); // check
				do {
					for (size_t i = 0; i < n; i++)
						xd(argv[0], list[i]);
				} while (++argv, --argc);
				// fixme: ? leaking each list item
				free(list);
			}
			break;
		case 'D': // delete all XAs
			do {
				xD(argv[0]);
			} while (++argv, --argc);
			break;
	}
	free(attr);
	return (errno != 0);
}
static inline void x(const char *path) {
	ssize_t n;
	char *all = xCopyList(path, &n);
	if (all) {
		char *ptr = all;
		do {
			puts(ptr);
			ptr += strlen(ptr) + 1;
		} while (ptr < all + n);
		free(all);
	}
}
static void xo(const char * restrict path, const char * restrict name) {
	ssize_t n;
	unsigned char *data = xCopyData(path, name, &n);
	if (data) {
		if (write(STDOUT_FILENO, data, n) == n) {
			if (isatty(STDOUT_FILENO) && data[n-1] != '\n')
				putchar('\n');
		} else {
			warn("write");
		}
		free(data);
	}
}
static void xp(const char * restrict path, const char * restrict name) {
	ssize_t n;
	unsigned char *data = xCopyData(path, name, &n);
	if (data) {
		hexdump(data, n);
		free(data);
	}
}
static inline void xO(const char *path) {
	ssize_t n;
	char *all = xCopyList(path, &n);
	if (all) {
		char *ptr = all;
		do {
			printf("%s:\n", ptr);
			xo(path, ptr);
			ptr += strlen(ptr) + 1;
		} while (ptr < all + n);
		free(all);
	}
}
static inline void xP(const char *path) {
	ssize_t n;
	char *all = xCopyList(path, &n);
	if (all) {
		char *ptr = all;
		do {
			printf("%s:\n", ptr);
			xp(path, ptr);
			ptr += strlen(ptr) + 1;
		} while (ptr < all + n);
		free(all);
	}
}
static inline void xd(const char * restrict path, const char * restrict name) {
	if (removexattr(path, name, options) != 0)
		warn(NULL);
}
static inline void xD(const char *path) {
	ssize_t n;
	char *all = xCopyList(path, &n);
	if (all) {
		char *ptr = all;
		do {
			xd(path, ptr);
			ptr += strlen(ptr) + 1;
		} while (ptr < all + n);
		free(all);
	}
}


static inline ssize_t xtotalsize(const char *path) {
	ssize_t n = listxattr(path, NULL, 0, options);
	if (n == -1)
		err(1, "%s", path);
	return n;
}
static char *xCopyList(const char *path, ssize_t *n) {
	*n = xtotalsize(path);
	if (*n) {
		char *all = xmalloc(*n);
		if (listxattr(path, all, (size_t)*n, options) == *n)
			return all;
		warn("%s", path);
		free(all);
	}
	return NULL;
}
static unsigned char *xCopyData(const char * restrict path, const char * restrict name, ssize_t *n) {
	*n = xsize(path, name);
	if (*n) {
		unsigned char *data = xmalloc(*n);
		if (getxattr(path, name, data, *n, 0, options) == *n) {
			return data;
		} else {
			free(data);
			warn("%s", name);
		}
	}
	return NULL;
}
static inline ssize_t xsize(const char * restrict path, const char * restrict name) {
	ssize_t n = getxattr(path, name, NULL, 0, 0, options);
	if (n >= 0)
		return n;
	warn("%s", name);
	return 0;
}

static inline void hexdump(const unsigned char *data, size_t n) {
	size_t i = 0;
	while (i < n) {
		printf("%.2X ", data[i]);
		i += 1;
		if (i % gCols == 0) {
			putchar(' ');
			for (size_t j = i - gCols; j < i; j++)
				putchar(isprint(data[j]) ? data[j] : '.');
			putchar('\n');
		}
	}
	size_t rem = i % gCols;
	if (rem != 0) {
		for (size_t j = 0; j < gCols - rem; j++)
			fputs("   ", stdout);
		putchar(' ');
		for (size_t j = i - rem; j < i; j++)
			putchar(isprint(data[j]) ? data[j] : '.');
		putchar('\n');
	}
}

// read (newline-separated) xattr names to delete from stdin
static char **readList(size_t *size) {
	size_t n = 0;
	char **list = xmalloc(sizeof(char *) * 16);
	char *dattr;
	do {
		size_t len = 0;
		dattr = fgetln(stdin, &len);
		if (dattr != NULL) {
			BOOL newln = (dattr[len - 1] == '\n');
			if ((len > 1) || !newln) {
				list[n] = xmalloc(len + !newln);
				memcpy(list[n], dattr, len - newln);
				list[n][len - newln] = '\0';
				n += 1;
				if (n % 16 == 0) {
					if ((list = realloc(list, (n + 16) * sizeof(char *))) == NULL)
						err(1, NULL);
				}
			}
		}
	} while (dattr != NULL);
	*size = n;
	return list;
}
