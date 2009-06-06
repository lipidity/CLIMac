#import "goosh-JSON.h"

#define skipWhitespace(c) while (isspace(*c)) c++
#define skipDigits(c) while (isdigit(*c)) c++

#define maxDepth 512

@implementation J

static char ctrl[0x22];

+ (void)initialize {
	ctrl[0] = '\"';
	ctrl[1] = '\\';
	int i;
	for (i = 1; i < 0x20; i++)
		ctrl[i+1] = i;
	ctrl[0x21] = 0;	
}

#pragma mark Scanner

- (id)objectWithString:(NSString*)repr {
	c = [repr UTF8String];
	depth = 0;
	id o;
	BOOL success = [self scanValue:&o];
	if (success && ![self scanIsAtEnd]) {
		fputs("Garbage after JSON fragment\n", stderr);
		success = NO;
	}
	if (success)
		return o;
	return nil;
}

- (BOOL)scanValue:(NSObject **)o {
	skipWhitespace(c);
	switch (*c++) {
		case '{':
			return [self scanRestOfDictionary:(NSMutableDictionary **)o];
			break;
		case '[':
			return [self scanRestOfArray:(NSMutableArray **)o];
			break;
		case '"':
			return [self scanRestOfString:(NSMutableString **)o];
			break;
		case 'f':
			return [self scanRestOfFalse:(NSNumber **)o];
			break;
		case 't':
			return [self scanRestOfTrue:(NSNumber **)o];
			break;
		case 'n':
			return [self scanRestOfNull:(NSNull **)o];
			break;
		case '-':
		case '0'...'9':
			c--; // cannot verify number correctly without the first character
			return [self scanNumber:(NSNumber **)o];
			break;
		case '+':
			fputs("Leading + disallowed in number\n", stderr);
			return NO;
			break;
		default:
			fputs("Unrecognised leading character\n", stderr);
			return NO;
			break;
	}
}

- (BOOL)scanRestOfTrue:(NSNumber **)o {
	if (!strncmp(c, "rue", 3)) {
		c += 3;
		*o = [NSNumber numberWithBool:YES];
		return YES;
	}
	fputs("Expected 'true'\n", stderr);
	return NO;
}

- (BOOL)scanRestOfFalse:(NSNumber **)o {
	if (!strncmp(c, "alse", 4)) {
		c += 4;
		*o = [NSNumber numberWithBool:NO];
		return YES;
	}
	fputs("Expected 'false'\n", stderr);
	return NO;
}

- (BOOL)scanRestOfNull:(NSNull **)o {
	if (!strncmp(c, "ull", 3)) {
		c += 3;
		*o = [NSNull null];
		return YES;
	}
	fputs("Expected 'null'\n", stderr);
	return NO;
}

- (BOOL)scanRestOfArray:(NSMutableArray **)o {
	if (maxDepth && ++depth > maxDepth) {
		fputs("Nested too deep\n", stderr);
		return NO;
	}

	*o = [NSMutableArray arrayWithCapacity:8];
	while(*c) {
//	for (; *c ;) {
		id v;
		skipWhitespace(c);
		if (*c == ']' && c++) {
			depth--;
			return YES;
		}
		if (![self scanValue:&v]) {
			fputs("Expected value while parsing array\n", stderr);
			return NO;
		}
		[*o addObject:v];
		skipWhitespace(c);
		if (*c == ',' && c++) {
			skipWhitespace(c);
			if (*c == ']') {
				fputs("Trailing comma disallowed in array\n", stderr);
				return NO;
			}
		}
	}
	fputs("End of input while parsing array\n", stderr);
	return NO;
}

- (BOOL)scanRestOfDictionary:(NSMutableDictionary **)o {
	if (maxDepth && ++depth > maxDepth) {
		fputs("Nested too deep\n", stderr);
		return NO;
	}
	*o = [NSMutableDictionary dictionaryWithCapacity:7];
//	for (; *c ;) {
	while (*c) {
		id k, v;
		skipWhitespace(c);
		if (*c == '}' && c++) {
			depth--;
			return YES;
		}
		if (!(*c == '\"' && c++ && [self scanRestOfString:&k])) {
			fputs("Object key string expected\n", stderr);
			return NO;
		}
		skipWhitespace(c);
		if (*c != ':') {
			fputs("Expected ':' separating key and value\n", stderr);
			return NO;
		}
		c++;
		if (![self scanValue:&v]) {
			fprintf(stderr, "Object value expected for key: %s\n", [[k description] UTF8String]);
			return NO;
		}
		[*o setObject:v forKey:k];
		skipWhitespace(c);
		if (*c == ',' && c++) {
			skipWhitespace(c);
			if (*c == '}') {
				fputs("Trailing comma disallowed in object\n", stderr);
				return NO;
			}
		}		
	}
	fputs("End of input while parsing object\n", stderr);
	return NO;
}

