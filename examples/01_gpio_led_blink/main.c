/**
 * Example 01: GPIO LED Blink
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Toggles an LED connected to PA5 (the on-board LED on many Nucleo boards)
 * at approximately 1 Hz using a simple software delay.
 *
 * Concepts demonstrated:
 *   - Memory-mapped register access
 *   - Clock gating (RCC)
 *   - GPIO output configuration
 *   - Volatile keyword usage
 *   - Bit manipulation
 */

#include <stdint.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE + 0x3800)
#define GPIOA_BASE        (AHB1_BASE + 0x0000)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

/* RCC registers */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)

/* GPIOA registers */
#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)   /* Mode register         */
#define GPIOA_OTYPER      REG32(GPIOA_BASE + 0x04)   /* Output type           */
#define GPIOA_OSPEEDR     REG32(GPIOA_BASE + 0x08)   /* Output speed          */
#define GPIOA_PUPDR       REG32(GPIOA_BASE + 0x0C)   /* Pull-up/pull-down     */
#define GPIOA_ODR         REG32(GPIOA_BASE + 0x14)   /* Output data register  */
#define GPIOA_BSRR        REG32(GPIOA_BASE + 0x18)   /* Bit set/reset         */

/* ───────────────────── Constants ────────────────────────── */

#define LED_PIN           5     /* PA5 — on-board LED on Nucleo-F4 boards */

/* Bit helpers */
#define BIT(n)            (1UL << (n))

/* ───────────────────── Delay ────────────────────────────── */

/**
 * Crude software delay.  The 'volatile' counter variable prevents the
 * compiler from optimizing the loop away.  This is NOT accurate — use a
 * hardware timer for real applications (see example 03).
 */
static void delay(volatile uint32_t count)
{
    while (count--) {
        /* spin */
    }
}

/* ───────────────────── GPIO Setup ───────────────────────── */

static void gpio_init(void)
{
    /*
     * Step 1: Enable the GPIOA peripheral clock.
     *
     * RCC_AHB1ENR bit 0 = GPIOAEN.
     * Without this, all writes to GPIOA registers are ignored.
     */
    RCC_AHB1ENR |= BIT(0);

    /*
     * Step 2: Configure PA5 as general-purpose output.
     *
     * MODER register: 2 bits per pin.
     *   00 = Input (reset state)
     *   01 = General-purpose output
     *   10 = Alternate function
     *   11 = Analog
     *
     * For pin 5: bits [11:10].
     */
    GPIOA_MODER &= ~(0x03UL << (LED_PIN * 2));   /* Clear mode bits      */
    GPIOA_MODER |=  (0x01UL << (LED_PIN * 2));    /* Set to output (01)   */

    /*
     * Step 3 (optional): Configure output type, speed, pull-up/down.
     *
     * Defaults after reset are fine for a simple LED:
     *   - Push-pull output (OTYPER bit = 0)
     *   - Low speed (OSPEEDR bits = 00)
     *   - No pull-up/pull-down (PUPDR bits = 00)
     */
    GPIOA_OTYPER  &= ~BIT(LED_PIN);               /* Push-pull            */
    GPIOA_OSPEEDR &= ~(0x03UL << (LED_PIN * 2));   /* Low speed            */
    GPIOA_PUPDR   &= ~(0x03UL << (LED_PIN * 2));   /* No pull              */
}

/* ───────────────────── LED Control ──────────────────────── */

static void led_on(void)
{
    /*
     * BSRR (Bit Set/Reset Register):
     *   Lower 16 bits: write 1 to SET the corresponding ODR bit.
     *   Upper 16 bits: write 1 to RESET the corresponding ODR bit.
     *
     * This is an atomic operation — no read-modify-write needed.
     */
    GPIOA_BSRR = BIT(LED_PIN);           /* Set PA5 high */
}

static void led_off(void)
{
    GPIOA_BSRR = BIT(LED_PIN + 16);      /* Reset PA5 (upper half) */
}

static void led_toggle(void)
{
    /*
     * XOR the Output Data Register.  This is a read-modify-write
     * operation, so it's NOT atomic.  In ISR-shared scenarios,
     * use BSRR with explicit state tracking instead.
     */
    GPIOA_ODR ^= BIT(LED_PIN);
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    gpio_init();

    /* Method 1: Toggle using XOR on ODR */
    while (1) {
        led_toggle();
        delay(1000000);   /* ~500 ms at 16 MHz (approximate) */
    }

    /* Method 2 (alternative): Explicit on/off using BSRR
     *
     * while (1) {
     *     led_on();
     *     delay(1000000);
     *     led_off();
     *     delay(1000000);
     * }
     */

    return 0;  /* never reached */
}
