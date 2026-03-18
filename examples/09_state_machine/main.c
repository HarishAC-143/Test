/**
 * Example 09: State Machine — Traffic Light Controller
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Implements a traffic light controller using a finite state machine (FSM).
 * Three LEDs (Green=PA0, Yellow=PA1, Red=PA2) cycle through the standard
 * traffic light sequence with configurable timing.
 *
 * Also includes a pedestrian crossing button (PC13) that can request a
 * priority red-light phase.
 *
 * Concepts demonstrated:
 *   - Finite state machine design pattern
 *   - State transition tables
 *   - Non-blocking timing with a tick counter
 *   - Event-driven state transitions (button press)
 *   - Enum-based state representation
 *   - Function pointer dispatch table (alternative approach)
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
#define TIM2_BASE         (APB1_BASE + 0x0000)
#define NVIC_ISER_BASE    ((uint32_t)0xE000E100)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)

#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_ODR         REG32(GPIOA_BASE + 0x14)
#define GPIOA_BSRR        REG32(GPIOA_BASE + 0x18)

#define GPIOC_MODER       REG32(GPIOC_BASE + 0x00)
#define GPIOC_PUPDR       REG32(GPIOC_BASE + 0x0C)
#define GPIOC_IDR         REG32(GPIOC_BASE + 0x10)

#define TIM2_CR1          REG32(TIM2_BASE + 0x00)
#define TIM2_DIER         REG32(TIM2_BASE + 0x0C)
#define TIM2_SR           REG32(TIM2_BASE + 0x10)
#define TIM2_CNT          REG32(TIM2_BASE + 0x24)
#define TIM2_PSC          REG32(TIM2_BASE + 0x28)
#define TIM2_ARR          REG32(TIM2_BASE + 0x2C)

#define NVIC_ISER(n)      REG32(NVIC_ISER_BASE + 4 * (n))

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

#define GREEN_PIN         0
#define YELLOW_PIN        1
#define RED_PIN           2
#define BUTTON_PIN        13
#define TIM2_IRQn         28

/* ───────────────────── Timing ───────────────────────────── */

static volatile uint32_t tick_ms = 0;   /* Millisecond counter, incremented by TIM2 ISR */

void TIM2_IRQHandler(void)
{
    if (TIM2_SR & BIT(0)) {
        TIM2_SR &= ~BIT(0);
        tick_ms++;
    }
}

static void systick_init(void)
{
    RCC_APB1ENR |= BIT(0);
    TIM2_CR1 = 0;
    TIM2_PSC = 15999;     /* 16 MHz / 16000 = 1 kHz */
    TIM2_ARR = 0;         /* Overflow every 1 ms    */
    TIM2_CNT = 0;
    TIM2_DIER |= BIT(0);
    TIM2_SR &= ~BIT(0);
    NVIC_ISER(TIM2_IRQn / 32) |= BIT(TIM2_IRQn % 32);
    TIM2_CR1 |= BIT(0);
}

static uint32_t millis(void) { return tick_ms; }

/* ───────────────────── GPIO Setup ───────────────────────── */

static void gpio_init(void)
{
    RCC_AHB1ENR |= BIT(0) | BIT(2);

    /* PA0, PA1, PA2: output (traffic light LEDs) */
    for (int pin = 0; pin <= 2; pin++) {
        GPIOA_MODER = (GPIOA_MODER & ~(0x03UL << (pin * 2)))
                     | (0x01UL << (pin * 2));
    }

    /* PC13: input with pull-up (pedestrian button, active low) */
    GPIOC_MODER &= ~(0x03UL << (BUTTON_PIN * 2));
    GPIOC_PUPDR = (GPIOC_PUPDR & ~(0x03UL << (BUTTON_PIN * 2)))
                 | (0x01UL << (BUTTON_PIN * 2));
}

static void set_lights(bool green, bool yellow, bool red)
{
    uint32_t set_mask   = 0;
    uint32_t reset_mask = 0;

    if (green)  set_mask |= BIT(GREEN_PIN);  else reset_mask |= BIT(GREEN_PIN);
    if (yellow) set_mask |= BIT(YELLOW_PIN); else reset_mask |= BIT(YELLOW_PIN);
    if (red)    set_mask |= BIT(RED_PIN);    else reset_mask |= BIT(RED_PIN);

    GPIOA_BSRR = set_mask | (reset_mask << 16);
}

static bool button_pressed(void)
{
    return !(GPIOC_IDR & BIT(BUTTON_PIN));
}

/* ───────────────────── State Machine ────────────────────── */

/**
 * State definitions — each state maps to a specific light combination
 * and a duration.
 */
typedef enum {
    STATE_GREEN,
    STATE_YELLOW,
    STATE_RED,
    STATE_RED_YELLOW,
    STATE_PED_RED,       /* Pedestrian requested: extended red */
    STATE_COUNT
} traffic_state_t;

typedef struct {
    bool     green;
    bool     yellow;
    bool     red;
    uint32_t duration_ms;
    traffic_state_t next_state;
} state_config_t;

/*
 * State transition table.
 *
 * Each row defines: lights on/off, duration, and next state.
 * This table-driven approach makes the FSM easy to modify
 * and understand.
 */
static const state_config_t state_table[STATE_COUNT] = {
    /* STATE_GREEN      */ { true,  false, false, 10000, STATE_YELLOW     },
    /* STATE_YELLOW     */ { false, true,  false, 3000,  STATE_RED        },
    /* STATE_RED        */ { false, false, true,  10000, STATE_RED_YELLOW },
    /* STATE_RED_YELLOW */ { false, true,  true,  2000,  STATE_GREEN      },
    /* STATE_PED_RED    */ { false, false, true,  15000, STATE_RED_YELLOW },
};

int main(void)
{
    gpio_init();
    systick_init();

    traffic_state_t  current_state = STATE_GREEN;
    uint32_t         state_start   = millis();
    bool             ped_requested = false;

    /* Apply initial state */
    const state_config_t *cfg = &state_table[current_state];
    set_lights(cfg->green, cfg->yellow, cfg->red);

    while (1) {
        uint32_t elapsed = millis() - state_start;

        /* Check pedestrian button */
        if (button_pressed() && !ped_requested) {
            ped_requested = true;
        }

        /* Time to transition? */
        if (elapsed >= state_table[current_state].duration_ms) {
            traffic_state_t next = state_table[current_state].next_state;

            /*
             * If a pedestrian crossing was requested and we're about
             * to leave RED, extend it by switching to PED_RED instead.
             */
            if (ped_requested && current_state == STATE_RED) {
                next = STATE_PED_RED;
                ped_requested = false;
            }

            current_state = next;
            state_start   = millis();

            cfg = &state_table[current_state];
            set_lights(cfg->green, cfg->yellow, cfg->red);
        }
    }

    return 0;
}

/*
 * ───────────────────── Alternative: Function-Pointer FSM ────────
 *
 * Instead of a table, each state can be a function that returns
 * the next state.  This is useful for states with complex logic.
 *
 * typedef traffic_state_t (*state_handler_t)(uint32_t elapsed);
 *
 * static traffic_state_t handle_green(uint32_t elapsed) {
 *     set_lights(true, false, false);
 *     return (elapsed >= 10000) ? STATE_YELLOW : STATE_GREEN;
 * }
 *
 * static const state_handler_t handlers[STATE_COUNT] = {
 *     [STATE_GREEN]  = handle_green,
 *     [STATE_YELLOW] = handle_yellow,
 *     ...
 * };
 */
