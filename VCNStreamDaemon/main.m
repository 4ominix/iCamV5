// CONFIRMED FROM BINARY: Port 1935 constant, "ServerStatus.plist" string
// CONFIRMED FROM BINARY: "incoming.flv" output path
// CONFIRMED: LaunchDaemon com.vcnext.streamd, UserName=mobile
// RECONSTRUCTED: FLV video callback (tag writing logic from format spec)
// RECONSTRUCTED: Status polling loop with capability check

#import <Foundation/Foundation.h>
#import <signal.h>
#import "rtmp/rtmp_server.h"
#import "VCNPaths.h"
#import "VCNNotifications.h"
#import "VCNConfig.h"
#import "VCNSecurity.h"

#define RTMP_PORT 1935
#define STATUS_POLL_INTERVAL 5.0

static rtmp_server_t *g_server = NULL;

static void signalHandler(int sig) {
    if (g_server) rtmp_server_destroy(g_server);
    exit(0);
}

static void onVideoData(const uint8_t *data, size_t len, uint32_t timestamp, void *ctx) {
    // Write incoming video data to the FLV file for the camera dylib to read
    static FILE *flvFile = NULL;
    if (!flvFile) {
        [VCNConfig ensureDirectoryExists:VCNStreamDirectory];
        flvFile = fopen(VCNIncomingStreamPath.UTF8String, "wb");
        if (!flvFile) return;
        // Write FLV header
        uint8_t header[] = {'F','L','V', 0x01, 0x01, 0x00,0x00,0x00,0x09, 0x00,0x00,0x00,0x00};
        fwrite(header, 1, sizeof(header), flvFile);
    }

    // Write FLV video tag
    uint8_t tagHeader[11];
    tagHeader[0] = 0x09; // video
    tagHeader[1] = (len >> 16) & 0xFF;
    tagHeader[2] = (len >> 8) & 0xFF;
    tagHeader[3] = len & 0xFF;
    tagHeader[4] = (timestamp >> 16) & 0xFF;
    tagHeader[5] = (timestamp >> 8) & 0xFF;
    tagHeader[6] = timestamp & 0xFF;
    tagHeader[7] = (timestamp >> 24) & 0xFF;
    tagHeader[8] = 0; tagHeader[9] = 0; tagHeader[10] = 0;

    fwrite(tagHeader, 1, 11, flvFile);
    fwrite(data, 1, len, flvFile);

    uint32_t prevTagSize = (uint32_t)(11 + len);
    uint8_t pts[4] = {
        (prevTagSize >> 24) & 0xFF, (prevTagSize >> 16) & 0xFF,
        (prevTagSize >> 8) & 0xFF, prevTagSize & 0xFF
    };
    fwrite(pts, 1, 4, flvFile);
    fflush(flvFile);
    fsync(fileno(flvFile));
}

static void onAudioData(const uint8_t *data, size_t len, uint32_t timestamp, void *ctx) {
    // Audio passthrough - not used for camera replacement
}

static void onStatusChanged(rtmp_server_state_t state, void *ctx) {
    NSString *stateStr;
    switch (state) {
        case RTMP_STATE_IDLE:      stateStr = @"idle";      break;
        case RTMP_STATE_LISTENING: stateStr = @"listening"; break;
        case RTMP_STATE_CONNECTED: stateStr = @"connected"; break;
        case RTMP_STATE_STREAMING: stateStr = @"streaming"; break;
        default:                   stateStr = @"unknown";   break;
    }

    [VCNConfig setServerStatus:@{
        @"state": stateStr,
        @"port": @(RTMP_PORT),
        @"timestamp": @([NSDate date].timeIntervalSince1970),
    }];

    VCNPostDarwinNotification(VCNServerStatusChangedNotification);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        signal(SIGTERM, signalHandler);
        signal(SIGINT, signalHandler);
        signal(SIGPIPE, SIG_IGN);

        srand((unsigned)time(NULL));

        [VCNConfig ensureDirectoryExists:VCN_SHARED_DIR];
        [VCNConfig ensureDirectoryExists:VCNStreamDirectory];

        printf("VCNStreamDaemon: starting RTMP server on port %d\n", RTMP_PORT);

        g_server = rtmp_server_create(RTMP_PORT);
        if (!g_server) {
            printf("VCNStreamDaemon: failed to create RTMP server\n");
            return 1;
        }

        rtmp_server_set_video_callback(g_server, onVideoData, NULL);
        rtmp_server_set_audio_callback(g_server, onAudioData, NULL);
        rtmp_server_set_status_callback(g_server, onStatusChanged, NULL);

        if (rtmp_server_start(g_server) != 0) {
            printf("VCNStreamDaemon: failed to start RTMP server\n");
            rtmp_server_destroy(g_server);
            return 1;
        }

        onStatusChanged(RTMP_STATE_LISTENING, NULL);

        // Run forever - launchd restarts us if we exit
        while (1) {
            sleep(STATUS_POLL_INTERVAL);

            rtmp_server_state_t state = rtmp_server_getstate(g_server);
            NSDictionary *capability = [VCNConfig capabilityLease];
            if (capability && ![capability[@"streamEnabled"] boolValue]) {
                if (state == RTMP_STATE_STREAMING || state == RTMP_STATE_CONNECTED) {
                    printf("VCNStreamDaemon: capability revoked, disconnecting\n");
                }
            }
        }

        rtmp_server_destroy(g_server);
        return 0;
    }
}
