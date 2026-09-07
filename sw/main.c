#define GPIO_BASE     0x40000000
#define UART_BASE     0x50000000

#define LED_REG       (*((volatile unsigned int *) GPIO_BASE))
#define UART_TX_REG   (*((volatile unsigned int *) UART_BASE))
#define UART_STAT_REG (*((volatile unsigned int *) (UART_BASE + 4)))

// Cấu trúc vòng lặp lồng nhau kép ép chạy trên thanh ghi lõi
void delay_loop() {
    register int i, j;
    for (i = 0; i < 500; i++) {
        for (j = 0; j < 500; j++) {
            __asm__ volatile("nop");
        }
    }
}

int main() {
    while (1) {
        // Kiểm tra cờ bận bằng thanh ghi raw
        while (UART_STAT_REG & 0x01);
        UART_TX_REG = 'H';

        LED_REG = 1;
        delay_loop();

        LED_REG = 0;
        delay_loop();
    }
    return 0;
}
