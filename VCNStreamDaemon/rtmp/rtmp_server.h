#ifndef RTMP_SERVER_H
#define RTMP_SERVER_H

#include <stdint.h>
#include <stddef.h>

typedef enum {
    RTMP_STATE_IDLE = 0,
    RTMP_STATE_LISTENING,
    RTMP_STATE_CONNECTED,
    RTMP_STATE_STREAMING,
} rtmp_server_state_t;

typedef struct rtmp_server rtmp_server_t;

typedef void (*rtmp_video_callback_t)(const uint8_t *data, size_t len, uint32_t timestamp, void *ctx);
typedef void (*rtmp_audio_callback_t)(const uint8_t *data, size_t len, uint32_t timestamp, void *ctx);
typedef void (*rtmp_status_callback_t)(rtmp_server_state_t state, void *ctx);

rtmp_server_t *rtmp_server_create(int port);
void rtmp_server_destroy(rtmp_server_t *server);
int rtmp_server_start(rtmp_server_t *server);
rtmp_server_state_t rtmp_server_getstate(rtmp_server_t *server);

void rtmp_server_set_video_callback(rtmp_server_t *s, rtmp_video_callback_t cb, void *ctx);
void rtmp_server_set_audio_callback(rtmp_server_t *s, rtmp_audio_callback_t cb, void *ctx);
void rtmp_server_set_status_callback(rtmp_server_t *s, rtmp_status_callback_t cb, void *ctx);

int rtmp_server_send_video(rtmp_server_t *s, const uint8_t *data, size_t len, uint32_t ts);
int rtmp_server_send_audio(rtmp_server_t *s, const uint8_t *data, size_t len, uint32_t ts);
int rtmp_server_send_script(rtmp_server_t *s, const uint8_t *data, size_t len, uint32_t ts);
void rtmp_server_input(rtmp_server_t *s, const uint8_t *data, size_t len);

// Internal accessors for submodules
#include "rtmp_handshake.h"
int rtmp_server_get_client_fd(rtmp_server_t *s);
rtmp_handshake_state_t rtmp_server_get_hs_state(rtmp_server_t *s);
void rtmp_server_set_hs_state(rtmp_server_t *s, rtmp_handshake_state_t state);
int rtmp_server_get_publishing(rtmp_server_t *s);
void rtmp_server_set_publishing(rtmp_server_t *s, int val);

void rtmp_event_stream_begin(rtmp_server_t *s, uint32_t stream_id);
void rtmp_event_pong(rtmp_server_t *s, uint32_t timestamp);

#endif
