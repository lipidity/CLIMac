#import <CoreServices/CoreServices.h>
#import <err.h>
#import <getopt.h>
#import <sys/stat.h>

// THIS IS ONLY FOR LEOPARD AND ABOVE

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
	const struct option longopts[] = {
		{ "add", no_argument, NULL, 'a' },
		{ "delete", no_argument, NULL, 'd' },
		{ "clear", no_argument, NULL, 'D' },
		{ "list", no_argument, NULL, 'l' },
		{ NULL, 0, NULL, 0 }
	};
	LSSharedFileListRef list = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	if (list == NULL)
		errx(1, "Couldn't retrieve list");
	UInt32 seed;
	CFArrayRef all = LSSharedFileListCopySnapshot(list, &seed);
	int c = getopt_long(argc, argv, "adrDl", longopts, NULL);
	if (argc == optind) {
		if (c == 'l') {
			for (CFIndex i = 0; i < CFArrayGetCount(all); i++) {
				CFURLRef itemURL = NULL;
				if (LSSharedFileListItemResolve((LSSharedFileListItemRef)CFArrayGetValueAtIndex(all, i), 0, &itemURL, NULL) == noErr) {
					UInt8 buffer[PATH_MAX];
					if (CFURLGetFileSystemRepresentation(itemURL, true, buffer, PATH_MAX))
						puts((char *)buffer);
					// else?
					CFRelease(itemURL);
				}
			}
			return 0;
		} else if (c == 'D') {
			return LSSharedFileListRemoveAllItems(list) == noErr;
		}
	} else if (optind < argc) {
		int j = optind;
		do {
			struct stat st = {0};
			stat(argv[j], &st);
			CFURLRef arg = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[j], strlen(argv[j]), S_ISDIR(st.st_mode));
			switch (c) {
				case 'a':
					LSSharedFileListInsertItemURL(list, kLSSharedFileListItemLast, NULL, NULL, arg, NULL, NULL);
					break;
				case 'r':
				case 'd': {
					for (CFIndex i = 0; i < CFArrayGetCount(all); i++) {
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
	fprintf(stderr, "usage:  %s -l\n\t%s [-a | -d] <item>\n\t%s -D\n", argv[0], argv[0], argv[0]);
	return 1;
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