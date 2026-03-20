/**
 * Interrupt-Driven UART with Ring Buffer
 *
 * Production-quality UART driver pattern using:
 *   - Ring buffer for RX data (ISR → main loop)
 *   - Ring buffer for TX data (main loop → ISR)
 *   - Non-blocking API
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o uart_interrupt uart_interrupt.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

/* ---- Ring Buffer Implementation ---- */

#define RING_BUF_SIZE 128
#define RING_BUF_MASK (RING_BUF_SIZE - 1)

typedef struct {
    uint8_t  buffer[RING_BUF_SIZE];
    volatile uint16_t head;
    volatile uint16_t tail;
} RingBuffer;

static void rb_init(RingBuffer *rb)
{
    rb->head = 0;
    rb->tail = 0;
}

static bool rb_is_empty(const RingBuffer *rb)
{
    return rb->head == rb->tail;
}

static bool rb_is_full(const RingBuffer *rb)
{
    return ((rb->head + 1) & RING_BUF_MASK) == rb->tail;
}

static uint16_t rb_count(const RingBuffer *rb)
{
    return (rb->head - rb->tail) & RING_BUF_MASK;
}

static bool rb_put(RingBuffer *rb, uint8_t byte)
{
    if (rb_is_full(rb))
        return false;
    rb->buffer[rb->head] = byte;
    rb->head = (rb->head + 1) & RING_BUF_MASK;
    return true;
}

static bool rb_get(RingBuffer *rb, uint8_t *byte)
{
    if (rb_is_empty(rb))
        return false;
    *byte = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) & RING_BUF_MASK;
    return true;
}

/* ---- UART Driver State ---- */

static RingBuffer uart_rx_buf;
static RingBuffer uart_tx_buf;
static uint32_t rx_overrun_count = 0;

/* ---- Simulated USART Peripheral ---- */

typedef struct {
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t BRR;
    volatile uint32_t CR1;
} USART_TypeDef;

static USART_TypeDef _usart1 = {0};
#define USART1 (&_usart1)

#define SR_RXNE  (1U << 5)
#define SR_TXE   (1U << 7)
#define CR1_RXNEIE (1U << 5)
#define CR1_TXEIE  (1U << 7)

/* ---- UART ISR ---- */

/*
 * In real hardware, this is called automatically by the NVIC
 * when the USART generates an interrupt.
 */
void USART1_IRQHandler(void)
{
    /* Receive interrupt: byte available */
    if (USART1->SR & SR_RXNE) {
        uint8_t byte = (uint8_t)(USART1->DR & 0xFF);
        if (!rb_put(&uart_rx_buf, byte)) {
            rx_overrun_count++;  /* Buffer full — data lost! */
        }
    }

    /* Transmit interrupt: TX register empty, send next byte */
    if (USART1->SR & SR_TXE) {
        uint8_t byte;
        if (rb_get(&uart_tx_buf, &byte)) {
            USART1->DR = byte;
        } else {
            USART1->CR1 &= ~CR1_TXEIE;  /* No more data — disable TX IRQ */
        }
    }
}

/* ---- UART Driver API ---- */

static void uart_init(uint32_t sys_clock, uint32_t baudrate)
{
    rb_init(&uart_rx_buf);
    rb_init(&uart_tx_buf);
    rx_overrun_count = 0;

    USART1->BRR = sys_clock / baudrate;
    USART1->CR1 = (1U << 13) |  /* UE: USART enable */
                  (1U << 3)  |  /* TE: Transmitter enable */
                  (1U << 2)  |  /* RE: Receiver enable */
                  CR1_RXNEIE;   /* RXNE interrupt enable */
    USART1->SR = SR_TXE;        /* TX ready */
}

static void uart_write(const uint8_t *data, uint16_t len)
{
    for (uint16_t i = 0; i < len; i++) {
        while (rb_is_full(&uart_tx_buf))
            ;  /* Wait for space — or implement overflow strategy */
        rb_put(&uart_tx_buf, data[i]);
    }
    USART1->CR1 |= CR1_TXEIE;  /* Enable TX interrupt to start sending */
}

static void uart_write_string(const char *str)
{
    uart_write((const uint8_t *)str, (uint16_t)strlen(str));
}

static int16_t uart_read_byte(void)
{
    uint8_t byte;
    if (rb_get(&uart_rx_buf, &byte))
        return byte;
    return -1;
}

