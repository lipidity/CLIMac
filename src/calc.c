#import <stdio.h>
#import <getopt.h>

// Dubious...
enum {
	CalculateUnknown1 = 1 << 0,
//	CalculateTreatInputAsIntegers = 1 << 1,
	CalculateMoreAccurate = 1 << 2
} CalculateFlags;

int CalculatePerformExpression(char *expr, int significantDigits, int flags, char *answer);
// returns 1 on success
// answer is \n\0 terminated -- on 10.6 is only \0

static int flags = CalculateUnknown1;
static int sigFigs = 15;

static void calc(char *p, char printEquation);
static void calc(char *p, char printEquation) {
	char j[1024];
	if (CalculatePerformExpression(p, sigFigs, flags, j)) {
		if (printEquation) {
			fputs(p, stdout);
			fputs(" = ", stdout);
		}
		puts(j);
	} else {
		fprintf(stderr, "'%s': error\n", p);
	}
}

int main(int argc, char *argv[]) {
	if (argc == 1) {
usage:
		fprintf(stderr, "Usage:  %s <expression>...\n", argv[0]);
		return 1;
	}
	int c;
	while ((c = getopt(argc, argv, "as:")) != EOF) {
		switch (c) {
			case 'a':
				flags ^= CalculateMoreAccurate;
				break;
			case 's':
				sigFigs = (int)strtol(optarg, NULL, 10);
				break;
			default:
				goto usage;
		}
	}
	argv += optind; argc -= optind;
	int i = 0;
	signed char z = (argc > 1);
	do
		calc(argv[i], z);
	while (++i < argc);
	return 0;
}
