#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>

extern DCSDictionaryRef DCSDictionaryCreate(CFURLRef url);
extern CFArrayRef DCSCopyRecordsForSearchString(DCSDictionaryRef dictionary, CFStringRef string, void *u1, void *u2);
extern CFDataRef DCSRecordCopyData(CFTypeRef record);
extern CFURLRef DCSDictionaryGetBaseURL(DCSDictionaryRef dictionary);
extern CFURLRef DCSDictionaryGetURL(DCSDictionaryRef dictionary);
extern CFStringRef DCSDictionaryGetName(DCSDictionaryRef dictionary);
extern CFStringRef DCSDictionaryGetShortName(DCSDictionaryRef dictionary);

//#define XML_DATA

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
extern CFStringRef CopySimpleDefinitionForTerm(CFStringRef); // similar to DCSCopyTextDefinition
extern CFSetRef DCSCopyAvailableDictionaries(void);
extern DCSDictionaryRef DCSGetDefaultThesaurus(void);
extern DCSDictionaryRef DCSGetDefaultDictionary(void);
extern CFArrayRef DCSGetActiveDictionaries(void);
extern OSErr DCSSetActiveDictionaries(CFArrayRef);
//extern void DCSActivateDictionaryPanel(void);
int main(int argc, char *argv[]) {
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
	return 1;
}
