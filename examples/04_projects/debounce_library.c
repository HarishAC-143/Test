/**
 * PROJECT: Button Debounce Library
 *
 * A reusable, configurable debounce library that supports:
 *   - Multiple simultaneous buttons
 *   - Short press, long press, and double-click detection
 *   - Configurable timing parameters
 *   - Callback-based event notification
 *   - Zero dynamic memory allocation
 *
 * The library is designed to be called from a timer ISR at a fixed
 * rate (e.g., every 5 ms).
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ================================================================
 * Configuration
 * ================================================================ */
#define MAX_BUTTONS          8
#define DEBOUNCE_SAMPLES     4     /* Consecutive identical reads needed */
#define LONG_PRESS_MS        1000  /* Hold time for long press */
#define DOUBLE_CLICK_MS      300   /* Max gap between clicks */
#define SAMPLE_PERIOD_MS     5     /* Timer ISR period */

/* ================================================================
 * Button Event Types
 * ================================================================ */
typedef enum {
    BTN_EVENT_NONE,
    BTN_EVENT_PRESSED,
    BTN_EVENT_RELEASED,
    BTN_EVENT_SHORT_CLICK,
    BTN_EVENT_LONG_PRESS,
    BTN_EVENT_DOUBLE_CLICK,
    BTN_EVENT_HELD          /* Fires repeatedly while held */
} ButtonEvent;

static const char *event_names[] = {
    "NONE", "PRESSED", "RELEASED", "SHORT_CLICK",
    "LONG_PRESS", "DOUBLE_CLICK", "HELD"
};

/* ================================================================
 * Button State Machine
 * ================================================================ */
typedef enum {
    BTN_STATE_IDLE,
    BTN_STATE_DEBOUNCE_PRESS,
    BTN_STATE_PRESSED,
    BTN_STATE_DEBOUNCE_RELEASE,
    BTN_STATE_WAIT_DOUBLE_CLICK
} ButtonState;

typedef void (*ButtonCallback)(uint8_t button_id, ButtonEvent event);

typedef struct {
    /* Configuration */
    uint8_t          id;
    bool             active_low;      /* true = pressed when LOW */
    uint16_t         long_press_ms;
    uint16_t         double_click_ms;

    /* State */
    ButtonState      state;
    uint8_t          sample_count;
    bool             current_raw;
    bool             debounced;
    uint16_t         press_duration_ms;
    uint16_t         release_duration_ms;
    uint8_t          click_count;
    bool             long_press_fired;

    /* Callback */
    ButtonCallback   callback;

    /* Statistics */
    uint32_t         total_presses;
    uint32_t         total_long_presses;
    uint32_t         total_double_clicks;
} Button;

/* ================================================================
 * Debounce Library API
 * ================================================================ */
static Button buttons[MAX_BUTTONS];
static uint8_t button_count = 0;

static int btn_register(uint8_t id, bool active_low,
                        ButtonCallback callback) {
    if (button_count >= MAX_BUTTONS) return -1;

    Button *b = &buttons[button_count];
    memset(b, 0, sizeof(Button));
    b->id = id;
    b->active_low = active_low;
    b->long_press_ms = LONG_PRESS_MS;
    b->double_click_ms = DOUBLE_CLICK_MS;
    b->state = BTN_STATE_IDLE;
    b->callback = callback;

    return button_count++;
}

static void btn_set_timing(int idx, uint16_t long_press_ms,
                           uint16_t double_click_ms) {
    if (idx >= 0 && idx < button_count) {
        buttons[idx].long_press_ms = long_press_ms;
        buttons[idx].double_click_ms = double_click_ms;
    }
}

static void btn_fire_event(Button *b, ButtonEvent event) {
    if (b->callback) {
        b->callback(b->id, event);
    }

    switch (event) {
    case BTN_EVENT_SHORT_CLICK:
        b->total_presses++;
        break;
    case BTN_EVENT_LONG_PRESS:
        b->total_long_presses++;
        break;
    case BTN_EVENT_DOUBLE_CLICK:
        b->total_double_clicks++;
        break;
    default:
        break;
    }
}

