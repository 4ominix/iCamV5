include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libVCNShared

libVCNShared_FILES  = VCNPaths.m
libVCNShared_FILES += VCNNotifications.m
libVCNShared_FILES += VCNSecurity.m
libVCNShared_FILES += VCNConfig.m
libVCNShared_FRAMEWORKS = Foundation CoreFoundation Security
libVCNShared_INSTALL_PATH = /usr/lib
libVCNShared_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/library.mk
