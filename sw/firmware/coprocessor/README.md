# Co-processor provider firmware API

This freestanding C API is the processor-side contract for Coyote logical co-processor providers. It discovers and acknowledges binding generations, receives and sends complete packets, accesses the selected application's bounded 64-bit MMIO aperture, and participates in quiesce and fault handling.

`provider.c` is transport independent. `provider_transport_r5.c` supplies the initial polling transport at the Coyote-owned V80 R5 provider window. Consumer firmware supplies its service loop, startup code, linker script, and immutable runtime identity.
