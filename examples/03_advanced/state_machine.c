/**
 * Finite State Machine (FSM) Patterns
 *
 * Demonstrates three FSM implementation styles:
 * 1. Switch-case (simple)
 * 2. Table-driven (scalable)
 * 3. State pattern with entry/exit actions (advanced)
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ================================================================
 * EXAMPLE 1: Traffic Light Controller (Switch-Case FSM)
 * ================================================================ */

typedef enum {
    TL_RED,
    TL_RED_YELLOW,
    TL_GREEN,
    TL_YELLOW
} TrafficLightState;

static const char *tl_state_names[] = {
    "RED", "RED+YELLOW", "GREEN", "YELLOW"
};

static const char *tl_visuals[] = {
    "[*] [ ] [ ]",    /* RED */
    "[*] [*] [ ]",    /* RED+YELLOW */
    "[ ] [ ] [*]",    /* GREEN */
    "[ ] [*] [ ]"     /* YELLOW */
};

static const uint32_t tl_durations[] = {
    5000,   /* RED: 5 s */
    1000,   /* RED+YELLOW: 1 s */
    4000,   /* GREEN: 4 s */
    2000    /* YELLOW: 2 s */
};

static void demo_traffic_light(void) {
    printf("=== FSM 1: Traffic Light (Switch-Case) ===\n\n");

    TrafficLightState state = TL_RED;
    uint32_t timer = 0;

    printf("  Time    State        LEDs         Duration\n");
    printf("  -----   ----------   -----------  --------\n");

    uint32_t elapsed = 0;

    for (int cycle = 0; cycle < 12; cycle++) {
        printf("  %4u ms  %-10s  %s   %u ms\n",
               elapsed, tl_state_names[state],
               tl_visuals[state], tl_durations[state]);

        timer = tl_durations[state];
        elapsed += timer;

        switch (state) {
        case TL_RED:        state = TL_RED_YELLOW; break;
        case TL_RED_YELLOW: state = TL_GREEN;      break;
        case TL_GREEN:      state = TL_YELLOW;     break;
        case TL_YELLOW:     state = TL_RED;        break;
        }
    }
    printf("\n");
}

/* ================================================================
 * EXAMPLE 2: Thermostat Controller (Table-Driven FSM)
 * ================================================================ */

typedef enum {
    THERM_IDLE,
    THERM_HEATING,
    THERM_AT_TARGET,
    THERM_COOLING,
    THERM_ERROR,
    THERM_NUM_STATES
} ThermState;

typedef enum {
    EVT_START,
    EVT_TEMP_LOW,
    EVT_TEMP_OK,
    EVT_TEMP_HIGH,
    EVT_STOP,
    EVT_FAULT,
    EVT_RESET,
    THERM_NUM_EVENTS
} ThermEvent;

static const char *therm_state_names[] = {
    "IDLE", "HEATING", "AT_TARGET", "COOLING", "ERROR"
};

static const char *therm_event_names[] = {
    "START", "TEMP_LOW", "TEMP_OK", "TEMP_HIGH", "STOP", "FAULT", "RESET"
};

typedef struct {
    ThermState next_state;
    void (*action)(void);
} ThermTransition;

static void act_heater_on(void)  { printf("      Action: Heater ON\n"); }
static void act_heater_off(void) { printf("      Action: Heater OFF\n"); }
static void act_fan_on(void)     { printf("      Action: Fan ON\n"); }
static void act_fan_off(void)    { printf("      Action: Fan OFF\n"); }
static void act_alarm(void)      { printf("      Action: ALARM! System fault\n"); }
static void act_reset(void)      { printf("      Action: System reset\n"); }
static void act_nop(void)        { /* no operation */ }

