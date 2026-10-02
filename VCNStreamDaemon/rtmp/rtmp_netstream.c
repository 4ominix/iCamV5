#include "rtmp_netstream.h"
#include <string.h>
#include <stdlib.h>

#define CMD_BUF_SIZE 4096

void rtmp_send_on_status(rtmp_server_t *s, const char *code, const char *description) {
    uint8_t buf[CMD_BUF_SIZE];
    size_t offset = 0;

    offset += amf0_encode_string(buf + offset, CMD_BUF_SIZE - offset, "onStatus", 8);
    offset += amf0_encode_number(buf + offset, CMD_BUF_SIZE - offset, 0);
    offset += amf0_encode_null(buf + offset, CMD_BUF_SIZE - offset);

    offset += amf0_encode_object_start(buf + offset, CMD_BUF_SIZE - offset);

    amf_value_t val;
    val.type = AMF_TYPE_STRING;
    val.string.data = (char *)"status";
    val.string.len = 6;
    offset += amf0_encode_object_property(buf + offset, CMD_BUF_SIZE - offset, "level", &val);

    val.string.data = (char *)code;
    val.string.len = strlen(code);
    offset += amf0_encode_object_property(buf + offset, CMD_BUF_SIZE - offset, "code", &val);

    val.string.data = (char *)description;
    val.string.len = strlen(description);
    offset += amf0_encode_object_property(buf + offset, CMD_BUF_SIZE - offset, "description", &val);

    offset += amf0_encode_object_end(buf + offset, CMD_BUF_SIZE - offset);

    rtmp_chunk_t chunk = {0};
    chunk.csid = 5;
    chunk.type_id = 20;
    chunk.stream_id = 1;
    chunk.data = buf;
    chunk.data_len = offset;
    rtmp_chunk_write(s, &chunk);
}

void rtmp_send_on_fcpublish(rtmp_server_t *s, const char *code, const char *description) {
    uint8_t buf[CMD_BUF_SIZE];
    size_t offset = 0;

    offset += amf0_encode_string(buf + offset, CMD_BUF_SIZE - offset, "onFCPublish", 11);
    offset += amf0_encode_number(buf + offset, CMD_BUF_SIZE - offset, 0);
    offset += amf0_encode_null(buf + offset, CMD_BUF_SIZE - offset);

    offset += amf0_encode_object_start(buf + offset, CMD_BUF_SIZE - offset);

    amf_value_t val;
    val.type = AMF_TYPE_STRING;
    val.string.data = (char *)code;
    val.string.len = strlen(code);
    offset += amf0_encode_object_property(buf + offset, CMD_BUF_SIZE - offset, "code", &val);

    val.string.data = (char *)description;
    val.string.len = strlen(description);
    offset += amf0_encode_object_property(buf + offset, CMD_BUF_SIZE - offset, "description", &val);

    offset += amf0_encode_object_end(buf + offset, CMD_BUF_SIZE - offset);

    rtmp_chunk_t chunk = {0};
    chunk.csid = 5;
    chunk.type_id = 20;
    chunk.stream_id = 1;
    chunk.data = buf;
    chunk.data_len = offset;
    rtmp_chunk_write(s, &chunk);
}

void rtmp_handle_publish(rtmp_server_t *s, double txn_id, const char *stream_name, const char *stream_type) {
    (void)txn_id;
    (void)stream_name;
    (void)stream_type;

    rtmp_server_set_publishing(s, 1);
    rtmp_event_stream_begin(s, 1);
    rtmp_send_on_status(s, "NetStream.Publish.Start", "Publishing started.");
    rtmp_send_on_fcpublish(s, "NetStream.Publish.Start", "Publishing started.");
}

void rtmp_handle_fcunpublish(rtmp_server_t *s, double txn_id) {
    (void)txn_id;
    rtmp_server_set_publishing(s, 0);
    rtmp_send_on_status(s, "NetStream.Unpublish.Success", "Stream unpublished.");
}

void rtmp_invoke_handler(rtmp_server_t *s, rtmp_chunk_context_t *ctx) {
    const uint8_t *data = ctx->msg_buf;
    size_t len = ctx->msg_len;
    size_t offset = 0;

    char *cmd_name = NULL;
    size_t cmd_len = 0;
    size_t n = amf0_decode_string(data + offset, len - offset, &cmd_name, &cmd_len);
    if (n == 0) return;
    offset += n;

    double txn_id = 0;
    n = amf0_decode_number(data + offset, len - offset, &txn_id);
    if (n == 0) { free(cmd_name); return; }
    offset += n;

    if (strcmp(cmd_name, "connect") == 0) {
        amf_value_t cmd_obj;
        n = amf0_decode_value(data + offset, len - offset, &cmd_obj);
        rtmp_handle_connect(s, txn_id, n > 0 ? &cmd_obj : NULL);
        if (n > 0) amf_value_free(&cmd_obj);
    } else if (strcmp(cmd_name, "releaseStream") == 0) {
        rtmp_handle_release_stream(s, txn_id);
    } else if (strcmp(cmd_name, "FCPublish") == 0) {
        rtmp_handle_fcpublish(s, txn_id);
    } else if (strcmp(cmd_name, "createStream") == 0) {
        rtmp_handle_create_stream(s, txn_id);
    } else if (strcmp(cmd_name, "publish") == 0) {
        amf_value_t null_val;
        n = amf0_decode_value(data + offset, len - offset, &null_val);
        if (n > 0) { offset += n; amf_value_free(&null_val); }

        char *stream_name = NULL; size_t sn_len = 0;
        n = amf0_decode_string(data + offset, len - offset, &stream_name, &sn_len);
        if (n > 0) offset += n;

        char *stream_type = NULL; size_t st_len = 0;
        n = amf0_decode_string(data + offset, len - offset, &stream_type, &st_len);

        rtmp_handle_publish(s, txn_id, stream_name ? stream_name : "live",
                           stream_type ? stream_type : "live");
        free(stream_name);
        free(stream_type);
    } else if (strcmp(cmd_name, "FCUnpublish") == 0) {
        rtmp_handle_fcunpublish(s, txn_id);
    } else if (strcmp(cmd_name, "closeStream") == 0) {
        rtmp_handle_close_stream(s, txn_id);
    } else if (strcmp(cmd_name, "deleteStream") == 0) {
        rtmp_handle_delete_stream(s, txn_id);
    }

    free(cmd_name);
}
