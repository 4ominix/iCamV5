#include "rtmp_amf.h"
#include <string.h>
#include <stdlib.h>
#include <arpa/inet.h>

static double read_double_be(const uint8_t *p) {
    uint64_t v = 0;
    for (int i = 0; i < 8; i++) v = (v << 8) | p[i];
    double d;
    memcpy(&d, &v, 8);
    return d;
}

static void write_double_be(uint8_t *p, double d) {
    uint64_t v;
    memcpy(&v, &d, 8);
    for (int i = 7; i >= 0; i--) { p[i] = v & 0xFF; v >>= 8; }
}

static size_t decode_short_string(const uint8_t *data, size_t len, char **out, size_t *out_len) {
    if (len < 2) return 0;
    uint16_t slen = (data[0] << 8) | data[1];
    if (len < 2 + slen) return 0;
    *out = malloc(slen + 1);
    memcpy(*out, data + 2, slen);
    (*out)[slen] = '\0';
    if (out_len) *out_len = slen;
    return 2 + slen;
}

size_t amf0_decode_string(const uint8_t *data, size_t len, char **out, size_t *out_len) {
    if (len < 1 || data[0] != AMF0_STRING) return 0;
    return 1 + decode_short_string(data + 1, len - 1, out, out_len);
}

size_t amf0_decode_number(const uint8_t *data, size_t len, double *out) {
    if (len < 9 || data[0] != AMF0_NUMBER) return 0;
    *out = read_double_be(data + 1);
    return 9;
}

size_t amf0_decode_value(const uint8_t *data, size_t len, amf_value_t *val) {
    if (len < 1) return 0;
    memset(val, 0, sizeof(*val));

    switch (data[0]) {
        case AMF0_NUMBER: {
            if (len < 9) return 0;
            val->type = AMF_TYPE_NUMBER;
            val->number = read_double_be(data + 1);
            return 9;
        }
        case AMF0_BOOLEAN: {
            if (len < 2) return 0;
            val->type = AMF_TYPE_BOOLEAN;
            val->boolean = data[1] != 0;
            return 2;
        }
        case AMF0_STRING: {
            val->type = AMF_TYPE_STRING;
            size_t n = decode_short_string(data + 1, len - 1, &val->string.data, &val->string.len);
            return n ? 1 + n : 0;
        }
        case AMF0_OBJECT: {
            val->type = AMF_TYPE_OBJECT;
            size_t offset = 1;
            size_t capacity = 16;
            val->object.props = malloc(capacity * sizeof(amf_property_t));
            val->object.count = 0;

            while (offset + 3 <= len) {
                // Check for object end marker (00 00 09)
                if (data[offset] == 0 && data[offset+1] == 0 && data[offset+2] == AMF0_OBJECT_END) {
                    offset += 3;
                    break;
                }
                // Read property name
                char *name = NULL;
                size_t name_len = 0;
                size_t n = decode_short_string(data + offset, len - offset, &name, &name_len);
                if (n == 0) { free(name); break; }
                offset += n;

                // Read property value
                amf_value_t pval;
                n = amf0_decode_value(data + offset, len - offset, &pval);
                if (n == 0) { free(name); break; }
                offset += n;

                if (val->object.count >= capacity) {
                    capacity *= 2;
                    val->object.props = realloc(val->object.props, capacity * sizeof(amf_property_t));
                }
                val->object.props[val->object.count].name = name;
                val->object.props[val->object.count].value = pval;
                val->object.count++;
            }
            return offset;
        }
        case AMF0_ECMA_ARRAY: {
            if (len < 5) return 0;
            val->type = AMF_TYPE_OBJECT;
            size_t offset = 5;
            size_t capacity = 16;
            val->object.props = malloc(capacity * sizeof(amf_property_t));
            val->object.count = 0;

            while (offset + 3 <= len) {
                if (data[offset] == 0 && data[offset+1] == 0 && data[offset+2] == AMF0_OBJECT_END) {
                    offset += 3;
                    break;
                }
                char *name = NULL;
                size_t name_len = 0;
                size_t n = decode_short_string(data + offset, len - offset, &name, &name_len);
                if (n == 0) { free(name); break; }
                offset += n;

                amf_value_t pval;
                n = amf0_decode_value(data + offset, len - offset, &pval);
                if (n == 0) { free(name); break; }
                offset += n;

                if (val->object.count >= capacity) {
                    capacity *= 2;
                    val->object.props = realloc(val->object.props, capacity * sizeof(amf_property_t));
                }
                val->object.props[val->object.count].name = name;
                val->object.props[val->object.count].value = pval;
                val->object.count++;
            }
            return offset;
        }
        case AMF0_NULL:
        case AMF0_UNDEFINED:
            val->type = AMF_TYPE_NULL;
            return 1;
        default:
            return 0;
    }
}

