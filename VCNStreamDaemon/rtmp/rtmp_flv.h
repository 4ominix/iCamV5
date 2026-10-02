#ifndef RTMP_FLV_H
#define RTMP_FLV_H

#include <stdint.h>
#include <stddef.h>

#define FLV_TAG_AUDIO 0x08
#define FLV_TAG_VIDEO 0x09
#define FLV_TAG_SCRIPT 0x12

#define FLV_HEADER_SIZE 9
#define FLV_TAG_HEADER_SIZE 11
#define FLV_PREV_TAG_SIZE 4

typedef struct {
    uint8_t  type;
    uint32_t data_size;
    uint32_t timestamp;
    uint8_t  *data;
} flv_tag_t;

// Write FLV header to file descriptor
int flv_write_header(int fd, int has_audio, int has_video);

// Write a single FLV tag
int flv_write_tag(int fd, uint8_t type, const uint8_t *data, size_t len, uint32_t timestamp);

// Parse FLV tag header from buffer (returns bytes consumed, 0 on incomplete)
size_t flv_read_tag_header(const uint8_t *buf, size_t len, flv_tag_t *tag);

#endif
