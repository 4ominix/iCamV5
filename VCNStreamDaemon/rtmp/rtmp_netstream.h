#ifndef RTMP_NETSTREAM_H
#define RTMP_NETSTREAM_H

#include "rtmp_server.h"
#include "rtmp_chunk.h"
#include "rtmp_amf.h"

void rtmp_handle_publish(rtmp_server_t *s, double txn_id, const char *stream_name, const char *stream_type);
void rtmp_handle_fcunpublish(rtmp_server_t *s, double txn_id);
void rtmp_send_on_status(rtmp_server_t *s, const char *code, const char *description);
void rtmp_send_on_fcpublish(rtmp_server_t *s, const char *code, const char *description);

#endif
