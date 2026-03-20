# Chapter 12: State Machines

State machines are one of the most powerful design patterns in embedded programming. They bring structure and predictability to complex, event-driven systems — from protocol parsers to motor controllers to user interfaces.

## What Is a Finite State Machine (FSM)?

A finite state machine is a system that:

1. Has a **finite set of states** (e.g., IDLE, RUNNING, ERROR)
2. Is in **exactly one state** at any time
3. Transitions between states based on **events** (inputs, timeouts, conditions)
4. May perform **actions** on entry, exit, or during transitions

```
          [BUTTON]             [TIMEOUT]
 ┌──────┐ ──────▶ ┌─────────┐ ──────▶ ┌──────┐
 │ IDLE │         │ RUNNING │         │ DONE │
 └──────┘ ◀────── └─────────┘         └──────┘
          [CANCEL]
```

## Implementation 1: Switch-Case FSM

The simplest and most common approach:

```c
typedef enum {
    STATE_IDLE,
    STATE_HEATING,
    STATE_MAINTAINING,
    STATE_COOLING,
    STATE_ERROR
} ThermostatState;

typedef enum {
    EVT_START,
    EVT_TEMP_REACHED,
    EVT_TEMP_LOW,
    EVT_TIMEOUT,
    EVT_FAULT,
    EVT_RESET
} ThermostatEvent;

static ThermostatState current_state = STATE_IDLE;

void thermostat_handle_event(ThermostatEvent event)
{
    switch (current_state) {
    case STATE_IDLE:
        if (event == EVT_START) {
            heater_on();
            current_state = STATE_HEATING;
        }
        break;

    case STATE_HEATING:
        if (event == EVT_TEMP_REACHED) {
            heater_off();
            start_timer(MAINTAIN_TIMEOUT);
            current_state = STATE_MAINTAINING;
        } else if (event == EVT_FAULT) {
            heater_off();
            alarm_on();
            current_state = STATE_ERROR;
        }
        break;

    case STATE_MAINTAINING:
        if (event == EVT_TEMP_LOW) {
            heater_on();
            current_state = STATE_HEATING;
        } else if (event == EVT_TIMEOUT) {
            fan_on();
            current_state = STATE_COOLING;
        }
        break;

    case STATE_COOLING:
        if (event == EVT_TEMP_LOW) {
            fan_off();
            current_state = STATE_IDLE;
        }
        break;

    case STATE_ERROR:
        if (event == EVT_RESET) {
            alarm_off();
            current_state = STATE_IDLE;
        }
        break;
    }
}
```

### Running the FSM

```c
int main(void)
{
    peripherals_init();

    while (1) {
        ThermostatEvent evt = get_next_event();
        thermostat_handle_event(evt);
    }
}
```

## Implementation 2: Table-Driven FSM

For larger state machines, a transition table is more maintainable:

```c
typedef void (*ActionFunc)(void);

typedef struct {
    ThermostatState current;
    ThermostatEvent event;
    ThermostatState next;
    ActionFunc      action;
} Transition;

void action_start_heating(void) { heater_on(); }
void action_maintain(void)      { heater_off(); start_timer(60000); }
void action_start_cooling(void) { fan_on(); }
void action_stop_cooling(void)  { fan_off(); }
void action_fault(void)         { heater_off(); alarm_on(); }
void action_reset(void)         { alarm_off(); }

static const Transition transitions[] = {
    /* Current           Event              Next              Action */
    { STATE_IDLE,        EVT_START,         STATE_HEATING,     action_start_heating },
    { STATE_HEATING,     EVT_TEMP_REACHED,  STATE_MAINTAINING, action_maintain },
    { STATE_HEATING,     EVT_FAULT,         STATE_ERROR,       action_fault },
    { STATE_MAINTAINING, EVT_TEMP_LOW,      STATE_HEATING,     action_start_heating },
    { STATE_MAINTAINING, EVT_TIMEOUT,       STATE_COOLING,     action_start_cooling },
    { STATE_COOLING,     EVT_TEMP_LOW,      STATE_IDLE,        action_stop_cooling },
    { STATE_ERROR,       EVT_RESET,         STATE_IDLE,        action_reset },
};

#define NUM_TRANSITIONS (sizeof(transitions) / sizeof(transitions[0]))

void fsm_handle_event(ThermostatEvent event)
{
    for (uint8_t i = 0; i < NUM_TRANSITIONS; i++) {
        if (transitions[i].current == current_state &&
            transitions[i].event == event) {

            if (transitions[i].action)
                transitions[i].action();

            current_state = transitions[i].next;
            return;
        }
    }
    /* No matching transition — event ignored in current state */
}
```