static void btn_update(Button *b, bool raw_pressed) {
    bool pressed = b->active_low ? !raw_pressed : raw_pressed;

    switch (b->state) {
    case BTN_STATE_IDLE:
        if (pressed) {
            b->sample_count = 1;
            b->state = BTN_STATE_DEBOUNCE_PRESS;
        }
        break;

    case BTN_STATE_DEBOUNCE_PRESS:
        if (pressed) {
            b->sample_count++;
            if (b->sample_count >= DEBOUNCE_SAMPLES) {
                b->debounced = true;
                b->press_duration_ms = 0;
                b->long_press_fired = false;
                b->state = BTN_STATE_PRESSED;
                btn_fire_event(b, BTN_EVENT_PRESSED);
            }
        } else {
            b->sample_count = 0;
            b->state = BTN_STATE_IDLE;
        }
        break;

    case BTN_STATE_PRESSED:
        b->press_duration_ms += SAMPLE_PERIOD_MS;

        if (!pressed) {
            b->sample_count = 1;
            b->state = BTN_STATE_DEBOUNCE_RELEASE;
        } else if (!b->long_press_fired &&
                   b->press_duration_ms >= b->long_press_ms) {
            b->long_press_fired = true;
            btn_fire_event(b, BTN_EVENT_LONG_PRESS);
        } else if (b->long_press_fired &&
                   b->press_duration_ms % 500 < SAMPLE_PERIOD_MS) {
            btn_fire_event(b, BTN_EVENT_HELD);
        }
        break;

    case BTN_STATE_DEBOUNCE_RELEASE:
        if (!pressed) {
            b->sample_count++;
            if (b->sample_count >= DEBOUNCE_SAMPLES) {
                b->debounced = false;
                btn_fire_event(b, BTN_EVENT_RELEASED);

                if (!b->long_press_fired) {
                    b->click_count++;
                    if (b->click_count >= 2) {
                        btn_fire_event(b, BTN_EVENT_DOUBLE_CLICK);
                        b->click_count = 0;
                        b->state = BTN_STATE_IDLE;
                    } else {
                        b->release_duration_ms = 0;
                        b->state = BTN_STATE_WAIT_DOUBLE_CLICK;
                    }
                } else {
                    b->click_count = 0;
                    b->state = BTN_STATE_IDLE;
                }
            }
        } else {
            b->sample_count = 0;
            b->state = BTN_STATE_PRESSED;
        }
        break;

    case BTN_STATE_WAIT_DOUBLE_CLICK:
        b->release_duration_ms += SAMPLE_PERIOD_MS;

        if (pressed) {
            b->sample_count = 1;
            b->state = BTN_STATE_DEBOUNCE_PRESS;
        } else if (b->release_duration_ms >= b->double_click_ms) {
            btn_fire_event(b, BTN_EVENT_SHORT_CLICK);
            b->click_count = 0;
            b->state = BTN_STATE_IDLE;
        }
        break;
    }
}

static void btn_process_all(bool raw_states[]) {
    for (int i = 0; i < button_count; i++) {
        btn_update(&buttons[i], raw_states[i]);
    }
}

/* ================================================================
 * Simulation
 * ================================================================ */

static void button_event_handler(uint8_t id, ButtonEvent event) {
    printf("    [Button %u] %s\n", id, event_names[event]);
}

