#include <libc.h>
#include <Block.h>
#import <Foundation/Foundation.h>

typedef id (^bii)(id);
typedef bii (^bb)(void *);

#define m_Block_copy(X) [[(X) copy] autorelease]

bii Y(bii (^f)(bb));
bii Y(bii (^f)(bb)) {
	bb g;
	g = m_Block_copy(^ bii (void *h){
		return m_Block_copy(^(id x){
			return (((bb)f)(((bb)h)(h)))(x);
		});
	});
	return g(g);
}

int main(int argc, char *argv[])
{
	[NSAutoreleasePool new];
	printf("%i\n", [((Y(^ bii (bb q){
		return m_Block_copy(^ id (id r) {
   			int n = [r intValue];
			if (n < 2)
				return [NSNumber numberWithInt:1];
			else {
				return [NSNumber numberWithInt:(n * [(((bii)q)([NSNumber numberWithInt:n - 1])) intValue])];
			}
		});
	}))([NSNumber numberWithInt:(argc != 1 ? (unsigned)strtoul(argv[1], NULL, 10) : 4)])) intValue]);
	return 0;
}
