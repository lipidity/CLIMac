#import <Cocoa/Cocoa.h>
#import <fts.h>

int main(int argc, char *argv[]) {
#if 0
	struct option longopts[] = {
		{ "junk", no_argument, NULL, 'j' },	// implies --headers --broken-symlinks
		{ "headers", no_argument, NULL, 'h' },	// delete Headers/*.h
		{ "broken-symlinks", no_argument, NULL, 'L' }, // delete symlinks which point to non-existent file
		{ "tiff", no_argument, NULL, 't' },		// compress tiffs
		{ "unsign", no_argument, NULL, 's' },	// remove code-signing
		{ "strip", no_argument, NULL, 'p' },	// implies --unsign
		{ "lipo", no_argument, NULL, 'a' },	// keep only native arch
		{ "arch", required_argument, NULL, 'r' },// keep specified arch(es)
		{ "xattr", no_argument, NULL, 'x' },	// implies --rsrc
		{ "rsrc", no_argument, NULL, 'c' },	// resource forks
		{ "lang", optional_argument, NULL, 'l' },	// language(s) to keep
		{ NULL, 0, NULL, 0 }
	};
	int c;
	while ((c = getopt_long_only(argc, argv, "", longopts, NULL)) != EOF) {
		
	}
	argc -= optind; argv += optind;
#else
/*
For dealing with lproj's, show tableview of |CFBundleCopyLocalizationsForURL()| with checkboxes
Tick all of |CFBundleCopyLocalizationsForPreferences| and first present object of |CFLocaleCopyPreferredLanguages()|
If more than two lproj's, and less than SETTING lproj's ticked, keep ticking from top of |CFLocaleCopyPreferredLanguages()| until exhaust list (display alert) or have SETTING ticked (where SETTING is one by default, but configurable)
 CFLocaleCopyPreferredLanguages() checks AppleLanguages AND NSLanguages
 
 Need to check localizations of each bundle contained within main bundle
*/
	[NSAutoreleasePool new];
	CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, argv[1], strlen(argv[1]), false);
	CFArrayRef locs = CFBundleCopyLocalizationsForURL(url);
	NSLog(@"localizations: %@", locs);
	NSLog(@"preferred languages: %@", CFLocaleCopyPreferredLanguages()); // leopard
	NSLog(@"preferred languages: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"]); // tiger
	NSLog(@"fromArrayForPrefs: %@", CFBundleCopyLocalizationsForPreferences(locs, NULL));
#endif
}
