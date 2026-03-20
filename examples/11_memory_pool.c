/**
 * @file    11_memory_pool.c
 * @brief   Fixed-block memory pool allocator for embedded systems
 *
 * Demonstrates:
 *  - Fixed-size block allocator (no fragmentation)
 *  - Free-list based allocation (O(1) alloc and free)
 *  - ISR-safe allocation with critical sections
 *  - Pool statistics and diagnostics
 *  - Multiple pool instances for different block sizes
 *  - Practical example: packet buffer management
 *
 * Target: Any embedded platform (hardware-independent)
 */

#include <stdint.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────
 * Critical Section Helpers (ARM Cortex-M)
 * ────────────────────────────────────────────────────────────────────────── */

static inline uint32_t critical_enter(void)
{
    uint32_t primask;
    __asm volatile ("MRS %0, PRIMASK" : "=r" (primask));
    __asm volatile ("CPSID i" ::: "memory");
    return primask;
}

static inline void critical_exit(uint32_t primask)
{
    __asm volatile ("MSR PRIMASK, %0" :: "r" (primask) : "memory");
}

/* ──────────────────────────────────────────────────────────────────────────
 * Simple Fixed-Block Pool (Array-Based)
 *
 * Each block tracks its used/free status with a bitmap.
 * Best for small pools where simplicity is preferred.
 * ────────────────────────────────────────────────────────────────────────── */

#define SIMPLE_BLOCK_SIZE   64
#define SIMPLE_BLOCK_COUNT  32

typedef struct {
    uint8_t  memory[SIMPLE_BLOCK_COUNT][SIMPLE_BLOCK_SIZE];
    uint32_t used_bitmap;   /* Bit N = 1 means block N is allocated */
    uint16_t alloc_count;
    uint16_t alloc_high_water;
    uint32_t alloc_fail_count;
} simple_pool_t;

static simple_pool_t simple_pool;

void simple_pool_init(void)
{
    simple_pool.used_bitmap = 0;
    simple_pool.alloc_count = 0;
    simple_pool.alloc_high_water = 0;
    simple_pool.alloc_fail_count = 0;
}

void *simple_pool_alloc(void)
{
    uint32_t state = critical_enter();

    uint32_t bitmap = simple_pool.used_bitmap;

    if (bitmap == 0xFFFFFFFF || SIMPLE_BLOCK_COUNT >= 32) {
        /* Fallback for pools > 32 blocks or when full */
        if (~bitmap == 0) {
            simple_pool.alloc_fail_count++;
            critical_exit(state);
            return (void *)0;
        }
    }

    /* Find first zero bit (first free block) */
    uint8_t idx = 0;
    uint32_t mask = 1;
    while (mask & bitmap) {
        idx++;
        mask <<= 1;
        if (idx >= SIMPLE_BLOCK_COUNT) {
            simple_pool.alloc_fail_count++;
            critical_exit(state);
            return (void *)0;
        }
    }

    simple_pool.used_bitmap |= mask;
    simple_pool.alloc_count++;
    if (simple_pool.alloc_count > simple_pool.alloc_high_water) {
        simple_pool.alloc_high_water = simple_pool.alloc_count;
    }

    critical_exit(state);
    return simple_pool.memory[idx];
}

