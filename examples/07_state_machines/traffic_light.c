/**
 * Traffic Light Controller — State Machine Example
 *
 * Implements a traffic light controller using two FSM patterns:
 *   1. Switch-case state machine
 *   2. Table-driven state machine
 *
 * Demonstrates state transitions, timed events, and emergency handling.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o traffic_light traffic_light.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

/* ---- Traffic Light States and Events ---- */

typedef enum {
    TL_RED,
    TL_RED_YELLOW,
    TL_GREEN,
    TL_GREEN_BLINK,
    TL_YELLOW,
    TL_EMERGENCY,
    TL_NUM_STATES
} TL_State;

typedef enum {
    EVT_TIMER,
    EVT_PEDESTRIAN,
    EVT_EMERGENCY_ON,
    EVT_EMERGENCY_OFF,
    EVT_NUM_EVENTS
} TL_Event;

static const char *state_names[] = {
    "RED", "RED+YELLOW", "GREEN", "GREEN_BLINK", "YELLOW", "EMERGENCY"
};

static const char *event_names[] = {
    "TIMER", "PEDESTRIAN", "EMERGENCY_ON", "EMERGENCY_OFF"
};

/* ---- Visual Output ---- */

static void show_lights(TL_State state)
{
    const char *r = "( )";
    const char *y = "( )";
    const char *g = "( )";

    switch (state) {
    case TL_RED:          r = "(R)"; break;
    case TL_RED_YELLOW:   r = "(R)"; y = "(Y)"; break;
    case TL_GREEN:        g = "(G)"; break;
    case TL_GREEN_BLINK:  g = "(*)"; break; /* Blinking green */
    case TL_YELLOW:       y = "(Y)"; break;
    case TL_EMERGENCY:    r = "(R)"; y = "(*)"; break; /* Flashing */
    default: break;
    }

    printf("  %s %s %s  [%s]", r, y, g, state_names[state]);
}

/* ---- Implementation 1: Switch-Case FSM ---- */

static void demo_switch_fsm(void)
{
    printf("=== Implementation 1: Switch-Case FSM ===\n\n");

    TL_State state = TL_RED;
    uint32_t timer = 0;

    /* Define durations (in ticks) */
    uint32_t red_dur = 5, ry_dur = 1, green_dur = 5, gb_dur = 3, yellow_dur = 2;

    TL_Event events[] = {
        EVT_TIMER, EVT_TIMER, EVT_TIMER, EVT_TIMER, EVT_TIMER,  /* RED phase */
        EVT_TIMER,                                                 /* RED_YELLOW */
        EVT_TIMER, EVT_TIMER, EVT_PEDESTRIAN, EVT_TIMER, EVT_TIMER, /* GREEN */
        EVT_TIMER, EVT_TIMER, EVT_TIMER,                          /* GREEN_BLINK */
        EVT_TIMER, EVT_TIMER,                                     /* YELLOW */
        EVT_TIMER, EVT_TIMER,                                     /* RED again */
        EVT_EMERGENCY_ON,                                          /* Emergency! */
        EVT_TIMER, EVT_TIMER, EVT_TIMER,                          /* In emergency */
        EVT_EMERGENCY_OFF,                                         /* Clear */
    };

    int num_events = sizeof(events) / sizeof(events[0]);

    printf("  Tick  Event           Lights            Next State\n");
    printf("  ----  --------------  ----------------  ----------\n");

    for (int i = 0; i < num_events; i++) {
        TL_Event evt = events[i];
        TL_State prev = state;
        timer++;

        switch (state) {
        case TL_RED:
            if (evt == EVT_TIMER && timer >= red_dur) {
                state = TL_RED_YELLOW;
                timer = 0;
            } else if (evt == EVT_EMERGENCY_ON) {
                state = TL_EMERGENCY;
                timer = 0;
            }
            break;

        case TL_RED_YELLOW:
            if (evt == EVT_TIMER && timer >= ry_dur) {
                state = TL_GREEN;
                timer = 0;
            }
            break;

        case TL_GREEN:
            if (evt == EVT_PEDESTRIAN) {
                state = TL_GREEN_BLINK;
                timer = 0;
            } else if (evt == EVT_TIMER && timer >= green_dur) {
                state = TL_GREEN_BLINK;
                timer = 0;
            } else if (evt == EVT_EMERGENCY_ON) {
                state = TL_EMERGENCY;
                timer = 0;
            }
            break;

        case TL_GREEN_BLINK:
            if (evt == EVT_TIMER && timer >= gb_dur) {
                state = TL_YELLOW;
                timer = 0;
            }
            break;

        case TL_YELLOW:
            if (evt == EVT_TIMER && timer >= yellow_dur) {
                state = TL_RED;
                timer = 0;
            }
            break;

        case TL_EMERGENCY:
            if (evt == EVT_EMERGENCY_OFF) {
                state = TL_RED;
                timer = 0;
            }
            break;

        default:
            state = TL_RED;
            timer = 0;
            break;
        }

        printf("  %4d  %-14s", i, event_names[evt]);
        show_lights(state);
        if (state != prev)
            printf("  ← transition");
        printf("\n");
    }
    printf("\n");
}