- (BOOL)scanRestOfString:(NSMutableString **)o {
	*o = [NSMutableString stringWithCapacity:16];
	do {
		// First see if there's a portion we can grab in one go. 
		// Doing this caused a massive speedup on the long string.
		size_t len = strcspn(c, ctrl);
		if (len) {
			// check for 
			id t = [[NSString alloc] initWithBytesNoCopy:(char*)c length:len encoding:NSUTF8StringEncoding freeWhenDone:NO];
			if (t) {
				[*o appendString:t];
				[t release];
				c += len;
			}
		}

		if (*c == '"') {
			c++;
			return YES;
		} else if (*c == '\\') {
			unichar uc = *++c;
			switch (uc) {
				case '\\':
				case '/':
				case '"':
					break;
				case 'b':   uc = '\b';  break;
				case 'n':   uc = '\n';  break;
				case 'r':   uc = '\r';  break;
				case 't':   uc = '\t';  break;
				case 'f':   uc = '\f';  break;
				case 'u':
					c++;
					if (![self scanUnicodeChar:&uc]) {
						fputs("Broken unicode character\n", stderr);
						return NO;
					}
					c--; // hack.
					break;
					default:
					fprintf(stderr, "Illegal escape sequence '0x%x'\n", uc);
					return NO;
					break;
			}
			[*o appendFormat:@"%C", uc];
			c++;
			
		} else if (*c < 0x20) {
			fprintf(stderr, "Unescaped control character '0x%x'", *c);
			return NO;
		} else {
			NSLog(@"should not be able to get here");
		}
	} while (*c);
	fputs("Unexpected EOF while parsing string\n", stderr);
	return NO;
}

- (BOOL)scanUnicodeChar:(unichar *)x {
	unichar hi, lo;
	
	if (![self scanHexQuad:&hi]) {
		fputs("Missing hex quad\n", stderr);
		return NO;		
	}
	if (hi >= 0xd800) { 	// high surrogate char?
		if (hi < 0xdc00) {  // yes - expect a low char
			if (!(*c == '\\' && ++c && *c == 'u' && ++c && [self scanHexQuad:&lo])) {
				fputs("Missing low character in surrogate pair\n", stderr);
				return NO;
			}
			if (lo < 0xdc00 || lo >= 0xdfff) {
				fputs("Invalid low surrogate char\n", stderr);
				return NO;
			}
			hi = (hi - 0xd800) * 0x400 + (lo - 0xdc00) + 0x10000;
		} else if (hi < 0xe000) {
			fputs("Invalid high character in surrogate pair\n", stderr);
			return NO;
		}
	}
	*x = hi;
	return YES;
}

- (BOOL)scanHexQuad:(unichar *)x {
	*x = 0;
	int i;
	for (i = 0; i < 4; i++) {
		unichar uc = *c;
		c++;
		int d = (uc >= '0' && uc <= '9')
		? uc - '0' : (uc >= 'a' && uc <= 'f')
		? (uc - 'a' + 10) : (uc >= 'A' && uc <= 'F')
		? (uc - 'A' + 10) : -1;
		if (d == -1) {
			fputs("Missing hex digit in quad\n", stderr);
			return NO;
		}
		*x *= 16;
		*x += d;
	}
	return YES;
}

- (BOOL)scanNumber:(NSNumber **)o {
	const char *ns = c;

	// The logic to test for validity of the number formatting is relicensed
	// from JSON::XS with permission from its author Marc Lehmann.
	// (Available at the CPAN: http://search.cpan.org/dist/JSON-XS/ .)
	if ('-' == *c)
		c++;

	if ('0' == *c && c++) {
		if (isdigit(*c)) {
			fputs("Leading 0 disallowed in number\n", stderr);
			return NO;
		}
	} else if (!isdigit(*c) && c != ns) {
		fputs("No digits after initial minus\n", stderr);
		return NO;
	} else {
		skipDigits(c);
	}
	// Fractional part
	if ('.' == *c && c++) {
		if (!isdigit(*c)) {
			fputs("No digits after decimal point\n", stderr);
			return NO;
		}
		skipDigits(c);
	}
	// Exponential part
	if ('e' == *c || 'E' == *c) {
		c++;
		if ('-' == *c || '+' == *c)
			c++;
		if (!isdigit(*c)) {
			fputs("No digits after exponent\n", stderr);
			return NO;
		}
		skipDigits(c);
	}
	id str = [[NSString alloc] initWithBytesNoCopy:(char*)ns length:c - ns encoding:NSUTF8StringEncoding freeWhenDone:NO];
	[str autorelease];
	if (str && (*o = [NSDecimalNumber decimalNumberWithString:str]))
		return YES;
	fputs("Failed creating decimal instance\n", stderr);
	return NO;
}

- (BOOL)scanIsAtEnd {
	skipWhitespace(c);
	return !*c;
}

@end