void simple_pool_free(void *ptr)
{
    if (ptr == (void *)0) return;

    uint8_t *base = simple_pool.memory[0];
    uint8_t *p = (uint8_t *)ptr;

    if (p < base || p >= base + sizeof(simple_pool.memory)) return;

    uint32_t offset = (uint32_t)(p - base);
    if (offset % SIMPLE_BLOCK_SIZE != 0) return;  /* Not block-aligned */

    uint8_t idx = (uint8_t)(offset / SIMPLE_BLOCK_SIZE);

    uint32_t state = critical_enter();
    simple_pool.used_bitmap &= ~(1U << idx);
    simple_pool.alloc_count--;
    critical_exit(state);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Free-List Based Pool (O(1) Alloc/Free)
 *
 * Uses an intrusive linked list threaded through the free blocks.
 * More efficient than bitmap scanning for larger pools.
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct free_node {
    struct free_node *next;
} free_node_t;

typedef struct {
    uint8_t     *memory;        /* Backing storage */
    free_node_t *free_list;     /* Head of free list */
    uint16_t     block_size;    /* Size of each block (must be >= sizeof(free_node_t)) */
    uint16_t     total_blocks;
    uint16_t     free_count;
    uint16_t     min_free;      /* Lowest free_count ever observed */
    uint32_t     alloc_fail_count;
} mem_pool_t;

void mem_pool_init(mem_pool_t *pool, void *memory,
                   uint16_t block_size, uint16_t block_count)
{
    /* Ensure block_size is large enough for a pointer */
    if (block_size < sizeof(free_node_t)) {
        block_size = sizeof(free_node_t);
    }

    /* Align block_size to 4 bytes */
    block_size = (block_size + 3U) & ~3U;

    pool->memory       = (uint8_t *)memory;
    pool->block_size   = block_size;
    pool->total_blocks = block_count;
    pool->free_count   = block_count;
    pool->min_free     = block_count;
    pool->alloc_fail_count = 0;

    /* Thread free list through all blocks */
    pool->free_list = (free_node_t *)memory;
    free_node_t *node = pool->free_list;

    for (uint16_t i = 0; i < block_count - 1; i++) {
        node->next = (free_node_t *)((uint8_t *)node + block_size);
        node = node->next;
    }
    node->next = (free_node_t *)0;  /* Last block */
}

void *mem_pool_alloc(mem_pool_t *pool)
{
    uint32_t state = critical_enter();

    free_node_t *block = pool->free_list;
    if (block == (free_node_t *)0) {
        pool->alloc_fail_count++;
        critical_exit(state);
        return (void *)0;
    }

    pool->free_list = block->next;
    pool->free_count--;
    if (pool->free_count < pool->min_free) {
        pool->min_free = pool->free_count;
    }

    critical_exit(state);
    return (void *)block;
}

void mem_pool_free(mem_pool_t *pool, void *ptr)
{
    if (ptr == (void *)0) return;

    /* Validate pointer is within pool range */
    uint8_t *p = (uint8_t *)ptr;
    uint8_t *end = pool->memory + (pool->block_size * pool->total_blocks);
    if (p < pool->memory || p >= end) return;

    uint32_t state = critical_enter();

    free_node_t *node = (free_node_t *)ptr;
    node->next = pool->free_list;
    pool->free_list = node;
    pool->free_count++;

    critical_exit(state);
}

uint16_t mem_pool_free_count(const mem_pool_t *pool)
{
    return pool->free_count;
}

uint16_t mem_pool_used_count(const mem_pool_t *pool)
{
    return pool->total_blocks - pool->free_count;
}

uint8_t mem_pool_usage_percent(const mem_pool_t *pool)
{
    return (uint8_t)(((uint32_t)mem_pool_used_count(pool) * 100)
                     / pool->total_blocks);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Multi-Pool Manager
 *
 * Provides pools of different block sizes. Allocation picks the
 * smallest pool that fits the request.
 * ────────────────────────────────────────────────────────────────────────── */

#define POOL_SMALL_SIZE   32
#define POOL_SMALL_COUNT  64
#define POOL_MED_SIZE     128
#define POOL_MED_COUNT    32
#define POOL_LARGE_SIZE   512
#define POOL_LARGE_COUNT  8

static uint8_t pool_small_mem[POOL_SMALL_SIZE * POOL_SMALL_COUNT]
    __attribute__((aligned(4)));
static uint8_t pool_med_mem[POOL_MED_SIZE * POOL_MED_COUNT]
    __attribute__((aligned(4)));
static uint8_t pool_large_mem[POOL_LARGE_SIZE * POOL_LARGE_COUNT]
    __attribute__((aligned(4)));

static mem_pool_t pools[3];

void multi_pool_init(void)
{
    mem_pool_init(&pools[0], pool_small_mem, POOL_SMALL_SIZE, POOL_SMALL_COUNT);
    mem_pool_init(&pools[1], pool_med_mem,   POOL_MED_SIZE,   POOL_MED_COUNT);
    mem_pool_init(&pools[2], pool_large_mem, POOL_LARGE_SIZE, POOL_LARGE_COUNT);
}

void *multi_pool_alloc(uint16_t size)
{
    for (uint8_t i = 0; i < 3; i++) {
        if (size <= pools[i].block_size) {
            void *ptr = mem_pool_alloc(&pools[i]);
            if (ptr) return ptr;
        }
    }
    return (void *)0;
}

void multi_pool_free(void *ptr)
{
    for (uint8_t i = 0; i < 3; i++) {
        uint8_t *base = pools[i].memory;
        uint8_t *end = base + (pools[i].block_size * pools[i].total_blocks);
        if ((uint8_t *)ptr >= base && (uint8_t *)ptr < end) {
            mem_pool_free(&pools[i], ptr);
            return;
        }
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: Network Packet Buffer Pool
 * ────────────────────────────────────────────────────────────────────────── */

#define PKT_BUF_SIZE    256
#define PKT_BUF_COUNT   16

typedef struct {
    uint8_t  data[PKT_BUF_SIZE];
    uint16_t length;
    uint8_t  type;
    uint8_t  flags;
} packet_t;

static uint8_t pkt_pool_mem[sizeof(packet_t) * PKT_BUF_COUNT]
    __attribute__((aligned(4)));
static mem_pool_t pkt_pool;

void packet_system_init(void)
{
    mem_pool_init(&pkt_pool, pkt_pool_mem, sizeof(packet_t), PKT_BUF_COUNT);
}

packet_t *packet_alloc(void)
{
    packet_t *pkt = (packet_t *)mem_pool_alloc(&pkt_pool);
    if (pkt) {
        memset(pkt, 0, sizeof(packet_t));
    }
    return pkt;
}

void packet_free(packet_t *pkt)
{
    mem_pool_free(&pkt_pool, pkt);
}

/* Simulate receiving a packet from a peripheral */
void receive_packet_handler(const uint8_t *raw_data, uint16_t len)
{
    packet_t *pkt = packet_alloc();
    if (pkt == (void *)0) {
        /* Pool exhausted — drop packet */
        return;
    }

    if (len > PKT_BUF_SIZE) len = PKT_BUF_SIZE;
    memcpy(pkt->data, raw_data, len);
    pkt->length = len;
    pkt->type = raw_data[0];

    /* Enqueue for processing */
    /* xQueueSend(packet_queue, &pkt, 0); */

    /* After processing, the consumer calls packet_free(pkt) */
}

/* ──────────────────────────────────────────────────────────────────────────
 * Diagnostics: Print Pool Statistics
 * ────────────────────────────────────────────────────────────────────────── */

extern void uart_printf(void *uart, const char *fmt, ...);

void pool_print_stats(void *uart, const mem_pool_t *pool, const char *name)
{
    uart_printf(uart,
        "Pool '%s': block_size=%u total=%u used=%u free=%u "
        "min_free=%u fails=%lu usage=%u%%\r\n",
        name,
        pool->block_size,
        pool->total_blocks,
        mem_pool_used_count(pool),
        pool->free_count,
        pool->min_free,
        (unsigned long)pool->alloc_fail_count,
        mem_pool_usage_percent(pool));
}

int main(void)
{
    multi_pool_init();
    packet_system_init();

    /* Allocate and free some blocks */
    void *a = multi_pool_alloc(20);   /* Gets 32-byte block */
    void *b = multi_pool_alloc(100);  /* Gets 128-byte block */
    void *c = multi_pool_alloc(256);  /* Gets 512-byte block */

    multi_pool_free(b);
    multi_pool_free(a);

    /* Allocate some packets */
    packet_t *p1 = packet_alloc();
    packet_t *p2 = packet_alloc();
    (void)p1; (void)p2; (void)c;

    /* Print statistics */
    pool_print_stats((void *)0x40011000U, &pools[0], "Small");
    pool_print_stats((void *)0x40011000U, &pools[1], "Medium");
    pool_print_stats((void *)0x40011000U, &pools[2], "Large");
    pool_print_stats((void *)0x40011000U, &pkt_pool, "Packets");

    while (1);
    return 0;
}
