// CONFIRMED FROM BINARY: Window Ack Size 2500000, Chunk Size 4096 constants
// CONFIRMED FROM BINARY: TCP socket + blocking accept + recv pattern
// CONFIRMED FROM BINARY: Message type IDs 1,4,8,9,18,20 dispatch
// CONFIRMED FROM BINARY: "FMS/5,0,15,5004" version string
// RECONSTRUCTED: Server struct layout, protocol control message handlers
// RECONSTRUCTED: Opaque struct accessor pattern for module separation

#include "rtmp_server.h"
#include "rtmp_handshake.h"
#include "rtmp_chunk.h"
#include "rtmp_amf.h"
#include "rtmp_netconnection.h"
#include "rtmp_netstream.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <fcntl.h>

#define RTMP_CHUNK_SIZE_DEFAULT 4096
#define RTMP_RECV_BUF_SIZE     65536

struct rtmp_server {
    int listen_fd;
    int client_fd;
    int port;
    rtmp_server_state_t state;

    uint32_t chunk_size_in;
    uint32_t chunk_size_out;
    uint32_t window_ack_size;
    uint32_t bytes_received;

    rtmp_handshake_state_t hs_state;
    rtmp_chunk_context_t   chunk_ctx;

    uint32_t next_stream_id;
    int publishing;

    rtmp_video_callback_t video_cb;
    void *video_ctx;
    rtmp_audio_callback_t audio_cb;
    void *audio_ctx;
    rtmp_status_callback_t status_cb;
    void *status_ctx;

    uint8_t recv_buf[RTMP_RECV_BUF_SIZE];
};

rtmp_server_t *rtmp_server_create(int port) {
    rtmp_server_t *s = calloc(1, sizeof(rtmp_server_t));
    if (!s) return NULL;
    s->port = port;
    s->listen_fd = -1;
    s->client_fd = -1;
    s->chunk_size_in = 128;
    s->chunk_size_out = RTMP_CHUNK_SIZE_DEFAULT;
    s->window_ack_size = 2500000;
    s->next_stream_id = 1;
    s->state = RTMP_STATE_IDLE;
    rtmp_chunk_context_init(&s->chunk_ctx);
    return s;
}

void rtmp_server_destroy(rtmp_server_t *s) {
    if (!s) return;
    if (s->client_fd >= 0) { shutdown(s->client_fd, SHUT_RDWR); close(s->client_fd); }
    if (s->listen_fd >= 0) close(s->listen_fd);
    rtmp_chunk_context_free(&s->chunk_ctx);
    free(s);
}

static void set_state(rtmp_server_t *s, rtmp_server_state_t state) {
    s->state = state;
    if (s->status_cb) s->status_cb(state, s->status_ctx);
}

