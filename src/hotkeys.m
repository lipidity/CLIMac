/*
 * Configurable system-wide hotkeys
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import <sys/mman.h>

#import <libc.h>
#import <pwd.h>
#import <err.h>

#import "alloc.h"

static char *shell = NULL;

static OSStatus h(EventHandlerCallRef n, EventRef e, void *a);

static OSStatus h(EventHandlerCallRef __unused n, EventRef e, void *cmds) {
	EventHotKeyID i;
	GetEventParameter(e, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(i), NULL, &i);
//	const char *cmd = [[(NSMutableArray *)cmds objectAtIndex:(i.id)] fileSystemRepresentation];
	char *cmd = *((char **)cmds + i.id);
	pid_t c;
	c = fork();
	if (c == -1)
		err(1, "fork");
	printf("%s -c %s", shell, cmd);
	if (c == 0) {
		execl(shell, shell, "-c", cmd, NULL);
		err(1, "exec shell");
	}
	return noErr;
}

static CGKeyCode keyCodeForCharWithLayout(const int, const UCKeyboardLayout *);

/* Beware! Messy, incomprehensible code ahead!
 * TODO: XXX: FIXME! Please! */
static CGKeyCode keyCodeForCharWithLayout(const int c, const UCKeyboardLayout *uchr) {
    const uint8_t *uchrData = (const uint8_t *)uchr;
    const UCKeyboardTypeHeader *uchrKeyboardList = uchr->keyboardTypeList;
	
    /* Loop through the keyboard type list. */
    ItemCount i, j;
    for (i = 0; i < uchr->keyboardTypeCount; ++i) {
    	/* Get a pointer to the keyToCharTable structure. */
    	const UCKeyToCharTableIndex *uchrKeyIX = (const UCKeyToCharTableIndex *)(uchrData + (uchrKeyboardList[i].keyToCharTableIndexOffset));
		
    	/* Not sure what this is for but it appears to be a safeguard... */
    	const UCKeyStateRecordsIndex *stateRecordsIndex;
    	if (uchrKeyboardList[i].keyStateRecordsIndexOffset != 0) {
    		stateRecordsIndex = (const UCKeyStateRecordsIndex *)(uchrData + (uchrKeyboardList[i].keyStateRecordsIndexOffset));
    		if ((stateRecordsIndex->keyStateRecordsIndexFormat) != kUCKeyStateRecordsIndexFormat)
    			stateRecordsIndex = NULL;
    	} else {
    		stateRecordsIndex = NULL;
    	}
		
    	/* Make sure structure is a table that can be searched. */
    	if ((uchrKeyIX->keyToCharTableIndexFormat) != kUCKeyToCharTableIndexFormat)
    		continue;
		
    	/* Check the table of each keyboard for character */
    	for (j = 0; j < uchrKeyIX->keyToCharTableCount; ++j) {
    		const UCKeyOutput *keyToCharData = (const UCKeyOutput *)(uchrData + (uchrKeyIX->keyToCharTableOffsets[j]));
			
    		/* Check THIS table of the keyboard for the character. */
    		UInt16 k;
    		for (k = 0; k < uchrKeyIX->keyToCharTableSize; ++k) {
    			/* Here's the strange safeguard again... */
    			if ((keyToCharData[k] & kUCKeyOutputTestForIndexMask) == kUCKeyOutputStateIndexMask) {
    				long keyIndex = (keyToCharData[k] & kUCKeyOutputGetIndexMask);
    				if (stateRecordsIndex != NULL && keyIndex <= (stateRecordsIndex->keyStateRecordCount)) {
    					const UCKeyStateRecord *stateRecord = (const UCKeyStateRecord *)(uchrData + (stateRecordsIndex->keyStateRecordOffsets[keyIndex]));
    					if ((stateRecord->stateZeroCharData) == c) {
    						return (CGKeyCode)k;
    					}
    				} else if (keyToCharData[k] == c) {
    					return (CGKeyCode)k;
    				}
    			} else if (((keyToCharData[k] & kUCKeyOutputTestForIndexMask) != kUCKeyOutputSequenceIndexMask)
						   && keyToCharData[k] != 0xFFFE
						   && keyToCharData[k] != 0xFFFF
						   && keyToCharData[k] == c) {
    				return (CGKeyCode)k;
    			}
    		}
    	}
    }
	errx(1, "Keycode for [%1$#x] not found", c);
//    return UINT16_MAX;
}

