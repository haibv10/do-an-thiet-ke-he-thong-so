#ifndef MQ5_SENSOR_H
#define MQ5_SENSOR_H

// MQ-5 is analog, and the Tang Nano 9K has no ADC, so AO goes through an
// ADS1115 (I2C, address 0x48, ADDR pin to GND) that shares the DS3231 bus.
// AO swings up to 5 V while the ADS1115 runs from 3.3 V, so AO must reach the
// ADC through a 10k (top) / 20k (bottom) divider; the driver undoes it.

#define MQ5_LEVEL_CLEAN   0
#define MQ5_LEVEL_WARN    1
#define MQ5_LEVEL_DANGER  2

// AO thresholds in millivolts. Clean air depends on the module's load
// resistor and warm-up, so tune these against the board.
#define MQ5_WARN_MV       1500
#define MQ5_DANGER_MV     2500

// One single-shot conversion of AIN0. Stores AO in millivolts and returns one,
// or returns zero if the ADS1115 did not acknowledge.
int mq5_read_mv(unsigned int *mv);

// Raw ADS1115 code (+-4.096 V range, 125 uV per LSB) to AO millivolts.
unsigned int mq5_raw_to_mv(int raw);

// MQ5_LEVEL_CLEAN, MQ5_LEVEL_WARN or MQ5_LEVEL_DANGER.
unsigned int mq5_level_of(unsigned int mv);

#endif
