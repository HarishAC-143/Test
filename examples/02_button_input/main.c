/**
 * Example 02: Button Input with Debouncing
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Reads a push-button on PC13 (the on-board USER button on many Nucleo
 * boards, active low) and toggles an LED on PA5 with each press.
 *
 * Two debounce methods are demonstrated:
 *   1. Simple blocking delay debounce
 *   2. Integration-based (counter) debounce — non-blocking
 *
 * Concepts demonstrated:
 *   - GPIO input configuration
 *   - Pull-up/pull-down resistors
 *   - Software debouncing techniques
 *   - Edge detection (press vs. held)
 */

#include <stdint.h>
#include <stdbool.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE + 0x3800)
#define GPIOA_BASE        (AHB1_BASE + 0x0000)
#define GPIOC_BASE        (AHB1_BASE + 0x0800)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

/* RCC */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)

/* GPIOA */
#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_ODR         REG32(GPIOA_BASE + 0x14)

/* GPIOC */
#define GPIOC_MODER       REG32(GPIOC_BASE + 0x00)
#define GPIOC_PUPDR       REG32(GPIOC_BASE + 0x0C)
#define GPIOC_IDR         REG32(GPIOC_BASE + 0x10)

/* ───────────────────── Pin Definitions ──────────────────── */

#define LED_PIN           5     /* PA5  */
#define BTN_PIN           13    /* PC13 (active low on Nucleo boards) */

#define BIT(n)            (1UL << (n))

/* ───────────────────── Delay ────────────────────────────── */

static void delay(volatile uint32_t count)
{
    while (count--) { }
}

/* ───────────────────── GPIO Setup ───────────────────────── */

static void gpio_init(void)
{
    /* Enable clocks for GPIOA and GPIOC */
    RCC_AHB1ENR |= BIT(0) | BIT(2);

    /* PA5: output (LED) */
    GPIOA_MODER &= ~(0x03UL << (LED_PIN * 2));
    GPIOA_MODER |=  (0x01UL << (LED_PIN * 2));

    /*
     * PC13: input (button)
     *
     * MODER = 00 → input (this is the default after reset).
     * Enable internal pull-up since the button connects PC13 to GND
     * when pressed (active low).
     *
     * PUPDR: 2 bits per pin
     *   00 = No pull
     *   01 = Pull-up
     *   10 = Pull-down
     */
    GPIOC_MODER &= ~(0x03UL << (BTN_PIN * 2));    /* Input mode */
    GPIOC_PUPDR &= ~(0x03UL << (BTN_PIN * 2));
    GPIOC_PUPDR |=  (0x01UL << (BTN_PIN * 2));     /* Pull-up   */
}

/* ───────────────────── Button Read ──────────────────────── */

/**
 * Returns true if the button is currently pressed.
 * The button is active low: IDR bit = 0 when pressed.
 */
static bool button_raw_read(void)
{
    return !(GPIOC_IDR & BIT(BTN_PIN));
}

/* ───────────────────── Method 1: Blocking Delay Debounce ── */

/**
 * Wait for a stable button state.  After detecting a state change,
 * delay ~20 ms and re-read.  If the state is still the same, accept it.
 *
 * Pros: Very simple.
 * Cons: Blocks the CPU during the delay — nothing else can run.
 */
static bool button_debounce_blocking(void)
{
    static bool last_state = false;
    bool current = button_raw_read();

    if (current != last_state) {
        delay(20000);                 /* ~20 ms debounce delay */
        current = button_raw_read();  /* re-sample             */
        last_state = current;
    }

    return current;
}

/* ───────────────────── Method 2: Integration Debounce ───── */

/**
 * Sample the button each call (meant to be called periodically, e.g.,
 * every 1 ms from a timer ISR or polling loop).  Maintain a counter:
 *   - Increment when the button reads "pressed" (up to a threshold).
 *   - Decrement when it reads "released" (down to 0).
 *   - Consider the button pressed when the counter reaches the threshold.
 *   - Consider it released when the counter reaches 0.
 *
 * Pros: Non-blocking, very robust against noise.
 * Cons: Requires periodic calling at a known rate.
 */
#define DEBOUNCE_THRESHOLD  10

typedef struct {
    uint8_t integrator;
    bool    pressed;
} debounce_state_t;

static bool button_debounce_integration(debounce_state_t *state)
{
    bool raw = button_raw_read();

    if (raw) {
        if (state->integrator < DEBOUNCE_THRESHOLD) {
            state->integrator++;
        }
    } else {
        if (state->integrator > 0) {
            state->integrator--;
        }
    }

    if (state->integrator >= DEBOUNCE_THRESHOLD) {
        state->pressed = true;
    } else if (state->integrator == 0) {
        state->pressed = false;
    }

    return state->pressed;
}

/* ───────────────────── Edge Detection ───────────────────── */

/**
 * Detects a rising edge (button just pressed).
 * Returns true only on the transition from "not pressed" to "pressed".
 */
static bool button_pressed_event(bool current_state)
{
    static bool previous_state = false;
    bool event = false;

    if (current_state && !previous_state) {
        event = true;   /* Rising edge detected */
    }

    previous_state = current_state;
    return event;
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    gpio_init();

    debounce_state_t btn_state = { .integrator = 0, .pressed = false };

    while (1) {
        /*
         * Option A: Blocking debounce
         *   bool pressed = button_debounce_blocking();
         *
         * Option B: Integration debounce (preferred)
         */
        bool pressed = button_debounce_integration(&btn_state);

        if (button_pressed_event(pressed)) {
            GPIOA_ODR ^= BIT(LED_PIN);   /* Toggle LED on each press */
        }

        delay(1000);  /* ~1 ms polling interval */
    }

    return 0;
}
