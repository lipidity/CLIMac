#include <Carbon/Carbon.h>
#include <CoreAudio/CoreAudio.h>
#include <getopt.h>

void setSystemVolume(float);

int main(int argc, char *argv[]) {
	opterr = 0; int c; UInt32 muting = 1;
	static struct option longopts[] = {
	{ "set", required_argument, NULL, 's' },
	{ "volume", no_argument, NULL, 'v' },
	{ "mute", no_argument, NULL, 'm' },
	{ "unmute", no_argument, NULL, 'u' },
	{ "info", no_argument, NULL, 'i' },
	{ NULL, 0, NULL, 0 }
	};	
	while((c = getopt_long(argc, argv, "umivs:", longopts, NULL)) != EOF) {
		switch(c) {
			case 's':
				setSystemVolume(strtof(optarg, NULL));
				return 0;
			case 'v': {
				float b_vol;
				OSStatus theErr;
				AudioDeviceID device;
				UInt32 size = sizeof device;
				theErr = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &size, &device);
				if(theErr != noErr) {
					fputs("Error getting audio device\n", stderr);
					return 2;
				}

				size = sizeof b_vol;
				// Master volume (channel 0)
				theErr = AudioDeviceGetProperty(device, 0, 0, kAudioDevicePropertyVolumeScalar, &size, &b_vol);
				if(noErr == theErr) goto end;
				
				// otherwise, try seperate channels.
				UInt32 channels[2];
				float volume[2];
				size = sizeof(channels);
				theErr = AudioDeviceGetProperty(device, 0, 0, kAudioDevicePropertyPreferredChannelsForStereo, &size, &channels);
				if(theErr != noErr) fputs("Error getting audio channel-numbers\n", stderr);

				size = sizeof(float);
				theErr = AudioDeviceGetProperty(device, channels[0], 0, kAudioDevicePropertyVolumeScalar, &size, &volume[0]);
				if(noErr != theErr) fprintf(stderr, "Error getting volume of audio channel %lu\n", channels[0]);
				theErr = AudioDeviceGetProperty(device, channels[1], 0, kAudioDevicePropertyVolumeScalar, &size, &volume[1]);
				if(noErr != theErr) fprintf(stderr, "Error getting volume of audio channel %lu\n", channels[1]);
				b_vol = (volume[0]+volume[1])/2.00;
end:
				printf("%g\n", b_vol);
				return 0;
			}
			case 'u':
				muting = 0; // no break
			case 'm': {
				AudioDeviceID d;
				UInt32 s = sizeof d;
				if(AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &s, &d)) {
					fputs("Error getting device\n", stderr); return 2;
				}
				s = sizeof(muting);
				if(AudioDeviceSetProperty(d, NULL, 0, false, kAudioDevicePropertyMute, s, &muting))
					return 3;
				else {
					fputs(muting?"Muted\n":"Unmuted\n", stderr);
					return 0;
				}
			}
			case 'i': {
				UInt32 size;
				AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &size, NULL);
				AudioDeviceID *dev_array = malloc(size); // check != NULL
				AudioHardwareGetProperty(kAudioHardwarePropertyDevices, &size, dev_array);
				UInt32 number_of_devices_on_system = (size / sizeof(AudioDeviceID));
				UInt32 i = 0; AudioDeviceID j = *dev_array;
				while(i++ < number_of_devices_on_system) {
					CFStringRef name = NULL;
					UInt32 z = sizeof(name);
					AudioDeviceGetProperty(j, 0, false, kAudioObjectPropertyName, &z, &name);
					if(name != NULL) {
						UInt8 *result = NULL;
						CFIndex length = CFStringGetLength(name);
						CFIndex size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
						result = malloc(size+1);
						if (result != NULL) {
							length = CFStringGetBytes(name, CFRangeMake(0, length), kCFStringEncodingUTF8, '?', 0, result, size, NULL);
							result[length] = 0;
							printf("\t   %s\n", result);
							free(result);
						}
						CFRelease(name);
					}
#define VERBOSE 1
#if VERBOSE
					AudioDeviceGetProperty(j,0,false,kAudioObjectPropertyCreator,&z,&name);
					if(name != NULL) {
						UInt8 *result = NULL;
						CFIndex length = CFStringGetLength(name);
						CFIndex size = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
						result = malloc(size+1);
						if (result != NULL) {
							length = CFStringGetBytes(name, CFRangeMake(0, length), kCFStringEncodingUTF8, '?', 0, result, size, NULL);
							result[length] = 0;
						}
						if(result)
							printf("  Creator: %s\n", result);
						free(result);
						CFRelease(name);
					}
					UInt32 m = 0; z = sizeof(m);
					if(!AudioDeviceGetProperty(j, 0, false, kAudioDevicePropertyMute, &z, &m))
						printf("    Muted: %s\n", m ? "yes" : "no");
					float o = 0.0f; z = sizeof(o);
					if(!AudioDeviceGetProperty(j, 0, false, kAudioDevicePropertyVolumeScalar, &z, &o))
						printf("  Out-Vol: %f\n", o);
					if(!AudioDeviceGetProperty(j, 0, true, kAudioDevicePropertyVolumeScalar, &z, &o))
						printf("   In-Vol: %f\n", o);
					UInt32 cs[2]; z = sizeof(cs);
					if(!AudioDeviceGetProperty(j, 0, false, kAudioDevicePropertyPreferredChannelsForStereo, &z, &cs)) {
						int k; z = sizeof(o);
						for(k = 0; k < 2; k++) {
							if(!AudioDeviceGetProperty(j, cs[k], false, kAudioDevicePropertyVolumeScalar, &z, &o))
								printf("OutVol(%d): %f\n", k, o);
							if(!AudioDeviceGetProperty(j, cs[k], true, kAudioDevicePropertyVolumeScalar, &z, &o))
								printf(" InVol(%d): %f\n", k, o);
						}
					}
					if(i < number_of_devices_on_system)
						puts("----");
#endif
				}
				return 0;
				/*	UInt32 dev_to_set_to;
				dev_to_set_to = *dev_array;
				AudioHardwareSetProperty(kAudioHardwarePropertyDefaultOutputDevice, sizeof(UInt32), &dev_to_set_to);
				*/
			}
		}
	}
	fprintf(stderr, "Usage:  %s [-s <volume> | -m | -u | -i | -v]\n", argv[0]);
	return 1;
}

