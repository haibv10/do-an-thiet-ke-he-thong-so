#include "sys_delay.h"

// The counter is volatile so the loop survives optimisation, which also fixes
// its cost at nine clocks an iteration. Callers pass DELAY_MS rather than a
// raw count.
// The firmware is built with -Os to fit the 8 KiB ROM. Keep this function at
// -O1 because DELAY_MS is calibrated against the -O1 instruction sequence.
__attribute__((optimize("O1")))
void delay_loop(unsigned int iterations) {
  volatile unsigned int index;

  for (index = 0; index < iterations; index++) {
  }
}
