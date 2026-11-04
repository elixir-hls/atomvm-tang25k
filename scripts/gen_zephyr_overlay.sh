#!/usr/bin/env bash
# Generate the Zephyr DTS overlay for board litex_vexriscv from build/soc/csr.json.
# usage: scripts/gen_zephyr_overlay.sh <output overlay>
# LiteX's litex_json2dts_zephyr.py patches the known peripherals; nodes of the stock
# litex_vexriscv.dts it does not handle are disabled, and gpio_out/gpio_in are pointed at
# the Dock's LEDs / buttons (leds_out; buttons with edge IRQ), also labelled gpio0 / gpio1, the
# controller indices AtomVM's gpio module uses ({0, Pin} LEDs, {1, Pin} buttons). The CPU node gets the imac
# ISA: Zephyr derives RISCV_ISA_EXT_* (and -march) from riscv,isa-extensions.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
OUT="${1:?usage: $0 <output overlay>}"
mkdir -p "$(dirname "$OUT")"
python3 "$LITEX_DEPS/litex/litex/tools/litex_json2dts_zephyr.py" "$CSR_JSON" --dts "$OUT"
csr() { python3 -c "import json,sys; print(hex(json.load(open('$CSR_JSON'))['csr_bases']['$1']))"; }
reg() { python3 -c "import json,sys; print(hex(json.load(open('$CSR_JSON'))['csr_registers']['$1']['addr']))"; }
irq() { python3 -c "import json,sys; print(json.load(open('$CSR_JSON'))['constants']['$1_interrupt'])"; }
cat >> "$OUT" <<EOT
&cpu0 {
    riscv,isa-extensions = "i", "m", "a", "c", "zicsr", "zifencei";
};
&i2c1 { status = "disabled"; };
&pwm0 { status = "disabled"; };

#include <zephyr/dt-bindings/gpio/gpio.h>
EOT
# Zephyr's interrupt controller calls a handler only for an interrupt number that some enabled
# devicetree node has: without one, an interrupt connected in the application (IRQ_CONNECT in a
# NIF) is never served and fires for ever. So a node for each interrupt of the SoC that no
# Zephyr driver here takes.
python3 - "$CSR_JSON" >> "$OUT" <<'PY'
import json, sys
constants = json.load(open(sys.argv[1]))["constants"]
for k, v in sorted(constants.items()):
    name = k[:-len("_interrupt")] if k.endswith("_interrupt") else None
    if name and v is not None and name not in ("uart", "timer0", "buttons"):
        print(f"/ {{ irq_{name} {{ interrupt-parent = <&intc0>; interrupts = <{v} 1>; status = \"okay\"; }}; }};")
PY
# The Dock's LEDs and buttons, unless the SoC left their pins to the application's circuits
# (AtomVMSoC with_dock_gpio=False): then AtomVM's gpio module has no controllers here
if python3 -c "import json,sys; sys.exit('leds_out' not in json.load(open('$CSR_JSON'))['csr_registers'])"; then
cat >> "$OUT" <<EOT
&gpio_out {
    reg = <$(csr leds) 0x4>;
    reg-names = "out";
    ngpios = <2>;
    status = "okay";
};

&gpio_in {
    reg = <$(reg buttons_in) 0x4>,
          <$(reg buttons_mode) 0x4>,
          <$(reg buttons_edge) 0x4>,
          <$(reg buttons_ev_pending) 0x4>,
          <$(reg buttons_ev_enable) 0x4>;
    reg-names = "in", "mode", "edge", "ev_pending", "ev_enable";
    interrupts = <$(irq buttons) 1>;
    ngpios = <2>;
    status = "okay";
};

gpio0: &gpio_out { };
gpio1: &gpio_in { };

/ {
    leds {
        compatible = "gpio-leds";
        led0: led_0 { gpios = <&gpio_out 0 GPIO_ACTIVE_HIGH>; };
        led1: led_1 { gpios = <&gpio_out 1 GPIO_ACTIVE_HIGH>; };
    };
    /* Dock user buttons: the buttons CSR reads ~btn_n with a pull-down on the pin, i.e. 1
     * when released, 0 when pressed -> active low */
    buttons {
        compatible = "gpio-keys";
        sw0: button_0 { gpios = <&gpio_in 0 GPIO_ACTIVE_LOW>; };
        sw1: button_1 { gpios = <&gpio_in 1 GPIO_ACTIVE_LOW>; };
    };
    aliases {
        led0 = &led0;
        led1 = &led1;
        sw0 = &sw0;
        sw1 = &sw1;
    };
};
EOT
else
cat >> "$OUT" <<EOT
&gpio_out { status = "disabled"; };
&gpio_in { status = "disabled"; };
EOT
fi
echo "Wrote $OUT"