int rtmp_server_start(rtmp_server_t *s) {
    s->listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (s->listen_fd < 0) return -1;

    int opt = 1;
    setsockopt(s->listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(s->port);
    addr.sin_addr.s_addr = INADDR_ANY;

    if (bind(s->listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(s->listen_fd);
        s->listen_fd = -1;
        return -1;
    }
    if (listen(s->listen_fd, 1) < 0) {
        close(s->listen_fd);
        s->listen_fd = -1;
        return -1;
    }

    set_state(s, RTMP_STATE_LISTENING);

    // Accept loop runs in the caller's thread (main.m calls this then sleeps)
    // For a production server you'd want this in its own thread.
    // The original binary uses blocking accept + recv in a loop.

    while (1) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        s->client_fd = accept(s->listen_fd, (struct sockaddr *)&client_addr, &client_len);
        if (s->client_fd < 0) {
            if (errno == EINTR) continue;
            break;
        }

        set_state(s, RTMP_STATE_CONNECTED);
        s->hs_state = RTMP_HS_WAITING_C0;
        s->publishing = 0;
        s->bytes_received = 0;

        // Connection loop
        while (1) {
            ssize_t n = recv(s->client_fd, s->recv_buf, sizeof(s->recv_buf), 0);
            if (n <= 0) break;

            s->bytes_received += n;
            rtmp_server_input(s, s->recv_buf, n);

            if (s->bytes_received >= s->window_ack_size) {
                rtmp_acknowledgement(s);
                s->bytes_received = 0;
            }
        }

        close(s->client_fd);
        s->client_fd = -1;
        s->publishing = 0;
        set_state(s, RTMP_STATE_LISTENING);
    }

    return 0;
}

rtmp_server_state_t rtmp_server_getstate(rtmp_server_t *s) {
    return s ? s->state : RTMP_STATE_IDLE;
}

void rtmp_server_set_video_callback(rtmp_server_t *s, rtmp_video_callback_t cb, void *ctx) {
    s->video_cb = cb; s->video_ctx = ctx;
}
void rtmp_server_set_audio_callback(rtmp_server_t *s, rtmp_audio_callback_t cb, void *ctx) {
    s->audio_cb = cb; s->audio_ctx = ctx;
}
void rtmp_server_set_status_callback(rtmp_server_t *s, rtmp_status_callback_t cb, void *ctx) {
    s->status_cb = cb; s->status_ctx = ctx;
}

void rtmp_server_input(rtmp_server_t *s, const uint8_t *data, size_t len) {
    size_t offset = 0;

    // Handle handshake first
    if (s->hs_state != RTMP_HS_DONE) {
        offset = rtmp_handshake_process(s, data, len);
        if (s->hs_state != RTMP_HS_DONE || offset >= len) return;
    }

    // Parse RTMP chunks
    while (offset < len) {
        size_t consumed = rtmp_chunk_read(&s->chunk_ctx, data + offset, len - offset,
                                           s->chunk_size_in);
        if (consumed == 0) break;
        offset += consumed;

        if (s->chunk_ctx.message_complete) {
            rtmp_handler(s, &s->chunk_ctx);
            s->chunk_ctx.message_complete = 0;
        }
    }
}

// Protocol control messages
void rtmp_set_chunk_size(rtmp_server_t *s, uint32_t size) {
    uint8_t msg[4];
    msg[0] = (size >> 24) & 0x7F;
    msg[1] = (size >> 16) & 0xFF;
    msg[2] = (size >> 8) & 0xFF;
    msg[3] = size & 0xFF;

    rtmp_chunk_t chunk = {0};
    chunk.csid = 2;
    chunk.type_id = 1;
    chunk.data = msg;
    chunk.data_len = 4;
    rtmp_chunk_write(s, &chunk);
    s->chunk_size_out = size;
}

void rtmp_window_acknowledgement_size(rtmp_server_t *s, uint32_t size) {
    uint8_t msg[4];
    msg[0] = (size >> 24) & 0xFF;
    msg[1] = (size >> 16) & 0xFF;
    msg[2] = (size >> 8) & 0xFF;
    msg[3] = size & 0xFF;

    rtmp_chunk_t chunk = {0};
    chunk.csid = 2;
    chunk.type_id = 5;
    chunk.data = msg;
    chunk.data_len = 4;
    rtmp_chunk_write(s, &chunk);
}

void rtmp_set_peer_bandwidth(rtmp_server_t *s, uint32_t size) {
    uint8_t msg[5];
    msg[0] = (size >> 24) & 0xFF;
    msg[1] = (size >> 16) & 0xFF;
    msg[2] = (size >> 8) & 0xFF;
    msg[3] = size & 0xFF;
    msg[4] = 2; // dynamic
    rtmp_chunk_t chunk = {0};
    chunk.csid = 2;
    chunk.type_id = 6;
    chunk.data = msg;
    chunk.data_len = 5;
    rtmp_chunk_write(s, &chunk);
}

void rtmp_acknowledgement(rtmp_server_t *s) {
    uint8_t msg[4];
    uint32_t seq = s->bytes_received;
    msg[0] = (seq >> 24) & 0xFF;
    msg[1] = (seq >> 16) & 0xFF;
    msg[2] = (seq >> 8) & 0xFF;
    msg[3] = seq & 0xFF;
    rtmp_chunk_t chunk = {0};
    chunk.csid = 2;
    chunk.type_id = 3;
    chunk.data = msg;
    chunk.data_len = 4;
    rtmp_chunk_write(s, &chunk);
}

void rtmp_abort_message(rtmp_server_t *s, uint32_t csid) {
    uint8_t msg[4];
    msg[0] = (csid >> 24) & 0xFF;
    msg[1] = (csid >> 16) & 0xFF;
    msg[2] = (csid >> 8) & 0xFF;
    msg[3] = csid & 0xFF;
    rtmp_chunk_t chunk = {0};
    chunk.csid = 2;
    chunk.type_id = 2;
    chunk.data = msg;
    chunk.data_len = 4;
    rtmp_chunk_write(s, &chunk);
}

// Message handler dispatch
void rtmp_handler(rtmp_server_t *s, rtmp_chunk_context_t *ctx) {
    switch (ctx->current_type_id) {
        case 1: // Set Chunk Size
            if (ctx->msg_len >= 4) {
                s->chunk_size_in = ((uint32_t)ctx->msg_buf[0] << 24) |
                                   ((uint32_t)ctx->msg_buf[1] << 16) |
                                   ((uint32_t)ctx->msg_buf[2] << 8) |
                                   (uint32_t)ctx->msg_buf[3];
                s->chunk_size_in &= 0x7FFFFFFF;
            }
            break;
        case 4: // User Control
            rtmp_control_handler(s, ctx->msg_buf, ctx->msg_len);
            break;
        case 8: // Audio
            if (s->audio_cb && s->publishing) {
                s->audio_cb(ctx->msg_buf, ctx->msg_len, ctx->current_timestamp, s->audio_ctx);
            }
            break;
        case 9: // Video
            if (s->video_cb && s->publishing) {
                s->video_cb(ctx->msg_buf, ctx->msg_len, ctx->current_timestamp, s->video_ctx);
                if (s->state != RTMP_STATE_STREAMING) {
                    set_state(s, RTMP_STATE_STREAMING);
                }
            }
            break;
        case 18: // Data (AMF0)
        case 20: // Command (AMF0)
            rtmp_invoke_handler(s, ctx);
            break;
        default:
            break;
    }
}

void rtmp_control_handler(rtmp_server_t *s, const uint8_t *data, size_t len) {
    if (len < 6) return;
    uint16_t event = (data[0] << 8) | data[1];
    uint32_t value = ((uint32_t)data[2] << 24) | ((uint32_t)data[3] << 16) |
                     ((uint32_t)data[4] << 8) | data[5];

    switch (event) {
        case 6: // Ping Request
            rtmp_event_pong(s, value);
            break;
        case 3: // SetBufferLength
            break;
        default:
            break;
    }
}

void rtmp_event_pong(rtmp_server_t *s, uint32_t timestamp) {
    uint8_t msg[6];
    msg[0] = 0; msg[1] = 7; // Pong
    msg[2] = (timestamp >> 24) & 0xFF;
    msg[3] = (timestamp >> 16) & 0xFF;
    msg[4] = (timestamp >> 8) & 0xFF;
    msg[5] = timestamp & 0xFF;
    rtmp_chunk_t chunk = {0};
    chunk.csid = 2;
    chunk.type_id = 4;
    chunk.data = msg;
    chunk.data_len = 6;
    rtmp_chunk_write(s, &chunk);
}

void rtmp_event_stream_begin(rtmp_server_t *s, uint32_t stream_id) {
    uint8_t msg[6];
    msg[0] = 0; msg[1] = 0;
    msg[2] = (stream_id >> 24) & 0xFF;
    msg[3] = (stream_id >> 16) & 0xFF;
    msg[4] = (stream_id >> 8) & 0xFF;
    msg[5] = stream_id & 0xFF;
    rtmp_chunk_t chunk = {0};
    chunk.csid = 2;
    chunk.type_id = 4;
    chunk.data = msg;
    chunk.data_len = 6;
    rtmp_chunk_write(s, &chunk);
}

int rtmp_server_send_video(rtmp_server_t *s, const uint8_t *data, size_t len, uint32_t ts) {
    if (!s || s->client_fd < 0) return -1;
    rtmp_chunk_t chunk = {0};
    chunk.csid = 6;
    chunk.type_id = 9;
    chunk.timestamp = ts;
    chunk.stream_id = 1;
    chunk.data = data;
    chunk.data_len = len;
    return rtmp_chunk_write(s, &chunk);
}

int rtmp_server_send_audio(rtmp_server_t *s, const uint8_t *data, size_t len, uint32_t ts) {
    if (!s || s->client_fd < 0) return -1;
    rtmp_chunk_t chunk = {0};
    chunk.csid = 4;
    chunk.type_id = 8;
    chunk.timestamp = ts;
    chunk.stream_id = 1;
    chunk.data = data;
    chunk.data_len = len;
    return rtmp_chunk_write(s, &chunk);
}

int rtmp_server_send_script(rtmp_server_t *s, const uint8_t *data, size_t len, uint32_t ts) {
    if (!s || s->client_fd < 0) return -1;
    rtmp_chunk_t chunk = {0};
    chunk.csid = 5;
    chunk.type_id = 18;
    chunk.timestamp = ts;
    chunk.stream_id = 1;
    chunk.data = data;
    chunk.data_len = len;
    return rtmp_chunk_write(s, &chunk);
}

// Accessors for modules that need internal state
int rtmp_server_get_client_fd(rtmp_server_t *s) { return s->client_fd; }
rtmp_handshake_state_t rtmp_server_get_hs_state(rtmp_server_t *s) { return s->hs_state; }
void rtmp_server_set_hs_state(rtmp_server_t *s, rtmp_handshake_state_t state) { s->hs_state = state; }
int rtmp_server_get_publishing(rtmp_server_t *s) { return s->publishing; }
void rtmp_server_set_publishing(rtmp_server_t *s, int val) { s->publishing = val; }
