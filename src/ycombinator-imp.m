#include <libc.h>
#include <Block.h>
#import <Foundation/Foundation.h>

#define Y(RETURN, ARGS, BLOCK) ({ __block RETURN (^this)ARGS; this = [[(^ RETURN ARGS BLOCK) copy] autorelease]; })

int main(int argc, char *argv[])
{
	[NSAutoreleasePool new];
	printf("%ld\n", Y(long, (long n), {
			if (n < 2)
				return 1;
			else
				return (n * this(n - 1));
   	})(argc != 1 ? strtoul(argv[1], NULL, 10) : 4));
	return 0;
}
