#include "rtmp_chunk.h"
#include <string.h>
#include <stdlib.h>
#include <sys/socket.h>

void rtmp_chunk_context_init(rtmp_chunk_context_t *ctx) {
    memset(ctx, 0, sizeof(rtmp_chunk_context_t));
    ctx->msg_capacity = RTMP_MSG_BUF_SIZE;
    ctx->msg_buf = malloc(ctx->msg_capacity);
}

void rtmp_chunk_context_free(rtmp_chunk_context_t *ctx) {
    if (ctx->msg_buf) { free(ctx->msg_buf); ctx->msg_buf = NULL; }
}

static size_t read_basic_header(const uint8_t *data, size_t len, uint32_t *csid, uint8_t *fmt) {
    if (len < 1) return 0;
    *fmt = (data[0] >> 6) & 0x03;
    *csid = data[0] & 0x3F;

    if (*csid == 0) {
        if (len < 2) return 0;
        *csid = data[1] + 64;
        return 2;
    } else if (*csid == 1) {
        if (len < 3) return 0;
        *csid = data[2] * 256 + data[1] + 64;
        return 3;
    }
    return 1;
}

size_t rtmp_chunk_read(rtmp_chunk_context_t *ctx, const uint8_t *data, size_t len, uint32_t chunk_size) {
    uint32_t csid;
    uint8_t fmt;
    size_t offset = read_basic_header(data, len, &csid, &fmt);
    if (offset == 0) return 0;

    if (csid >= RTMP_MAX_CHANNELS) return 0;
    rtmp_chunk_header_t *ch = &ctx->channels[csid];

    uint32_t timestamp = 0, msg_length = 0;
    uint8_t type_id = 0;
    uint32_t stream_id = 0;

    switch (fmt) {
        case 0: // Full header (11 bytes)
            if (len - offset < 11) return 0;
            timestamp = ((uint32_t)data[offset] << 16) | ((uint32_t)data[offset+1] << 8) | data[offset+2];
            msg_length = ((uint32_t)data[offset+3] << 16) | ((uint32_t)data[offset+4] << 8) | data[offset+5];
            type_id = data[offset+6];
            stream_id = data[offset+7] | ((uint32_t)data[offset+8] << 8) |
                        ((uint32_t)data[offset+9] << 16) | ((uint32_t)data[offset+10] << 24);
            offset += 11;
            if (timestamp == 0xFFFFFF) {
                if (len - offset < 4) return 0;
                timestamp = ((uint32_t)data[offset] << 24) | ((uint32_t)data[offset+1] << 16) |
                            ((uint32_t)data[offset+2] << 8) | data[offset+3];
                offset += 4;
            }
            ch->timestamp = timestamp;
            ch->msg_length = msg_length;
            ch->type_id = type_id;
            ch->stream_id = stream_id;
            ch->has_header = 1;
            ctx->current_bytes_read = 0;
            ctx->msg_len = 0;
            break;

        case 1: // No stream ID (7 bytes)
            if (len - offset < 7) return 0;
            timestamp = ((uint32_t)data[offset] << 16) | ((uint32_t)data[offset+1] << 8) | data[offset+2];
            msg_length = ((uint32_t)data[offset+3] << 16) | ((uint32_t)data[offset+4] << 8) | data[offset+5];
            type_id = data[offset+6];
            offset += 7;
            if (timestamp == 0xFFFFFF) {
                if (len - offset < 4) return 0;
                timestamp = ((uint32_t)data[offset] << 24) | ((uint32_t)data[offset+1] << 16) |
                            ((uint32_t)data[offset+2] << 8) | data[offset+3];
                offset += 4;
            }
            ch->timestamp += timestamp;
            ch->msg_length = msg_length;
            ch->type_id = type_id;
            ctx->current_bytes_read = 0;
            ctx->msg_len = 0;
            break;

        case 2: // Timestamp delta only (3 bytes)
            if (len - offset < 3) return 0;
            timestamp = ((uint32_t)data[offset] << 16) | ((uint32_t)data[offset+1] << 8) | data[offset+2];
            offset += 3;
            if (timestamp == 0xFFFFFF) {
                if (len - offset < 4) return 0;
                timestamp = ((uint32_t)data[offset] << 24) | ((uint32_t)data[offset+1] << 16) |
                            ((uint32_t)data[offset+2] << 8) | data[offset+3];
                offset += 4;
            }
            ch->timestamp += timestamp;
            ctx->current_bytes_read = 0;
            ctx->msg_len = 0;
            break;

        case 3: // No header - continuation
            break;
    }

    ctx->current_csid = csid;
    ctx->current_type_id = ch->type_id;
    ctx->current_timestamp = ch->timestamp;
    ctx->current_stream_id = ch->stream_id;
    ctx->current_msg_length = ch->msg_length;

    size_t remaining = ch->msg_length - ctx->current_bytes_read;
    size_t to_read = remaining < chunk_size ? remaining : chunk_size;
    if (len - offset < to_read) return 0;

    if (ctx->msg_len + to_read > ctx->msg_capacity) {
        ctx->msg_capacity = ctx->msg_len + to_read + 4096;
        ctx->msg_buf = realloc(ctx->msg_buf, ctx->msg_capacity);
    }
    memcpy(ctx->msg_buf + ctx->msg_len, data + offset, to_read);
    ctx->msg_len += to_read;
    ctx->current_bytes_read += to_read;
    offset += to_read;

    if (ctx->current_bytes_read >= ch->msg_length) {
        ctx->message_complete = 1;
        ctx->current_bytes_read = 0;
    }

    return offset;
}

