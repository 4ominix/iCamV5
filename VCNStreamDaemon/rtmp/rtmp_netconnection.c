#include "rtmp_netconnection.h"
#include <string.h>

#define CMD_BUF_SIZE 4096

void rtmp_send_result(rtmp_server_t *s, double txn_id, const uint8_t *properties, size_t prop_len,
                      const uint8_t *info, size_t info_len) {
    uint8_t buf[CMD_BUF_SIZE];
    size_t offset = 0;

    offset += amf0_encode_string(buf + offset, CMD_BUF_SIZE - offset, "_result", 7);
    offset += amf0_encode_number(buf + offset, CMD_BUF_SIZE - offset, txn_id);

    if (properties && prop_len) {
        memcpy(buf + offset, properties, prop_len);
        offset += prop_len;
    } else {
        offset += amf0_encode_null(buf + offset, CMD_BUF_SIZE - offset);
    }

    if (info && info_len) {
        memcpy(buf + offset, info, info_len);
        offset += info_len;
    }

    rtmp_chunk_t chunk = {0};
    chunk.csid = 3;
    chunk.type_id = 20;
    chunk.data = buf;
    chunk.data_len = offset;
    rtmp_chunk_write(s, &chunk);
}

void rtmp_send_error(rtmp_server_t *s, double txn_id, const char *code, const char *description) {
    uint8_t buf[CMD_BUF_SIZE];
    size_t offset = 0;

    offset += amf0_encode_string(buf + offset, CMD_BUF_SIZE - offset, "_error", 6);
    offset += amf0_encode_number(buf + offset, CMD_BUF_SIZE - offset, txn_id);
    offset += amf0_encode_null(buf + offset, CMD_BUF_SIZE - offset);

    offset += amf0_encode_object_start(buf + offset, CMD_BUF_SIZE - offset);

    amf_value_t val;
    val.type = AMF_TYPE_STRING;
    val.string.data = (char *)"error";
    val.string.len = 5;
    offset += amf0_encode_object_property(buf + offset, CMD_BUF_SIZE - offset, "level", &val);

    val.string.data = (char *)code;
    val.string.len = strlen(code);
    offset += amf0_encode_object_property(buf + offset, CMD_BUF_SIZE - offset, "code", &val);

    val.string.data = (char *)description;
    val.string.len = strlen(description);
    offset += amf0_encode_object_property(buf + offset, CMD_BUF_SIZE - offset, "description", &val);

    offset += amf0_encode_object_end(buf + offset, CMD_BUF_SIZE - offset);

    rtmp_chunk_t chunk = {0};
    chunk.csid = 3;
    chunk.type_id = 20;
    chunk.data = buf;
    chunk.data_len = offset;
    rtmp_chunk_write(s, &chunk);
}

void rtmp_handle_connect(rtmp_server_t *s, double txn_id, const amf_value_t *cmd_obj) {
    (void)cmd_obj;

    uint8_t props[CMD_BUF_SIZE];
    size_t po = 0;
    po += amf0_encode_object_start(props + po, CMD_BUF_SIZE - po);

    amf_value_t val;
    val.type = AMF_TYPE_STRING;
    val.string.data = (char *)"FMS/5,0,15,5004";
    val.string.len = 16;
    po += amf0_encode_object_property(props + po, CMD_BUF_SIZE - po, "fmsVer", &val);

    val.type = AMF_TYPE_NUMBER;
    val.number = 31.0;
    po += amf0_encode_object_property(props + po, CMD_BUF_SIZE - po, "capabilities", &val);

    po += amf0_encode_object_end(props + po, CMD_BUF_SIZE - po);

    uint8_t info[CMD_BUF_SIZE];
    size_t io = 0;
    io += amf0_encode_object_start(info + io, CMD_BUF_SIZE - io);

    val.type = AMF_TYPE_STRING;
    val.string.data = (char *)"status";
    val.string.len = 6;
    io += amf0_encode_object_property(info + io, CMD_BUF_SIZE - io, "level", &val);

    val.string.data = (char *)"NetConnection.Connect.Success";
    val.string.len = 29;
    io += amf0_encode_object_property(info + io, CMD_BUF_SIZE - io, "code", &val);

    val.string.data = (char *)"Connection succeeded.";
    val.string.len = 21;
    io += amf0_encode_object_property(info + io, CMD_BUF_SIZE - io, "description", &val);

    val.type = AMF_TYPE_NUMBER;
    val.number = 1.0;
    io += amf0_encode_object_property(info + io, CMD_BUF_SIZE - io, "objectEncoding", &val);

    io += amf0_encode_object_end(info + io, CMD_BUF_SIZE - io);

    rtmp_send_result(s, txn_id, props, po, info, io);
    rtmp_send_on_bw_done(s);
}

void rtmp_handle_release_stream(rtmp_server_t *s, double txn_id) {
    rtmp_send_result(s, txn_id, NULL, 0, NULL, 0);
}

void rtmp_handle_fcpublish(rtmp_server_t *s, double txn_id) {
    rtmp_send_result(s, txn_id, NULL, 0, NULL, 0);
}

void rtmp_handle_create_stream(rtmp_server_t *s, double txn_id) {
    uint8_t info[16];
    size_t io = amf0_encode_number(info, sizeof(info), 1.0);
    rtmp_send_result(s, txn_id, NULL, 0, info, io);
}

void rtmp_handle_close_stream(rtmp_server_t *s, double txn_id) {
    rtmp_server_set_publishing(s, 0);
    rtmp_send_result(s, txn_id, NULL, 0, NULL, 0);
}

void rtmp_handle_delete_stream(rtmp_server_t *s, double txn_id) {
    rtmp_server_set_publishing(s, 0);
    rtmp_send_result(s, txn_id, NULL, 0, NULL, 0);
}

void rtmp_send_on_bw_done(rtmp_server_t *s) {
    uint8_t buf[128];
    size_t offset = 0;
    offset += amf0_encode_string(buf + offset, sizeof(buf) - offset, "onBWDone", 8);
    offset += amf0_encode_number(buf + offset, sizeof(buf) - offset, 0);
    offset += amf0_encode_null(buf + offset, sizeof(buf) - offset);

    rtmp_chunk_t chunk = {0};
    chunk.csid = 3;
    chunk.type_id = 20;
    chunk.data = buf;
    chunk.data_len = offset;
    rtmp_chunk_write(s, &chunk);
}
