/**
 * PROJECT: LED Pattern Controller with Button Input
 *
 * A multi-pattern LED controller that cycles through patterns
 * using button input with proper debouncing.
 *
 * Concepts demonstrated:
 *   - GPIO output (LEDs) and input (button)
 *   - Button debouncing with timer sampling
 *   - State machine for pattern management
 *   - Timer-driven animation
 *   - PWM fade effect (simulated)
 *   - Long press detection
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>

/* ================================================================
 * Configuration
 * ================================================================ */
#define NUM_LEDS          8
#define TICK_MS           10
#define DEBOUNCE_TICKS    5
#define LONG_PRESS_TICKS  100

/* ================================================================
 * Simulated Hardware
 * ================================================================ */
static uint8_t led_state = 0;   /* Bit per LED */
static bool button_raw = false; /* Raw button state */
static uint32_t sim_tick = 0;

static void hw_set_leds(uint8_t state) {
    led_state = state;
}

static uint8_t hw_get_leds(void) {
    return led_state;
}

/* ================================================================
 * Button Debouncer
 * ================================================================ */
typedef struct {
    uint8_t  history;        /* Shift register of recent samples */
    bool     state;          /* Debounced state */
    bool     pressed;        /* Rising edge (just pressed) */
    bool     released;       /* Falling edge (just released) */
    uint16_t held_ticks;     /* How long held */
    bool     long_press;     /* Long press detected */
} Debouncer;

static void debounce_init(Debouncer *d) {
    memset(d, 0, sizeof(*d));
}

static void debounce_update(Debouncer *d, bool raw) {
    d->history = (d->history << 1) | (raw ? 1 : 0);
    d->pressed = false;
    d->released = false;
    d->long_press = false;

    /* Require DEBOUNCE_TICKS consecutive identical readings */
    uint8_t mask = (uint8_t)((1 << DEBOUNCE_TICKS) - 1);

    if ((d->history & mask) == mask && !d->state) {
        d->state = true;
        d->pressed = true;
        d->held_ticks = 0;
    } else if ((d->history & mask) == 0 && d->state) {
        d->state = false;
        d->released = true;
        d->held_ticks = 0;
    }

    if (d->state) {
        d->held_ticks++;
        if (d->held_ticks == LONG_PRESS_TICKS) {
            d->long_press = true;
        }
    }
}

/* ================================================================
 * LED Pattern Engine
 * ================================================================ */
typedef enum {
    PATTERN_OFF,
    PATTERN_ALL_ON,
    PATTERN_BLINK,
    PATTERN_CHASE,
    PATTERN_BREATHE,
    PATTERN_BINARY_COUNT,
    PATTERN_PING_PONG,
    NUM_PATTERNS
} Pattern;

static const char *pattern_names[] = {
    "All Off", "All On", "Blink", "Chase",
    "Breathe", "Binary Counter", "Ping-Pong"
};

typedef struct {
    Pattern  current_pattern;
    uint32_t tick_count;
    uint32_t frame;
    uint8_t  led_output;
    bool     direction;      /* For ping-pong */
    uint8_t  chase_pos;      /* For chase */
    uint8_t  binary_val;     /* For binary counter */
    uint8_t  breathe_level;  /* For breathe (PWM duty) */
    bool     breathe_up;     /* For breathe direction */
} PatternEngine;

static void pattern_init(PatternEngine *pe) {
    memset(pe, 0, sizeof(*pe));
    pe->current_pattern = PATTERN_OFF;
    pe->breathe_up = true;
}

static void pattern_set(PatternEngine *pe, Pattern p) {
    pe->current_pattern = p;
    pe->tick_count = 0;
    pe->frame = 0;
    pe->chase_pos = 0;
    pe->binary_val = 0;
    pe->breathe_level = 0;
    pe->breathe_up = true;
    pe->direction = true;
}

static void pattern_next(PatternEngine *pe) {
    Pattern next = (Pattern)((pe->current_pattern + 1) % NUM_PATTERNS);
    pattern_set(pe, next);
}

