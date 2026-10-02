INSTALL_TARGET_PROCESSES =
ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

SUBPROJECTS  = VCNShared
SUBPROJECTS += VCNextApp
SUBPROJECTS += VCNextCamera
SUBPROJECTS += VCNextOverlay
SUBPROJECTS += VCNextBrandUI
SUBPROJECTS += VCNextNetworkCompat
SUBPROJECTS += VCNStreamDaemon
SUBPROJECTS += VCNNetworkDaemon
SUBPROJECTS += VCNNetworkDaemonLauncher

include $(THEOS_MAKE_PATH)/aggregate.mk
