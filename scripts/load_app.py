#!/usr/bin/env python3
"""
Upload an application AVM pack into the SDRAM staging slot through the LiteX BIOS serial boot,
then abort the serial boot: the BIOS goes on to boot AtomVM from the SPI flash, whose loader
(apps/atomvm/src/avm_loader.c) picks the pack up. Only the small application crosses the
115200-baud UART; AtomVM and the library pack stay in flash (scripts/flash.sh).

After the upload the console output is printed (and appended to --log) for --seconds.
Start this before the board resets (scripts/run.sh loads the bitstream after it).

usage: load_app.py <port> <app.avm> [--address 0x41c00000] [--seconds 10] [--log file]
"""
import argparse
import sys
import time

import serial
from litex.tools.litex_term import (SFLFrame, sfl_cmd_abort, sfl_cmd_load, sfl_magic_ack,
                                    sfl_magic_req, sfl_ack_success, sfl_ack_crcerror)

CHUNK = 251     # bytes per frame (SFL maximum)


def send_frame(port, cmd, payload=b"", retries=8):
    frame = SFLFrame()
    frame.cmd = cmd
    frame.payload = payload
    data = frame.encode()
    for _ in range(retries):
        port.write(data)
        reply = port.read(1)
        if reply == sfl_ack_success:
            return
        if reply not in (sfl_ack_crcerror, b""):
            raise RuntimeError(f"unexpected reply {reply!r}")
    raise RuntimeError("frame not acknowledged")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("port")
    parser.add_argument("avm")
    parser.add_argument("--address", default="0x41c00000")
    parser.add_argument("--seconds", type=float, default=10)
    parser.add_argument("--log")
    parser.add_argument("--wait", type=float, default=30, help="seconds to wait for the BIOS")
    args = parser.parse_args()

    data = open(args.avm, "rb").read()
    address = int(args.address, 0)
    log = open(args.log, "ab", buffering=0) if args.log else None

    def out(b):
        sys.stdout.buffer.write(b)
        sys.stdout.flush()
        if log:
            log.write(b)

    # short read timeout while waiting: the BIOS gives up if the ack is late
    port = serial.Serial(args.port, 115200, timeout=0.01)
    deadline = time.time() + args.wait
    # Loading a bitstream into SRAM may first restart the FPGA from its flash: that BIOS asks
    # for a serial boot too and is gone a moment later, when the SRAM bitstream starts. A
    # load that gets an unexpected reply therefore waits for the next request and starts over.
    while True:
        buf = b""
        while sfl_magic_req not in buf:
            if time.time() > deadline:
                sys.exit("no serial boot request from the BIOS")
            b = port.read(256)
            out(b)
            buf = (buf + b)[-256:]
        port.write(sfl_magic_ack)
        port.timeout = 1.0
        t0 = time.time()
        try:
            for off in range(0, len(data), CHUNK):
                send_frame(port, sfl_cmd_load, (address + off).to_bytes(4, "big") + data[off:off + CHUNK])
            send_frame(port, sfl_cmd_abort)
            break
        except RuntimeError as e:
            out(f"\n[load_app] {e}: waiting for the next serial boot request\n".encode())
            port.timeout = 0.01
    out(f"\n[load_app] {len(data)} B to {address:#x} in {time.time() - t0:.1f} s, "
        f"serial boot aborted -> flash boot\n".encode())

    end = time.time() + args.seconds
    while time.time() < end:
        out(port.read(256))


if __name__ == "__main__":
    main()
