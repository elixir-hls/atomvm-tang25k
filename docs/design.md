# AtomVM on Tang Primer 25K — design

Goal: run [AtomVM](https://github.com/atomvm/AtomVM) (Erlang/Elixir VM for
microcontrollers) on a LiteX SoC on the Sipeed Tang Primer 25K (Gowin GW5A-25A),
then expose FPGA peripherals to Erlang. The repository is meant to be published.

## 1. Approach

AtomVM has no LiteX port. Options considered:

| | Approach | Verdict |
|---|---|---|
| A | Zephyr (`litex_vexriscv` board) + AtomVM's Zephyr port ([PR #2389](https://github.com/atomvm/AtomVM/pull/2389), draft, release-0.7 based, pins Zephyr v4.4.2) | **chosen** — the platform layer (sys, UART, GPIO, timers) already exists; only board config is new |
| B | Bare-metal port on LiteX libbase + picolibc, modeled on `src/platforms/stm32` | fallback if A stalls (~1000 lines of platform code) |
| C | Linux-on-LiteX + `generic_unix` | rejected: needs an MMU CPU, heavy for the 25K, slow boot |

## 2. SoC

- Base: litex-boards `sipeed_tang_primer_25k` target, SDRAM (Dock's 32 MB W9825G6KH6),
  `--timer-uptime` (Zephyr timer driver), no L2 cache (the L2 is what filled the device in
  earlier projects; without it VexRiscv + SDRAM uses about a third of the logic).
- CPU: VexRiscv **`imac`** (rv32imac, 4 KB I$ + 4 KB D$, single-cycle multiplier).
  - `C`: AtomVM's riscv32 JIT / precompiled code emits compressed instructions
    (`libs/jit/src/jit_riscv32_asm.erl`), same ISA family as ESP32-C3 (rv32imc).
  - `A`: lets the C library / Zephyr use real atomics; harmless for the single-core VM.
- SPI flash (W25Q64, 8 MB) memory-mapped, for standalone boot (later stage).

## 3. Software

- Zephyr v4.4.2, board `litex_vexriscv` + a DTS overlay generated from the SoC's `csr.json`
  (`litex_json2dts_zephyr.py`), with the CPU node's `riscv,isa-extensions` set to imac.
- AtomVM: PR #2389's `src/platforms/zephyr` west application, pinned to a commit.
  Network / Wi-Fi / NVS features off; SMP off.
- AVM packs: the library (atomvmlib) and the application are separate packs
  (`patches/atomvm/0003` adds `CONFIG_AVM_LIB_ADDRESS`). Both run from SDRAM slots that
  `apps/atomvm/src/avm_loader.c` fills at boot: the library from SPI flash, the application
  from the staging slot (uploaded by `scripts/load_app.py`, then invalidated) or from flash.
  Memory map in the README.
- Loading: the BIOS serial boot only carries the small application pack; the uploader then
  sends SFL abort, and the BIOS continues with its flash boot of the AtomVM image.

## 4. Stages

| Stage | Content | Done when |
|---|---|---|
| S0 | SoC with VexRiscv imac + SDRAM + uptime timer | BIOS boots, memtest passes; resources/Fmax recorded |
| S1 | Zephyr on the imac SoC | `hello_world` on the UART, built with A+C enabled |
| S2 | AtomVM minimal | `hello_world.erl` prints over the UART (app embedded) |
| S3 | Separate app loading | `.avm` loaded into SDRAM next to the VM; then flash boot |
| S4 | Peripherals / performance | LED/button from Erlang, benchmarks, riscv32 JIT/precompiled |
| S5 | FPGA extensions (optional) | custom gateware exposed as NIF/port |

## 5. Results

- S0: Logic 30%, CLS 46%, BSRAM 34/56, DSP 4/28, sys Fmax 59.8 MHz (50 MHz target).
  BIOS memtest OK; SDRAM write 44.9 MiB/s, read 21.8 MiB/s (sequential).
- S1: Zephyr derives `RISCV_ISA_EXT_A/C` and `-march=rv32imac_zicsr_zifencei` from the
  overlay's `riscv,isa-extensions`; no Kconfig needed. hello_world runs.
- S2: PR #2389 builds unmodified for `litex_vexriscv` apart from one fix
  (`patches/atomvm/0001`: a `(uint32_t)` cast inside `#if` breaks when `CONFIG_FLASH_SIZE`
  is 0, i.e. a board without a `zephyr,flash` chosen node). Board config in
  `apps/atomvm/prj.conf`: crypto, PM, task watchdog and I2C off; malloc gets all remaining SDRAM.
  Image 904 KB (AtomVM + 497 KB atomvmlib-zephyr.avm). `erl/hello.erl` (io:format, 5 spawned
  processes) runs: VM start to exit 230 ms. AtomVM reports `riscv32-zephyr-zephyr`.

- S3: `patches/atomvm/0002` adds `CONFIG_AVM_APP_ADDRESS/SIZE` (the port derived the address
  from the flash size). Upload of hello.avm (1.1 KB) 0.1 s, then flash boot: AtomVM image
  copy + library copy (497 KB from the 1x SPI flash) -> AtomVM starts 0.36 s after Zephyr.
  Standalone boot (app in flash) verified. Writing vm + lib over JTAG ~30 s.
- Faster UART was tried and dropped: at 2 Mbaud (and 1 Mbaud) the BIOS serial boot fails on
  251-byte frames even with a 2 KB RX FIFO, and litex_term falls back to 64-byte frames at
  ~10 KB/s, no faster than 115200. Sending less (app-only uploads) solved it instead.

- S4 GPIO: `{0, N}` LEDs, `{1, N}` buttons with edge IRQs (SoC GPIOIn with_irq, overlay
  labels gpio0/gpio1; the btn_n pins keep PULL_MODE=DOWN). `erl/buttons_check.erl` on
  hardware: released reads high, pressed low, an interrupt on every press and release of
  both buttons, no bounce events. `erl/gpio_demo.erl` (LED0 blinks, buttons toggle LED1)
  checked by eye on the board.
- S4 UART input: `io:get_line` throws `no_group_leader` (the port starts no group leader);
  `uart:open([])` on the console UART reads lines fine (`erl/echo.erl`).
- Messages from interrupts: `patches/atomvm/0005` makes `sys_signal` wake the scheduler without
  sockets (it wrote an eventfd nobody polls, so a message waited for the next timer), 0006 keeps
  the messages sent from tasks in order (the queue is a stack, and the scheduler emptied it from
  the newest). An interrupt connected in a NIF needs an enabled devicetree node with its
  number, or Zephyr's interrupt controller never calls its handler
  (`scripts/gen_zephyr_overlay.sh` adds one per SoC interrupt no driver takes).
- S4 precompiled code (`patches/atomvm/0004`): AtomVM runs riscv32 native code from the packs.
  atomvmlib precompiled is 2.8 MB (0.5 MB BEAM) -> flash layout VM 0x100000 / lib 0x200000 /
  app 0x600000.
- Mixing native and emulated code does not work on this port: native code calling an
  emulated module traps to `code_server`, which is not started (-> `undef`, e.g. gpio:start/0
  from a precompiled app); with code_server started by hand the call goes through but the
  return to native code fails (`Undecoded opcode: 255`, abort), as does an emulated app on
  the precompiled library. AtomVM's own riscv32 library pack precompiles only the archives
  built with pack_precompiled_archive (estdlib, eavmlib, jit; avm_zephyr, avm_network and
  exavmlib stay BEAM). So `scripts/build_host.sh` precompiles every module of
  atomvmlib-zephyr.avm itself (`jit_precompile`, 168 modules, 1.4 s) into
  atomvmlib-zephyr-native.avm (2.6 MB), which `flash.sh lib` writes. Elixir apps run native.
- S4 performance (`erl/bench.erl`, each case in a Fibonacci-heap process, -O2, ms):

  | case | board emulated | board precompiled | host x86-64 emulated |
  |---|---:|---:|---:|
  | fib(22) | 6920 | 868 | 9 |
  | count to 100000 | 10615 | 732 | 13 |
  | int64 mul+add+band x200 | 179 | 139 | 0 |
  | lists:sort 2000 | 10643 | 2832 | 16 |
  | map+foldl 5000 | 2756 | 817 | 3 |
  | ping-pong 2000 msgs | 3890 | 2913 | 23 |
  | spawn+exit 200 procs | 467 | 358 | 2 |
  | binary build 2000 B | 914 | 218 | 1 |
  | io_lib:format x50 | 1632 | 1150 | 6 |

  Findings:
  - AtomVM's default heap growth (bounded free) enlarges a heap by `size + 16` words, so
    building a large term garbage-collects every few allocations: quadratic. Spawning with
    `{atomvm_heap_growth, fibonacci}` made a 8000-element build+sort 36x faster (host).
  - Integers above 2^27 are boxed on 32-bit AtomVM; a loop accumulating boxed int64 values
    ran ~30000x slower than on the 64-bit host (where they are immediates).
  - Memory system (`apps/membench`, cycles): D$ hit load 11 (loop incl.), D$ miss 64 per line,
    store 5-9 (write-through), memcpy 13/word and memset 4/word with -O2 (49 and 25 with -Os:
    picolibc's size-optimised versions) -> `CONFIG_SPEED_OPTIMIZATIONS=y`.
  - The emulator is 700-900x slower than on the host, precompiled code ~80-100x: the large
    interpreter loop does not fit the 4 KB I-cache (code runs from SDRAM, 64 cycles per miss);
    -O2 made emulated fib slower (6450 -> 6920 ms) as the code grew. Larger CPU caches are
    the main lever left: LiteX's L2 (8 KB) does not place on the GW5A-25 (built from flip-flops,
    63% registers), and bigger VexRiscv/VexiiRiscv caches need regenerating the core (JDK+sbt).

## 6. Open questions

- Larger I/D caches (regenerate VexRiscv with e.g. 16 KB + 16 KB from the free BSRAM).
- A group leader / shell on the console UART.
- Mixed native/emulated execution (code_server + the return path) — report upstream.
