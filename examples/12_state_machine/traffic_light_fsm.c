/**
 * @file    traffic_light_fsm.c
 * @brief   Table-driven finite state machine for a traffic light controller.
 * @target  Any embedded platform
 *
 * Demonstrates:
 *  - Table-driven state machine (declarative, easy to maintain)
 *  - Switch-case state machine (imperative, good for simple cases)
 *  - State entry/exit actions
 *  - Timed transitions
 *  - Event-driven transitions (pedestrian button, emergency)
 *
 * State Diagram:
 *
 *   ┌──────────┐  timer   ┌─────────────┐  timer   ┌──────────┐
 *   │   RED    ├─────────►│ RED+YELLOW  ├─────────►│  GREEN   │
 *   │ (30s)   │          │  (2s)       │          │  (25s)   │
 *   └────▲─────┘          └─────────────┘          └────┬─────┘
 *        │                                               │ timer
 *        │         ┌──────────┐                          │
 *        └─────────┤  YELLOW  │◄─────────────────────────┘
 *         timer    │  (3s)    │
 *                  └──────────┘
 *
 *   Emergency event → immediate transition to RED from any state
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  State and Event Definitions                                                */
/* ========================================================================== */

typedef enum {
    STATE_RED,
    STATE_RED_YELLOW,
    STATE_GREEN,
    STATE_YELLOW,
    STATE_FLASH_RED,     /* Emergency / fault mode */
    STATE_OFF,
    STATE_COUNT
} fsm_state_t;

typedef enum {
    EVT_TIMER,           /* Timer expired                     */
    EVT_PEDESTRIAN,      /* Pedestrian button pressed          */
    EVT_EMERGENCY_ON,    /* Emergency vehicle approaching      */
    EVT_EMERGENCY_OFF,   /* Emergency vehicle passed           */
    EVT_FAULT,           /* Hardware fault detected            */
    EVT_RESET,           /* Manual reset                       */
    EVT_COUNT
} fsm_event_t;

/* ========================================================================== */
/*  Hardware Interface (abstracted)                                            */
/* ========================================================================== */

typedef struct {
    bool red;
    bool yellow;
    bool green;
    bool pedestrian_walk;
    bool pedestrian_stop;
} light_output_t;

static void set_lights(const light_output_t *output)
{
    /* In real code, this writes to GPIO registers */
    (void)output;
}

/* Predefined light configurations */
static const light_output_t LIGHTS_RED         = { true,  false, false, false, true  };
static const light_output_t LIGHTS_RED_YELLOW  = { true,  true,  false, false, true  };
static const light_output_t LIGHTS_GREEN       = { false, false, true,  true,  false };
static const light_output_t LIGHTS_YELLOW      = { false, true,  false, false, true  };
static const light_output_t LIGHTS_OFF         = { false, false, false, false, false };

/* ========================================================================== */
/*  State Machine Context                                                      */
/* ========================================================================== */

typedef struct {
    fsm_state_t current_state;
    uint32_t    state_entry_time;
    uint32_t    state_timeout_ms;
    bool        pedestrian_requested;
    uint32_t    flash_toggle_time;
} fsm_context_t;

/* Duration for each state (milliseconds) */
static const uint32_t state_durations[STATE_COUNT] = {
    [STATE_RED]        = 30000,   /* 30 seconds */
    [STATE_RED_YELLOW] = 2000,    /*  2 seconds */
    [STATE_GREEN]      = 25000,   /* 25 seconds */
    [STATE_YELLOW]     = 3000,    /*  3 seconds */
    [STATE_FLASH_RED]  = 500,     /* Flash toggle rate */
    [STATE_OFF]        = 0,       /* No timeout  */
};

/* ========================================================================== */
/*  Approach 1: Table-Driven State Machine                                     */
/* ========================================================================== */

typedef void (*action_func_t)(fsm_context_t *ctx);

typedef struct {
    fsm_state_t  next_state;
    action_func_t action;        /* Function to call during transition */
} transition_t;

/* ---- Action Functions ---- */

static void action_set_red(fsm_context_t *ctx)
{
    set_lights(&LIGHTS_RED);
    ctx->state_timeout_ms = state_durations[STATE_RED];
}

