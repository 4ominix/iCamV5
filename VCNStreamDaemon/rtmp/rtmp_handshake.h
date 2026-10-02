#ifndef RTMP_HANDSHAKE_H
#define RTMP_HANDSHAKE_H

#include "rtmp_server.h"
#include <stdint.h>
#include <stddef.h>

typedef enum {
    RTMP_HS_WAITING_C0 = 0,
    RTMP_HS_WAITING_C1,
    RTMP_HS_WAITING_C2,
    RTMP_HS_DONE,
} rtmp_handshake_state_t;

size_t rtmp_handshake_process(rtmp_server_t *s, const uint8_t *data, size_t len);

#endif
