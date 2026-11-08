#!/usr/bin/env python3
"""Set the DS3231 from the host clock using the firmware's UART command."""
import argparse
from datetime import datetime, timedelta
import math
import os
import re
import shutil
import subprocess
import sys
import time
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

TIME_LINE = re.compile(r"RTC (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})$")


def positive_timeout(value):
    value = float(value)
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError("timeout must be a finite positive number")
    return value


def lines_until(port, deadline):
    pending = bytearray()
    while time.monotonic() < deadline:
        pending.extend(port.read(max(1, min(port.in_waiting, 4096))))
        while b"\n" in pending:
            line, _, pending = pending.partition(b"\n")
            yield line.decode("ascii", errors="replace").strip()
        if len(pending) > 4096:
            pending.clear()


def sync_rtc(port, zone, timeout):
    # Give boot output a chance to arrive. A quiet RTC is still allowed: invalid
    # or stopped seconds can leave the application without periodic UART output.
    ready_deadline = time.monotonic() + min(2.0, timeout)
    for line in lines_until(port, ready_deadline):
        if line.startswith("RTC "):
            break

    # Discard old output so an old acknowledgement cannot confirm this request.
    port.reset_input_buffer()
    requested = datetime.now(zone).replace(microsecond=0)
    if not 2000 <= requested.year <= 2099:
        raise RuntimeError("firmware supports years 2000 through 2099")
    command = ("W" + requested.strftime("%y%m%d%H%M%S")).encode("ascii")
    print(f"Sending host time: {requested.isoformat()} ({zone.key})", flush=True)
    sent_at = time.monotonic()
    if port.write(command) != len(command):
        raise RuntimeError("incomplete UART write")
    port.flush()

    deadline = sent_at + timeout
    acknowledged = False
    for line in lines_until(port, deadline):
        if not line:
            continue
        if line.startswith("RTC SET "):
            print(line, flush=True)
            if line != "RTC SET OK":
                raise RuntimeError("firmware rejected the time-setting command")
            acknowledged = True
        elif acknowledged:
            match = TIME_LINE.fullmatch(line)
            if match:
                actual = datetime.strptime(match[1], "%Y-%m-%d %H:%M:%S").replace(tzinfo=zone)
                expected = requested + timedelta(seconds=time.monotonic() - sent_at)
                if abs((actual - expected).total_seconds()) > 3:
                    raise RuntimeError(f"RTC readback differs from host time: {line}")
                print(line, flush=True)
                print("RTC synchronized; acknowledgement and time readback verified.")
                return
    if acknowledged:
        raise RuntimeError("RTC SET OK received, but no valid time readback before timeout")
    raise RuntimeError("no RTC SET OK before timeout; check firmware, UART wiring and port")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default="/dev/ttyUSB0", help="UART port (default: /dev/ttyUSB0)")
    parser.add_argument("--timezone", default="Asia/Ho_Chi_Minh", help="RTC timezone (default: Asia/Ho_Chi_Minh)")
    parser.add_argument("--timeout", type=positive_timeout, default=15.0, help="response timeout in seconds (default: 15)")
    args = parser.parse_args()
    try:
        zone = ZoneInfo(args.timezone)
    except ZoneInfoNotFoundError:
        parser.error(f"unknown timezone: {args.timezone}")
    try:
        import serial
    except ImportError:
        print("Missing pyserial. On Ubuntu: sudo apt install python3-serial", file=sys.stderr)
        return 1
    # Detect existing terminals before opening. pyserial's exclusive lock alone
    # cannot exclude a terminal that does not use flock, such as picocom.
    if os.name == "posix" and shutil.which("fuser"):
        users = subprocess.run(["fuser", "--", args.port], capture_output=True, text=True)
        if users.stdout.strip():
            print(f"Port {args.port} is in use. Exit picocom (Ctrl-A, Ctrl-X) first.", file=sys.stderr)
            return 1
    try:
        options = {"exclusive": True} if os.name == "posix" else {}
        with serial.Serial(port=None, baudrate=115200, timeout=0.2, write_timeout=2,
                           xonxoff=False, rtscts=False, dsrdtr=False, **options) as port:
            port.dtr = False
            port.rts = False
            port.port = args.port
            port.open()
            sync_rtc(port, zone, args.timeout)
    except (serial.SerialException, OSError, RuntimeError, ValueError) as error:
        print(f"RTC sync failed: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("RTC sync cancelled.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