static void action_set_red_yellow(fsm_context_t *ctx)
{
    set_lights(&LIGHTS_RED_YELLOW);
    ctx->state_timeout_ms = state_durations[STATE_RED_YELLOW];
}

static void action_set_green(fsm_context_t *ctx)
{
    set_lights(&LIGHTS_GREEN);
    ctx->state_timeout_ms = state_durations[STATE_GREEN];
    ctx->pedestrian_requested = false;
}

static void action_set_yellow(fsm_context_t *ctx)
{
    set_lights(&LIGHTS_YELLOW);
    ctx->state_timeout_ms = state_durations[STATE_YELLOW];
}

static void action_enter_emergency(fsm_context_t *ctx)
{
    set_lights(&LIGHTS_RED);
    ctx->state_timeout_ms = 0;  /* No auto-transition */
}

static void action_shorten_green(fsm_context_t *ctx)
{
    /* Shorten green phase when pedestrian button is pressed */
    if (ctx->state_timeout_ms > 5000) {
        ctx->state_timeout_ms = 5000;
    }
    ctx->pedestrian_requested = true;
}

static void action_nop(fsm_context_t *ctx)
{
    (void)ctx;
}

/*
 * State transition table.
 * Each cell defines: {next_state, action_function}
 *
 * Reads as: "In state X, when event Y occurs, go to state Z and call action."
 */
static const transition_t transition_table[STATE_COUNT][EVT_COUNT] = {
    /* STATE_RED */
    [STATE_RED] = {
        [EVT_TIMER]         = { STATE_RED_YELLOW,  action_set_red_yellow },
        [EVT_PEDESTRIAN]    = { STATE_RED,          action_nop           },
        [EVT_EMERGENCY_ON]  = { STATE_RED,          action_enter_emergency },
        [EVT_EMERGENCY_OFF] = { STATE_RED,          action_nop           },
        [EVT_FAULT]         = { STATE_FLASH_RED,    action_nop           },
        [EVT_RESET]         = { STATE_RED,          action_set_red       },
    },
    /* STATE_RED_YELLOW */
    [STATE_RED_YELLOW] = {
        [EVT_TIMER]         = { STATE_GREEN,        action_set_green     },
        [EVT_PEDESTRIAN]    = { STATE_RED_YELLOW,   action_nop           },
        [EVT_EMERGENCY_ON]  = { STATE_RED,          action_enter_emergency },
        [EVT_EMERGENCY_OFF] = { STATE_RED_YELLOW,   action_nop           },
        [EVT_FAULT]         = { STATE_FLASH_RED,    action_nop           },
        [EVT_RESET]         = { STATE_RED,          action_set_red       },
    },
    /* STATE_GREEN */
    [STATE_GREEN] = {
        [EVT_TIMER]         = { STATE_YELLOW,       action_set_yellow    },
        [EVT_PEDESTRIAN]    = { STATE_GREEN,        action_shorten_green },
        [EVT_EMERGENCY_ON]  = { STATE_YELLOW,       action_set_yellow    },
        [EVT_EMERGENCY_OFF] = { STATE_GREEN,        action_nop           },
        [EVT_FAULT]         = { STATE_FLASH_RED,    action_nop           },
        [EVT_RESET]         = { STATE_RED,          action_set_red       },
    },
    /* STATE_YELLOW */
    [STATE_YELLOW] = {
        [EVT_TIMER]         = { STATE_RED,          action_set_red       },
        [EVT_PEDESTRIAN]    = { STATE_YELLOW,       action_nop           },
        [EVT_EMERGENCY_ON]  = { STATE_YELLOW,       action_nop           },
        [EVT_EMERGENCY_OFF] = { STATE_YELLOW,       action_nop           },
        [EVT_FAULT]         = { STATE_FLASH_RED,    action_nop           },
        [EVT_RESET]         = { STATE_RED,          action_set_red       },
    },
    /* STATE_FLASH_RED */
    [STATE_FLASH_RED] = {
        [EVT_TIMER]         = { STATE_FLASH_RED,    action_nop           },
        [EVT_PEDESTRIAN]    = { STATE_FLASH_RED,    action_nop           },
        [EVT_EMERGENCY_ON]  = { STATE_FLASH_RED,    action_nop           },
        [EVT_EMERGENCY_OFF] = { STATE_FLASH_RED,    action_nop           },
        [EVT_FAULT]         = { STATE_FLASH_RED,    action_nop           },
        [EVT_RESET]         = { STATE_RED,          action_set_red       },
    },
    /* STATE_OFF */
    [STATE_OFF] = {
        [EVT_TIMER]         = { STATE_OFF,          action_nop           },
        [EVT_PEDESTRIAN]    = { STATE_OFF,          action_nop           },
        [EVT_EMERGENCY_ON]  = { STATE_OFF,          action_nop           },
        [EVT_EMERGENCY_OFF] = { STATE_OFF,          action_nop           },
        [EVT_FAULT]         = { STATE_OFF,          action_nop           },
        [EVT_RESET]         = { STATE_RED,          action_set_red       },
    },
};

