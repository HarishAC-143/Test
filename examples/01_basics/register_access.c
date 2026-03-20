/**
 * Memory-Mapped Register Access Patterns
 *
 * Demonstrates the common techniques for accessing hardware registers
 * in embedded C, using simulated registers for host-PC execution.
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ================================================================
 * TECHNIQUE 1: Direct #define macros
 *
 * The simplest approach. Each register is a dereferenced pointer
 * to a volatile uint32_t at a specific address.
 * ================================================================ */

/* Simulated memory block to act as "hardware" */
static uint32_t sim_periph_memory[16] = {0};
#define SIM_BASE ((uintptr_t)sim_periph_memory)

#define REG_CONTROL    (*(volatile uint32_t *)(SIM_BASE + 0x00))
#define REG_STATUS     (*(volatile uint32_t *)(SIM_BASE + 0x04))
#define REG_DATA       (*(volatile uint32_t *)(SIM_BASE + 0x08))
#define REG_INTERRUPT  (*(volatile uint32_t *)(SIM_BASE + 0x0C))

static void demo_direct_define(void) {
    printf("=== Technique 1: Direct #define Macros ===\n\n");

    memset(sim_periph_memory, 0, sizeof(sim_periph_memory));

    REG_CONTROL = 0x00000001;
    printf("  CONTROL = 0x%08X (enabled)\n", REG_CONTROL);

    REG_DATA = 0xCAFEBABE;
    printf("  DATA    = 0x%08X\n", REG_DATA);

    /* Read status */
    sim_periph_memory[1] = 0x00000003;  /* Simulate hardware setting status */
    printf("  STATUS  = 0x%08X (simulated hw ready)\n", REG_STATUS);

    printf("\n  Pros: Simple, fast, minimal overhead\n");
    printf("  Cons: No grouping, easy to mistype offset\n\n");
}

/* ================================================================
 * TECHNIQUE 2: Struct overlay
 *
 * Map a struct over the register block. Each struct field aligns
 * with a hardware register at the correct offset.
 * ================================================================ */

typedef struct {
    volatile uint32_t CR;      /* 0x00: Control Register */
    volatile uint32_t SR;      /* 0x04: Status Register */
    volatile uint32_t DR;      /* 0x08: Data Register */
    volatile uint32_t IER;     /* 0x0C: Interrupt Enable Register */
    volatile uint32_t ISR_REG; /* 0x10: Interrupt Status Register */
    volatile uint32_t reserved[3];
    volatile uint32_t BRR;     /* 0x20: Baud Rate Register */
} UART_TypeDef;

static uint32_t sim_uart_memory[16] = {0};
#define SIM_UART ((UART_TypeDef *)sim_uart_memory)

static void demo_struct_overlay(void) {
    printf("=== Technique 2: Struct Overlay ===\n\n");

    memset(sim_uart_memory, 0, sizeof(sim_uart_memory));

    /* Clean, readable register access */
    SIM_UART->CR = (1 << 0)    /* Enable UART */
                 | (1 << 1)    /* Enable TX */
                 | (1 << 2);   /* Enable RX */

    SIM_UART->BRR = 0x1A0;    /* Baud rate divider */

    printf("  UART->CR  = 0x%08X (UART, TX, RX enabled)\n", SIM_UART->CR);
    printf("  UART->BRR = 0x%08X (baud rate)\n", SIM_UART->BRR);

    /* Verify offsets */
    printf("\n  Offset verification:\n");
    printf("    CR  offset: 0x%02lX (expected 0x00)\n",
           (unsigned long)((uint8_t *)&SIM_UART->CR - (uint8_t *)SIM_UART));
    printf("    SR  offset: 0x%02lX (expected 0x04)\n",
           (unsigned long)((uint8_t *)&SIM_UART->SR - (uint8_t *)SIM_UART));
    printf("    DR  offset: 0x%02lX (expected 0x08)\n",
           (unsigned long)((uint8_t *)&SIM_UART->DR - (uint8_t *)SIM_UART));
    printf("    BRR offset: 0x%02lX (expected 0x20)\n",
           (unsigned long)((uint8_t *)&SIM_UART->BRR - (uint8_t *)SIM_UART));

    printf("\n  Pros: Readable, IDE autocomplete, offset checked by compiler\n");
    printf("  Cons: Must match actual hardware layout exactly\n\n");
}