static const ThermTransition therm_table[THERM_NUM_STATES][THERM_NUM_EVENTS] = {
    /* IDLE */
    [THERM_IDLE] = {
        [EVT_START]     = { THERM_HEATING,   act_heater_on },
        [EVT_TEMP_LOW]  = { THERM_IDLE,      act_nop },
        [EVT_TEMP_OK]   = { THERM_IDLE,      act_nop },
        [EVT_TEMP_HIGH] = { THERM_IDLE,      act_nop },
        [EVT_STOP]      = { THERM_IDLE,      act_nop },
        [EVT_FAULT]     = { THERM_ERROR,     act_alarm },
        [EVT_RESET]     = { THERM_IDLE,      act_nop },
    },
    /* HEATING */
    [THERM_HEATING] = {
        [EVT_START]     = { THERM_HEATING,   act_nop },
        [EVT_TEMP_LOW]  = { THERM_HEATING,   act_nop },
        [EVT_TEMP_OK]   = { THERM_AT_TARGET, act_heater_off },
        [EVT_TEMP_HIGH] = { THERM_COOLING,   act_fan_on },
        [EVT_STOP]      = { THERM_IDLE,      act_heater_off },
        [EVT_FAULT]     = { THERM_ERROR,     act_alarm },
        [EVT_RESET]     = { THERM_IDLE,      act_heater_off },
    },
    /* AT_TARGET */
    [THERM_AT_TARGET] = {
        [EVT_START]     = { THERM_AT_TARGET, act_nop },
        [EVT_TEMP_LOW]  = { THERM_HEATING,   act_heater_on },
        [EVT_TEMP_OK]   = { THERM_AT_TARGET, act_nop },
        [EVT_TEMP_HIGH] = { THERM_COOLING,   act_fan_on },
        [EVT_STOP]      = { THERM_IDLE,      act_nop },
        [EVT_FAULT]     = { THERM_ERROR,     act_alarm },
        [EVT_RESET]     = { THERM_IDLE,      act_nop },
    },
    /* COOLING */
    [THERM_COOLING] = {
        [EVT_START]     = { THERM_COOLING,   act_nop },
        [EVT_TEMP_LOW]  = { THERM_HEATING,   act_heater_on },
        [EVT_TEMP_OK]   = { THERM_AT_TARGET, act_fan_off },
        [EVT_TEMP_HIGH] = { THERM_COOLING,   act_nop },
        [EVT_STOP]      = { THERM_IDLE,      act_fan_off },
        [EVT_FAULT]     = { THERM_ERROR,     act_alarm },
        [EVT_RESET]     = { THERM_IDLE,      act_fan_off },
    },
    /* ERROR */
    [THERM_ERROR] = {
        [EVT_START]     = { THERM_ERROR,     act_nop },
        [EVT_TEMP_LOW]  = { THERM_ERROR,     act_nop },
        [EVT_TEMP_OK]   = { THERM_ERROR,     act_nop },
        [EVT_TEMP_HIGH] = { THERM_ERROR,     act_nop },
        [EVT_STOP]      = { THERM_ERROR,     act_nop },
        [EVT_FAULT]     = { THERM_ERROR,     act_nop },
        [EVT_RESET]     = { THERM_IDLE,      act_reset },
    },
};

static void demo_thermostat(void) {
    printf("=== FSM 2: Thermostat (Table-Driven) ===\n\n");

    ThermState state = THERM_IDLE;

    ThermEvent scenario[] = {
        EVT_START,      /* IDLE -> HEATING */
        EVT_TEMP_LOW,   /* HEATING (stay) */
        EVT_TEMP_OK,    /* HEATING -> AT_TARGET */
        EVT_TEMP_HIGH,  /* AT_TARGET -> COOLING */
        EVT_TEMP_OK,    /* COOLING -> AT_TARGET */
        EVT_FAULT,      /* AT_TARGET -> ERROR */
        EVT_STOP,       /* ERROR (stays — must reset) */
        EVT_RESET,      /* ERROR -> IDLE */
        EVT_START,      /* IDLE -> HEATING */
        EVT_STOP,       /* HEATING -> IDLE */
    };
    int n = sizeof(scenario) / sizeof(scenario[0]);

    printf("  Step  Event        State Before    Action           State After\n");
    printf("  ----  -----------  -------------   ---------------  -----------\n");

    for (int i = 0; i < n; i++) {
        ThermEvent evt = scenario[i];
        const ThermTransition *t = &therm_table[state][evt];

        printf("  %2d    %-11s  %-13s   ", i + 1,
               therm_event_names[evt], therm_state_names[state]);

        t->action();
        state = t->next_state;
        printf("                 %s\n", therm_state_names[state]);
    }
    printf("\n");
}

/* ================================================================
 * EXAMPLE 3: Door Lock (FSM with Entry/Exit Actions)
 * ================================================================ */

typedef enum {
    DOOR_LOCKED,
    DOOR_UNLOCKED,
    DOOR_OPEN,
    DOOR_ALARM,
    DOOR_NUM_STATES
} DoorState;

static const char *door_state_names[] = {
    "LOCKED", "UNLOCKED", "OPEN", "ALARM"
};

typedef struct {
    DoorState state;
    uint32_t  failed_attempts;
    uint32_t  unlock_timeout;
    bool      alarm_active;
} DoorLockFSM;

static void door_on_enter(DoorLockFSM *fsm, DoorState state) {
    printf("    [ENTER %s] ", door_state_names[state]);
    switch (state) {
    case DOOR_LOCKED:
        printf("Motor: lock engaged, LED: red\n");
        break;
    case DOOR_UNLOCKED:
        fsm->unlock_timeout = 10;
        printf("Motor: lock released, LED: green, timeout=%u s\n",
               fsm->unlock_timeout);
        break;
    case DOOR_OPEN:
        printf("Sensor: door ajar, LED: green blinking\n");
        break;
    case DOOR_ALARM:
        fsm->alarm_active = true;
        printf("BUZZER ON, LED: red flashing, sending alert!\n");
        break;
    default:
        break;
    }
}

