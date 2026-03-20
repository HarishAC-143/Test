/**
 * Button Debounce Techniques
 *
 * Demonstrates three software debounce methods for mechanical buttons:
 *   1. Simple delay-based debounce
 *   2. Integration (counter) debounce
 *   3. Shift register debounce
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o button_debounce button_debounce.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---- Simulated Button Hardware ---- */

/*
 * In real code, this reads a GPIO input register:
 *   #define is_button_raw() (!(GPIOC->IDR & (1U << 13)))  // Active-low
 *
 * For this demo, we feed in a simulated sequence of raw readings
 * that includes bounce.
 */

static const uint8_t bounce_sequence[] = {
    /* Button at rest (not pressed) */
    0, 0, 0, 0, 0,
    /* Contact begins — bouncing */
    1, 0, 1, 1, 0, 1, 0, 1, 1, 1,
    /* Settled — button is pressed */
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    /* Release begins — bouncing */
    0, 1, 0, 0, 1, 0, 1, 0, 0, 0,
    /* Settled — button is released */
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

#define SEQUENCE_LEN (sizeof(bounce_sequence) / sizeof(bounce_sequence[0]))

static uint32_t sim_index = 0;

static uint8_t is_button_raw(void)
{
    if (sim_index < SEQUENCE_LEN)
        return bounce_sequence[sim_index];
    return 0;
}

/* ---- Method 1: Delay-Based Debounce ---- */

/*
 * The simplest approach: when a press is detected, wait a fixed
 * time for the bouncing to settle, then re-check.
 *
 * Pros: Very simple
 * Cons: Blocks the CPU during the delay; may miss short presses
 */

static void demo_delay_debounce(void)
{
    printf("=== Method 1: Delay-Based Debounce ===\n\n");
    printf("Idx  Raw  Debounced  Note\n");
    printf("---  ---  ---------  ----\n");

    bool last_state = false;

    for (sim_index = 0; sim_index < SEQUENCE_LEN; sim_index++) {
        uint8_t raw = is_button_raw();
        bool debounced = false;

        if (raw && !last_state) {
            /*
             * In real code: delay_ms(50);
             * Then re-read the pin. For simulation, we peek ahead.
             */
            uint32_t future = sim_index + 5;
            if (future < SEQUENCE_LEN && bounce_sequence[future]) {
                debounced = true;
            }
        } else if (!raw && last_state) {
            uint32_t future = sim_index + 5;
            if (future < SEQUENCE_LEN && !bounce_sequence[future]) {
                debounced = false;
            } else {
                debounced = true;
            }
        } else {
            debounced = last_state;
        }

        const char *note = "";
        if (debounced && !last_state)  note = "<-- PRESS detected";
        if (!debounced && last_state)  note = "<-- RELEASE detected";

        printf("%3u   %u      %u      %s\n", sim_index, raw, debounced, note);
        last_state = debounced;
    }
    printf("\n");
}

/* ---- Method 2: Integration (Counter) Debounce ---- */

/*
 * Sample the button periodically. Require N consecutive matching
 * readings before changing state. Best when called from a timer ISR.
 *
 * Pros: No blocking; robust; adjustable sensitivity
 * Cons: Adds latency proportional to the sample count
 */

#define DEBOUNCE_THRESHOLD 4

typedef struct {
    uint8_t state;
    uint8_t count;
} IntegrationDebouncer;

static uint8_t integration_debounce(IntegrationDebouncer *d, uint8_t raw)
{
    if (raw != d->state) {
        d->count++;
        if (d->count >= DEBOUNCE_THRESHOLD) {
            d->state = raw;
            d->count = 0;
        }
    } else {
        d->count = 0;
    }
    return d->state;
}

static void demo_integration_debounce(void)
{
    printf("=== Method 2: Integration (Counter) Debounce ===\n");
    printf("    (threshold = %d consecutive matching samples)\n\n", DEBOUNCE_THRESHOLD);
    printf("Idx  Raw  Debounced  Count  Note\n");
    printf("---  ---  ---------  -----  ----\n");

    IntegrationDebouncer db = { .state = 0, .count = 0 };
    uint8_t prev_state = 0;

    for (sim_index = 0; sim_index < SEQUENCE_LEN; sim_index++) {
        uint8_t raw = is_button_raw();
        uint8_t debounced = integration_debounce(&db, raw);

        const char *note = "";
        if (debounced && !prev_state)   note = "<-- PRESS detected";
        if (!debounced && prev_state)   note = "<-- RELEASE detected";

        printf("%3u   %u      %u       %u    %s\n",
               sim_index, raw, debounced, db.count, note);
        prev_state = debounced;
    }
    printf("\n");
}

/* ---- Method 3: Shift Register Debounce ---- */

/*
 * Maintain a shift register of the last N readings. The button state
 * changes only when all N bits are unanimous.
 *
 * Pros: Very efficient (single shift + mask per sample); no branching
 * Cons: Fixed window size; N must match the bounce duration
 */

#define SHIFT_BITS 8
#define SHIFT_MASK ((1U << SHIFT_BITS) - 1)  /* 0xFF for 8 bits */

typedef struct {
    uint16_t history;
    uint8_t  state;
} ShiftDebouncer;

static uint8_t shift_debounce(ShiftDebouncer *d, uint8_t raw)
{
    d->history = ((d->history << 1) | (raw & 1)) & SHIFT_MASK;

    if (d->history == SHIFT_MASK)
        d->state = 1;
    else if (d->history == 0)
        d->state = 0;

    return d->state;
}

static void demo_shift_debounce(void)
{
    printf("=== Method 3: Shift Register Debounce ===\n");
    printf("    (window = %d samples, mask = 0x%02X)\n\n", SHIFT_BITS, SHIFT_MASK);
    printf("Idx  Raw  Debounced  History   Note\n");
    printf("---  ---  ---------  --------  ----\n");

    ShiftDebouncer db = { .history = 0, .state = 0 };
    uint8_t prev_state = 0;

    for (sim_index = 0; sim_index < SEQUENCE_LEN; sim_index++) {
        uint8_t raw = is_button_raw();
        uint8_t debounced = shift_debounce(&db, raw);

        const char *note = "";
        if (debounced && !prev_state)   note = "<-- PRESS detected";
        if (!debounced && prev_state)   note = "<-- RELEASE detected";

        char hist_str[SHIFT_BITS + 1];
        for (int i = SHIFT_BITS - 1; i >= 0; i--)
            hist_str[SHIFT_BITS - 1 - i] = (db.history & (1U << i)) ? '1' : '0';
        hist_str[SHIFT_BITS] = '\0';

        printf("%3u   %u      %u      %s  %s\n",
               sim_index, raw, debounced, hist_str, note);
        prev_state = debounced;
    }
    printf("\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("Button Debounce Techniques Demo\n");
    printf("================================\n\n");

    printf("Simulated raw input sequence (1=pressed, 0=released):\n  ");
    for (uint32_t i = 0; i < SEQUENCE_LEN; i++) {
        printf("%u", bounce_sequence[i]);
        if (i == 4) printf("|");
        else if (i == 14) printf("|");
        else if (i == 24) printf("|");
        else if (i == 34) printf("|");
    }
    printf("\n");
    printf("  ^rest |^bounce|^pressed |^bounce|^released\n\n");

    demo_delay_debounce();
    demo_integration_debounce();
    demo_shift_debounce();

    printf("Recommendation: Use integration or shift register debounce\n");
    printf("called from a periodic timer interrupt (e.g., every 1 ms).\n");

    return 0;
}
