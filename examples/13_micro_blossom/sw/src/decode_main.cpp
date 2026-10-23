/**
 * Coyote Example 13: Micro Blossom QEC Decoder — host-driven decode (MVP).
 *
 * Runs the full heterogeneous MWPM decode with the primal (blossom-tree)
 * algorithm on the host x86 CPU and the dual accelerator in the V80 vFPGA,
 * communicating over the Coyote PCIe control path.
 *
 * The primal + control loop is reused verbatim from Micro Blossom's Rust
 * `blossom` crate (the same code that drives the verilator simulation); only
 * the hardware transport is swapped for Coyote CSRs. This program:
 *   1. opens the vFPGA (coyote::cThread) and registers it with the CSR shim,
 *   2. for each known d3 syndrome, calls into Rust `mb_decode_and_check`, which
 *      decodes on the real hardware AND on the in-repo software reference, then
 *      compares the two subgraphs,
 *   3. reports pass/fail.
 *
 * Success bar (MVP): every d3 syndrome's hardware matching equals the software
 * reference.
 *
 * Prereq: the bitstream must be built from the address-remapped vfpga_top.svh,
 * and GRAPH_PATH must point at the SAME graph the bitstream was generated from
 * (example_code_capacity_d3.json).
 */

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

#include <unistd.h>

#include <coyote/cThread.hpp>

#include "mb_csr.h"

// Rust C ABI entry (micro-blossom `blossom` crate, ffi_coyote.rs).
extern "C" {
struct MbDecodeResult {
    int matched_reference;
    uint32_t hw_subgraph_len;
    uint32_t ref_subgraph_len;
};
int mb_decode_and_check(const char* graph_path, const uint32_t* defects,
                        size_t defects_len, MbDecodeResult* out);
}

namespace {

constexpr uint32_t DEFAULT_VFPGA_ID = 0;

// Must match the graph the bitstream was generated from.
constexpr const char* GRAPH_PATH =
    "/scratch/anubhav/micro-blossom/resources/graphs/example_code_capacity_d3.json";

// Known d3 syndromes (lists of defect vertex indices). Real vertices are 0,1;
// virtual boundaries are 2,3. The Rust side cross-checks each against the
// software reference, so no pre-computed expected matching is needed here.
const std::vector<std::vector<uint32_t>> kSyndromes = {
    {},        // no defects -> empty matching
    {0, 1},    // two real defects
    {0},       // single defect -> matches to a virtual boundary
    {1},       // single defect (other side)
};

}  // namespace

int main(int /*argc*/, char* /*argv*/[]) {
    coyote::cThread coyote_thread(DEFAULT_VFPGA_ID, getpid());
    mb_csr_set_cthread(&coyote_thread);

    int failures = 0;
    for (size_t s = 0; s < kSyndromes.size(); ++s) {
        const auto& defects = kSyndromes[s];
        MbDecodeResult result{};
        int rc = mb_decode_and_check(GRAPH_PATH, defects.data(), defects.size(), &result);

        std::cout << "Syndrome " << s << " { ";
        for (uint32_t v : defects) std::cout << v << " ";
        std::cout << "}: ";

        if (rc != 0) {
            std::cout << "DECODE ERROR (rc=" << rc << ")\n";
            ++failures;
            continue;
        }

        std::cout << "hw_edges=" << result.hw_subgraph_len
                  << " ref_edges=" << result.ref_subgraph_len
                  << " -> " << (result.matched_reference ? "OK" : "MISMATCH") << "\n";
        if (!result.matched_reference) ++failures;
    }

    if (failures == 0) {
        std::cout << "\n*** MICRO BLOSSOM HOST-DRIVEN d3 DECODE PASSED ***\n";
        return 0;
    }
    std::cerr << "\n*** DECODE FAILED: " << failures << " syndrome(s) mismatched ***\n";
    return 1;
}
