#include "provider_internal.h"
#include "provider_protocol.h"

struct cyt_provider {
    struct cyt_provider_transport transport;
    uint32_t endpoint_generation;
    uint32_t binding_generation;
    bool opened;
};

static struct cyt_provider singleton;
static struct cyt_provider_transport installed_transport;
static bool transport_installed;

void cyt_provider_install_transport(const struct cyt_provider_transport *transport) {
    if (transport == (const void *)0 || transport->read32 == (void *)0 ||
        transport->write32 == (void *)0) {
        transport_installed = false;
        return;
    }
    installed_transport = *transport;
    transport_installed = true;
}

static bool read32(cyt_provider *provider, uint16_t offset, uint32_t *value) {
    return provider->transport.read32(provider->transport.context, offset, value);
}

static bool write32(cyt_provider *provider, uint16_t offset, uint32_t value) {
    return provider->transport.write32(provider->transport.context, offset, value);
}

static enum cyt_provider_result wait_again(struct cyt_provider_wait *wait) {
    if (wait == (void *)0) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    if (wait->polls_left == 0u) {
        return CYT_PROVIDER_WOULD_BLOCK;
    }
    wait->polls_left -= 1u;
    return wait->polls_left == 0u ? CYT_PROVIDER_TIMEOUT : CYT_PROVIDER_OK;
}

static enum cyt_provider_result command_result(uint32_t result) {
    switch (result & UINT32_C(0xff)) {
    case CYT_COMMAND_OK:
        return CYT_PROVIDER_OK;
    case CYT_COMMAND_EMPTY:
    case CYT_COMMAND_FULL:
    case CYT_COMMAND_BUSY:
        return CYT_PROVIDER_WOULD_BLOCK;
    case CYT_COMMAND_STALE:
        return CYT_PROVIDER_STALE;
    case CYT_COMMAND_QUIESCING:
        return CYT_PROVIDER_QUIESCING;
    case CYT_COMMAND_NOT_READY:
        return CYT_PROVIDER_UNBOUND;
    case CYT_COMMAND_ABORTED:
        return CYT_PROVIDER_RECOVERY_REQUIRED;
    case CYT_COMMAND_TIMEOUT:
        return CYT_PROVIDER_TIMEOUT;
    case CYT_COMMAND_AXI_SLVERR:
        return CYT_PROVIDER_SLVERR;
    case CYT_COMMAND_AXI_DECERR:
        return CYT_PROVIDER_DECERR;
    default:
        return CYT_PROVIDER_PROTOCOL_ERROR;
    }
}

static enum cyt_provider_result read_last_result(cyt_provider *provider) {
    uint32_t value;
    if (!read32(provider, CYT_REG_LAST_COMMAND, &value)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    return command_result(value);
}

static enum cyt_provider_result require_session(cyt_provider *provider) {
    uint32_t status;
    uint32_t generation;
    if (provider == (void *)0 || !provider->opened) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    if (!read32(provider, CYT_REG_STATUS, &status) ||
        !read32(provider, CYT_REG_ACTIVE_GENERATION, &generation)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    if ((status & CYT_STATUS_ABORTED) != 0u) {
        return CYT_PROVIDER_RECOVERY_REQUIRED;
    }
    if ((status & CYT_STATUS_HEALTHY) == 0u) {
        return (status & CYT_STATUS_AVAILABLE) == 0u ? CYT_PROVIDER_NOT_PRESENT
                                                     : CYT_PROVIDER_FAULTED;
    }
    if ((status & CYT_STATUS_SELECTED) == 0u || generation == 0u) {
        return CYT_PROVIDER_UNBOUND;
    }
    if ((status & CYT_STATUS_QUIESCE_ACK) != 0u) {
        return CYT_PROVIDER_QUIESCING;
    }
    if (generation != provider->binding_generation ||
        (status & CYT_STATUS_GENERATION_ACK) == 0u) {
        return CYT_PROVIDER_STALE;
    }
    return CYT_PROVIDER_OK;
}

static uint32_t load_word_le(const uint8_t *bytes, size_t available) {
    uint32_t value = 0u;
    size_t index;
    for (index = 0u; index < 4u && index < available; ++index) {
        value |= (uint32_t)bytes[index] << (index * 8u);
    }
    return value;
}

static void store_word_le(uint8_t *bytes, size_t available, uint32_t value) {
    size_t index;
    for (index = 0u; index < 4u && index < available; ++index) {
        bytes[index] = (uint8_t)(value >> (index * 8u));
    }
}

enum cyt_provider_result cyt_provider_open(
    const struct cyt_provider_firmware_identity *firmware,
    cyt_provider **provider,
    struct cyt_provider_identity *identity) {
    uint32_t magic;
    uint32_t version;
    uint32_t stream_shape;
    uint32_t queue_shape;
    uint32_t endpoint_generation;
    uint32_t index;

