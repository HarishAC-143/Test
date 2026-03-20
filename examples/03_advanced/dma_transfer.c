/**
 * DMA (Direct Memory Access) Transfer Patterns
 *
 * Demonstrates DMA concepts: memory-to-memory transfers, peripheral
 * transfers, double buffering, and scatter-gather simulation.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>

/* ----------------------------------------------------------------
 * Simulated DMA engine
 * ---------------------------------------------------------------- */
typedef enum {
    DMA_DIR_MEM_TO_MEM,
    DMA_DIR_PERIPH_TO_MEM,
    DMA_DIR_MEM_TO_PERIPH
} DMA_Direction;

typedef enum {
    DMA_SIZE_BYTE     = 1,
    DMA_SIZE_HALFWORD = 2,
    DMA_SIZE_WORD     = 4
} DMA_DataSize;

typedef struct {
    volatile uint8_t  *src;
    volatile uint8_t  *dst;
    uint32_t           count;
    DMA_Direction      direction;
    DMA_DataSize       data_size;
    bool               src_increment;
    bool               dst_increment;
    bool               circular;
    bool               complete;
    uint32_t           transfers_done;
} DMA_Channel;

static void dma_init(DMA_Channel *ch,
                     volatile void *src, volatile void *dst,
                     uint32_t count, DMA_Direction dir,
                     DMA_DataSize size,
                     bool src_inc, bool dst_inc, bool circular) {
    ch->src = (volatile uint8_t *)src;
    ch->dst = (volatile uint8_t *)dst;
    ch->count = count;
    ch->direction = dir;
    ch->data_size = size;
    ch->src_increment = src_inc;
    ch->dst_increment = dst_inc;
    ch->circular = circular;
    ch->complete = false;
    ch->transfers_done = 0;
}

static void dma_execute(DMA_Channel *ch) {
    volatile uint8_t *s = ch->src;
    volatile uint8_t *d = ch->dst;

    for (uint32_t i = 0; i < ch->count; i++) {
        for (uint32_t b = 0; b < (uint32_t)ch->data_size; b++) {
            *d = *s;
            s++;
            d++;
        }

        if (!ch->src_increment) {
            s = ch->src;
        }
        if (!ch->dst_increment) {
            d = ch->dst;
        }

        ch->transfers_done++;
    }

    if (ch->circular) {
        ch->complete = false;
    } else {
        ch->complete = true;
    }
}

/* ----------------------------------------------------------------
 * Demo: Memory-to-memory transfer
 * ---------------------------------------------------------------- */
static void demo_mem_to_mem(void) {
    printf("=== DMA: Memory-to-Memory Transfer ===\n\n");

    uint32_t source[8] = { 0xDEAD0001, 0xDEAD0002, 0xDEAD0003, 0xDEAD0004,
                           0xDEAD0005, 0xDEAD0006, 0xDEAD0007, 0xDEAD0008 };
    uint32_t dest[8] = {0};

    printf("  Source buffer: ");
    for (int i = 0; i < 8; i++) printf("0x%08X ", source[i]);
    printf("\n");

    printf("  Dest before:   ");
    for (int i = 0; i < 8; i++) printf("0x%08X ", dest[i]);
    printf("\n");

    DMA_Channel ch;
    dma_init(&ch, source, dest, 8, DMA_DIR_MEM_TO_MEM,
             DMA_SIZE_WORD, true, true, false);
    dma_execute(&ch);

    printf("  Dest after:    ");
    for (int i = 0; i < 8; i++) printf("0x%08X ", dest[i]);
    printf("\n");

    printf("\n  Transfers completed: %u (no CPU involvement!)\n", ch.transfers_done);
    printf("  Complete flag: %s\n\n", ch.complete ? "Yes" : "No");
}

/* ----------------------------------------------------------------
 * Demo: Peripheral-to-memory (UART RX via DMA)
 * ---------------------------------------------------------------- */