/* ========================================================================== */
/*  FSM Engine                                                                 */
/* ========================================================================== */

static const char *state_names[STATE_COUNT] = {
    "RED", "RED+YELLOW", "GREEN", "YELLOW", "FLASH_RED", "OFF"
};

static const char *event_names[EVT_COUNT] = {
    "TIMER", "PEDESTRIAN", "EMERGENCY_ON", "EMERGENCY_OFF", "FAULT", "RESET"
};

/**
 * Initialize the state machine.
 */
void fsm_init(fsm_context_t *ctx)
{
    ctx->current_state       = STATE_RED;
    ctx->state_entry_time    = 0;
    ctx->state_timeout_ms    = state_durations[STATE_RED];
    ctx->pedestrian_requested = false;
    ctx->flash_toggle_time   = 0;

    set_lights(&LIGHTS_RED);
}

/**
 * Process an event through the state machine.
 */
void fsm_process_event(fsm_context_t *ctx, fsm_event_t event, uint32_t now_ms)
{
    if (event >= EVT_COUNT) return;

    const transition_t *trans = &transition_table[ctx->current_state][event];
    fsm_state_t old_state = ctx->current_state;

    /* Call the transition action */
    if (trans->action) {
        trans->action(ctx);
    }

    /* Update state */
    if (trans->next_state != old_state) {
        ctx->current_state    = trans->next_state;
        ctx->state_entry_time = now_ms;
        ctx->state_timeout_ms = state_durations[trans->next_state];
    }

    (void)state_names;
    (void)event_names;
}

/**
 * Periodic update — checks for timer expiry and handles flash mode.
 * Call this from the main loop or a timer interrupt.
 */
void fsm_update(fsm_context_t *ctx, uint32_t now_ms)
{
    /* Handle flashing in FLASH_RED state */
    if (ctx->current_state == STATE_FLASH_RED) {
        if ((now_ms - ctx->flash_toggle_time) >= 500) {
            ctx->flash_toggle_time = now_ms;
            static bool flash_on = false;
            flash_on = !flash_on;
            if (flash_on) {
                set_lights(&LIGHTS_RED);
            } else {
                set_lights(&LIGHTS_OFF);
            }
        }
        return;
    }

    /* Check for timeout → generate EVT_TIMER */
    if (ctx->state_timeout_ms > 0) {
        if ((now_ms - ctx->state_entry_time) >= ctx->state_timeout_ms) {
            fsm_process_event(ctx, EVT_TIMER, now_ms);
        }
    }
}

/* ========================================================================== */
/*  Main — Example Usage                                                       */
/* ========================================================================== */

extern uint32_t millis(void);
extern bool button_pressed(void);

int main(void)
{
    /* system_init(); */

    fsm_context_t traffic;
    fsm_init(&traffic);

    while (1) {
        uint32_t now = millis();

        /* Check for external events */
        if (button_pressed()) {
            fsm_process_event(&traffic, EVT_PEDESTRIAN, now);
        }

        /* Periodic update (handles timing and flash mode) */
        fsm_update(&traffic, now);

        /* Sleep until next tick */
        __asm volatile ("wfi");
    }
}
