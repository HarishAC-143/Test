/**
 * @file    ring_buffer.h
 * @brief   Generic ring buffer (circular buffer) for embedded systems.
 *
 * Features:
 *  - Lock-free for single-producer/single-consumer (ISR ↔ main loop)
 *  - Power-of-2 size for fast modulo via bitmask
 *  - Configurable element size (bytes, uint16_t, structs)
 *  - Peek without consume
 *  - Bulk read/write
 */

#ifndef RING_BUFFER_H
#define RING_BUFFER_H

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* Buffer size MUST be a power of 2 */
#ifndef RING_BUF_CAPACITY
#define RING_BUF_CAPACITY   256
#endif

_Static_assert((RING_BUF_CAPACITY & (RING_BUF_CAPACITY - 1)) == 0,
               "RING_BUF_CAPACITY must be a power of 2");

typedef struct {
    uint8_t  data[RING_BUF_CAPACITY];
    volatile uint16_t head;  /* Next write position (producer modifies) */
    volatile uint16_t tail;  /* Next read position  (consumer modifies) */
} ring_buffer_t;

/* ---- Initialization ---- */

static inline void ring_buf_init(ring_buffer_t *rb)
{
    rb->head = 0;
    rb->tail = 0;
}

/* ---- Status ---- */

static inline bool ring_buf_is_empty(const ring_buffer_t *rb)
{
    return rb->head == rb->tail;
}

static inline bool ring_buf_is_full(const ring_buffer_t *rb)
{
    return ((rb->head + 1) & (RING_BUF_CAPACITY - 1)) == rb->tail;
}

static inline uint16_t ring_buf_count(const ring_buffer_t *rb)
{
    return (rb->head - rb->tail) & (RING_BUF_CAPACITY - 1);
}

static inline uint16_t ring_buf_free_space(const ring_buffer_t *rb)
{
    return (RING_BUF_CAPACITY - 1) - ring_buf_count(rb);
}

/* ---- Single-Element Operations ---- */

static inline bool ring_buf_put(ring_buffer_t *rb, uint8_t byte)
{
    if (ring_buf_is_full(rb)) return false;
    rb->data[rb->head] = byte;
    rb->head = (rb->head + 1) & (RING_BUF_CAPACITY - 1);
    return true;
}

static inline bool ring_buf_get(ring_buffer_t *rb, uint8_t *byte)
{
    if (ring_buf_is_empty(rb)) return false;
    *byte = rb->data[rb->tail];
    rb->tail = (rb->tail + 1) & (RING_BUF_CAPACITY - 1);
    return true;
}

/**
 * Read without consuming (look at next byte without removing it).
 */
static inline bool ring_buf_peek(const ring_buffer_t *rb, uint8_t *byte)
{
    if (ring_buf_is_empty(rb)) return false;
    *byte = rb->data[rb->tail];
    return true;
}

/* ---- Bulk Operations ---- */

/**
 * Write multiple bytes. Returns number of bytes actually written.
 */
static inline uint16_t ring_buf_write(ring_buffer_t *rb,
                                       const uint8_t *data, uint16_t len)
{
    uint16_t written = 0;
    while (written < len && !ring_buf_is_full(rb)) {
        rb->data[rb->head] = data[written++];
        rb->head = (rb->head + 1) & (RING_BUF_CAPACITY - 1);
    }
    return written;
}

/**
 * Read multiple bytes. Returns number of bytes actually read.
 */
static inline uint16_t ring_buf_read(ring_buffer_t *rb,
                                      uint8_t *data, uint16_t max_len)
{
    uint16_t count = 0;
    while (count < max_len && !ring_buf_is_empty(rb)) {
        data[count++] = rb->data[rb->tail];
        rb->tail = (rb->tail + 1) & (RING_BUF_CAPACITY - 1);
    }
    return count;
}

/**
 * Discard all data in the buffer.
 */
static inline void ring_buf_flush(ring_buffer_t *rb)
{
    rb->tail = rb->head;
}

/**
 * Discard N bytes from the read end.
 */
static inline void ring_buf_skip(ring_buffer_t *rb, uint16_t count)
{
    uint16_t available = ring_buf_count(rb);
    if (count > available) count = available;
    rb->tail = (rb->tail + count) & (RING_BUF_CAPACITY - 1);
}

#endif /* RING_BUFFER_H */
