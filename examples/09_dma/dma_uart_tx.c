/**
 * @file    dma_uart_tx.c
 * @brief   DMA-accelerated UART transmission.
 * @target  STM32F4xx (DMA1 Stream6 Channel4 → USART2_TX)
 *
 * Demonstrates:
 *  - DMA stream configuration for memory-to-peripheral transfer
 *  - Transfer-complete interrupt handling
 *  - Double-buffering with DMA for continuous data streaming
 *  - CPU-free data transmission (CPU sets up DMA, then does other work)
 *
 * Without DMA:  CPU copies each byte → USART_DR, waits for TXE (busy loop)
 * With DMA:     CPU sets up DMA once → DMA feeds bytes automatically
 *               CPU utilization: ~0% during transfer
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

/* USART2 (same as other UART examples) */
typedef struct {
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t BRR;
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t CR3;
    volatile uint32_t GTPR;
} USART_TypeDef;

#define USART2  ((USART_TypeDef *)0x40004400U)

/* DMA1 */
typedef struct {
    volatile uint32_t LISR;     /* 0x00: Low interrupt status     */
    volatile uint32_t HISR;     /* 0x04: High interrupt status    */
    volatile uint32_t LIFCR;    /* 0x08: Low interrupt flag clear */
    volatile uint32_t HIFCR;    /* 0x0C: High interrupt flag clear */
} DMA_TypeDef;

typedef struct {
    volatile uint32_t CR;       /* 0x00: Configuration            */
    volatile uint32_t NDTR;     /* 0x04: Number of data items     */
    volatile uint32_t PAR;      /* 0x08: Peripheral address       */
    volatile uint32_t M0AR;     /* 0x0C: Memory 0 address         */
    volatile uint32_t M1AR;     /* 0x10: Memory 1 address         */
    volatile uint32_t FCR;      /* 0x14: FIFO control             */
} DMA_Stream_TypeDef;

#define DMA1            ((DMA_TypeDef *)0x40026000U)
/* Stream 6 offset: 0x10 + 6 × 0x18 = 0xA0 */
#define DMA1_Stream6    ((DMA_Stream_TypeDef *)(0x40026000U + 0x10 + 6 * 0x18))

#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))

/* DMA_CR bits */
#define DMA_CR_EN           (1U << 0)
#define DMA_CR_DMEIE        (1U << 1)   /* Direct mode error interrupt  */
#define DMA_CR_TEIE         (1U << 2)   /* Transfer error interrupt     */
#define DMA_CR_HTIE         (1U << 3)   /* Half transfer interrupt      */
#define DMA_CR_TCIE         (1U << 4)   /* Transfer complete interrupt  */
#define DMA_CR_PFCTRL       (1U << 5)   /* Peripheral flow controller   */
#define DMA_CR_DIR_P2M      (0U << 6)   /* Peripheral to memory         */
#define DMA_CR_DIR_M2P      (1U << 6)   /* Memory to peripheral         */
#define DMA_CR_DIR_M2M      (2U << 6)   /* Memory to memory             */
#define DMA_CR_CIRC         (1U << 8)   /* Circular mode                */
#define DMA_CR_PINC         (1U << 9)   /* Peripheral increment         */
#define DMA_CR_MINC         (1U << 10)  /* Memory increment             */
#define DMA_CR_PSIZE_8      (0U << 11)  /* Peripheral data size: byte   */
#define DMA_CR_PSIZE_16     (1U << 11)
#define DMA_CR_PSIZE_32     (2U << 11)
#define DMA_CR_MSIZE_8      (0U << 13)  /* Memory data size: byte       */
#define DMA_CR_MSIZE_16     (1U << 13)
#define DMA_CR_MSIZE_32     (2U << 13)
#define DMA_CR_PL_LOW       (0U << 16)  /* Priority: low                */
#define DMA_CR_PL_MED       (1U << 16)
#define DMA_CR_PL_HIGH      (2U << 16)
#define DMA_CR_PL_VHIGH     (3U << 16)
#define DMA_CR_DBM          (1U << 18)  /* Double buffer mode           */
#define DMA_CR_CHSEL(n)     ((uint32_t)(n) << 25)  /* Channel selection */

