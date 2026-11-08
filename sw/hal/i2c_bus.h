#ifndef I2C_BUS_H
#define I2C_BUS_H

#define I2C_START 0x100
#define I2C_STOP 0x200
#define I2C_READ 0x400
#define I2C_NACK 0x800

unsigned char i2c_last_byte(void);

// Returns 0 for NACK or polling timeout; 1 for ACK.
int i2c_frame(unsigned int value);

void i2c_release(void);

#endif