/* ---- Implementation 2: Table-Driven FSM ---- */

typedef void (*ActionFunc)(void);

typedef struct {
    TL_State current;
    TL_Event event;
    TL_State next;
    ActionFunc action;
} Transition;

static uint32_t tick_counter = 0;

static void action_start_green(void)  { tick_counter = 0; }
static void action_start_blink(void)  { tick_counter = 0; }
static void action_start_yellow(void) { tick_counter = 0; }
static void action_start_red(void)    { tick_counter = 0; }
static void action_start_ry(void)     { tick_counter = 0; }
static void action_emergency(void)    { tick_counter = 0; }

/*
 * Note: In a real implementation, timer-based transitions would use
 * a guard condition (timer >= duration). This simplified table shows
 * the structure — each TIMER event triggers a transition.
 */
static const Transition table[] = {
    { TL_RED,         EVT_TIMER,         TL_RED_YELLOW, action_start_ry },
    { TL_RED_YELLOW,  EVT_TIMER,         TL_GREEN,      action_start_green },
    { TL_GREEN,       EVT_TIMER,         TL_GREEN_BLINK,action_start_blink },
    { TL_GREEN,       EVT_PEDESTRIAN,    TL_GREEN_BLINK,action_start_blink },
    { TL_GREEN_BLINK, EVT_TIMER,         TL_YELLOW,     action_start_yellow },
    { TL_YELLOW,      EVT_TIMER,         TL_RED,        action_start_red },
    { TL_RED,         EVT_EMERGENCY_ON,  TL_EMERGENCY,  action_emergency },
    { TL_GREEN,       EVT_EMERGENCY_ON,  TL_EMERGENCY,  action_emergency },
    { TL_YELLOW,      EVT_EMERGENCY_ON,  TL_EMERGENCY,  action_emergency },
    { TL_EMERGENCY,   EVT_EMERGENCY_OFF, TL_RED,        action_start_red },
};

#define TABLE_SIZE (sizeof(table) / sizeof(table[0]))

static bool table_fsm_handle(TL_State *state, TL_Event event)
{
    for (uint32_t i = 0; i < TABLE_SIZE; i++) {
        if (table[i].current == *state && table[i].event == event) {
            if (table[i].action)
                table[i].action();
            *state = table[i].next;
            return true;
        }
    }
    return false;  /* No matching transition */
}

static void demo_table_fsm(void)
{
    printf("=== Implementation 2: Table-Driven FSM ===\n\n");

    printf("Transition table (%zu entries):\n\n", TABLE_SIZE);
    printf("  Current         Event            Next\n");
    printf("  ----------      ---------------  ----------\n");
    for (uint32_t i = 0; i < TABLE_SIZE; i++) {
        printf("  %-14s  %-15s  %s\n",
               state_names[table[i].current],
               event_names[table[i].event],
               state_names[table[i].next]);
    }

    printf("\nRunning the table-driven FSM:\n\n");

    TL_State state = TL_RED;
    TL_Event sequence[] = {
        EVT_TIMER, EVT_TIMER, EVT_TIMER,
        EVT_PEDESTRIAN,
        EVT_TIMER, EVT_TIMER,
        EVT_EMERGENCY_ON,
        EVT_TIMER,
        EVT_EMERGENCY_OFF,
        EVT_TIMER,
    };

    for (int i = 0; i < 10; i++) {
        TL_State prev = state;
        bool transitioned = table_fsm_handle(&state, sequence[i]);
        printf("  %-14s + %-14s →", state_names[prev], event_names[sequence[i]]);
        show_lights(state);
        printf("  %s\n", transitioned ? "" : "(no transition)");
    }
    printf("\n");
}

/* ---- Comparison ---- */

static void comparison(void)
{
    printf("=== Switch-Case vs. Table-Driven ===\n\n");

    printf("  Switch-Case:\n");
    printf("    + Simple, no extra data structures\n");
    printf("    + Easy to add guard conditions (timer >= N)\n");
    printf("    + Compiler can optimize (jump table)\n");
    printf("    - Gets unwieldy with many states/events\n");
    printf("    - Logic mixed with transition structure\n\n");

    printf("  Table-Driven:\n");
    printf("    + Transition rules separated from logic\n");
    printf("    + Easy to add/remove transitions (one line)\n");
    printf("    + Table stored in Flash (const) saves RAM\n");
    printf("    + Easy to auto-generate from design tools\n");
    printf("    - Guard conditions require extra fields\n");
    printf("    - Linear search through table (O(n))\n\n");

    printf("  Recommendation: Use switch-case for < 10 states.\n");
    printf("  Use table-driven for larger FSMs or when the\n");
    printf("  transition rules change frequently.\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("Traffic Light Controller — State Machine Demo\n");
    printf("===============================================\n\n");

    demo_switch_fsm();
    demo_table_fsm();
    comparison();

    return 0;
}
