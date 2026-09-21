#ifndef I2C_BUS_H
#define I2C_BUS_H

// Flags a caller ORs into the byte to shape the frame around it.
#define I2C_START     0x100
#define I2C_STOP      0x200
#define I2C_READ      0x400
#define I2C_NACK      0x800

// Byte received by the last read frame.
unsigned char i2c_last_byte(void);

// One store launches one frame: eight data bits and an acknowledge, shaped by
// the flag bits in mmio_map.h. Framing a transaction out of frames is the
// caller's job, because which register pointer to set and where a read turns
// around are properties of the slave rather than of the bus.
int i2c_frame(unsigned int value);

// The peripheral has no stop-only operation, so releasing the bus after a
// refused frame costs one throwaway byte.
void i2c_release(void);

#endif
