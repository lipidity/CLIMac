typedef void *QLPreviewRef;
extern QLPreviewRef QLPreviewCreate(void *unknownNULL, CFTypeRef item, CFDictionaryRef options) AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER;
extern CFDataRef QLPreviewCopyData(QLPreviewRef thumbnail) AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER;
//extern CFURLRef QLPreviewCopyURLRepresentation(QLPreviewRef);
extern CFDictionaryRef QLPreviewCopyOptions(QLPreviewRef) AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER;
extern CFDictionaryRef QLPreviewCopyProperties(QLPreviewRef) AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER;
//extern CFStringRef QLPreviewGetPreviewType(QLPreviewRef) AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER_BUT_DEPRECATED_IN_MAC_OS_X_VERSION_10_6; // eg. public.webcontent; public.text; public.image; public.pdf
//extern void QLPreviewSetPreviewType(QLPreviewRef, CFStringRef);
extern CFStringRef QLPreviewGetDisplayBundleID(QLPreviewRef) AVAILABLE_MAC_OS_X_VERSION_10_6_AND_LATER; // com.apple.qldisplay.Web, com.apple.qldisplay.PDF

//extern void QLPreviewSetForceContentTypeUTI(QLPreviewRef, CFStringRef) AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER;

typedef void *QLThumbnailRef;
#if 0
extern const NSString *kQLThumbnailOptionContentTypeUTI;
//extern const NSString *kQLThumbnailOptionIconModeKey;
extern QLThumbnailRef QLThumbnailCreate(void *unknownNULL, CFURLRef fileURL, CGSize iconSize, CFDictionaryRef options);
extern CGImageRef QLThumbnailCopyImage(QLThumbnailRef thumbnail);
_QLThumbnailSupportsContentUTIAtSize
_QLThumbnailCopySpecialGenericImage
_QLThumbnailGetMaximumSize
_QLThumbnailGetMinimumUsefulSize
_QLThumbnailSetForceContentTypeUTI
#endif
