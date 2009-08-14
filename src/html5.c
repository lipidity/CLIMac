#import <libc.h>
#import <stdbool.h>
#import <ctype.h>
#import <err.h>

#define pr(FORMAT, ...) printf(FORMAT "\n", __VA_ARGS__)

enum node_type {
	ENDTAG = 0x0,
	DOCTYPE = 0x1,
	TEXT = 0x2,
	COMMENT = 0x3,
	CDATA = 0x4,
	VOID_ELEMENT = 0x5,
	CDATA_ELEMENT = 0x11,
	RCDATA_ELEMENT = 0x12,
	NORMAL_ELEMENT = 0x13,
	FOREIGN_ELEMENT = 0x14,
};

#define NODE_CAN_HAVE_CHILDREN(N) ((N)->isa & 0x10)

struct node {
	enum node_type isa;
	struct node *up;
	struct node *next;
	struct node *down;
	struct node *prev;
	void *data;
};

typedef struct node node;

struct element_data {
	char *tag;
	char *attrs[];
};

char *splice(const char * restrict start, const char * restrict end) {
	size_t len = end - start;
	if (len != 0) {
		char *str = xmalloc(len + 1);
		memcpy(str, start, len);
		*(str + len) = '\0';
		return str;
	}
	return NULL;
}
char *splice_lower(const char * restrict start, const char * restrict end) {
	size_t len = end - start;
	if (len != 0) {
		char *str = xmalloc(len + 1);
		register char *c = str;
		while (start < end)
			*c++ = tolower(*start++);
		*c = '\0';
		return str;
	}
	return NULL;
}

void tr(node *n, unsigned int lvl) {
	if (!n)
		return;
	for(unsigned int i = lvl; i != 0; --i)
		putchar(' ');
	puts(n->data ? : "(null)");
	if (n->down)
		tr(n->down, lvl + 1);
	if (n->next)
		tr(n->next, lvl);
}

node *readnode(char ** restrict location, char * restrict end, node * restrict parent, node * restrict prev) {
	char *p = *location;
	node *item = xmalloc(sizeof(node));
	*item = (node){.up = parent, .prev = prev};
//	item->data = NULL;
	switch (*p++) { // todo: lower case everything // could have run off the end of the string
		case '<':
			switch (*p++) {
				case '/': {
					char *q = p;
					while (q < end && isalnum(*q) || *q == '-')
						++q;
					char *tagname = splice_lower(p, q);
					if (tagname == NULL)
						errx(1, "Bad tag name");
					while (q < end && isspace(*q))
						++q;
					if (parent != NULL && strcmp(parent->data, tagname)==0 && *q == '>') {
						item->isa = ENDTAG;
						*location = q + 1;
					} else {
						errx(1, "Unexpected end tag");
					}
				}
					break;
				case '!':
					switch (*p++) {
						case '-':
							item->isa = COMMENT;
							break;
						case '[':
							item->isa = CDATA;
							break;
						case 'd':
						case 'D':
							item->isa = DOCTYPE;
						// todo: read doctype
								item->data = "DOCTYPE";
							*location = strchr(p, '>') + 1;
							break;
					}
					break;
				default:
					--p;
					char *q = p;
					while (q < end && isalnum(*q) || *q == '-')
						++q;
					char *tagname = splice_lower(p, q);
					if (tagname == NULL)
						errx(1, "Bad tag name");
					static const char *void_elements[] = { "area", "base", "br", "col", "command", "embed", "hr", "img", "input", "keygen", "link", "meta", "param", "source" };
					if (strcmp("script", tagname) == 0 || strcmp("style", tagname) == 0) {
						item->isa = CDATA_ELEMENT;
					} else if (strcmp("textarea", tagname) == 0 || strcmp("title", tagname) == 0) {
						item->isa = RCDATA_ELEMENT;
					} else {
						item->isa = NORMAL_ELEMENT;
						for (short i = 0; i < sizeof(void_elements)/sizeof(void_elements[0]); i++) {
							if (strcmp(tagname, void_elements[i]) == 0) {
								item->isa = VOID_ELEMENT;
								break;
							}
						}
					}
					// todo: read attributes
						*location = strchr(q, '>') + 1;
					item->data = tagname;
					if (NODE_CAN_HAVE_CHILDREN(item))
						item->down = readnode(location, end, item, NULL);
					break;
			}
			break;
		default:
			--p;
			if (parent == NULL || parent->isa == NORMAL_ELEMENT) {
				char *q = strpbrk(p, "<>&");
again:
				if (q == NULL)
					q = end;
				else {
					switch (*q) {
						case '&':
							++q;
							switch (*q) {
								case '#':
									++q;
									if (isdigit(*q))
										pr("character reference: _%c_", strtoul(q, NULL, 10));
									else if (*q == 'x')
										pr("character reference: _%c_", strtoul(++q, NULL, 16));
									break;
								default:
									break;
							}
							q = strchr(q, ';') + 1;
							goto again;
							break;
						case '>':
							errx(1, "'>' not allowed in contents");
							break;
	//					case '<':
						// start of something else
//						default:
							// probably at EOF
					}
				}
				*location = q;
				item->isa = TEXT;
				item->data = splice(p, q);
			}
	}
	if (item->isa == ENDTAG) {
		free(item);
		item = NULL;
	} else {
		if (prev != NULL)
			prev->next = item;
		if (parent != NULL)
			readnode(location, end, parent, item);
	}
	return item;
}

int main(int argc, char *argv[]) {
	char *html = "asdf3<!DOCTYPE html><HTML><p >asdf&#039;83&#x23;8</p></html>aus<p>asdf</p>";
	char *end = html + strlen(html);

	node *first = NULL;
	node *n = NULL;
	while (html < end && (n = readnode(&html, end, NULL, n))) {
		if (first == NULL)
			first = n;
	}
	tr(first, 0);
}
