#import <Foundation/Foundation.h>
#import <libc.h>

#pragma mark Parse State

#define BSEARCH(element, array) bsearch((element), (array), sizeof((array))/sizeof((array)[0]), sizeof((array)[0]), string_search)

enum insertion_mode_type {
	initial = 1,
	before_html,
	before_head,
	in_head,
	in_head_noscript,
	after_head,
	in_body,
	in_RAWTEXT_RCDATA,
	in_table,
	in_table_text,
	in_caption,
	in_column_group,
	in_table_body,
	in_row,
	in_cell,
	in_select,
	in_select_in_table,
	in_foreign_content,
	after_body,
	in_frameset,
	after_frameset,
	after_after_body,
	after_after_frameset,
};

enum standard_namespaces {
	NOTHING,
	NAMESPACE_HTML,
	NAMESPACE_SVG,
	NAMESPACE_MATHML,
};
typedef enum standard_namespaces namespace_t;

@interface Node : NSObject {
}
- (char *) tag;
- (void) getTag:(char **)tag namespace:(namespace_t *)ns;
@end

static void reset_insertion_mode(void);
static Node *current_table(void);

static bool element_in_scope(Node *target);
static bool element_in_table_scope(Node *target);

static void reconstruct_active_formatting_elements(void);
static void clear_active_formatting_elements_to_last_marker(void);

static int string_search(const void *s1, const void *s2); // for bsearch

#pragma mark Tokenization

enum content_model_type {
	PCDATA,
	RCDATA,
	RAWTEXT,
	PLAINTEXT
};