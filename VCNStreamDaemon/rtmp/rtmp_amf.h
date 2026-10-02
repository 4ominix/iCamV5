#ifndef RTMP_AMF_H
#define RTMP_AMF_H

#include <stdint.h>
#include <stddef.h>

// AMF0 type markers
#define AMF0_NUMBER      0x00
#define AMF0_BOOLEAN     0x01
#define AMF0_STRING      0x02
#define AMF0_OBJECT      0x03
#define AMF0_NULL        0x05
#define AMF0_UNDEFINED   0x06
#define AMF0_ECMA_ARRAY  0x08
#define AMF0_OBJECT_END  0x09
#define AMF0_STRICT_ARRAY 0x0A
#define AMF0_LONG_STRING 0x0C

typedef enum {
    AMF_TYPE_NUMBER,
    AMF_TYPE_BOOLEAN,
    AMF_TYPE_STRING,
    AMF_TYPE_OBJECT,
    AMF_TYPE_NULL,
} amf_value_type_t;

typedef struct amf_value {
    amf_value_type_t type;
    union {
        double number;
        int    boolean;
        struct { char *data; size_t len; } string;
        struct {
            struct amf_property *props;
            size_t count;
        } object;
    };
} amf_value_t;

typedef struct amf_property {
    char      *name;
    amf_value_t value;
} amf_property_t;

// Decoding
size_t amf0_decode_value(const uint8_t *data, size_t len, amf_value_t *val);
size_t amf0_decode_string(const uint8_t *data, size_t len, char **out, size_t *out_len);
size_t amf0_decode_number(const uint8_t *data, size_t len, double *out);

// Encoding
size_t amf0_encode_number(uint8_t *buf, size_t capacity, double val);
size_t amf0_encode_string(uint8_t *buf, size_t capacity, const char *str, size_t str_len);
size_t amf0_encode_boolean(uint8_t *buf, size_t capacity, int val);
size_t amf0_encode_null(uint8_t *buf, size_t capacity);
size_t amf0_encode_object_start(uint8_t *buf, size_t capacity);
size_t amf0_encode_object_property(uint8_t *buf, size_t capacity, const char *name, const amf_value_t *val);
size_t amf0_encode_object_end(uint8_t *buf, size_t capacity);

void amf_value_free(amf_value_t *val);

// Object property access
const amf_value_t *amf_object_get(const amf_value_t *obj, const char *name);

#endif
