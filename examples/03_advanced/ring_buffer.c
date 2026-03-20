/**
 * Lock-Free Ring Buffer Implementation
 *
 * A production-quality circular buffer suitable for ISR-to-main-loop
 * communication, with multiple variants for different use cases.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ================================================================
 * VARIANT 1: Byte Ring Buffer (power-of-2 size, masking)
 *
 * Most common variant for UART RX/TX buffers.
 * Size must be a power of 2 for the bitwise AND masking trick.
 * ================================================================ */

#define RING1_SIZE 16  /* Must be power of 2 */
#define RING1_MASK (RING1_SIZE - 1)

typedef struct {
    volatile uint8_t  buffer[RING1_SIZE];
    volatile uint16_t head;  /* Write position (modified by producer/ISR) */
    volatile uint16_t tail;  /* Read position (modified by consumer/main) */
} ByteRingBuffer;

static void byte_rb_init(ByteRingBuffer *rb) {
    rb->head = 0;
    rb->tail = 0;
}

static bool byte_rb_put(ByteRingBuffer *rb, uint8_t data) {
    uint16_t next = (rb->head + 1) & RING1_MASK;
    if (next == rb->tail) return false;  /* Full */
    rb->buffer[rb->head] = data;
    rb->head = next;
    return true;
}

static bool byte_rb_get(ByteRingBuffer *rb, uint8_t *data) {
    if (rb->head == rb->tail) return false;  /* Empty */
    *data = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) & RING1_MASK;
    return true;
}

static uint16_t byte_rb_count(const ByteRingBuffer *rb) {
    return (rb->head - rb->tail) & RING1_MASK;
}

static uint16_t byte_rb_free(const ByteRingBuffer *rb) {
    return (RING1_SIZE - 1) - byte_rb_count(rb);
}

static bool byte_rb_empty(const ByteRingBuffer *rb) {
    return rb->head == rb->tail;
}

static bool byte_rb_full(const ByteRingBuffer *rb) {
    return ((rb->head + 1) & RING1_MASK) == rb->tail;
}

static void demo_byte_ring_buffer(void) {
    printf("=== Variant 1: Byte Ring Buffer ===\n\n");

    ByteRingBuffer rb;
    byte_rb_init(&rb);

    printf("  Size: %d, usable: %d (one slot reserved for full detection)\n\n",
           RING1_SIZE, RING1_SIZE - 1);

    /* Fill the buffer */
    printf("  Writing 'A' through 'O' (15 bytes):\n  ");
    for (char c = 'A'; c <= 'O'; c++) {
        if (byte_rb_put(&rb, (uint8_t)c)) {
            printf("%c", c);
        } else {
            printf("!(FULL at %c)", c);
            break;
        }
    }
    printf("\n  Count: %u, Free: %u, Full: %s\n\n",
           byte_rb_count(&rb), byte_rb_free(&rb),
           byte_rb_full(&rb) ? "Yes" : "No");

    /* Try to write when full */
    bool ok = byte_rb_put(&rb, 'X');
    printf("  Write when full: %s\n\n", ok ? "OK" : "REJECTED (correct!)");

    /* Read some bytes */
    printf("  Reading 5 bytes: ");
    for (int i = 0; i < 5; i++) {
        uint8_t data;
        if (byte_rb_get(&rb, &data)) {
            printf("%c ", data);
        }
    }
    printf("\n  Count: %u, Free: %u\n\n", byte_rb_count(&rb), byte_rb_free(&rb));

    /* Write more (wrapping around) */
    printf("  Writing 'P', 'Q', 'R' (wraps around physical buffer):\n  ");
    for (char c = 'P'; c <= 'R'; c++) {
        byte_rb_put(&rb, (uint8_t)c);
        printf("%c ", c);
    }
    printf("\n  Head: %u, Tail: %u (indices show wrap-around)\n\n",
           rb.head, rb.tail);

    /* Drain all */
    printf("  Draining all: ");
    uint8_t data;
    while (byte_rb_get(&rb, &data)) {
        printf("%c ", data);
    }
    printf("\n  Empty: %s\n\n", byte_rb_empty(&rb) ? "Yes" : "No");
}

/* ================================================================
 * VARIANT 2: Generic element ring buffer (any data type)
 * ================================================================ */

#define RING2_SIZE 8

typedef struct {
    uint16_t timestamp;
    int16_t  temperature;
    uint16_t humidity;
} SensorSample;

typedef struct {
    SensorSample buffer[RING2_SIZE];
    volatile uint8_t head;
    volatile uint8_t tail;
} SensorRingBuffer;

static void sensor_rb_init(SensorRingBuffer *rb) {
    rb->head = 0;
    rb->tail = 0;
}

