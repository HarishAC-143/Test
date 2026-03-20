/**
 * UART Polling-Based Communication
 *
 * Demonstrates the structure of a basic UART driver using polling.
 * Includes baud rate calculation, initialization, and character I/O.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o uart_polling uart_polling.c
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* ---- UART Frame Explanation ---- */

static void explain_uart(void)
{
    printf("=== UART Communication Basics ===\n\n");

    printf("UART (Universal Asynchronous Receiver/Transmitter) sends data\n");
    printf("one bit at a time without a shared clock line.\n\n");

    printf("Frame format (8N1 — most common):\n\n");
    printf("  Idle ─┐   ┌───┬───┬───┬───┬───┬───┬───┬───┬───┐   ┌─ Idle\n");
    printf("   (1)  └───│ D0│ D1│ D2│ D3│ D4│ D5│ D6│ D7│Stp│───┘  (1)\n");
    printf("        Start                                  Stop\n");
    printf("        bit(0)     8 data bits (LSB first)     bit(1)\n\n");

    printf("  Total: 10 bits per byte (1 start + 8 data + 1 stop)\n");
    printf("  At 115200 baud: ~11520 bytes/second (~86.8 µs per byte)\n\n");
}

/* ---- Baud Rate Calculation ---- */

static void explain_baud_rate(void)
{
    printf("=== Baud Rate Calculation ===\n\n");

    printf("The baud rate register (BRR) divides the peripheral clock\n");
    printf("to produce the UART bit clock:\n\n");
    printf("  BRR = System_clock / Baud_rate\n\n");

    struct { uint32_t baud; const char *use; } rates[] = {
        {   9600, "Slow sensors, GPS modules" },
        {  19200, "Older equipment" },
        {  38400, "Moderate speed" },
        { 115200, "Default for most debug consoles" },
        { 230400, "Higher speed, shorter cables" },
        { 921600, "High-speed data transfer" },
    };

    uint32_t sys_clock = 84000000;
    printf("  System clock: %u MHz\n\n", sys_clock / 1000000);
    printf("  %-8s  %-6s  %-8s  %s\n", "Baud", "BRR", "Error%%", "Typical Use");
    printf("  %-8s  %-6s  %-8s  %s\n", "--------", "------", "--------", "---");

    for (int i = 0; i < 6; i++) {
        uint32_t brr = sys_clock / rates[i].baud;
        double actual = (double)sys_clock / brr;
        double error = (actual - rates[i].baud) * 100.0 / rates[i].baud;

        printf("  %-8u  %-6u  %+.2f%%    %s\n",
               rates[i].baud, brr, error, rates[i].use);
    }
    printf("\n  Error must be < 3%% for reliable communication.\n\n");
}

/* ---- Simulated UART Peripheral ---- */

typedef struct {
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t BRR;
    volatile uint32_t CR1;
} USART_TypeDef;

static USART_TypeDef _usart1 = {0};
#define USART1 (&_usart1)

#define USART_SR_TXE   (1U << 7)   /* Transmit register empty */
#define USART_SR_RXNE  (1U << 5)   /* Receive register not empty */
#define USART_SR_TC    (1U << 6)   /* Transmission complete */
#define USART_CR1_TE   (1U << 3)   /* Transmitter enable */
#define USART_CR1_RE   (1U << 2)   /* Receiver enable */
#define USART_CR1_UE   (1U << 13)  /* USART enable */

/* TX buffer to capture what the UART "sends" */
#define TX_LOG_SIZE 256
static char tx_log[TX_LOG_SIZE];
static uint16_t tx_log_idx = 0;

/* ---- UART Driver Functions ---- */

static void uart_init(uint32_t sys_clock, uint32_t baudrate)
{
    USART1->BRR = sys_clock / baudrate;
    USART1->CR1 = USART_CR1_TE | USART_CR1_RE | USART_CR1_UE;
    USART1->SR  = USART_SR_TXE | USART_SR_TC;  /* Ready to transmit */
}

static void uart_send_byte(uint8_t byte)
{
    /* Wait for TXE (transmit data register empty) */
    while (!(USART1->SR & USART_SR_TXE))
        ;
    USART1->DR = byte;

    /* Log the transmitted byte */
    if (tx_log_idx < TX_LOG_SIZE - 1) {
        tx_log[tx_log_idx++] = (char)byte;
        tx_log[tx_log_idx] = '\0';
    }
}

static void uart_send_string(const char *str)
{
    while (*str) {
        uart_send_byte((uint8_t)*str++);
    }
}

static void uart_send_buffer(const uint8_t *buf, uint16_t len)
{
    for (uint16_t i = 0; i < len; i++) {
        uart_send_byte(buf[i]);
    }
}

/* ---- Lightweight Print Functions ---- */

static void uart_print_int(int32_t value)
{
    char buf[12];
    int i = 0;
    uint32_t abs_val;

    if (value < 0) {
        uart_send_byte('-');
        abs_val = (uint32_t)(-(value + 1)) + 1;
    } else {
        abs_val = (uint32_t)value;
    }

    if (abs_val == 0) {
        uart_send_byte('0');
        return;
    }

    while (abs_val > 0) {
        buf[i++] = '0' + (char)(abs_val % 10);
        abs_val /= 10;
    }

    while (i > 0)
        uart_send_byte((uint8_t)buf[--i]);
}

static void uart_print_hex(uint32_t value)
{
    const char hex[] = "0123456789ABCDEF";
    uart_send_string("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart_send_byte((uint8_t)hex[(value >> i) & 0xF]);
    }
}

/* ---- Demo ---- */

static void demo_uart_output(void)
{
    printf("=== UART Output Demo ===\n\n");

    uart_init(84000000, 115200);
    tx_log_idx = 0;

    /* Simulate sending various data */
    uart_send_string("Hello, Embedded World!\r\n");
    uart_send_string("ADC Value: ");
    uart_print_int(3247);
    uart_send_string(" (");
    uart_print_hex(0x00000CAF);
    uart_send_string(")\r\n");
    uart_send_string("Temperature: ");
    uart_print_int(-15);
    uart_send_string(" C\r\n");

    printf("Data sent over UART (captured in simulation):\n\n");
    printf("  %s\n", tx_log);

    printf("Total bytes transmitted: %u\n", tx_log_idx);
    printf("At 115200 baud: ~%.1f ms transmission time\n\n",
           tx_log_idx * 10.0 * 1000.0 / 115200.0);
}

static void demo_printf_comparison(void)
{
    printf("=== printf vs. Lightweight Functions ===\n\n");

    printf("  printf(\"Value: %%d\", 42):\n");
    printf("    + Familiar, flexible formatting\n");
    printf("    - Adds ~10-20 KB to Flash (full newlib)\n");
    printf("    - Slow (format string parsing at runtime)\n");
    printf("    - Uses heap (malloc) internally\n\n");

    printf("  uart_print_int(42):\n");
    printf("    + Tiny code size (~100 bytes)\n");
    printf("    + Fast (no format parsing)\n");
    printf("    + No heap usage\n");
    printf("    - Less flexible formatting\n\n");

    printf("  Recommendation: Use lightweight functions on constrained\n");
    printf("  targets (< 64 KB Flash). Use printf on larger MCUs where\n");
    printf("  code size is not critical.\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("UART Polling Communication Demo\n");
    printf("================================\n\n");

    explain_uart();
    explain_baud_rate();
    demo_uart_output();
    demo_printf_comparison();

    return 0;
}