/* ================================================================
 * TECHNIQUE 3: Register with named bit fields
 *
 * Define named constants for individual bits and fields within
 * each register, improving code readability.
 * ================================================================ */

/* Control Register bits */
#define UART_CR_EN      (1U << 0)
#define UART_CR_TE      (1U << 1)
#define UART_CR_RE      (1U << 2)
#define UART_CR_RXNEIE  (1U << 5)
#define UART_CR_TXEIE   (1U << 7)

/* Word length field: bits [13:12] */
#define UART_CR_WLEN_MASK   (3U << 12)
#define UART_CR_WLEN_7      (0U << 12)
#define UART_CR_WLEN_8      (1U << 12)
#define UART_CR_WLEN_9      (2U << 12)

/* Status Register bits */
#define UART_SR_TXE     (1U << 7)
#define UART_SR_RXNE    (1U << 5)
#define UART_SR_TC      (1U << 6)
#define UART_SR_ORE     (1U << 3)

static void demo_named_bits(void) {
    printf("=== Technique 3: Named Bit Constants ===\n\n");

    memset(sim_uart_memory, 0, sizeof(sim_uart_memory));

    /* Configuration is self-documenting */
    SIM_UART->CR = UART_CR_EN
                 | UART_CR_TE
                 | UART_CR_RE
                 | UART_CR_WLEN_8
                 | UART_CR_RXNEIE;

    printf("  CR configured: 0x%08X\n", SIM_UART->CR);
    printf("    UART enabled:       %s\n", (SIM_UART->CR & UART_CR_EN) ? "Yes" : "No");
    printf("    TX enabled:         %s\n", (SIM_UART->CR & UART_CR_TE) ? "Yes" : "No");
    printf("    RX enabled:         %s\n", (SIM_UART->CR & UART_CR_RE) ? "Yes" : "No");
    printf("    RX interrupt:       %s\n", (SIM_UART->CR & UART_CR_RXNEIE) ? "Yes" : "No");
    printf("    Word length field:  0x%X\n",
           (SIM_UART->CR & UART_CR_WLEN_MASK) >> 12);

    /* Simulating a status check */
    sim_uart_memory[1] = UART_SR_TXE | UART_SR_RXNE;

    printf("\n  Status register: 0x%08X\n", SIM_UART->SR);
    printf("    TX empty:  %s\n", (SIM_UART->SR & UART_SR_TXE) ? "Yes" : "No");
    printf("    RX ready:  %s\n", (SIM_UART->SR & UART_SR_RXNE) ? "Yes" : "No");

    printf("\n  Pros: Most readable; bit names match datasheet\n");
    printf("  Cons: More definitions to maintain\n\n");
}

/* ================================================================
 * TECHNIQUE 4: Function-based HAL (Hardware Abstraction Layer)
 *
 * Wrap register access in functions for portability and testability.
 * ================================================================ */

typedef enum {
    UART_WORDLEN_7 = 0,
    UART_WORDLEN_8 = 1,
    UART_WORDLEN_9 = 2
} UART_WordLength;

typedef enum {
    UART_STOPBITS_1   = 0,
    UART_STOPBITS_0_5 = 1,
    UART_STOPBITS_2   = 2,
    UART_STOPBITS_1_5 = 3
} UART_StopBits;

typedef struct {
    uint32_t         baudrate;
    UART_WordLength  word_length;
    UART_StopBits    stop_bits;
    uint8_t          parity_enable;
    uint8_t          tx_enable;
    uint8_t          rx_enable;
} UART_Config;

