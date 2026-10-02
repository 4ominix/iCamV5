include $(THEOS)/makefiles/common.mk

TOOL_NAME = VCNNetworkDaemon

VCNNetworkDaemon_FILES  = main.m
VCNNetworkDaemon_FILES += VCNAuthHeartbeat.m
VCNNetworkDaemon_FILES += VCNHTTPClient.m
VCNNetworkDaemon_FILES += VCNCellularPolicy.m
VCNNetworkDaemon_FRAMEWORKS = Foundation CoreFoundation Security
VCNNetworkDaemon_LIBRARIES = VCNShared
VCNNetworkDaemon_CFLAGS = -fobjc-arc -I../VCNShared
VCNNetworkDaemon_LDFLAGS = -L../.theos/obj
VCNNetworkDaemon_INSTALL_PATH = /usr/libexec
VCNNetworkDaemon_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
