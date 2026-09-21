#ifndef GPIO_LED_H
#define GPIO_LED_H

// The board LED is active low, so the register holds what software wrote and
// the inversion happens on the pin rather than here.
void led_set(unsigned int on);

#endif
