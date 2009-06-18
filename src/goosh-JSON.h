/*
 Copyright (C) 2008 Stig Brautaset. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 Neither the name of the author nor the names of its contributors may be used
 to endorse or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
		  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>

/**
 Objective-C types are mapped to JSON types and back in the following way:
 - NSNull -> Null -> NSNull
 - NSString -> String -> NSMutableString
 - NSArray -> Array -> NSMutableArray
 - NSDictionary -> Object -> NSMutableDictionary
 - NSNumber (-initWithBool:) -> Boolean -> NSNumber -initWithBool:
 - NSNumber -> Number -> NSDecimalNumber
 NSNumber instances created with the +numberWithBool: method are
 converted into the JSON boolean "true" and "false" values, and vice
 versa. Any other NSNumber instances are converted to a JSON number the
 way you would expect. JSON numbers turn into NSDecimalNumber instances,
 as we can thus avoid any loss of precision.
 */
@interface J : NSObject {
	@private
		// Used temporarily during scanning/generation
		unsigned depth;
    const char *c;
}
	/// Return the object represented by the given string
- (id)objectWithString:(NSString*)jsonrep;

- (BOOL)scanValue:(NSObject **)o;

- (BOOL)scanRestOfArray:(NSMutableArray **)o;
- (BOOL)scanRestOfDictionary:(NSMutableDictionary **)o;
- (BOOL)scanRestOfNull:(NSNull **)o;
- (BOOL)scanRestOfFalse:(NSNumber **)o;
- (BOOL)scanRestOfTrue:(NSNumber **)o;
- (BOOL)scanRestOfString:(NSMutableString **)o;

	// Cannot manage without looking at the first digit
- (BOOL)scanNumber:(NSNumber **)o;

- (BOOL)scanHexQuad:(unichar *)x;
- (BOOL)scanUnicodeChar:(unichar *)x;

- (BOOL)scanIsAtEnd;
@end
