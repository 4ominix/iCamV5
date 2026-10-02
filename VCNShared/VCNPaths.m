// CONFIRMED FROM BINARY: All plist filenames (AuthSession, CameraConfig, etc.)
// CONFIRMED FROM BINARY: "incoming.flv", "latest.flv" stream file names
// CONFIRMED FROM BINARY: /var/jb/ roothide prefix throughout
// RECONSTRUCTED: VCNLiveStreamPath "live.vcn" (INFERRED from stream reader refs)

#import "VCNPaths.h"

NSString *const VCNAuthSessionPath       = VCN_SHARED_DIR @"/AuthSession.plist";
NSString *const VCNCameraConfigurationPath = VCN_SHARED_DIR @"/CameraConfig.plist";
NSString *const VCNCameraStatusPath      = VCN_SHARED_DIR @"/CameraStatus.plist";
NSString *const VCNCapabilityLeasePath   = VCN_SHARED_DIR @"/CapabilityLease.plist";
NSString *const VCNServerStatusPath      = VCN_SHARED_DIR @"/ServerStatus.plist";
NSString *const VCNMediaDirectory        = VCN_SHARED_DIR @"/Media";
NSString *const VCNLegacyMediaDirectory  = @"/var/mobile/Library/Application Support/V4HCAMNext/Media";
NSString *const VCNStreamDirectory       = VCN_SHARED_DIR @"/Streams";
NSString *const VCNIncomingStreamPath    = VCN_SHARED_DIR @"/Streams/incoming.flv";
NSString *const VCNLatestStreamPath      = VCN_SHARED_DIR @"/Streams/latest.flv";
NSString *const VCNLiveStreamPath        = VCN_SHARED_DIR @"/Streams/live.vcn";
