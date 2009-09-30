#ifdef __OBJC__

#import <Foundation/Foundation.h>

static BOOL dl(NSString *p, NSArray *a);
static void sl(NSString *p);

static BOOL launch = YES;

static BOOL dl(NSString *p, NSArray *a) {
	NSEnumerator *e = [a objectEnumerator];
	NSDictionary *d;
	while((d = [e nextObject]))
		if([[[d objectForKey:@"Path"] stringByStandardizingPath] isEqualToString:p])
			return YES;
	return NO;
}

static void sl(NSString *p) {
	NSArray *tmp = (NSArray*)CFPreferencesCopyValue(CFSTR("AutoLaunchedApplicationDictionary"), CFSTR("loginwindow"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	NSMutableArray *l = tmp ? [[tmp mutableCopy] autorelease] : [NSMutableArray arrayWithCapacity:1];
	if(launch) {
		if(dl(p, tmp)) {
			fprintf(stderr, "%s already launches at login\n", [p fileSystemRepresentation]);
			return;
		} else
			[l addObject:[NSDictionary dictionaryWithObjectsAndKeys:p, @"Path", [NSNumber numberWithBool:NO] , @"Hide", nil, @"AliasData", nil]]; // is aliasdata needed here? after nil it just stops right?
	} else {
		NSUInteger i;
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
					NSString *p = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[c++]);
					sl([([p isAbsolutePath] ? p : [[f currentDirectoryPath] stringByAppendingPathComponent:p]) stringByStandardizingPath]);
					[p release];
				}
				return 0;
			case 'l': {
				NSArray *l = (NSArray *)CFPreferencesCopyValue(CFSTR("AutoLaunchedApplicationDictionary"), CFSTR("loginwindow"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
				for (NSUInteger j = 0; j < [l count]; j++)
					puts([[[[l objectAtIndex:j] objectForKey:@"Path"] stringByStandardizingPath] fileSystemRepresentation]);
				return 0;
			}
		}
	}
	fprintf(stderr, "Usage:  %s -l\n\t%s -a <item>...\n\t%s -r <item>...\n", argv[0], argv[0], argv[0]);
	return 1;
}

#else // !__OBJC__

#import <CoreServices/CoreServices.h>
#import <err.h>
#import <getopt.h>
#import <sys/stat.h>

#if 0
	types
kLSSharedFileListFavoriteVolumes
kLSSharedFileListFavoriteItems
kLSSharedFileListRecentApplicationItems
kLSSharedFileListRecentDocumentItems
kLSSharedFileListRecentServerItems
kLSSharedFileListSessionLoginItems
kLSSharedFileListGlobalLoginItems
	property keys
kLSSharedFileListRecentItemsMaxAmount
kLSSharedFileListVolumesComputerVisible
kLSSharedFileListVolumesIDiskVisible
kLSSharedFileListVolumesNetworkVisible
	item positions
kLSSharedFileListItemBeforeFirst
kLSSharedFileListItemLast
	item property keys
kLSSharedFileListItemHidden
#endif

int main(int argc, char *argv[]) {
	bool retval = 0;
	const struct option longopts[] = {
		{ "list", no_argument, NULL, 'l' },
		{ "add", no_argument, NULL, 'a' },
		{ "remove", no_argument, NULL, 'r' },
		{ "remove-all", no_argument, NULL, 'R' },
		{ NULL, 0, NULL, 0 }
	};
	LSSharedFileListRef list = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	if (list == NULL)
		errx(1, "Couldn't retrieve list");
	UInt32 seed;
	CFArrayRef all = LSSharedFileListCopySnapshot(list, &seed);
	int c = getopt_long_only(argc, argv, "larR", longopts, NULL);
	if (argc == optind) {
		if (c == 'l') {
			for (CFIndex i = 0; i < CFArrayGetCount(all); i++) {
				CFURLRef itemURL = NULL;
				if (LSSharedFileListItemResolve((LSSharedFileListItemRef)CFArrayGetValueAtIndex(all, i), 0, &itemURL, NULL) == noErr) {
					UInt8 buffer[PATH_MAX];
					if (CFURLGetFileSystemRepresentation(itemURL, true, buffer, PATH_MAX))
						puts((char *)buffer);
					else
						retval = 1;
					CFRelease(itemURL);
				}
			}
			return retval;
		} else if (c == 'R') {
			return LSSharedFileListRemoveAllItems(list) == noErr;
		}
	} else if (optind < argc) {
		// SHOULD: '-' for stdin like xattr
		int j = optind;
		do {
			struct stat st = {0};
			stat(argv[j], &st);
			CFURLRef arg = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[j], strlen(argv[j]), S_ISDIR(st.st_mode));
			switch (c) {
				case 'a':
					LSSharedFileListInsertItemURL(list, kLSSharedFileListItemLast, NULL, NULL, arg, NULL, NULL);
					break;
				case 'r': {
					CFIndex allCount = CFArrayGetCount(all);
					CFIndex i;
					for (i = 0; i < allCount; i++) {
						CFURLRef itemURL = NULL;
						LSSharedFileListItemRef item = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(all, i);
						if (LSSharedFileListItemResolve(item, 0, &itemURL, NULL) == noErr) {
							if (CFEqual(itemURL, arg)) {
								if (LSSharedFileListItemRemove(list, item) != noErr)
									warnx("%s: Couldn't remove", argv[j]);
								CFRelease(itemURL);
								break;
							}
							CFRelease(itemURL);
						}
					}
					if (i == allCount)
						warnx("%s: No such item", argv[j]);
				} break;
				default:
					goto usage;
			}
			j += 1;
		} while (j < argc);
		return 0;
	}
	CFRelease(all);
usage:
	fprintf(stderr, "usage:  %s -l\n\t%s [-a | -r] <item>\n\t%s -R\n", argv[0], argv[0], argv[0]);
	return retval;
}
#if 0
LSSharedFileListInsertItemURL
LSSharedFileListItemMove
LSSharedFileListItemRemove
LSSharedFileListRemoveAllItems
LSSharedFileListItemCopyIconRef
LSSharedFileListItemCopyDisplayName
LSSharedFileListItemResolve
LSSharedFileListItemCopyProperty
#endif

#endif // !__OBJC__