#import <Cocoa/Cocoa.h>
#import <histedit.h>
#import <string.h>
#import <unistd.h>
#import "goosh-fn.h"

#define NSTR(X) (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, (X))

static BOOL ecv(NSString *cmd);
char *regularPrompt(EditLine *e);
char *nestedPrompt(EditLine *e);
char *findNestings(char *prevNestings, const char *line);

static BOOL ecv(NSString *cmd) {
	static const char *lang = "en";
	NSMutableArray *c = args(cmd);
	// fixme: check for correct no of args
	NSString *x = [c objectAtIndex:0];
	unsigned ck = [c count];
	if([x hasPrefix:@"t"]) { // should do switch on first character
		if(ck < 4)
			return NO;
		NSDictionary *d = web([NSString stringWithFormat:@"language/translate?v=1.0&q=%@&langpair=%@%%7C%@", u([[c subarrayWithRange:NSMakeRange(3, ck-3)] componentsJoinedByString:@" "]), [[c objectAtIndex:1] isEqualToString:@"-"]?@"":u([c objectAtIndex:1]), u([c objectAtIndex:2])], -1);
		if(d) {
			NSDictionary *o = [d objectForKey:@"responseData"];
			if(![o isEqual:[NSNull null]]) {
				if([o objectForKey:@"detectedSourceLanguage"])
					fprintf(stderr, "Translated from: %s\n", [[o objectForKey:@"detectedSourceLanguage"] UTF8String]);
				NSPuts([o objectForKey:@"translatedText"]);
			}
		}
	} else if([x hasPrefix:@"h"]) {
		puts("translate <langFrom> <langTo> <text>...\n"
			 "lang <lang>\n"
			 "search <query>...\n"
			 "lucky <query>...\n"
			 "wiki <query>...\n"
			 "in <site> <query>...\n"
			 "news <query>...\n"
			 "blogs <query>...\n"
			 "books <query>...\n"
			 "feeds <query>...\n"
			 "goto <url>...\n"
			 "goto <result>\n"
			 "more\n"
			 "u    previous page of results\n"
			 "j    next page of results");
	} else if([x hasPrefix:@"la"]) {
		// for some reason, '>lang ' gets counted as ck == 2?
		if(ck != 2) {
			printf("ar\t bg\t ca\t zh\t zh-cn\t zh-tw\t hr\t cs\t da\t nl\t en\t et\t tl\t fi\t fr\t de\t el\t iw\t hi\t hu\t id\t it\t ja\t ko\t lv\t lt\t no\t fa\t pl\t pt-pt\t ro\t ru\t sr\t sk\t sl\t es\t sv\t th\t tr\t uk\t vi\n");
		} else
			lang = [[c objectAtIndex:1] UTF8String];
	} else if([x hasPrefix:@"s"] || [x hasPrefix:@"lu"]) {
		if(ck < 2)
			return NO;
		startIdx = 0;
		web([NSString stringWithFormat:@"search/web?v=1.0&hl=%s&q=%@", lang, u([[c subarrayWithRange:NSMakeRange(1, ck-1)] componentsJoinedByString:@" "])], [x hasPrefix:@"l"]);
	} else if([x hasPrefix:@"g"]) {
		if(ck < 2)
			return NO;
		NSString *s; NSEnumerator *e = [c objectEnumerator];
		while((s = [e nextObject])) {
			unsigned n = [s intValue];
			if(n-- && lastResult && n < [lastResult count])
				s = [[lastResult objectAtIndex:n] objectForKey:@"url"];
/*			if([s rangeOfString:@"://"].location != NSNotFound)
				s = [@"http://" stringByAppendingString:s];*/
			NSURL *url = [NSURL URLWithString:s];
			if(!url)
				NSFPuts(lastResult);
			else
				[[NSWorkspace sharedWorkspace] openURL:url];
		}
		return YES;
	} else if([x hasPrefix:@"in"]) {
		if(ck < 3)
			return NO;
sitesearch:
		startIdx = 0;
		web([NSString stringWithFormat:@"search/web?v=1.0&hl=%s&q=site:%@%%20%@", lang, u([c objectAtIndex:1]), u([[c subarrayWithRange:NSMakeRange(2, ck-2)] componentsJoinedByString:@" "])], 0);
	} else if([x hasPrefix:@"w"]) {
		[c insertObject:[NSString stringWithFormat:@"%s.wikipedia.org", lang] atIndex:1];
		ck++;
		goto sitesearch;
	} else if([x hasPrefix:@"bl"]) {
		if(ck < 2)
			return NO;
		startIdx = 0;
		web([NSString stringWithFormat:@"search/blogs?v=1.0&hl=%s&q=%@", lang, u([[c subarrayWithRange:NSMakeRange(1, ck-1)] componentsJoinedByString:@" "])], 0);
	} else if([x hasPrefix:@"bo"]) {
		if(ck < 2)
			return NO;
		startIdx = 0;
		web([NSString stringWithFormat:@"search/books?v=1.0&hl=%s&q=%@", lang, u([[c subarrayWithRange:NSMakeRange(1, ck-1)] componentsJoinedByString:@" "])], 0);
	} else if([x hasPrefix:@"n"]) {
		if(ck < 2)
			return NO;
		startIdx = 0;
		web([NSString stringWithFormat:@"search/news?v=1.0&hl=%s&q=%@", lang, u([[c subarrayWithRange:NSMakeRange(1, ck-1)] componentsJoinedByString:@" "])], 0); // &geo=Australia
	} else if([x hasPrefix:@"f"]) {
		if(ck < 2)
			return NO;
		startIdx = 0;
		NSDictionary *d = web([NSString stringWithFormat:@"feed/find?v=1.0&q=%@", u([[c subarrayWithRange:NSMakeRange(1, ck-1)] componentsJoinedByString:@" "])], -1);
		if(d) {
			NSDictionary *o = [d objectForKey:@"responseData"];
			if(![o isEqual:[NSNull null]]) {
				[lastResult release];
				lastResult = [[o objectForKey:@"entries"] retain];
				if(![lastResult count]) {
					fputs("No results\n", stderr);
					return NO;
				}
				NSEnumerator *r = [lastResult objectEnumerator]; id z;
				while((z = [r nextObject])) {
					putchar('\n');
					if(useColor)
						printf("\033[1;34m" "\033[1;4m");
					NSPuts([z objectForKey:@"title"]); // replace <b></b>
					if(useColor)
						printf("\033[1;0m" "\033[1;32m");
					NSPuts([z objectForKey:@"url"]);
					if(useColor)
						printf("\033[1;30m" "%s" "\033[1;0m\n", [[z objectForKey:@"contentSnippet"] UTF8String]);
					else
						NSPuts([z objectForKey:@"contentSnippet"]);
				}
			}
			NSFPuts([d objectForKey:@"responseDetails"]);
		}
	} else if([x hasPrefix:@"m"]) {
		NSURL *url = [NSURL URLWithString:moreLink];
		if(url)
			[[NSWorkspace sharedWorkspace] openURL:url];
	} else if([x hasPrefix:@"u"] || [x hasPrefix:@"j"]) {
		NSUInteger r = [lastQuery rangeOfString:@"&start="].location;
		if(r != NSNotFound) {
			NSString *tmp = lastQuery;
			lastQuery = [[tmp substringToIndex:r] retain];
			[tmp release];
		}
		if([x hasPrefix:@"j"])
			startIdx += 4;
		else if(startIdx == 0) {
			fputs("Can't go back further than the start.\n", stderr);
			return NO;
		} else
			startIdx -= 4;
		web([lastQuery stringByAppendingFormat:@"&start=%d", startIdx], 0);
	}
	return YES;
}

