#import <Foundation/Foundation.h>

// THIS SHOULD BE FOR TIGER AND BELOW

BOOL launch = YES;

BOOL dl(NSString *p, NSArray *a) {
	NSEnumerator *e = [a objectEnumerator];
	NSDictionary *d;
	while((d = [e nextObject]))
		if([[[d objectForKey:@"Path"] stringByStandardizingPath] isEqualToString:p])
			return YES;
	return NO;
}

void sl(NSString *p) {
	NSArray *tmp = (NSArray*)CFPreferencesCopyValue(CFSTR("AutoLaunchedApplicationDictionary"), CFSTR("loginwindow"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	NSMutableArray *l = tmp ? [[tmp mutableCopy] autorelease] : [NSMutableArray arrayWithCapacity:1];
	if(launch) {
		if(dl(p, tmp)) {
			fprintf(stderr, "%s already launches at login\n", [p fileSystemRepresentation]);
			return;
		} else
			[l addObject:[NSDictionary dictionaryWithObjectsAndKeys:p, @"Path", [NSNumber numberWithBool:NO] , @"Hide", nil, @"AliasData", nil]]; // is aliasdata needed here? after nil it just stops right?
	} else {
		int i;
		for(i = 0; i < [l count]; i++)
			if([[[[l objectAtIndex:i] objectForKey:@"Path"] stringByStandardizingPath] isEqualToString:p]) break;
		if(i < [l count])
			[l removeObjectAtIndex:i];
		else {
			fprintf(stderr, "%s doesn't launch at login\n", [p fileSystemRepresentation]);
			return;
		}
	}
	[tmp release];
	CFPreferencesSetValue(CFSTR("AutoLaunchedApplicationDictionary"), l, CFSTR("loginwindow"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	CFPreferencesSynchronize(CFSTR("loginwindow"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

int main(int argc, const char * argv[]) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	if (argc > 1 && strlen(argv[1]) == 2 && argv[1][0] == '-') {
		int c = argv[1][1];
		switch (c) {
			case 'r':
				launch = NO; // no break
			case 'a':
				c = 2;
				NSFileManager *f = [NSFileManager defaultManager];
				while (c < argc) {
					NSString *p = NSTR(argv[c++]);
					sl([([p isAbsolutePath] ? p : [[f currentDirectoryPath] stringByAppendingPathComponent:p]) stringByStandardizingPath]);
					[p release];
				}
				return 0;
			case 'l': {
				NSArray *l = (NSArray *)CFPreferencesCopyValue(CFSTR("AutoLaunchedApplicationDictionary"), CFSTR("loginwindow"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
				for (c = 0; c < [l count]; c++)
					puts([[[[l objectAtIndex:c] objectForKey:@"Path"] stringByStandardizingPath] fileSystemRepresentation]);
				return 0;
			}
		}
	}
	fprintf(stderr, "Usage:  %s -l\n\t%s -a <item>...\n\t%s -r <item>...\n", argv[0], argv[0], argv[0]);
	return 1;
}