### Advantages of Table-Driven FSMs

- Adding a new transition is a single line in the table
- The transition logic is separate from the action code
- The table can be stored in Flash (`const`) to save RAM
- Easy to auto-generate from design tools

## Practical Example: Traffic Light Controller

```c
typedef enum {
    TL_RED,
    TL_RED_YELLOW,
    TL_GREEN,
    TL_YELLOW
} TrafficState;

typedef struct {
    TrafficState state;
    uint32_t     duration_ms;
    uint8_t      red;
    uint8_t      yellow;
    uint8_t      green;
} TrafficPhase;

static const TrafficPhase phases[] = {
    { TL_RED,        5000, 1, 0, 0 },
    { TL_RED_YELLOW, 1000, 1, 1, 0 },
    { TL_GREEN,      5000, 0, 0, 1 },
    { TL_YELLOW,     2000, 0, 1, 0 },
};

#define NUM_PHASES (sizeof(phases) / sizeof(phases[0]))

void traffic_light_run(void)
{
    uint8_t phase_idx = 0;

    while (1) {
        const TrafficPhase *phase = &phases[phase_idx];

        set_traffic_light(phase->red, phase->yellow, phase->green);
        delay_ms(phase->duration_ms);

        phase_idx = (phase_idx + 1) % NUM_PHASES;
    }
}
```

## Practical Example: UART Protocol Parser

Parse incoming data with a defined frame format: `[START][LEN][DATA...][CRC]`

```c
typedef enum {
    PARSE_WAIT_START,
    PARSE_GET_LENGTH,
    PARSE_GET_DATA,
    PARSE_GET_CRC
} ParseState;

typedef struct {
    ParseState state;
    uint8_t    length;
    uint8_t    data[256];
    uint8_t    index;
    uint8_t    expected_crc;
} FrameParser;

#define START_BYTE 0xAA

void parser_init(FrameParser *p)
{
    p->state = PARSE_WAIT_START;
    p->index = 0;
}

int parser_feed_byte(FrameParser *p, uint8_t byte)
{
    switch (p->state) {
    case PARSE_WAIT_START:
        if (byte == START_BYTE) {
            p->state = PARSE_GET_LENGTH;
            p->index = 0;
        }
        break;

    case PARSE_GET_LENGTH:
        p->length = byte;
        if (p->length == 0 || p->length > 250) {
            p->state = PARSE_WAIT_START;
        } else {
            p->state = PARSE_GET_DATA;
        }
        break;

    case PARSE_GET_DATA:
        p->data[p->index++] = byte;
        if (p->index >= p->length) {
            p->state = PARSE_GET_CRC;
        }
        break;

    case PARSE_GET_CRC:
        p->expected_crc = byte;
        p->state = PARSE_WAIT_START;

        uint8_t computed_crc = compute_crc(p->data, p->length);
        if (computed_crc == p->expected_crc) {
            return 1;  /* Valid frame received */
        }
        break;
    }
    return 0;  /* Frame not yet complete */
}
```

## FSM with Entry/Exit Actions

For more complex systems, add entry and exit actions:

```c
typedef struct {
    const char *name;
    void (*on_enter)(void);
    void (*on_exit)(void);
    void (*on_event)(ThermostatEvent event);
} State;

static void idle_enter(void)      { display_show("IDLE"); }
static void heating_enter(void)   { heater_on(); display_show("HEATING"); }
static void heating_exit(void)    { heater_off(); }
static void error_enter(void)     { alarm_on(); display_show("ERROR!"); }

static const State *active_state = &state_table[STATE_IDLE];

void fsm_transition(const State *new_state)
{
    if (active_state->on_exit)
        active_state->on_exit();

    active_state = new_state;

    if (active_state->on_enter)
        active_state->on_enter();
}
```

## Summary

- State machines impose structure on event-driven firmware.
- Switch-case FSMs are simple and sufficient for small designs.
- Table-driven FSMs scale better and are easier to modify.
- Use entry/exit actions for resource management (turning peripherals on/off).
- Protocol parsers are a natural fit for state machines.

---

**Next:** [Chapter 13 — Circular Buffers](13-circular-buffers.md)
