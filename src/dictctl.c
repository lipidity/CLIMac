#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>

extern DCSDictionaryRef DCSDictionaryCreate(CFURLRef url);
extern CFArrayRef DCSCopyRecordsForSearchString(DCSDictionaryRef dictionary, CFStringRef string, void *u1, void *u2);
extern CFDataRef DCSRecordCopyData(CFTypeRef record);
extern CFURLRef DCSDictionaryGetBaseURL(DCSDictionaryRef dictionary);
extern CFURLRef DCSDictionaryGetURL(DCSDictionaryRef dictionary);
extern CFStringRef DCSDictionaryGetName(DCSDictionaryRef dictionary);
extern CFStringRef DCSDictionaryGetShortName(DCSDictionaryRef dictionary);

extern CFStringRef CopySimpleDefinitionForTerm(CFStringRef); // similar to DCSCopyTextDefinition
extern CFSetRef DCSCopyAvailableDictionaries(void);
extern DCSDictionaryRef DCSGetDefaultThesaurus(void);
extern DCSDictionaryRef DCSGetDefaultDictionary(void);
extern CFArrayRef DCSGetActiveDictionaries(void);
extern OSErr DCSSetActiveDictionaries(CFArrayRef);
//extern void DCSActivateDictionaryPanel(void);

static inline void printDictURL(DCSDictionaryRef dict) {
	CFURLRef url = DCSDictionaryGetURL(dict);
	char buffer[PATH_MAX];
	if (url != NULL && CFURLGetFileSystemRepresentation(url, true, (UInt8 *)buffer, PATH_MAX))
		puts(buffer);
}
__attribute__((always_inline)) static inline void printCFStr(CFStringRef str) {
	if (str != NULL) {
		CFIndex len = CFStringGetMaximumSizeOfFileSystemRepresentation(str);
		char buffer[len];
		if (CFStringGetFileSystemRepresentation(str, buffer, len))
			puts(buffer);
	}
}

int main(int argc, char *argv[]) {
#if 0
	dict list			DCSCopyAvailableDictionaries
	dict default			DCSGetDefaultDictionary
	dict default thesaurus	DCSGetDefaultThesaurus
	dict active			DCSGetActiveDictionaries
	dict active +URL -URL		DCSSetActiveDictionaries
	dict name URL		DCSDictionaryGetName
	dict shortname URL	DCSDictionaryGetShortName
#endif
	if (argc != 1)
		switch (argv[1][0]) {
			case 'l':
				if (argc == 2 && strcmp("list", argv[1]) == 0) {
					CFSetRef all = DCSCopyAvailableDictionaries();
					EIF (all == NULL, errx(1, "Unable to get available dictionaries"));
					CFIndex num = CFSetGetCount(all);
					DCSDictionaryRef *r = xmalloc(sizeof(DCSDictionaryRef) * num);
					CFSetGetValues(all, (const void **)r);
					for (CFIndex i = 0; i < num; i++)
						printDictURL(r[i]);
					free(r);
				}
				return 0;
			case 'd':
				if (argc == 3 && argv[2][0] == 't') {
					printDictURL(DCSGetDefaultThesaurus());
					return 0;
				} else if (argc == 2) {
					printDictURL(DCSGetDefaultDictionary());
					return 0;
				}
				break;
			case 'a':
			if (argc == 2) {
				CFArrayRef active = DCSGetActiveDictionaries();
				EIF (active == NULL, errx(1, "Unable to get active dictionaries"));
				CFIndex num = CFArrayGetCount(active);
				for (CFIndex i = 0; i < num; i++)
					printDictURL(CFArrayGetValueAtIndex(active, i));
			} else if (argc > 2) {
				// TODO: get all dicts, get set of shortnames, de/activate by shortname
			}
				return 0;
			case 'n': {
				CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[2], strlen(argv[2]), false);
				if (url != NULL) {
					DCSDictionaryRef dict = DCSDictionaryCreate(url);
					CFRelease(url);
					EIF (dict == NULL, errx(1, "Not a dictionary"));
					printCFStr(DCSDictionaryGetName(dict));
					CFRelease(dict);
					return 0;
				}
			}
				break;	
			case 's':
				if (argc == 3) {
					CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8 *)argv[2], strlen(argv[2]), false);
					if (url != NULL) {
						DCSDictionaryRef dict = DCSDictionaryCreate(url);
						CFRelease(url);
						EIF (dict == NULL, errx(1, "Not a dictionary"));
						printCFStr(DCSDictionaryGetShortName(dict));
						CFRelease(dict);
						return 0;
					}
				}
				break;	
		}
	fprintf(stderr, "usage:  %s\n", argv[0]);
	return 1;
}

#if 0
CFStringRef word = CFStringCreateWithFileSystemRepresentation(NULL, argv[1]);
CFRange range = CFRangeMake(0, CFStringGetLength(word));

#ifdef XML_DATA
const UInt8 dict[] = "/Library/Dictionaries/New Oxford American Dictionary.dictionary";
CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, dict, strlen((const char *)dict), false);
CFTypeRef dictionary = DCSDictionaryCreate(url);
CFArrayRef records =  DCSCopyRecordsForSearchString(dictionary, word, 0, 0);
if (records) // MUST: only print one definition unless specified otherwise?
CFArrayApplyFunction(records, CFRangeMake(0, CFArrayGetCount(records)), &a, NULL);
else
warnx("No records in New Oxford Am");
#endif

CFStringRef def = DCSCopyTextDefinition(NULL, word, range);
if (def != NULL) {
	char buffer[PATH_MAX];
	if (CFStringGetFileSystemRepresentation(def, buffer, PATH_MAX)) {
		fputs(buffer, stdout);
		return 0;
	}
}
#endif


// requires Carbon; anyway, can open dict:// URL instead
//	HIDictionaryWindowShow(NULL, word, range, CTFontCreateUIFontForLanguage(kCTFontUserFontType, 0.0f, NULL), p, false, NULL);

#ifdef XML_DATA
//_DCSDictionaryEqual	_DCSRecordEqual
extern CFStringRef DCSRecordGetString(CFTypeRef); // returns searched word (possibly entire string?)
extern CFStringRef DCSRecordGetHeadword(CFTypeRef); // returns searched word (possibly range of entire string that was searched?)
//CFStringRef DCSRecordGetAnchor(CFTypeRef); // returns NULL
extern CFStringRef DCSRecordGetDictionary(CFTypeRef); // returns DCSDictionaryRef
static void a(const void *value, void *context);
static void a(const void *record, void *context) {
	CFDataRef data = DCSRecordCopyData((CFTypeRef)record);
	if (fwrite(CFDataGetBytePtr(data), CFDataGetLength(data), 1, stdout) != 1) {
		CFStringRef str = DCSRecordGetString(record);
		if (str != NULL) {
			// print filesystemrepresentation
		}
	}
	//	CFShow(data);
	//	CFShow(DCSRecordCopyFormattingDesc((CFTypeRef)record, NULL));
	//	CFStringRef s = CFStringCreateFromExternalRepresentation(NULL, data, kCFStringEncodingUTF8);
	//	CFShow(s);
}
#endif