    if (firmware == (const void *)0 || provider == (void *)0 ||
        identity == (void *)0 || !transport_installed ||
        firmware->runtime_abi == 0u || firmware->firmware_abi == 0u) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }

    singleton.transport = installed_transport;
    singleton.opened = false;
    singleton.binding_generation = 0u;
    if (!read32(&singleton, CYT_REG_MAGIC, &magic) ||
        !read32(&singleton, CYT_REG_VERSION, &version) ||
        !read32(&singleton, CYT_REG_STREAM_SHAPE, &stream_shape) ||
        !read32(&singleton, CYT_REG_QUEUE_SHAPE, &queue_shape)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    if (magic != CYT_PROVIDER_MAGIC) {
        return CYT_PROVIDER_NOT_PRESENT;
    }
    if (version != CYT_PROVIDER_VERSION || (stream_shape & UINT32_C(0xff)) != 64u ||
        ((stream_shape >> 8u) & UINT32_C(0xff)) != 16u ||
        ((stream_shape >> 16u) & UINT32_C(0xff)) != 64u ||
        ((stream_shape >> 24u) & UINT32_C(0xff)) != 6u) {
        return CYT_PROVIDER_ABI_MISMATCH;
    }

    if (!write32(&singleton, CYT_REG_RUNTIME_ABI, firmware->runtime_abi) ||
        !write32(&singleton, CYT_REG_FIRMWARE_ABI, firmware->firmware_abi)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    for (index = 0u; index < CYT_PROVIDER_IMAGE_WORDS; ++index) {
        if (!write32(&singleton, (uint16_t)(CYT_REG_IDENTITY_BASE + index * 4u),
                     firmware->image_identity[index])) {
            return CYT_PROVIDER_BUS_ERROR;
        }
    }
    if (!write32(&singleton, CYT_REG_IDENTITY_COMMIT, CYT_PROVIDER_IDENTITY_COMMIT)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    if (read_last_result(&singleton) != CYT_PROVIDER_OK ||
        !read32(&singleton, CYT_REG_ENDPOINT_GENERATION, &endpoint_generation) ||
        endpoint_generation == 0u) {
        return CYT_PROVIDER_ABI_MISMATCH;
    }
    if (!write32(&singleton, CYT_REG_FIRMWARE_STATE, 1u)) {
        return CYT_PROVIDER_BUS_ERROR;
    }

    singleton.endpoint_generation = endpoint_generation;
    singleton.opened = true;
    identity->protocol_version = version;
    identity->stream_abi = 1u;
    identity->mmio_abi = 1u;
    identity->receive_depth = (uint16_t)((queue_shape >> 8u) & UINT32_C(0xff));
    identity->transmit_depth = (uint16_t)((queue_shape >> 16u) & UINT32_C(0xff));
    identity->max_packet_beats = (uint16_t)(queue_shape & UINT32_C(0xff));
    identity->data_words_per_beat = (uint16_t)((stream_shape >> 8u) & UINT32_C(0xff));
    identity->endpoint_generation = endpoint_generation;
    *provider = &singleton;
    return CYT_PROVIDER_OK;
}

enum cyt_provider_result cyt_provider_refresh_binding(cyt_provider *provider) {
    uint32_t status;
    uint32_t generation;
    enum cyt_provider_result result;
    if (provider == (void *)0 || !provider->opened) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    if (!read32(provider, CYT_REG_STATUS, &status) ||
        !read32(provider, CYT_REG_ACTIVE_GENERATION, &generation)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    if ((status & CYT_STATUS_ABORTED) != 0u) {
        return CYT_PROVIDER_RECOVERY_REQUIRED;
    }
    if ((status & CYT_STATUS_SELECTED) == 0u || generation == 0u) {
        return CYT_PROVIDER_UNBOUND;
    }
    if (!write32(provider, CYT_REG_COMMAND_GENERATION, generation)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    result = read_last_result(provider);
    if (result != CYT_PROVIDER_OK) {
        return result;
    }
    if (!read32(provider, CYT_REG_STATUS, &status) ||
        (status & CYT_STATUS_GENERATION_ACK) == 0u) {
        return CYT_PROVIDER_STALE;
    }
    provider->binding_generation = generation;
    return CYT_PROVIDER_OK;
}

enum cyt_provider_result cyt_provider_read_status(
    cyt_provider *provider,
    struct cyt_provider_status *status) {
    uint32_t raw;
    if (provider == (void *)0 || status == (void *)0 || !provider->opened ||
        !read32(provider, CYT_REG_STATUS, &raw) ||
        !read32(provider, CYT_REG_ENDPOINT_GENERATION, &status->endpoint_generation) ||
        !read32(provider, CYT_REG_ACTIVE_GENERATION, &status->binding_generation) ||
        !read32(provider, CYT_REG_FAULT, &status->fault_code)) {
        return provider == (void *)0 || status == (void *)0 ? CYT_PROVIDER_INVALID_ARGUMENT
                                                            : CYT_PROVIDER_BUS_ERROR;
    }
    status->available = (raw & CYT_STATUS_AVAILABLE) != 0u;
    status->healthy = (raw & CYT_STATUS_HEALTHY) != 0u;
    status->selected = (raw & CYT_STATUS_SELECTED) != 0u;
    status->generation_acknowledged = (raw & CYT_STATUS_GENERATION_ACK) != 0u;
    status->quiesce_requested = (raw & CYT_STATUS_QUIESCE_REQUEST) != 0u;
    status->quiesce_acknowledged = (raw & CYT_STATUS_QUIESCE_ACK) != 0u;
    status->idle = (raw & CYT_STATUS_IDLE) != 0u;
    status->aborted = (raw & CYT_STATUS_ABORTED) != 0u;
    return CYT_PROVIDER_OK;
}

enum cyt_provider_result cyt_provider_receive(
    cyt_provider *provider,
    void *buffer,
    size_t capacity,
    size_t *length,
    struct cyt_provider_packet_metadata *metadata,
    struct cyt_provider_wait *wait) {
    uint32_t rx_status;
    uint32_t token;
    uint32_t generation_before;
    uint32_t generation_after;
    uint32_t beats;
    uint32_t bytes;
    size_t beat;
    size_t word;
    enum cyt_provider_result result;
    uint8_t *output = buffer;

    if (buffer == (void *)0 || length == (void *)0 || metadata == (void *)0) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    result = require_session(provider);
    if (result != CYT_PROVIDER_OK) {
        return result;
    }
    for (;;) {
        if (!read32(provider, CYT_REG_RX_STATUS, &rx_status)) {
            return CYT_PROVIDER_BUS_ERROR;
        }
        if ((rx_status & CYT_RX_EMPTY) == 0u) {
            break;
        }
        result = wait_again(wait);
        if (result != CYT_PROVIDER_OK) {
            return result;
        }
    }
    if (!read32(provider, CYT_REG_RX_TOKEN, &token) ||
        !read32(provider, CYT_REG_RX_GENERATION, &generation_before) ||
        !read32(provider, CYT_REG_RX_BEATS, &beats) ||
        !read32(provider, CYT_REG_RX_BYTES, &bytes)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    if (generation_before != provider->binding_generation || beats == 0u ||
        beats > CYT_PROVIDER_MAX_PACKET_BEATS || bytes == 0u ||
        bytes > CYT_PROVIDER_MAX_PACKET_BYTES || bytes > beats * 64u) {
        return CYT_PROVIDER_PROTOCOL_ERROR;
    }
    *length = bytes;
    metadata->beat_count = beats;
    if (capacity < bytes) {
        return CYT_PROVIDER_BUFFER_TOO_SMALL;
    }
    for (beat = 0u; beat < beats; ++beat) {
        uint32_t attribute;
        if (!read32(provider, (uint16_t)(CYT_RX_ATTR_BASE + beat * 4u), &attribute)) {
            return CYT_PROVIDER_BUS_ERROR;
        }
        metadata->beat_id[beat] = (uint8_t)(attribute & UINT32_C(0x3f));
        if (((attribute >> 6u) & 1u) != (beat + 1u == beats)) {
            return CYT_PROVIDER_PROTOCOL_ERROR;
        }
        for (word = 0u; word < 16u; ++word) {
            const size_t offset = beat * 64u + word * 4u;
            uint32_t value;
            if (!read32(provider, (uint16_t)(CYT_RX_DATA_BASE + offset), &value)) {
                return CYT_PROVIDER_BUS_ERROR;
            }
            if (offset < bytes) {
                const size_t available = bytes - offset < 4u ? bytes - offset : 4u;
                store_word_le(output + offset, available, value);
            }
        }
    }
    if (!read32(provider, CYT_REG_ACTIVE_GENERATION, &generation_after) ||
        generation_after != generation_before) {
        return CYT_PROVIDER_STALE;
    }
    if (!write32(provider, CYT_REG_RX_POP, token)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    return read_last_result(provider);
}

enum cyt_provider_result cyt_provider_send(
    cyt_provider *provider,
    const void *buffer,
    size_t length,
    const struct cyt_provider_packet_metadata *metadata,
    struct cyt_provider_wait *wait) {
    const uint8_t *input = buffer;
    const size_t beats = (length + 63u) / 64u;
    uint32_t tx_status;
    uint32_t token;
    size_t beat;
    size_t word;
    enum cyt_provider_result result;

    if (buffer == (const void *)0 || metadata == (const void *)0 || length == 0u ||
        length > CYT_PROVIDER_MAX_PACKET_BYTES || metadata->beat_count != beats) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    result = require_session(provider);
    if (result != CYT_PROVIDER_OK) {
        return result;
    }
    for (;;) {
        if (!read32(provider, CYT_REG_TX_STATUS, &tx_status)) {
            return CYT_PROVIDER_BUS_ERROR;
        }
        if ((tx_status & CYT_TX_FULL) == 0u) {
            break;
        }
        result = wait_again(wait);
        if (result != CYT_PROVIDER_OK) {
            return result;
        }
    }
    if (!read32(provider, CYT_REG_TX_TOKEN, &token) ||
        !write32(provider, CYT_REG_TX_BEATS, (uint32_t)beats)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    for (beat = 0u; beat < beats; ++beat) {
        uint64_t keep;
        const size_t remaining = length - beat * 64u;
        const size_t valid = remaining < 64u ? remaining : 64u;
        if (metadata->beat_id[beat] >= 64u) {
            (void)write32(provider, CYT_REG_TX_CANCEL, token);
            return CYT_PROVIDER_INVALID_ARGUMENT;
        }
        for (word = 0u; word < 16u; ++word) {
            const size_t offset = beat * 64u + word * 4u;
            const size_t available = offset < length ?
                (length - offset < 4u ? length - offset : 4u) : 0u;
            const uint32_t value = available == 0u ? 0u : load_word_le(input + offset, available);
            if (!write32(provider, (uint16_t)(CYT_TX_DATA_BASE + offset), value)) {
                return CYT_PROVIDER_BUS_ERROR;
            }
        }
        keep = valid == 64u ? UINT64_MAX : (UINT64_C(1) << valid) - UINT64_C(1);
        if (!write32(provider, (uint16_t)(CYT_TX_KEEP_BASE + beat * 8u), (uint32_t)keep) ||
            !write32(provider, (uint16_t)(CYT_TX_KEEP_BASE + beat * 8u + 4u),
                     (uint32_t)(keep >> 32u)) ||
            !write32(provider, (uint16_t)(CYT_TX_ATTR_BASE + beat * 4u),
                     (uint32_t)metadata->beat_id[beat] |
                     (beat + 1u == beats ? UINT32_C(1) << 6u : 0u))) {
            return CYT_PROVIDER_BUS_ERROR;
        }
    }
    if (!write32(provider, CYT_REG_TX_COMMIT, token)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    return read_last_result(provider);
}

static enum cyt_provider_result wait_mmio(
    cyt_provider *provider,
    uint32_t token,
    uint64_t *read_value,
    struct cyt_provider_wait *wait) {
    uint32_t status;
    uint32_t result_value;
    enum cyt_provider_result result;
    for (;;) {
        if (!read32(provider, CYT_REG_MMIO_STATUS, &status)) {
            return CYT_PROVIDER_BUS_ERROR;
        }
        if ((status & CYT_MMIO_DONE) != 0u) {
            break;
        }
        result = wait_again(wait);
        if (result != CYT_PROVIDER_OK) {
            return result;
        }
    }
    if (!read32(provider, CYT_REG_MMIO_RESULT, &result_value)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    result = command_result(result_value);
    if (result == CYT_PROVIDER_OK && read_value != (void *)0) {
        uint32_t low;
        uint32_t high;
        if (!read32(provider, CYT_REG_MMIO_READ_LO, &low) ||
            !read32(provider, CYT_REG_MMIO_READ_HI, &high)) {
            return CYT_PROVIDER_BUS_ERROR;
        }
        *read_value = (uint64_t)low | ((uint64_t)high << 32u);
    }
    if (!write32(provider, CYT_REG_MMIO_ACK, token)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    return result;
}

enum cyt_provider_result cyt_provider_app_read64(
    cyt_provider *provider,
    uint16_t application_offset,
    uint64_t *value,
    struct cyt_provider_wait *wait) {
    uint32_t token;
    enum cyt_provider_result result;
    if (value == (void *)0 || (application_offset & 7u) != 0u || application_offset > 0xff8u) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    result = require_session(provider);
    if (result != CYT_PROVIDER_OK) {
        return result;
    }
    if (!read32(provider, CYT_REG_MMIO_TOKEN, &token) ||
        !write32(provider, CYT_REG_MMIO_ADDRESS, application_offset) ||
        !write32(provider, CYT_REG_MMIO_OPERATION, 0u) ||
        !write32(provider, CYT_REG_MMIO_SUBMIT, token)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    result = read_last_result(provider);
    return result == CYT_PROVIDER_OK ? wait_mmio(provider, token, value, wait) : result;
}

enum cyt_provider_result cyt_provider_app_write64(
    cyt_provider *provider,
    uint16_t application_offset,
    uint64_t value,
    uint8_t byte_strobe,
    struct cyt_provider_wait *wait) {
    uint32_t token;
    enum cyt_provider_result result;
    if ((application_offset & 7u) != 0u || application_offset > 0xff8u || byte_strobe == 0u) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    result = require_session(provider);
    if (result != CYT_PROVIDER_OK) {
        return result;
    }
    if (!read32(provider, CYT_REG_MMIO_TOKEN, &token) ||
        !write32(provider, CYT_REG_MMIO_ADDRESS, application_offset) ||
        !write32(provider, CYT_REG_MMIO_WRITE_LO, (uint32_t)value) ||
        !write32(provider, CYT_REG_MMIO_WRITE_HI, (uint32_t)(value >> 32u)) ||
        !write32(provider, CYT_REG_MMIO_OPERATION, ((uint32_t)byte_strobe << 1u) | 1u) ||
        !write32(provider, CYT_REG_MMIO_SUBMIT, token)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    result = read_last_result(provider);
    return result == CYT_PROVIDER_OK ? wait_mmio(provider, token, (void *)0, wait) : result;
}

enum cyt_provider_result cyt_provider_set_idle(cyt_provider *provider, bool idle) {
    if (provider == (void *)0 || !provider->opened) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    return write32(provider, CYT_REG_FIRMWARE_STATE, idle ? 1u : 0u)
               ? CYT_PROVIDER_OK
               : CYT_PROVIDER_BUS_ERROR;
}

enum cyt_provider_result cyt_provider_ack_quiesce(cyt_provider *provider) {
    enum cyt_provider_result result = require_session(provider);
    if (result != CYT_PROVIDER_OK && result != CYT_PROVIDER_QUIESCING) {
        return result;
    }
    if (!write32(provider, CYT_REG_QUIESCE_ACK, provider->binding_generation)) {
        return CYT_PROVIDER_BUS_ERROR;
    }
    return read_last_result(provider);
}

enum cyt_provider_result cyt_provider_report_fault(
    cyt_provider *provider,
    uint16_t code,
    uint16_t detail) {
    uint32_t value;
    if (provider == (void *)0 || !provider->opened || code == 0u) {
        return CYT_PROVIDER_INVALID_ARGUMENT;
    }
    value = ((uint32_t)code << 16u) |
            (((uint32_t)detail & UINT32_C(0x3fff)) << 2u) | UINT32_C(2);
    return write32(provider, CYT_REG_FIRMWARE_STATE, value)
               ? CYT_PROVIDER_OK
               : CYT_PROVIDER_BUS_ERROR;
}
