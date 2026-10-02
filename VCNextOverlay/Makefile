include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VCNextOverlay

VCNextOverlay_FILES  = Tweak.xm
VCNextOverlay_FILES += VCNFloatingWindow.m
VCNextOverlay_FILES += VCNControlPanel.m
VCNextOverlay_FILES += VCNScreenCapture.m
VCNextOverlay_FRAMEWORKS = Foundation CoreFoundation UIKit QuartzCore IOSurface CoreGraphics Security
VCNextOverlay_LIBRARIES = VCNShared
VCNextOverlay_CFLAGS = -fobjc-arc -I../VCNShared

include $(THEOS_MAKE_PATH)/tweak.mk
