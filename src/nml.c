#import <sys/mman.h>
#import <sys/stat.h>

#import <ctype.h>
#import <err.h>
#import <fcntl.h>
#import <getopt.h>
#import <limits.h>
#import <stdbool.h>
#import <stdio.h>
#import <stdint.h>
#import <stdlib.h>
#import <string.h>
#import <sysexits.h>

#import "alloc.h"

#define EIF(cond, then) ((cond) ? (then) : (void)0)

#define WRITE(PTR, LEN) EIF (fwrite((PTR), (LEN), 1, outFile) != 1, err(1, NULL));

#define SEEK(N) ({ if ((ptr+=(N)) >= end) errx(1, "Syntax"); })
#define NEXTC SEEK(1ul)

static char *ptr, *end;

static inline void parseAttr(bool isXHTML, FILE *outFile) {
top: ;
	while (isspace(*ptr))
		NEXTC;
	char *attr = ptr;
	size_t lenAttr = 0;
	while (!(isspace(*ptr) || *ptr == ']' || *ptr == ';'))
		++lenAttr, NEXTC;
	if (lenAttr) {
		putc_unlocked(' ', outFile);
		WRITE (attr, lenAttr);
		putc_unlocked('=', outFile);
		putc_unlocked('"', outFile);

		while (isspace(*ptr))
			NEXTC;

		switch (*ptr) {
			case ']':
			case ';':
				WRITE (attr, lenAttr);
				putc_unlocked('"', outFile);
				if (*ptr == ';') {
					NEXTC;
					goto top;
				}
				break;
			default: {
				bool quoted = 0;
				while (1) {
					char c = *ptr;
					NEXTC;
					if (c == '"')
						quoted = !quoted;
					else if (quoted) {
						putc_unlocked(c, outFile);
					} else {
						switch (c) {
							case ';':
								putc_unlocked('"', outFile);
								goto top;
							case ']':
								putc_unlocked('"', outFile);
								return;
							default:
								putc_unlocked(c, outFile);
						}
					}
				}
			}
		}
	} else if (*ptr == ';') {
		NEXTC;
		goto top;
	}
	NEXTC;
}
static void penc(int c, FILE *out) {
	static const char * const str = "&<>";
	static const char * const rep[] = {"amp", "lt", "gt"};
	char * pos = strchr(str, c);
	if (pos == NULL) {
		putc_unlocked(c, out);
	} else {
		putc_unlocked('&', out);
		fputs(rep[(pos - str)], out);
		putc_unlocked(';', out);
	}
}
static void parseElem(bool isXHTML, bool compact, FILE *outFile) {
	NEXTC;
	while (isspace(*ptr))
		NEXTC;
	char *name = ptr;
	size_t lenName = 0;
	while (isalnum(*ptr) || *ptr == ':')
		++lenName, NEXTC;
	if (lenName) {
		putc_unlocked('<', outFile);
		WRITE (name, lenName);

		char *spaceAfterName = NULL;
		size_t lenSpaceAfterName = 0;

		bool selfClosed = (*ptr == '/');
		if (selfClosed) {
			NEXTC;
			while (isspace(*ptr))
				NEXTC;
		} else {
			if (*ptr == ' ')
				NEXTC;
			while (isspace(*ptr))
				++lenSpaceAfterName, NEXTC;
			if (lenSpaceAfterName != 0)
				spaceAfterName = ptr - lenSpaceAfterName;
		}

		if (*ptr == '[') {
			spaceAfterName = NULL;
			NEXTC;
			parseAttr(isXHTML, outFile);
			if (*ptr == ' ')
				NEXTC;
		}

		if (isXHTML && selfClosed) {
			putc_unlocked(' ', outFile);
			putc_unlocked('/', outFile);
		}
		putc_unlocked('>', outFile);

		if (selfClosed) {
			while (*ptr != '>')
				NEXTC;
		} else {
			if (spaceAfterName)
				WRITE (spaceAfterName, lenSpaceAfterName);
			do {
				while (*ptr != '<' && *ptr != '>')
					putc_unlocked(*ptr, outFile), NEXTC;
				if (*ptr == '<')
					parseElem(isXHTML, compact, outFile);
			} while (*ptr != '>');
			putc_unlocked('<', outFile);
			putc_unlocked('/', outFile);
			WRITE (name, lenName);
			putc_unlocked('>', outFile);
		}
	} else {
		NEXTC;
		switch (*(ptr - 1)) {
			case '!': {
				int a, b;
				a = *ptr; NEXTC;
				b = *ptr; NEXTC;
				if (a == '-' && b == '-') {
					fputs("<!--", outFile);
					while (1) {
						putc_unlocked(*ptr, outFile);
						if (*ptr == '-') {
							NEXTC;
							putc_unlocked(*ptr, outFile);
							if (*ptr == '-') {
								NEXTC;
								putc_unlocked(*ptr, outFile);
								if (*ptr == '>') {
									break;
								}
							}
						}
						NEXTC;
					}
				} else if (a == '[' && b == 'C') {
					if (ptr + 5 < end && bcmp("DATA[", ptr, 5) == 0) {
						SEEK(5);
						fputs("<![CDATA[", outFile);
						while (1) {
							putc_unlocked(*ptr, outFile);
							NEXTC;
							if (*ptr == ']') {
								NEXTC;
								putc_unlocked(*ptr, outFile);
								if (*ptr == ']') {
									NEXTC;
									putc_unlocked(*ptr, outFile);
									if (*ptr == '>') {
										break;
									}
								}
							}
						}
					} else {
						goto doctype;
					}
				} else {
doctype:
					ptr -= 2;
					putc_unlocked('<', outFile);
					putc_unlocked('!', outFile);
					while (*ptr != '>')
						putc_unlocked(*ptr, outFile), NEXTC;
					putc_unlocked('>', outFile);
				}
			}
				break;
			case '?':
				putc_unlocked('<', outFile);
				putc_unlocked('?', outFile);
				while (1) {
					putc_unlocked(*ptr, outFile);
					if (*ptr == '?') {
						NEXTC;
						putc_unlocked(*ptr, outFile);
						if (*ptr == '>') {
							break;
						}
					}
					NEXTC;
				}
				break;
			case '<': {
				while (isspace(*ptr))
					NEXTC;
				char *token = ptr;
				size_t len = 0;
				while (*ptr != '\n')
					++len, NEXTC;
				NEXTC;
				if (len == 0)
					err(EX_DATAERR, "zero-length heredoc delimiter");
				void (*pfn)(int, FILE *);
				if (*token == '&') {
					pfn = &penc;
					++token;
					--len;
				} else {
					pfn = (void (*)(int, FILE *))&putc_unlocked;
				}
				while (1) {
					while (*ptr != '\n')
						pfn(*ptr, outFile), NEXTC;
					NEXTC;
					char *search = ptr;
					SEEK(len - 1);
					if (bcmp(token, search, len) == 0 && ++ptr < end && *ptr == '\n') {
						break;
					} else {
						ptr -= len - 1;
						putc_unlocked('\n', outFile);
					}
				}
			}
				break;
			default:
				err(EX_DATAERR, "bad syntax");
		}
	}
	NEXTC;
}

