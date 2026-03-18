/**
 * Example 03: Timer and Interrupts
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Configures TIM2 (a 32-bit general-purpose timer) to generate an
 * update interrupt every 500 ms, toggling an LED on PA5.
 *
 * Concepts demonstrated:
 *   - Timer prescaler and auto-reload configuration
 *   - NVIC (Nested Vectored Interrupt Controller) setup
 *   - Writing an Interrupt Service Routine (ISR)
 *   - Volatile flag shared between ISR and main loop
 *   - Clearing interrupt pending flags
 */

#include <stdint.h>
#include <stdbool.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define APB1_BASE         (PERIPH_BASE)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE  + 0x3800)
#define GPIOA_BASE        (AHB1_BASE  + 0x0000)
#define TIM2_BASE         (APB1_BASE  + 0x0000)
#define NVIC_ISER_BASE    ((uint32_t)0xE000E100)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

/* RCC */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)

/* GPIOA */
#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_ODR         REG32(GPIOA_BASE + 0x14)

/* TIM2 */
#define TIM2_CR1          REG32(TIM2_BASE + 0x00)   /* Control register 1   */
#define TIM2_DIER         REG32(TIM2_BASE + 0x0C)   /* DMA/Interrupt enable  */
#define TIM2_SR           REG32(TIM2_BASE + 0x10)   /* Status register       */
#define TIM2_CNT          REG32(TIM2_BASE + 0x24)   /* Counter               */
#define TIM2_PSC          REG32(TIM2_BASE + 0x28)   /* Prescaler             */
#define TIM2_ARR          REG32(TIM2_BASE + 0x2C)   /* Auto-reload           */

/* NVIC */
#define NVIC_ISER(n)      REG32(NVIC_ISER_BASE + 4 * (n))

/* ───────────────────── Constants ────────────────────────── */

#define LED_PIN           5
#define BIT(n)            (1UL << (n))

#define TIM2_IRQn         28    /* TIM2 global interrupt (IRQ number) */

/*
 * System clock assumption: 16 MHz (default HSI on STM32F4).
 *
 * Desired period: 500 ms
 *   PSC  = 15999  → timer clock = 16 MHz / 16000 = 1 kHz (1 ms ticks)
 *   ARR  = 499    → 500 ticks = 500 ms
 */
#define TIMER_PSC         15999
#define TIMER_ARR         499

/* ───────────────────── Shared State ─────────────────────── */

/*
 * This flag is set by the ISR and cleared by main().
 * It MUST be volatile because it is modified asynchronously.
 */
static volatile bool timer_flag = false;

/* ───────────────────── GPIO Setup ───────────────────────── */

static void gpio_init(void)
{
    RCC_AHB1ENR |= BIT(0);

    GPIOA_MODER &= ~(0x03UL << (LED_PIN * 2));
    GPIOA_MODER |=  (0x01UL << (LED_PIN * 2));
}

/* ───────────────────── Timer Setup ──────────────────────── */

static void timer_init(void)
{
    /* Enable TIM2 clock (APB1 peripheral) */
    RCC_APB1ENR |= BIT(0);

    /* Stop the timer while configuring */
    TIM2_CR1 = 0;

    /* Set prescaler and auto-reload value */
    TIM2_PSC = TIMER_PSC;
    TIM2_ARR = TIMER_ARR;

    /* Reset the counter */
    TIM2_CNT = 0;

    /*
     * Enable update interrupt.
     * DIER bit 0 = UIE (Update Interrupt Enable).
     */
    TIM2_DIER |= BIT(0);

    /*
     * Clear any pending update event flag.
     * SR bit 0 = UIF (Update Interrupt Flag).
     * Flags are cleared by writing 0 (rc_w0).
     */
    TIM2_SR &= ~BIT(0);

    /*
     * Enable TIM2 interrupt in the NVIC.
     * TIM2_IRQn = 28 → ISER[0], bit 28.
     */
    NVIC_ISER(TIM2_IRQn / 32) |= BIT(TIM2_IRQn % 32);

    /*
     * Start the timer.
     * CR1 bit 0 = CEN (Counter Enable).
     */
    TIM2_CR1 |= BIT(0);
}

/* ───────────────────── ISR ──────────────────────────────── */

/**
 * TIM2 interrupt handler.
 *
 * The function name must match the vector table entry for TIM2.
 * In a real project, the startup file / vector table defines this name.
 */
void TIM2_IRQHandler(void)
{
    /* Check that this is indeed an update event */
    if (TIM2_SR & BIT(0)) {
        TIM2_SR &= ~BIT(0);    /* Clear the flag — CRITICAL              */
        timer_flag = true;       /* Signal main loop                       */
    }

    /*
     * NOTE: If you forget to clear the pending flag, the ISR will
     * fire again immediately after returning — effectively locking
     * up the CPU in the ISR.
     */
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    gpio_init();
    timer_init();

    while (1) {
        if (timer_flag) {
            timer_flag = false;
            GPIOA_ODR ^= BIT(LED_PIN);   /* Toggle LED every 500 ms */
        }

        /*
         * The CPU is free to do other work here between timer events.
         * In a real application you might:
         *   - Read sensors
         *   - Process communication
         *   - Run a state machine
         *   - Enter low-power sleep (WFI) and wake on interrupt
         */
    }

    return 0;
}
