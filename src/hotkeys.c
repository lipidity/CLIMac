/*
 * Configurable system-wide hotkeys
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

#import <Carbon/Carbon.h>

#import <sys/mman.h>

#import <libc.h>
#import <pwd.h>
#import <err.h>

#import "alloc.h"

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
}
#if 0
NSString *sta(const UCKeyboardLayout *keyboardLayout, UInt16 keyCode, NSUInteger modifierFlags);
NSString *sta(const UCKeyboardLayout *keyboardLayout, UInt16 keyCode, NSUInteger modifierFlags) {
	if(keyboardLayout) {
		UInt32 deadKeyState = 0;
		UniCharCount maxStringLength = 255;
		UniCharCount actualStringLength = 0;
		UniChar unicodeString[maxStringLength];

		OSStatus status = UCKeyTranslate(keyboardLayout,
										 keyCode, kUCKeyActionDown, modifierFlags,
										 LMGetKbdType(), 0,
										 &deadKeyState,
										 maxStringLength,
										 &actualStringLength, unicodeString);

		if(status != noErr)
			NSLog(@"There was an %s error translating from the '%d' key code to a human readable string: %s",
				  GetMacOSStatusErrorString(status), status, GetMacOSStatusCommentString(status));
		else if(actualStringLength > 0) {
			// Replace certain characters with user friendly names, e.g. Space, Enter, Tab etc.
//			NSUInteger i = 0;
//			while(i <= NumberOfUnicodeGlyphReplacements) {
//				if(mapOfNamesForUnicodeGlyphs[i].glyph == unicodeString[0])
//					return NSLocalizedString(([NSString stringWithFormat:@"%s", mapOfNamesForUnicodeGlyphs[i].name, nil]), @"Friendly Key Name");
				
//				i++;
			}

			// NSLog(@"Unicode character as hexadecimal: %X", unicodeString[0]);
			return [NSString stringWithCharacters:unicodeString length:(NSInteger)actualStringLength];
		} else
			NSLog(@"Couldn't find a translation for the '%d' key code", keyCode);
//	} else
//		NSLog(@"Couldn't find a suitable keyboard layout from which to translate");

	return nil;
}
#endif
int main (int __unused argc, const char *argv[]) {
	signal(SIGCHLD, SIG_IGN);
#if 0
	[NSAutoreleasePool new];
#endif
	TISInputSourceRef tis = TISCopyCurrentKeyboardLayoutInputSource();
	CFDataRef uchr = TISGetInputSourceProperty(tis, kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayoutData = (const UCKeyboardLayout *)CFDataGetBytePtr(uchr);
#if 0
	for (int i = 0; i < 255; i++) {
		NSString *s = sta(keyboardLayoutData, i, 0);
		if ([s length]) {
			unichar buf[16];
			[s getCharacters:buf];
			printf("%i %x\n", i, buf[0]);
		}
	}
#endif
	char **cmds = NULL;
	unsigned cmd_top = 0;

	static char *shell = NULL;

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

	EventHotKeyRef hotkey; EventHotKeyID hotkey_id = {0, 0};

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
	unsigned int mods = 0;
	int character = 0;
	CGKeyCode keycode = UINT16_MAX;
read_mod:
	switch (*c) {
		case '^':
			mods |= controlKey;
			break;
		case '~':
			mods |= optionKey;
			break;
		case '@':
			mods |= cmdKey;
			break;
		case '$':
			mods |= shiftKey;
			break;
		default:
			goto end_mod;
	}
	inc;
	goto read_mod;
end_mod:
	if (mods == 0)
		errx(1, "hotkey with no %s", "modifiers");
	if (*c != '-')
		errx(1, "hotkey with no %s", "character");
	inc;
	character = *c;
	inc;
	// handle ^-\ ^-\013 or ^-\0x13 or ^-\k0xF704
	if (character == '\\') {
		if (isnumber(*c)) {
			character = (int)strtoul(c, &c, 0);
			inc;
		} else if (*c == 'K') {
			inc;
			keycode = (int)strtoul(c, &c, 0);
			inc;
		}
	}
	char *cmd_start = c;
	unsigned int cmd_len = 0;
	while (*c != '\n') {
		++cmd_len;
		inc_or_last;
	}
	if (keycode == UINT16_MAX)
		keycode = keyCodeForCharWithLayout(character, keyboardLayoutData);
	RegisterEventHotKey(keycode, (UInt32)mods, hotkey_id, GetApplicationEventTarget(), 0, &hotkey);
	hotkey_id.id += 1;
	if (cmd_top % 16 == 0)
		cmds = xrealloc(cmds, cmd_top + (sizeof(char *) * 16));
	cmds[cmd_top] = xmalloc(cmd_len + 1);
	strlcpy(cmds[cmd_top], cmd_start, cmd_len + 1);
	if (argc != 1)
		fprintf(stderr, "%2i: %c,%x-%x -- %s\n", hotkey_id.id - 1, (char)character, keycode, (int)mods, cmds[cmd_top]);
	++cmd_top;
	if (c != end)
		goto loop;
fin:
	munmap(base, st.st_size);
	CFRelease(tis);
	EventTypeSpec e = {kEventClassKeyboard, kEventHotKeyPressed};
	InstallApplicationEventHandler(NULL, 1, &e, NULL, NULL);
	EventTypeSpec evs = {kEventClassKeyboard, kEventHotKeyPressed};
	while (1) {
		EventRef event;
		EventHotKeyID i;
		if (ReceiveNextEvent(1, &evs, kEventDurationForever, 1, &event) == noErr
			&& GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(i), NULL, &i) == noErr
			&& i.id < cmd_top) {
			char *cmd = *((char **)cmds + i.id);
			pid_t child;
//			fprintf(stderr, "%s -c %s", shell, cmd);
			child = fork();
			if (child == -1)
				err(1, "fork");
			if (child == 0) {
				execl(shell, shell, "-c", cmd, NULL);
				err(1, "exec shell");
			}
		}
	}
}
