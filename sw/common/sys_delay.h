#ifndef SYS_DELAY_H
#define SYS_DELAY_H

#define DELAY_MS(ms) ((ms) * 3000U)

void delay_loop(unsigned int iterations);

#endif
