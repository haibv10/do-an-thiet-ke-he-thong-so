"""Test the host RTC synchronization CLI against a pseudo-terminal board."""
from datetime import datetime
import errno
import os
import pathlib
import pty
import select
import subprocess
import threading
import time
import tty
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "tools/sync_rtc.py"


class RtcSyncTest(unittest.TestCase):
    def run_board(self, response):
        master, slave = pty.openpty()
        name = os.ttyname(slave)
        tty.setraw(slave)
        os.close(slave)
        stop = threading.Event()
        received = bytearray()
        errors = []

        def board():
            try:
                while not stop.is_set() and len(received) < 13:
                    os.write(master, b"RTC INVALID\r\n")
                    if select.select([master], [], [], 0.05)[0]:
                        try:
                            received.extend(os.read(master, 1024))
                        except OSError as error:
                            if error.errno == errno.EIO:
                                time.sleep(0.05)
                                continue
                            raise
                        # The script opens the slave in raw mode; ignore any
                        # terminal echo emitted before that setup completed.
                        start = received.find(b"W")
                        if start >= 0:
                            del received[:start]
                        else:
                            received.clear()
                if not stop.is_set():
                    response(master, bytes(received[:13]))
            except Exception as error:
                errors.append(error)

        worker = threading.Thread(target=board, daemon=True)
        worker.start()
        try:
            result = subprocess.run(
                ["python3", str(SCRIPT), "--port", name, "--timeout", "1.5"],
                capture_output=True, text=True, timeout=8,
            )
        finally:
            stop.set()
            worker.join(timeout=3)
            os.close(master)
        self.assertFalse(errors, errors)
        self.assertEqual(len(received), 13)
        self.assertRegex(received.decode(), r"^W\d{12}$")
        return result

    @staticmethod
    def reply(master, command):
        timestamp = datetime.strptime(command[1:].decode(), "%y%m%d%H%M%S")
        os.write(master, b"RTC SET OK\r\n")
        os.write(master, timestamp.strftime("RTC %Y-%m-%d %H:%M:%S\r\n").encode())

    def test_success_requires_ack_and_readback(self):
        result = self.run_board(self.reply)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Asia/Ho_Chi_Minh", result.stdout)
        self.assertIn("readback verified", result.stdout)

    def test_firmware_rejection(self):
        result = self.run_board(lambda master, command: os.write(master, b"RTC SET FAIL\r\n"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("firmware rejected", result.stderr)

    def test_no_acknowledgement(self):
        result = self.run_board(lambda master, command: None)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no RTC SET OK", result.stderr)

    def test_ack_without_readback_is_not_success(self):
        result = self.run_board(lambda master, command: os.write(master, b"RTC SET OK\r\n"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no valid time readback", result.stderr)

    def test_wrong_readback_is_not_success(self):
        result = self.run_board(lambda master, command: os.write(
            master, b"RTC SET OK\r\nRTC 2000-01-01 00:00:00\r\n"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("differs from host", result.stderr)

    def test_fragmented_response_across_read_timeouts(self):
        def fragmented(master, command):
            os.write(master, b"RTC SET ")
            time.sleep(0.3)
            os.write(master, b"OK\r\n")
            stamp = datetime.strptime(command[1:].decode(), "%y%m%d%H%M%S")
            os.write(master, stamp.strftime("RTC %Y-%m-%d %H:%M:%S\r\n").encode())
        result = self.run_board(fragmented)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
