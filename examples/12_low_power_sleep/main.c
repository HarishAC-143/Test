/**
 * Example 12: Low-Power Sleep Modes
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Demonstrates entering and waking from various low-power modes:
 *   1. Sleep mode — CPU halted, peripherals active, wake on any interrupt
 *   2. Stop mode  — all clocks stopped, RAM retained, wake on EXTI
 *   3. Standby mode — lowest power, RAM lost, wake on WKUP pin or RTC
 *
 * A button on PC13 wakes the MCU from sleep. An RTC alarm wakes
 * from stop/standby modes.
 *
 * Concepts demonstrated:
 *   - ARM Cortex-M WFI / WFE instructions
 *   - SCB->SCR SLEEPDEEP bit
 *   - PWR peripheral configuration for stop/standby
 *   - EXTI (External Interrupt) for wake-up
 *   - Clock reconfiguration after wake-up from stop mode
 *   - Power consumption comparison
 */

#include <stdint.h>
#include <stdbool.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define APB1_BASE         (PERIPH_BASE)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE + 0x3800)
#define GPIOA_BASE        (AHB1_BASE + 0x0000)
#define GPIOC_BASE        (AHB1_BASE + 0x0800)
#define PWR_BASE          (APB1_BASE + 0x7000)
#define EXTI_BASE         (APB2_BASE_FIX + 0x3C00)
#define SYSCFG_BASE       (APB2_BASE_FIX + 0x3800)

#define APB2_BASE_FIX     (PERIPH_BASE + 0x00010000)

/* System Control Block */
#define SCB_SCR           (*(volatile uint32_t *)0xE000ED10)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

/* RCC */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)
#define RCC_APB2ENR       REG32(RCC_BASE + 0x44)

/* GPIOA */
#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_ODR         REG32(GPIOA_BASE + 0x14)
#define GPIOA_BSRR        REG32(GPIOA_BASE + 0x18)

/* GPIOC */
#define GPIOC_MODER       REG32(GPIOC_BASE + 0x00)
#define GPIOC_PUPDR       REG32(GPIOC_BASE + 0x0C)
#define GPIOC_IDR         REG32(GPIOC_BASE + 0x10)

/* PWR (Power Control) */
#define PWR_CR            REG32(PWR_BASE + 0x00)
#define PWR_CSR           REG32(PWR_BASE + 0x04)

/* EXTI (External Interrupt) */
#define EXTI_IMR          REG32(EXTI_BASE + 0x00)   /* Interrupt mask       */
#define EXTI_FTSR         REG32(EXTI_BASE + 0x0C)   /* Falling trigger      */
#define EXTI_PR           REG32(EXTI_BASE + 0x14)   /* Pending register     */

/* SYSCFG */
#define SYSCFG_EXTICR4    REG32(SYSCFG_BASE + 0x14) /* EXTI config for pins 12-15 */

/* NVIC */
#define NVIC_ISER_BASE    ((uint32_t)0xE000E100)
#define NVIC_ISER(n)      REG32(NVIC_ISER_BASE + 4 * (n))

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

#define LED_PIN           5
#define BUTTON_PIN        13

/* EXTI13 IRQ = EXTI15_10_IRQn = IRQ 40 */
#define EXTI15_10_IRQn    40

/* PWR_CR bits */
#define PWR_CR_LPDS       BIT(0)     /* Low-power deepsleep        */
#define PWR_CR_PDDS       BIT(1)     /* Power down deepsleep (standby) */
#define PWR_CR_CWUF       BIT(2)     /* Clear wakeup flag           */

/* SCB_SCR bits */
#define SCR_SLEEPDEEP     BIT(2)
#define SCR_SLEEPONEXIT   BIT(1)

/* UART (minimal) */
#define USART2_BASE       (APB1_BASE + 0x4400)
#define GPIOA_AFRL        REG32(GPIOA_BASE + 0x20)
#define USART2_SR         REG32(USART2_BASE + 0x00)
#define USART2_DR         REG32(USART2_BASE + 0x04)
#define USART2_BRR        REG32(USART2_BASE + 0x08)
#define USART2_CR1_REG    REG32(USART2_BASE + 0x0C)

