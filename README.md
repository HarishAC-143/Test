# Embedded C Programming Tutorial

A comprehensive, hands-on tutorial covering Embedded C programming from foundational concepts to real-world peripheral interfacing. Every topic includes working code examples targeting ARM Cortex-M microcontrollers (register-level), so you can study the patterns and port them to any hardware.

---

## Table of Contents

1. [Introduction to Embedded C](#1-introduction-to-embedded-c)
2. [Development Environment](#2-development-environment)
3. [Memory-Mapped I/O and Volatile](#3-memory-mapped-io-and-volatile)
4. [Bitwise Operations](#4-bitwise-operations)
5. [GPIO — Digital Output (LED Blink)](#5-gpio--digital-output-led-blink)
6. [GPIO — Digital Input (Button with Debounce)](#6-gpio--digital-input-button-with-debounce)
7. [Timers and Interrupts](#7-timers-and-interrupts)
8. [UART Serial Communication](#8-uart-serial-communication)
9. [ADC — Analog-to-Digital Conversion](#9-adc--analog-to-digital-conversion)
10. [PWM — Pulse Width Modulation](#10-pwm--pulse-width-modulation)
11. [I2C Communication](#11-i2c-communication)
12. [SPI Communication](#12-spi-communication)
13. [State Machines](#13-state-machines)
14. [Ring Buffers](#14-ring-buffers)
15. [Watchdog Timer](#15-watchdog-timer)
16. [Low-Power / Sleep Modes](#16-low-power--sleep-modes)
17. [Best Practices and Common Pitfalls](#17-best-practices-and-common-pitfalls)
18. [Further Reading](#18-further-reading)

---

## 1. Introduction to Embedded C

**Embedded C** is the C programming language applied to embedded systems — dedicated computers inside larger devices (automotive ECUs, medical instruments, IoT sensors, consumer electronics, etc.). It differs from desktop C in several important ways:

| Aspect | Desktop C | Embedded C |
|---|---|---|
| **Hardware access** | Through OS / drivers | Direct register manipulation |
| **Memory** | Gigabytes of RAM | Kilobytes of RAM, flash |
| **OS** | Linux, Windows, macOS | Bare-metal or lightweight RTOS |
| **Standard library** | Full `libc` available | Subset or none (`newlib-nano`, no `malloc`) |
| **Timing** | Non-deterministic | Hard real-time deadlines |
| **Power** | Wall power | Battery / energy harvesting |

### Key Characteristics

- **Direct hardware control** via memory-mapped registers.
- **Deterministic execution** — every cycle counts.
- **Resource constraints** — every byte of RAM and flash matters.
- **Concurrency through interrupts** rather than threads.
- **Cross-compilation** — code is compiled on a host PC, executed on a target MCU.

### Why C for Embedded Systems?

1. **Efficiency** — compiles to compact, fast machine code.
2. **Control** — direct memory and register access.
3. **Portability** — available on virtually every microcontroller.
4. **Maturity** — decades of toolchains, libraries, and community knowledge.
5. **Determinism** — no garbage collector, no hidden allocations.

---

## 2. Development Environment

### Typical Toolchain

```
Source Code (.c / .h)
        │
        ▼
  Cross-Compiler  (arm-none-eabi-gcc)
        │
        ▼
  Object Files (.o)
        │
        ▼
    Linker  (uses linker script .ld)
        │
        ▼
  ELF / HEX / BIN
        │
        ▼
  Flash Programmer  (OpenOCD, J-Link, ST-Link)
        │
        ▼
  Target MCU
```

### Common Tools

| Tool | Purpose |
|---|---|
| `arm-none-eabi-gcc` | Cross-compiler for ARM Cortex-M |
| `make` / `CMake` | Build automation |
| `OpenOCD` | On-chip debugger / flash programmer |
| `GDB` | Source-level debugging |
| `minicom` / `picocom` | Serial terminal for UART output |
| `STM32CubeMX` | Code generator for STM32 |

### Compilation Flags

```bash
arm-none-eabi-gcc \
    -mcpu=cortex-m4 \
    -mthumb \
    -Os \
    -Wall -Wextra -Werror \
    -ffunction-sections -fdata-sections \
    -Wl,--gc-sections \
    -T linker_script.ld \
    -o firmware.elf main.c startup.c
```

Key flags explained:

- `-mcpu=cortex-m4` — target processor core.
- `-mthumb` — use Thumb-2 instruction set (smaller code).
- `-Os` — optimize for size.
- `-ffunction-sections -fdata-sections` with `-Wl,--gc-sections` — remove unused code/data.

### Memory Layout (Linker Script Basics)

A typical Cortex-M linker script defines:

```ld
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 256K
    SRAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 64K
}

SECTIONS
{
    .text : {           /* Code and read-only data */
        *(.isr_vector)
        *(.text*)
        *(.rodata*)
    } > FLASH

    .data : {           /* Initialized global/static variables */
        *(.data*)
    } > SRAM AT> FLASH

    .bss : {            /* Zero-initialized global/static variables */
        *(.bss*)
        *(COMMON)
    } > SRAM
}
```

---

## 3. Memory-Mapped I/O and Volatile

In embedded systems, peripherals (GPIO, timers, UART, etc.) are controlled by reading and writing special memory addresses. The MCU's memory map assigns fixed addresses to each peripheral's control, status, and data registers.

### The `volatile` Keyword

The single most important keyword in Embedded C. It tells the compiler:

> "This variable can change at any time outside the program's normal flow of control — do **not** optimize away reads or writes to it."

Without `volatile`, the compiler may:
- Cache a register value in a CPU register and never re-read the actual hardware.
- Remove a write that appears to have no effect.
- Reorder accesses.

```c
/* WRONG — compiler may optimize away the read */
uint32_t *status_reg = (uint32_t *)0x40021000;
while (*status_reg & 0x01) { }  /* may become infinite loop or be removed */

/* CORRECT — forces the compiler to read the actual memory location every time */
volatile uint32_t *status_reg = (volatile uint32_t *)0x40021000;
while (*status_reg & 0x01) { }  /* reads hardware register each iteration */
```

### When to Use `volatile`

| Scenario | Reason |
|---|---|
| Hardware registers | Changed by peripheral hardware |
| Variables shared with ISRs | Modified asynchronously by interrupt |
| Variables shared between threads | Modified by another execution context |
| Memory-mapped I/O | Reads/writes have side effects |

### Register Access Pattern

A clean, maintainable approach to register access:

```c
#include <stdint.h>

/* Base addresses from the MCU reference manual */
#define PERIPH_BASE       ((uint32_t)0x40000000)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)
#define GPIOA_BASE        (AHB1_BASE + 0x0000)

/* GPIO register offsets */
#define GPIO_MODER_OFFSET   0x00
#define GPIO_ODR_OFFSET     0x14
#define GPIO_BSRR_OFFSET    0x18

/* Typed register access macros */
#define REG32(addr) (*(volatile uint32_t *)(addr))

#define GPIOA_MODER  REG32(GPIOA_BASE + GPIO_MODER_OFFSET)
#define GPIOA_ODR    REG32(GPIOA_BASE + GPIO_ODR_OFFSET)
#define GPIOA_BSRR   REG32(GPIOA_BASE + GPIO_BSRR_OFFSET)
```

---

## 4. Bitwise Operations

Bitwise operations are the bread and butter of embedded programming. Every peripheral register is a collection of bit fields, and you must be able to set, clear, toggle, and test individual bits without disturbing others.

### Operation Reference

| Operation | Syntax | Purpose |
|---|---|---|
| Set bit(s) | `reg \|= (1 << n)` | Turn on bit `n` |
| Clear bit(s) | `reg &= ~(1 << n)` | Turn off bit `n` |
| Toggle bit(s) | `reg ^= (1 << n)` | Flip bit `n` |
| Test bit | `if (reg & (1 << n))` | Check if bit `n` is set |
| Set field | `reg = (reg & ~MASK) \| (val << SHIFT)` | Write multi-bit field |

### Practical Macros

```c
#define BIT(n)              (1UL << (n))
#define SET_BIT(reg, n)     ((reg) |= BIT(n))
#define CLR_BIT(reg, n)     ((reg) &= ~BIT(n))
#define TGL_BIT(reg, n)     ((reg) ^= BIT(n))
#define GET_BIT(reg, n)     (((reg) >> (n)) & 1UL)

/* Multi-bit field helpers */
#define FIELD_MASK(width, pos)          (((1UL << (width)) - 1) << (pos))
#define FIELD_SET(reg, width, pos, val) \
    ((reg) = ((reg) & ~FIELD_MASK(width, pos)) | (((val) & ((1UL << (width)) - 1)) << (pos)))
#define FIELD_GET(reg, width, pos)      (((reg) >> (pos)) & ((1UL << (width)) - 1))
```

### Example: Configuring a GPIO Pin

GPIO MODER register uses 2-bit fields per pin:

```
Bits [1:0]   = Pin 0 mode
Bits [3:2]   = Pin 1 mode
Bits [5:4]   = Pin 2 mode
...
Bits [31:30] = Pin 15 mode

Mode values: 00 = Input, 01 = Output, 10 = Alternate, 11 = Analog
```

```c
/* Configure pin 5 as general-purpose output */
GPIOA_MODER &= ~(0x03 << (5 * 2));  /* Clear the 2-bit field */
GPIOA_MODER |=  (0x01 << (5 * 2));  /* Set to 01 (output)   */

/* Using the field macro: */
FIELD_SET(GPIOA_MODER, 2, 5 * 2, 0x01);
```

---

## 5. GPIO — Digital Output (LED Blink)

The "Hello World" of embedded programming. This example configures a GPIO pin as output and toggles an LED.

**Source:** [`examples/01_gpio_led_blink/main.c`](examples/01_gpio_led_blink/main.c)

### How It Works

1. Enable the clock to the GPIO port (the peripheral is powered off by default to save energy).
2. Configure the pin mode as **General-Purpose Output**.
3. In an infinite loop, toggle the pin and delay.

### Key Concepts

- **Clock gating** — peripherals must have their clock enabled before use.
- **Output Data Register (ODR)** — writing a 1 sets the pin high; 0 sets it low.
- **Bit-Set/Reset Register (BSRR)** — atomic set/reset without read-modify-write.
- **Software delay** — a simple busy-wait loop (replaced by timers in production).

---

## 6. GPIO — Digital Input (Button with Debounce)

Reading a mechanical switch and dealing with contact bounce.

**Source:** [`examples/02_button_input/main.c`](examples/02_button_input/main.c)

### The Bounce Problem

When a mechanical button is pressed, the contacts do not make clean contact instantly. They "bounce" — rapidly opening and closing for 1-20 ms. Without debouncing, a single press can register as dozens of presses.

```
Ideal:    ──────┐          ┌──────
                └──────────┘

Reality:  ──────┐ ┌┐ ┌┐   ┌──────
                └─┘└─┘└───┘
                 ← bounce →
```

### Debounce Strategies

| Method | Pros | Cons |
|---|---|---|
| Software delay | Simple | Blocks CPU |
| Timer-based sampling | Non-blocking | Uses a timer |
| Shift register / integration | Very robust | More code |
| Hardware RC filter | No CPU cost | Extra components |

The example implements both blocking delay and integration-based debouncing.

---

## 7. Timers and Interrupts

Timers are peripheral counters clocked by the system clock (or a prescaled version). They can generate interrupts at precise intervals, measure pulse widths, and produce PWM signals.

**Source:** [`examples/03_timer_interrupt/main.c`](examples/03_timer_interrupt/main.c)

### Timer Concepts

```
System Clock (e.g., 72 MHz)
        │
        ▼
   ┌──────────┐
   │ Prescaler │  ÷ PSC     →  Timer clock = SysClk / (PSC + 1)
   └──────────┘
        │
        ▼
   ┌──────────┐
   │  Counter  │  counts 0 → ARR
   └──────────┘
        │  overflow
        ▼
   Update Event → Interrupt (if enabled)
```

**Period formula:**

```
T = (PSC + 1) × (ARR + 1) / F_CLK

Example: 1-second interrupt at 72 MHz:
  PSC = 7199, ARR = 9999
  T = 7200 × 10000 / 72,000,000 = 1.0 s
```

### Interrupts

An interrupt is a hardware-triggered event that suspends the main program, executes a short handler (ISR), and then returns to where it left off.

**Rules for ISRs:**
1. Keep them **short** — do the minimum work, set a flag, return.
2. Variables shared between ISR and `main()` must be `volatile`.
3. Avoid calling non-reentrant functions (`printf`, `malloc`).
4. Clear the interrupt pending flag, or the ISR fires repeatedly.
5. Use critical sections when modifying multi-byte shared data.

---

## 8. UART Serial Communication

UART (Universal Asynchronous Receiver/Transmitter) is the most common serial protocol for debugging output and inter-device communication.

**Source:** [`examples/04_uart_communication/main.c`](examples/04_uart_communication/main.c)

### UART Frame

```
Idle ──┐   ┌───┐───┐───┐───┐───┐───┐───┐───┐   ┌───── Idle
       │   │ D0│ D1│ D2│ D3│ D4│ D5│ D6│ D7│   │
       └───┘   │   │   │   │   │   │   │   └───┘
       Start               Data (LSB first)       Stop
        bit                  (8 bits)              bit
```

### Baud Rate Calculation

```
USARTDIV = F_CLK / (16 × BaudRate)

Example: 115200 baud at 72 MHz:
  USARTDIV = 72,000,000 / (16 × 115,200) = 39.0625
  Mantissa = 39, Fraction = 0.0625 × 16 = 1
  BRR = (39 << 4) | 1 = 0x271
```

### Key Concepts

- **Transmit Data Register (TDR)** — write a byte here to send.
- **Receive Data Register (RDR)** — read received byte from here.
- **Status Register (SR)** — flags: TXE (transmit empty), RXNE (receive not empty), etc.

---

## 9. ADC — Analog-to-Digital Conversion

Read analog voltages from sensors (temperature, light, potentiometer, etc.).

**Source:** [`examples/05_adc_reading/main.c`](examples/05_adc_reading/main.c)

### ADC Basics

```
Analog Input (0V – 3.3V)
        │
        ▼
   ┌─────────┐
   │   ADC   │  12-bit resolution → 0–4095
   └─────────┘
        │
        ▼
   Digital Value = (V_in / V_ref) × 4095
```

### Conversion Modes

| Mode | Description |
|---|---|
| Single | One conversion, then stop |
| Continuous | Converts repeatedly |
| Scan | Converts multiple channels in sequence |
| DMA | Transfers results to memory automatically |

### Voltage Calculation

```c
float voltage = (adc_value / 4095.0f) * 3.3f;
```

For a temperature sensor with 10 mV/°C and 500 mV offset at 0°C:

```c
float temp_celsius = (voltage - 0.5f) / 0.01f;
```

---

## 10. PWM — Pulse Width Modulation

Control LED brightness, motor speed, and servo position by varying the duty cycle of a square wave.

**Source:** [`examples/06_pwm_motor_control/main.c`](examples/06_pwm_motor_control/main.c)

### PWM Concepts

```
      ┌─────┐          ┌─────┐          ┌─────┐
      │     │          │     │          │     │
 ─────┘     └──────────┘     └──────────┘     └────
      ← Ton →← Toff  →
      ←── Period (T) ──→

Duty Cycle = Ton / T × 100%
Frequency  = 1 / T
```

### Timer in PWM Mode

The timer counter counts from 0 to ARR. When `counter < CCR` the output is high; when `counter >= CCR` it goes low.

```
Duty Cycle = CCR / (ARR + 1) × 100%
```

### Common Applications

| Application | Typical Frequency | Notes |
|---|---|---|
| LED dimming | 1 kHz – 25 kHz | Above 200 Hz to avoid flicker |
| DC motor | 20 kHz – 40 kHz | Above audible range |
| Servo motor | 50 Hz | 1–2 ms pulse within 20 ms period |
| Buzzer / tone | 200 Hz – 5 kHz | Specific frequency = specific tone |

---

## 11. I2C Communication

I2C (Inter-Integrated Circuit) is a two-wire serial protocol for communicating with sensors, EEPROMs, displays, and other ICs.

**Source:** [`examples/07_i2c_temperature_sensor/main.c`](examples/07_i2c_temperature_sensor/main.c)

### I2C Bus

```
         VCC
          │
         ┌┤├┐ Pull-up resistors (4.7kΩ typical)
         │   │
 ────────┤   ├──────────────── SDA (data)
         │   │
 ────────┤   ├──────────────── SCL (clock)
         │   │
      Master  Slave 1  Slave 2  ...
```

### I2C Transaction

```
Master:  [S] [Addr+W] [A] [RegAddr] [A] [S] [Addr+R] [A] [Data] [N] [P]
Slave:               [A]           [A]              [A]

S = Start, P = Stop, A = ACK, N = NACK
```

### Key Parameters

- **Address:** 7-bit (0x00–0x7F) or 10-bit.
- **Speed:** Standard 100 kHz, Fast 400 kHz, Fast+ 1 MHz.
- **Open-drain:** requires external pull-up resistors.

---

## 12. SPI Communication

SPI (Serial Peripheral Interface) is a high-speed, full-duplex, four-wire serial bus.

**Source:** [`examples/08_spi_communication/main.c`](examples/08_spi_communication/main.c)

### SPI Signals

| Signal | Direction | Description |
|---|---|---|
| SCLK | Master → Slave | Clock |
| MOSI | Master → Slave | Master Out, Slave In |
| MISO | Master ← Slave | Master In, Slave Out |
| CS/SS | Master → Slave | Chip Select (active low) |

### SPI Modes (Clock Polarity and Phase)

| Mode | CPOL | CPHA | Clock Idle | Data Sampled On |
|---|---|---|---|---|
| 0 | 0 | 0 | Low | Rising edge |
| 1 | 0 | 1 | Low | Falling edge |
| 2 | 1 | 0 | High | Falling edge |
| 3 | 1 | 1 | High | Rising edge |

### SPI vs I2C

| Feature | SPI | I2C |
|---|---|---|
| Wires | 4 + 1 CS per slave | 2 (shared bus) |
| Speed | Up to 50+ MHz | Typically 100–400 kHz |
| Duplex | Full | Half |
| Addressing | CS line selects slave | 7-bit address |
| Complexity | Simpler protocol | More complex (ACK/NACK, arbitration) |

---

## 13. State Machines

State machines are the backbone of embedded firmware design. They organize complex behavior into well-defined states and transitions.

**Source:** [`examples/09_state_machine/main.c`](examples/09_state_machine/main.c)

### Why State Machines?

- **Clarity** — each state has a single, well-defined responsibility.
- **Maintainability** — adding new states is straightforward.
- **Testability** — each state can be tested independently.
- **Non-blocking** — no `delay()` calls; the main loop keeps running.

### Traffic Light Example

```
    ┌───────────────────────────────────┐
    │                                   │
    ▼                                   │
 ┌──────┐   30s   ┌────────┐   5s   ┌──────┐
 │ GREEN │ ─────→ │ YELLOW │ ─────→ │  RED  │
 └──────┘         └────────┘        └──────┘
                                       │  25s
                                       ▼
                                 ┌───────────┐  5s
                                 │ RED_YELLOW │ ───→ GREEN
                                 └───────────┘
```

---

## 14. Ring Buffers

A ring (circular) buffer is the standard data structure for buffering UART data, sensor readings, or any producer-consumer scenario in embedded systems.

**Source:** [`examples/10_ring_buffer/ring_buffer.h`](examples/10_ring_buffer/ring_buffer.h) | [`examples/10_ring_buffer/main.c`](examples/10_ring_buffer/main.c)

### How It Works

```
Buffer: [ A ][ B ][ C ][ _ ][ _ ][ _ ][ _ ][ _ ]
              ▲              ▲
             tail           head
         (read next)    (write next)

After writing 'D':
        [ A ][ B ][ C ][ D ][ _ ][ _ ][ _ ][ _ ]
              ▲                   ▲
             tail                head

After reading 'A':
        [ _ ][ B ][ C ][ D ][ _ ][ _ ][ _ ][ _ ]
                   ▲              ▲
                  tail           head
```

### Key Properties

- **O(1)** push and pop.
- **Fixed memory** — no dynamic allocation.
- **Wrap-around** — indices wrap modulo buffer size.
- **Interrupt-safe** — single-producer, single-consumer is naturally thread-safe with volatile head/tail.

---

## 15. Watchdog Timer

A watchdog timer (WDT) is a hardware safety mechanism that resets the MCU if the software hangs or crashes.

**Source:** [`examples/11_watchdog_timer/main.c`](examples/11_watchdog_timer/main.c)

### How It Works

```
    Start
      │
      ▼
┌──────────┐   "kick"     ┌──────────────┐
│ WDT runs │ ◄────────── │ Normal code   │
│ counting │              │ periodically  │
│ down     │              │ resets WDT    │
└──────────┘              └──────────────┘
      │
      │ timeout (code froze — no kick)
      ▼
  SYSTEM RESET
```

### Types

| Type | Description |
|---|---|
| Independent WDT (IWDG) | Clocked by internal RC, runs even if main clock fails |
| Window WDT (WWDG) | Must be refreshed within a specific time window |

---

## 16. Low-Power / Sleep Modes

Battery-powered devices must minimize power consumption. ARM Cortex-M offers several sleep modes.

**Source:** [`examples/12_low_power_sleep/main.c`](examples/12_low_power_sleep/main.c)

### Power Modes (Cortex-M)

| Mode | CPU | Peripherals | RAM | Wake-up Source |
|---|---|---|---|---|
| Run | Active | Active | Retained | N/A |
| Sleep | Stopped | Active | Retained | Any interrupt |
| Stop | Stopped | Stopped | Retained | EXTI, RTC |
| Standby | Stopped | Stopped | Lost | WKUP pin, RTC |

### Entering Sleep Mode

```c
__WFI();  /* Wait For Interrupt — CPU halts until interrupt fires */
__WFE();  /* Wait For Event — CPU halts until event */
```

### Power Budget Example

```
Active mode:   30 mA
Sleep mode:     5 mA
Stop mode:     20 µA
Standby mode:   2 µA

With 500 mAh battery:
  Active:  500 / 30  ≈ 16.7 hours
  Sleep:   500 / 5   = 100 hours
  Stop:    500 / 0.02 = 25,000 hours ≈ 2.85 years
```

---

## 17. Best Practices and Common Pitfalls

### Do

- **Use `volatile`** for all hardware registers and ISR-shared variables.
- **Use `stdint.h` types** (`uint8_t`, `uint32_t`) — never `int` for registers.
- **Use `static`** for file-scoped variables and functions to limit visibility.
- **Use `const`** for lookup tables and configuration — keeps them in flash.
- **Check return values** and peripheral status flags.
- **Keep ISRs short** — set a flag, process in `main()`.
- **Use bit-band or BSRR** for atomic bit operations.
- **Enable all compiler warnings** (`-Wall -Wextra -Werror`).
- **Use a watchdog** in production firmware.
- **Document register magic numbers** with named constants.

### Don't

- **Don't use `malloc`/`free`** — memory fragmentation in constrained systems is fatal.
- **Don't use floating point** unless the MCU has an FPU, or you accept the cost.
- **Don't busy-wait** when you can use interrupts or DMA.
- **Don't forget to enable the peripheral clock** — the #1 "why doesn't it work?" issue.
- **Don't modify shared variables without critical sections.**
- **Don't use `printf`** in ISRs.
- **Don't assume integer size** — `int` can be 16 or 32 bits depending on the platform.

### Critical Sections

When `main()` and an ISR share data, you must disable interrupts briefly:

```c
/* ARM Cortex-M critical section using PRIMASK */
static inline uint32_t critical_enter(void) {
    uint32_t primask;
    __asm volatile ("MRS %0, PRIMASK" : "=r" (primask));
    __asm volatile ("CPSID i" ::: "memory");
    return primask;
}

static inline void critical_exit(uint32_t primask) {
    __asm volatile ("MSR PRIMASK, %0" :: "r" (primask) : "memory");
}

/* Usage */
uint32_t state = critical_enter();
shared_counter++;  /* safe access */
critical_exit(state);
```

### Data Type Sizes — Use Fixed-Width Types

```c
#include <stdint.h>

uint8_t   reg_byte;     /* Exactly 8 bits  */
uint16_t  reg_half;     /* Exactly 16 bits */
uint32_t  reg_word;     /* Exactly 32 bits */
int32_t   signed_val;   /* Signed 32 bits  */

/* Avoid: int, short, long — their sizes are platform-dependent */
```

---

## 18. Further Reading

### Books

- *Making Embedded Systems* — Elecia White
- *The Definitive Guide to ARM Cortex-M3 and Cortex-M4 Processors* — Joseph Yiu
- *Embedded Systems: Introduction to ARM Cortex-M Microcontrollers* — Jonathan Valvano
- *Programming Embedded Systems in C and C++* — Michael Barr

### Online References

- [ARM Cortex-M Programming Guide](https://developer.arm.com/documentation)
- [STM32 Reference Manuals](https://www.st.com/en/microcontrollers-microprocessors/stm32-32-bit-arm-cortex-mcus.html)
- [Embedded Artistry Blog](https://embeddedartistry.com/)
- [Interrupt (Memfault Blog)](https://interrupt.memfault.com/)
- [Bare Metal Programming Guide](https://github.com/cpq/bare-metal-programming-guide)

---

## Repository Structure

```
.
├── README.md                              ← This tutorial
└── examples/
    ├── 01_gpio_led_blink/
    │   └── main.c                         ← LED blink (digital output)
    ├── 02_button_input/
    │   └── main.c                         ← Button with debounce (digital input)
    ├── 03_timer_interrupt/
    │   └── main.c                         ← Timer-based periodic interrupt
    ├── 04_uart_communication/
    │   └── main.c                         ← UART transmit and receive
    ├── 05_adc_reading/
    │   └── main.c                         ← ADC analog sensor reading
    ├── 06_pwm_motor_control/
    │   └── main.c                         ← PWM output for LED/motor control
    ├── 07_i2c_temperature_sensor/
    │   └── main.c                         ← I2C sensor communication
    ├── 08_spi_communication/
    │   └── main.c                         ← SPI master communication
    ├── 09_state_machine/
    │   └── main.c                         ← Traffic light state machine
    ├── 10_ring_buffer/
    │   ├── ring_buffer.h                  ← Ring buffer library
    │   └── main.c                         ← Ring buffer with UART
    ├── 11_watchdog_timer/
    │   └── main.c                         ← Independent watchdog timer
    └── 12_low_power_sleep/
        └── main.c                         ← Low-power sleep modes
```

---

*This tutorial targets ARM Cortex-M (STM32F4 family) at the register level. The patterns and concepts apply to any microcontroller — only the specific register addresses and bit definitions change.*
