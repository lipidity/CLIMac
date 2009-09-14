#include "html-tokenize.h"

#pragma mark Parse State

static enum insertion_mode_type insertion_mode = initial, original_insertion_mode = 0, secondary_insertion_mode = 0;

static NSMutableArray *stack = nil;

static Node *head_element = nil;
static Node *form_element = nil;

static NSMutableArray *active_formatting_elements = nil;

// p 738
static bool scripting_enabled = false;
static bool frameset_ok = false;

static const char *stack_special[] = {"address", "area", "article", "aside", "base", "basefont", "bgsound", "blockquote", "body", "br", "center", "col", "colgroup", "command", "datagrid", "dd", "details", "dialog", "dir", "div", "dl", "dt", "embed", "fieldset", "figure", "footer", "form", "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hgroup", "hr", "iframe", "img", "input", "isindex", "li", "link", "listing", "menu", "meta", "nav", "noembed", "noframes", "noscript", "ol", "p", "param", "plaintext", "pre", "script", "section", "select", "spacer", "style", "tbody", "textarea", "tfoot", "thead", "title", "tr", "ul", "wbr"};
static const char *stack_scoping[] = {"applet", "button", "caption", "html", "marquee", "object", "table", "td", "th"}; // , and SVG's foreignObject
static const char *stack_formatting[] = {"a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u"};
//static const char *stack_phrasing[] = {};

// p 733-4
static void reset_insertion_mode(void) {
	bool last = false;
	NSUInteger idx = [stack count] - 1;
again:
	idx -= 1;
	Node *node = [stack objectAtIndex:idx];
	if (idx == 0) {
		last = true;
//		node = context; //!!!!!!!!!!! what's context?
	}
	char *tag = NULL;
	namespace_t ns;
	[node getTag:&tag namespace:&ns];
	if (strcmp(tag, "select") == 0) {
		insertion_mode = in_select;
	} else if (last == false && tag[0] == 't' && (tag[1] == 'd' || tag[1] == 'h')) {
		insertion_mode = in_cell;
	} else if (strcmp(tag, "tr") == 0) {
		insertion_mode = in_row;
	} else if (tag[0] == 't' && (strcmp(tag, "tbody") == 0 || strcmp(tag, "thead") == 0 || strcmp(tag, "tfoot") == 0)) {
		insertion_mode = in_table_body;
	} else if (strcmp(tag, "caption") == 0) {
		insertion_mode = in_caption;
	} else if (strcmp(tag, "colgroup") == 0) {
		insertion_mode = in_column_group;
	} else if (strcmp(tag, "table") == 0) {
		insertion_mode = in_table;
	} else if (ns == NAMESPACE_SVG || ns == NAMESPACE_MATHML) {
		insertion_mode = in_foreign_content;
		secondary_insertion_mode = in_body;
	} else if (strcmp(tag, "head") == 0) {
		insertion_mode = in_body;
	} else if (strcmp(tag, "body") == 0) {
		insertion_mode = in_body;
	} else if (strcmp(tag, "frameset") == 0) {
		insertion_mode = in_frameset;
	} else if (strcmp(tag, "html") == 0) {
		if (head_element == nil)
			insertion_mode = before_head;
		else
			insertion_mode = after_head;
	} else if (last == true) {
		insertion_mode = in_body;
	} else {
		goto again;
	}

}

#define current_node [stack lastObject]
static Node *current_table(void) {
	for (Node *node in [stack reverseObjectEnumerator]) {
		if (strcmp([node tag], "table") == 0)
			return node;
	}
	return [stack objectAtIndex:0u];
}

static bool element_in_scope(Node *target) {
	NSUInteger idx = [stack count];
again:
	idx -= 1;
	Node *node = [stack objectAtIndex:idx];
	if (node == target) {
		return true;
	} else {
		// todo MUST sort
		const char *check[] = {"applet", "caption", "html", "table", "td", "th", "button", "marquee", "object"};
		char *element = NULL;
		namespace_t ns = 0u;
		[node getTag:&element namespace:&ns];
		if (ns == NAMESPACE_HTML && BSEARCH(element, check) != NULL)
			return false;
		if (ns == NAMESPACE_SVG && strcmp(element, "foreignObject") == 0)
			return false;
		goto again;
	}
}
static bool element_in_table_scope(Node *target) {
	NSUInteger idx = [stack count];
again:
	idx -= 1;
	Node *node = [stack objectAtIndex:idx];
	if (node == target) {
		return true;
	} else {
		// todo MUST sort
		const char *check[] = {"html", "table"};
		char *element = NULL;
		namespace_t ns = 0u;
		[node getTag:&element namespace:&ns];
		if (ns == NAMESPACE_HTML && BSEARCH(element, check) != NULL)
			return false;
		goto again;
	}
}

// p 736
static void reconstruct_active_formatting_elements(void) {
	NSUInteger idx = [active_formatting_elements count];
	if (idx != 0u) {
		idx -= 1;
		Node *entry = [active_formatting_elements objectAtIndex:idx];
		if (BSEARCH(entry, stack_scoping) == NULL && [stack indexOfObjectIdenticalTo:entry] == NSNotFound) {
step4:
			if (idx != 0u) {
				idx -= 1;
				entry = [active_formatting_elements objectAtIndex:idx];
				if (BSEARCH(entry, stack_scoping) == NULL && [stack indexOfObjectIdenticalTo:entry] == NSNotFound)
					goto step4;
				else
step7:
					entry = [active_formatting_elements objectAtIndex:++idx];
			}
			Node *new_element = [[Node alloc] blankCopy]; // copy tag and attrs only
			// UNSURE
			[current_node appendNode:new_element];
			[stack addObject:new_element];
			// END UNSURE
			[active_formatting_elements replaceObjectAtIndex:idx withObject:new_element];
			if (idx < [active_formatting_elements count]-1)
				goto step7;
		}
	}
}

// p 737
static void clear_active_formatting_elements_to_last_marker(void) {
again: ;
	Node *entry = [active_formatting_elements lastObject];
	if (entry != nil) {
		bool was_marker = BSEARCH([entry tag], stack_scoping);
		[active_formatting_elements removeLastObject];
		if (was_marker)
			goto again;
	}
}

static int string_search(const void *s1, const void *s2) { // for bsearch
	return strcmp((const char *)s1, *(const char * const *)s2);
}

#pragma mark Tokenization

static enum content_model_type content_model = PCDATA;
static bool escape = false;
