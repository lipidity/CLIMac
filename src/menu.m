/*
 * Describe and manipulate running applications
 * gcc -std=c99 -framework Cocoa -o appr appr.m
 */

#import <Cocoa/Cocoa.h>

#import "version.h"
#import "ret_codes.h"

static inline void usage(FILE *);

