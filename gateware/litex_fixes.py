"""
Fixes to LiteX / LiteDRAM, applied when gateware/soc.py is imported (before the SoC is built).
Each fix wraps the upstream code instead of editing it, so a newer LiteX keeps working with
it, and checks that the upstream code still looks as the fix assumes: when it does not, the
build stops with the reason (look at the upstream change, then drop or adapt the fix).

1. dfi_phase_injector — LiteDRAM's DFI PhaseInjector (litedram/dfii.py; checked with litedram
   2026.08, c454a44):
   the commands the CPU issues to the SDRAM through CSRs (the BIOS's SDRAM init and memtest)
   reach the PHY combinationally from the CSR write strobe, i.e. from the decode of the CSR
   bus address. Through the DFIInjector's mux that path ends at the PHY's DQ output-enable
   register in the 2x clock domain, and on the Tang Primer 25K it missed setup by ~0.1-1 ns
   depending on the placement (sys 50 MHz -> sys2x 100 MHz, 10 ns). The fix registers the
   PhaseInjector's outputs to the PHY: software commands leave one sys clock later (rddata_en
   too, so the PHY's read data still lines up); the hardware controller's path is unchanged.
"""
import inspect
import os

import litedram.dfii as dfii
from migen import Record
from migen.fhdl.tools import list_targets
from migen.genlib.record import DIR_M_TO_S, DIR_S_TO_M

_UpstreamPhaseInjector = dfii.PhaseInjector


class RegisteredPhaseInjector(_UpstreamPhaseInjector):
    """LiteDRAM's PhaseInjector (same CSRs, same logic) driving an inner copy of the DFI phase;
    the signals it drives towards the PHY go out through a register, those from the PHY come
    in as they are. Signals of the phase it does not drive (cke, odt, reset_n: DFIInjector
    drives them) are left alone."""
    def __init__(self, phase):
        for entry in phase.layout:
            if len(entry) != 3 or entry[2] not in (DIR_M_TO_S, DIR_S_TO_M):
                raise SystemExit(f"litex_fixes: DFI phase field {entry!r} has no direction: "
                                 "litedram changed, check litex_fixes.RegisteredPhaseInjector")
        inner = Record(phase.layout)
        _UpstreamPhaseInjector.__init__(self, inner)
        driven = {id(s) for s in list_targets(self._fragment.comb)}
        registered = 0
        for name, _width, direction in phase.layout:
            outer, mine = getattr(phase, name), getattr(inner, name)
            if direction == DIR_M_TO_S:
                if id(mine) in driven:
                    self.sync += outer.eq(mine)
                    registered += 1
            else:
                self.comb += mine.eq(outer)
        if registered == 0:
            raise SystemExit("litex_fixes: PhaseInjector drives no DFI signal combinationally any "
                             "more: litedram changed, check whether the fix is still needed")


# LITEX_FIXES_SKIP=<name>,...: build without these fixes, to check whether one is still needed
# (build, then look at the timing report: scripts/check_timing.py in atomvm-tang25k-hls)
SKIP = {n.strip() for n in os.environ.get("LITEX_FIXES_SKIP", "").split(",") if n.strip()}


def apply():
    if "dfi_phase_injector" in SKIP:
        print("litex_fixes: dfi_phase_injector skipped (LITEX_FIXES_SKIP)")
        return
    params = list(inspect.signature(_UpstreamPhaseInjector.__init__).parameters)
    if params != ["self", "phase"]:
        raise SystemExit(f"litex_fixes: litedram.dfii.PhaseInjector.__init__{tuple(params)} "
                         "is not (self, phase) any more: check litex_fixes.RegisteredPhaseInjector")
    dfii.PhaseInjector = RegisteredPhaseInjector


apply()
