# Benchmark Results

All runs use a 1024x1024 matrix (`MATRIX_SIZE=1024`), verified correct against an independently recomputed value for `C[0]` on every successful run.

## Per-Process Compute Time Comparison

| Profile | Nodes | Memory Limit | Avg Per-Process Time | Total Job Time |
|---|---|---|---|---|
| CPU Naive (-O2) | 4 (1 master + 3 workers) | 32MB | ~1.19s | 1.50s |
| CPU Optimized (-O2) | 4 (1 master + 3 workers) | 32MB | ~0.10s | 0.29s |
| GPU CUDA (naive kernel) | 2 (1 master + 1 worker) | 128MB | ~0.54s | 0.66s |

## What Each Profile Represents

**CPU Naive:** Straight triple-nested loop (`i, j, k`), row-major access on A, column-jumping access on B. No compiler optimization advantage realized, since the access pattern itself defeats cache prefetching regardless of optimization level. See `docs/optimization_notes.md` for the full explanation.

**CPU Optimized:** Same algorithm, reordered loops (`i, k, j`) so B is read sequentially instead of jumping through memory on every step. Combined with `-O2`, this produced a roughly 12x improvement in per-process compute time over naive at the same optimization level.

**GPU CUDA:** One thread computes one cell of the result matrix, using the same straightforward dot-product logic as CPU naive, just parallelized across thousands of threads instead of looping sequentially. No CUDA-specific optimizations were applied, intentionally, to keep this a fair "naive" baseline parallel to the CPU naive profile rather than mixing naive and optimized comparisons across hardware types.

## Notable Finding: Naive GPU vs. Optimized CPU

A naive, unoptimized GPU kernel outperforms naive CPU by roughly 2x, but is still slower than a well-optimized CPU implementation. This shows that raw parallelism (thousands of GPU threads) doesn't automatically outperform careful, cache-aware algorithm design on far fewer CPU cores, at least not without further GPU-specific optimization. A shared-memory tiled GPU kernel would likely close or exceed this gap, but that's outside the current scope of this project, which intentionally compares naive-to-naive and optimized-to-naive, not optimized-to-optimized across hardware.

## Memory Limit Findings

Memory limits were determined empirically by testing progressively lower `mem_limit` values per container until failure, then confirming stability at the lowest reliable value.

### CPU Profiles (naive and optimized)

| Memory Limit | Result |
|---|---|
| 16MB | Fails reliably (OOM killed) |
| 24MB | Unreliable. Succeeded in some runs, failed in others with different failure symptoms (TCP connection reset, peer disconnect) depending on timing |
| 32MB | Succeeds consistently |

**Official limit used: 32MB**, chosen for reliability over the theoretical minimum. The empirical floor (24MB) lines up closely with the calculated matrix data requirement, roughly 24MB for two full matrices plus one row chunk as `double` values, suggesting the instability at 24MB comes from having effectively zero headroom for OS, MPI, and SSH overhead on top of the raw data.

### GPU Profile

| Memory Limit | Result |
|---|---|
| 32MB | Fails (OOM killed) |
| 64MB | Fails (OOM killed) |
| 128MB | Succeeds consistently |

**Official limit used: 128MB.** The GPU profile requires substantially more memory than the CPU profiles at the same matrix size, due to CUDA runtime initialization overhead (driver context, runtime libraries) that the CPU/MPI-only containers never incur. This overhead exists independent of actual matrix size. A trivial "hello world" CUDA kernel hit the same floor as the full matrix multiplication kernel.

## Raw Results

Full timestamped run logs, including the failed boundary-testing runs referenced above, are available in this `results/` directory.