static uint16_t uart_read(uint8_t *buf, uint16_t max_len)
{
    uint16_t count = 0;
    uint8_t byte;
    while (count < max_len && rb_get(&uart_rx_buf, &byte)) {
        buf[count++] = byte;
    }
    return count;
}

static uint16_t uart_available(void)
{
    return rb_count(&uart_rx_buf);
}

/* ---- Simulation: Feed Data and Process ---- */

static void simulate_rx(const char *data)
{
    for (const char *p = data; *p; p++) {
        USART1->SR = SR_RXNE;
        USART1->DR = (uint8_t)*p;
        USART1_IRQHandler();
    }
    USART1->SR = 0;
}

static void simulate_tx_drain(void)
{
    printf("  TX output: \"");
    USART1->SR = SR_TXE;
    while (!rb_is_empty(&uart_tx_buf)) {
        USART1_IRQHandler();
        printf("%c", (char)(USART1->DR & 0xFF));
    }
    printf("\"\n");
}

/* ---- Demo ---- */

static void demo_interrupt_uart(void)
{
    printf("=== Interrupt-Driven UART Demo ===\n\n");

    uart_init(84000000, 115200);

    /* Simulate receiving "Hello\r\n" */
    printf("1. Simulating incoming data: \"Hello\\r\\n\"\n");
    simulate_rx("Hello\r\n");
    printf("   RX buffer count: %u bytes\n", uart_available());

    /* Read the data in main loop */
    printf("   Reading from RX buffer: \"");
    int16_t c;
    while ((c = uart_read_byte()) >= 0) {
        if (c == '\r') printf("\\r");
        else if (c == '\n') printf("\\n");
        else printf("%c", (char)c);
    }
    printf("\"\n\n");

    /* Simulate sending data */
    printf("2. Sending response: \"ACK: Message received\\r\\n\"\n");
    uart_write_string("ACK: Message received\r\n");
    printf("   TX buffer count: %u bytes\n", rb_count(&uart_tx_buf));
    simulate_tx_drain();
    printf("\n");

    /* Simulate buffer overflow */
    printf("3. Simulating RX buffer overflow:\n");
    printf("   Buffer size: %d bytes (usable: %d)\n",
           RING_BUF_SIZE, RING_BUF_SIZE - 1);

    char overflow_data[200];
    for (int i = 0; i < 199; i++)
        overflow_data[i] = 'A' + (char)(i % 26);
    overflow_data[199] = '\0';

    rx_overrun_count = 0;
    simulate_rx(overflow_data);
    printf("   Bytes in buffer: %u\n", uart_available());
    printf("   Overrun count: %u (bytes lost!)\n\n", rx_overrun_count);

    printf("   Lesson: Size your buffers for worst-case burst size.\n");
    printf("   If data loss is unacceptable, implement flow control\n");
    printf("   (hardware RTS/CTS or software XON/XOFF).\n");
}

static void demo_architecture(void)
{
    printf("\n=== Architecture: ISR ↔ Ring Buffer ↔ Main Loop ===\n\n");

    printf("  ┌──────────────┐     ┌────────────────┐     ┌─────────────┐\n");
    printf("  │   USART HW   │────▶│  RX Ring Buffer │────▶│  Main Loop  │\n");
    printf("  │   (RX IRQ)   │     │  (ISR writes)   │     │  (reads)    │\n");
    printf("  └──────────────┘     └────────────────┘     └─────────────┘\n\n");
    printf("  ┌─────────────┐     ┌────────────────┐     ┌──────────────┐\n");
    printf("  │  Main Loop  │────▶│  TX Ring Buffer │────▶│   USART HW   │\n");
    printf("  │  (writes)   │     │  (ISR reads)    │     │   (TX IRQ)   │\n");
    printf("  └─────────────┘     └────────────────┘     └──────────────┘\n\n");

    printf("  Key properties:\n");
    printf("  - Single producer, single consumer → lock-free\n");
    printf("  - ISR never blocks → fast, deterministic\n");
    printf("  - Main loop processes data at its own pace\n");
    printf("  - Buffer absorbs burst traffic\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("Interrupt-Driven UART with Ring Buffer\n");
    printf("=======================================\n\n");

    demo_interrupt_uart();
    demo_architecture();

    return 0;
}
