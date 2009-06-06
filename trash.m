#import <Cocoa/Cocoa.h>
#import <err.h>

int main(int argc, const char *argv[])
{
	if (argc > 1) {
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		int i = 1;
		do {
			NSString *s = (NSString *)CFStringCreateWithFileSystemRepresentation(NULL, argv[i]);
			NSArray *file = [[NSArray alloc] initWithObjects:[s lastPathComponent], nil];
			if (![[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[s stringByDeletingLastPathComponent] destination:nil files:file tag:nil])
				warn(argv[i]);
			[file release];
			[s release];
			i += 1;
		} while (i < argc);
		[pool release];
		return 0;
	} else {
		fprintf(stderr, "usage:  %s <file>...\n", argv[0]);
		return 1;
	}
}
