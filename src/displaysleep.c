// this should be moved to target 'power'?
#import <IOKit/IOKitLib.h>
// INTEL ONLY OR >=10.5 ONLY?
#if 1
int main (int argc, char *argv[]) {
	io_registry_entry_t io = IORegistryEntryFromPath(kIOMasterPortDefault, kIOServicePlane ":/IOResources/IODisplayWrangler");
	if (io != MACH_PORT_NULL) {
		usleep(300000);
		IORegistryEntrySetCFProperty(io, CFSTR("IORequestIdle"), kCFBooleanTrue);
		IOObjectRelease(io);
		return 0;
	}
	return 1;
}
#else
int
main(int argc, char **argv)
{
    kern_return_t kr;
    CFTypeRef obj;
	
    io_registry_entry_t regEntry;
	
    regEntry = IORegistryEntryFromPath(kIOMasterPortDefault, 
									   kIOServicePlane ":/IOResources/IODisplayWrangler");
	
    obj = CFRetain(kCFBooleanTrue);
    if (argc > 1)
    {
		SInt32 num = 1000 * strtol(argv[1], 0, 0);
		obj = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &num);
    }
	
    kr = IORegistryEntrySetCFProperty(regEntry, CFSTR("IORequestIdle"), obj);
	
    printf("IORegistryEntrySetCFProperty(IORequestIdle) 0x%x\n", kr);
	
    CFRelease(obj);
    IOObjectRelease(regEntry);
	
    return (0);
}
#endif