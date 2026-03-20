/**
 * @file    04_uart_ring_buffer.c
 * @brief   Interrupt-driven UART with lock-free ring buffer
 *
 * Demonstrates:
 *  - Interrupt-driven TX and RX
 *  - Lock-free single-producer single-consumer ring buffer
 *  - Non-blocking and blocking API variants
 *  - Line-buffered reception
 *  - Overflow detection
 *
 * Target: Generic ARM Cortex-M with STM32-like USART peripheral
 */

#include <stdint.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────
 * Hardware Definitions (abbreviated — see 03_uart_driver.c for full)
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t BRR;
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t CR3;
    volatile uint32_t GTPR;
} USART_TypeDef;

#define USART1  ((USART_TypeDef *)0x40011000U)

#define USART_SR_RXNE   (1U << 5)
#define USART_SR_TXE    (1U << 7)
#define USART_CR1_RXNEIE (1U << 5)
#define USART_CR1_TXEIE  (1U << 7)
#define USART_CR1_RE     (1U << 2)
#define USART_CR1_TE     (1U << 3)
#define USART_CR1_UE     (1U << 13)

/* ──────────────────────────────────────────────────────────────────────────
 * Ring Buffer (Lock-Free SPSC)
 *
 * Single-producer single-consumer queues are safe without locks when:
 *  - Only one context writes to head (producer)
 *  - Only one context writes to tail (consumer)
 *  - head and tail are accessed atomically (which they are for aligned
 *    uint16_t on ARM)
 *
 * The buffer wastes one slot to distinguish full from empty.
 * ────────────────────────────────────────────────────────────────────────── */

#define RING_SIZE_BITS   8                      /* Must be ≤ 15 */
#define RING_SIZE        (1U << RING_SIZE_BITS)  /* 256 */
#define RING_MASK        (RING_SIZE - 1)

typedef struct {
    volatile uint8_t  data[RING_SIZE];
    volatile uint16_t head;   /* Written by producer only */
    volatile uint16_t tail;   /* Written by consumer only */
    volatile uint32_t overflow_count;
} ring_t;

static inline void ring_init(ring_t *r)
{
    r->head = 0;
    r->tail = 0;
    r->overflow_count = 0;
}

static inline uint16_t ring_count(const ring_t *r)
{
    return (r->head - r->tail) & RING_MASK;
}

static inline uint16_t ring_free(const ring_t *r)
{
    return RING_SIZE - 1 - ring_count(r);
}

static inline uint8_t ring_is_empty(const ring_t *r)
{
    return r->head == r->tail;
}

static inline uint8_t ring_is_full(const ring_t *r)
{
    return ring_count(r) == (RING_SIZE - 1);
}

static inline uint8_t ring_push(ring_t *r, uint8_t byte)
{
    if (ring_is_full(r)) {
        r->overflow_count++;
        return 0;
    }
    r->data[r->head & RING_MASK] = byte;
    __asm volatile ("DMB" ::: "memory");  /* Ensure data is written before head */
    r->head = (r->head + 1) & RING_MASK;
    return 1;
}

static inline uint8_t ring_pop(ring_t *r, uint8_t *byte)
{
    if (ring_is_empty(r)) return 0;
    *byte = r->data[r->tail & RING_MASK];
    __asm volatile ("DMB" ::: "memory");
    r->tail = (r->tail + 1) & RING_MASK;
    return 1;
}

static inline uint8_t ring_peek(const ring_t *r, uint8_t *byte)
{
    if (ring_is_empty(r)) return 0;
    *byte = r->data[r->tail & RING_MASK];
    return 1;
}

/* ──────────────────────────────────────────────────────────────────────────
 * Interrupt-Driven UART Handle
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    USART_TypeDef *hw;
    ring_t         rx_ring;
    ring_t         tx_ring;
    volatile uint8_t  rx_line_ready;   /* Flag: '\n' received */
    volatile uint32_t rx_errors;       /* Count of framing/overrun errors */
} uart_handle_t;

static uart_handle_t uart1_handle;

void uart_irq_init(uart_handle_t *h, USART_TypeDef *hw, uint32_t baud,
                   uint32_t pclk)
{
    h->hw = hw;
    ring_init(&h->rx_ring);
    ring_init(&h->tx_ring);
    h->rx_line_ready = 0;
    h->rx_errors = 0;

    hw->CR1 = 0;
    hw->BRR = (pclk + baud / 2) / baud;
    hw->CR1 = USART_CR1_RE | USART_CR1_TE
            | USART_CR1_RXNEIE    /* Enable RX interrupt */
            | USART_CR1_UE;       /* Enable USART */

    /* Note: TX interrupt is enabled on-demand when data is available */
}

/* ──────────────────────────────────────────────────────────────────────────
 * ISR — handles both RX and TX in one handler
 * ────────────────────────────────────────────────────────────────────────── */

