#include "i2c_bus.h"

#define I2C_BASE      0x60000000
#define I2C_FRAME_REG (*((volatile unsigned int *) I2C_BASE))
#define I2C_STAT_REG  (*((volatile unsigned int *) (I2C_BASE + 4)))
#define I2C_DATA_REG  (*((volatile unsigned int *) (I2C_BASE + 8)))
#define I2C_BUSY      0x01
#define I2C_ACK       0x02

static void i2c_wait(void) {
  while (I2C_STAT_REG & I2C_BUSY) {
  }
}

// One store carries one frame. The acknowledge belongs to the frame that just
// finished, so it is only meaningful once busy has fallen again.
int i2c_frame(unsigned int value) {
  i2c_wait();
  I2C_FRAME_REG = value;
  i2c_wait();
  return (I2C_STAT_REG & I2C_ACK) != 0;
}

// The peripheral has no stop-only operation, so releasing the bus after a
// refused frame costs one throwaway byte. A slave that did not acknowledge is
// not listening to it.
void i2c_release(void) {
  i2c_frame(I2C_STOP | 0x00);
}

unsigned char i2c_last_byte(void) {
  return (unsigned char) I2C_DATA_REG;
}
