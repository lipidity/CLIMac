#import <sys/mman.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <err.h>
#include <sysexits.h>

#define WRITE(PTR, LEN) EIF (fwrite((PTR), (LEN), 1, outFile) != 1, err(1, NULL));

static inline void parseAttr(char ** restrict ptrToptr, char * restrict end, bool isXHTML, FILE * restrict outFile) {
	char *ptr = *ptrToptr;
top:
	while (ptr < end && isspace(*ptr))
		++ptr;
	char *attr = ptr;
	size_t lenAttr = 0;
	while (ptr < end && !(isspace(*ptr) || *ptr == ']' || *ptr == ';'))
		++lenAttr, ++ptr;
	if (lenAttr) {
		putc_unlocked(' ', outFile);
		WRITE (attr, lenAttr);
		putc_unlocked('=', outFile);
		putc_unlocked('"', outFile);

		while (ptr < end && isspace(*ptr))
			++ptr;

		switch (*ptr) {
			case ']':
			case ';':
				WRITE (attr, lenAttr);
				putc_unlocked('"', outFile);
				if (*ptr++ == ';')
					goto top;
				break;
			default: {
				bool quoted = 0;
				do {
					char c = *ptr++;
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
								goto end;
							default:
								putc_unlocked(c, outFile);
						}
					}
				} while (ptr < end);
			}
		}
	} else if (*ptr++ == ';') {
		goto top;
	}