void USART1_IRQHandler(void)
{
    uart_handle_t *h = &uart1_handle;
    uint32_t sr = h->hw->SR;

    /* ── Receive ──────────────────────────── */
    if (sr & USART_SR_RXNE) {
        uint8_t byte = (uint8_t)(h->hw->DR & 0xFF);

        ring_push(&h->rx_ring, byte);

        if (byte == '\n' || byte == '\r') {
            h->rx_line_ready = 1;
        }
    }

    /* ── Overrun / framing errors ─────────── */
    if (sr & ((1U << 3) | (1U << 1))) {
        (void)h->hw->DR;   /* Clear error by reading DR */
        h->rx_errors++;
    }

    /* ── Transmit ─────────────────────────── */
    if ((sr & USART_SR_TXE) && (h->hw->CR1 & USART_CR1_TXEIE)) {
        uint8_t byte;
        if (ring_pop(&h->tx_ring, &byte)) {
            h->hw->DR = byte;
        } else {
            h->hw->CR1 &= ~USART_CR1_TXEIE;  /* Nothing to send → disable */
        }
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Public API
 * ────────────────────────────────────────────────────────────────────────── */

/* Non-blocking receive: returns number of bytes read */
uint16_t uart_read(uart_handle_t *h, uint8_t *buf, uint16_t max_len)
{
    uint16_t count = 0;
    while (count < max_len) {
        if (!ring_pop(&h->rx_ring, &buf[count])) break;
        count++;
    }
    return count;
}

/* Blocking receive: waits until 'len' bytes are available */
void uart_read_blocking(uart_handle_t *h, uint8_t *buf, uint16_t len)
{
    for (uint16_t i = 0; i < len; i++) {
        while (ring_is_empty(&h->rx_ring));  /* Spin */
        ring_pop(&h->rx_ring, &buf[i]);
    }
}

/* Read a full line (up to '\n' or '\r'). Returns length, 0 if no line. */
uint16_t uart_read_line(uart_handle_t *h, char *buf, uint16_t max_len)
{
    if (!h->rx_line_ready) return 0;

    uint16_t i = 0;
    uint8_t byte;

    while (i < max_len - 1 && ring_pop(&h->rx_ring, &byte)) {
        if (byte == '\n' || byte == '\r') {
            /* Consume trailing \n after \r (or vice versa) */
            uint8_t next;
            if (ring_peek(&h->rx_ring, &next)) {
                if (next == '\n' || next == '\r') {
                    ring_pop(&h->rx_ring, &next);
                }
            }
            break;
        }
        buf[i++] = (char)byte;
    }

    buf[i] = '\0';

    /* Check if another line is already buffered */
    h->rx_line_ready = 0;
    uint16_t scan = h->rx_ring.tail;
    while (scan != h->rx_ring.head) {
        if (h->rx_ring.data[scan] == '\n' || h->rx_ring.data[scan] == '\r') {
            h->rx_line_ready = 1;
            break;
        }
        scan = (scan + 1) & RING_MASK;
    }

    return i;
}

/* Non-blocking transmit: queues data and starts TX interrupt */
uint16_t uart_write(uart_handle_t *h, const uint8_t *buf, uint16_t len)
{
    uint16_t queued = 0;
    for (uint16_t i = 0; i < len; i++) {
        if (!ring_push(&h->tx_ring, buf[i])) break;
        queued++;
    }

    if (queued > 0) {
        h->hw->CR1 |= USART_CR1_TXEIE;   /* Enable TX interrupt */
    }

    return queued;
}

/* Blocking transmit: waits until all bytes are queued */
void uart_write_blocking(uart_handle_t *h, const uint8_t *buf, uint16_t len)
{
    for (uint16_t i = 0; i < len; i++) {
        while (ring_is_full(&h->tx_ring));  /* Spin until space */
        ring_push(&h->tx_ring, buf[i]);
    }
    h->hw->CR1 |= USART_CR1_TXEIE;
}

void uart_write_string(uart_handle_t *h, const char *str)
{
    uart_write_blocking(h, (const uint8_t *)str, (uint16_t)strlen(str));
}

/* Flush: wait until TX ring is fully drained */
void uart_flush_tx(uart_handle_t *h)
{
    while (!ring_is_empty(&h->tx_ring));
}

uint16_t uart_rx_available(const uart_handle_t *h)
{
    return ring_count(&h->rx_ring);
}

uint16_t uart_tx_free(const uart_handle_t *h)
{
    return ring_free(&h->tx_ring);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: Echo with Line Processing
 * ────────────────────────────────────────────────────────────────────────── */

int main(void)
{
    uart_irq_init(&uart1_handle, USART1, 115200, 72000000U);

    uart_write_string(&uart1_handle,
        "\r\n=== UART Ring Buffer Demo ===\r\n"
        "Type a line and press Enter.\r\n\r\n");

    char line[128];

    while (1) {
        uint16_t len = uart_read_line(&uart1_handle, line, sizeof(line));

        if (len > 0) {
            uart_write_string(&uart1_handle, "Echo: ");
            uart_write_blocking(&uart1_handle, (const uint8_t *)line, len);
            uart_write_string(&uart1_handle, "\r\n");

            /* Report buffer statistics */
            char stats[80];
            snprintf(stats, sizeof(stats),
                     "[RX buf: %u/%u, TX buf: %u/%u, errors: %lu]\r\n",
                     ring_count(&uart1_handle.rx_ring), RING_SIZE - 1,
                     ring_count(&uart1_handle.tx_ring), RING_SIZE - 1,
                     (unsigned long)uart1_handle.rx_errors);
            uart_write_string(&uart1_handle, stats);
        }
    }

    return 0;
}
