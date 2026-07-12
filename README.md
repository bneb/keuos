# KeuOS

[![CI](https://github.com/bneb/keuos/actions/workflows/ci.yml/badge.svg)](https://github.com/bneb/keuos/actions/workflows/ci.yml)

A microkernel written in [Salt](https://github.com/bneb/salt) with Z3-verified
safety invariants. SMP, preemptive scheduler, SPSC ring IPC, TCP stack,
arena-based memory, and Ring 3 userspace.

## Architecture

```
Ring 3:  grit (shell) | netd (TCP/IP) | basalt (LLM) | lettuce (KV)
         ───────────────────────────────────────────────────────────
Ring 0:  scheduler | SPSC IPC | VirtIO drivers | TCP stack | ECS
         ───────────────────────────────────────────────────────────
         arch/ (x86_64, aarch64) | mem/ (paging, slab) | boot/
```

## Quick Start

Prerequisites: Docker, QEMU, Python 3.

```bash
python3 tools/docker_build.py build   # build keuos.elf in Docker
make run-qemu                         # boot in QEMU
```

The kernel requires salt-opt (C++/MLIR backend, depends on LLVM 21) — the
Docker build handles this. See [`Dockerfile`](Dockerfile) for the full
build environment.

Kernel source compiles in CI. Full QEMU boot smoke test passes in the
[monorepo CI](https://github.com/bneb/lattice/actions/runs/28913406326).

## Directory Map

| Directory | What |
|-----------|------|
| `kernel/arch/` | x86_64 and aarch64 HAL (boot, interrupts, syscalls) |
| `kernel/core/` | Platform-independent kernel (scheduler, process, IPC) |
| `kernel/mem/` | Physical memory manager, paging, slab allocator |
| `kernel/net/` | TCP stack: connect/send/recv/close, ARP, ICMP, UDP |
| `kernel/drivers/` | VirtIO, NVMe, serial, PS/2, framebuffer |
| `kernel/ecs/` | Entity Component System (native process model) |
| `kernel/ipc/` | SPSC ring buffers, fastpath handoff |
| `kernel/sched/` | Chase-Lev work-stealing scheduler |
| `keuos_rt/` | C runtime (startup, ABI) |
| `user/` | Ring 3 programs (grit shell, netd, basalt, facet, lettuce) |
| `lattice_ecs/` | Rust ECS bridge library |
| `vendor/` | bearssl, openlibm, quickjs |
| `kernel/tests/` | Kernel integration tests |
| `benchmarks/` | ECS and kernel benchmarks |

## Verification

Core kernel operations carry Z3 contracts:

```salt
fn sys_spawn(path: Ptr<u8>, flags: u64) -> Result<ProcessId, Status>
    requires(!path.is_null())
    requires(flags == 0 || flags == SPAWN_NONBLOCKING)
    ensures(result.is_ok() || flags == SPAWN_NONBLOCKING)
```

SPSC ring accesses validate capacity and tail pointers from untrusted userspace.
Chase-Lev deque invariants are Z3-proven. NetD TCP state machine has Z3
contracts on every state transition.

## License

MIT

## See Also

- [Basalt](https://github.com/bneb/basalt) — ML inference in Salt (ported as a kernel Ring 3 service)
- [Lettuce](https://github.com/bneb/lettuce) — Redis-compatible server in Salt
- [Facet](https://github.com/bneb/facet) — GPU 2D compositor in Salt
- [Salt Benchmarks](https://github.com/bneb/salt-benchmarks) — Salt vs C/Rust across 36 algorithm problems

## Built With

[Salt](https://github.com/bneb/salt) — a systems language with Z3-powered compile-time verification.
