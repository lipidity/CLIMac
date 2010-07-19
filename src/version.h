/*
 * Macros for printing out --version string
 * UTIL_NAME and UTIL_VERSION must be set either in Xcode build settings, command line, or top of src file
 */

#define PKG_NAME		"CLIMac"
#define PKG_VERSION		"0.1"	// TODO This should be taken from git describe and warn if install build and same as last
#define PKG_URL			"http://lipidity.com/climac"
#define PKG_COPYRIGHT	"Copyright 2010 Vacuous Virtuoso"

#define PKG PKG_NAME " " PKG_VERSION

#ifdef UTIL_VERSION
#	define THE_STRING(name, version, pkg, copyright, url) name " (" pkg ") " version "\n" copyright "<" url ">"
#else
#	define THE_STRING(name, version, pkg, copyright, url) name " (" pkg ")" "\n" copyright "<" url ">"
#endif

#define pp_hash(X) #X
#define _stringify(X) pp_hash(X)
#ifdef UTIL_NAME
#	define UTIL_NAME_STRING _stringify(UTIL_NAME)
#endif
#ifdef UTIL_VERSION
#	define UTIL_VERSION_STRING _stringify(UTIL_VERSION)
#endif

#ifdef UTIL_NAME
#	define climac_version_info() ({\
		puts(THE_STRING(UTIL_NAME_STRING, UTIL_VERSION_STRING, PKG, "\n" PKG_COPYRIGHT "\n", PKG_URL "/" UTIL_NAME_STRING "/"));\
	})
#else
#	define climac_version_info() custom_version_info(NULL, NULL, NULL, NULL, NULL)
#endif

#define V_OMIT ((const char *)-1)

static inline void custom_version_info(const char *name, const char *version, const char *pkg, const char *copyright, const char *url) {
	if (name != V_OMIT) {
		if (name != NULL) {
			fputs(name, stdout);
		} else {
#ifdef UTIL_NAME
			fputs(UTIL_NAME_STRING, stdout);
#else
			fputs(getprogname(), stdout);
#endif
		}
	}
	if (pkg != V_OMIT) {
		if (pkg != NULL)
			printf(" (%s)", pkg);
		else
			fputs(" (" PKG ")", stdout);
	}
	if (version != V_OMIT) {
		if (version != NULL)
			printf(" %s", version);
		else {
#ifdef UTIL_VERSION
			fputs(UTIL_VERSION_STRING, stdout);
#endif
		}
	}
	putchar('\n');
	if (copyright != V_OMIT) {
		if (copyright != NULL)
			printf("\n%s\n", copyright);
		else
			puts("\n" PKG_COPYRIGHT);
	}
	if (url != V_OMIT) {
		if (url != NULL) {
			printf("<%s>\n", url);
		} else {
#ifdef PKG_URL
#	ifdef UTIL_NAME
			puts("<" PKG_URL "/" UTIL_NAME_STRING "/" ">");
#	else
			printf("<%s%s/>\n", PKG_URL "/", getprogname());
#	endif
#endif
		}
	}
}
