#import "VCNStreamReader.h"
#import "VCNPaths.h"
#import "VCNNotifications.h"
#import <CoreVideo/CoreVideo.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

typedef struct {
    uint8_t  signature[3];   // "FLV"
    uint8_t  version;
    uint8_t  flags;
    uint32_t headerSize;
} __attribute__((packed)) FLVHeader;

typedef struct {
    uint8_t  tagType;
    uint8_t  dataSize[3];
    uint8_t  timestamp[3];
    uint8_t  timestampExt;
    uint8_t  streamID[3];
} __attribute__((packed)) FLVTagHeader;

#define FLV_TAG_AUDIO 8
#define FLV_TAG_VIDEO 9
#define FLV_TAG_SCRIPT 18

@implementation VCNStreamReader {
    VCNVideoDecoder    *_decoder;
    dispatch_source_t   _fileWatcher;
    dispatch_queue_t    _readQueue;
    NSString           *_currentPath;
    int                 _fd;
    off_t               _readOffset;
    BOOL                _headerParsed;
    NSData             *_spsData;
    NSData             *_ppsData;
}

- (instancetype)init {
    if ((self = [super init])) {
        _readQueue = dispatch_queue_create("com.vcnext.streamreader", DISPATCH_QUEUE_SERIAL);
        _decoder = [[VCNVideoDecoder alloc] init];
        _fd = -1;
        __weak typeof(self) weakSelf = self;
        _decoder.frameCallback = ^(CVPixelBufferRef pb, CMTime pts) {
            __strong typeof(weakSelf) self = weakSelf;
            if (self && self.frameProcessor) {
                @synchronized(self.frameProcessor) {
                    CVPixelBufferRef old = self.frameProcessor.currentVideoSample;
                    self.frameProcessor.currentVideoSample = CVPixelBufferRetain(pb);
                    if (old) CVPixelBufferRelease(old);
                }
            }
        };
    }
    return self;
}

- (void)dealloc {
    [self stopReading];
}

- (void)startReadingFromPath:(NSString *)path {
    [self stopReading];
    _currentPath = [path copy];
    _readOffset = 0;
    _headerParsed = NO;

    _fd = open(path.UTF8String, O_RDONLY);
    if (_fd < 0) return;

    _isReading = YES;

    _fileWatcher = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _readQueue);
    dispatch_source_set_timer(_fileWatcher, DISPATCH_TIME_NOW, 33 * NSEC_PER_MSEC, 5 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_fileWatcher, ^{
        [self _readAvailableData];
    });
    dispatch_resume(_fileWatcher);
}

- (void)stopReading {
    if (_fileWatcher) {
        dispatch_source_cancel(_fileWatcher);
        _fileWatcher = nil;
    }
    if (_fd >= 0) {
        close(_fd);
        _fd = -1;
    }
    [_decoder invalidate];
    _isReading = NO;
}

- (void)_readAvailableData {
    if (_fd < 0) return;

    struct stat st;
    if (fstat(_fd, &st) != 0) return;
    off_t fileSize = st.st_size;
    if (_readOffset >= fileSize) return;

    if (!_headerParsed) {
        if (fileSize < sizeof(FLVHeader) + 4) return;
        FLVHeader header;
        pread(_fd, &header, sizeof(header), 0);
        if (memcmp(header.signature, "FLV", 3) != 0) {
            [self stopReading];
            return;
        }
        uint32_t hdrSize = ntohl(header.headerSize);
        _readOffset = hdrSize + 4;
        _headerParsed = YES;
    }

    while (_readOffset + sizeof(FLVTagHeader) < fileSize) {
        FLVTagHeader tagHdr;
        ssize_t rd = pread(_fd, &tagHdr, sizeof(tagHdr), _readOffset);
        if (rd < (ssize_t)sizeof(tagHdr)) break;

        uint32_t dataSize = ((uint32_t)tagHdr.dataSize[0] << 16) |
                            ((uint32_t)tagHdr.dataSize[1] << 8) |
                            (uint32_t)tagHdr.dataSize[2];

        uint32_t timestamp = ((uint32_t)tagHdr.timestamp[0] << 16) |
                             ((uint32_t)tagHdr.timestamp[1] << 8) |
                             (uint32_t)tagHdr.timestamp[2] |
                             ((uint32_t)tagHdr.timestampExt << 24);

        off_t tagEnd = _readOffset + sizeof(FLVTagHeader) + dataSize + 4;
        if (tagEnd > fileSize) break;

        if (tagHdr.tagType == FLV_TAG_VIDEO && dataSize > 5) {
            NSMutableData *tagData = [NSMutableData dataWithLength:dataSize];
            pread(_fd, tagData.mutableBytes, dataSize, _readOffset + sizeof(FLVTagHeader));
            [self _processVideoTag:tagData timestamp:timestamp];
        }

        _readOffset = tagEnd;
    }
}

- (void)_processVideoTag:(NSData *)data timestamp:(uint32_t)ts {
    if (data.length < 5) return;
    const uint8_t *bytes = data.bytes;

    uint8_t codecID = bytes[0] & 0x0F;

    if (codecID != 7) return; // AVC/H.264

    uint8_t avcPacketType = bytes[1];

    if (avcPacketType == 0) {
        [self _parseAVCDecoderConfig:[data subdataWithRange:NSMakeRange(5, data.length - 5)]];
    } else if (avcPacketType == 1) {
        NSData *nalData = [data subdataWithRange:NSMakeRange(5, data.length - 5)];
        CMTime pts = CMTimeMake(ts, 1000);
        [self _feedNALUnits:nalData timestamp:pts];
    }
}

- (void)_parseAVCDecoderConfig:(NSData *)config {
    if (config.length < 8) return;
    const uint8_t *p = config.bytes;

    uint8_t numSPS = p[5] & 0x1F;
    size_t offset = 6;

    for (int i = 0; i < numSPS && offset + 2 < config.length; i++) {
        uint16_t spsLen = (p[offset] << 8) | p[offset + 1];
        offset += 2;
        if (offset + spsLen > config.length) break;
        _spsData = [config subdataWithRange:NSMakeRange(offset, spsLen)];
        offset += spsLen;
    }

    if (offset >= config.length) return;
    uint8_t numPPS = p[offset];
    offset++;

    for (int i = 0; i < numPPS && offset + 2 < config.length; i++) {
        uint16_t ppsLen = (p[offset] << 8) | p[offset + 1];
        offset += 2;
        if (offset + ppsLen > config.length) break;
        _ppsData = [config subdataWithRange:NSMakeRange(offset, ppsLen)];
        offset += ppsLen;
    }

    if (_spsData && _ppsData) {
        [_decoder feedH264SPS:_spsData PPS:_ppsData];
    }
}

- (void)_feedNALUnits:(NSData *)data timestamp:(CMTime)pts {
    if (data.length < 4 || !_decoder.isReady) return;
    const uint8_t *p = data.bytes;
    size_t len = data.length;
    size_t offset = 0;

    while (offset + 4 < len) {
        uint32_t nalSize = ((uint32_t)p[offset] << 24) | ((uint32_t)p[offset+1] << 16) |
                           ((uint32_t)p[offset+2] << 8) | (uint32_t)p[offset+3];
        offset += 4;
        if (offset + nalSize > len) break;

        uint8_t startCode[4] = {0, 0, 0, 1};
        NSMutableData *nalUnit = [NSMutableData dataWithBytes:startCode length:4];
        [nalUnit appendBytes:p + offset length:nalSize];
        [_decoder feedNALUnit:nalUnit timestamp:pts];

        offset += nalSize;
    }
}

@end
