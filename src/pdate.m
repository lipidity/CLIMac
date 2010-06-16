/*
 * Parse a date string into a timestamp
 *
 * Copyright (C) Vacuous Virtuoso
 * <http://lipidity.com/climac/>
 */

int main(int argc, char *argv[]) {
	id p = [NSAutoreleasePool new];
#if 0
	NSDateFormatter *f = [];
	(style each: (do (s) (f setDateStyle: s) (set a (f dateFromString:str)));
	if (!a) {
	format:
			d'th'|'st'|'nd'|'rd'
			d/m or m/d -- check locale
			'to' -- tomorrow
			't' -- today
			last mon,tue etc
			next mon,tue etc
	}
#endif
	[p release];
	return 0;
}
