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

int main (int __unused argc, const char *argv[]) {
	signal(SIGCHLD, SIG_IGN);

	TISInputSourceRef tis = TISCopyCurrentKeyboardLayoutInputSource();
	CFDataRef uchr = TISGetInputSourceProperty(tis, kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayoutData = (const UCKeyboardLayout *)CFDataGetBytePtr(uchr);

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
		case '$':
			mods |= shiftKey;
			break;
//		case '#':
//			numpad
//			mods |= ;
//			break;
		case '@':
			mods |= cmdKey;
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
	// ^-<F1> etc
	if (character == '<' && !isspace(*c)) {
		switch (*c) {
				// add 'clear'
			case 'D':
				if ((inc, *c == 'E') && (inc, *c == 'L') && (inc, *c == '>'))
					inc, keycode = kVK_Delete;
				else if ((*c == 'O') && (inc, *c == 'W') && (inc, *c == 'N') && (inc, *c == '>'))
					inc, keycode = kVK_DownArrow;
				break;
			case 'E':
				// add 'enter' (different to return)
				if ((inc, *c == 'N') && (inc, *c == 'D') && (inc, *c == '>'))
					inc, keycode = kVK_End;
				if ((inc, *c == 'S') && (inc, *c == 'C') && (inc, *c == '>'))
					inc, keycode = kVK_Escape;
				break;
			case 'F': {
				// add 'find'
				// add 'forward delete'
				if ((inc, *c == 'D') && (inc, *c == 'E') && (inc, *c == 'L') && (inc, *c == '>')) {
					inc, keycode = kVK_ForwardDelete;
				} else {
					unsigned fs[] = {kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
					kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20 };
					int n = (int)strtol(c, &c, 10) - 1;
					if (n < 0 || n >= sizeof(fs)/sizeof(fs[0]) || *c != '>')
						errx(1, "no f%d key", n);
					inc;
					keycode = fs[n];
				}
			}
				break;
			case 'H':
				if ((inc, *c == 'E') && (inc, *c == 'L') && (inc, *c == 'P') && (inc, *c == '>'))
					inc, keycode = kVK_Help;
				else if ((*c == 'O') && (inc, *c == 'M') && (inc, *c == 'E') && (inc, *c == '>'))
					inc, keycode = kVK_Home;
				break;
				// add 'insert'
//			case 'I':
//				if ((inc, *c == 'N') && (inc, *c == 'S') && (inc, *c == '>'))
//					inc, keycode = kVK_I;
//				break;
			case 'L':
				if ((inc, *c == 'E') && (inc, *c == 'F') && (inc, *c == 'T') && (inc, *c == '>'))
					inc, keycode = kVK_LeftArrow;
				break;
			case 'P':
				if ((inc, *c == 'G')) {
					if ((inc, *c == 'U') && (inc, *c == 'P') && (inc, *c == '>'))
						inc, keycode = kVK_PageUp;
					else if ((*c == 'D') && (inc, *c == 'N') && (inc, *c == '>'))
						inc, keycode = kVK_PageDown;
				}
				break;
			case 'R':
				if ((inc, *c == 'E') && (inc, *c == 'T') && (inc, *c == '>'))
					inc, keycode = kVK_Return;
				else if ((*c == 'I') && (inc, *c == 'G') && (inc, *c == 'H') && (inc, *c == 'T') && (inc, *c == '>'))
					inc, keycode = kVK_RightArrow;
				break;
			case 'S':
				if ((inc, *c == 'P') && (inc, *c == 'C') && (inc, *c == '>'))
					inc, keycode = kVK_Space;
				break;
			case 'T':
				if ((inc, *c == 'A') && (inc, *c == 'B') && (inc, *c == '>'))
					inc, keycode = kVK_Tab;
				break;
			case 'U':
				if ((inc, *c == 'P') && (inc, *c == '>'))
					inc, keycode = kVK_UpArrow;
				break;
		}
		if (keycode == UINT16_MAX)
			errx(1, "unknown key");
	}
	// handle eg ^-\U0013 (hex unicode character) or ^-\K7a (hex key code)
	if (character == '\\' && !isspace(*c)) {
		if (*c == 'U') {
			inc;
			character = (int)strtoul(c, &c, 16);
			inc;
		} else if (*c == 'K') {
			inc;
			keycode = (int)strtoul(c, &c, 16);
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