void amf_value_free(amf_value_t *val) {
    if (!val) return;
    switch (val->type) {
        case AMF_TYPE_STRING:
            free(val->string.data);
            break;
        case AMF_TYPE_OBJECT:
            for (size_t i = 0; i < val->object.count; i++) {
                free(val->object.props[i].name);
                amf_value_free(&val->object.props[i].value);
            }
            free(val->object.props);
            break;
        default:
            break;
    }
    memset(val, 0, sizeof(*val));
}

const amf_value_t *amf_object_get(const amf_value_t *obj, const char *name) {
    if (!obj || obj->type != AMF_TYPE_OBJECT) return NULL;
    for (size_t i = 0; i < obj->object.count; i++) {
        if (strcmp(obj->object.props[i].name, name) == 0)
            return &obj->object.props[i].value;
    }
    return NULL;
}

// Encoding

size_t amf0_encode_number(uint8_t *buf, size_t capacity, double val) {
    if (capacity < 9) return 0;
    buf[0] = AMF0_NUMBER;
    write_double_be(buf + 1, val);
    return 9;
}

size_t amf0_encode_string(uint8_t *buf, size_t capacity, const char *str, size_t str_len) {
    if (capacity < 3 + str_len) return 0;
    buf[0] = AMF0_STRING;
    buf[1] = (str_len >> 8) & 0xFF;
    buf[2] = str_len & 0xFF;
    memcpy(buf + 3, str, str_len);
    return 3 + str_len;
}

size_t amf0_encode_boolean(uint8_t *buf, size_t capacity, int val) {
    if (capacity < 2) return 0;
    buf[0] = AMF0_BOOLEAN;
    buf[1] = val ? 1 : 0;
    return 2;
}

size_t amf0_encode_null(uint8_t *buf, size_t capacity) {
    if (capacity < 1) return 0;
    buf[0] = AMF0_NULL;
    return 1;
}

size_t amf0_encode_object_start(uint8_t *buf, size_t capacity) {
    if (capacity < 1) return 0;
    buf[0] = AMF0_OBJECT;
    return 1;
}

size_t amf0_encode_object_property(uint8_t *buf, size_t capacity, const char *name, const amf_value_t *val) {
    size_t name_len = strlen(name);
    size_t offset = 0;
    if (capacity < 2 + name_len) return 0;

    buf[0] = (name_len >> 8) & 0xFF;
    buf[1] = name_len & 0xFF;
    memcpy(buf + 2, name, name_len);
    offset = 2 + name_len;

    size_t val_size = 0;
    switch (val->type) {
        case AMF_TYPE_NUMBER:
            val_size = amf0_encode_number(buf + offset, capacity - offset, val->number);
            break;
        case AMF_TYPE_BOOLEAN:
            val_size = amf0_encode_boolean(buf + offset, capacity - offset, val->boolean);
            break;
        case AMF_TYPE_STRING:
            val_size = amf0_encode_string(buf + offset, capacity - offset, val->string.data, val->string.len);
            break;
        case AMF_TYPE_NULL:
            val_size = amf0_encode_null(buf + offset, capacity - offset);
            break;
        default:
            return 0;
    }

    return val_size ? offset + val_size : 0;
}

size_t amf0_encode_object_end(uint8_t *buf, size_t capacity) {
    if (capacity < 3) return 0;
    buf[0] = 0; buf[1] = 0; buf[2] = AMF0_OBJECT_END;
    return 3;
}