static void door_on_exit(DoorLockFSM *fsm, DoorState state) {
    (void)fsm;
    printf("    [EXIT  %s] ", door_state_names[state]);
    switch (state) {
    case DOOR_ALARM:
        printf("Buzzer OFF\n");
        fsm->alarm_active = false;
        break;
    default:
        printf("Cleanup\n");
        break;
    }
}

static void door_transition(DoorLockFSM *fsm, DoorState new_state) {
    if (fsm->state != new_state) {
        door_on_exit(fsm, fsm->state);
        fsm->state = new_state;
        door_on_enter(fsm, new_state);
    }
}

static void door_handle_correct_code(DoorLockFSM *fsm) {
    printf("  Event: CORRECT CODE\n");
    fsm->failed_attempts = 0;
    switch (fsm->state) {
    case DOOR_LOCKED:
        door_transition(fsm, DOOR_UNLOCKED);
        break;
    case DOOR_ALARM:
        door_transition(fsm, DOOR_LOCKED);
        break;
    default:
        printf("    (no effect in state %s)\n", door_state_names[fsm->state]);
        break;
    }
}

static void door_handle_wrong_code(DoorLockFSM *fsm) {
    printf("  Event: WRONG CODE\n");
    fsm->failed_attempts++;
    printf("    Failed attempts: %u/3\n", fsm->failed_attempts);
    if (fsm->failed_attempts >= 3) {
        door_transition(fsm, DOOR_ALARM);
    }
}

static void door_handle_open(DoorLockFSM *fsm) {
    printf("  Event: DOOR OPENED\n");
    switch (fsm->state) {
    case DOOR_UNLOCKED:
        door_transition(fsm, DOOR_OPEN);
        break;
    case DOOR_LOCKED:
        printf("    FORCED ENTRY DETECTED!\n");
        door_transition(fsm, DOOR_ALARM);
        break;
    default:
        break;
    }
}

static void door_handle_close(DoorLockFSM *fsm) {
    printf("  Event: DOOR CLOSED\n");
    if (fsm->state == DOOR_OPEN) {
        door_transition(fsm, DOOR_LOCKED);
    }
}

static void door_handle_timeout(DoorLockFSM *fsm) {
    printf("  Event: TIMEOUT\n");
    if (fsm->state == DOOR_UNLOCKED) {
        printf("    Auto-locking (no one opened the door)\n");
        door_transition(fsm, DOOR_LOCKED);
    }
}

static void demo_door_lock(void) {
    printf("=== FSM 3: Door Lock (Entry/Exit Actions) ===\n\n");

    DoorLockFSM fsm = {
        .state = DOOR_LOCKED,
        .failed_attempts = 0,
        .unlock_timeout = 0,
        .alarm_active = false
    };

    door_on_enter(&fsm, DOOR_LOCKED);
    printf("\n");

    printf("--- Scenario: Normal unlock-open-close ---\n\n");
    door_handle_correct_code(&fsm);
    printf("\n");
    door_handle_open(&fsm);
    printf("\n");
    door_handle_close(&fsm);
    printf("\n");

    printf("--- Scenario: 3 wrong codes → alarm → reset ---\n\n");
    door_handle_wrong_code(&fsm);
    printf("\n");
    door_handle_wrong_code(&fsm);
    printf("\n");
    door_handle_wrong_code(&fsm);
    printf("\n");
    door_handle_correct_code(&fsm);
    printf("\n");

    printf("--- Scenario: Timeout auto-lock ---\n\n");
    door_handle_correct_code(&fsm);
    printf("\n");
    door_handle_timeout(&fsm);
    printf("\n");

    printf("--- Scenario: Forced entry ---\n\n");
    door_handle_open(&fsm);
    printf("\n");
}

/* ----------------------------------------------------------------
 * FSM pattern comparison
 * ---------------------------------------------------------------- */
static void demo_comparison(void) {
    printf("=== FSM Pattern Comparison ===\n\n");

    printf("  ┌──────────────┬────────────────────────────────────────┐\n");
    printf("  │ Pattern      │ When to Use                            │\n");
    printf("  ├──────────────┼────────────────────────────────────────┤\n");
    printf("  │ Switch-Case  │ < 5 states, simple logic               │\n");
    printf("  │              │ Quick prototyping                      │\n");
    printf("  ├──────────────┼────────────────────────────────────────┤\n");
    printf("  │ Table-Driven │ Many states/events, regular structure  │\n");
    printf("  │              │ Auto-generated from diagrams           │\n");
    printf("  ├──────────────┼────────────────────────────────────────┤\n");
    printf("  │ Entry/Exit   │ Complex state behaviors                │\n");
    printf("  │              │ Resource management on transitions     │\n");
    printf("  └──────────────┴────────────────────────────────────────┘\n\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Finite State Machine Patterns           ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_traffic_light();
    demo_thermostat();
    demo_door_lock();
    demo_comparison();

    printf("═══ End of State Machine Demo ═══\n");
    return 0;
}
