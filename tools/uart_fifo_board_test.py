#!/usr/bin/env python3
"""Exercise the UART RX FIFO through the firmware T command."""

import argparse
import os
import select
import sys
import termios
import time


CASE16 = bytes(range(0x10, 0x20))
CASE17 = bytes(range(0x80, 0x91))


def configure_serial(fd):
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attrs[3] = 0
    attrs[4] = termios.B115200
    attrs[5] = termios.B115200
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device", help="external USB-UART device")
    parser.add_argument("--timeout", type=float, default=15.0)
    args = parser.parse_args()

    fd = os.open(args.device, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        configure_serial(fd)
        deadline = time.monotonic() + args.timeout
        output = bytearray()
        sent_trigger = False
        sent_case16 = False
        sent_case17 = False

        while time.monotonic() < deadline:
            readable, _, _ = select.select([fd], [], [], 0.1)
            if not readable:
                continue

            chunk = os.read(fd, 256)
            if not chunk:
                continue

            output.extend(chunk)
            sys.stdout.buffer.write(chunk)
            sys.stdout.buffer.flush()

            if not sent_trigger and b"BOOT " in output:
                os.write(fd, b"T")
                sent_trigger = True
            if sent_trigger and not sent_case16 and b"RXFIFO CASE16" in output:
                os.write(fd, CASE16)
                sent_case16 = True
            if sent_case16 and not sent_case17 and b"RXFIFO CASE17" in output:
                os.write(fd, CASE17)
                sent_case17 = True
            if b"RXFIFO PASS" in output:
                return 0
            if b"RXFIFO FAIL" in output:
                return 1

        print("\nRXFIFO TIMEOUT", file=sys.stderr)
        return 2
    finally:
        os.close(fd)


if __name__ == "__main__":
    sys.exit(main())
