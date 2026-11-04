# AtomVM on Tang Primer 25K

Run [AtomVM](https://github.com/atomvm/AtomVM) (Erlang/Elixir VM) on a LiteX SoC
(VexRiscv rv32imac + SDRAM) on the Sipeed Tang Primer 25K, through Zephyr.

Work in progress — see [docs/design.md](docs/design.md) for the approach and stages.

Status: AtomVM (0.7, Zephyr port) runs Erlang apps on the board (`erl/hello.erl`: `io:format`,
`spawn`, message passing). AtomVM and the Erlang library (atomvmlib) live in the SPI flash;
an application is either uploaded over the UART in a fraction of a second or also kept in
flash for standalone boot.

## Requirements

- Sipeed Tang Primer 25K + Dock, with the Sipeed SDRAM module
- Gowin IDE, installed from Gowin's site (developed with V1.9.11.03 Education); its
  directory in `GOWIN_HOME`, e.g. `export GOWIN_HOME=$HOME/Gowin_V1.9.11.03_Education` in the
  shell profile (the scripts that build a SoC stop without it; LiteX runs its `gw_sh`)
- openFPGALoader >= 1.1.1
- Zephyr v4.4.2 workspace (`ZEPHYR_WORKSPACE`, default `~/zephyrproject`) and Zephyr SDK 1.0.1
  ([below](#the-zephyr-workspace))
- For AtomVM: Erlang/OTP (tested 28.3), rebar3, gperf, cmake, ninja
- The UART (FT2232 channel B) needs `ftdi_sio`: `sudo modprobe ftdi_sio`

### The Zephyr workspace

Zephyr's getting started, as this repository uses it (Ubuntu). The scripts activate the Python
virtual environment in `$ZEPHYR_WORKSPACE/.venv`, so it goes inside the workspace:

```sh
sudo apt install --no-install-recommends git cmake ninja-build gperf ccache dfu-util \
  device-tree-compiler wget python3-dev python3-venv python3-tk xz-utils file make gcc \
  gcc-multilib g++-multilib libsdl2-dev libmagic1

python3 -m venv ~/zephyrproject/.venv
source ~/zephyrproject/.venv/bin/activate
pip install west
west init -m https://github.com/zephyrproject-rtos/zephyr --mr v4.4.2 ~/zephyrproject
cd ~/zephyrproject
west update                  # Zephyr and its modules (takes a while)
west zephyr-export           # lets CMake find Zephyr
west packages pip --install  # Zephyr's Python packages

# the SDK with the RISC-V toolchain only (the CPU, VexRiscv, is RISC-V): ~/zephyr-sdk-1.0.1
cd ~/zephyrproject/zephyr
west sdk install --version 1.0.1 -t riscv64-zephyr-elf
```

A workspace elsewhere than `~/zephyrproject` is named by `ZEPHYR_WORKSPACE`.

## Build and run

```sh
scripts/setup_litex.sh        # pinned LiteX into deps/ (or: ln -s <same-commit workspace> deps)
scripts/build_soc.sh          # gateware -> build/soc/
scripts/build_app.sh          # plain Zephyr app (default apps/hello_world) -> build/app_<name>/
scripts/run.sh                # load the bitstream to SRAM and serial-boot that app

scripts/setup_atomvm.sh       # pinned AtomVM (Zephyr port) into ext/AtomVM + patches/atomvm
scripts/build_host.sh         # host tools: packbeam, atomvmlib-zephyr.avm -> build/host/
scripts/build_atomvm.sh       # AtomVM -> build/app_atomvm/zephyr/AtomVM.bin
scripts/flash.sh vm lib       # AtomVM + atomvmlib into the SPI flash (JTAG; once per VM build)
scripts/run.sh atomvm hello   # erl/hello.erl -> build/erl/hello.avm, uploaded, AtomVM boots from flash
```

Standalone boot: `scripts/flash.sh all hello` writes the bitstream, AtomVM, atomvmlib and the
app; after a power cycle the BIOS boots AtomVM from flash (when no upload answers on the UART).

### Memory map

| Where | Address | Content |
|---|---|---|
| SPI flash | 0x000000 | bitstream (~0.9 MB) |
| | 0x100000 | AtomVM image (LiteX BIOS flash boot format) |
| | 0x200000 | library pack (4 MB max): atomvmlib-zephyr-native.avm (all precompiled, 2.6 MB) or atomvmlib-zephyr.avm (BEAM, 0.5 MB) |
| | 0x600000 | application pack (2 MB max) |
| SDRAM | 0x40000000 | Zephyr + AtomVM, malloc arena (24 MB) |
| | 0x41800000 | library pack, copied from flash at boot |
| | 0x41c00000 | staging slot for an uploaded application |
| | 0x41e00000 | application pack AtomVM runs (from staging, else from flash) |

### Precompiled code

AtomVM runs precompiled riscv32 native code from the packs (`patches/atomvm/0004`).
Native and emulated code must not be mixed on this port (calls between them fail), so use
either `scripts/flash.sh lib` (atomvmlib-zephyr-native.avm, every module precompiled by
`scripts/build_host.sh`) with precompiled apps (the default of `scripts/build_erl.sh`), or
`lib-emu` with `EMU=1` apps.

### GPIO and UART

`{0, N}` are the Dock LEDs, `{1, N}` the user buttons (edge interrupts; the input reads 0
while pressed). See `erl/gpio_demo.erl`. `AtomVMSoC(with_dock_gpio=False)` leaves those pins to the
application's circuits; AtomVM's `gpio` module then has no controllers. Console input: `io:get_line` needs a group leader,
which this port does not start; read the console UART with `uart:open([])` (`erl/echo.erl`).

### LiteX fixes

`gateware/litex_fixes.py` (applied on import by `gateware/soc.py`):

| Fix | Why |
|---|---|
| LiteDRAM's DFI `PhaseInjector`: its outputs to the PHY go through a register | The commands the CPU issues to the SDRAM through CSRs (BIOS SDRAM init) reached the PHY's DQ output-enable register (2x clock) combinationally from the CSR bus address decode: up to ~1 ns short of setup, depending on the placement. Software commands now leave one clock later; the controller's path is unchanged (checked: BIOS SDRAM init + memtest OK) |

After a LiteX update the build stops with the reason if a fix no longer fits the upstream
code; then look at the upstream change and adapt or drop the fix.

### Performance notes

Precompiled code runs 1.3-14x faster than emulated (`erl/bench.erl`, table in
docs/design.md). Spawn processes that build large terms with
`spawn_opt(Fun, [{atomvm_heap_growth, fibonacci}])`: the default growth strategy
garbage-collects every few allocations once a term grows. Integers above 2^27 are boxed on
this 32-bit target and are much slower than small integers.

## Layout

- `gateware/soc.py` — the LiteX SoC
- `gateware/litex_fixes.py` — fixes to LiteX / LiteDRAM, wrapped around the upstream classes
  when the SoC is built (no edits to the LiteX sources): each checks that the upstream code
  still looks as it assumes and stops the build otherwise
- `apps/hello_world` — plain Zephyr check
- `apps/atomvm` — AtomVM's Zephyr port + board config + AVM pack loader (`src/avm_loader.c`)
- `scripts/load_app.py` — uploads an application pack through the BIOS serial boot, then lets
  the BIOS continue with the flash boot
- `erl/` — Erlang apps run on the board
- `patches/atomvm/` — fixes applied on top of the pinned AtomVM commit

## License

Apache-2.0 (see [LICENSE](LICENSE)). `litex_setup.py` is LiteX's own setup script (BSD-2-Clause).
