/*
 * Macros for printing out --version string
 * This file must be included after defining _VERSION in the primary source file.
 */

#define PKG_NAME		"CLIMac"
#define PKG_VERSION		"0.1"	// TODO This should be taken from git describe and warn if install build and same as last
#define PKG_URL			"http://lipidity.com/climac"
#define PKG_COPYRIGHT	"Copyright 2010 Vacuous Virtuoso"

#define PKG PKG_NAME " " PKG_VERSION

#ifdef _VERSION
#	define THE_STRING(name, version, pkg, copyright, url) name " (" pkg ") " version "\n" copyright "<" url ">"
#else
#	define THE_STRING(name, version, pkg, copyright, url) name " (" pkg ")" "\n" copyright "<" url ">"
#endif

#ifdef UTIL_NAME
/*
 * UTIL_NAME is defined via Xcode build settings as $(PRODUCT_NAME)
 * UTIL_VERSION is optionally defined at the start of the primary source file
 */
#	define climac_version_info() do {\
		puts(THE_STRING(UTIL_NAME, UTIL_VERSION, PKG, "\n" PKG_COPYRIGHT "\n", PKG_URL "/" UTIL_NAME "/"));\
	} while (0)
#else
#	define climac_version_info() custom_version_info(NULL, NULL, NULL, NULL, NULL)
#endif

#define V_OMIT ((const char *)-1)

static inline void custom_version_info(const char *name, const char *version, const char *pkg, const char *copyright, const char *url)
{
	if (name != V_OMIT) {
		if (name != NULL) {
			printf("%s", name);
		} else {
#ifdef UTIL_NAME
			printf("%s", UTIL_NAME);
#else
			printf("%s", getprogname());
#endif
		}
	}
	if (pkg != V_OMIT)
		printf(" (%s)", (pkg ? : PKG));
	if (version != V_OMIT && version != NULL)
		printf(" %s", version);
	putchar_unlocked('\n');
	if (copyright != V_OMIT)
		printf("\n%s\n", copyright ? : PKG_COPYRIGHT);
	if (url != V_OMIT) {
		if (url != NULL) {
			printf("<%s>\n", url);
		} else {
#if defined(PKG_URL)
#	if defined(UTIL_NAME)
			printf("<%s>\n", PKG_URL "/" UTIL_NAME "/");
#	else
			printf("<%s%s/>\n", PKG_URL "/", getprogname());
#	endif
#endif
		}
	}
}
