/**
 * @file    critical_section.c
 * @brief   Protecting shared data between ISR and main contexts.
 * @target  ARM Cortex-M (any)
 *
 * Demonstrates:
 *  - Race conditions with shared variables
 *  - Interrupt disable/enable for critical sections
 *  - Nested-safe critical sections using PRIMASK save/restore
 *  - Atomic operations as an alternative
 *  - Double-buffering pattern for large shared data
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Critical Section Primitives                                                */
/* ========================================================================== */

/**
 * Disable all interrupts (simple version).
 * WARNING: Not safe to nest — calling enter twice then exit once leaves
 * interrupts enabled even if they were disabled before the first enter.
 */
static inline void irq_disable(void)
{
    __asm volatile ("cpsid i" ::: "memory");
}

static inline void irq_enable(void)
{
    __asm volatile ("cpsie i" ::: "memory");
}

/**
 * Save interrupt state and disable (nesting-safe version).
 *
 * PRIMASK register: bit 0 = 1 means interrupts disabled.
 * We save the current PRIMASK, then disable. On exit, we restore
 * the saved value. This correctly handles nested critical sections.
 */
static inline uint32_t irq_save(void)
{
    uint32_t primask;
    __asm volatile (
        "mrs %0, primask\n\t"
        "cpsid i"
        : "=r" (primask)
        :
        : "memory"
    );
    return primask;
}

static inline void irq_restore(uint32_t primask)
{
    __asm volatile ("msr primask, %0" : : "r" (primask) : "memory");
}

/* ========================================================================== */
/*  Problem: Race Condition Without Protection                                 */
/* ========================================================================== */

/*
 * Scenario: A 32-bit counter shared between SysTick ISR and main.
 * On a 32-bit ARM, a single-word read/write IS atomic.
 * But a 64-bit counter or a multi-field struct is NOT.
 */

/* Single-word variable: atomic on 32-bit ARM, no protection needed for reads */
volatile uint32_t g_tick_count = 0;

/* Multi-word variable: NOT atomic — needs protection */
typedef struct {
    uint32_t seconds;
    uint16_t milliseconds;
    uint8_t  flags;
} timestamp_t;

volatile timestamp_t g_timestamp = {0, 0, 0};

void SysTick_Handler(void)
{
    g_tick_count++;

    /* Update multi-field timestamp (non-atomic) */
    g_timestamp.milliseconds++;
    if (g_timestamp.milliseconds >= 1000) {
        g_timestamp.milliseconds = 0;
        g_timestamp.seconds++;
    }
}

/**
 * BUG: Reading g_timestamp without protection.
 *
 * If the ISR fires between reading `seconds` and `milliseconds`,
 * we might read seconds=10, milliseconds=0 (after rollover) when
 * the actual time was 9.999 → we'd compute 10.000 instead of 9.999.
 */
timestamp_t get_timestamp_BUGGY(void)
{
    timestamp_t ts;
    ts.seconds      = g_timestamp.seconds;      /* ISR fires here! */
    ts.milliseconds = g_timestamp.milliseconds;  /* Inconsistent!   */
    ts.flags        = g_timestamp.flags;
    return ts;
}

/**
 * FIX: Disable interrupts while reading the shared structure.
 */
timestamp_t get_timestamp_safe(void)
{
    timestamp_t ts;
    uint32_t saved = irq_save();

    ts.seconds      = g_timestamp.seconds;
    ts.milliseconds = g_timestamp.milliseconds;
    ts.flags        = g_timestamp.flags;

    irq_restore(saved);
    return ts;
}

/* ========================================================================== */
/*  Pattern: Read-Copy-Compare (Lock-Free)                                     */
/* ========================================================================== */

/**
 * For read-heavy workloads, avoid disabling interrupts by reading twice
 * and checking consistency.
 */
timestamp_t get_timestamp_lockfree(void)
{
    timestamp_t ts1, ts2;

    do {
        ts1.seconds      = g_timestamp.seconds;
        ts1.milliseconds = g_timestamp.milliseconds;

        ts2.seconds      = g_timestamp.seconds;
        ts2.milliseconds = g_timestamp.milliseconds;
    } while (ts1.seconds != ts2.seconds || ts1.milliseconds != ts2.milliseconds);

    ts1.flags = g_timestamp.flags;
    return ts1;
}

/* ========================================================================== */
/*  Pattern: Double-Buffer for Large Data                                      */
/* ========================================================================== */

/**
 * When the shared data is too large to copy in a critical section
 * (e.g., a 512-byte sensor buffer), use double buffering.
 *
 * The ISR writes to one buffer while the main loop reads from the other.
 * An index variable (single word, atomic on 32-bit ARM) switches them.
 */

#define ADC_BUF_SIZE    128

typedef struct {
    uint16_t samples[ADC_BUF_SIZE];
    uint16_t count;
    uint32_t timestamp;
} adc_buffer_t;

static adc_buffer_t adc_buffers[2];
static volatile uint8_t adc_write_idx = 0;  /* ISR writes to this buffer */
static volatile bool    adc_data_ready = false;

void ADC_IRQHandler(void)
{
    adc_buffer_t *wb = &adc_buffers[adc_write_idx];

    /* Fill the write buffer (simplified — normally from ADC->DR) */
    if (wb->count < ADC_BUF_SIZE) {
        wb->samples[wb->count] = 0;  /* ADC->DR */
        wb->count++;
    }

    if (wb->count >= ADC_BUF_SIZE) {
        wb->timestamp = g_tick_count;
        adc_write_idx ^= 1;          /* Swap: 0→1 or 1→0 (atomic on 32-bit) */
        adc_buffers[adc_write_idx].count = 0;  /* Reset new write buffer */
        adc_data_ready = true;
    }
}

void process_adc_data(void)
{
    if (!adc_data_ready) return;
    adc_data_ready = false;

    /* Read from the buffer the ISR is NOT writing to */
    uint8_t read_idx = adc_write_idx ^ 1;
    const adc_buffer_t *rb = &adc_buffers[read_idx];

    uint32_t sum = 0;
    for (uint16_t i = 0; i < rb->count; i++) {
        sum += rb->samples[i];
    }
    uint16_t average = (rb->count > 0) ? (uint16_t)(sum / rb->count) : 0;
    (void)average;
}

/* ========================================================================== */
/*  Pattern: Shared Counter with Critical Section                              */
/* ========================================================================== */

volatile int32_t g_error_count = 0;

void increment_error_count(void)
{
    uint32_t saved = irq_save();
    g_error_count++;
    irq_restore(saved);
}

int32_t get_and_reset_error_count(void)
{
    uint32_t saved = irq_save();
    int32_t count = g_error_count;
    g_error_count = 0;
    irq_restore(saved);
    return count;
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    /* System init would go here */

    while (1) {
        /* Safe read of shared timestamp */
        timestamp_t now = get_timestamp_safe();
        (void)now;

        /* Process double-buffered ADC data */
        process_adc_data();

        /* Check error count periodically */
        int32_t errors = get_and_reset_error_count();
        if (errors > 0) {
            /* Handle errors */
        }

        __asm volatile ("wfi");
    }
}