static int hal_uart_init(UART_TypeDef *uart, const UART_Config *config) {
    /* Disable UART during configuration */
    uart->CR &= ~UART_CR_EN;

    /* Set word length */
    uart->CR &= ~UART_CR_WLEN_MASK;
    uart->CR |= ((uint32_t)config->word_length << 12);

    /* Set baud rate (simplified: assumes 36 MHz clock) */
    uart->BRR = 36000000 / config->baudrate;

    /* Enable TX/RX as configured */
    if (config->tx_enable) uart->CR |= UART_CR_TE;
    if (config->rx_enable) uart->CR |= UART_CR_RE;

    /* Enable UART */
    uart->CR |= UART_CR_EN;

    return 0;
}

static void demo_hal_functions(void) {
    printf("=== Technique 4: Function-Based HAL ===\n\n");

    memset(sim_uart_memory, 0, sizeof(sim_uart_memory));

    UART_Config cfg = {
        .baudrate    = 115200,
        .word_length = UART_WORDLEN_8,
        .stop_bits   = UART_STOPBITS_1,
        .parity_enable = 0,
        .tx_enable   = 1,
        .rx_enable   = 1,
    };

    hal_uart_init(SIM_UART, &cfg);

    printf("  After hal_uart_init(115200, 8-N-1):\n");
    printf("    CR  = 0x%08X\n", SIM_UART->CR);
    printf("    BRR = 0x%08X (%u)\n", SIM_UART->BRR, SIM_UART->BRR);

    printf("\n  Pros: Portable, testable, hides hardware details\n");
    printf("  Cons: Function call overhead (minimal on modern MCUs)\n\n");
}

/* ================================================================
 * TECHNIQUE 5: Read-modify-write safety
 *
 * Demonstrates the subtle bugs that can arise with register access.
 * ================================================================ */

static void demo_rmw_safety(void) {
    printf("=== Technique 5: Read-Modify-Write Safety ===\n\n");

    memset(sim_uart_memory, 0, sizeof(sim_uart_memory));
    SIM_UART->CR = 0xFF;

    printf("  Initial CR = 0x%08X\n", SIM_UART->CR);

    /*
     * DANGEROUS: This reads CR, ORs, and writes back.
     * If an interrupt modifies CR between the read and write,
     * the interrupt's change is lost!
     */
    printf("\n  Read-Modify-Write hazard:\n");
    printf("    Thread: reads CR (0x%08X)\n", SIM_UART->CR);
    printf("    IRQ:    sets bit 15 -> CR = 0x%08X\n", SIM_UART->CR | (1 << 15));
    printf("    Thread: writes back OR'd value -> bit 15 LOST!\n");

    /*
     * SAFE approaches:
     * 1. Disable interrupts around the RMW
     * 2. Use the BSRR register (if available) for atomic set/clear
     * 3. Use bit-banding (ARM Cortex-M)
     */
    printf("\n  Safe alternatives:\n");
    printf("    1. __disable_irq(); reg |= bit; __enable_irq();\n");
    printf("    2. GPIO->BSRR = (1 << pin);  // Atomic set\n");
    printf("    3. BITBAND_PERIPH(&reg, bit) = 1;  // Atomic\n");

    /* Demonstrate atomic set/reset register pattern */
    uint32_t bsrr = 0;
    uint32_t odr  = 0x00FF;

    printf("\n  Atomic GPIO BSRR pattern:\n");
    printf("    ODR before: 0x%04X\n", odr);

    /* Set pin 8 via BSRR lower 16 bits */
    bsrr = (1 << 8);           /* Set pin 8 */
    odr |= (bsrr & 0xFFFF);   /* Simulate BSRR effect */
    printf("    BSRR = 0x%08X -> set pin 8 -> ODR = 0x%04X\n", bsrr, odr);

    /* Clear pin 3 via BSRR upper 16 bits */
    bsrr = (1 << (3 + 16));
    odr &= ~((bsrr >> 16) & 0xFFFF);
    printf("    BSRR = 0x%08X -> clr pin 3 -> ODR = 0x%04X\n", bsrr, odr);
    printf("\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Memory-Mapped Register Access Patterns  ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_direct_define();
    demo_struct_overlay();
    demo_named_bits();
    demo_hal_functions();
    demo_rmw_safety();

    printf("═══ End of Register Access Demo ═══\n");
    return 0;
}
