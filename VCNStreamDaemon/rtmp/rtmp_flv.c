#include "rtmp_flv.h"
#include <unistd.h>
#include <string.h>

int flv_write_header(int fd, int has_audio, int has_video) {
    uint8_t header[FLV_HEADER_SIZE + FLV_PREV_TAG_SIZE];
    header[0] = 'F'; header[1] = 'L'; header[2] = 'V';
    header[3] = 0x01; // version
    header[4] = (has_audio ? 0x04 : 0x00) | (has_video ? 0x01 : 0x00);
    // Data offset (always 9 for FLV version 1)
    header[5] = 0; header[6] = 0; header[7] = 0; header[8] = FLV_HEADER_SIZE;
    // Previous tag size 0
    header[9] = 0; header[10] = 0; header[11] = 0; header[12] = 0;

    return (write(fd, header, sizeof(header)) == sizeof(header)) ? 0 : -1;
}

int flv_write_tag(int fd, uint8_t type, const uint8_t *data, size_t len, uint32_t timestamp) {
    uint8_t tag_header[FLV_TAG_HEADER_SIZE];

    tag_header[0] = type;
    tag_header[1] = (len >> 16) & 0xFF;
    tag_header[2] = (len >> 8) & 0xFF;
    tag_header[3] = len & 0xFF;
    tag_header[4] = (timestamp >> 16) & 0xFF;
    tag_header[5] = (timestamp >> 8) & 0xFF;
    tag_header[6] = timestamp & 0xFF;
    tag_header[7] = (timestamp >> 24) & 0xFF;
    tag_header[8] = 0; tag_header[9] = 0; tag_header[10] = 0; // StreamID always 0

    if (write(fd, tag_header, FLV_TAG_HEADER_SIZE) != FLV_TAG_HEADER_SIZE) return -1;
    if (write(fd, data, len) != (ssize_t)len) return -1;

    uint32_t prev_tag = (uint32_t)(FLV_TAG_HEADER_SIZE + len);
    uint8_t pts[4] = {
        (prev_tag >> 24) & 0xFF, (prev_tag >> 16) & 0xFF,
        (prev_tag >> 8) & 0xFF, prev_tag & 0xFF
    };
    if (write(fd, pts, 4) != 4) return -1;

    return 0;
}

size_t flv_read_tag_header(const uint8_t *buf, size_t len, flv_tag_t *tag) {
    if (len < FLV_TAG_HEADER_SIZE) return 0;

    tag->type = buf[0];
    tag->data_size = ((uint32_t)buf[1] << 16) | ((uint32_t)buf[2] << 8) | buf[3];
    tag->timestamp = ((uint32_t)buf[4] << 16) | ((uint32_t)buf[5] << 8) | buf[6] |
                     ((uint32_t)buf[7] << 24);

    if (len < FLV_TAG_HEADER_SIZE + tag->data_size + FLV_PREV_TAG_SIZE)
        return 0;

    tag->data = (uint8_t *)(buf + FLV_TAG_HEADER_SIZE);
    return FLV_TAG_HEADER_SIZE + tag->data_size + FLV_PREV_TAG_SIZE;
}
