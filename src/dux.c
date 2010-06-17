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
		const int cs = 1;
		ItemCount count;
		FSCatalogInfo cat[cs];
		FSRef ref[cs];
	_do:
		count = 0;
		OSErr fsErr = FSGetCatalogInfoBulk(iterator, cs, &count, NULL, kFSCatInfoRsrcSizes | kFSCatInfoDataSizes | kFSCatInfoNodeFlags, cat, ref, NULL, NULL);
		if (fsErr == errFSNoMoreItems)
			goto end;
		if (fsErr != noErr)
			err(1, "%d", fsErr);
		s->count += count;
		ItemCount i;
		for (i = 0; i < count; i++) {
			UInt8 path[1024];
			FSRefMakePath(&ref[i], path, 1024);
			printf("%s\n", path);
			if (cat[i].nodeFlags & kFSNodeIsDirectoryMask) {
				ff(&ref[i], level + 1, s);
//					printf("%llu\t%s\n", subdir_size, path);
			} else {
//					printf("%llu %s\n", cat.dataPhysicalSize, path);
				s->physical += cat[i].dataPhysicalSize;
				s->logical += cat[i].dataLogicalSize;
				s->rsrc_physical += cat[i].rsrcPhysicalSize;
				s->rsrc_logical += cat[i].rsrcLogicalSize;
			}
		}
		goto _do;
	end:
		FSCloseIterator(iterator);
    }
}

int main(int argc, char *argv[]) {
	FSRef ref;
	if (argc == 0)
		return 1;
	FSPathMakeRef((UInt8 *)argv[1], &ref, NULL);
    struct sizes s = {0,0,0,0,0};
	ff(&ref, 0, &s);
	printf("%lld items\ndata\nphys %lld\tlogi %lld\nrsrc\nphys %lld\tlogi %lld\n", s.count, s.physical, s.logical, s.rsrc_physical, s.rsrc_logical);
	return 0;
}
