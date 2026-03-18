/**
 * Example 11: Watchdog Timer (IWDG)
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Configures the Independent Watchdog (IWDG) with a ~1 second timeout.
 * The main loop periodically "kicks" (refreshes) the watchdog.  If the
 * firmware ever hangs or enters an infinite loop, the watchdog will
 * reset the MCU — a critical safety mechanism.
 *
 * A deliberate hang is triggered after 10 successful iterations to
 * demonstrate the watchdog reset behavior.
 *
 * Concepts demonstrated:
 *   - IWDG key register protocol
 *   - Prescaler and reload configuration
 *   - Watchdog refresh in normal operation
 *   - Reset detection (was the last reset caused by the watchdog?)
 *   - Window watchdog (WWDG) overview
 */

#include <stdint.h>
#include <stdbool.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define APB1_BASE         (PERIPH_BASE)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE + 0x3800)
#define GPIOA_BASE        (AHB1_BASE + 0x0000)
#define IWDG_BASE         (APB1_BASE + 0x3000)
#define USART2_BASE       (APB1_BASE + 0x4400)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)
#define RCC_CSR           REG32(RCC_BASE + 0x74)

#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_ODR         REG32(GPIOA_BASE + 0x14)

/*
 * IWDG Registers:
 *
 * KR  — Key Register: controls start/reload/unlock.
 * PR  — Prescaler Register: divides the 32 kHz LSI clock.
 * RLR — Reload Register: counter value loaded on refresh.
 * SR  — Status Register: update flags.
 */
#define IWDG_KR           REG32(IWDG_BASE + 0x00)
#define IWDG_PR           REG32(IWDG_BASE + 0x04)
#define IWDG_RLR          REG32(IWDG_BASE + 0x08)
#define IWDG_SR           REG32(IWDG_BASE + 0x0C)

/* USART2 (minimal) */
#define GPIOA_AFRL        REG32(GPIOA_BASE + 0x20)
#define USART2_SR         REG32(USART2_BASE + 0x00)
#define USART2_DR         REG32(USART2_BASE + 0x04)
#define USART2_BRR        REG32(USART2_BASE + 0x08)
#define USART2_CR1_REG    REG32(USART2_BASE + 0x0C)

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

/*
 * IWDG Key values (magic numbers mandated by hardware):
 *   0x5555 = Unlock PR and RLR registers for writing
 *   0xAAAA = Reload the counter (kick the watchdog)
 *   0xCCCC = Start the watchdog
 */
#define IWDG_KEY_UNLOCK   0x5555
#define IWDG_KEY_RELOAD   0xAAAA
#define IWDG_KEY_START    0xCCCC

/*
 * Watchdog timeout calculation:
 *
 * LSI clock ≈ 32 kHz.
 * Prescaler = /32  → WDG clock = 32000 / 32 = 1000 Hz (1 ms)
 * Reload    = 999  → Timeout   = 1000 × 1 ms = 1.0 s
 *
 * PR values: 0=/4, 1=/8, 2=/16, 3=/32, 4=/64, 5=/128, 6=/256
 */
#define IWDG_PRESCALER    3     /* /32 */
#define IWDG_RELOAD       999   /* 1000 ms at 1 kHz */

/* RCC_CSR watchdog reset flag */
#define RCC_CSR_IWDGRSTF  BIT(29)
#define RCC_CSR_RMVF      BIT(24)   /* Remove reset flags */

#define LED_PIN           5

/* ───────────────────── UART (minimal) ───────────────────── */

static void uart_init(void)
{
    RCC_AHB1ENR |= BIT(0);
    RCC_APB1ENR |= BIT(17);
    GPIOA_MODER = (GPIOA_MODER & ~(0x03UL << 4)) | (0x02UL << 4);
    GPIOA_AFRL  = (GPIOA_AFRL  & ~(0x0FUL << 8)) | (0x07UL << 8);
    USART2_CR1_REG = 0;
    USART2_BRR = 0x008B;
    USART2_CR1_REG = BIT(13) | BIT(3);
}

