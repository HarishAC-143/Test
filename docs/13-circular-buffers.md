# Chapter 13: Circular Buffers

A circular buffer (also called a ring buffer) is a fixed-size FIFO (first-in, first-out) data structure that wraps around. It is the backbone of interrupt-driven I/O in embedded systems — every UART driver, audio buffer, and sensor pipeline uses one.

## Why Circular Buffers?

In embedded systems, data is often produced and consumed at different rates:

- A UART ISR receives bytes faster than the main loop processes them
- An ADC samples data faster than a communication link can transmit it
- Audio samples must be buffered between the codec interrupt and the processing routine

A circular buffer solves this by decoupling the **producer** (typically an ISR) from the **consumer** (the main loop or another task):

```
Producer (ISR) ──▶ [Ring Buffer] ──▶ Consumer (Main Loop)
```

## How It Works

The buffer uses two indices:

- **head** (write index): where new data is written
- **tail** (read index): where data is read from

```
                    tail          head
                     │             │
                     ▼             ▼
Buffer: [ _ ][ _ ][ A ][ B ][ C ][ _ ][ _ ][ _ ]
                    ▲                         ▲
                    oldest                    next write position
```

When either index reaches the end of the array, it wraps around to the beginning — hence "circular."

## Implementation: Byte-Oriented Ring Buffer

```c
#include <stdint.h>
#include <stdbool.h>

#define RING_BUF_SIZE 256  /* Must be a power of 2 for optimization */

typedef struct {
    uint8_t  buffer[RING_BUF_SIZE];
    volatile uint16_t head;  /* Write index (modified by producer) */
    volatile uint16_t tail;  /* Read index (modified by consumer) */
} RingBuffer;

void ringbuf_init(RingBuffer *rb)
{
    rb->head = 0;
    rb->tail = 0;
}

bool ringbuf_is_empty(const RingBuffer *rb)
{
    return rb->head == rb->tail;
}

bool ringbuf_is_full(const RingBuffer *rb)
{
    return ((rb->head + 1) % RING_BUF_SIZE) == rb->tail;
}

uint16_t ringbuf_count(const RingBuffer *rb)
{
    return (rb->head - rb->tail + RING_BUF_SIZE) % RING_BUF_SIZE;
}

uint16_t ringbuf_free_space(const RingBuffer *rb)
{
    return RING_BUF_SIZE - 1 - ringbuf_count(rb);
}

bool ringbuf_put(RingBuffer *rb, uint8_t byte)
{
    if (ringbuf_is_full(rb))
        return false;

    rb->buffer[rb->head] = byte;
    rb->head = (rb->head + 1) % RING_BUF_SIZE;
    return true;
}

bool ringbuf_get(RingBuffer *rb, uint8_t *byte)
{
    if (ringbuf_is_empty(rb))
        return false;

    *byte = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) % RING_BUF_SIZE;
    return true;
}

/* Peek without removing */
bool ringbuf_peek(const RingBuffer *rb, uint8_t *byte)
{
    if (ringbuf_is_empty(rb))
        return false;

    *byte = rb->buffer[rb->tail];
    return true;
}

void ringbuf_flush(RingBuffer *rb)
{
    rb->tail = rb->head;
}
```

### Power-of-Two Optimization

When the buffer size is a power of two, the modulo operation can be replaced with a bitmask — much faster on MCUs without a hardware divider:

```c
#define RING_BUF_SIZE 256
#define RING_BUF_MASK (RING_BUF_SIZE - 1)

/* Instead of: (index + 1) % RING_BUF_SIZE */
/* Use:        (index + 1) & RING_BUF_MASK  */

bool ringbuf_put(RingBuffer *rb, uint8_t byte)
{
    uint16_t next_head = (rb->head + 1) & RING_BUF_MASK;
    if (next_head == rb->tail)
        return false;

    rb->buffer[rb->head] = byte;
    rb->head = next_head;
    return true;
}
```

## Lock-Free Safety: Single Producer, Single Consumer

The implementation above is inherently **lock-free** when:

- Only **one** producer writes to `head` (e.g., the UART RX ISR)
- Only **one** consumer reads from `tail` (e.g., the main loop)
- `head` and `tail` are `volatile`
- Read and write of `head`/`tail` are atomic on the platform (which they are for 16-bit values on ARM Cortex-M)

No critical sections or interrupt disabling needed! This is why ring buffers are the standard pattern for ISR-to-main communication.

## Usage: UART Driver

