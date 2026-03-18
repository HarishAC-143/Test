/**
 * Example 04: UART Serial Communication
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Configures USART2 for 115200-8-N-1 communication.
 * Transmits a greeting string, then echoes back any received characters.
 *
 * On Nucleo boards, USART2 (PA2=TX, PA3=RX) is connected to the
 * on-board ST-Link's virtual COM port — visible as a USB serial device
 * on the host PC.
 *
 * Concepts demonstrated:
 *   - Alternate function GPIO configuration
 *   - USART baud rate calculation
 *   - Polling-based TX and RX
 *   - Interrupt-driven RX
 *   - Redirecting printf to UART (retarget)
 */

#include <stdint.h>
#include <stdbool.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define APB1_BASE         (PERIPH_BASE)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE + 0x3800)
#define GPIOA_BASE        (AHB1_BASE + 0x0000)
#define USART2_BASE       (APB1_BASE + 0x4400)
#define NVIC_ISER_BASE    ((uint32_t)0xE000E100)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

/* RCC */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)

/* GPIOA */
#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_AFRL        REG32(GPIOA_BASE + 0x20)   /* Alternate function low (pins 0-7) */

/* USART2 */
#define USART2_SR         REG32(USART2_BASE + 0x00)   /* Status register   */
#define USART2_DR         REG32(USART2_BASE + 0x04)   /* Data register     */
#define USART2_BRR        REG32(USART2_BASE + 0x08)   /* Baud rate         */
#define USART2_CR1        REG32(USART2_BASE + 0x0C)   /* Control register 1 */
#define USART2_CR2        REG32(USART2_BASE + 0x10)   /* Control register 2 */
#define USART2_CR3        REG32(USART2_BASE + 0x14)   /* Control register 3 */

/* NVIC */
#define NVIC_ISER(n)      REG32(NVIC_ISER_BASE + 4 * (n))

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

#define USART2_IRQn       38

/*
 * System clock: 16 MHz (HSI default).
 * Baud rate:    115200
 *
 * USARTDIV = F_CLK / (16 × BaudRate) = 16000000 / (16 × 115200) ≈ 8.6875
 * Mantissa = 8, Fraction = 0.6875 × 16 = 11
 * BRR = (8 << 4) | 11 = 0x8B
 */
#define UART_BRR_VALUE    0x008B

/* Status register flags */
#define USART_SR_TXE      BIT(7)    /* Transmit data register empty */
#define USART_SR_TC       BIT(6)    /* Transmission complete         */
#define USART_SR_RXNE     BIT(5)    /* Read data register not empty  */

/* Control register 1 flags */
#define USART_CR1_UE      BIT(13)   /* USART enable                  */
#define USART_CR1_TE      BIT(3)    /* Transmitter enable             */
#define USART_CR1_RE      BIT(2)    /* Receiver enable                */
#define USART_CR1_RXNEIE  BIT(5)    /* RXNE interrupt enable          */

/* ───────────────────── Shared State ─────────────────────── */

static volatile bool     rx_ready = false;
static volatile uint8_t  rx_byte  = 0;

/* ───────────────────── GPIO Setup ───────────────────────── */

static void uart_gpio_init(void)
{
    /* Enable GPIOA clock */
    RCC_AHB1ENR |= BIT(0);

    /*
     * PA2 (TX) and PA3 (RX) — Alternate Function 7 (USART2).
     *
     * MODER: set to 10 (alternate function) for pins 2 and 3.
     */
    GPIOA_MODER &= ~(0x03UL << (2 * 2));
    GPIOA_MODER |=  (0x02UL << (2 * 2));    /* PA2 = AF */
    GPIOA_MODER &= ~(0x03UL << (3 * 2));
    GPIOA_MODER |=  (0x02UL << (3 * 2));    /* PA3 = AF */

    /*
     * AFRL (Alternate Function Low Register): 4 bits per pin (pins 0-7).
     * AF7 = 0x7 for USART2.
     *   PA2: bits [11:8]
     *   PA3: bits [15:12]
     */
    GPIOA_AFRL &= ~(0x0FUL << (2 * 4));
    GPIOA_AFRL |=  (0x07UL << (2 * 4));     /* PA2 = AF7 */
    GPIOA_AFRL &= ~(0x0FUL << (3 * 4));
    GPIOA_AFRL |=  (0x07UL << (3 * 4));     /* PA3 = AF7 */
}