const char *defaultPrompt = "goosh> ";
const int defaultPromptLength = 7;

char *regularPrompt(EditLine *e) {
	return (char*)defaultPrompt;
}
static char *currentNestings = NULL;
static size_t currentNestingsLength = 0;
static char *currentPrompt = NULL;

char *nestedPrompt(EditLine *e) {
	if (currentPrompt)
		free(currentPrompt);

	currentPrompt = malloc(defaultPromptLength+1);
	strncpy(currentPrompt, currentNestings, currentNestingsLength);

	// pad to the length of the default prompt
	int i;
	for (i = currentNestingsLength; i < defaultPromptLength - 3; i++) {
		currentPrompt[i] = ' ';
	}

	currentPrompt[i] = ' ';
	currentPrompt[i+1] = '>';
	currentPrompt[i+2] = ' ';
	currentPrompt[i+3] = '\0';

	return currentPrompt;
}

// this should really be resizable...
#define MAX_NESTINGS_SIZE 80
char *findNestings(char *prevNestings, const char *line) {
	char *nestings = malloc(MAX_NESTINGS_SIZE * sizeof(char) );

	// if there were any previous nestings, copy them over and free the old nesting string
	char *nestChar;
	size_t nestLen;
	if (prevNestings) {
		nestLen = strlen(prevNestings);
		strncpy(nestings, prevNestings, nestLen);
		free(prevNestings);
		nestChar = nestings + nestLen - 1;
	} else {
		*nestings = '\0';
		nestChar = nestings - 1;
		nestLen = 0;
	}

	const char *lineChar = line;

	// check to see if we are inside a comment or string, which will
	// disable nesting of the other characters
	BOOL inString = (nestChar+1 != nestings && *nestChar == '\'');
	BOOL inComment = (nestChar+1 != nestings && *nestChar == '"');

	while (*lineChar) {
		// remove matching comment markers - if we're in a comment, don't try to match braces
		if (inComment && (*lineChar == '"') ) {
			inComment = NO;
			nestChar--;
			nestLen--;
		} else if (inString && (*lineChar == '\'' && (lineChar == line || *(lineChar-1) != '\\') )) {
			// same for strings
			inString = NO;
			nestChar--;
			nestLen--;
		} else {
			// remove matching characters
			if (nestLen && ((*lineChar == ')' && *nestChar == '(') || (*lineChar == '}' && *nestChar == '{') || (*lineChar == ']' && *nestChar == '[') )) {
				nestLen--;
				nestChar--;
			}

			// find beginnings of parens, braces, blocks, strings, etc and add them
			// to the nexting pairs
			if (*lineChar == '(') {
				*++nestChar = '(';
				nestLen++;
			} else if (*lineChar == '{') {
				*++nestChar = '{';
				nestLen++;
			} else if (*lineChar == '[') {
				*++nestChar = '[';
				nestLen++;
			} else if (*lineChar == '"' && !inComment) {
				*++nestChar = '"';
				inComment = YES;
				nestLen++;
			} else if (*lineChar == '\'' && !inString) {
				*++nestChar = '\'';
				inString = YES;
				nestLen++;
			}
		}
		lineChar++;
	}

	if (!nestLen) {
		free(nestings);
		return NULL;
	} else {
		return nestings;
	}
}

