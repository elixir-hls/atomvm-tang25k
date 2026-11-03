#!/usr/bin/env python3
"""
LiteX SoC for AtomVM on the Sipeed Tang Primer 25K (see docs/design.md section 2).

litex-boards' sipeed_tang_primer_25k BaseSoC with
  VexRiscv imac (rv32imac) + SDRAM (sipeed module) + timer uptime (Zephyr) + no L2 cache
  + memory-mapped SPI flash (BIOS flash boot).

SPI flash (W25Q64, 8 MB, mapped at 0x800000) layout, written by scripts/flash.sh:
  0x000000 bitstream (~0.9 MB), FLASH_APP_OFFSET AtomVM image (BIOS flash boot copies it to
  SDRAM), 0x200000 library AVM pack (4 MB: atomvmlib precompiled for riscv32 is 2.8 MB),
  0x600000 application AVM pack (2 MB); apps/atomvm/src/avm_loader.c copies them to SDRAM.
"""
import os

from litex.build.generic_platform import Misc
import litex_boards.platforms.sipeed_tang_primer_25k as platform_mod

# The Dock's user buttons float without a pull-down (they read 1 when released through ~btn_n).
platform_mod._dock_io = [
    (*e, Misc("PULL_MODE=DOWN")) if e[0] == "btn_n" else e for e in platform_mod._dock_io
]

# Fixes to LiteX / LiteDRAM, wrapped around the upstream code (gateware/litex_fixes.py)
import litex_fixes  # noqa: F401  (applies them on import)

import litex_boards.targets.sipeed_tang_primer_25k as target
from litex.soc.cores.gpio import GPIOIn

DEFAULTS = {
    "cpu_variant": "imac",
    "with_sdram": True,
    "timer_uptime": True,
    # L2 cache between the CPU and SDRAM (bytes, SOC_L2_SIZE); VexRiscv's D-cache is write-through
    "l2_size": int(os.environ.get("SOC_L2_SIZE", 0)),
    "with_spi_flash": True,
    "with_buttons": False,      # replaced by an interrupt-capable GPIOIn below
}

FLASH_APP_OFFSET = 0x100000


class AtomVMSoC(target.BaseSoC):
    def __init__(self, *args, **kwargs):
        for k, v in DEFAULTS.items():
            kwargs[k] = v
        super().__init__(*args, **kwargs)
        # Dock user buttons with edge interrupts (Erlang gpio:set_int through Zephyr's gpio_litex)
        self.buttons = GPIOIn(pads=~self.platform.request_all("btn_n"), with_irq=True)
        self.irq.add("buttons", use_loc_if_exists=True)
        self.add_constant("FLASH_BOOT_ADDRESS",
                          self.bus.regions["spiflash"].origin + FLASH_APP_OFFSET)


target.BaseSoC = AtomVMSoC

if __name__ == "__main__":
    target.main()