/* ───────────────────── USART Setup ──────────────────────── */

static void uart_init(void)
{
    uart_gpio_init();

    /* Enable USART2 clock (APB1) */
    RCC_APB1ENR |= BIT(17);

    /* Disable USART while configuring */
    USART2_CR1 = 0;

    /* Configure baud rate */
    USART2_BRR = UART_BRR_VALUE;

    /*
     * Configure frame format (CR2):
     *   - 1 stop bit (bits [13:12] = 00) — default after reset
     */
    USART2_CR2 = 0;

    /*
     * No hardware flow control (CR3):
     *   - No CTS/RTS — default after reset
     */
    USART2_CR3 = 0;

    /*
     * Enable transmitter, receiver, and USART.
     * Optionally enable RXNE interrupt for interrupt-driven reception.
     */
    USART2_CR1 = USART_CR1_UE | USART_CR1_TE | USART_CR1_RE;
}

/**
 * Enable RXNE interrupt for interrupt-driven reception.
 */
static void uart_enable_rx_interrupt(void)
{
    USART2_CR1 |= USART_CR1_RXNEIE;
    NVIC_ISER(USART2_IRQn / 32) |= BIT(USART2_IRQn % 32);
}

/* ───────────────────── Polling TX/RX ────────────────────── */

/**
 * Transmit a single byte (blocking).
 * Waits until the Transmit Data Register is empty, then writes.
 */
static void uart_putc(uint8_t ch)
{
    while (!(USART2_SR & USART_SR_TXE)) {
        /* Wait for TXE flag */
    }
    USART2_DR = ch;
}

/**
 * Transmit a null-terminated string.
 */
static void uart_puts(const char *str)
{
    while (*str) {
        uart_putc((uint8_t)*str++);
    }
}

/**
 * Receive a single byte (blocking).
 * Waits until a byte is available in the Receive Data Register.
 */
static uint8_t uart_getc(void)
{
    while (!(USART2_SR & USART_SR_RXNE)) {
        /* Wait for RXNE flag */
    }
    return (uint8_t)(USART2_DR & 0xFF);
}

/* ───────────────────── Utility: Print Hex ───────────────── */

static void uart_print_hex(uint32_t value)
{
    static const char hex_digits[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart_putc(hex_digits[(value >> i) & 0x0F]);
    }
}

/* ───────────────────── ISR ──────────────────────────────── */

/**
 * USART2 interrupt handler.
 * Called when a byte is received (RXNE flag set).
 */
void USART2_IRQHandler(void)
{
    if (USART2_SR & USART_SR_RXNE) {
        rx_byte  = (uint8_t)(USART2_DR & 0xFF);
        rx_ready = true;
    }
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    uart_init();

    /* Send a greeting */
    uart_puts("=== Embedded C UART Example ===\r\n");
    uart_puts("Type characters — they will be echoed back.\r\n\r\n");

    /*
     * Choose one of two approaches:
     *
     * Approach 1: Polling — simple but blocks the CPU.
     * Approach 2: Interrupt-driven — CPU is free between bytes.
     */

    /* ── Approach 2: Interrupt-driven echo ──────────────── */
    uart_enable_rx_interrupt();

    while (1) {
        if (rx_ready) {
            rx_ready = false;

            uint8_t ch = rx_byte;

            /* Echo the character back */
            uart_putc(ch);

            /* Print hex value for non-printable characters */
            if (ch < 0x20 || ch > 0x7E) {
                uart_puts(" [");
                uart_print_hex(ch);
                uart_puts("]");
            }

            /* Newline handling: CR → CR+LF */
            if (ch == '\r') {
                uart_putc('\n');
            }
        }

        /* CPU is free to do other work here */
    }

    return 0;
}
