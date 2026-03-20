/**
 * @file    button_debounce.c
 * @brief   Button input with software debouncing.
 * @target  STM32F4xx (Nucleo: user button on PC13, LED on PA5)
 *
 * Demonstrates:
 *  - Configuring a GPIO as input with pull-up
 *  - Software debounce algorithm
 *  - Toggle-on-press pattern
 *
 * Mechanical buttons "bounce" — they make and break contact several times
 * in a few milliseconds before settling. Without debouncing, a single press
 * may register as 5-50 presses.
 *
 * Bounce waveform (zoomed in, ~5ms):
 *   ────┐ ┌┐ ┌─┐ ┌──────────────
 *       └─┘└─┘ └─┘
 *       ▲ bouncing  ▲ stable LOW
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))

#define GPIOA_BASE      0x40020000U
#define GPIOA_MODER     (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_ODR       (*(volatile uint32_t *)(GPIOA_BASE + 0x14))
#define GPIOA_BSRR      (*(volatile uint32_t *)(GPIOA_BASE + 0x18))

#define GPIOC_BASE      0x40020800U
#define GPIOC_MODER     (*(volatile uint32_t *)(GPIOC_BASE + 0x00))
#define GPIOC_PUPDR     (*(volatile uint32_t *)(GPIOC_BASE + 0x0C))
#define GPIOC_IDR       (*(volatile uint32_t *)(GPIOC_BASE + 0x10))

#define LED_PIN         5   /* PA5 */
#define BUTTON_PIN      13  /* PC13 — active LOW (pressed = 0) */

/* ========================================================================== */
/*  SysTick for Timing                                                         */
/* ========================================================================== */

#define STK_CTRL    (*(volatile uint32_t *)0xE000E010)
#define STK_LOAD    (*(volatile uint32_t *)0xE000E014)
#define STK_VAL     (*(volatile uint32_t *)0xE000E018)

volatile uint32_t tick_ms = 0;

void SysTick_Handler(void)
{
    tick_ms++;
}

static uint32_t get_tick(void)
{
    return tick_ms;
}

static void systick_init(uint32_t cpu_freq_hz)
{
    STK_LOAD = (cpu_freq_hz / 1000) - 1;
    STK_VAL  = 0;
    STK_CTRL = 0x07;  /* Enable, interrupt, processor clock */
}

/* ========================================================================== */
/*  GPIO Initialization                                                        */
/* ========================================================================== */

static void gpio_init(void)
{
    /* Enable clocks for GPIOA and GPIOC */
    RCC_AHB1ENR |= (1U << 0) | (1U << 2);

    /* PA5: Output (LED) */
    GPIOA_MODER &= ~(3U << (LED_PIN * 2));
    GPIOA_MODER |=  (1U << (LED_PIN * 2));

    /* PC13: Input (default after reset — MODER bits are 00) */
    GPIOC_MODER &= ~(3U << (BUTTON_PIN * 2));

    /*
     * Enable internal pull-up on PC13.
     * The Nucleo board has an external pull-up, but enabling the internal
     * one doesn't hurt and makes the code more portable.
     * PUPDR: 00 = none, 01 = pull-up, 10 = pull-down
     */
    GPIOC_PUPDR &= ~(3U << (BUTTON_PIN * 2));
    GPIOC_PUPDR |=  (1U << (BUTTON_PIN * 2));
}

/* ========================================================================== */
/*  Debounce Algorithm                                                         */
/* ========================================================================== */

#define DEBOUNCE_DELAY_MS   50

typedef struct {
    bool     current_state;    /* Debounced state                */
    bool     last_raw;         /* Previous raw reading           */
    uint32_t last_change_time; /* Timestamp of last raw change   */
} debounce_t;

/**
 * Initialize debounce state.
 */
static void debounce_init(debounce_t *db, bool initial_state)
{
    db->current_state    = initial_state;
    db->last_raw         = initial_state;
    db->last_change_time = 0;
}

/**
 * Update debounce state with a new raw reading.
 *
 * Algorithm: If the raw reading differs from the debounced state and has
 * been stable for DEBOUNCE_DELAY_MS, accept it as the new state.
 *
 * @return true if the debounced state changed this call
 */
static bool debounce_update(debounce_t *db, bool raw_state)
{
    bool state_changed = false;

    if (raw_state != db->last_raw) {
        db->last_change_time = get_tick();
        db->last_raw = raw_state;
    }

    if (raw_state != db->current_state) {
        if ((get_tick() - db->last_change_time) >= DEBOUNCE_DELAY_MS) {
            db->current_state = raw_state;
            state_changed = true;
        }
    }

    return state_changed;
}

/* ========================================================================== */
/*  Alternative: Integration-Based Debounce                                    */
/* ========================================================================== */

/**
 * Vertical counter debounce — processes multiple buttons simultaneously
 * using bitwise operations. Efficient for systems with many buttons.
 *
 * Each bit position in 'state' represents one button.
 */
typedef struct {
    uint8_t integrator;   /* Vertical counter per button */
    uint8_t state;        /* Debounced state             */
} multi_debounce_t;

#define INTEGRATOR_MAX  10

static void multi_debounce_init(multi_debounce_t *db)
{
    db->integrator = 0;
    db->state = 0;
}

/**
 * Call this at a fixed rate (e.g., every 1 ms from SysTick).
 * @param raw  Raw button state (1 = pressed)
 * @return     Debounced state (1 = pressed)
 */
static uint8_t multi_debounce_update(multi_debounce_t *db, uint8_t raw)
{
    if (raw == 0) {
        if (db->integrator > 0)
            db->integrator--;
    } else {
        if (db->integrator < INTEGRATOR_MAX)
            db->integrator++;
    }

    if (db->integrator == 0)
        db->state = 0;
    else if (db->integrator >= INTEGRATOR_MAX)
        db->state = 1;

    return db->state;
}

/* ========================================================================== */
/*  LED Control                                                                */
/* ========================================================================== */

static void led_toggle(void)
{
    GPIOA_ODR ^= (1U << LED_PIN);
}

static bool button_read_raw(void)
{
    /* Active LOW: pressed = IDR bit is 0 */
    return !(GPIOC_IDR & (1U << BUTTON_PIN));
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    gpio_init();
    systick_init(16000000);

    debounce_t button;
    debounce_init(&button, false);

    multi_debounce_t alt_button;
    multi_debounce_init(&alt_button);
    (void)alt_button;

    while (1) {
        bool raw = button_read_raw();
        bool changed = debounce_update(&button, raw);

        /* Toggle LED on each press (rising edge of debounced signal) */
        if (changed && button.current_state) {
            led_toggle();
        }
    }
}
