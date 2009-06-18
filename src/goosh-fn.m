/*
 *  fn.c
 *  goosh
 *
 *  Created by Ankur Kothari on 5/06/08.
 *  Copyright 2008 Lipidity. All rights reserved.
 *
 */

#import "goosh-fn.h"
#import "goosh-JSON.h"

NSDictionary *web(NSString *query, int lucky) {
	NSURLResponse *r;
	NSMutableURLRequest *q = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"http://ajax.googleapis.com/ajax/services/" stringByAppendingString:query]]];
	[q setValue:@"http://example.com" forHTTPHeaderField:@"Referer"];
	NSString *s = [[NSString alloc] initWithData:[NSURLConnection sendSynchronousRequest:q returningResponse:&r error:nil] encoding:NSUTF8StringEncoding];
	J *j = [[J alloc] init];
	NSDictionary *d = [j objectWithString:s];
	[j release];
	[s release];
	if(d && lucky != -1) {
		NSDictionary *o = [d objectForKey:@"responseData"];
		if(![o isEqual:[NSNull null]]) {
			[lastResult release]; [lastQuery release]; [moreLink release];
			lastResult = [[o objectForKey:@"results"] retain];
			lastQuery = [query retain];
			moreLink = [[[[d objectForKey:@"responseData"] objectForKey:@"cursor"] objectForKey:@"moreResultsUrl"] retain];
			if(![lastResult count]) {
				fputs("No results\n", stderr);
				return nil;
			} else if(lucky == 1) {
				[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[[lastResult objectAtIndex:0] objectForKey:@"url"]]];
				return nil;
			}
			NSEnumerator *rr = [lastResult objectEnumerator]; id z;
			while((z = [rr nextObject])) {
				putchar('\n');
				if(useColor)
					printf("\033[1;34m" "\033[1;4m");
				NSPuts([z objectForKey:@"titleNoFormatting"]);
				if(useColor)
					printf("\033[1;0m" "\033[1;32m");
				if(!NSPuts([z objectForKey:@"visibleUrl"]))
					NSPuts([z objectForKey:@"postUrl"]);
				if([z objectForKey:@"authors"]) {
					if(useColor)
						printf("\033[1;30m" "by %s" "\033[1;0m\n", [[z objectForKey:@"authors"] UTF8String]);
					else
						NSPuts([z objectForKey:@"authors"]);
				}
				if([z objectForKey:@"content"]) {
					if(useColor)
						printf("\033[1;30m" "%s" "\033[1;0m\n", [[z objectForKey:@"content"] UTF8String]);
					else
						NSPuts([z objectForKey:@"content"]); // replace <b></b>
				}
				if([z objectForKey:@"publisher"]) {
					if(useColor)
						printf("\033[1;30m" "%s" "\033[1;0m\n", [[z objectForKey:@"publisher"] UTF8String]);
					else
						NSPuts([z objectForKey:@"publisher"]);
				}
			}
			putchar('\n');
		}
		NSFPuts([d objectForKey:@"responseDetails"]);
	}
	return d;
}

NSString *u(NSString *r) {
	//	CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)r, CFSTR("")))
	return [(NSString *)(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)r, NULL, CFSTR(" =+?"), kCFStringEncodingUTF8)) autorelease];
}

BOOL NSPuts(id o) {
	if(o && ![o isEqual:[NSNull null]]) {
		puts([[o description] UTF8String]);
		return YES;
	}
	return NO;
}
BOOL NSFPuts(id o) {
	if(o && ![o isEqual:[NSNull null]]) {
		fprintf(stderr, "%s\n", [[o description] UTF8String]);
		return YES;
	}
	return NO;
}

NSMutableArray *args(NSString *s) {
	NSMutableArray *a = [[NSMutableArray alloc] initWithCapacity:3];
	char **ap, *argv[5], *inputstring = (char *)[s UTF8String];
	ap = argv;
	while ((*ap = strsep(&inputstring, " \t")) != NULL) {
		if (**ap != '\0') {
			[a addObject:[NSString stringWithUTF8String:*ap]];
			if (++ap >= &argv[5])
				ap = argv;
		}
	}
	NSString *t = [a lastObject];
	if([t hasSuffix:@"\n"])
		[a replaceObjectAtIndex:[a count]-1 withObject:[t substringToIndex:[t length]-1]];
	return a;
}
