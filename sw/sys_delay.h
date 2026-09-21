#ifndef SYS_DELAY_H
#define SYS_DELAY_H

// delay_loop counts iterations, not clocks. One iteration costs its five
// instructions plus two cycles for the taken branch and one for each load-use
// stall, which is nine, and nine is what the board measured as the gap between
// RTC lines. Changing optimisation level changes this number: the
// six-instruction loop -Os emits costs twelve.
#define DELAY_MS(ms) ((ms) * 3000U)

void delay_loop(unsigned int iterations);

#endif
