#ifndef MMIO_POLL_H
#define MMIO_POLL_H

// Iteration budget, not elapsed milliseconds. Override for bounded-wait tests.
#ifndef MMIO_POLL_LIMIT
#define MMIO_POLL_LIMIT 100000u
#endif

static inline int mmio_wait_clear(volatile unsigned int *status, unsigned int mask) {
  unsigned int remaining = MMIO_POLL_LIMIT;
  while (remaining != 0u) {
    if ((*status & mask) == 0u)
      return 1;
    remaining--;
  }
  return 0;
}

#endif
