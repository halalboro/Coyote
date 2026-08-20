#ifndef COYOTE_R5_PROVIDER_H
#define COYOTE_R5_PROVIDER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define CYT_PROVIDER_IMAGE_WORDS 8u
#define CYT_PROVIDER_MAX_PACKET_BYTES 4096u
#define CYT_PROVIDER_MAX_PACKET_BEATS 64u

typedef struct cyt_provider cyt_provider;

struct cyt_provider_firmware_identity {
    uint16_t runtime_abi;
    uint16_t firmware_abi;
    uint32_t image_identity[CYT_PROVIDER_IMAGE_WORDS];
};

struct cyt_provider_identity {
    uint32_t protocol_version;
    uint16_t stream_abi;
    uint16_t mmio_abi;
    uint16_t receive_depth;
    uint16_t transmit_depth;
    uint16_t max_packet_beats;
    uint16_t data_words_per_beat;
    uint32_t endpoint_generation;
};

struct cyt_provider_status {
    uint32_t endpoint_generation;
    uint32_t binding_generation;
    uint32_t fault_code;
    bool available;
    bool healthy;
    bool selected;
    bool generation_acknowledged;
    bool quiesce_requested;
    bool quiesce_acknowledged;
    bool idle;
    bool aborted;
};

struct cyt_provider_packet_metadata {
    size_t beat_count;
    uint8_t beat_id[CYT_PROVIDER_MAX_PACKET_BEATS];
};

struct cyt_provider_wait {
    uint32_t polls_left;
};

enum cyt_provider_result {
    CYT_PROVIDER_OK = 0,
    CYT_PROVIDER_WOULD_BLOCK,
    CYT_PROVIDER_TIMEOUT,
    CYT_PROVIDER_INVALID_ARGUMENT,
    CYT_PROVIDER_NOT_PRESENT,
    CYT_PROVIDER_ABI_MISMATCH,
    CYT_PROVIDER_BUFFER_TOO_SMALL,
    CYT_PROVIDER_UNBOUND,
    CYT_PROVIDER_QUIESCING,
    CYT_PROVIDER_FAULTED,
    CYT_PROVIDER_STALE,
    CYT_PROVIDER_SLVERR,
    CYT_PROVIDER_DECERR,
    CYT_PROVIDER_PROTOCOL_ERROR,
    CYT_PROVIDER_BUS_ERROR,
    CYT_PROVIDER_RECOVERY_REQUIRED,
};

enum cyt_provider_result cyt_provider_open(
    const struct cyt_provider_firmware_identity *firmware,
    cyt_provider **provider,
    struct cyt_provider_identity *identity);

enum cyt_provider_result cyt_provider_refresh_binding(cyt_provider *provider);

enum cyt_provider_result cyt_provider_read_status(
    cyt_provider *provider,
    struct cyt_provider_status *status);

enum cyt_provider_result cyt_provider_receive(
    cyt_provider *provider,
    void *buffer,
    size_t capacity,
    size_t *length,
    struct cyt_provider_packet_metadata *metadata,
    struct cyt_provider_wait *wait);

enum cyt_provider_result cyt_provider_send(
    cyt_provider *provider,
    const void *buffer,
    size_t length,
    const struct cyt_provider_packet_metadata *metadata,
    struct cyt_provider_wait *wait);

enum cyt_provider_result cyt_provider_app_read64(
    cyt_provider *provider,
    uint16_t application_offset,
    uint64_t *value,
    struct cyt_provider_wait *wait);

enum cyt_provider_result cyt_provider_app_write64(
    cyt_provider *provider,
    uint16_t application_offset,
    uint64_t value,
    uint8_t byte_strobe,
    struct cyt_provider_wait *wait);

enum cyt_provider_result cyt_provider_set_idle(cyt_provider *provider, bool idle);
enum cyt_provider_result cyt_provider_ack_quiesce(cyt_provider *provider);
enum cyt_provider_result cyt_provider_report_fault(
    cyt_provider *provider,
    uint16_t code,
    uint16_t detail);

#endif