end:
	*ptrToptr = ptr;
}
#if 0
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
#endif
static inline void parseElem(char ** restrict ptrToptr, char * restrict end, bool isXHTML, bool compact, FILE * restrict outFile) {
	char *ptr = *ptrToptr;
	while (ptr < end && isspace(*ptr))
		++ptr;
	char *name = ptr;
	size_t lenName = 0;
	while (ptr < end && (isalnum(*ptr) || *ptr == ':'))
		++lenName, ++ptr;
	if (lenName) {
		WRITE (name, lenName);

		char *spaceAfterName = NULL;
		size_t lenSpaceAfterName = 0;

		bool selfClosed = (*ptr == '/');
		if (selfClosed) {
			++ptr;
			while (ptr < end && isspace(*ptr))
				++ptr;
		} else {
			if (*ptr == ' ')
				++ptr;
			while (ptr < end && isspace(*ptr))
				++lenSpaceAfterName, ++ptr;
			if (lenSpaceAfterName != 0)
				spaceAfterName = ptr - lenSpaceAfterName;
		}

		if (ptr < end && *ptr == '[') {
			spaceAfterName = NULL;
			++ptr;
			*ptrToptr = ptr;
			parseAttr(ptrToptr, end, isXHTML, outFile);
			ptr = *ptrToptr;
			if (ptr < end && *ptr == ' ')
				++ptr;
		}

		if (isXHTML && selfClosed) {
			putc_unlocked(' ', outFile);
			putc_unlocked('/', outFile);
		}
		putc_unlocked('>', outFile);

		if (selfClosed) {
			while (ptr < end && *ptr != '>')
				++ptr;
			++ptr;
		} else {
			if (spaceAfterName)
				WRITE (spaceAfterName, lenSpaceAfterName);
			do {
				while (ptr < end && *ptr != '<' && *ptr != '>')
					putc_unlocked(*ptr, outFile), ++ptr;
				if (*ptr == '<') {
					putc_unlocked('<', outFile);
					++ptr;
					*ptrToptr = ptr;
					parseElem(ptrToptr, end, isXHTML, compact, outFile);
					ptr = *ptrToptr;
				}
			} while (ptr < end && *ptr != '>');
			++ptr;
			putc_unlocked('<', outFile);
			putc_unlocked('/', outFile);
			WRITE (name, lenName);
			putc_unlocked('>', outFile);
		}
	} else {
#if 0
		switch (*ptr) {
			case '!': {
				int a = getc_unlocked(f), b = getc_unlocked(f);
				if (a == '-' && b == '-') {
					fputs("<!--", outFile);
					while ((c = getc_unlocked(f)) != EOF) {
						putc_unlocked(c, outFile);
						if (c == '-') {
							putc_unlocked((c = getc_unlocked(f)), outFile);
							if (c == '-') {
								putc_unlocked((c = getc_unlocked(f)), outFile);
								if (c == '>') {
									break;
								}
							}
						}
					}
				} else if (a == '[' && b == 'C') {
					char m[5];
					fread(m, 5, 1, f);
					if (strncmp("DATA[", m, 5) == 0) {
						fputs("<![CDATA[", outFile);
						while ((c = getc_unlocked(f)) != EOF) {
							putc_unlocked(c, outFile);
							if (c == ']') {
								putc_unlocked((c = getc_unlocked(f)), outFile);
								if (c == ']') {
									putc_unlocked((c = getc_unlocked(f)), outFile);
									if (c == '>') {
										break;
									}
								}
							}
						}
					} else {
						fseek(f, -7, SEEK_CUR);
						goto doctype;
					}
				} else {
doctype:
					ungetc(b, f);
					ungetc(a, f);
					putc_unlocked('<', outFile);
					putc_unlocked('!', outFile);
					while ((c = getc_unlocked(f)) != EOF && c != '>')
						putc_unlocked(c, outFile);
					putc_unlocked(c, outFile);
				}
			}
				break;
			case '?':
				while ((c = getc_unlocked(f)) != EOF) {
					putc_unlocked(c, outFile);
					if (c == '?') {
						putc_unlocked((c = getc_unlocked(f)), outFile);
						if (c == '>') {
							break;
						}
					}
				}
				break;
			case '<': {
				while ((c = getc_unlocked(f)) != EOF && isspace(c))
					;
				ungetc(c, f);
				len = 0;
				while ((c = getc_unlocked(f)) != EOF && c != '\n' && c != '\r')
					++len;
				if (len == 0)
					err(EX_DATAERR, "zero-length heredoc delimiter");
				char token[len + 1];
				readBackStr(token, len, f);
				if (getc_unlocked(f) == '\r' && (c = getc_unlocked(f)) != '\n') // crlf handling
					ungetc(c, f);
				char search[len];
				void (*pfn)(int, FILE *) = (token[0] == '&') ? &penc : (void (*)(int, FILE *))&putc_unlocked;
				do {
					while ((c = getc_unlocked(f)) != EOF && c != '\n' && c != '\r')
						pfn(c, outFile);

					int lf = 0;
					if (c == '\r' && (lf = getc_unlocked(f)) != '\n') // crlf handling
						ungetc(lf, f);

					fread(search, len, 1, f);
					int d = getc_unlocked(f);
					if (strncmp(token, search, len) == 0 && (d == '\n' || d == '\r')) {
						if (d == '\r' && (c = getc_unlocked(f)) != '\n') // crlf handling
							ungetc(c, f);
						break;
					} else {
						putc_unlocked(c, outFile);
						if (lf == '\n') // crlf handling
							putc_unlocked('\n', outFile);
						fseek(f, -1 - len, SEEK_CUR);
					}
				} while (!(feof_unlocked(f) || ferror_unlocked(f)));
			}
				break;
			default:
				err(EX_DATAERR, "bad syntax");
		}
#endif
	}
	*ptrToptr = ptr;
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
					struct stat st = {0};
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
				// Locks are retain counted,
				// Create one now so don't have to create / destroy locks all the time (eg. in fputs)
				flockfile(outFile); // no funlockfile(outFile)
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
	char *ptr = nml, *end = (nml + nml_len);
	while (ptr < end) {
		char ch = *ptr;
		putc_unlocked(ch, outFile);
		++ptr;
		if (ch == '<')
			parseElem(&ptr, end, selfClosing, compact, outFile);
	}
	return 0;
}
