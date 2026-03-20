/**
 * @file    uart_irq.c
 * @brief   Interrupt-driven UART with ring buffers for non-blocking I/O.
 * @target  STM32F4xx (USART2)
 *
 * Demonstrates:
 *  - Interrupt-driven TX and RX
 *  - Ring buffer for decoupling ISR from application
 *  - Non-blocking API
 *  - Newline-delimited message reception
 *
 * Architecture:
 *
 *   Application          Ring Buffer (TX)          UART ISR
 *   ───────────          ────────────────          ────────
 *   uart_write() ──►  [put into TX ring]
 *                                              ◄── TXE interrupt
 *                                                  [get from TX ring] → DR
 *
 *   uart_read()  ◄──  [get from RX ring]
 *                                              ◄── RXNE interrupt
 *                                                  DR → [put into RX ring]
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ========================================================================== */
/*  Ring Buffer                                                                */
/* ========================================================================== */

#define RING_BUF_SIZE   256  /* Must be power of 2 */

typedef struct {
    uint8_t          buffer[RING_BUF_SIZE];
    volatile uint16_t head;  /* Write position (producer) */
    volatile uint16_t tail;  /* Read position (consumer)  */
} ring_buffer_t;

static inline void rb_init(ring_buffer_t *rb)
{
    rb->head = 0;
    rb->tail = 0;
}

static inline bool rb_is_empty(const ring_buffer_t *rb)
{
    return rb->head == rb->tail;
}

static inline bool rb_is_full(const ring_buffer_t *rb)
{
    return ((rb->head + 1) & (RING_BUF_SIZE - 1)) == rb->tail;
}

static inline uint16_t rb_count(const ring_buffer_t *rb)
{
    return (rb->head - rb->tail) & (RING_BUF_SIZE - 1);
}

static inline bool rb_put(ring_buffer_t *rb, uint8_t data)
{
    if (rb_is_full(rb)) return false;
    rb->buffer[rb->head] = data;
    rb->head = (rb->head + 1) & (RING_BUF_SIZE - 1);
    return true;
}

static inline bool rb_get(ring_buffer_t *rb, uint8_t *data)
{
    if (rb_is_empty(rb)) return false;
    *data = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) & (RING_BUF_SIZE - 1);
    return true;
}

/* ========================================================================== */
/*  Hardware Definitions                                                       */
/* ========================================================================== */

typedef struct {
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t BRR;
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t CR3;
    volatile uint32_t GTPR;
} USART_TypeDef;

#define USART2          ((USART_TypeDef *)0x40004400U)

#define USART_SR_TXE    (1U << 7)
#define USART_SR_RXNE   (1U << 5)
#define USART_SR_ORE    (1U << 3)
#define USART_CR1_UE    (1U << 13)
#define USART_CR1_TXEIE (1U << 7)   /* TXE interrupt enable  */
#define USART_CR1_RXNEIE (1U << 5)  /* RXNE interrupt enable */
#define USART_CR1_TE    (1U << 3)
#define USART_CR1_RE    (1U << 2)

/* NVIC */
#define USART2_IRQn     38
#define NVIC_ISER1      (*(volatile uint32_t *)0xE000E104)

/* ========================================================================== */
/*  Module State                                                               */
/* ========================================================================== */

static ring_buffer_t tx_ring;
static ring_buffer_t rx_ring;

static volatile uint32_t tx_count = 0;
static volatile uint32_t rx_count = 0;
static volatile uint32_t rx_overrun_count = 0;

/* ========================================================================== */
/*  Initialization                                                             */
/* ========================================================================== */

void uart_irq_init(uint32_t baud_rate)
{
    rb_init(&tx_ring);
    rb_init(&rx_ring);

    /* GPIO and clock configuration would go here (same as uart_polling.c) */

    uint32_t pclk = 42000000;
    USART2->BRR = pclk / baud_rate;

    /* Enable USART, TX, RX, and RXNE interrupt */
    USART2->CR1 = USART_CR1_UE
                | USART_CR1_TE
                | USART_CR1_RE
                | USART_CR1_RXNEIE;  /* Enable RX interrupt */
    /* TXE interrupt is only enabled when we have data to send */

    /* Enable USART2 interrupt in NVIC (IRQ 38 → ISER1 bit 6) */
    NVIC_ISER1 = (1U << (USART2_IRQn - 32));
}

/* ========================================================================== */
/*  Interrupt Service Routine                                                  */
/* ========================================================================== */

/**
 * USART2 ISR handles both TX (TXE) and RX (RXNE) interrupts.
 */