static void demo_periph_to_mem(void) {
    printf("=== DMA: Peripheral-to-Memory (UART RX) ===\n\n");

    /* Simulated UART data register (single byte) */
    volatile uint8_t uart_dr = 0;
    uint8_t rx_buffer[16] = {0};

    printf("  Simulating 16 bytes received via UART DMA:\n\n");

    DMA_Channel ch;
    dma_init(&ch, &uart_dr, rx_buffer, 16, DMA_DIR_PERIPH_TO_MEM,
             DMA_SIZE_BYTE, false, true, false);

    /* Simulate: UART receives bytes one at a time */
    const char *message = "Hello DMA World";
    volatile uint8_t *dst_ptr = ch.dst;

    for (int i = 0; i < 16; i++) {
        uart_dr = (uint8_t)(i < (int)strlen(message) ? message[i] : 0);
        *dst_ptr = uart_dr;
        dst_ptr++;
        ch.transfers_done++;
    }
    ch.complete = true;

    printf("  Received string: \"");
    for (int i = 0; i < 16; i++) {
        if (rx_buffer[i] >= 32 && rx_buffer[i] < 127)
            printf("%c", rx_buffer[i]);
        else
            printf(".");
    }
    printf("\"\n");

    printf("  Hex dump: ");
    for (int i = 0; i < 16; i++) printf("%02X ", rx_buffer[i]);
    printf("\n\n");

    printf("  Key advantage: CPU was free during the entire transfer!\n");
    printf("  The DMA engine moved each byte from UART->DR to memory\n");
    printf("  without any CPU instructions.\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Double buffering
 * ---------------------------------------------------------------- */
static void demo_double_buffer(void) {
    printf("=== DMA: Double Buffering ===\n\n");

    uint8_t buffer_a[8];
    uint8_t buffer_b[8];
    uint8_t *active_buf = buffer_a;
    uint8_t *process_buf = buffer_b;

    printf("  Double buffering: DMA fills one buffer while\n");
    printf("  CPU processes the other. No data is ever lost.\n\n");

    printf("  ┌──────────┐     ┌──────────┐\n");
    printf("  │ Buffer A │ ◄── │   DMA    │  (DMA fills A)\n");
    printf("  └──────────┘     └──────────┘\n");
    printf("  ┌──────────┐     ┌──────────┐\n");
    printf("  │ Buffer B │ ──► │   CPU    │  (CPU processes B)\n");
    printf("  └──────────┘     └──────────┘\n\n");

    for (int round = 0; round < 4; round++) {
        /* DMA fills the active buffer */
        for (int i = 0; i < 8; i++) {
            active_buf[i] = (uint8_t)((round * 8) + i);
        }

        printf("  Round %d: DMA filled %s, CPU processes %s\n",
               round + 1,
               active_buf == buffer_a ? "Buffer A" : "Buffer B",
               process_buf == buffer_a ? "Buffer A" : "Buffer B");

        printf("    Active:  ");
        for (int i = 0; i < 8; i++) printf("%02X ", active_buf[i]);
        printf("\n");

        printf("    Process: ");
        for (int i = 0; i < 8; i++) printf("%02X ", process_buf[i]);
        printf("\n");

        /* Swap buffers */
        uint8_t *tmp = active_buf;
        active_buf = process_buf;
        process_buf = tmp;
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Circular DMA for continuous ADC
 * ---------------------------------------------------------------- */
static void demo_circular_dma(void) {
    printf("=== DMA: Circular Mode (Continuous ADC) ===\n\n");

    #define NUM_ADC_CHANNELS 4
    #define NUM_SAMPLES 3

    uint16_t adc_buffer[NUM_ADC_CHANNELS * NUM_SAMPLES];
    memset(adc_buffer, 0, sizeof(adc_buffer));

    printf("  Circular DMA continuously fills a buffer with ADC data.\n");
    printf("  When the buffer is full, DMA wraps around to the beginning.\n\n");

    /* Simulate 3 complete scan cycles */
    uint16_t sim_adc_values[NUM_ADC_CHANNELS] = { 1024, 2048, 3072, 4095 };

    for (int sample = 0; sample < NUM_SAMPLES; sample++) {
        for (int ch = 0; ch < NUM_ADC_CHANNELS; ch++) {
            /* Add some variation */
            adc_buffer[sample * NUM_ADC_CHANNELS + ch] =
                sim_adc_values[ch] + (uint16_t)(sample * 10 + ch);
        }
    }

    printf("  Buffer contents (%d channels × %d samples):\n\n",
           NUM_ADC_CHANNELS, NUM_SAMPLES);
    printf("           Ch0    Ch1    Ch2    Ch3\n");
    printf("  ------  -----  -----  -----  -----\n");

    for (int s = 0; s < NUM_SAMPLES; s++) {
        printf("  Scan %d: ", s + 1);
        for (int ch = 0; ch < NUM_ADC_CHANNELS; ch++) {
            printf(" %4u  ", adc_buffer[s * NUM_ADC_CHANNELS + ch]);
        }
        printf("\n");
    }

    /* Calculate averages */
    printf("\n  Averages:\n  ");
    for (int ch = 0; ch < NUM_ADC_CHANNELS; ch++) {
        uint32_t sum = 0;
        for (int s = 0; s < NUM_SAMPLES; s++) {
            sum += adc_buffer[s * NUM_ADC_CHANNELS + ch];
        }
        printf("  Ch%d=%u", ch, sum / NUM_SAMPLES);
    }
    printf("\n\n");
}

/* ----------------------------------------------------------------
 * Demo: DMA vs CPU transfer benchmark
 * ---------------------------------------------------------------- */
static void demo_benchmark(void) {
    printf("=== DMA: CPU vs DMA Transfer Comparison ===\n\n");

    #define BENCH_SIZE 4096
    static uint8_t src[BENCH_SIZE];
    static uint8_t dst[BENCH_SIZE];

    for (int i = 0; i < BENCH_SIZE; i++) {
        src[i] = (uint8_t)i;
    }

    /* CPU transfer */
    clock_t cpu_start = clock();
    for (int rep = 0; rep < 10000; rep++) {
        memcpy(dst, src, BENCH_SIZE);
    }
    clock_t cpu_end = clock();
    double cpu_time = (double)(cpu_end - cpu_start) / CLOCKS_PER_SEC;

    printf("  Transfer size: %d bytes × 10000 repetitions\n\n", BENCH_SIZE);
    printf("  CPU (memcpy): %.4f seconds\n", cpu_time);
    printf("  DMA:          Runs in background — CPU is FREE to:\n");
    printf("                - Process previous data\n");
    printf("                - Handle other peripherals\n");
    printf("                - Enter low-power mode\n\n");

    printf("  On real hardware:\n");
    printf("    CPU transfer: Each byte requires LOAD + STORE instructions\n");
    printf("    DMA transfer: Zero CPU instructions (bus master does the work)\n\n");

    printf("  DMA is most beneficial when:\n");
    printf("    1. Transferring large blocks of data\n");
    printf("    2. Moving data at high rates (e.g., ADC at 1 Msps)\n");
    printf("    3. CPU needs to do other work simultaneously\n");
    printf("    4. Low-power operation (CPU can sleep during transfers)\n\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  DMA (Direct Memory Access) Patterns     ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_mem_to_mem();
    demo_periph_to_mem();
    demo_double_buffer();
    demo_circular_dma();
    demo_benchmark();

    printf("═══ End of DMA Transfer Demo ═══\n");
    return 0;
}
