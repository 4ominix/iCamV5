#ifndef RTMP_CHUNK_H
#define RTMP_CHUNK_H

#include "rtmp_server.h"
#include <stdint.h>
#include <stddef.h>

#define RTMP_MAX_CHANNELS 64
#define RTMP_MSG_BUF_SIZE (1024 * 1024)

typedef struct {
    uint32_t csid;
    uint32_t timestamp;
    uint32_t msg_length;
    uint8_t  type_id;
    uint32_t stream_id;
    int      has_header;
} rtmp_chunk_header_t;

typedef struct {
    rtmp_chunk_header_t channels[RTMP_MAX_CHANNELS];

    uint8_t *msg_buf;
    size_t   msg_len;
    size_t   msg_capacity;

    uint32_t current_csid;
    uint32_t current_type_id;
    uint32_t current_timestamp;
    uint32_t current_stream_id;
    uint32_t current_msg_length;
    size_t   current_bytes_read;

    int message_complete;
} rtmp_chunk_context_t;

typedef struct {
    uint32_t       csid;
    uint8_t        type_id;
    uint32_t       timestamp;
    uint32_t       stream_id;
    const uint8_t *data;
    size_t         data_len;
} rtmp_chunk_t;

void   rtmp_chunk_context_init(rtmp_chunk_context_t *ctx);
void   rtmp_chunk_context_free(rtmp_chunk_context_t *ctx);
size_t rtmp_chunk_read(rtmp_chunk_context_t *ctx, const uint8_t *data, size_t len, uint32_t chunk_size);
int    rtmp_chunk_write(rtmp_server_t *s, const rtmp_chunk_t *chunk);

// Internal dispatch
void rtmp_handler(rtmp_server_t *s, rtmp_chunk_context_t *ctx);
void rtmp_control_handler(rtmp_server_t *s, const uint8_t *data, size_t len);
void rtmp_invoke_handler(rtmp_server_t *s, rtmp_chunk_context_t *ctx);
void rtmp_event_pong(rtmp_server_t *s, uint32_t timestamp);
void rtmp_event_stream_begin(rtmp_server_t *s, uint32_t stream_id);
void rtmp_set_chunk_size(rtmp_server_t *s, uint32_t size);
void rtmp_window_acknowledgement_size(rtmp_server_t *s, uint32_t size);
void rtmp_set_peer_bandwidth(rtmp_server_t *s, uint32_t size);
void rtmp_acknowledgement(rtmp_server_t *s);
void rtmp_abort_message(rtmp_server_t *s, uint32_t csid);

#endif
