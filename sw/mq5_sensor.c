#include "i2c_bus.h"
#include "sys_delay.h"
#include "mq5_sensor.h"

#define ADS_WRITE      0x90
#define ADS_READ       0x91
#define ADS_REG_CONV   0x00
#define ADS_REG_CONFIG 0x01

// Config 0xC383: start single shot, AIN0 against GND, +-4.096 V, single-shot
// mode, 128 SPS, comparator disabled.
#define ADS_CFG_HI     0xc3
#define ADS_CFG_LO     0x83

// 128 SPS converts in 7.8 ms; one more millisecond of margin.
#define ADS_WAIT_MS    9U

static int ads_write_config(void) {
  if (!i2c_frame(I2C_START | ADS_WRITE)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(ADS_REG_CONFIG)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(ADS_CFG_HI)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(I2C_STOP | ADS_CFG_LO)) {
    i2c_release();
    return 0;
  }
  return 1;
}

static int ads_read_conversion(int *raw) {
  unsigned int high;

  // Point at the conversion register, then turn the bus around.
  if (!i2c_frame(I2C_START | ADS_WRITE)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(ADS_REG_CONV)) {
    i2c_release();
    return 0;
  }
  if (!i2c_frame(I2C_START | ADS_READ)) {
    i2c_release();
    return 0;
  }

  i2c_frame(I2C_READ);
  high = i2c_last_byte();
  i2c_frame(I2C_READ | I2C_NACK | I2C_STOP);

  *raw = (int) (short) ((high << 8) | i2c_last_byte());
  return 1;
}

// No multiply or divide: the core has neither. One LSB is 125 uV, so the
// ADC pin in millivolts is raw / 8, and the 2/3 divider is undone by x1.5.
unsigned int mq5_raw_to_mv(int raw) {
  unsigned int pin_mv;

  if (raw < 0) return 0;
  pin_mv = ((unsigned int) raw) >> 3;
  return pin_mv + (pin_mv >> 1);
}

unsigned int mq5_level_of(unsigned int mv) {
  if (mv >= MQ5_DANGER_MV) return MQ5_LEVEL_DANGER;
  if (mv >= MQ5_WARN_MV) return MQ5_LEVEL_WARN;
  return MQ5_LEVEL_CLEAN;
}

int mq5_read_mv(unsigned int *mv) {
  int raw;

  if (!ads_write_config()) return 0;
  delay_loop(DELAY_MS(ADS_WAIT_MS));
  if (!ads_read_conversion(&raw)) return 0;

  *mv = mq5_raw_to_mv(raw);
  return 1;
}
