/**
 * @file    08_dma_driver.c
 * @brief   DMA driver for UART, ADC, and memory operations
 *
 * Demonstrates:
 *  - DMA channel configuration
 *  - Memory-to-peripheral (UART TX via DMA)
 *  - Peripheral-to-memory (ADC continuous sampling via DMA)
 *  - Memory-to-memory (fast copy and fill)
 *  - Circular buffer mode with half-transfer interrupts
 *  - Double-buffering technique
 *
 * Target: Generic ARM Cortex-M with STM32-like DMA controller
 */

#include <stdint.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────
 * DMA Register Definitions
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    volatile uint32_t CCR;     /* Channel configuration register */
    volatile uint32_t CNDTR;   /* Number of data items to transfer */
    volatile uint32_t CPAR;    /* Peripheral address register */
    volatile uint32_t CMAR;    /* Memory address register */
    uint32_t          RESERVED;
} DMA_Channel_TypeDef;

typedef struct {
    volatile uint32_t ISR;     /* Interrupt status register */
    volatile uint32_t IFCR;    /* Interrupt flag clear register */
} DMA_TypeDef;

#define DMA1      ((DMA_TypeDef *)0x40020000U)
#define DMA1_CH1  ((DMA_Channel_TypeDef *)0x40020008U)
#define DMA1_CH2  ((DMA_Channel_TypeDef *)0x4002001CU)
#define DMA1_CH3  ((DMA_Channel_TypeDef *)0x40020030U)
#define DMA1_CH4  ((DMA_Channel_TypeDef *)0x40020044U)  /* USART1_TX */
#define DMA1_CH5  ((DMA_Channel_TypeDef *)0x40020058U)  /* USART1_RX */

/* CCR bits */
#define DMA_CCR_EN       (1U << 0)   /* Channel enable */
#define DMA_CCR_TCIE     (1U << 1)   /* Transfer complete interrupt */
#define DMA_CCR_HTIE     (1U << 2)   /* Half transfer interrupt */
#define DMA_CCR_TEIE     (1U << 3)   /* Transfer error interrupt */
#define DMA_CCR_DIR      (1U << 4)   /* Direction: 0=periph-to-mem, 1=mem-to-periph */
#define DMA_CCR_CIRC     (1U << 5)   /* Circular mode */
#define DMA_CCR_PINC     (1U << 6)   /* Peripheral increment */
#define DMA_CCR_MINC     (1U << 7)   /* Memory increment */
#define DMA_CCR_MEM2MEM  (1U << 14)  /* Memory-to-memory mode */

/* ISR/IFCR bit positions per channel (channel N: offset = 4*(N-1)) */
#define DMA_ISR_GIF(ch)   (1U << (4 * ((ch) - 1)))
#define DMA_ISR_TCIF(ch)  (1U << (4 * ((ch) - 1) + 1))
#define DMA_ISR_HTIF(ch)  (1U << (4 * ((ch) - 1) + 2))
#define DMA_ISR_TEIF(ch)  (1U << (4 * ((ch) - 1) + 3))

/* USART registers (abbreviated) */
typedef struct {
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t BRR;
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t CR3;
} USART_TypeDef;

#define USART1 ((USART_TypeDef *)0x40011000U)

/* ADC register (abbreviated) */
typedef struct {
    volatile uint32_t SR;
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t SMPR1;
    volatile uint32_t SMPR2;
    uint32_t RESERVED[5];
    volatile uint32_t SQR1;
    volatile uint32_t SQR2;
    volatile uint32_t SQR3;
    uint32_t RESERVED2[4];
    volatile uint32_t DR;
} ADC_TypeDef;

#define ADC1 ((ADC_TypeDef *)0x40012400U)

/* RCC */
#define RCC_AHBENR  (*(volatile uint32_t *)0x40021014U)

/* ──────────────────────────────────────────────────────────────────────────
 * DMA Data Size Encoding (PSIZE / MSIZE fields in CCR)
 * ────────────────────────────────────────────────────────────────────────── */

typedef enum {
    DMA_SIZE_8BIT  = 0,
    DMA_SIZE_16BIT = 1,
    DMA_SIZE_32BIT = 2
} dma_data_size_t;

typedef struct {
    DMA_Channel_TypeDef *channel;
    uint8_t              ch_num;     /* 1-based for ISR/IFCR access */
    uint32_t             periph_addr;
    uint32_t             mem_addr;
    uint16_t             count;
    dma_data_size_t      periph_size;
    dma_data_size_t      mem_size;
    uint8_t              direction;  /* 0 = periph→mem, 1 = mem→periph */
    uint8_t              circular;
    uint8_t              mem_inc;
    uint8_t              periph_inc;
} dma_config_t;

