#ifndef BCD_H
#define BCD_H

// Binary 0..99 to packed BCD; larger values are clamped to 99.
static inline unsigned char to_bcd(unsigned int value) {
  unsigned int tens = 0;
  if (value > 99u)
    value = 99u;
  while (value >= 10u) {
    value -= 10u;
    tens++;
  }
  return (unsigned char)((tens << 4) | value);
}

#endif
