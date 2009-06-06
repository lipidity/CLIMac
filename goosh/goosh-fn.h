/*
 *  fn.h
 *  goosh
 *
 *  Created by Ankur Kothari on 5/06/08.
 *  Copyright 2008 Lipidity. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>

BOOL useColor;
NSString *lastQuery, *moreLink;
NSArray *lastResult;
int startIdx;

NSDictionary *json(NSString *s);
NSDictionary *web(NSString *query, int lucky);

NSString *u(NSString *r);
BOOL NSPuts(id o);
BOOL NSFPuts(id o);
NSMutableArray *args(NSString *s);