int main(void) {
    printf("╔══════════════════════════════════════════════╗\n");
    printf("║  Button Debounce Library                     ║\n");
    printf("╚══════════════════════════════════════════════╝\n\n");

    /* Register buttons */
    int btn0 = btn_register(0, true, button_event_handler);
    int btn1 = btn_register(1, true, button_event_handler);

    btn_set_timing(btn0, 1000, 300);
    btn_set_timing(btn1, 800,  250);

    printf("  Registered %d buttons\n", button_count);
    printf("  Sample period: %d ms\n", SAMPLE_PERIOD_MS);
    printf("  Debounce samples: %d (%d ms)\n",
           DEBOUNCE_SAMPLES, DEBOUNCE_SAMPLES * SAMPLE_PERIOD_MS);
    printf("  Long press: %d ms\n", LONG_PRESS_MS);
    printf("  Double-click window: %d ms\n\n", DOUBLE_CLICK_MS);

    /* Define button press scenarios */
    printf("  ═══ Scenario 1: Short Click (Button 0) ═══\n\n");
    {
        bool raw[MAX_BUTTONS] = {false};
        for (uint32_t t = 0; t < 600; t += SAMPLE_PERIOD_MS) {
            /* Button 0: press 100-200 ms (100 ms duration) */
            raw[0] = (t >= 100 && t < 200);
            /* Active-low: invert for simulation */
            bool states[MAX_BUTTONS] = {!raw[0], true, true, true, true, true, true, true};
            btn_process_all(states);
        }
    }

    printf("\n  ═══ Scenario 2: Long Press (Button 0) ═══\n\n");
    {
        /* Reset button state */
        buttons[0].state = BTN_STATE_IDLE;
        buttons[0].click_count = 0;

        bool raw0;
        for (uint32_t t = 0; t < 2000; t += SAMPLE_PERIOD_MS) {
            /* Button 0: press 100-1300 ms (1200 ms hold) */
            raw0 = (t >= 100 && t < 1300);
            bool states[MAX_BUTTONS] = {!raw0, true, true, true, true, true, true, true};
            btn_process_all(states);
        }
    }

    printf("\n  ═══ Scenario 3: Double Click (Button 0) ═══\n\n");
    {
        buttons[0].state = BTN_STATE_IDLE;
        buttons[0].click_count = 0;

        bool raw0;
        for (uint32_t t = 0; t < 1000; t += SAMPLE_PERIOD_MS) {
            /* First click: 100-180 ms */
            /* Second click: 300-380 ms */
            raw0 = (t >= 100 && t < 180) || (t >= 300 && t < 380);
            bool states[MAX_BUTTONS] = {!raw0, true, true, true, true, true, true, true};
            btn_process_all(states);
        }
    }

    printf("\n  ═══ Scenario 4: Bouncy Signal (Button 1) ═══\n\n");
    {
        buttons[1].state = BTN_STATE_IDLE;
        buttons[1].click_count = 0;

        printf("  Simulating mechanical bounce on Button 1:\n");
        printf("  Raw:    1 0 1 0 0 0 0 0 0 0 ... (bouncing then settling)\n\n");

        bool bounce_pattern[] = {
            true, false, true, false, false, false, false, false,
            false, false, false, false, false, false, false, false,
            false, false, false, false, false, false, false, false,
            false, false, false, false, false, false,
            true, true, false, true, true, true, true, true,
            true, true, true, true, true, true, true, true,
        };
        int pattern_len = sizeof(bounce_pattern) / sizeof(bounce_pattern[0]);

        for (int i = 0; i < pattern_len; i++) {
            bool states[MAX_BUTTONS] = {true, bounce_pattern[i], true, true, true, true, true, true};
            btn_process_all(states);
        }
    }

    /* Print statistics */
    printf("\n  ═══ Statistics ═══\n\n");
    printf("  %-10s  %10s  %12s  %14s\n",
           "Button", "Clicks", "Long Press", "Double Click");
    printf("  %-10s  %10s  %12s  %14s\n",
           "----------", "----------", "------------", "--------------");

    for (int i = 0; i < button_count; i++) {
        printf("  Button %u    %10u  %12u  %14u\n",
               buttons[i].id,
               buttons[i].total_presses,
               buttons[i].total_long_presses,
               buttons[i].total_double_clicks);
    }

    printf("\n  The debounce filter eliminates the bouncy transitions\n");
    printf("  and only fires events on clean, confirmed state changes.\n\n");

    return 0;
}
