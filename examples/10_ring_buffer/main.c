/**
 * Example 10: Ring Buffer — Interrupt-Driven UART with Buffering
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Uses the ring buffer library to buffer incoming and outgoing UART
 * data.  The UART ISR pushes received bytes into an RX ring buffer;
 * the main loop processes them.  Outgoing data is placed in a TX ring
 * buffer and transmitted by the TX-empty interrupt.
 *
 * This is the production-quality pattern for UART communication in
 * embedded systems — no bytes are lost, and the CPU is not blocked
 * waiting for transmission.
 *
 * Concepts demonstrated:
 *   - Ring buffer for ISR ↔ main communication
 *   - Interrupt-driven TX (no blocking waits)
 *   - Interrupt-driven RX (no polling)
 *   - Line buffering (process complete lines)
 */

#include <stdint.h>
#include <stdbool.h>
#include "ring_buffer.h"

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

#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)

#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_AFRL        REG32(GPIOA_BASE + 0x20)

#define USART2_SR         REG32(USART2_BASE + 0x00)
#define USART2_DR         REG32(USART2_BASE + 0x04)
#define USART2_BRR        REG32(USART2_BASE + 0x08)
#define USART2_CR1        REG32(USART2_BASE + 0x0C)

#define NVIC_ISER(n)      REG32(NVIC_ISER_BASE + 4 * (n))

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

#define USART2_IRQn       38

#define USART_SR_TXE      BIT(7)
#define USART_SR_RXNE     BIT(5)
#define USART_CR1_UE      BIT(13)
#define USART_CR1_TE      BIT(3)
#define USART_CR1_RE      BIT(2)
#define USART_CR1_RXNEIE  BIT(5)
#define USART_CR1_TXEIE   BIT(7)

/* ───────────────────── Ring Buffers ─────────────────────── */

static ring_buf_t rx_buf;
static ring_buf_t tx_buf;

/* ───────────────────── UART Setup ───────────────────────── */

static void uart_init(void)
{
    RCC_AHB1ENR |= BIT(0);
    RCC_APB1ENR |= BIT(17);

    /* PA2 = TX (AF7), PA3 = RX (AF7) */
    for (int pin = 2; pin <= 3; pin++) {
        GPIOA_MODER = (GPIOA_MODER & ~(0x03UL << (pin * 2))) | (0x02UL << (pin * 2));
        GPIOA_AFRL  = (GPIOA_AFRL  & ~(0x0FUL << (pin * 4))) | (0x07UL << (pin * 4));
    }

    USART2_CR1 = 0;
    USART2_BRR = 0x008B;   /* 115200 baud @ 16 MHz */

    /* Enable USART, TX, RX, RXNE interrupt */
    USART2_CR1 = USART_CR1_UE | USART_CR1_TE | USART_CR1_RE | USART_CR1_RXNEIE;

    /* Enable USART2 interrupt in NVIC */
    NVIC_ISER(USART2_IRQn / 32) |= BIT(USART2_IRQn % 32);
}

/* ───────────────────── USART2 ISR ───────────────────────── */

void USART2_IRQHandler(void)
{
    /* ── Receive ── */
    if (USART2_SR & USART_SR_RXNE) {
        uint8_t byte = (uint8_t)(USART2_DR & 0xFF);
        ring_buf_put(&rx_buf, byte);   /* If full, byte is dropped */
    }

    /* ── Transmit ── */
    if ((USART2_CR1 & USART_CR1_TXEIE) && (USART2_SR & USART_SR_TXE)) {
        uint8_t byte;
        if (ring_buf_get(&tx_buf, &byte)) {
            USART2_DR = byte;
        } else {
            /* TX buffer empty — disable TXE interrupt to stop firing */
            USART2_CR1 &= ~USART_CR1_TXEIE;
        }
    }
}

/* ───────────────────── Buffered UART API ────────────────── */

/**
 * Queue a byte for transmission.
 * Returns immediately; actual transmission happens in the ISR.
 */
static bool uart_send(uint8_t byte)
{
    bool ok = ring_buf_put(&tx_buf, byte);
    if (ok) {
        /* Enable TXE interrupt to start transmission */
        USART2_CR1 |= USART_CR1_TXEIE;
    }
    return ok;
}

/**
 * Queue a null-terminated string for transmission.
 */
static void uart_send_string(const char *str)
{
    while (*str) {
        while (!uart_send((uint8_t)*str)) {
            /* TX buffer full — spin until space is available */
        }
        str++;
    }
}

/**
 * Check if a complete line (\r or \n terminated) is available
 * in the RX buffer.  Does NOT consume data.
 */
static bool uart_line_available(void)
{
    for (uint32_t i = rx_buf.tail; i != rx_buf.head;
         i = (i + 1) & (RING_BUF_SIZE - 1))
    {
        if (rx_buf.data[i] == '\r' || rx_buf.data[i] == '\n') {
            return true;
        }
    }
    return false;
}

/**
 * Read a line from the RX buffer into dst (up to max_len - 1 chars).
 * Returns the length of the line (excluding null terminator).
 */
static uint32_t uart_read_line(char *dst, uint32_t max_len)
{
    uint32_t len = 0;
    uint8_t  byte;

    while (ring_buf_get(&rx_buf, &byte)) {
        if (byte == '\r' || byte == '\n') {
            break;
        }
        if (len < max_len - 1) {
            dst[len++] = (char)byte;
        }
    }
    dst[len] = '\0';
    return len;
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    ring_buf_init(&rx_buf);
    ring_buf_init(&tx_buf);
    uart_init();

    uart_send_string("=== Ring Buffer UART Example ===\r\n");
    uart_send_string("Type a line and press Enter:\r\n\r\n");

    char line_buf[128];

    while (1) {
        if (uart_line_available()) {
            uint32_t len = uart_read_line(line_buf, sizeof(line_buf));

            uart_send_string("You typed (");
            /* Print length as ASCII digits */
            if (len >= 100) uart_send('0' + (len / 100) % 10);
            if (len >= 10)  uart_send('0' + (len / 10)  % 10);
            uart_send('0' + len % 10);
            uart_send_string(" chars): ");
            uart_send_string(line_buf);
            uart_send_string("\r\n");

            /* Print buffer utilization */
            uart_send_string("[RX buf: ");
            uint32_t cnt = ring_buf_count(&rx_buf);
            if (cnt >= 100) uart_send('0' + (cnt / 100) % 10);
            if (cnt >= 10)  uart_send('0' + (cnt / 10)  % 10);
            uart_send('0' + cnt % 10);
            uart_send_string("/");
            /* Print buffer size */
            uint32_t sz = RING_BUF_SIZE - 1;
            if (sz >= 100) uart_send('0' + (sz / 100) % 10);
            if (sz >= 10)  uart_send('0' + (sz / 10)  % 10);
            uart_send('0' + sz % 10);
            uart_send_string("]\r\n");
        }
    }

    return 0;
}
