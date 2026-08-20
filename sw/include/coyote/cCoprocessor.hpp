#pragma once

#include <cstdint>
#include <functional>
#include <limits>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace coyote {

enum class CoprocessorState : std::uint8_t {
    unbound = 0,
    ready = 1,
    quiescing = 2,
    quiesced = 3,
    faulted = 4,
};

enum class CoprocessorResult : std::uint8_t {
    ok = 0,
    endpoint_not_found = 1,
    abi_mismatch = 2,
    unhealthy = 3,
    not_idle = 4,
    stale_generation = 5,
    decoupled = 6,
    generation_exhausted = 7,
    faulted = 8,
    bad_state = 9,
    invalid_port = 10,
    occupied = 11,
};

struct CoprocessorProvider {
    std::uint16_t endpoint_id = 0;
    std::string name;
    std::string processor_class;
    std::uint32_t stream_abi = 0;
    std::uint32_t mmio_abi = 0;
    std::string runtime_abi;
    std::string firmware_abi;
    std::uint32_t generation = 1;
    std::uint32_t capacity = 1;
    std::uint64_t timing_ns = 0;
    bool available = true;
    bool healthy = true;
    bool fault = false;
};

struct CoprocessorRequirement {
    std::uint32_t stream_abi = 0;
    std::uint32_t mmio_abi = 0;
};

struct CoprocessorBinding {
    CoprocessorState state = CoprocessorState::unbound;
    std::uint32_t binding_generation = 0;
    std::optional<std::uint16_t> endpoint_id;
    std::uint32_t endpoint_generation = 0;
    bool application_decoupled = false;
    bool streams_idle = true;
    bool mmio_idle = true;
    bool provider_idle = true;
};

class CoprocessorBindingModel {
public:
    CoprocessorBindingModel(
        std::vector<CoprocessorRequirement> requirements,
        std::vector<CoprocessorProvider> providers);

    CoprocessorResult bind(
        std::size_t port,
        std::uint16_t endpoint_id,
        std::uint32_t expected_endpoint_generation);
    CoprocessorResult quiesce(std::size_t port, std::uint32_t expected_binding_generation);
    CoprocessorResult pollQuiesce(std::size_t port);
    CoprocessorResult unbind(std::size_t port, std::uint32_t expected_binding_generation);
    CoprocessorResult recover(std::size_t port, std::uint32_t expected_binding_generation);

    void setDatapathIdle(
        std::size_t port,
        bool streams_idle,
        bool mmio_idle,
        bool provider_idle);
    void setApplicationDecoupled(std::size_t port, bool decoupled);
    void setProviderHealth(std::uint16_t endpoint_id, bool available, bool healthy);
    void setProviderFault(std::uint16_t endpoint_id, bool fault);
    void setProviderGeneration(std::uint16_t endpoint_id, std::uint32_t generation);

    const CoprocessorBinding& binding(std::size_t port) const;
    const CoprocessorProvider& provider(std::uint16_t endpoint_id) const;
    std::size_t portCount() const noexcept { return requirements_.size(); }
    std::size_t providerCount() const noexcept { return providers_.size(); }

private:
    std::vector<CoprocessorRequirement> requirements_;
    std::vector<CoprocessorProvider> providers_;
    std::vector<CoprocessorBinding> bindings_;

    CoprocessorProvider* findProvider(std::uint16_t endpoint_id);
    const CoprocessorProvider* findProvider(std::uint16_t endpoint_id) const;
    bool endpointOwned(std::uint16_t endpoint_id, std::size_t except_port) const;
    bool allIdle(const CoprocessorBinding& binding) const;
    void faultPort(CoprocessorBinding& binding);
};

struct CoprocessorControlCommand {
    enum class Opcode : std::uint8_t {
        get_info = 0,
        bind = 1,
        quiesce = 2,
        unbind = 3,
        recover = 4,
        get_provider = 5,
        read_binding = 6,
    };

    Opcode opcode = Opcode::get_info;
    std::uint16_t port = 0;
    std::uint16_t endpoint_id = 0;
    std::uint32_t binding_generation = 0;
    std::uint32_t endpoint_generation = 0;
};

struct CoprocessorControlResponse {
    CoprocessorResult result = CoprocessorResult::ok;
    CoprocessorBinding binding;
    std::optional<CoprocessorProvider> provider;
    std::uint16_t port_count = 0;
    std::uint16_t provider_count = 0;
};

class CoprocessorControlIo {
public:
    virtual ~CoprocessorControlIo() = default;
    virtual CoprocessorControlResponse transact(const CoprocessorControlCommand& command) = 0;
};

class cCoprocessorControl {
public:
    explicit cCoprocessorControl(CoprocessorControlIo& io) : io_(io) {}

    CoprocessorControlResponse info();
    CoprocessorControlResponse provider(std::uint16_t index);
    CoprocessorControlResponse bind(
        std::uint16_t port,
        std::uint16_t endpoint_id,
        std::uint32_t endpoint_generation);
    CoprocessorControlResponse binding(std::uint16_t port);
    CoprocessorControlResponse quiesce(std::uint16_t port, std::uint32_t binding_generation);
    CoprocessorControlResponse unbind(std::uint16_t port, std::uint32_t binding_generation);
    CoprocessorControlResponse recover(std::uint16_t port, std::uint32_t binding_generation);

private:
    CoprocessorControlIo& io_;
    CoprocessorControlResponse invoke(CoprocessorControlCommand command);
};

} // namespace coyote
