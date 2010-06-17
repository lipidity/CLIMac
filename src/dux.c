/*
 * directory "size"
 * gcc -std=c99 -framework CoreServices -o duh duh.c
 */
// /usr/ 53389 items, 2127426494 bytes, 2515776 blocks, 21938 bytes xattr

// this is slower than du -s
// try getting multiple catinfos at once (was failing before...)

#import <CoreServices/CoreServices.h>
#include <inttypes.h>

#import "alloc.h"

struct sizes {
	off_t count;
	off_t logical, physical;
	off_t rsrc_logical, rsrc_physical;
};

void ff(FSRef *aref, int level, struct sizes *s);
void ff(FSRef *aref, int level, struct sizes *s) {
    FSIterator iterator = NULL;

    if (FSOpenIterator(aref, kFSIterateFlat, &iterator) == noErr) {
		FSCatalogInfo cat;
		FSRef ref;
		ItemCount count = 0;
		OSErr fsErr = FSGetCatalogInfoBulk(iterator, 1, &count, NULL, kFSCatInfoRsrcSizes | kFSCatInfoDataSizes | kFSCatInfoNodeFlags, &cat, &ref, NULL, NULL);
		if (fsErr == errFSNoMoreItems) {
			return;
		}
		if (fsErr != noErr) {
			err(1, "%d", fsErr);
		}
        while ((fsErr == noErr) || (fsErr == errFSNoMoreItems)) {
			s->count += count;
            ItemCount i;
            for (i = 0; i < count; i++) {
                // Recurse if it's a folder
				UInt8 path[1024];
				FSRefMakePath(&ref, path, 1024);
                if (cat.nodeFlags & kFSNodeIsDirectoryMask) {
					ff(&ref, level + 1, s);
//					printf("%llu\t%s\n", subdir_size, path);
                } else {
//					printf("%llu %s\n", cat.dataPhysicalSize, path);
                    s->physical += cat.dataPhysicalSize;
					s->logical += cat.dataLogicalSize;
                    s->rsrc_physical += cat.rsrcPhysicalSize;
					s->rsrc_logical += cat.rsrcLogicalSize;
                }
            }
            if (fsErr == errFSNoMoreItems)
                break;
            else if (fsErr == noErr)
                fsErr = FSGetCatalogInfoBulk(iterator, 1, &count, NULL, kFSCatInfoRsrcSizes | kFSCatInfoDataSizes | kFSCatInfoNodeFlags, &cat, &ref, NULL, NULL);
			else
				printf("ERROR %d\n", fsErr);
        }
		FSCloseIterator(iterator);
    }
}

int main(int argc, char *argv[]) {
	FSRef ref;
	if (argc == 0)
		return 1;
	FSPathMakeRef((UInt8 *)argv[1], &ref, NULL);
    struct sizes s = {0};
	ff(&ref, 0, &s);
	printf("%lld items\ndata\nphys %lld\tlogi %lld\nrsrc\nphys %lld\tlogi %lld\n", s.count, s.physical, s.logical, s.rsrc_physical, s.rsrc_logical);
	return 0;
}
