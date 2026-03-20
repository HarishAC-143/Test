/**
 * @file    09_state_machine.c
 * @brief   Finite State Machine patterns for embedded systems
 *
 * Demonstrates:
 *  - Simple switch-case FSM
 *  - Table-driven FSM with function pointers
 *  - Hierarchical State Machine (HSM) pattern
 *  - Timed state transitions
 *  - Practical example: thermostat controller
 *
 * Target: Any embedded platform (hardware-independent logic)
 */

#include <stdint.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────
 * Pattern 1: Switch-Case FSM (Simplest, Good for < 5 States)
 *
 * Example: Traffic light controller
 * ────────────────────────────────────────────────────────────────────────── */

typedef enum {
    TRAFFIC_RED,
    TRAFFIC_RED_YELLOW,
    TRAFFIC_GREEN,
    TRAFFIC_YELLOW
} traffic_state_t;

typedef struct {
    traffic_state_t state;
    uint32_t        state_entered_ms;
    uint32_t        pedestrian_request;
} traffic_light_t;

extern uint32_t millis(void);

/* Duration in each state (milliseconds) */
#define RED_DURATION        5000
#define RED_YELLOW_DURATION 1000
#define GREEN_DURATION      4000
#define YELLOW_DURATION     1500

void traffic_init(traffic_light_t *tl)
{
    tl->state = TRAFFIC_RED;
    tl->state_entered_ms = millis();
    tl->pedestrian_request = 0;
}

static void set_lights(uint8_t red, uint8_t yellow, uint8_t green)
{
    (void)red; (void)yellow; (void)green;
    /* gpio_write(LED_RED_PORT, LED_RED_PIN, red);
       gpio_write(LED_YEL_PORT, LED_YEL_PIN, yellow);
       gpio_write(LED_GRN_PORT, LED_GRN_PIN, green); */
}

