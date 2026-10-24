#ifndef DHT11_SENSOR_H
#define DHT11_SENSOR_H

#define DHT11_BUSY  0x01u
#define DHT11_VALID 0x02u
#define DHT11_FAULT 0x04u

void dht11_start(void);
unsigned int dht11_status(void);
int dht11_read(unsigned char *humidity, unsigned char *temperature);

#endif
