include $(THEOS)/makefiles/common.mk

TOOL_NAME = VCNStreamDaemon

VCNStreamDaemon_FILES  = main.m
VCNStreamDaemon_FILES += rtmp/rtmp_server.c
VCNStreamDaemon_FILES += rtmp/rtmp_handshake.c
VCNStreamDaemon_FILES += rtmp/rtmp_chunk.c
VCNStreamDaemon_FILES += rtmp/rtmp_amf.c
VCNStreamDaemon_FILES += rtmp/rtmp_netconnection.c
VCNStreamDaemon_FILES += rtmp/rtmp_netstream.c
VCNStreamDaemon_FILES += rtmp/rtmp_flv.c
VCNStreamDaemon_FRAMEWORKS = Foundation CoreFoundation Security
VCNStreamDaemon_LIBRARIES = VCNShared
VCNStreamDaemon_CFLAGS = -fobjc-arc -I../VCNShared
VCNStreamDaemon_LDFLAGS = -L../.theos/obj
VCNStreamDaemon_INSTALL_PATH = /usr/libexec

include $(THEOS_MAKE_PATH)/tool.mk
