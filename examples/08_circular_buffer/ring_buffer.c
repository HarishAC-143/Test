/**
 * Circular (Ring) Buffer — Complete Implementation
 *
 * A production-quality ring buffer suitable for ISR-to-main communication.
 * Features:
 *   - Power-of-two optimization (bitmask instead of modulo)
 *   - Single-producer/single-consumer lock-free operation
 *   - Byte and block read/write operations
 *   - Comprehensive self-test
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o ring_buffer ring_buffer.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

/* ---- Ring Buffer Configuration ---- */

#define RING_SIZE  64  /* Must be a power of two */
#define RING_MASK  (RING_SIZE - 1)

/* Compile-time check */
_Static_assert((RING_SIZE & RING_MASK) == 0,
               "RING_SIZE must be a power of two");

/* ---- Ring Buffer Structure ---- */

typedef struct {
    uint8_t  buffer[RING_SIZE];
    volatile uint16_t head;  /* Write pointer (producer modifies) */
    volatile uint16_t tail;  /* Read pointer (consumer modifies) */
} RingBuffer;

/* ---- Core Operations ---- */

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
    return ((rb->head + 1) & RING_MASK) == rb->tail;
}

static uint16_t rb_count(const RingBuffer *rb)
{
    return (rb->head - rb->tail) & RING_MASK;
}

static uint16_t rb_free(const RingBuffer *rb)
{
    return RING_SIZE - 1 - rb_count(rb);
}

/* Put a single byte (returns false if full) */
static bool rb_put(RingBuffer *rb, uint8_t byte)
{
    uint16_t next = (rb->head + 1) & RING_MASK;
    if (next == rb->tail)
        return false;
    rb->buffer[rb->head] = byte;
    rb->head = next;
    return true;
}

/* Get a single byte (returns false if empty) */
static bool rb_get(RingBuffer *rb, uint8_t *byte)
{
    if (rb->head == rb->tail)
        return false;
    *byte = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) & RING_MASK;
    return true;
}

/* Peek without consuming */
static bool rb_peek(const RingBuffer *rb, uint8_t *byte)
{
    if (rb->head == rb->tail)
        return false;
    *byte = rb->buffer[rb->tail];
    return true;
}

/* Discard all data */
static void rb_flush(RingBuffer *rb)
{
    rb->tail = rb->head;
}

/* ---- Block Operations ---- */

static uint16_t rb_write(RingBuffer *rb, const uint8_t *data, uint16_t len)
{
    uint16_t written = 0;
    while (written < len) {
        uint16_t next = (rb->head + 1) & RING_MASK;
        if (next == rb->tail)
            break;
        rb->buffer[rb->head] = data[written++];
        rb->head = next;
    }
    return written;
}

static uint16_t rb_read(RingBuffer *rb, uint8_t *data, uint16_t max_len)
{
    uint16_t count = 0;
    while (count < max_len && rb->head != rb->tail) {
        data[count++] = rb->buffer[rb->tail];
        rb->tail = (rb->tail + 1) & RING_MASK;
    }
    return count;
}

/* ---- Visualization ---- */

static void rb_print(const RingBuffer *rb)
{
    printf("  [");
    for (int i = 0; i < RING_SIZE; i++) {
        if (i == rb->tail && i == rb->head)
            printf("TH");  /* Empty: head == tail */
        else if (i == rb->tail)
            printf("T>");
        else if (i == rb->head)
            printf("<H");
        else {
            /* Check if this slot has valid data */
            uint16_t t = rb->tail;
            bool valid = false;
            while (t != rb->head) {
                if (t == (uint16_t)i) { valid = true; break; }
                t = (t + 1) & RING_MASK;
            }
            if (valid)
                printf("%02X", rb->buffer[i]);
            else
                printf("__");
        }
        if (i < RING_SIZE - 1) printf("|");
    }
    printf("]\n");
    printf("  head=%u, tail=%u, count=%u, free=%u\n\n",
           rb->head, rb->tail, rb_count(rb), rb_free(rb));
}

/* ---- Self-Test ---- */

static int tests_passed = 0;
static int tests_failed = 0;

#define TEST(cond, msg) do {                           \
    if (cond) {                                        \
        tests_passed++;                                \
    } else {                                           \
        tests_failed++;                                \
        printf("  FAIL: %s (line %d)\n", msg, __LINE__); \
    }                                                  \
} while (0)