void USART2_IRQHandler(void)
{
    uint32_t sr = USART2->SR;

    /* ---- Receive: data available ---- */
    if (sr & USART_SR_RXNE) {
        uint8_t data = (uint8_t)(USART2->DR & 0xFF);

        if (!rb_put(&rx_ring, data)) {
            rx_overrun_count++;  /* Ring buffer full — data lost */
        }
        rx_count++;
    }

    /* ---- Overrun error: must read DR to clear ---- */
    if (sr & USART_SR_ORE) {
        (void)USART2->DR;
        rx_overrun_count++;
    }

    /* ---- Transmit: register empty, send next byte ---- */
    if ((sr & USART_SR_TXE) && (USART2->CR1 & USART_CR1_TXEIE)) {
        uint8_t data;
        if (rb_get(&tx_ring, &data)) {
            USART2->DR = data;
            tx_count++;
        } else {
            /* No more data — disable TXE interrupt to avoid spinning */
            USART2->CR1 &= ~USART_CR1_TXEIE;
        }
    }
}

/* ========================================================================== */
/*  Application API                                                            */
/* ========================================================================== */

/**
 * Write data to UART (non-blocking).
 *
 * @return Number of bytes actually written (may be less than length if
 *         the ring buffer is full).
 */
uint16_t uart_write(const uint8_t *data, uint16_t length)
{
    uint16_t written = 0;

    for (uint16_t i = 0; i < length; i++) {
        if (!rb_put(&tx_ring, data[i])) {
            break;  /* Ring buffer full */
        }
        written++;
    }

    /* Enable TXE interrupt to start transmission */
    if (written > 0) {
        USART2->CR1 |= USART_CR1_TXEIE;
    }

    return written;
}

/**
 * Write a null-terminated string (non-blocking).
 */
uint16_t uart_write_string(const char *str)
{
    uint16_t len = 0;
    while (str[len]) len++;
    return uart_write((const uint8_t *)str, len);
}

/**
 * Read available data from UART (non-blocking).
 *
 * @return Number of bytes actually read.
 */
uint16_t uart_read(uint8_t *data, uint16_t max_length)
{
    uint16_t count = 0;

    while (count < max_length) {
        uint8_t byte;
        if (!rb_get(&rx_ring, &byte)) {
            break;  /* No more data */
        }
        data[count++] = byte;
    }

    return count;
}

/**
 * Read a complete line (terminated by \r or \n).
 * Returns 0 if no complete line is available yet.
 */
uint16_t uart_read_line(char *buf, uint16_t max_length)
{
    uint16_t available = rb_count(&rx_ring);
    if (available == 0) return 0;

    /* Peek through the ring buffer to find a newline */
    bool found_newline = false;
    uint16_t idx = rx_ring.tail;

    for (uint16_t i = 0; i < available; i++) {
        if (rx_ring.buffer[idx] == '\r' || rx_ring.buffer[idx] == '\n') {
            found_newline = true;
            break;
        }
        idx = (idx + 1) & (RING_BUF_SIZE - 1);
    }

    if (!found_newline) return 0;

    /* Extract the line */
    uint16_t pos = 0;
    while (pos < max_length - 1) {
        uint8_t c;
        if (!rb_get(&rx_ring, &c)) break;
        if (c == '\r' || c == '\n') {
            /* Consume the other half of \r\n if present */
            if (!rb_is_empty(&rx_ring)) {
                uint8_t next = rx_ring.buffer[rx_ring.tail];
                if ((next == '\r' || next == '\n') && next != c) {
                    rb_get(&rx_ring, &next);
                }
            }
            break;
        }
        buf[pos++] = (char)c;
    }

    buf[pos] = '\0';
    return pos;
}

/**
 * Get number of bytes waiting to be read.
 */
uint16_t uart_rx_available(void)
{
    return rb_count(&rx_ring);
}

/**
 * Check if TX is complete (ring buffer empty and last byte shifted out).
 */
bool uart_tx_complete(void)
{
    return rb_is_empty(&tx_ring) && (USART2->SR & (1U << 6));
}

/**
 * Get error statistics.
 */
uint32_t uart_get_overrun_count(void)
{
    return rx_overrun_count;
}

/* ========================================================================== */
/*  Main — Example Usage                                                       */
/* ========================================================================== */

int main(void)
{
    uart_irq_init(115200);

    uart_write_string("UART IRQ driver ready.\r\n");

    char line_buf[128];

    while (1) {
        /* Non-blocking line read */
        uint16_t len = uart_read_line(line_buf, sizeof(line_buf));

        if (len > 0) {
            uart_write_string("Received: ");
            uart_write_string(line_buf);
            uart_write_string("\r\n");
        }

        /* Application can do other work here without blocking */
    }
}
