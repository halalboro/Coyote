#include <coyote/cCoprocessor.hpp>

#include <algorithm>

namespace coyote {

CoprocessorBindingModel::CoprocessorBindingModel(
    std::vector<CoprocessorRequirement> requirements,
    std::vector<CoprocessorProvider> providers)
    : requirements_(std::move(requirements)),
      providers_(std::move(providers)),
      bindings_(requirements_.size()) {
    if (requirements_.empty()) {
        throw std::invalid_argument("at least one logical co-processor port is required");
    }
    for (std::size_t i = 0; i < providers_.size(); ++i) {
        const auto& provider = providers_[i];
        if (provider.endpoint_id == 0 || provider.generation == 0 || provider.stream_abi == 0 ||
            provider.mmio_abi == 0 || provider.capacity != 1 || provider.name.empty() ||
            provider.processor_class.empty() || provider.runtime_abi.empty() ||
            provider.firmware_abi.empty()) {
            throw std::invalid_argument("provider identities and ABIs must be nonzero");
        }
        for (std::size_t j = 0; j < i; ++j) {
            if (providers_[j].endpoint_id == provider.endpoint_id) {
                throw std::invalid_argument("duplicate co-processor endpoint id");
            }
        }
    }
    for (const auto& requirement : requirements_) {
        if (requirement.stream_abi == 0 || requirement.mmio_abi == 0) {
            throw std::invalid_argument("logical port ABIs must be nonzero");
        }
    }
}

CoprocessorProvider* CoprocessorBindingModel::findProvider(std::uint16_t endpoint_id) {
    const auto iterator = std::find_if(
        providers_.begin(), providers_.end(),
        [endpoint_id](const auto& provider) { return provider.endpoint_id == endpoint_id; });
    return iterator == providers_.end() ? nullptr : &*iterator;
}

const CoprocessorProvider* CoprocessorBindingModel::findProvider(std::uint16_t endpoint_id) const {
    const auto iterator = std::find_if(
        providers_.cbegin(), providers_.cend(),
        [endpoint_id](const auto& provider) { return provider.endpoint_id == endpoint_id; });
    return iterator == providers_.cend() ? nullptr : &*iterator;
}

bool CoprocessorBindingModel::endpointOwned(
    std::uint16_t endpoint_id, std::size_t except_port) const {
    for (std::size_t port = 0; port < bindings_.size(); ++port) {
        if (port == except_port) {
            continue;
        }
        const auto& binding = bindings_[port];
        if (binding.endpoint_id && *binding.endpoint_id == endpoint_id &&
            binding.state != CoprocessorState::unbound) {
            return true;
        }
    }
    return false;
}

bool CoprocessorBindingModel::allIdle(const CoprocessorBinding& binding) const {
    return binding.streams_idle && binding.mmio_idle && binding.provider_idle;
}

void CoprocessorBindingModel::faultPort(CoprocessorBinding& binding) {
    if (binding.state != CoprocessorState::unbound) {
        binding.state = CoprocessorState::faulted;
    }
}

CoprocessorResult CoprocessorBindingModel::bind(
    std::size_t port,
    std::uint16_t endpoint_id,
    std::uint32_t expected_endpoint_generation) {
    if (port >= bindings_.size()) {
        return CoprocessorResult::invalid_port;
    }
    auto& binding = bindings_[port];
    if (binding.state == CoprocessorState::faulted) {
        return CoprocessorResult::faulted;
    }
    if (binding.state != CoprocessorState::unbound) {
        return CoprocessorResult::bad_state;
    }
    if (binding.application_decoupled) {
        return CoprocessorResult::decoupled;
    }
    auto* selected = findProvider(endpoint_id);
    if (selected == nullptr) {
        return CoprocessorResult::endpoint_not_found;
    }
    if (selected->generation != expected_endpoint_generation) {
        return CoprocessorResult::stale_generation;
    }
    if (!selected->available || !selected->healthy || selected->fault) {
        return CoprocessorResult::unhealthy;
    }
    if (!binding.streams_idle || !binding.mmio_idle || !binding.provider_idle) {
        return CoprocessorResult::not_idle;
    }
    if (endpointOwned(endpoint_id, port)) {
        return CoprocessorResult::occupied;
    }
    const auto& requirement = requirements_[port];
    if (selected->stream_abi != requirement.stream_abi ||
        selected->mmio_abi != requirement.mmio_abi) {
        return CoprocessorResult::abi_mismatch;
    }
    if (binding.binding_generation == std::numeric_limits<std::uint32_t>::max()) {
        return CoprocessorResult::generation_exhausted;
    }

    ++binding.binding_generation;
    binding.endpoint_id = endpoint_id;
    binding.endpoint_generation = selected->generation;
    binding.state = CoprocessorState::ready;
    binding.streams_idle = true;
    binding.mmio_idle = true;
    binding.provider_idle = true;
    return CoprocessorResult::ok;
}

CoprocessorResult CoprocessorBindingModel::quiesce(
    std::size_t port, std::uint32_t expected_binding_generation) {
    if (port >= bindings_.size()) {
        return CoprocessorResult::invalid_port;
    }
    auto& binding = bindings_[port];
    if (binding.binding_generation != expected_binding_generation) {
        return CoprocessorResult::stale_generation;
    }
    if (binding.state == CoprocessorState::faulted) {
        return CoprocessorResult::faulted;
    }
    if (binding.state != CoprocessorState::ready &&
        binding.state != CoprocessorState::quiescing &&
        binding.state != CoprocessorState::quiesced) {
        return CoprocessorResult::bad_state;
    }
    if (binding.state != CoprocessorState::quiesced) {
        binding.state = allIdle(binding) ? CoprocessorState::quiesced
                                         : CoprocessorState::quiescing;
    }
    return CoprocessorResult::ok;
}

CoprocessorResult CoprocessorBindingModel::pollQuiesce(std::size_t port) {
    if (port >= bindings_.size()) {
        return CoprocessorResult::invalid_port;
    }
    auto& binding = bindings_[port];
    if (binding.state == CoprocessorState::faulted) {
        return CoprocessorResult::faulted;
    }
    if (binding.state == CoprocessorState::quiescing && allIdle(binding)) {
        binding.state = CoprocessorState::quiesced;
    }
    return binding.state == CoprocessorState::quiesced ? CoprocessorResult::ok
                                                        : CoprocessorResult::not_idle;
}

CoprocessorResult CoprocessorBindingModel::unbind(
    std::size_t port, std::uint32_t expected_binding_generation) {
    if (port >= bindings_.size()) {
        return CoprocessorResult::invalid_port;
    }
    auto& binding = bindings_[port];
    if (binding.binding_generation != expected_binding_generation) {
        return CoprocessorResult::stale_generation;
    }
    if (binding.state == CoprocessorState::faulted) {
        return CoprocessorResult::faulted;
    }
    if (binding.state != CoprocessorState::quiesced || !allIdle(binding)) {
        return CoprocessorResult::not_idle;
    }
    binding.state = CoprocessorState::unbound;
    binding.endpoint_id.reset();
    binding.endpoint_generation = 0;
    return CoprocessorResult::ok;
}

CoprocessorResult CoprocessorBindingModel::recover(
    std::size_t port, std::uint32_t expected_binding_generation) {
    if (port >= bindings_.size()) {
        return CoprocessorResult::invalid_port;
    }
    auto& binding = bindings_[port];
    if (binding.binding_generation != expected_binding_generation) {
        return CoprocessorResult::stale_generation;
    }
    if (binding.state != CoprocessorState::faulted) {
        return CoprocessorResult::bad_state;
    }
    if (binding.application_decoupled || !allIdle(binding)) {
        return CoprocessorResult::not_idle;
    }
    binding.state = CoprocessorState::unbound;
    binding.endpoint_id.reset();
    binding.endpoint_generation = 0;
    return CoprocessorResult::ok;
}

void CoprocessorBindingModel::setDatapathIdle(
    std::size_t port,
    bool streams_idle,
    bool mmio_idle,
    bool provider_idle) {
    if (port >= bindings_.size()) {
        throw std::out_of_range("co-processor port index");
    }
    auto& binding = bindings_[port];
    binding.streams_idle = streams_idle;
    binding.mmio_idle = mmio_idle;
    binding.provider_idle = provider_idle;
    if (binding.state == CoprocessorState::quiescing && allIdle(binding)) {
        binding.state = CoprocessorState::quiesced;
    }
}

void CoprocessorBindingModel::setApplicationDecoupled(std::size_t port, bool decoupled) {
    if (port >= bindings_.size()) {
        throw std::out_of_range("co-processor port index");
    }
    auto& binding = bindings_[port];
    binding.application_decoupled = decoupled;
    if (decoupled) {
        faultPort(binding);
    }
}

void CoprocessorBindingModel::setProviderHealth(
    std::uint16_t endpoint_id, bool available, bool healthy) {
    auto* changed = findProvider(endpoint_id);
    if (changed == nullptr) {
        throw std::out_of_range("co-processor endpoint id");
    }
    changed->available = available;
    changed->healthy = healthy;
    if (!available || !healthy) {
        for (auto& binding : bindings_) {
            if (binding.endpoint_id && *binding.endpoint_id == endpoint_id) {
                faultPort(binding);
            }
        }
    }
}

void CoprocessorBindingModel::setProviderFault(std::uint16_t endpoint_id, bool fault) {
    auto* changed = findProvider(endpoint_id);
    if (changed == nullptr) {
        throw std::out_of_range("co-processor endpoint id");
    }
    changed->fault = fault;
    if (fault) {
        for (auto& binding : bindings_) {
            if (binding.endpoint_id && *binding.endpoint_id == endpoint_id) {
                faultPort(binding);
            }
        }
    }
}

void CoprocessorBindingModel::setProviderGeneration(
    std::uint16_t endpoint_id, std::uint32_t generation) {
    if (generation == 0) {
        throw std::invalid_argument("provider generation must be nonzero");
    }
    auto* changed = findProvider(endpoint_id);
    if (changed == nullptr) {
        throw std::out_of_range("co-processor endpoint id");
    }
    changed->generation = generation;
    for (auto& binding : bindings_) {
        if (binding.endpoint_id && *binding.endpoint_id == endpoint_id &&
            binding.endpoint_generation != generation) {
            faultPort(binding);
        }
    }
}

const CoprocessorBinding& CoprocessorBindingModel::binding(std::size_t port) const {
    if (port >= bindings_.size()) {
        throw std::out_of_range("co-processor port index");
    }
    return bindings_[port];
}

const CoprocessorProvider& CoprocessorBindingModel::provider(
    std::uint16_t endpoint_id) const {
    const auto* found = findProvider(endpoint_id);
    if (found == nullptr) {
        throw std::out_of_range("co-processor endpoint id");
    }
    return *found;
}

CoprocessorControlResponse cCoprocessorControl::invoke(CoprocessorControlCommand command) {
    return io_.transact(command);
}

CoprocessorControlResponse cCoprocessorControl::info() {
    return invoke({CoprocessorControlCommand::Opcode::get_info});
}

CoprocessorControlResponse cCoprocessorControl::provider(std::uint16_t index) {
    CoprocessorControlCommand command;
    command.opcode = CoprocessorControlCommand::Opcode::get_provider;
    command.endpoint_id = index;
    return invoke(command);
}

CoprocessorControlResponse cCoprocessorControl::bind(
    std::uint16_t port,
    std::uint16_t endpoint_id,
    std::uint32_t endpoint_generation) {
    CoprocessorControlCommand command;
    command.opcode = CoprocessorControlCommand::Opcode::bind;
    command.port = port;
    command.endpoint_id = endpoint_id;
    command.endpoint_generation = endpoint_generation;
    return invoke(command);
}

CoprocessorControlResponse cCoprocessorControl::binding(std::uint16_t port) {
    CoprocessorControlCommand command;
    command.opcode = CoprocessorControlCommand::Opcode::read_binding;
    command.port = port;
    return invoke(command);
}

CoprocessorControlResponse cCoprocessorControl::quiesce(
    std::uint16_t port, std::uint32_t binding_generation) {
    CoprocessorControlCommand command;
    command.opcode = CoprocessorControlCommand::Opcode::quiesce;
    command.port = port;
    command.binding_generation = binding_generation;
    return invoke(command);
}

CoprocessorControlResponse cCoprocessorControl::unbind(
    std::uint16_t port, std::uint32_t binding_generation) {
    CoprocessorControlCommand command;
    command.opcode = CoprocessorControlCommand::Opcode::unbind;
    command.port = port;
    command.binding_generation = binding_generation;
    return invoke(command);
}

CoprocessorControlResponse cCoprocessorControl::recover(
    std::uint16_t port, std::uint32_t binding_generation) {
    CoprocessorControlCommand command;
    command.opcode = CoprocessorControlCommand::Opcode::recover;
    command.port = port;
    command.binding_generation = binding_generation;
    return invoke(command);
}

} // namespace coyote
