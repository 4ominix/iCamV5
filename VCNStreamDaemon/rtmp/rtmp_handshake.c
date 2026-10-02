#include "rtmp_handshake.h"
#include "rtmp_server.h"
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>

#define RTMP_HS_SIZE 1536

size_t rtmp_handshake_process(rtmp_server_t *s, const uint8_t *data, size_t len) {
    size_t consumed = 0;
    int fd = rtmp_server_get_client_fd(s);
    rtmp_handshake_state_t hs = rtmp_server_get_hs_state(s);

    // C0: 1 byte (version 0x03)
    if (hs == RTMP_HS_WAITING_C0) {
        if (len < 1) return 0;
        consumed = 1;
        hs = RTMP_HS_WAITING_C1;
        rtmp_server_set_hs_state(s, hs);
    }

    // C1: 1536 bytes
    if (hs == RTMP_HS_WAITING_C1) {
        if (len - consumed < RTMP_HS_SIZE) return consumed;
        const uint8_t *c1 = data + consumed;

        uint8_t response[1 + RTMP_HS_SIZE + RTMP_HS_SIZE];

        // S0
        response[0] = 0x03;

        // S1: timestamp + zero + random
        uint32_t server_time = 0;
        memcpy(response + 1, &server_time, 4);
        memset(response + 5, 0, 4);
        for (int i = 0; i < RTMP_HS_SIZE - 8; i++)
            response[9 + i] = (uint8_t)(rand() & 0xFF);

        // S2: echo C1
        memcpy(response + 1 + RTMP_HS_SIZE, c1, RTMP_HS_SIZE);

        size_t total = 1 + RTMP_HS_SIZE + RTMP_HS_SIZE;
        size_t sent = 0;
        while (sent < total) {
            ssize_t n = send(fd, response + sent, total - sent, 0);
            if (n <= 0) return consumed;
            sent += n;
        }

        consumed += RTMP_HS_SIZE;
        hs = RTMP_HS_WAITING_C2;
        rtmp_server_set_hs_state(s, hs);
    }

    // C2: 1536 bytes
    if (hs == RTMP_HS_WAITING_C2) {
        if (len - consumed < RTMP_HS_SIZE) return consumed;
        consumed += RTMP_HS_SIZE;
        rtmp_server_set_hs_state(s, RTMP_HS_DONE);

        // Post-handshake protocol messages
        extern void rtmp_set_chunk_size(rtmp_server_t *, uint32_t);
        extern void rtmp_window_acknowledgement_size(rtmp_server_t *, uint32_t);
        extern void rtmp_set_peer_bandwidth(rtmp_server_t *, uint32_t);

        rtmp_window_acknowledgement_size(s, 2500000);
        rtmp_set_peer_bandwidth(s, 2500000);
        rtmp_set_chunk_size(s, 4096);
    }

    return consumed;
}