static void pattern_update(PatternEngine *pe) {
    pe->tick_count++;

    switch (pe->current_pattern) {
    case PATTERN_OFF:
        pe->led_output = 0x00;
        break;

    case PATTERN_ALL_ON:
        pe->led_output = 0xFF;
        break;

    case PATTERN_BLINK:
        /* Toggle every 500 ms (50 ticks at 10 ms) */
        if (pe->tick_count % 50 == 0) {
            pe->frame++;
        }
        pe->led_output = (pe->frame % 2) ? 0xFF : 0x00;
        break;

    case PATTERN_CHASE:
        /* Move one LED every 100 ms */
        if (pe->tick_count % 10 == 0) {
            pe->chase_pos = (pe->chase_pos + 1) % NUM_LEDS;
        }
        pe->led_output = (uint8_t)(1 << pe->chase_pos);
        break;

    case PATTERN_BREATHE:
        /* Fade in/out using simulated PWM */
        if (pe->tick_count % 2 == 0) {
            if (pe->breathe_up) {
                pe->breathe_level++;
                if (pe->breathe_level >= 20) pe->breathe_up = false;
            } else {
                pe->breathe_level--;
                if (pe->breathe_level == 0) pe->breathe_up = true;
            }
        }
        /* Simulate PWM: LEDs are ON if tick within duty cycle */
        pe->led_output = (pe->tick_count % 20 < pe->breathe_level) ? 0xFF : 0x00;
        break;

    case PATTERN_BINARY_COUNT:
        /* Increment every 500 ms */
        if (pe->tick_count % 50 == 0) {
            pe->binary_val++;
        }
        pe->led_output = pe->binary_val;
        break;

    case PATTERN_PING_PONG:
        /* Bounce back and forth every 80 ms */
        if (pe->tick_count % 8 == 0) {
            if (pe->direction) {
                pe->chase_pos++;
                if (pe->chase_pos >= NUM_LEDS - 1) pe->direction = false;
            } else {
                pe->chase_pos--;
                if (pe->chase_pos == 0) pe->direction = true;
            }
        }
        pe->led_output = (uint8_t)(1 << pe->chase_pos);
        break;

    default:
        pe->led_output = 0x00;
        break;
    }

    hw_set_leds(pe->led_output);
}

/* ================================================================
 * Display
 * ================================================================ */
static void print_leds(uint8_t state) {
    printf("[");
    for (int i = NUM_LEDS - 1; i >= 0; i--) {
        printf("%c", (state & (1 << i)) ? '*' : '.');
    }
    printf("]");
}

/* ================================================================
 * Main Application
 * ================================================================ */
int main(void) {
    printf("╔══════════════════════════════════════════════╗\n");
    printf("║  LED Pattern Controller                      ║\n");
    printf("╚══════════════════════════════════════════════╝\n\n");

    Debouncer btn;
    PatternEngine engine;

    debounce_init(&btn);
    pattern_init(&engine);

    printf("  Patterns: ");
    for (int i = 0; i < NUM_PATTERNS; i++) {
        printf("%d=%s  ", i, pattern_names[i]);
    }
    printf("\n\n");

    /* Simulation script: button presses at specific times */
    typedef struct {
        uint32_t start_tick;
        uint32_t duration_ticks;
    } ButtonPress;

    ButtonPress presses[] = {
        {  50,   8 },  /* Short press at tick 50 → next pattern */
        { 200,   8 },  /* Short press → next pattern */
        { 400,   8 },  /* Short press → next pattern */
        { 600,   8 },  /* Short press → next pattern */
        { 800,   8 },  /* Short press → next pattern */
        { 1000,  8 },  /* Short press → next pattern */
        { 1200, 120 }, /* Long press → reset to OFF */
    };
    int num_presses = sizeof(presses) / sizeof(presses[0]);
    int press_idx = 0;

    printf("  Tick  Button  LED State   Pattern\n");
    printf("  ----  ------  ---------   -------\n");

    uint32_t last_print = 0;

    for (sim_tick = 0; sim_tick < 1500; sim_tick++) {
        /* Determine raw button state from script */
        button_raw = false;
        for (int p = 0; p < num_presses; p++) {
            if (sim_tick >= presses[p].start_tick &&
                sim_tick < presses[p].start_tick + presses[p].duration_ticks) {
                button_raw = true;
                break;
            }
        }

        /* Update debouncer */
        debounce_update(&btn, button_raw);

        /* Handle button events */
        if (btn.pressed) {
            /* (Wait for release or long press) */
        }
        if (btn.long_press) {
            pattern_set(&engine, PATTERN_OFF);
            printf("  %4u  LONG    ", sim_tick);
            print_leds(hw_get_leds());
            printf("   -> %s (long press reset)\n", pattern_names[engine.current_pattern]);
            last_print = sim_tick;
        } else if (btn.released && btn.held_ticks < LONG_PRESS_TICKS) {
            pattern_next(&engine);
            printf("  %4u  SHORT   ", sim_tick);
            print_leds(hw_get_leds());
            printf("   -> %s\n", pattern_names[engine.current_pattern]);
            last_print = sim_tick;
            press_idx++;
        }

        /* Update pattern animation */
        pattern_update(&engine);

        /* Print periodic snapshots (every 100 ticks but skip if button event was recent) */
        if (sim_tick % 100 == 0 && (sim_tick - last_print > 20)) {
            printf("  %4u          ", sim_tick);
            print_leds(hw_get_leds());
            printf("   %s\n", pattern_names[engine.current_pattern]);
            last_print = sim_tick;
        }
    }

    printf("\n  ═══ Summary ═══\n");
    printf("    Total ticks:   %u (%u ms)\n", sim_tick, sim_tick * TICK_MS);
    printf("    Button presses: %d short, %d long\n",
           press_idx, (int)(num_presses - press_idx));
    printf("    Final pattern:  %s\n\n",
           pattern_names[engine.current_pattern]);

    return 0;
}