/* DMA HISR/HIFCR bits for Stream 6 */
#define DMA_HISR_TCIF6      (1U << 21)
#define DMA_HISR_HTIF6      (1U << 20)
#define DMA_HISR_TEIF6      (1U << 19)
#define DMA_HIFCR_CTCIF6    (1U << 21)
#define DMA_HIFCR_CHTIF6    (1U << 20)
#define DMA_HIFCR_CTEIF6    (1U << 19)

/* NVIC */
#define DMA1_Stream6_IRQn   17
#define NVIC_ISER0          (*(volatile uint32_t *)0xE000E100)

/* ========================================================================== */
/*  Module State                                                               */
/* ========================================================================== */

static volatile bool dma_tx_busy = false;
static volatile uint32_t dma_tx_complete_count = 0;

/* Callback for transfer completion */
typedef void (*dma_complete_cb_t)(void);
static dma_complete_cb_t dma_tx_callback = (void *)0;

/* ========================================================================== */
/*  DMA UART TX Driver                                                         */
/* ========================================================================== */

/**
 * Initialize DMA1 for USART2 TX.
 */
void dma_uart_init(void)
{
    /* Enable DMA1 clock */
    RCC_AHB1ENR |= (1U << 21);

    /* Enable USART2 DMA TX request */
    USART2->CR3 |= (1U << 7);  /* DMAT bit */

    /* Enable DMA1 Stream6 interrupt in NVIC */
    NVIC_ISER0 = (1U << DMA1_Stream6_IRQn);
}

/**
 * Start a DMA transfer from memory to USART2.
 *
 * @param data      Pointer to data buffer (must remain valid until transfer completes)
 * @param length    Number of bytes to send
 * @param callback  Optional function to call when transfer completes
 * @return          true if transfer started, false if DMA is busy
 */
bool dma_uart_send(const uint8_t *data, uint16_t length, dma_complete_cb_t callback)
{
    if (dma_tx_busy) return false;
    if (length == 0) return false;

    dma_tx_busy = true;
    dma_tx_callback = callback;

    /* Disable stream before configuration */
    DMA1_Stream6->CR &= ~DMA_CR_EN;
    while (DMA1_Stream6->CR & DMA_CR_EN) { }

    /* Clear all interrupt flags for stream 6 */
    DMA1->HIFCR = DMA_HIFCR_CTCIF6 | DMA_HIFCR_CHTIF6 | DMA_HIFCR_CTEIF6;

    /* Configure DMA stream */
    DMA1_Stream6->PAR  = (uint32_t)&USART2->DR;  /* Destination: UART DR  */
    DMA1_Stream6->M0AR = (uint32_t)data;           /* Source: memory buffer */
    DMA1_Stream6->NDTR = length;                   /* Number of items       */

    DMA1_Stream6->CR = DMA_CR_CHSEL(4)    /* Channel 4 = USART2_TX    */
                     | DMA_CR_DIR_M2P     /* Memory → peripheral      */
                     | DMA_CR_MINC        /* Increment memory address  */
                     | DMA_CR_PSIZE_8     /* Peripheral: 8-bit         */
                     | DMA_CR_MSIZE_8     /* Memory: 8-bit             */
                     | DMA_CR_PL_MED      /* Medium priority           */
                     | DMA_CR_TCIE        /* Transfer complete interrupt */
                     | DMA_CR_TEIE;       /* Transfer error interrupt   */

    /* Start transfer */
    DMA1_Stream6->CR |= DMA_CR_EN;

    return true;
}

/**
 * DMA1 Stream6 interrupt handler.
 */
void DMA1_Stream6_IRQHandler(void)
{
    /* Transfer complete */
    if (DMA1->HISR & DMA_HISR_TCIF6) {
        DMA1->HIFCR = DMA_HIFCR_CTCIF6;

        dma_tx_busy = false;
        dma_tx_complete_count++;

        if (dma_tx_callback) {
            dma_tx_callback();
        }
    }

    /* Transfer error */
    if (DMA1->HISR & DMA_HISR_TEIF6) {
        DMA1->HIFCR = DMA_HIFCR_CTEIF6;
        dma_tx_busy = false;
    }
}