/* ───────────────────── UART ─────────────────────────────── */

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

/* ───────────────────── Delay ────────────────────────────── */

static void delay(volatile uint32_t count)
{
    while (count--) { }
}

/* ───────────────────── GPIO Setup ───────────────────────── */

static void gpio_init(void)
{
    RCC_AHB1ENR |= BIT(0) | BIT(2);

    /* PA5: output (LED) */
    GPIOA_MODER = (GPIOA_MODER & ~(0x03UL << (LED_PIN * 2)))
                 | (0x01UL << (LED_PIN * 2));

    /* PC13: input with pull-up (button) */
    GPIOC_MODER &= ~(0x03UL << (BUTTON_PIN * 2));
    GPIOC_PUPDR = (GPIOC_PUPDR & ~(0x03UL << (BUTTON_PIN * 2)))
                 | (0x01UL << (BUTTON_PIN * 2));
}

/* ───────────────────── EXTI Setup (Wake on Button) ──────── */

static volatile bool wakeup_flag = false;

void EXTI15_10_IRQHandler(void)
{
    if (EXTI_PR & BIT(BUTTON_PIN)) {
        EXTI_PR = BIT(BUTTON_PIN);   /* Clear pending bit (write 1 to clear) */
        wakeup_flag = true;
    }
}

static void exti_button_init(void)
{
    /* Enable SYSCFG clock (needed to configure EXTI source) */
    RCC_APB2ENR |= BIT(14);

    /*
     * SYSCFG_EXTICR4: map EXTI13 to Port C.
     * EXTICR4 covers pins 12–15; pin 13 is bits [7:4].
     * Port C = 0x02.
     */
    SYSCFG_EXTICR4 = (SYSCFG_EXTICR4 & ~(0x0FUL << 4)) | (0x02UL << 4);

    /* Enable EXTI13: unmask interrupt */
    EXTI_IMR |= BIT(BUTTON_PIN);

    /* Trigger on falling edge (button press → PC13 goes LOW) */
    EXTI_FTSR |= BIT(BUTTON_PIN);

    /* Enable in NVIC */
    NVIC_ISER(EXTI15_10_IRQn / 32) |= BIT(EXTI15_10_IRQn % 32);
}

/* ───────────────────── Sleep Modes ──────────────────────── */

/**
 * Enter Sleep mode (WFI).
 *
 * - CPU clock is stopped.
 * - All peripherals continue running.
 * - Wakes up on any enabled interrupt.
 * - Typical power: 5–10 mA (peripheral-dependent).
 */
static void enter_sleep_mode(void)
{
    /* Ensure SLEEPDEEP is clear (sleep, not deep sleep) */
    SCB_SCR &= ~SCR_SLEEPDEEP;

    /* Wait For Interrupt — CPU halts here */
    __asm volatile ("WFI" ::: "memory");

    /* Execution resumes here after interrupt */
}

/**
 * Enter Stop mode.
 *
 * - All clocks stopped (HSI, HSE, PLL).
 * - 1.2V regulator in low-power mode.
 * - RAM and register contents retained.
 * - Wake-up sources: EXTI lines (including RTC alarm).
 * - After wake-up, HSI is the system clock — must reconfigure if needed.
 * - Typical power: 10–30 µA.
 */
static void enter_stop_mode(void)
{
    /* Enable PWR clock */
    RCC_APB1ENR |= BIT(28);

    /* Select low-power regulator for Stop mode, clear PDDS (not standby) */
    PWR_CR &= ~PWR_CR_PDDS;
    PWR_CR |= PWR_CR_LPDS;

    /* Set SLEEPDEEP bit */
    SCB_SCR |= SCR_SLEEPDEEP;

    /* Clear wake-up flag */
    PWR_CR |= PWR_CR_CWUF;

    /* Enter Stop mode */
    __asm volatile ("WFI" ::: "memory");

    /* ── After wake-up: HSI is now the clock source ── */
    SCB_SCR &= ~SCR_SLEEPDEEP;

    /*
     * If you were using HSE/PLL before stop mode, you must
     * reconfigure the clock tree here.  For HSI (16 MHz),
     * no reconfiguration is needed.
     */
}

