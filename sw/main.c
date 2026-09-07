#define GPIO_BASE     0x40000000
#define UART_BASE     0x50000000

#define LED_REG       (*((volatile unsigned int *) GPIO_BASE))
#define UART_TX_REG   (*((volatile unsigned int *) UART_BASE))
#define UART_STAT_REG (*((volatile unsigned int *) (UART_BASE + 4)))
#define UART_RX_REG   (*((volatile unsigned int *) (UART_BASE + 8)))

#define UART_TX_BUSY  0x01
#define UART_RX_VALID 0x02

int main() {
  LED_REG = 0;

  while (1) {
    if (UART_STAT_REG & UART_RX_VALID) {
      unsigned int received = UART_RX_REG;

      while (UART_STAT_REG & UART_TX_BUSY) {
      }

      UART_TX_REG = received;
      LED_REG = received & 1;
    }
  }
}
