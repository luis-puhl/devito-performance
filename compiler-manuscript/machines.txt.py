# WARNING: ASSUME SINGLE PRECISION
# WARNING: EVERYTHING ASSUMES SINGLE SOCKET
# WARNING: THE REPORTED CORE FREQUENCY IS THE SIMD ISA BASE (no turbo boost) FREQUENCY

###########################################

# KNL 7250 ("knl7250")
# ---------------
# machine peak: 1.2 Ghz * 68 cores * 16 flots/avx512_register * 2 avx units * 2[fma] = 5222 SP-GFlops/s
# stream triad:
#     68 threads
#     MCDRAM: 475 GB/s
#     DDR4: 87 GB/s

knl7250 = {
    'machine-peak': 5222,
    'linpack-peak': 3790,
    'dram-stream-bw': 475,  # Hack, actually DRAM BW is 87
    'mcdram-stream-bw': 475
}


# SKL 6148 ("skl6148")
# ---------------
# machine peak: 2.2 Ghz * 20 cores * 16 flots/avx512_register * 2 avx units * 2[fma] = 2816 SP-GFlops/s
# i7-3632QM: 2.2 * 4 * 4? = 8.8
# i7-3632QM: 3.2 * 4 * 2.6? = 12.8
# 34GFlops @ linpack

skl6148 = {
    'machine-peak': 2816,   # teorico       Flops/s
    'linpack-peak': 2273,   # linpack exe   Flops/s (80%)
    'dram-stream-bw': 98    # 
}

# Load v1
# Load v2
# Add v1 v2
# Store vr

# SKL 8180 ("skl8180")
# ---------------
# machine peak: 2.3 Ghz * 28 cores * 16 flots/avx512_register * 2 avx units * 2[fma] = 4121 SP-GFlops/s

skl8180 = {
    'machine-peak': 4121,
    'linpack-peak': 3285,
    'dram-stream-bw': 104
}