int main (int __unused argc, const char *argv[]) {
	signal(SIGCHLD, SIG_IGN);
	
	TISInputSourceRef tis = TISCopyCurrentKeyboardLayoutInputSource();
	CFDataRef uchr = TISGetInputSourceProperty(tis, kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayoutData = (const UCKeyboardLayout *)CFDataGetBytePtr(uchr);
//	int ch;
//	for (ch = 0; ch < 65535; ++ch)
//		printf("%1$x (%1$d) == %2$x (%2$d)\n", ch, keyCodeForCharWithLayout(ch, keyboardLayoutData));
//	exit(0);
//	NSMutableArray *cmds = [[NSMutableArray alloc] init];
	char **cmds = NULL;
	unsigned cmd_top = 0;

	shell = getenv("SHELL");
	if (shell == NULL || *shell == '\0') {
		struct passwd *pw = getpwuid(getuid());
		if (pw == NULL)
			err(1, "getpwuid");
		shell = pw->pw_shell;
	}
	
	char *home = getenv("HOME");
	if (home == NULL || *home == '\0') {
		struct passwd *pw = getpwuid(getuid());
		if (pw == NULL)
			err(1, "getpwuid");
		home = pw->pw_dir;
	}
	size_t home_len = strlen(home);
	char cfg_file[home_len + 10];
	memcpy(cfg_file, home, home_len);
	memcpy(cfg_file + home_len, "/.hotkeys", 10);

	int fd = open(cfg_file, O_RDONLY | O_SHLOCK);
	if (fd == -1)
		err(1, "open %s", argv[1]);
	struct stat st;
	fstat(fd, &st);
	char *base = mmap(NULL, st.st_size, PROT_READ, MAP_SHARED, fd, 0);
	if (base == MAP_FAILED)
		err(1, "mmap %s", argv[1]);
	close(fd);

	char *end = base + st.st_size;

//	NSAutoreleasePool *p = [NSAutoreleasePool new];
//	NSFileManager *fm = [NSFileManager defaultManager];
	
	EventHotKeyRef hotkey; EventHotKeyID hotkey_id = {0, 0};
	
	const char *mods_char = "^~@$";
	unsigned mods_mask[] = {controlKey, optionKey, cmdKey, shiftKey};
#define inc ({ if (++c == end) errx(1, "unexpected EOF"); })
#define inc_or_last ({ if (++c == end) break; })
#define inc_or_end ({ if (++c == end) goto fin; })
	char *c = base;

loop: ;
	while (isspace(*c))
		inc_or_end;
	if (*c == '#') {
		while (*c != '\n') inc_or_end;
		goto loop;
	}
	unsigned mods = 0;
	int character = 0;
	char *m;
read_mod:
	m = strchr(mods_char, *c);
	if (m != NULL) {
		mods |= mods_mask[m - mods_char];
		inc;
		goto read_mod;
	}
	if (mods == 0)
		errx(1, "hotkey with no %s", "modifiers");
	if (*c != '-')
		errx(1, "hotkey with no %s", "character");
	inc;
	character = *c;
	inc;
	// handle ^-\ ^-\013 or ^-\0x13
	if (character == '\\') {
		if (isnumber(*c)) {
			character = (int)strtoul(c, &c, 0);
			inc;
		}
	}
	char *cmd_start = c;
	NSUInteger cmd_len = 0;
	while (*c != '\n') {
		++cmd_len;
		inc_or_last;
	}
	CGKeyCode keycode = keyCodeForCharWithLayout(character, keyboardLayoutData);
	RegisterEventHotKey(keycode, mods, hotkey_id, GetApplicationEventTarget(), 0, &hotkey);
	hotkey_id.id += 1;
	if (cmd_top % 16 == 0)
		cmds = xrealloc(cmds, cmd_top + (sizeof(char *) * 16));
	cmds[cmd_top] = xmalloc(cmd_len + 1);
	strlcpy(cmds[cmd_top], cmd_start, cmd_len + 1);
	printf("%2i: %c,%x-%x -- %s\n", hotkey_id.id - 1, (char)character, keycode, mods, cmds[cmd_top]);
	++cmd_top;
	//		[cmds addObject:[fm stringWithFileSystemRepresentation:cmd_start length:cmd_len]];
	if (c != end)
		goto loop;
fin:
	munmap(base, st.st_size);
//	[p release];
	CFRelease(tis);
	EventTypeSpec e = {kEventClassKeyboard, kEventHotKeyPressed};
	InstallApplicationEventHandler(&h, 1, &e, cmds, NULL);
	[[NSApplication sharedApplication] run];
}