/* ──────────────────────────────────────────────────────────────────────────
 * DMA Driver API
 * ────────────────────────────────────────────────────────────────────────── */

void dma_clock_enable(void)
{
    RCC_AHBENR |= (1U << 0);  /* DMA1 clock */
}

void dma_configure(const dma_config_t *cfg)
{
    cfg->channel->CCR = 0;  /* Disable first */

    cfg->channel->CPAR  = cfg->periph_addr;
    cfg->channel->CMAR  = cfg->mem_addr;
    cfg->channel->CNDTR = cfg->count;

    uint32_t ccr = 0;
    ccr |= ((uint32_t)cfg->periph_size << 8);
    ccr |= ((uint32_t)cfg->mem_size << 10);
    if (cfg->direction) ccr |= DMA_CCR_DIR;
    if (cfg->circular)  ccr |= DMA_CCR_CIRC;
    if (cfg->mem_inc)   ccr |= DMA_CCR_MINC;
    if (cfg->periph_inc) ccr |= DMA_CCR_PINC;
    ccr |= DMA_CCR_TCIE;  /* Always enable TC interrupt */

    cfg->channel->CCR = ccr;
}

void dma_start(DMA_Channel_TypeDef *ch)
{
    ch->CCR |= DMA_CCR_EN;
}

void dma_stop(DMA_Channel_TypeDef *ch)
{
    ch->CCR &= ~DMA_CCR_EN;
}

uint16_t dma_remaining(DMA_Channel_TypeDef *ch)
{
    return (uint16_t)ch->CNDTR;
}

void dma_clear_flags(uint8_t ch_num)
{
    DMA1->IFCR = (0xFU << (4 * (ch_num - 1)));
}

/* ──────────────────────────────────────────────────────────────────────────
 * DMA UART TX: Send a buffer without CPU involvement
 * ────────────────────────────────────────────────────────────────────────── */

static volatile uint8_t uart_tx_dma_busy = 0;

void dma_uart_tx_start(const uint8_t *data, uint16_t len)
{
    while (uart_tx_dma_busy);  /* Wait if previous transfer in progress */

    dma_config_t cfg = {
        .channel     = DMA1_CH4,
        .ch_num      = 4,
        .periph_addr = (uint32_t)&USART1->DR,
        .mem_addr    = (uint32_t)data,
        .count       = len,
        .periph_size = DMA_SIZE_8BIT,
        .mem_size    = DMA_SIZE_8BIT,
        .direction   = 1,  /* Memory → peripheral */
        .circular    = 0,
        .mem_inc     = 1,
        .periph_inc  = 0,
    };

    dma_clear_flags(4);
    dma_configure(&cfg);

    uart_tx_dma_busy = 1;

    USART1->CR3 |= (1U << 7);  /* DMAT: enable USART DMA transmit */
    dma_start(DMA1_CH4);
}

void DMA1_Channel4_IRQHandler(void)
{
    if (DMA1->ISR & DMA_ISR_TCIF(4)) {
        dma_clear_flags(4);
        dma_stop(DMA1_CH4);
        USART1->CR3 &= ~(1U << 7);
        uart_tx_dma_busy = 0;
    }
}

/* Wait for DMA UART TX to complete */
void dma_uart_tx_wait(void)
{
    while (uart_tx_dma_busy);
}

/* ──────────────────────────────────────────────────────────────────────────
 * DMA ADC: Continuous Sampling with Double Buffer
 * ────────────────────────────────────────────────────────────────────────── */

#define ADC_DMA_BUF_SIZE  512  /* Total buffer size (split into two halves) */

static uint16_t adc_dma_buffer[ADC_DMA_BUF_SIZE];
static volatile uint8_t  adc_half_ready = 0;  /* 1 = first half, 2 = second half */

void dma_adc_continuous_start(uint8_t channel)
{
    /* Configure ADC for continuous conversion + DMA */
    ADC1->SQR3 = channel;
    ADC1->CR2 |= (1U << 8);   /* DMA enable */
    ADC1->CR2 |= (1U << 1);   /* Continuous mode */

    /* Configure DMA in circular mode with half-transfer interrupt */
    dma_config_t cfg = {
        .channel     = DMA1_CH1,
        .ch_num      = 1,
        .periph_addr = (uint32_t)&ADC1->DR,
        .mem_addr    = (uint32_t)adc_dma_buffer,
        .count       = ADC_DMA_BUF_SIZE,
        .periph_size = DMA_SIZE_16BIT,
        .mem_size    = DMA_SIZE_16BIT,
        .direction   = 0,  /* Peripheral → memory */
        .circular    = 1,
        .mem_inc     = 1,
        .periph_inc  = 0,
    };

    dma_clear_flags(1);
    dma_configure(&cfg);
    DMA1_CH1->CCR |= DMA_CCR_HTIE;  /* Enable half-transfer interrupt */
    dma_start(DMA1_CH1);

    ADC1->CR2 |= (1U << 0);   /* Enable ADC */
    ADC1->CR2 |= (1U << 30);  /* Start conversion */
}

