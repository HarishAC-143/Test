/**
 * Ring Buffer (Circular Buffer) — Header-Only Library
 *
 * A fixed-size, interrupt-safe, single-producer / single-consumer
 * circular buffer suitable for buffering UART data, sensor samples,
 * or any byte stream in embedded systems.
 *
 * Thread/ISR safety:
 *   - Safe without locks when there is exactly ONE writer (producer)
 *     and ONE reader (consumer), because head and tail are only
 *     modified by their respective side.
 *   - head and tail are volatile to prevent compiler reordering.
 *
 * Memory:
 *   - Uses a power-of-two size for fast modulo via bitmask.
 *   - No dynamic allocation.
 */

#ifndef RING_BUFFER_H
#define RING_BUFFER_H

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/**
 * Buffer size MUST be a power of two (32, 64, 128, 256, etc.).
 * Adjust to your needs and available RAM.
 */
#ifndef RING_BUF_SIZE
#define RING_BUF_SIZE  256
#endif

/* Compile-time check: size must be a power of two */
_Static_assert((RING_BUF_SIZE & (RING_BUF_SIZE - 1)) == 0,
               "RING_BUF_SIZE must be a power of two");

typedef struct {
    uint8_t          data[RING_BUF_SIZE];
    volatile uint32_t head;   /* Next write position (modified by producer) */
    volatile uint32_t tail;   /* Next read position  (modified by consumer) */
} ring_buf_t;

/* ───────── Initialization ───────── */

static inline void ring_buf_init(ring_buf_t *rb)
{
    rb->head = 0;
    rb->tail = 0;
    memset(rb->data, 0, RING_BUF_SIZE);
}

/* ───────── Status Queries ───────── */

static inline bool ring_buf_is_empty(const ring_buf_t *rb)
{
    return rb->head == rb->tail;
}

static inline bool ring_buf_is_full(const ring_buf_t *rb)
{
    return ((rb->head + 1) & (RING_BUF_SIZE - 1)) == rb->tail;
}

static inline uint32_t ring_buf_count(const ring_buf_t *rb)
{
    return (rb->head - rb->tail) & (RING_BUF_SIZE - 1);
}

static inline uint32_t ring_buf_free(const ring_buf_t *rb)
{
    return (RING_BUF_SIZE - 1) - ring_buf_count(rb);
}

/* ───────── Single-Byte Operations ───────── */

/**
 * Push one byte into the buffer.
 * Returns true on success, false if the buffer is full.
 */
static inline bool ring_buf_put(ring_buf_t *rb, uint8_t byte)
{
    if (ring_buf_is_full(rb)) {
        return false;
    }

    rb->data[rb->head] = byte;
    rb->head = (rb->head + 1) & (RING_BUF_SIZE - 1);
    return true;
}

/**
 * Pop one byte from the buffer.
 * Returns true on success (byte stored in *out), false if empty.
 */
static inline bool ring_buf_get(ring_buf_t *rb, uint8_t *out)
{
    if (ring_buf_is_empty(rb)) {
        return false;
    }

    *out = rb->data[rb->tail];
    rb->tail = (rb->tail + 1) & (RING_BUF_SIZE - 1);
    return true;
}

/**
 * Peek at the next byte without removing it.
 */
static inline bool ring_buf_peek(const ring_buf_t *rb, uint8_t *out)
{
    if (ring_buf_is_empty(rb)) {
        return false;
    }

    *out = rb->data[rb->tail];
    return true;
}

/* ───────── Multi-Byte Operations ───────── */

/**
 * Write multiple bytes into the buffer.
 * Returns the number of bytes actually written (may be less than len if full).
 */
static inline uint32_t ring_buf_write(ring_buf_t *rb, const uint8_t *src, uint32_t len)
{
    uint32_t written = 0;
    while (written < len && !ring_buf_is_full(rb)) {
        rb->data[rb->head] = src[written++];
        rb->head = (rb->head + 1) & (RING_BUF_SIZE - 1);
    }
    return written;
}

/**
 * Read multiple bytes from the buffer.
 * Returns the number of bytes actually read (may be less than len if not enough data).
 */
static inline uint32_t ring_buf_read(ring_buf_t *rb, uint8_t *dst, uint32_t len)
{
    uint32_t read_count = 0;
    while (read_count < len && !ring_buf_is_empty(rb)) {
        dst[read_count++] = rb->data[rb->tail];
        rb->tail = (rb->tail + 1) & (RING_BUF_SIZE - 1);
    }
    return read_count;
}

/**
 * Flush (discard) all data in the buffer.
 */
static inline void ring_buf_flush(ring_buf_t *rb)
{
    rb->tail = rb->head;
}

#endif /* RING_BUFFER_H */