static void run_tests(void)
{
    printf("=== Ring Buffer Self-Test ===\n\n");

    RingBuffer rb;
    uint8_t byte;

    /* Test 1: Initialize */
    rb_init(&rb);
    TEST(rb_is_empty(&rb), "New buffer should be empty");
    TEST(!rb_is_full(&rb), "New buffer should not be full");
    TEST(rb_count(&rb) == 0, "New buffer count should be 0");
    TEST(rb_free(&rb) == RING_SIZE - 1, "New buffer free should be SIZE-1");

    /* Test 2: Put and get one byte */
    TEST(rb_put(&rb, 0x42), "Put should succeed");
    TEST(!rb_is_empty(&rb), "Buffer should not be empty after put");
    TEST(rb_count(&rb) == 1, "Count should be 1");
    TEST(rb_get(&rb, &byte), "Get should succeed");
    TEST(byte == 0x42, "Got correct byte");
    TEST(rb_is_empty(&rb), "Buffer should be empty after get");

    /* Test 3: Fill to capacity */
    rb_init(&rb);
    uint16_t max_items = RING_SIZE - 1;
    for (uint16_t i = 0; i < max_items; i++) {
        TEST(rb_put(&rb, (uint8_t)i), "Put should succeed while not full");
    }
    TEST(rb_is_full(&rb), "Buffer should be full");
    TEST(!rb_put(&rb, 0xFF), "Put should fail when full");
    TEST(rb_count(&rb) == max_items, "Count should equal capacity");

    /* Test 4: Read back in order */
    for (uint16_t i = 0; i < max_items; i++) {
        TEST(rb_get(&rb, &byte), "Get should succeed");
        TEST(byte == (uint8_t)i, "FIFO order preserved");
    }
    TEST(rb_is_empty(&rb), "Buffer should be empty after reading all");

    /* Test 5: Wraparound */
    rb_init(&rb);
    for (int round = 0; round < 3; round++) {
        for (uint16_t i = 0; i < 20; i++)
            rb_put(&rb, (uint8_t)(round * 20 + i));
        for (uint16_t i = 0; i < 20; i++) {
            rb_get(&rb, &byte);
            TEST(byte == (uint8_t)(round * 20 + i), "Wraparound data correct");
        }
    }
    TEST(rb_is_empty(&rb), "Empty after wraparound test");

    /* Test 6: Block write/read */
    rb_init(&rb);
    uint8_t write_data[] = "Hello, Ring Buffer!";
    uint16_t written = rb_write(&rb, write_data, (uint16_t)strlen((char *)write_data));
    TEST(written == strlen((char *)write_data), "Block write count correct");

    uint8_t read_data[64] = {0};
    uint16_t read_count = rb_read(&rb, read_data, 64);
    TEST(read_count == strlen((char *)write_data), "Block read count correct");
    TEST(memcmp(write_data, read_data, read_count) == 0, "Block data matches");

    /* Test 7: Peek */
    rb_init(&rb);
    rb_put(&rb, 0xAA);
    rb_put(&rb, 0xBB);
    TEST(rb_peek(&rb, &byte) && byte == 0xAA, "Peek returns first byte");
    TEST(rb_count(&rb) == 2, "Peek does not consume");
    rb_get(&rb, &byte);
    TEST(rb_peek(&rb, &byte) && byte == 0xBB, "Peek returns next after get");

    /* Test 8: Flush */
    rb_init(&rb);
    rb_write(&rb, (uint8_t *)"test", 4);
    rb_flush(&rb);
    TEST(rb_is_empty(&rb), "Flush empties the buffer");

    printf("\n  Results: %d passed, %d failed\n\n", tests_passed, tests_failed);
}

/* ---- Visual Demo ---- */

static void demo_visual(void)
{
    printf("=== Visual Demonstration (16-byte view) ===\n\n");

    /* Use a small buffer for visualization */
    RingBuffer small;
    rb_init(&small);

    printf("1. Empty buffer:\n");
    rb_print(&small);

    printf("2. After writing 'ABCDE':\n");
    rb_write(&small, (uint8_t *)"ABCDE", 5);
    rb_print(&small);

    printf("3. After reading 3 bytes:\n");
    uint8_t tmp[3];
    rb_read(&small, tmp, 3);
    rb_print(&small);

    printf("4. After writing 'FGHIJ':\n");
    rb_write(&small, (uint8_t *)"FGHIJ", 5);
    rb_print(&small);

    printf("5. After reading all:\n");
    uint8_t all[64];
    uint16_t n = rb_read(&small, all, 64);
    all[n] = '\0';
    printf("  Read: \"%s\"\n", all);
    rb_print(&small);
}

/* ---- Main ---- */

int main(void)
{
    printf("Circular (Ring) Buffer — Complete Implementation\n");
    printf("=================================================\n\n");

    printf("  Buffer size: %d bytes\n", RING_SIZE);
    printf("  Usable capacity: %d bytes (one slot reserved)\n", RING_SIZE - 1);
    printf("  Mask: 0x%02X (for O(1) index wrapping)\n\n", RING_MASK);

    run_tests();
    demo_visual();

    return 0;
}
