/*
 * Parse a date string into a timestamp
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Foundation/Foundation.h>
#import <err.h>

#import "ret_codes.h"

int main(int argc, char *argv[]) {
	if (argc == 1)
		exit(RET_USAGE);
	id p = [NSAutoreleasePool new];
	NSMutableString *s = [[NSMutableString alloc] initWithFormat:@"%s", argv[1]];
	while ((++argv)[1])
		[s appendFormat:@" %s", argv[1]];
	id d = [NSDate dateWithNaturalLanguageString:s];
	puts([[d description] fileSystemRepresentation]);
	[s release];
	[p release];
	return RET_SUCCESS;
}
