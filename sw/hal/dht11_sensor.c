#include "dht11_sensor.h"

#define DHT11_BASE        0x80000000u
#define DHT11_CONTROL     (*((volatile unsigned int *) DHT11_BASE))
#define DHT11_STATUS      (*((volatile unsigned int *) DHT11_BASE))
#define DHT11_MEASUREMENT (*((volatile unsigned int *) (DHT11_BASE + 4u)))

void dht11_start(void) {
  DHT11_CONTROL = 1u;
}

unsigned int dht11_status(void) {
  return DHT11_STATUS;
}

int dht11_read(unsigned char *humidity, unsigned char *temperature) {
  unsigned int value;

  if (!(DHT11_STATUS & DHT11_VALID)) return 0;
  value = DHT11_MEASUREMENT;
  *humidity = (unsigned char) (value >> 8);
  *temperature = (unsigned char) value;
  return 1;
}