static bool sensor_rb_put(SensorRingBuffer *rb, const SensorSample *sample) {
    uint8_t next = (rb->head + 1) % RING2_SIZE;
    if (next == rb->tail) return false;
    rb->buffer[rb->head] = *sample;
    rb->head = next;
    return true;
}

static bool sensor_rb_get(SensorRingBuffer *rb, SensorSample *sample) {
    if (rb->head == rb->tail) return false;
    *sample = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) % RING2_SIZE;
    return true;
}

static bool sensor_rb_peek(const SensorRingBuffer *rb, SensorSample *sample) {
    if (rb->head == rb->tail) return false;
    *sample = rb->buffer[rb->tail];
    return true;
}

static uint8_t sensor_rb_count(const SensorRingBuffer *rb) {
    return (rb->head - rb->tail + RING2_SIZE) % RING2_SIZE;
}

static void demo_generic_ring_buffer(void) {
    printf("=== Variant 2: Generic Element Ring Buffer ===\n\n");

    SensorRingBuffer rb;
    sensor_rb_init(&rb);

    printf("  Element type: SensorSample (%zu bytes each)\n", sizeof(SensorSample));
    printf("  Buffer slots: %d\n\n", RING2_SIZE);

    /* Produce some sensor readings */
    SensorSample samples[] = {
        { 1000, 235, 450 },
        { 2000, 237, 448 },
        { 3000, 240, 445 },
        { 4000, 238, 450 },
        { 5000, 236, 452 },
    };
    int n = sizeof(samples) / sizeof(samples[0]);

    printf("  Enqueueing %d sensor readings:\n", n);
    for (int i = 0; i < n; i++) {
        sensor_rb_put(&rb, &samples[i]);
        printf("    t=%u: temp=%.1f°C, humidity=%.1f%%\n",
               samples[i].timestamp,
               samples[i].temperature / 10.0f,
               samples[i].humidity / 10.0f);
    }

    printf("\n  Queue count: %u\n\n", sensor_rb_count(&rb));

    /* Peek without removing */
    SensorSample peeked;
    if (sensor_rb_peek(&rb, &peeked)) {
        printf("  Peek (not removed): t=%u, temp=%.1f°C\n\n",
               peeked.timestamp, peeked.temperature / 10.0f);
    }

    /* Consume all */
    printf("  Dequeuing all:\n");
    SensorSample s;
    while (sensor_rb_get(&rb, &s)) {
        printf("    t=%u: temp=%.1f°C, humidity=%.1f%%\n",
               s.timestamp, s.temperature / 10.0f, s.humidity / 10.0f);
    }
    printf("\n");
}

/* ================================================================
 * VARIANT 3: Overwrite ring buffer (always accepts new data)
 *
 * When the buffer is full, the oldest data is silently overwritten.
 * Useful for "latest N samples" buffering (e.g., for display).
 * ================================================================ */

#define RING3_SIZE 8

typedef struct {
    int16_t  buffer[RING3_SIZE];
    uint8_t  head;
    uint8_t  count;
} OverwriteRingBuffer;

static void overwrite_rb_init(OverwriteRingBuffer *rb) {
    rb->head = 0;
    rb->count = 0;
}

static void overwrite_rb_put(OverwriteRingBuffer *rb, int16_t data) {
    rb->buffer[rb->head] = data;
    rb->head = (rb->head + 1) % RING3_SIZE;
    if (rb->count < RING3_SIZE) {
        rb->count++;
    }
}

static int16_t overwrite_rb_get_at(const OverwriteRingBuffer *rb, uint8_t index) {
    /* Index 0 = oldest sample */
    uint8_t actual = (rb->head - rb->count + index + RING3_SIZE) % RING3_SIZE;
    return rb->buffer[actual];
}

static void demo_overwrite_ring_buffer(void) {
    printf("=== Variant 3: Overwrite Ring Buffer ===\n\n");

    OverwriteRingBuffer rb;
    overwrite_rb_init(&rb);

    printf("  This buffer always accepts new data.\n");
    printf("  When full, the oldest entry is overwritten.\n\n");

    /* Write 12 values into an 8-slot buffer */
    int16_t values[] = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120 };
    int n = sizeof(values) / sizeof(values[0]);

    printf("  Writing %d values into %d-slot buffer:\n  ", n, RING3_SIZE);
    for (int i = 0; i < n; i++) {
        overwrite_rb_put(&rb, values[i]);
        printf("%d ", values[i]);
    }

    printf("\n\n  Buffer contains (oldest to newest):\n  ");
    for (int i = 0; i < rb.count; i++) {
        printf("%d ", overwrite_rb_get_at(&rb, (uint8_t)i));
    }
    printf("\n\n  First 4 values (10-40) were overwritten by 90-120.\n\n");
}

