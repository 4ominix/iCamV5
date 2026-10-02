#ifndef RTMP_NETCONNECTION_H
#define RTMP_NETCONNECTION_H

#include "rtmp_server.h"
#include "rtmp_chunk.h"
#include "rtmp_amf.h"

void rtmp_handle_connect(rtmp_server_t *s, double txn_id, const amf_value_t *cmd_obj);
void rtmp_handle_release_stream(rtmp_server_t *s, double txn_id);
void rtmp_handle_fcpublish(rtmp_server_t *s, double txn_id);
void rtmp_handle_create_stream(rtmp_server_t *s, double txn_id);
void rtmp_handle_close_stream(rtmp_server_t *s, double txn_id);
void rtmp_handle_delete_stream(rtmp_server_t *s, double txn_id);

void rtmp_send_result(rtmp_server_t *s, double txn_id, const uint8_t *properties, size_t prop_len,
                      const uint8_t *info, size_t info_len);
void rtmp_send_error(rtmp_server_t *s, double txn_id, const char *code, const char *description);
void rtmp_send_on_bw_done(rtmp_server_t *s);

#endif
