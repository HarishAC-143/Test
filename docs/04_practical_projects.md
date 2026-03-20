# Chapter 4: Practical Projects

This chapter presents complete, self-contained projects that combine multiple concepts from the previous chapters. Each project is designed to run on real hardware or be simulated on a host PC for learning.

## Project 1: Temperature Monitoring System

**Concepts used**: ADC, UART, timer interrupts, state machine, averaging filter

### System Overview

```
┌──────────┐       ┌──────────┐       ┌──────────┐       ┌──────────┐
│  Temp    │ analog│   ADC    │digital│  Filter  │  text │   UART   │
│  Sensor  ├──────►│  Reader  ├──────►│& Average ├──────►│  Output  │
│ (LM35)   │       │          │       │          │       │(to PC)   │
└──────────┘       └──────────┘       └──────────┘       └──────────┘
                                                                │
                                      ┌──────────┐             │
                                      │  Alert   │◄────────────┘
                                      │  System  │ (checks thresholds)
                                      └──────────┘
```

### Key Design Decisions

- **Moving average filter** (8 samples) smooths noise without introducing phase lag
- **Hysteresis** on alert thresholds prevents rapid on/off toggling near the boundary
- **Non-blocking architecture**: Timer ISR triggers ADC reads; main loop processes and transmits

### Source Code

See [`examples/04_projects/temperature_monitor.c`](../examples/04_projects/temperature_monitor.c) for the complete implementation.

---

## Project 2: LED Pattern Controller with Button Input

**Concepts used**: GPIO, interrupts, debouncing, timer PWM, state machine

### System Overview

```
┌──────────┐    ┌───────────┐    ┌──────────────┐    ┌──────────┐
│  Button  ├───►│ Debounce  ├───►│    Pattern    ├───►│   LED    │
│  Input   │    │  Filter   │    │ State Machine │    │  Output  │
└──────────┘    └───────────┘    └──────────────┘    └──────────┘
                                        ▲
                                        │
                                 ┌──────┴──────┐
                                 │  Timer ISR  │
                                 │ (animation) │
                                 └─────────────┘
```

### LED Patterns

1. **All Off** — idle state
2. **Steady On** — all LEDs lit
3. **Blink** — all LEDs toggle at 1 Hz
4. **Chase** — sequential pattern scrolling
5. **Breathe** — PWM fade in/out
6. **Binary Counter** — count up in binary on LEDs

Button press cycles through patterns; long press returns to "All Off."

### Source Code

See [`examples/04_projects/led_pattern_controller.c`](../examples/04_projects/led_pattern_controller.c) for the complete implementation.

---

## Project 3: Serial Command-Line Interface

**Concepts used**: UART, ring buffer, string parsing, command dispatch table

### System Overview

```
PC Terminal                          Microcontroller
┌──────────┐      UART       ┌──────────────────────────┐
│          │  ───────────►   │  RX Ring Buffer           │
│  User    │                 │       │                   │
│  Types   │                 │  Line Parser              │
│ Commands │                 │       │                   │
│          │  ◄───────────   │  Command Dispatcher       │
│          │   responses     │       │                   │
└──────────┘                 │  Action Handlers          │
                             └──────────────────────────┘
```

### Supported Commands

| Command | Description | Example |
|---------|-------------|---------|
| `help` | List available commands | `> help` |
| `led on/off` | Control an LED | `> led on` |
| `adc read [ch]` | Read ADC channel | `> adc read 0` |
| `gpio set/clear [pin]` | Set/clear a GPIO pin | `> gpio set 5` |
| `status` | Show system status | `> status` |
| `reset` | Software reset | `> reset` |

### Source Code

See [`examples/04_projects/serial_command_parser.c`](../examples/04_projects/serial_command_parser.c) for the complete implementation.

---

## Project 4: Button Debounce Library

**Concepts used**: Timer sampling, digital filtering, edge detection, callback pattern

### The Bouncing Problem

When a mechanical button is pressed, the contacts don't make a clean transition. They "bounce" for 5–50 ms, producing multiple false edges:

```
Ideal signal:           Real signal (with bounce):

HIGH ─────┐             HIGH ─────┐ ┌┐ ┌─┐
          │                       │ ││ │ │
LOW       └──────       LOW       └─┘└─┘ └──────
          ▲ clean                 ▲ bouncing ▲ settled
```

### Debounce Algorithm

Sample the button at a fixed rate (e.g., every 5 ms). Only register a state change after N consecutive identical readings:

```
Samples: 1 1 1 0 1 0 0 0 0 0 0 0 1 1 1 1 1 1
                ─────────────── ───────────────
                counter counts   counter counts
                down from N      up to N
                → press event    → release event
```

### Source Code

See [`examples/04_projects/debounce_library.c`](../examples/04_projects/debounce_library.c) for the complete implementation.

---

## Design Patterns Summary

These projects demonstrate several recurring design patterns in embedded systems:

| Pattern | Where Used | Benefit |
|---------|-----------|---------|
| **Interrupt + Flag** | All projects | Responsive without blocking |
| **Ring Buffer** | Serial CLI | Decouples ISR from processing |
| **State Machine** | LED controller, Temp monitor | Organized, testable logic |
| **Moving Average** | Temperature monitor | Noise reduction |
| **Debounce Filter** | Button library | Reliable input detection |
| **Command Table** | Serial CLI | Extensible command dispatch |
| **Callback Pattern** | Debounce library | Reusable, decoupled modules |

## Tips for Real-World Deployment

1. **Start with the datasheet**: Every register, clock tree, and pin mapping comes from the MCU datasheet and reference manual.
2. **Use vendor HAL initially**: Start with the vendor's Hardware Abstraction Layer (e.g., STM32 HAL, CMSIS) to get things working, then optimize critical paths with direct register access.
3. **Version control everything**: Including linker scripts, startup files, and build configurations.
4. **Test on real hardware early**: Simulation can't catch timing issues, electrical noise, or power problems.
5. **Instrument your code**: Use spare GPIO pins as "debug signals" that you can observe with a logic analyzer or oscilloscope.
6. **Plan for failure**: Add watchdog timers, brown-out detection, and error recovery from the start.

**Back to**: [README](../README.md)
