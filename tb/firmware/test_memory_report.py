"""Exercise stack-report failure modes independently of the firmware compiler."""
import pathlib
import subprocess
import tempfile
import unittest

REPORT = pathlib.Path(__file__).resolve().parents[2] / "tools/report_memory.py"


class MemoryReportTest(unittest.TestCase):
    def report(self, assembly, frames):
        with tempfile.TemporaryDirectory() as directory:
            build = pathlib.Path(directory)
            (build / "firmware.bin").write_bytes(bytes(128))
            (build / "firmware.symbols").write_text(
                "00002000 A _rom_capacity\n00001000 A _ram_capacity\n"
                "20001000 A _stack_top\n20000000 A _data_start\n"
                "20000004 A _data_end\n20000004 A _bss_start\n"
                "20000010 A _bss_end\n00000080 T helper.constprop.0\n"
            )
            (build / "firmware.asm").write_text(assembly)
            (build / "test.su").write_text(frames)
            return subprocess.check_output(["python3", str(REPORT), str(build)], text=True)

    def test_direct_calls_and_optimized_tail_call(self):
        output = self.report(
            "00000000 <main>:\n 0: 000000ef jal 40 <worker>\n"
            "00000040 <worker>:\n 40: 0000006f j 80 <helper.constprop.0>\n"
            "00000080 <helper.constprop.0>:\n 80: 00008067 ret\n",
            "demo.c:1:1:main\t16\tstatic\n"
            "demo.c:2:1:worker\t32\tstatic\n"
            "demo.c:3:1:helper.constprop\t8\tstatic\n",
        )
        self.assertIn("ROM image: 128/8192 bytes", output)
        self.assertIn("RAM static: 16/4096 bytes", output)
        self.assertIn("estimate from main: 56 bytes", output)

    def test_recursion_is_not_reported_as_bounded(self):
        output = self.report(
            "00000000 <main>:\n 0: 000000ef jal 0 <main>\n",
            "demo.c:1:1:main\t16\tstatic\n",
        )
        self.assertIn("Stack estimate unavailable: recursive", output)

    def test_indirect_call_is_not_reported_as_bounded(self):
        output = self.report(
            "00000000 <main>:\n 0: 000780e7 jalr a5\n",
            "demo.c:1:1:main\t16\tstatic\n",
        )
        self.assertIn("Stack estimate unavailable: indirect", output)

    def test_missing_frame_is_not_assumed_zero(self):
        output = self.report("00000000 <main>:\n 0: 00008067 ret\n", "")
        self.assertIn("Stack estimate unavailable: missing", output)


if __name__ == "__main__":
    unittest.main()