```c
static RingBuffer uart_rx_buf;
static RingBuffer uart_tx_buf;

void USART1_IRQHandler(void)
{
    /* Receive interrupt */
    if (USART1->SR & (1U << 5)) {
        uint8_t byte = (uint8_t)USART1->DR;
        ringbuf_put(&uart_rx_buf, byte);  /* ISR is the producer */
    }

    /* Transmit interrupt */
    if (USART1->SR & (1U << 7)) {
        uint8_t byte;
        if (ringbuf_get(&uart_tx_buf, &byte)) {
            USART1->DR = byte;
        } else {
            USART1->CR1 &= ~(1U << 7);  /* Disable TXE interrupt */
        }
    }
}

void uart_write(const uint8_t *data, uint16_t len)
{
    for (uint16_t i = 0; i < len; i++) {
        while (ringbuf_is_full(&uart_tx_buf))
            ;  /* Wait for space */
        ringbuf_put(&uart_tx_buf, data[i]);
    }
    USART1->CR1 |= (1U << 7);  /* Enable TXE interrupt to start sending */
}

int16_t uart_read_byte(void)
{
    uint8_t byte;
    if (ringbuf_get(&uart_rx_buf, &byte))
        return byte;
    return -1;
}
```

## Generic Ring Buffer (Any Element Type)

For non-byte data (e.g., sensor readings, events), use a generic approach:

```c
#define GENERIC_RINGBUF_DEF(name, type, size)          \
    typedef struct {                                    \
        type buffer[size];                              \
        volatile uint16_t head;                         \
        volatile uint16_t tail;                         \
    } name##_RingBuffer;                                \
                                                        \
    static inline bool name##_put(name##_RingBuffer *rb, type item) { \
        uint16_t next = (rb->head + 1) % (size);       \
        if (next == rb->tail) return false;             \
        rb->buffer[rb->head] = item;                    \
        rb->head = next;                                \
        return true;                                    \
    }                                                   \
                                                        \
    static inline bool name##_get(name##_RingBuffer *rb, type *item) { \
        if (rb->head == rb->tail) return false;         \
        *item = rb->buffer[rb->tail];                   \
        rb->tail = (rb->tail + 1) % (size);             \
        return true;                                    \
    }

/* Usage: */
typedef struct {
    uint16_t channel;
    uint16_t value;
    uint32_t timestamp;
} ADC_Sample;

GENERIC_RINGBUF_DEF(adc, ADC_Sample, 32)

adc_RingBuffer adc_buffer = { .head = 0, .tail = 0 };

/* In ADC ISR: */
ADC_Sample sample = { .channel = 0, .value = ADC1->DR, .timestamp = ms_ticks };
adc_put(&adc_buffer, sample);

/* In main loop: */
ADC_Sample s;
if (adc_get(&adc_buffer, &s)) {
    process_sample(&s);
}
```

## Block Operations

For efficiency, add bulk read/write operations:

```c
uint16_t ringbuf_write(RingBuffer *rb, const uint8_t *data, uint16_t len)
{
    uint16_t written = 0;
    while (written < len && !ringbuf_is_full(rb)) {
        rb->buffer[rb->head] = data[written++];
        rb->head = (rb->head + 1) & RING_BUF_MASK;
    }
    return written;
}

uint16_t ringbuf_read(RingBuffer *rb, uint8_t *data, uint16_t max_len)
{
    uint16_t read_count = 0;
    while (read_count < max_len && !ringbuf_is_empty(rb)) {
        data[read_count++] = rb->buffer[rb->tail];
        rb->tail = (rb->tail + 1) & RING_BUF_MASK;
    }
    return read_count;
}
```

## Common Pitfalls

### 1. Non-Power-of-Two Size

Using modulo with a non-power-of-two size is correct but slow. Prefer sizes like 32, 64, 128, 256, 512, 1024.

### 2. Lost Capacity

A ring buffer of size N can only hold N-1 elements, because one slot must remain empty to distinguish full from empty. If you need exactly 256 bytes, allocate 257.

### 3. Multiple Producers or Consumers

The lock-free guarantee only holds for single-producer/single-consumer. Multiple producers require a mutex or interrupt disabling.

## Practical Example

See [`examples/08_circular_buffer/ring_buffer.c`](../examples/08_circular_buffer/ring_buffer.c) for a complete, tested implementation.

## Summary

- Circular buffers are the standard pattern for ISR-to-main data transfer.
- Single-producer, single-consumer ring buffers are inherently lock-free.
- Use power-of-two sizes for efficient bitmask-based wrapping.
- The buffer holds at most `size - 1` elements.
- Generic macros let you create typed ring buffers for any data structure.

---

**Next:** [Chapter 14 — RTOS Fundamentals](14-rtos-fundamentals.md)