int main(int argc, const char *argv[]) {
	char *term = getenv("TERM");
    useColor = term && !(strcmp("xterm-color", term) && strcmp("ansi", term));
	lastResult = nil; lastQuery = nil; moreLink = nil;
	startIdx =  0;

	if(argc > 1) {
		[[NSAutoreleasePool alloc] init];
		bool a = access(argv[1], F_OK);
		if(!(a && strcmp(argv[1], "-s"))) {
			NSString *s;
			if (a) {
				s = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
			} else {
				NSString *path = NSTR(argv[1]);
				s = [[NSString alloc] initWithContentsOfFile:path];
				[path release];
			}
			NSEnumerator *e = [[s componentsSeparatedByString:@"\n"] objectEnumerator];
			[s release];
			while ((s = [e nextObject])) {
				if ([s length])
					ecv(s);
			}
			return 0;
		} else {
			fprintf(stderr, "Usage:  %s\n\t -s\n\t <file>\n", argv[0]);
			return 1;
		}
	}

	EditLine *el;
	History *myhistory;
	int count;
	const char *line;
	BOOL keepreading = YES;
	HistEvent ev;

	el = el_init("", stdin, stdout, stderr);
	el_set(el, EL_PROMPT, (&regularPrompt) );
	el_set(el, EL_EDITOR, "emacs");

	myhistory = history_init();
	if (myhistory == 0) {
		fputs("History could not be initialized\n", stderr);
		return 1;
	}

	history(myhistory, &ev, H_SETSIZE, 800);
	el_set(el, EL_HIST, history, myhistory);

	NSString *currentCommand = [[NSString alloc] init];
	while (keepreading) {
		/* count is the number of characters read.
		line is a const char* of our command line with the tailing \n */
		line = el_gets(el, &count);
		// line will be null if the user closes stdin by typing Control-D
		if (line == NULL) {
			printf("\n");
			keepreading = NO;
		} else if (count > 0) {
			/* In order to use our history we have to explicitly add commands to the history */
			history(myhistory, &ev, H_ENTER, line);
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

			NSString *lineString = [NSString stringWithCString:line encoding:NSASCIIStringEncoding];
			// add this line to the current command
			NSString *newCommand = [[NSString alloc] initWithFormat:@"%@%@", currentCommand, lineString];
			[currentCommand release];
			currentCommand = newCommand;

			char *nestings = findNestings(currentNestings, line);
			currentNestings = nestings;

			if (nestings) {
				// update the prompt
				currentNestingsLength = strlen(nestings);
				el_set(el, EL_PROMPT, (&nestedPrompt) );
			} else {
				el_set(el, EL_PROMPT, (&regularPrompt) );
				currentNestingsLength = 0;
				// check for special commands
				if ([currentCommand length] > 0) {
					if (!ecv(currentCommand)) {
						// fixme: error msg
					}
				}
				// release this command
				[currentCommand release];
				currentCommand = [[NSString alloc] init];
			}
			[pool release];
		}
	}
	history_end(myhistory);
	el_end(el);
	return 0;
}