/**
 * Enter Standby mode.
 *
 * - Lowest power (~2 µA).
 * - 1.2V regulator OFF — RAM contents LOST.
 * - Wake-up causes a full system reset (execution starts from the beginning).
 * - Wake-up sources: WKUP pin (PA0), RTC alarm/tamper, IWDG reset.
 */
static void enter_standby_mode(void)
{
    RCC_APB1ENR |= BIT(28);

    /* Set PDDS (Power Down Deep Sleep = standby) */
    PWR_CR |= PWR_CR_PDDS;

    /* Clear wake-up flag */
    PWR_CR |= PWR_CR_CWUF;

    /* Enable WKUP pin (PA0) — set EWUP bit in PWR_CSR */
    PWR_CSR |= BIT(8);   /* EWUP */

    /* Set SLEEPDEEP */
    SCB_SCR |= SCR_SLEEPDEEP;

    /* Enter standby — this never returns; MCU resets on wake-up */
    __asm volatile ("WFI" ::: "memory");

    /* Never reached */
}

/* ───────────────────── LED Feedback ─────────────────────── */

static void blink_led(uint8_t count, uint32_t on_time, uint32_t off_time)
{
    for (uint8_t i = 0; i < count; i++) {
        GPIOA_BSRR = BIT(LED_PIN);
        delay(on_time);
        GPIOA_BSRR = BIT(LED_PIN + 16);
        delay(off_time);
    }
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    gpio_init();
    uart_init();
    exti_button_init();

    uart_puts("\r\n=== Low-Power Sleep Mode Example ===\r\n\r\n");

    /* 3 quick blinks to indicate startup */
    blink_led(3, 200000, 200000);

    uint32_t cycle = 0;

    while (1) {
        cycle++;
        wakeup_flag = false;

        uart_puts("Cycle ");
        char c = '0' + (cycle % 10);
        uart_putc(c);
        uart_puts(": Active — doing work...\r\n");

        /* Simulate some work */
        blink_led(2, 500000, 500000);

        /*
         * Demonstrate Sleep mode:
         * CPU stops, wakes on button press (EXTI13 interrupt).
         */
        uart_puts("Entering SLEEP mode (press button to wake)...\r\n");

        /* Wait for UART TX to complete before sleeping */
        delay(100000);

        GPIOA_BSRR = BIT(LED_PIN + 16);   /* LED off while sleeping */
        enter_sleep_mode();

        /* Woke up! */
        GPIOA_BSRR = BIT(LED_PIN);
        uart_puts("Woke up from SLEEP mode!\r\n\r\n");

        delay(2000000);

        /*
         * To demonstrate Stop mode, uncomment the following:
         *
         * uart_puts("Entering STOP mode...\r\n");
         * delay(100000);
         * enter_stop_mode();
         * uart_init();  // Re-initialize UART (clocks were stopped)
         * uart_puts("Woke up from STOP mode!\r\n");
         */

        /*
         * To demonstrate Standby mode, uncomment the following:
         * WARNING: RAM contents are lost — MCU does a full reset on wake-up.
         *
         * uart_puts("Entering STANDBY mode...\r\n");
         * delay(100000);
         * enter_standby_mode();
         * // Never reached — MCU resets
         */
    }

    return 0;
}

/*
 * ───────────────────── Power Consumption Summary ─────────────
 *
 * Mode        Typical Current    Wake-up Time     RAM
 * ─────────── ────────────────── ──────────────── ──────────
 * Run         15–100 mA          N/A              Retained
 * Sleep       2–10 mA            < 1 µs           Retained
 * Stop        10–30 µA           ~4 µs (HSI)      Retained
 * Standby     2–3 µA             Reset (~ms)      LOST
 *
 * For battery life estimation:
 *
 *   Battery capacity: 500 mAh
 *   Average current:  50 µA (mostly in Stop, brief Run periods)
 *   Life = 500 mAh / 0.05 mA = 10,000 hours ≈ 1.14 years
 */