void setSystemVolume(float involume) {
	AudioDeviceID device;
	UInt32 size = sizeof device;
	OSStatus err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &size, &device);
	if(err != noErr) {
		fputs("audio-volume error getting device\n", stderr);
		exit(2);
	}
	// Try to set the master-channel (0) volume.
	Boolean canset = false;
	size = sizeof canset;
	err = AudioDeviceGetPropertyInfo(device, 0, false, kAudioDevicePropertyVolumeScalar, &size, &canset);
	if(err == noErr && canset==true) {
		size = sizeof involume;
		err = AudioDeviceSetProperty(device, NULL, 0, false, kAudioDevicePropertyVolumeScalar, size, &involume);
		return;
	}
	// else, try seperate channels:
	UInt32 channels[2];
	size = sizeof(channels);
	err = AudioDeviceGetProperty(device, 0, false, kAudioDevicePropertyPreferredChannelsForStereo, &size, &channels);
	if(err != noErr) {
		fputs("Error getting audio device\n", stderr);
		return;
	}
	// Set volume.
	size = sizeof(involume);
	err = AudioDeviceSetProperty(device, NULL, channels[0], false, kAudioDevicePropertyVolumeScalar, size, &involume);
	if(noErr!=err) fprintf(stderr, "Error setting volume of audio channel %lu\n", channels[0]);
	err = AudioDeviceSetProperty(device, NULL, channels[1], false, kAudioDevicePropertyVolumeScalar, size, &involume);
	if(noErr!=err) fprintf(stderr, "Error setting volume of audio channel %lu\n", channels[1]);
}
