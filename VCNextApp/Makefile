include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = VCNext

VCNext_FILES  = main.m
VCNext_FILES += VCNAppDelegate.m
VCNext_FILES += VCNMainViewController.m
VCNext_FILES += VCNAccountManager.m
VCNext_FILES += VCNMediaPicker.m
VCNext_FILES += VCNCameraConfigController.m
VCNext_FRAMEWORKS = UIKit Foundation CoreFoundation Security PhotosUI AVFoundation UniformTypeIdentifiers
VCNext_LIBRARIES = VCNShared
VCNext_CFLAGS = -fobjc-arc -I../VCNShared
VCNext_LDFLAGS = -L../VCNShared/.theos/obj
VCNext_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