void DMA1_Channel1_IRQHandler(void)
{
    if (DMA1->ISR & DMA_ISR_HTIF(1)) {
        DMA1->IFCR = DMA_ISR_HTIF(1);
        adc_half_ready = 1;  /* First half is ready for processing */
    }

    if (DMA1->ISR & DMA_ISR_TCIF(1)) {
        DMA1->IFCR = DMA_ISR_TCIF(1);
        adc_half_ready = 2;  /* Second half is ready for processing */
    }
}

const uint16_t *dma_adc_get_buffer(uint8_t *which_half)
{
    *which_half = adc_half_ready;
    adc_half_ready = 0;

    if (*which_half == 1) {
        return &adc_dma_buffer[0];
    } else if (*which_half == 2) {
        return &adc_dma_buffer[ADC_DMA_BUF_SIZE / 2];
    }
    return (void *)0;
}

/* ──────────────────────────────────────────────────────────────────────────
 * DMA Memory-to-Memory: Fast Copy and Fill
 * ────────────────────────────────────────────────────────────────────────── */

static volatile uint8_t mem_dma_done = 0;

void dma_memcpy(void *dst, const void *src, uint16_t len_words)
{
    mem_dma_done = 0;

    DMA1_CH1->CCR = 0;  /* Disable and reset */

    DMA1_CH1->CPAR  = (uint32_t)src;
    DMA1_CH1->CMAR  = (uint32_t)dst;
    DMA1_CH1->CNDTR = len_words;

    DMA1_CH1->CCR = DMA_CCR_MEM2MEM
                  | DMA_CCR_MINC
                  | DMA_CCR_PINC
                  | (DMA_SIZE_32BIT << 8)   /* Source size: 32-bit */
                  | (DMA_SIZE_32BIT << 10)  /* Dest size: 32-bit */
                  | DMA_CCR_TCIE;

    dma_clear_flags(1);
    dma_start(DMA1_CH1);
}

/* Busy-wait version */
void dma_memcpy_blocking(void *dst, const void *src, uint16_t len_words)
{
    dma_memcpy(dst, src, len_words);
    while (!(DMA1->ISR & DMA_ISR_TCIF(1)));
    dma_clear_flags(1);
    dma_stop(DMA1_CH1);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Signal Processing on DMA ADC Buffer
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    uint16_t min;
    uint16_t max;
    uint32_t avg;
    uint32_t rms;
} signal_stats_t;

void compute_signal_stats(const uint16_t *data, uint16_t count,
                           signal_stats_t *stats)
{
    uint16_t min_val = 0xFFFF;
    uint16_t max_val = 0;
    uint32_t sum = 0;
    uint64_t sum_sq = 0;

    for (uint16_t i = 0; i < count; i++) {
        uint16_t v = data[i];
        if (v < min_val) min_val = v;
        if (v > max_val) max_val = v;
        sum += v;
        sum_sq += (uint32_t)v * v;
    }

    stats->min = min_val;
    stats->max = max_val;
    stats->avg = sum / count;

    /* Integer square root approximation for RMS */
    uint64_t mean_sq = sum_sq / count;
    uint32_t rms = (uint32_t)mean_sq;
    uint32_t x = rms;
    uint32_t y = 1;
    while (x > y) {
        x = (x + y) / 2;
        y = rms / x;
    }
    stats->rms = x;
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example
 * ────────────────────────────────────────────────────────────────────────── */

extern void uart_printf(void *uart, const char *fmt, ...);
extern void delay_ms(uint32_t ms);

int main(void)
{
    dma_clock_enable();

    /* Send a welcome message via DMA */
    static const char msg[] = "DMA UART TX example running...\r\n";
    dma_uart_tx_start((const uint8_t *)msg, sizeof(msg) - 1);
    dma_uart_tx_wait();

    /* Start continuous ADC sampling via DMA */
    dma_adc_continuous_start(0);

    signal_stats_t stats;

    while (1) {
        uint8_t half;
        const uint16_t *buf = dma_adc_get_buffer(&half);

        if (buf) {
            compute_signal_stats(buf, ADC_DMA_BUF_SIZE / 2, &stats);

            char report[128];
            int len = snprintf(report, sizeof(report),
                "ADC [half %u]: min=%u max=%u avg=%lu rms=%lu\r\n",
                half, stats.min, stats.max,
                (unsigned long)stats.avg, (unsigned long)stats.rms);

            dma_uart_tx_start((const uint8_t *)report, (uint16_t)len);
        }

        delay_ms(100);
    }

    return 0;
}
