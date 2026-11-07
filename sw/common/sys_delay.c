#include "sys_delay.h"

__attribute__((optimize("O1")))
void delay_loop(unsigned int iterations) {
  volatile unsigned int index;

  for (index = 0; index < iterations; index++) {
  }
}
