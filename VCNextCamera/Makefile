include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VCNextCamera

VCNextCamera_FILES  = Tweak.xm
VCNextCamera_FILES += VCNCameraHooks.m
VCNextCamera_FILES += VCNVideoDecoder.m
VCNextCamera_FILES += VCNFrameProcessor.m
VCNextCamera_FILES += VCNFaceDetector.m
VCNextCamera_FILES += VCNColorSync.m
VCNextCamera_FILES += VCNStreamReader.m
VCNextCamera_FRAMEWORKS = Foundation CoreFoundation AVFoundation CoreImage CoreVideo CoreMedia VideoToolbox CoreGraphics ImageIO Vision Security
VCNextCamera_LIBRARIES = VCNShared
VCNextCamera_CFLAGS = -fobjc-arc -I../VCNShared

include $(THEOS_MAKE_PATH)/tweak.mk