static void uart_putc(uint8_t ch) { while (!(USART2_SR & BIT(7))); USART2_DR = ch; }
static void uart_puts(const char *s) { while (*s) uart_putc(*s++); }

static void uart_print_uint(uint32_t val)
{
    char buf[11];
    int i = 0;
    if (val == 0) { uart_putc('0'); return; }
    while (val > 0) { buf[i++] = '0' + (val % 10); val /= 10; }
    while (i > 0) uart_putc(buf[--i]);
}

/* ───────────────────── Delay ────────────────────────────── */

static void delay(volatile uint32_t count)
{
    while (count--) { }
}

/* ───────────────────── IWDG Functions ───────────────────── */

/**
 * Check if the last MCU reset was caused by the IWDG.
 */
static bool iwdg_was_reset_source(void)
{
    return (RCC_CSR & RCC_CSR_IWDGRSTF) != 0;
}

/**
 * Clear the reset source flags in RCC_CSR.
 */
static void iwdg_clear_reset_flags(void)
{
    RCC_CSR |= RCC_CSR_RMVF;
}

/**
 * Initialize and start the Independent Watchdog.
 *
 * WARNING: Once started, the IWDG CANNOT be stopped!
 * It can only be stopped by a system reset.
 */
static void iwdg_init(void)
{
    /* Unlock the PR and RLR registers */
    IWDG_KR = IWDG_KEY_UNLOCK;

    /* Set prescaler */
    IWDG_PR = IWDG_PRESCALER;

    /* Set reload value */
    IWDG_RLR = IWDG_RELOAD;

    /* Wait until the prescaler and reload values are updated */
    while (IWDG_SR != 0) { }

    /* Reload the counter */
    IWDG_KR = IWDG_KEY_RELOAD;

    /* Start the watchdog */
    IWDG_KR = IWDG_KEY_START;
}

/**
 * Kick (refresh) the watchdog — must be called before timeout.
 */
static void iwdg_refresh(void)
{
    IWDG_KR = IWDG_KEY_RELOAD;
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    uart_init();

    /* LED for visual feedback */
    RCC_AHB1ENR |= BIT(0);
    GPIOA_MODER = (GPIOA_MODER & ~(0x03UL << (LED_PIN * 2)))
                 | (0x01UL << (LED_PIN * 2));

    uart_puts("\r\n=== Watchdog Timer Example ===\r\n");

    /* Check if we got here because of a watchdog reset */
    if (iwdg_was_reset_source()) {
        uart_puts("*** WATCHDOG RESET DETECTED ***\r\n");
        uart_puts("The MCU was reset by the IWDG.\r\n\r\n");
        iwdg_clear_reset_flags();
    } else {
        uart_puts("Normal power-on reset.\r\n\r\n");
        iwdg_clear_reset_flags();
    }

    /* Start the watchdog with a 1-second timeout */
    iwdg_init();
    uart_puts("IWDG started with ~1 second timeout.\r\n");

    uint32_t iteration = 0;

    while (1) {
        iteration++;

        uart_puts("Iteration ");
        uart_print_uint(iteration);
        uart_puts(" — kicking watchdog...\r\n");

        /* Refresh the watchdog before it expires */
        iwdg_refresh();

        /* Toggle LED to show we're alive */
        GPIOA_ODR ^= BIT(LED_PIN);

        /* Simulate work (~500 ms) */
        delay(4000000);

        /*
         * After 10 iterations, simulate a firmware hang.
         * The watchdog will NOT be refreshed, causing a reset
         * after ~1 second.
         */
        if (iteration >= 10) {
            uart_puts("\r\n!!! Simulating firmware hang — no more kicks !!!\r\n");
            uart_puts("Watchdog reset expected in ~1 second...\r\n");
            while (1) { /* Hang forever — watchdog will save us */ }
        }
    }

    return 0;
}