/* ================================================================
 * VARIANT 4: Block ring buffer (for DMA-friendly transfers)
 *
 * Operates on fixed-size blocks instead of individual elements.
 * ================================================================ */

#define BLOCK_SIZE 8
#define NUM_BLOCKS 4

typedef struct {
    uint8_t  blocks[NUM_BLOCKS][BLOCK_SIZE];
    uint8_t  head;
    uint8_t  tail;
    uint8_t  count;
} BlockRingBuffer;

static void block_rb_init(BlockRingBuffer *rb) {
    rb->head = 0;
    rb->tail = 0;
    rb->count = 0;
}

static uint8_t *block_rb_write_ptr(BlockRingBuffer *rb) {
    if (rb->count >= NUM_BLOCKS) return NULL;
    return rb->blocks[rb->head];
}

static void block_rb_commit_write(BlockRingBuffer *rb) {
    rb->head = (rb->head + 1) % NUM_BLOCKS;
    rb->count++;
}

static const uint8_t *block_rb_read_ptr(const BlockRingBuffer *rb) {
    if (rb->count == 0) return NULL;
    return rb->blocks[rb->tail];
}

static void block_rb_commit_read(BlockRingBuffer *rb) {
    rb->tail = (rb->tail + 1) % NUM_BLOCKS;
    rb->count--;
}

static void demo_block_ring_buffer(void) {
    printf("=== Variant 4: Block Ring Buffer ===\n\n");

    BlockRingBuffer rb;
    block_rb_init(&rb);

    printf("  Block size: %d bytes, Number of blocks: %d\n", BLOCK_SIZE, NUM_BLOCKS);
    printf("  Ideal for DMA transfers: get a pointer, let DMA fill it,\n");
    printf("  then commit when the transfer is complete.\n\n");

    /* DMA-style write: get pointer, fill it, commit */
    for (int i = 0; i < 3; i++) {
        uint8_t *wp = block_rb_write_ptr(&rb);
        if (wp) {
            for (int j = 0; j < BLOCK_SIZE; j++) {
                wp[j] = (uint8_t)(i * BLOCK_SIZE + j);
            }
            block_rb_commit_write(&rb);
            printf("  Block %d written: ", i);
            for (int j = 0; j < BLOCK_SIZE; j++) {
                printf("%02X ", wp[j]);
            }
            printf("\n");
        }
    }

    printf("\n  Blocks in buffer: %u\n\n", rb.count);

    /* Read blocks out */
    printf("  Reading blocks:\n");
    while (rb.count > 0) {
        const uint8_t *rp = block_rb_read_ptr(&rb);
        if (rp) {
            printf("    ");
            for (int j = 0; j < BLOCK_SIZE; j++) {
                printf("%02X ", rp[j]);
            }
            printf("\n");
            block_rb_commit_read(&rb);
        }
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Concurrency safety analysis
 * ---------------------------------------------------------------- */
static void demo_concurrency(void) {
    printf("=== Ring Buffer Concurrency Safety ===\n\n");

    printf("  Single-producer / single-consumer ring buffers are lock-free\n");
    printf("  when the following conditions are met:\n\n");

    printf("  1. Only ONE writer (producer) modifies 'head'\n");
    printf("     Typical: ISR writes to head\n\n");

    printf("  2. Only ONE reader (consumer) modifies 'tail'\n");
    printf("     Typical: Main loop reads from tail\n\n");

    printf("  3. Head and tail are read atomically\n");
    printf("     On 32-bit ARM: uint16_t and uint32_t reads are atomic\n\n");

    printf("  4. Buffer size is a power of 2 (for masking)\n");
    printf("     Eliminates expensive modulo operation\n\n");

    printf("  ┌──────────────────────────────────────────────┐\n");
    printf("  │  ISR (Producer)         Main Loop (Consumer) │\n");
    printf("  │  ────────────────       ──────────────────── │\n");
    printf("  │  Writes head ──┐        ┌── Writes tail      │\n");
    printf("  │  Reads tail ◄──┼────────┼── Reads head       │\n");
    printf("  │                │        │                    │\n");
    printf("  │  No locks needed! Each side only modifies    │\n");
    printf("  │  its own index and reads the other's.        │\n");
    printf("  └──────────────────────────────────────────────┘\n\n");

    printf("  WARNING: Multiple-producer or multiple-consumer scenarios\n");
    printf("  require additional synchronization (mutexes, CAS, etc.).\n\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Lock-Free Ring Buffer Implementations   ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_byte_ring_buffer();
    demo_generic_ring_buffer();
    demo_overwrite_ring_buffer();
    demo_block_ring_buffer();
    demo_concurrency();

    printf("═══ End of Ring Buffer Demo ═══\n");
    return 0;
}
