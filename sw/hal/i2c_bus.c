#include "i2c_bus.h"
#include "mmio_poll.h"

#define I2C_BASE 0x60000000
#define I2C_FRAME_REG (*((volatile unsigned int *)I2C_BASE))
#define I2C_STAT_REG (*((volatile unsigned int *)(I2C_BASE + 4)))
#define I2C_DATA_REG (*((volatile unsigned int *)(I2C_BASE + 8)))
#define I2C_BUSY 0x01
#define I2C_ACK 0x02

int i2c_frame(unsigned int value) {
  if (!mmio_wait_clear(&I2C_STAT_REG, I2C_BUSY))
    return 0;
  I2C_FRAME_REG = value;
  if (!mmio_wait_clear(&I2C_STAT_REG, I2C_BUSY))
    return 0;
  return (I2C_STAT_REG & I2C_ACK) != 0;
}

void i2c_release(void) { i2c_frame(I2C_STOP | 0x00); }

unsigned char i2c_last_byte(void) { return (unsigned char)I2C_DATA_REG; }
