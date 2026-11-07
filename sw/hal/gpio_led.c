#include "gpio_led.h"

#define GPIO_BASE 0x40000000
#define LED_REG   (*((volatile unsigned int *) GPIO_BASE))

void led_set(unsigned int on) {
  LED_REG = on;
}