int main(int argc, char *argv[]) {
	bool selfClosing = 0;
	bool compact = 0;
	size_t nml_len = 0;
	char *nml = NULL;
	FILE *outFile = stdout;
	int c;
	while ((c = getopt(argc, argv, "f:o:xc")) != EOF) {
		switch (c) {
			case 'f':
				if (nml != NULL)
					errx(1, "Only one %s option can be specified", "-f");
				else {
					// SHOULD: check if these three EIF's are optimized into one
					struct stat st = (struct stat){0};
					int fd = open(optarg, O_RDONLY);
					EIF (fd == -1, err(1, "%s", optarg));
					EIF (fstat(fd, &st) == -1, err(1, "%s", optarg));
					EIF (sizeof(off_t) > sizeof(size_t) && st.st_size > SIZE_MAX, errx(1, "Input file too big"));
					nml_len = (size_t) st.st_size;
					nml = mmap(NULL, nml_len, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
					EIF (nml == MAP_FAILED, err(1, "%s", optarg));
				}
				break;
			case 'o':
				if (outFile != stdout)
					errx(1, "Only one %s option can be specified", "-o");
				outFile = fopen(optarg, "w"); // FIXME: MUST: don't create/truncate file unless have output
				EIF (outFile == NULL, err(1, "%s", optarg));
				break;
			case 'x':
				selfClosing ^= 1;
				break;
			case 'c':
				compact ^= 1;
				break;
			default:
				fprintf(stderr, "usage:  %s \n", argv[0]);
				return 1;
		}
	}
	if (nml == NULL) {
		size_t lastReadCount = 0u;
		while (!ferror_unlocked(stdin) && !feof_unlocked(stdin)) {
			if (SIZE_T_MAX - nml_len < 4096ul)
				errx(1, "Input too big");
			nml_len += 4096ul;
			nml = xrealloc(nml, nml_len);
			lastReadCount = fread(nml + (nml_len - 4096u), 1u, 4096u, stdin);
		}
		EIF (ferror_unlocked(stdin), errx(1, "Read error"));
		if (nml_len != 0u)
			nml_len = nml_len - 4096ul + lastReadCount;
	}
	ptr = nml;
	end = (nml + nml_len);
	while (ptr < end) {
		if (*ptr == '<')
			parseElem(selfClosing, compact, outFile);
		else {
			if (!compact || !isspace(*ptr))
				putc_unlocked(*ptr, outFile);
			++ptr;
		}
	}
	return 0;
}