void traffic_update(traffic_light_t *tl)
{
    uint32_t elapsed = millis() - tl->state_entered_ms;

    switch (tl->state) {
    case TRAFFIC_RED:
        set_lights(1, 0, 0);
        if (elapsed >= RED_DURATION) {
            tl->state = TRAFFIC_RED_YELLOW;
            tl->state_entered_ms = millis();
        }
        break;

    case TRAFFIC_RED_YELLOW:
        set_lights(1, 1, 0);
        if (elapsed >= RED_YELLOW_DURATION) {
            tl->state = TRAFFIC_GREEN;
            tl->state_entered_ms = millis();
        }
        break;

    case TRAFFIC_GREEN:
        set_lights(0, 0, 1);
        if (elapsed >= GREEN_DURATION || tl->pedestrian_request) {
            tl->state = TRAFFIC_YELLOW;
            tl->state_entered_ms = millis();
            tl->pedestrian_request = 0;
        }
        break;

    case TRAFFIC_YELLOW:
        set_lights(0, 1, 0);
        if (elapsed >= YELLOW_DURATION) {
            tl->state = TRAFFIC_RED;
            tl->state_entered_ms = millis();
        }
        break;
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Pattern 2: Table-Driven FSM (Scalable, Maintainable)
 *
 * Example: Thermostat controller
 * ────────────────────────────────────────────────────────────────────────── */

typedef enum {
    THERMO_IDLE,
    THERMO_HEATING,
    THERMO_AT_TEMP,
    THERMO_COOLING,
    THERMO_ERROR,
    THERMO_STATE_COUNT
} thermo_state_t;

typedef enum {
    THERMO_EVT_START,
    THERMO_EVT_STOP,
    THERMO_EVT_TEMP_BELOW,
    THERMO_EVT_TEMP_ABOVE,
    THERMO_EVT_TEMP_OK,
    THERMO_EVT_SENSOR_FAIL,
    THERMO_EVT_RESET,
    THERMO_EVT_COUNT
} thermo_event_t;

typedef void (*state_action_t)(void);
typedef uint8_t (*state_guard_t)(void);

typedef struct {
    thermo_state_t  next_state;
    state_action_t  action;
    state_guard_t   guard;     /* Optional: transition only if guard returns 1 */
} transition_entry_t;

/* Actions */
static void heater_on(void)    { /* gpio_write(RELAY_PORT, RELAY_PIN, 1); */ }
static void heater_off(void)   { /* gpio_write(RELAY_PORT, RELAY_PIN, 0); */ }
static void fan_on(void)       { /* gpio_write(FAN_PORT, FAN_PIN, 1); */ }
static void fan_off(void)      { /* gpio_write(FAN_PORT, FAN_PIN, 0); */ }
static void alarm_on(void)     { /* buzzer_on(); led_error_on(); */ }
static void alarm_off(void)    { /* buzzer_off(); led_error_off(); */ }
static void log_event(void)    { /* uart_printf(...); */ }
static void do_nothing(void)   { }

/* Guard: check if system has been in error for long enough */
static uint32_t error_enter_time = 0;
static uint8_t error_cooldown_expired(void)
{
    return (millis() - error_enter_time) > 10000;
}

/* Transition table */
static const transition_entry_t
thermo_fsm[THERMO_STATE_COUNT][THERMO_EVT_COUNT] = {

    /* THERMO_IDLE */
    [THERMO_IDLE] = {
        [THERMO_EVT_START]       = {THERMO_HEATING,  heater_on,  0},
        [THERMO_EVT_STOP]        = {THERMO_IDLE,     do_nothing, 0},
        [THERMO_EVT_SENSOR_FAIL] = {THERMO_ERROR,    alarm_on,   0},
    },

    /* THERMO_HEATING */
    [THERMO_HEATING] = {
        [THERMO_EVT_TEMP_OK]     = {THERMO_AT_TEMP,  heater_off,  0},
        [THERMO_EVT_TEMP_ABOVE]  = {THERMO_COOLING,  heater_off,  0},
        [THERMO_EVT_STOP]        = {THERMO_IDLE,     heater_off,  0},
        [THERMO_EVT_SENSOR_FAIL] = {THERMO_ERROR,    alarm_on,    0},
    },

    /* THERMO_AT_TEMP */
    [THERMO_AT_TEMP] = {
        [THERMO_EVT_TEMP_BELOW]  = {THERMO_HEATING,  heater_on,  0},
        [THERMO_EVT_TEMP_ABOVE]  = {THERMO_COOLING,  fan_on,     0},
        [THERMO_EVT_STOP]        = {THERMO_IDLE,     do_nothing, 0},
        [THERMO_EVT_SENSOR_FAIL] = {THERMO_ERROR,    alarm_on,   0},
    },

    /* THERMO_COOLING */
    [THERMO_COOLING] = {
        [THERMO_EVT_TEMP_OK]     = {THERMO_AT_TEMP,  fan_off,    0},
        [THERMO_EVT_TEMP_BELOW]  = {THERMO_HEATING,  heater_on,  0},
        [THERMO_EVT_STOP]        = {THERMO_IDLE,     fan_off,    0},
        [THERMO_EVT_SENSOR_FAIL] = {THERMO_ERROR,    alarm_on,   0},
    },

    /* THERMO_ERROR */
    [THERMO_ERROR] = {
        [THERMO_EVT_RESET] = {THERMO_IDLE, alarm_off,
                              error_cooldown_expired},
    },
};

/* FSM engine */
typedef struct {
    thermo_state_t current;
    thermo_state_t previous;
    uint32_t       state_enter_time;
    uint32_t       transition_count;
} thermo_fsm_t;

void thermo_fsm_init(thermo_fsm_t *fsm)
{
    fsm->current = THERMO_IDLE;
    fsm->previous = THERMO_IDLE;
    fsm->state_enter_time = millis();
    fsm->transition_count = 0;
}

void thermo_fsm_dispatch(thermo_fsm_t *fsm, thermo_event_t evt)
{
    if (evt >= THERMO_EVT_COUNT) return;

    const transition_entry_t *t = &thermo_fsm[fsm->current][evt];

    /* If no action is defined, the transition is not valid */
    if (t->action == 0) return;

    /* Check guard condition */
    if (t->guard && !t->guard()) return;

    /* Execute transition */
    t->action();
    fsm->previous = fsm->current;
    fsm->current = t->next_state;
    fsm->state_enter_time = millis();
    fsm->transition_count++;

    if (fsm->current == THERMO_ERROR) {
        error_enter_time = millis();
    }
}

uint32_t thermo_fsm_time_in_state(const thermo_fsm_t *fsm)
{
    return millis() - fsm->state_enter_time;
}

/* ──────────────────────────────────────────────────────────────────────────
 * Pattern 3: State Machine with Entry/Exit Actions
 *
 * Each state has optional on_enter and on_exit callbacks that run
 * once during transitions.
 * ────────────────────────────────────────────────────────────────────────── */

typedef void (*state_handler_t)(void);

typedef struct {
    const char     *name;
    state_handler_t on_enter;
    state_handler_t on_exit;
    state_handler_t on_run;     /* Called every cycle while in this state */
} state_descriptor_t;

typedef struct {
    const state_descriptor_t *states;
    uint8_t                   state_count;
    uint8_t                   current;
    uint8_t                   next;     /* Set this to trigger a transition */
    uint8_t                   changed;
} generic_fsm_t;

void gfsm_init(generic_fsm_t *fsm, const state_descriptor_t *states,
                uint8_t count, uint8_t initial_state)
{
    fsm->states = states;
    fsm->state_count = count;
    fsm->current = initial_state;
    fsm->next = initial_state;
    fsm->changed = 1;  /* Trigger on_enter for initial state */
}

void gfsm_transition(generic_fsm_t *fsm, uint8_t new_state)
{
    if (new_state < fsm->state_count && new_state != fsm->current) {
        fsm->next = new_state;
    }
}

void gfsm_run(generic_fsm_t *fsm)
{
    if (fsm->next != fsm->current || fsm->changed) {
        /* Exit current state */
        if (!fsm->changed && fsm->states[fsm->current].on_exit) {
            fsm->states[fsm->current].on_exit();
        }

        fsm->current = fsm->next;

        /* Enter new state */
        if (fsm->states[fsm->current].on_enter) {
            fsm->states[fsm->current].on_enter();
        }

        fsm->changed = 0;
    }

    /* Run current state */
    if (fsm->states[fsm->current].on_run) {
        fsm->states[fsm->current].on_run();
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: Thermostat with Table-Driven FSM
 * ────────────────────────────────────────────────────────────────────────── */

extern int16_t  read_temperature(void);   /* From ADC/sensor driver */
extern void     uart_printf(void *uart, const char *fmt, ...);
extern void     delay_ms(uint32_t ms);

static const char *thermo_state_names[] = {
    "IDLE", "HEATING", "AT_TEMP", "COOLING", "ERROR"
};

int main(void)
{
    thermo_fsm_t thermostat;
    thermo_fsm_init(&thermostat);

    int16_t target_temp = 22;  /* Target: 22°C */
    int16_t hysteresis  = 1;   /* ±1°C deadband */

    uart_printf((void *)0x40011000U,
        "Thermostat FSM Demo | Target: %d°C\r\n", target_temp);

    /* Start the heating system */
    thermo_fsm_dispatch(&thermostat, THERMO_EVT_START);

    while (1) {
        int16_t current_temp = read_temperature();

        /* Generate events based on temperature */
        if (current_temp < (target_temp - hysteresis)) {
            thermo_fsm_dispatch(&thermostat, THERMO_EVT_TEMP_BELOW);
        } else if (current_temp > (target_temp + hysteresis)) {
            thermo_fsm_dispatch(&thermostat, THERMO_EVT_TEMP_ABOVE);
        } else {
            thermo_fsm_dispatch(&thermostat, THERMO_EVT_TEMP_OK);
        }

        /* Report */
        uart_printf((void *)0x40011000U,
            "Temp: %d°C | State: %s | In-state: %lums | Transitions: %lu\r\n",
            current_temp,
            thermo_state_names[thermostat.current],
            (unsigned long)thermo_fsm_time_in_state(&thermostat),
            (unsigned long)thermostat.transition_count);

        delay_ms(1000);
    }

    return 0;
}
