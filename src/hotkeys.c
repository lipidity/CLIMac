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

static inline CGKeyCode keyCodeForCharWithLayout(const int, const UCKeyboardLayout *);

/* Beware! Messy, incomprehensible code ahead!
 * TODO: XXX: FIXME! Please! */
static inline CGKeyCode keyCodeForCharWithLayout(const int c, const UCKeyboardLayout *uchr) {
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
	errx(1, "Keycode for \\U%X not found", c);
}

int main (int __unused argc, const char * __unused argv[]) {
	signal(SIGCHLD, SIG_IGN);

	TISInputSourceRef tis = TISCopyCurrentKeyboardLayoutInputSource();
	CFDataRef uchr = TISGetInputSourceProperty(tis, kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayoutData = (const UCKeyboardLayout *)CFDataGetBytePtr(uchr);

	char **cmds = NULL;
	unsigned cmd_top = 0;

	char *shell = getenv("SHELL");
	char *home = getenv("HOME");
	bool no_shell = shell == NULL || *shell == '\0';
	bool no_home = home == NULL || home == '\0';
	if (no_shell || no_home) {
		struct passwd *pw = getpwuid(getuid());
		if (pw == NULL)
			err(1, "getpwuid");
		if (no_shell)
			shell = pw->pw_shell;
		if (no_home)
			home = pw->pw_dir;
	}
	size_t home_len = strlen(home);
	const char *hotkeys_file = "/.hotkeys";
	char cfg_file[home_len + strlen(hotkeys_file) + 1];
	memcpy(cfg_file, home, home_len);
	memcpy(cfg_file + home_len, hotkeys_file, strlen(hotkeys_file) + 1);

	int fd = open(cfg_file, O_RDONLY | O_SHLOCK);
	if (fd == -1)
		err(1, "open %s", cfg_file);
	struct stat st;
	fstat(fd, &st);
	char *config = mmap(NULL, st.st_size, PROT_READ, MAP_SHARED, fd, 0);
	if (config == MAP_FAILED)
		err(1, "mmap %s", cfg_file);
	close(fd);

	char *end = config + st.st_size;

	EventHotKeyID hotkey_id = {0, 0};

#define inc ({ if (++c == end) errx(1, "unexpected EOF"); })
#define inc_or_last ({ if (++c == end) break; })
#define inc_or_end ({ if (++c == end) goto fin; })
	char *c = config;

	do {
		while (isspace(*c))
			inc_or_end;
		if (*c == '#') {
			while (*c != '\n') inc_or_end;
			continue;
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
#if 0
			case '#':
				// numpad
				mods |= ;
				break;
#endif
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
			static const char *names[] = {
				"DEL",
				"DOWN",
				"END",
				"ESC",
				"FDEL",
				"HELP",
				"HOME",
				"LEFT",
				"PGDN",
				"PGUP",
				"RET",
				"RIGHT",
				"SPC",
				"TAB",
				"UP",
				NULL
			};
			static CGKeyCode codes[] = {
				 kVK_Delete,
				 kVK_DownArrow,
				 kVK_End,
				 kVK_Escape,
				 kVK_ForwardDelete,
				 kVK_Help,
				 kVK_Home,
				 kVK_LeftArrow,
				 kVK_PageDown,
				 kVK_PageUp,
				 kVK_Return,
				 kVK_RightArrow,
				 kVK_Space,
				 kVK_Tab,
				 kVK_UpArrow,
			};
			if (*c == 'F') {
				static unsigned fs[] = {kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20 };
				unsigned n = (unsigned)strtoul(c, &c, 10);
				if (n == 0 || n > sizeof(fs)/sizeof(fs[0]) || *c != '>')
					errx(1, "bad fn key");
				inc;
				keycode = fs[n];
				goto found;
			}
			for (int i = 0; names[i] != NULL; ++i) {
				size_t len = strlen(names[i]);
				if ((c + len) < end && strncmp(names[i], c, len) == 0) {
					if (*(c + len) == '>') {
						c += len;
						keycode = codes[i];
						break;
					}
				}
			}
			if (keycode == UINT16_MAX)
				errx(1, "unknown key");
		found:
			inc;
		}
		// handle eg ^-\U0013 (hex unicode character) or ^-\K7a (hex key code)
		if (character == '\\' && !isspace(*c)) {
			if (*c == 'U') {
				inc;
				character = (int)strtoul(c, &c, 16);
				inc;
			} else if (*c == 'K') {
				inc;
				keycode = (unsigned)strtoul(c, &c, 16);
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
		EventHotKeyRef hotkey;
#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
#	define kEventHotKeyExclusive 0
#endif
		RegisterEventHotKey(keycode, (UInt32)mods, hotkey_id, GetApplicationEventTarget(), kEventHotKeyExclusive, &hotkey);
		hotkey_id.id += 1;
		if (cmd_top % 16 == 0)
			cmds = xrealloc(cmds, cmd_top + (sizeof(char *) * 16));
		cmds[cmd_top] = xmalloc(cmd_len + 1);
		strlcpy(cmds[cmd_top], cmd_start, cmd_len + 1);
		if (argc != 1)
			fprintf(stderr, "%2i: %c,%x-%x -- %s\n", hotkey_id.id - 1, (char)character, keycode, (int)mods, cmds[cmd_top]);
		++cmd_top;
	} while (c != end);
fin:
	munmap(config, st.st_size);
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
//			fprintf(stderr, "%s -c \"%s\"", shell, cmd);
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