int rtmp_chunk_write(rtmp_server_t *s, const rtmp_chunk_t *chunk) {
    uint32_t chunk_size = 4096;
    size_t remaining = chunk->data_len;
    size_t data_offset = 0;
    int first = 1;

    while (remaining > 0) {
        uint8_t header[18];
        size_t hdr_len = 0;

        if (first) {
            // fmt=0 full header
            if (chunk->csid < 64) {
                header[0] = (0 << 6) | (chunk->csid & 0x3F);
                hdr_len = 1;
            } else if (chunk->csid < 320) {
                header[0] = (0 << 6) | 0;
                header[1] = (chunk->csid - 64) & 0xFF;
                hdr_len = 2;
            } else {
                header[0] = (0 << 6) | 1;
                uint32_t v = chunk->csid - 64;
                header[1] = v & 0xFF;
                header[2] = (v >> 8) & 0xFF;
                hdr_len = 3;
            }

            uint32_t ts = chunk->timestamp;
            int ext_ts = (ts >= 0xFFFFFF);
            uint32_t ts_field = ext_ts ? 0xFFFFFF : ts;

            header[hdr_len++] = (ts_field >> 16) & 0xFF;
            header[hdr_len++] = (ts_field >> 8) & 0xFF;
            header[hdr_len++] = ts_field & 0xFF;
            header[hdr_len++] = (chunk->data_len >> 16) & 0xFF;
            header[hdr_len++] = (chunk->data_len >> 8) & 0xFF;
            header[hdr_len++] = chunk->data_len & 0xFF;
            header[hdr_len++] = chunk->type_id;
            header[hdr_len++] = chunk->stream_id & 0xFF;
            header[hdr_len++] = (chunk->stream_id >> 8) & 0xFF;
            header[hdr_len++] = (chunk->stream_id >> 16) & 0xFF;
            header[hdr_len++] = (chunk->stream_id >> 24) & 0xFF;

            if (ext_ts) {
                header[hdr_len++] = (ts >> 24) & 0xFF;
                header[hdr_len++] = (ts >> 16) & 0xFF;
                header[hdr_len++] = (ts >> 8) & 0xFF;
                header[hdr_len++] = ts & 0xFF;
            }
            first = 0;
        } else {
            // fmt=3 continuation
            if (chunk->csid < 64) {
                header[0] = (3 << 6) | (chunk->csid & 0x3F);
                hdr_len = 1;
            } else if (chunk->csid < 320) {
                header[0] = (3 << 6) | 0;
                header[1] = (chunk->csid - 64) & 0xFF;
                hdr_len = 2;
            } else {
                header[0] = (3 << 6) | 1;
                uint32_t v = chunk->csid - 64;
                header[1] = v & 0xFF;
                header[2] = (v >> 8) & 0xFF;
                hdr_len = 3;
            }
        }

        size_t payload = remaining < chunk_size ? remaining : chunk_size;

        int fd = rtmp_server_get_client_fd(s);

        // Send header
        ssize_t n = send(fd, header, hdr_len, 0);
        if (n <= 0) return -1;

        // Send payload
        n = send(fd, chunk->data + data_offset, payload, 0);
        if (n <= 0) return -1;

        data_offset += payload;
        remaining -= payload;
    }

    return 0;
}
