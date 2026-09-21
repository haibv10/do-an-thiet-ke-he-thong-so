#include "sys_delay.h"

// The counter is volatile so the loop survives optimisation, which also fixes
// its cost at nine clocks an iteration. Callers pass DELAY_MS rather than a
// raw count.
void delay_loop(unsigned int iterations) {
  volatile unsigned int index;

  for (index = 0; index < iterations; index++) {
  }
}
