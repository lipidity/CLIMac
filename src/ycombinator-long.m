#include <libc.h>
#include <Block.h>
#import <Foundation/Foundation.h>

typedef long (^bii)(long);
typedef bii (^bb)(void *);

#define m_Block_copy(X) [[(X) copy] autorelease]

bii Y(bii (^f)(bb));
bii Y(bii (^f)(bb)) {
	bb g;
	g = m_Block_copy(^ bii (void *h){
		return m_Block_copy(^(long x){
			return (((bb)f)(((bb)h)(h)))(x);
		});
	});
	return g(g);
}

int main(int argc, char *argv[])
{
	[NSAutoreleasePool new];
	printf("%ld\n", Y(^ bii (bb q){
		return m_Block_copy(^ long (long n) {
			if (n < 2)
				return 1;
			else
				return (n * ((bii)q)(n - 1));
		});
   	})(argc != 1 ? strtoul(argv[1], NULL, 10) : 4));
	return 0;
}