/**
 * Check if DMA TX is complete.
 */
bool dma_uart_tx_complete(void)
{
    return !dma_tx_busy;
}

/**
 * Blocking send: start DMA and wait for completion.
 */
void dma_uart_send_blocking(const uint8_t *data, uint16_t length)
{
    dma_uart_send(data, length, (void *)0);
    while (dma_tx_busy) {
        __asm volatile ("wfi");
    }
}

/* ========================================================================== */
/*  Double-Buffer DMA for Continuous Streaming                                 */
/* ========================================================================== */

#define STREAM_BUF_SIZE  256

static uint8_t stream_buf_a[STREAM_BUF_SIZE];
static uint8_t stream_buf_b[STREAM_BUF_SIZE];
static volatile uint8_t active_buf = 0;  /* 0 = buf_a active, 1 = buf_b */

/**
 * Start continuous DMA streaming with double buffering.
 * While DMA sends from one buffer, the application fills the other.
 */
void dma_uart_start_stream(void)
{
    DMA1_Stream6->CR &= ~DMA_CR_EN;
    while (DMA1_Stream6->CR & DMA_CR_EN) { }

    DMA1->HIFCR = DMA_HIFCR_CTCIF6 | DMA_HIFCR_CHTIF6 | DMA_HIFCR_CTEIF6;

    DMA1_Stream6->PAR  = (uint32_t)&USART2->DR;
    DMA1_Stream6->M0AR = (uint32_t)stream_buf_a;
    DMA1_Stream6->M1AR = (uint32_t)stream_buf_b;
    DMA1_Stream6->NDTR = STREAM_BUF_SIZE;

    DMA1_Stream6->CR = DMA_CR_CHSEL(4)
                     | DMA_CR_DIR_M2P
                     | DMA_CR_MINC
                     | DMA_CR_PSIZE_8
                     | DMA_CR_MSIZE_8
                     | DMA_CR_PL_HIGH
                     | DMA_CR_DBM         /* Double-buffer mode */
                     | DMA_CR_CIRC        /* Circular mode      */
                     | DMA_CR_TCIE;

    active_buf = 0;
    DMA1_Stream6->CR |= DMA_CR_EN;
}

/**
 * Get a pointer to the buffer that is NOT currently being sent by DMA.
 * The application should fill this buffer before the current transfer completes.
 */
uint8_t *dma_get_inactive_buffer(void)
{
    /* CT bit in CR indicates which buffer DMA is currently using */
    if (DMA1_Stream6->CR & (1U << 19)) {
        return stream_buf_a;  /* DMA using buf_b → app can fill buf_a */
    } else {
        return stream_buf_b;  /* DMA using buf_a → app can fill buf_b */
    }
}

/* ========================================================================== */
/*  Main — Example Usage                                                       */
/* ========================================================================== */

int main(void)
{
    /* uart_init(115200); — assumed already done */
    dma_uart_init();

    /* Example 1: Single DMA transfer */
    const char msg[] = "Hello from DMA!\r\n";
    dma_uart_send_blocking((const uint8_t *)msg, sizeof(msg) - 1);

    /* Example 2: Non-blocking with callback */
    static volatile bool send_done = false;

    static void on_send_complete(void)
    {
        send_done = true;
    }

    const char msg2[] = "Non-blocking DMA transfer.\r\n";
    dma_uart_send((const uint8_t *)msg2, sizeof(msg2) - 1, on_send_complete);

    while (!send_done) {
        /* CPU does other work here */
    }

    /* Example 3: Continuous streaming */
    dma_uart_start_stream();

    while (1) {
        uint8_t *buf = dma_get_inactive_buffer();

        /* Fill the buffer with sensor data, formatted strings, etc. */
        memset(buf, 'A', STREAM_BUF_SIZE);

        /* Wait for buffer swap (in production, use TCIE interrupt flag) */
        /* The DMA will automatically switch buffers */
    }
}
