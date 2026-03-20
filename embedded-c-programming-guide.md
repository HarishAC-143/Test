# Embedded C Programming Guide: From Basics to Advanced

A comprehensive tutorial covering Embedded C programming concepts, techniques, and practical examples for microcontroller-based systems.

---

## Table of Contents

1. [Introduction to Embedded C](#1-introduction-to-embedded-c)
2. [Embedded C vs Standard C](#2-embedded-c-vs-standard-c)
3. [Data Types and Memory Layout](#3-data-types-and-memory-layout)
4. [Bit Manipulation](#4-bit-manipulation)
5. [Volatile, Const, and Static Qualifiers](#5-volatile-const-and-static-qualifiers)
6. [Memory-Mapped I/O and Register Access](#6-memory-mapped-io-and-register-access)
7. [GPIO Programming](#7-gpio-programming)
8. [Interrupt Handling](#8-interrupt-handling)
9. [Timers and Counters](#9-timers-and-counters)
10. [UART Serial Communication](#10-uart-serial-communication)
11. [ADC and DAC](#11-adc-and-dac)
12. [SPI Communication](#12-spi-communication)
13. [I2C Communication](#13-i2c-communication)
14. [DMA (Direct Memory Access)](#14-dma-direct-memory-access)
15. [Finite State Machines](#15-finite-state-machines)
16. [RTOS Fundamentals](#16-rtos-fundamentals)
17. [Memory Management Strategies](#17-memory-management-strategies)
18. [Low-Power Design Techniques](#18-low-power-design-techniques)
19. [Watchdog Timers and System Reliability](#19-watchdog-timers-and-system-reliability)
20. [Debugging and Testing](#20-debugging-and-testing)
21. [Coding Standards and Best Practices](#21-coding-standards-and-best-practices)

---

## 1. Introduction to Embedded C

Embedded C is a set of language extensions for the C programming language, specifically designed for programming microcontrollers and embedded systems. Unlike desktop applications, embedded software runs on resource-constrained hardware with direct access to hardware peripherals.

### Key Characteristics of Embedded Systems

- **Resource-constrained**: Limited RAM (kilobytes), limited Flash (kilobytes to megabytes)
- **Real-time requirements**: Must respond to events within strict deadlines
- **Direct hardware access**: Programs interact directly with registers and peripherals
- **No operating system** (bare-metal) or a lightweight RTOS
- **Cross-compiled**: Code is written on a host machine and compiled for a target architecture

### Typical Embedded System Architecture

```
┌──────────────────────────────────────────┐
│              Application Layer           │
├──────────────────────────────────────────┤
│           Middleware / RTOS              │
├──────────────────────────────────────────┤
│     Hardware Abstraction Layer (HAL)     │
├──────────────────────────────────────────┤
│          Device Drivers (BSP)            │
├──────────────────────────────────────────┤
│     MCU Hardware (CPU, Peripherals)      │
└──────────────────────────────────────────┘
```

### A Minimal Embedded C Program

```c
#include <stdint.h>

/* Register definitions for a hypothetical MCU */
#define RCC_BASE        0x40021000U
#define GPIOA_BASE      0x40010800U

#define RCC_APB2ENR     (*(volatile uint32_t *)(RCC_BASE + 0x18))
#define GPIOA_CRL       (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_ODR       (*(volatile uint32_t *)(GPIOA_BASE + 0x0C))

int main(void)
{
    /* Enable GPIOA clock */
    RCC_APB2ENR |= (1U << 2);

    /* Configure PA5 as output (push-pull, 2 MHz) */
    GPIOA_CRL &= ~(0xFU << 20);
    GPIOA_CRL |=  (0x2U << 20);

    /* Toggle LED on PA5 forever */
    while (1) {
        GPIOA_ODR ^= (1U << 5);
        for (volatile uint32_t i = 0; i < 100000; i++);
    }

    return 0; /* Never reached */
}
```

---

## 2. Embedded C vs Standard C

| Feature | Standard C | Embedded C |
|---|---|---|
| Target platform | Desktop / Server | Microcontroller |
| Standard library | Full libc available | Minimal or none |
| Memory model | Virtual memory, large heap | Physical memory, fixed size |
| I/O model | `printf`, files, sockets | Register-level hardware access |
| Dynamic allocation | `malloc`/`free` common | Generally avoided |
| Data types | Implementation-defined widths | Fixed-width types (`uint8_t`, `uint32_t`) |
| Startup code | Provided by OS | Custom startup / vector table |
| Floating point | Hardware FPU on most hosts | Often software-emulated or absent |

### Fixed-Width Integer Types

Always use fixed-width types from `<stdint.h>` in embedded code to guarantee sizes across compilers and architectures:

```c
#include <stdint.h>

uint8_t  sensor_id;      /* Exactly 8 bits, unsigned  */
int16_t  temperature;    /* Exactly 16 bits, signed   */
uint32_t tick_counter;   /* Exactly 32 bits, unsigned  */
int32_t  position;       /* Exactly 32 bits, signed    */
uint64_t timestamp_us;   /* Exactly 64 bits, unsigned  */
```

### Why Not `int` and `unsigned`?

```c
/* On a 16-bit MCU, 'int' is 16 bits.
   On a 32-bit MCU, 'int' is 32 bits.
   This difference can cause subtle bugs when porting code. */

int counter = 40000;
/* 16-bit int overflows (max 32767 for signed).
   32-bit int is fine.
   Using uint32_t makes the intent explicit and portable. */
```

---

## 3. Data Types and Memory Layout

### Memory Sections in an Embedded System

```
┌─────────────────────┐  High Address
│     Stack           │  ← Grows downward
│         ↓           │
│                     │
│         ↑           │
│     Heap            │  ← Grows upward (if used)
├─────────────────────┤
│     .bss            │  ← Uninitialized global/static (zeroed)
├─────────────────────┤
│     .data           │  ← Initialized global/static
├─────────────────────┤
│     .rodata         │  ← Constants, string literals
├─────────────────────┤
│     .text           │  ← Program code (Flash)
├─────────────────────┤
│   Vector Table      │  ← Interrupt vectors
└─────────────────────┘  Low Address (0x00000000)
```

### Structures and Packing

In embedded systems, structures often map to hardware registers or communication protocol frames. Controlling layout is critical.

```c
#include <stdint.h>

/* Without packing: compiler may insert padding for alignment */
struct sensor_data_padded {
    uint8_t  id;          /* 1 byte  + 3 bytes padding */
    uint32_t timestamp;   /* 4 bytes */
    uint16_t value;       /* 2 bytes + 2 bytes padding */
};
/* sizeof = 12 bytes (with typical 32-bit alignment) */

/* With packing: no padding, exact memory layout */
struct __attribute__((packed)) sensor_data {
    uint8_t  id;          /* 1 byte */
    uint32_t timestamp;   /* 4 bytes */
    uint16_t value;       /* 2 bytes */
};
/* sizeof = 7 bytes */
```

> **Warning**: Packed structures may cause unaligned memory access on some architectures (e.g., ARM Cortex-M0), leading to hard faults. Use with care and prefer naturally aligned layouts when performance matters.

### Unions for Type-Punning

Unions are heavily used in embedded C for interpreting data in multiple ways:

```c
#include <stdint.h>

typedef union {
    uint32_t word;
    struct {
        uint8_t byte0;
        uint8_t byte1;
        uint8_t byte2;
        uint8_t byte3;
    } bytes;
    struct {
        uint16_t low;
        uint16_t high;
    } halves;
} reg32_t;

void example(void)
{
    reg32_t reg;
    reg.word = 0xDEADBEEF;

    /* Access individual bytes */
    uint8_t lsb = reg.bytes.byte0;  /* 0xEF on little-endian */
    uint16_t msw = reg.halves.high; /* 0xDEAD on little-endian */
}
```

### Enumerations for State and Configuration

```c
typedef enum {
    MOTOR_STOPPED = 0,
    MOTOR_FORWARD,
    MOTOR_REVERSE,
    MOTOR_BRAKING
} motor_state_t;

typedef enum {
    BAUD_9600   = 9600,
    BAUD_115200 = 115200,
    BAUD_921600 = 921600
} uart_baudrate_t;
```

---

## 4. Bit Manipulation

Bit manipulation is the most fundamental skill in embedded C. Almost every hardware register is controlled at the bit level.

### Core Bit Operations

```c
#include <stdint.h>

/* ── Setting a bit (OR) ──────────────────────────────── */
uint8_t reg = 0x00;
reg |= (1U << 3);      /* Set bit 3: reg = 0x08 */

/* ── Clearing a bit (AND with complement) ─────────────── */
reg &= ~(1U << 3);     /* Clear bit 3: reg = 0x00 */

/* ── Toggling a bit (XOR) ─────────────────────────────── */
reg ^= (1U << 3);      /* Toggle bit 3 */

/* ── Testing a bit ────────────────────────────────────── */
if (reg & (1U << 3)) {
    /* Bit 3 is set */
}

/* ── Setting multiple bits ────────────────────────────── */
reg |= (1U << 3) | (1U << 5);  /* Set bits 3 and 5 */

/* ── Clearing a bit field and writing a value ─────────── */
reg &= ~(0x07U << 4);   /* Clear bits [6:4] */
reg |= (0x05U << 4);    /* Write 0b101 into bits [6:4] */
```

### Macros for Bit Operations

```c
#define BIT_SET(reg, bit)       ((reg) |= (1U << (bit)))
#define BIT_CLEAR(reg, bit)     ((reg) &= ~(1U << (bit)))
#define BIT_TOGGLE(reg, bit)    ((reg) ^= (1U << (bit)))
#define BIT_CHECK(reg, bit)     ((reg) & (1U << (bit)))

#define BITS_SET(reg, mask)     ((reg) |= (mask))
#define BITS_CLEAR(reg, mask)   ((reg) &= ~(mask))

/* Field manipulation: extract and insert multi-bit fields */
#define FIELD_GET(reg, mask, shift)        (((reg) & (mask)) >> (shift))
#define FIELD_SET(reg, mask, shift, val)   \
    do { (reg) = ((reg) & ~(mask)) | (((val) << (shift)) & (mask)); } while (0)
```

### Practical Example: Configuring a Register

```c
/*
 * Timer Control Register (TCR) bit layout:
 *   Bit 0    : Enable (1 = timer running)
 *   Bit 1    : Auto-reload (1 = enabled)
 *   Bits 3:2 : Clock source (00=internal, 01=external, 10=PLL)
 *   Bits 7:4 : Prescaler (0x0..0xF)
 */

#define TCR_ENABLE          (1U << 0)
#define TCR_AUTO_RELOAD     (1U << 1)
#define TCR_CLK_SRC_MASK    (0x3U << 2)
#define TCR_CLK_SRC_INT     (0x0U << 2)
#define TCR_CLK_SRC_EXT     (0x1U << 2)
#define TCR_CLK_SRC_PLL     (0x2U << 2)
#define TCR_PRESCALER_MASK  (0xFU << 4)
#define TCR_PRESCALER(n)    (((n) & 0xFU) << 4)

void timer_configure(volatile uint32_t *tcr)
{
    uint32_t val = 0;

    val |= TCR_ENABLE;
    val |= TCR_AUTO_RELOAD;
    val |= TCR_CLK_SRC_PLL;
    val |= TCR_PRESCALER(8);

    *tcr = val;
    /* Result: 0b1000_1011 = 0x8B */
}
```

---

## 5. Volatile, Const, and Static Qualifiers

### The `volatile` Qualifier

The `volatile` keyword tells the compiler that a variable's value can change at any time without any action being taken by the code the compiler finds nearby. This prevents the compiler from optimizing away reads or writes.

**When to use `volatile`:**
- Hardware registers (memory-mapped I/O)
- Variables modified by interrupt service routines (ISRs)
- Variables shared between threads/tasks in an RTOS
- Memory-mapped DMA buffers

```c
/* WRONG: Compiler may optimize away repeated reads */
uint32_t *status_reg = (uint32_t *)0x40001000;
while (*status_reg & 0x01) {
    /* Compiler might read *status_reg once and cache the value,
       never seeing the hardware update the register */
}

/* CORRECT: volatile forces the compiler to read from memory every time */
volatile uint32_t *status_reg = (volatile uint32_t *)0x40001000;
while (*status_reg & 0x01) {
    /* Compiler will issue a load instruction every iteration */
}
```

### Variable Shared with an ISR

```c
volatile uint8_t data_ready = 0;
volatile uint8_t rx_buffer[64];
volatile uint8_t rx_index = 0;

void UART_IRQHandler(void)
{
    rx_buffer[rx_index++] = UART_DR;
    if (rx_index >= 64) {
        rx_index = 0;
        data_ready = 1;
    }
}

int main(void)
{
    while (1) {
        if (data_ready) {
            process_data(rx_buffer, 64);
            data_ready = 0;
        }
    }
}
```

### The `const` Qualifier

`const` prevents modification after initialization. In embedded systems, `const` data is typically placed in Flash (read-only) memory, saving precious RAM.

```c
/* Stored in Flash (.rodata section), not RAM */
const uint16_t sine_table[256] = {
    0, 402, 804, 1205, 1606, 2006, /* ... */
};

/* Pointer to a volatile, read-only hardware register */
volatile const uint32_t *chip_id = (volatile const uint32_t *)0x1FFF7A10;

/* Read-only pointer to a volatile register (pointer itself is const) */
volatile uint32_t *const GPIOA_ODR = (volatile uint32_t *)0x4001080C;
```

### The `const volatile` Combination

```c
/* A register that hardware can change, but software should never write to.
   volatile: value can change at any time (hardware updates it)
   const:    code must not write to it */
const volatile uint32_t *adc_result = (const volatile uint32_t *)0x4001204C;

uint32_t read_adc(void)
{
    return *adc_result; /* OK: reading is allowed */
    /* *adc_result = 0; */  /* COMPILE ERROR: writing is forbidden */
}
```

### The `static` Qualifier

`static` has two roles in C, both heavily used in embedded:

```c
/* 1. File-scope (internal linkage): restricts visibility to this file.
      Enables encapsulation without C++ classes. */
static uint32_t error_count = 0;

static void handle_error(uint32_t code)
{
    error_count++;
    log_error(code);
}

/* 2. Function-scope persistence: retains value across calls.
      Stored in .data/.bss, not on the stack. */
uint8_t debounce_button(void)
{
    static uint8_t history = 0xFF;

    history = (history << 1) | read_pin();

    if (history == 0x00) return 1;  /* Stable pressed */
    if (history == 0xFF) return 0;  /* Stable released */
    return 2;                        /* Transitioning */
}
```

---

## 6. Memory-Mapped I/O and Register Access

### How Memory-Mapped I/O Works

In most microcontrollers, peripherals are accessed through specific memory addresses. Reading from or writing to these addresses directly controls hardware.

```
Address Space Map (Example: ARM Cortex-M)
┌────────────────────────┐ 0xFFFFFFFF
│   System / Debug       │
├────────────────────────┤ 0xE0000000
│   Reserved             │
├────────────────────────┤ 0x60000000
│   Peripheral Registers │ ← GPIO, UART, SPI, etc.
├────────────────────────┤ 0x40000000
│   SRAM                 │ ← Variables, stack, heap
├────────────────────────┤ 0x20000000
│   Flash (Code)         │ ← .text, .rodata
└────────────────────────┘ 0x00000000
```

### Approaches to Register Access

**Approach 1: Direct Pointer Casting (Simplest)**

```c
#define GPIOA_MODER    (*(volatile uint32_t *)0x48000000U)
#define GPIOA_ODR      (*(volatile uint32_t *)0x48000014U)

void led_on(void)
{
    GPIOA_ODR |= (1U << 5);
}
```

**Approach 2: Base Address + Offset (Scalable)**

```c
#define GPIOA_BASE  0x48000000U
#define GPIOB_BASE  0x48000400U

#define GPIO_MODER_OFFSET   0x00U
#define GPIO_ODR_OFFSET     0x14U

#define REG(base, offset) (*(volatile uint32_t *)((base) + (offset)))

void led_toggle(void)
{
    REG(GPIOA_BASE, GPIO_ODR_OFFSET) ^= (1U << 5);
}
```

**Approach 3: Structure Overlay (Industry Standard)**

```c
typedef struct {
    volatile uint32_t MODER;    /* Offset 0x00: Mode register           */
    volatile uint32_t OTYPER;   /* Offset 0x04: Output type register    */
    volatile uint32_t OSPEEDR;  /* Offset 0x08: Output speed register   */
    volatile uint32_t PUPDR;    /* Offset 0x0C: Pull-up/pull-down reg   */
    volatile uint32_t IDR;      /* Offset 0x10: Input data register     */
    volatile uint32_t ODR;      /* Offset 0x14: Output data register    */
    volatile uint32_t BSRR;     /* Offset 0x18: Bit set/reset register  */
    volatile uint32_t LCKR;     /* Offset 0x1C: Lock register           */
    volatile uint32_t AFRL;     /* Offset 0x20: Alternate func low reg  */
    volatile uint32_t AFRH;     /* Offset 0x24: Alternate func high reg */
} GPIO_TypeDef;

#define GPIOA  ((GPIO_TypeDef *)0x48000000U)
#define GPIOB  ((GPIO_TypeDef *)0x48000400U)
#define GPIOC  ((GPIO_TypeDef *)0x48000800U)

void example(void)
{
    GPIOA->MODER |= (1U << 10);   /* Set PA5 to output mode */
    GPIOA->ODR   |= (1U << 5);    /* Drive PA5 high */
    GPIOA->BSRR   = (1U << 21);   /* Drive PA5 low (atomic) */
}
```

---

## 7. GPIO Programming

General Purpose Input/Output (GPIO) is the most basic peripheral. Each pin can be independently configured as input or output with various electrical characteristics.

### GPIO Pin Modes

| Mode | Description | Use Case |
|---|---|---|
| Input floating | High impedance, no pull | External pull-up/down present |
| Input pull-up | Internal pull-up resistor | Button to ground |
| Input pull-down | Internal pull-down resistor | Button to VCC |
| Output push-pull | Drives both high and low | LED, digital control |
| Output open-drain | Drives low only, floats high | I2C, level shifting |
| Alternate function | Peripheral controls the pin | UART TX, SPI CLK |
| Analog | Disconnects digital buffer | ADC input |

### Complete GPIO Driver Example

See [`examples/01_gpio_driver.c`](examples/01_gpio_driver.c) for a full implementation.

```c
#include <stdint.h>

typedef struct {
    volatile uint32_t MODER;
    volatile uint32_t OTYPER;
    volatile uint32_t OSPEEDR;
    volatile uint32_t PUPDR;
    volatile uint32_t IDR;
    volatile uint32_t ODR;
    volatile uint32_t BSRR;
    volatile uint32_t LCKR;
    volatile uint32_t AFRL;
    volatile uint32_t AFRH;
} GPIO_TypeDef;

typedef enum {
    GPIO_MODE_INPUT  = 0x00,
    GPIO_MODE_OUTPUT = 0x01,
    GPIO_MODE_AF     = 0x02,
    GPIO_MODE_ANALOG = 0x03
} gpio_mode_t;

typedef enum {
    GPIO_PULL_NONE = 0x00,
    GPIO_PULL_UP   = 0x01,
    GPIO_PULL_DOWN = 0x02
} gpio_pull_t;

void gpio_set_mode(GPIO_TypeDef *port, uint8_t pin, gpio_mode_t mode)
{
    port->MODER &= ~(0x3U << (pin * 2));
    port->MODER |=  ((uint32_t)mode << (pin * 2));
}

void gpio_set_pull(GPIO_TypeDef *port, uint8_t pin, gpio_pull_t pull)
{
    port->PUPDR &= ~(0x3U << (pin * 2));
    port->PUPDR |=  ((uint32_t)pull << (pin * 2));
}

void gpio_write(GPIO_TypeDef *port, uint8_t pin, uint8_t value)
{
    if (value) {
        port->BSRR = (1U << pin);        /* Atomic set */
    } else {
        port->BSRR = (1U << (pin + 16)); /* Atomic reset */
    }
}

uint8_t gpio_read(GPIO_TypeDef *port, uint8_t pin)
{
    return (port->IDR >> pin) & 0x01U;
}

void gpio_toggle(GPIO_TypeDef *port, uint8_t pin)
{
    port->ODR ^= (1U << pin);
}
```

### Button with Software Debounce

```c
#define DEBOUNCE_SAMPLES 8
#define GPIOC ((GPIO_TypeDef *)0x48000800U)

uint8_t button_debounced_read(uint8_t pin)
{
    static uint8_t state = 0;
    static uint8_t counter = 0;

    uint8_t raw = gpio_read(GPIOC, pin);

    if (raw != state) {
        counter++;
        if (counter >= DEBOUNCE_SAMPLES) {
            state = raw;
            counter = 0;
        }
    } else {
        counter = 0;
    }

    return state;
}
```

---

## 8. Interrupt Handling

Interrupts are signals that cause the processor to suspend normal execution and jump to an Interrupt Service Routine (ISR). They are essential for real-time, responsive embedded systems.

### Interrupt Concepts

```
Normal Execution          Interrupt Occurs           ISR Completes
      │                        │                          │
      ▼                        ▼                          ▼
┌──────────┐            ┌──────────┐               ┌──────────┐
│  main()  │──────────▶ │ Save     │──▶ ┌───────┐  │ Restore  │──▶ main()
│  code    │            │ Context  │    │  ISR  │  │ Context  │    resumes
└──────────┘            └──────────┘    └───────┘  └──────────┘
```

### NVIC (Nested Vectored Interrupt Controller) on ARM Cortex-M

```c
#include <stdint.h>

/* NVIC register structure */
typedef struct {
    volatile uint32_t ISER[8];    /* Interrupt Set Enable */
    uint32_t RESERVED0[24];
    volatile uint32_t ICER[8];    /* Interrupt Clear Enable */
    uint32_t RESERVED1[24];
    volatile uint32_t ISPR[8];    /* Interrupt Set Pending */
    uint32_t RESERVED2[24];
    volatile uint32_t ICPR[8];    /* Interrupt Clear Pending */
    uint32_t RESERVED3[24];
    volatile uint32_t IABR[8];    /* Interrupt Active Bit */
    uint32_t RESERVED4[56];
    volatile uint8_t  IPR[240];   /* Interrupt Priority */
} NVIC_TypeDef;

#define NVIC ((NVIC_TypeDef *)0xE000E100U)

void nvic_enable_irq(uint8_t irq_num)
{
    NVIC->ISER[irq_num >> 5] = (1U << (irq_num & 0x1F));
}

void nvic_disable_irq(uint8_t irq_num)
{
    NVIC->ICER[irq_num >> 5] = (1U << (irq_num & 0x1F));
}

void nvic_set_priority(uint8_t irq_num, uint8_t priority)
{
    NVIC->IPR[irq_num] = (priority << 4);
}
```

### Writing ISRs — Best Practices

```c
volatile uint32_t systick_count = 0;
volatile uint8_t  button_pressed = 0;

/* ISR: Keep it SHORT. Set flags, update counters, clear sources. */
void SysTick_Handler(void)
{
    systick_count++;
}

void EXTI0_IRQHandler(void)
{
    if (EXTI->PR & (1U << 0)) {
        EXTI->PR = (1U << 0);   /* Clear pending flag (write-1-to-clear) */
        button_pressed = 1;      /* Signal main loop */
    }
}

/* Main loop processes the event — heavy work stays out of the ISR */
int main(void)
{
    setup_interrupts();

    while (1) {
        if (button_pressed) {
            button_pressed = 0;
            handle_button_event();
        }
        /* Low-power sleep until next interrupt */
        __WFI();
    }
}
```

### Critical Sections: Protecting Shared Data

```c
/* Disable interrupts to protect a read-modify-write sequence */
static inline uint32_t critical_section_enter(void)
{
    uint32_t primask;
    __asm volatile ("MRS %0, PRIMASK" : "=r" (primask));
    __asm volatile ("CPSID i" ::: "memory");
    return primask;
}

static inline void critical_section_exit(uint32_t primask)
{
    __asm volatile ("MSR PRIMASK, %0" :: "r" (primask) : "memory");
}

/* Usage */
void safe_increment(volatile uint32_t *counter)
{
    uint32_t state = critical_section_enter();
    (*counter)++;
    critical_section_exit(state);
}
```

---

## 9. Timers and Counters

Timers are among the most versatile peripherals. They can generate precise delays, measure pulse widths, produce PWM signals, and trigger periodic interrupts.

### Timer Modes Overview

| Mode | Description | Application |
|---|---|---|
| Timer (up-count) | Count from 0 to auto-reload | Periodic interrupt |
| Timer (down-count) | Count from auto-reload to 0 | Timeout detection |
| Input capture | Record count on external edge | Frequency / pulse measurement |
| Output compare | Act when count matches value | Precise event timing |
| PWM generation | Duty-cycle waveform output | Motor control, LED dimming |
| One-pulse | Single triggered pulse | Monostable trigger |

### Basic Timer Configuration

See [`examples/02_timer_driver.c`](examples/02_timer_driver.c) for a full implementation.

```c
typedef struct {
    volatile uint32_t CR1;     /* Control register 1 */
    volatile uint32_t CR2;     /* Control register 2 */
    volatile uint32_t SMCR;    /* Slave mode control */
    volatile uint32_t DIER;    /* DMA/interrupt enable */
    volatile uint32_t SR;      /* Status register */
    volatile uint32_t EGR;     /* Event generation */
    volatile uint32_t CCMR1;   /* Capture/compare mode 1 */
    volatile uint32_t CCMR2;   /* Capture/compare mode 2 */
    volatile uint32_t CCER;    /* Capture/compare enable */
    volatile uint32_t CNT;     /* Counter */
    volatile uint32_t PSC;     /* Prescaler */
    volatile uint32_t ARR;     /* Auto-reload */
    volatile uint32_t RESERVED;
    volatile uint32_t CCR1;    /* Capture/compare 1 */
    volatile uint32_t CCR2;    /* Capture/compare 2 */
    volatile uint32_t CCR3;    /* Capture/compare 3 */
    volatile uint32_t CCR4;    /* Capture/compare 4 */
} TIM_TypeDef;

#define TIM2 ((TIM_TypeDef *)0x40000000U)

/* Configure TIM2 to generate a 1 kHz interrupt (assuming 72 MHz clock) */
void timer2_init_1khz(void)
{
    RCC->APB1ENR |= (1U << 0);  /* Enable TIM2 clock */

    TIM2->PSC = 72 - 1;         /* 72 MHz / 72 = 1 MHz tick */
    TIM2->ARR = 1000 - 1;       /* 1 MHz / 1000 = 1 kHz overflow */
    TIM2->DIER |= (1U << 0);    /* Enable update interrupt */
    TIM2->CR1  |= (1U << 0);    /* Start timer */

    nvic_enable_irq(28);        /* TIM2 IRQ number */
}

volatile uint32_t milliseconds = 0;

void TIM2_IRQHandler(void)
{
    if (TIM2->SR & (1U << 0)) {
        TIM2->SR &= ~(1U << 0); /* Clear update interrupt flag */
        milliseconds++;
    }
}
```

### PWM Generation

```c
void pwm_init(TIM_TypeDef *tim, uint8_t channel, uint32_t freq_hz,
              uint8_t duty_percent)
{
    uint32_t sys_clk = 72000000U;
    uint32_t period  = sys_clk / freq_hz;
    uint32_t prescaler = 0;

    /* Find a prescaler that keeps the period within 16-bit range */
    while (period > 65535) {
        prescaler++;
        period = sys_clk / ((prescaler + 1) * freq_hz);
    }

    tim->PSC = prescaler;
    tim->ARR = period - 1;

    uint32_t pulse = (period * duty_percent) / 100;

    switch (channel) {
    case 1:
        tim->CCMR1 = (0x6U << 4);   /* PWM mode 1 on CH1 */
        tim->CCER |= (1U << 0);     /* Enable CH1 output */
        tim->CCR1  = pulse;
        break;
    case 2:
        tim->CCMR1 = (0x6U << 12);  /* PWM mode 1 on CH2 */
        tim->CCER |= (1U << 4);     /* Enable CH2 output */
        tim->CCR2  = pulse;
        break;
    case 3:
        tim->CCMR2 = (0x6U << 4);
        tim->CCER |= (1U << 8);
        tim->CCR3  = pulse;
        break;
    case 4:
        tim->CCMR2 = (0x6U << 12);
        tim->CCER |= (1U << 12);
        tim->CCR4  = pulse;
        break;
    }

    tim->CR1 |= (1U << 0);  /* Enable timer */
}

/* Example: 1 kHz PWM at 75% duty on TIM2 channel 1 */
/* pwm_init(TIM2, 1, 1000, 75); */
```

---

## 10. UART Serial Communication

UART (Universal Asynchronous Receiver/Transmitter) is the most common serial communication interface in embedded systems. It uses two wires (TX and RX) for full-duplex communication.

### UART Frame Format

```
Idle ──┐  ┌── Start Bit   Data Bits (LSB first)    Parity  Stop
       │  │                                          (opt)   Bit
       ▼  ▼
    ───┐  ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
       └──┘D0│D1│D2│D3│D4│D5│D6│D7│ P│ S│────
          └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
```

### UART Driver

See [`examples/03_uart_driver.c`](examples/03_uart_driver.c) for the complete implementation.

```c
typedef struct {
    volatile uint32_t SR;    /* Status register */
    volatile uint32_t DR;    /* Data register */
    volatile uint32_t BRR;   /* Baud rate register */
    volatile uint32_t CR1;   /* Control register 1 */
    volatile uint32_t CR2;   /* Control register 2 */
    volatile uint32_t CR3;   /* Control register 3 */
    volatile uint32_t GTPR;  /* Guard time / prescaler */
} USART_TypeDef;

#define USART1 ((USART_TypeDef *)0x40011000U)
#define USART2 ((USART_TypeDef *)0x40004400U)

/* Status register bits */
#define USART_SR_TXE    (1U << 7)  /* Transmit data register empty */
#define USART_SR_RXNE   (1U << 5)  /* Read data register not empty */
#define USART_SR_TC     (1U << 6)  /* Transmission complete */
#define USART_SR_ORE    (1U << 3)  /* Overrun error */

void uart_init(USART_TypeDef *uart, uint32_t baud, uint32_t pclk)
{
    /* Baud rate = pclk / (16 * USARTDIV) */
    uint32_t div = (pclk + (baud / 2)) / baud;
    uart->BRR = div;

    uart->CR1 = 0;
    uart->CR1 |= (1U << 2);   /* RE: Receiver enable */
    uart->CR1 |= (1U << 3);   /* TE: Transmitter enable */
    uart->CR1 |= (1U << 13);  /* UE: USART enable */
}

void uart_send_byte(USART_TypeDef *uart, uint8_t data)
{
    while (!(uart->SR & USART_SR_TXE));
    uart->DR = data;
}

uint8_t uart_receive_byte(USART_TypeDef *uart)
{
    while (!(uart->SR & USART_SR_RXNE));
    return (uint8_t)(uart->DR & 0xFF);
}

void uart_send_string(USART_TypeDef *uart, const char *str)
{
    while (*str) {
        uart_send_byte(uart, (uint8_t)*str++);
    }
}

/* printf-style output via UART */
#include <stdarg.h>
#include <stdio.h>

void uart_printf(USART_TypeDef *uart, const char *fmt, ...)
{
    char buf[128];
    va_list args;
    va_start(args, fmt);
    int len = vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);

    for (int i = 0; i < len && i < (int)sizeof(buf); i++) {
        uart_send_byte(uart, (uint8_t)buf[i]);
    }
}
```

### Interrupt-Driven UART with Ring Buffer

See [`examples/04_uart_ring_buffer.c`](examples/04_uart_ring_buffer.c) for the full implementation.

```c
#define RING_BUF_SIZE 256

typedef struct {
    volatile uint8_t  buffer[RING_BUF_SIZE];
    volatile uint16_t head;
    volatile uint16_t tail;
} ring_buffer_t;

static ring_buffer_t rx_buf = {.head = 0, .tail = 0};
static ring_buffer_t tx_buf = {.head = 0, .tail = 0};

static inline uint8_t ring_is_empty(const ring_buffer_t *rb)
{
    return rb->head == rb->tail;
}

static inline uint8_t ring_is_full(const ring_buffer_t *rb)
{
    return ((rb->head + 1) % RING_BUF_SIZE) == rb->tail;
}

void ring_push(ring_buffer_t *rb, uint8_t data)
{
    if (!ring_is_full(rb)) {
        rb->buffer[rb->head] = data;
        rb->head = (rb->head + 1) % RING_BUF_SIZE;
    }
}

uint8_t ring_pop(ring_buffer_t *rb)
{
    uint8_t data = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) % RING_BUF_SIZE;
    return data;
}

void USART1_IRQHandler(void)
{
    /* Receive interrupt */
    if (USART1->SR & USART_SR_RXNE) {
        uint8_t data = (uint8_t)(USART1->DR & 0xFF);
        ring_push(&rx_buf, data);
    }

    /* Transmit interrupt */
    if ((USART1->SR & USART_SR_TXE) && (USART1->CR1 & (1U << 7))) {
        if (!ring_is_empty(&tx_buf)) {
            USART1->DR = ring_pop(&tx_buf);
        } else {
            USART1->CR1 &= ~(1U << 7); /* Disable TXE interrupt */
        }
    }
}
```

---

## 11. ADC and DAC

### ADC (Analog-to-Digital Converter)

The ADC converts analog voltages to digital values. A 12-bit ADC maps 0V–3.3V to 0–4095.

```
Voltage → ADC Value: digital = (Vin / Vref) × (2^n - 1)
ADC Value → Voltage: Vin = (digital / (2^n - 1)) × Vref

Example (12-bit, Vref = 3.3V):
  1.65V → (1.65 / 3.3) × 4095 = 2047
  2047  → (2047 / 4095) × 3.3 = 1.649V
```

See [`examples/05_adc_driver.c`](examples/05_adc_driver.c) for the complete implementation.

```c
typedef struct {
    volatile uint32_t SR;
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t SMPR1;
    volatile uint32_t SMPR2;
    volatile uint32_t JOFR1;
    volatile uint32_t JOFR2;
    volatile uint32_t JOFR3;
    volatile uint32_t JOFR4;
    volatile uint32_t HTR;
    volatile uint32_t LTR;
    volatile uint32_t SQR1;
    volatile uint32_t SQR2;
    volatile uint32_t SQR3;
    volatile uint32_t JSQR;
    volatile uint32_t JDR1;
    volatile uint32_t JDR2;
    volatile uint32_t JDR3;
    volatile uint32_t JDR4;
    volatile uint32_t DR;
} ADC_TypeDef;

#define ADC1 ((ADC_TypeDef *)0x40012400U)

#define ADC_SR_EOC   (1U << 1)   /* End of conversion */
#define ADC_CR2_ADON (1U << 0)   /* ADC enable */
#define ADC_CR2_SWST (1U << 30)  /* Start conversion */

void adc_init(void)
{
    RCC->APB2ENR |= (1U << 9);  /* Enable ADC1 clock */

    ADC1->CR2 |= ADC_CR2_ADON;   /* Power on ADC */

    /* Wait for ADC stabilization */
    for (volatile int i = 0; i < 1000; i++);

    ADC1->CR2 |= ADC_CR2_ADON;   /* Second write starts calibration */
}

uint16_t adc_read(uint8_t channel)
{
    /* Select channel in regular sequence */
    ADC1->SQR3 = channel;

    /* Set sample time (239.5 cycles for accuracy) */
    if (channel < 10) {
        ADC1->SMPR2 |= (0x7U << (channel * 3));
    } else {
        ADC1->SMPR1 |= (0x7U << ((channel - 10) * 3));
    }

    /* Start conversion */
    ADC1->CR2 |= ADC_CR2_SWST;

    /* Wait for conversion complete */
    while (!(ADC1->SR & ADC_SR_EOC));

    return (uint16_t)(ADC1->DR & 0x0FFF);
}

/* Convert raw ADC value to millivolts */
uint32_t adc_to_millivolts(uint16_t raw, uint32_t vref_mv)
{
    return ((uint32_t)raw * vref_mv) / 4095U;
}

/* Read temperature from NTC thermistor using Steinhart-Hart (simplified) */
int16_t read_temperature_ntc(uint8_t channel)
{
    uint16_t raw = adc_read(channel);
    uint32_t mv = adc_to_millivolts(raw, 3300);

    /* For a 10k NTC with 10k pull-up divider */
    uint32_t r_ntc = (10000UL * mv) / (3300 - mv);

    /* Simplified lookup: linear approximation around 25°C
       Actual implementations should use a lookup table or
       the Steinhart-Hart equation */
    int16_t temp = 25 - (int16_t)((r_ntc - 10000) / 400);

    return temp;
}
```

### Multi-Channel ADC with Averaging

```c
#define ADC_OVERSAMPLE_COUNT 16

uint16_t adc_read_averaged(uint8_t channel)
{
    uint32_t sum = 0;

    for (uint8_t i = 0; i < ADC_OVERSAMPLE_COUNT; i++) {
        sum += adc_read(channel);
    }

    return (uint16_t)(sum / ADC_OVERSAMPLE_COUNT);
}

typedef struct {
    uint16_t raw;
    uint32_t millivolts;
} adc_result_t;

void adc_scan_channels(const uint8_t *channels, uint8_t count,
                        adc_result_t *results)
{
    for (uint8_t i = 0; i < count; i++) {
        results[i].raw = adc_read_averaged(channels[i]);
        results[i].millivolts = adc_to_millivolts(results[i].raw, 3300);
    }
}
```

---

## 12. SPI Communication

SPI (Serial Peripheral Interface) is a synchronous, full-duplex, master-slave protocol commonly used for high-speed communication with sensors, displays, and memory devices.

### SPI Signal Lines

```
        Master                          Slave
    ┌───────────┐                  ┌───────────┐
    │       MOSI├─────────────────▶│MOSI       │
    │       MISO│◀─────────────────┤MISO       │
    │       SCLK├─────────────────▶│SCLK       │
    │        CS ├─────────────────▶│CS         │
    └───────────┘                  └───────────┘

MOSI: Master Out, Slave In (data from master to slave)
MISO: Master In, Slave Out (data from slave to master)
SCLK: Serial Clock (generated by master)
CS:   Chip Select (active low, one per slave)
```

### SPI Clock Modes

| Mode | CPOL | CPHA | Clock Idle | Sampling Edge |
|---|---|---|---|---|
| 0 | 0 | 0 | Low | Rising |
| 1 | 0 | 1 | Low | Falling |
| 2 | 1 | 0 | High | Falling |
| 3 | 1 | 1 | High | Rising |

### SPI Driver

See [`examples/06_spi_driver.c`](examples/06_spi_driver.c) for the complete implementation.

```c
typedef struct {
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t CRCPR;
    volatile uint32_t RXCRCR;
    volatile uint32_t TXCRCR;
} SPI_TypeDef;

#define SPI1 ((SPI_TypeDef *)0x40013000U)

#define SPI_SR_TXE   (1U << 1)
#define SPI_SR_RXNE  (1U << 0)
#define SPI_SR_BSY   (1U << 7)

typedef struct {
    SPI_TypeDef  *peripheral;
    GPIO_TypeDef *cs_port;
    uint8_t       cs_pin;
} spi_handle_t;

void spi_init_master(SPI_TypeDef *spi, uint8_t prescaler, uint8_t mode)
{
    spi->CR1 = 0;

    /* Set baud rate prescaler (fPCLK / 2^(prescaler+1)) */
    spi->CR1 |= ((prescaler & 0x07U) << 3);

    /* Set clock polarity and phase */
    if (mode & 0x02) spi->CR1 |= (1U << 1);  /* CPOL */
    if (mode & 0x01) spi->CR1 |= (1U << 0);  /* CPHA */

    spi->CR1 |= (1U << 2);   /* Master mode */
    spi->CR1 |= (1U << 8);   /* Software slave management */
    spi->CR1 |= (1U << 9);   /* Internal slave select */
    spi->CR1 |= (1U << 6);   /* SPI enable */
}

uint8_t spi_transfer_byte(SPI_TypeDef *spi, uint8_t tx_data)
{
    while (!(spi->SR & SPI_SR_TXE));
    spi->DR = tx_data;

    while (!(spi->SR & SPI_SR_RXNE));
    return (uint8_t)(spi->DR & 0xFF);
}

void spi_cs_low(const spi_handle_t *h)
{
    gpio_write(h->cs_port, h->cs_pin, 0);
}

void spi_cs_high(const spi_handle_t *h)
{
    gpio_write(h->cs_port, h->cs_pin, 1);
}

void spi_transfer(const spi_handle_t *h, const uint8_t *tx, uint8_t *rx,
                  uint16_t len)
{
    spi_cs_low(h);

    for (uint16_t i = 0; i < len; i++) {
        uint8_t tx_byte = tx ? tx[i] : 0xFF;
        uint8_t rx_byte = spi_transfer_byte(h->peripheral, tx_byte);
        if (rx) rx[i] = rx_byte;
    }

    spi_cs_high(h);
}
```

### SPI Flash Memory Example

```c
#define FLASH_CMD_READ_ID      0x9F
#define FLASH_CMD_READ         0x03
#define FLASH_CMD_WRITE_EN     0x06
#define FLASH_CMD_PAGE_PROG    0x02
#define FLASH_CMD_SECTOR_ERASE 0x20
#define FLASH_CMD_READ_STATUS  0x05

uint32_t flash_read_id(const spi_handle_t *h)
{
    uint8_t tx[4] = {FLASH_CMD_READ_ID, 0, 0, 0};
    uint8_t rx[4];

    spi_transfer(h, tx, rx, 4);

    return ((uint32_t)rx[1] << 16) | ((uint32_t)rx[2] << 8) | rx[3];
}

void flash_wait_ready(const spi_handle_t *h)
{
    uint8_t status;
    do {
        spi_cs_low(h);
        spi_transfer_byte(h->peripheral, FLASH_CMD_READ_STATUS);
        status = spi_transfer_byte(h->peripheral, 0xFF);
        spi_cs_high(h);
    } while (status & 0x01);  /* WIP bit */
}

void flash_read(const spi_handle_t *h, uint32_t addr,
                uint8_t *buf, uint16_t len)
{
    spi_cs_low(h);
    spi_transfer_byte(h->peripheral, FLASH_CMD_READ);
    spi_transfer_byte(h->peripheral, (addr >> 16) & 0xFF);
    spi_transfer_byte(h->peripheral, (addr >> 8)  & 0xFF);
    spi_transfer_byte(h->peripheral, addr & 0xFF);

    for (uint16_t i = 0; i < len; i++) {
        buf[i] = spi_transfer_byte(h->peripheral, 0xFF);
    }
    spi_cs_high(h);
}
```

---

## 13. I2C Communication

I2C (Inter-Integrated Circuit) is a two-wire, half-duplex, multi-master protocol. It uses open-drain outputs with pull-up resistors.

### I2C Bus Architecture

```
        VCC
         │
        ┌┴┐  ┌┴┐
        │R│  │R│   Pull-up resistors (typically 4.7kΩ)
        └┬┘  └┬┘
    SDA ─┴────┴─────┬──────────┬──────────┐
    SCL ────────────┬┼──────────┼┬─────────┼┐
                    ││          ││         ││
               ┌────┤│     ┌───┤│    ┌────┤│
               │Master│    │Slave1│   │Slave2│
               └──────┘    └──────┘   └──────┘
                            Addr:0x48  Addr:0x68
```

### I2C Transaction Format

```
START  Slave Address  R/W  ACK  Data Byte  ACK  ...  STOP
  │    [7 bits]        │    │    [8 bits]   │         │
  ▼                    ▼    ▼               ▼         ▼
┌──┐ ┌─┬─┬─┬─┬─┬─┬─┐ ┌─┐ ┌─┐ ┌─┬─┬─┬─┬─┬─┬─┬─┐ ┌─┐ ┌──┐
│S │ │A│A│A│A│A│A│A│ │W│ │A│ │D│D│D│D│D│D│D│D│ │A│ │P │
└──┘ └─┴─┴─┴─┴─┴─┴─┘ └─┘ └─┘ └─┴─┴─┴─┴─┴─┴─┴─┘ └─┘ └──┘
```

### I2C Driver

See [`examples/07_i2c_driver.c`](examples/07_i2c_driver.c) for the complete implementation.

```c
typedef struct {
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t OAR1;
    volatile uint32_t OAR2;
    volatile uint32_t DR;
    volatile uint32_t SR1;
    volatile uint32_t SR2;
    volatile uint32_t CCR;
    volatile uint32_t TRISE;
} I2C_TypeDef;

#define I2C1 ((I2C_TypeDef *)0x40005400U)

typedef enum {
    I2C_OK = 0,
    I2C_ERR_TIMEOUT,
    I2C_ERR_NACK,
    I2C_ERR_BUS
} i2c_status_t;

void i2c_init(I2C_TypeDef *i2c, uint32_t pclk_mhz, uint32_t speed_hz)
{
    i2c->CR1 |= (1U << 15);   /* Software reset */
    i2c->CR1 &= ~(1U << 15);

    i2c->CR2 = pclk_mhz & 0x3F;

    if (speed_hz <= 100000) {
        /* Standard mode (100 kHz) */
        i2c->CCR = (pclk_mhz * 1000000) / (2 * speed_hz);
        i2c->TRISE = pclk_mhz + 1;
    } else {
        /* Fast mode (400 kHz) */
        i2c->CCR = (1U << 15) |                  /* Fast mode flag */
                   ((pclk_mhz * 1000000) / (3 * speed_hz));
        i2c->TRISE = (pclk_mhz * 300 / 1000) + 1;
    }

    i2c->CR1 |= (1U << 0);  /* Peripheral enable */
}

i2c_status_t i2c_write(I2C_TypeDef *i2c, uint8_t addr,
                        const uint8_t *data, uint16_t len)
{
    uint32_t timeout;

    /* Generate START */
    i2c->CR1 |= (1U << 8);
    timeout = 10000;
    while (!(i2c->SR1 & (1U << 0)) && --timeout);
    if (!timeout) return I2C_ERR_TIMEOUT;

    /* Send slave address + Write bit */
    i2c->DR = (addr << 1) | 0;
    timeout = 10000;
    while (!(i2c->SR1 & (1U << 1)) && --timeout);
    if (!timeout) return I2C_ERR_TIMEOUT;
    if (i2c->SR1 & (1U << 10)) return I2C_ERR_NACK;
    (void)i2c->SR2;  /* Clear ADDR flag by reading SR2 */

    /* Send data bytes */
    for (uint16_t i = 0; i < len; i++) {
        timeout = 10000;
        while (!(i2c->SR1 & (1U << 7)) && --timeout);
        if (!timeout) return I2C_ERR_TIMEOUT;
        i2c->DR = data[i];
    }

    /* Wait for last byte to finish */
    timeout = 10000;
    while (!(i2c->SR1 & (1U << 2)) && --timeout);
    if (!timeout) return I2C_ERR_TIMEOUT;

    /* Generate STOP */
    i2c->CR1 |= (1U << 9);

    return I2C_OK;
}

i2c_status_t i2c_read(I2C_TypeDef *i2c, uint8_t addr,
                       uint8_t *data, uint16_t len)
{
    uint32_t timeout;

    if (len == 0) return I2C_OK;

    i2c->CR1 |= (1U << 10);  /* Enable ACK */

    /* Generate START */
    i2c->CR1 |= (1U << 8);
    timeout = 10000;
    while (!(i2c->SR1 & (1U << 0)) && --timeout);
    if (!timeout) return I2C_ERR_TIMEOUT;

    /* Send slave address + Read bit */
    i2c->DR = (addr << 1) | 1;
    timeout = 10000;
    while (!(i2c->SR1 & (1U << 1)) && --timeout);
    if (!timeout) return I2C_ERR_TIMEOUT;
    (void)i2c->SR2;

    /* Read data bytes */
    for (uint16_t i = 0; i < len; i++) {
        if (i == len - 1) {
            i2c->CR1 &= ~(1U << 10);  /* NACK for last byte */
            i2c->CR1 |= (1U << 9);    /* Generate STOP */
        }

        timeout = 10000;
        while (!(i2c->SR1 & (1U << 6)) && --timeout);
        if (!timeout) return I2C_ERR_TIMEOUT;
        data[i] = (uint8_t)i2c->DR;
    }

    return I2C_OK;
}
```

### I2C Sensor Example: Reading a Temperature Sensor (LM75)

```c
#define LM75_ADDR       0x48
#define LM75_REG_TEMP   0x00
#define LM75_REG_CONF   0x01

int16_t lm75_read_temperature(I2C_TypeDef *i2c)
{
    uint8_t reg = LM75_REG_TEMP;
    uint8_t data[2];

    i2c_write(i2c, LM75_ADDR, &reg, 1);
    i2c_read(i2c, LM75_ADDR, data, 2);

    /* Temperature is in 9-bit two's complement, 0.5°C resolution.
       data[0] = integer part, data[1] MSB = 0.5 degree flag */
    int16_t raw = ((int16_t)data[0] << 8) | data[1];
    return raw >> 7;  /* Divide by 128 to get 0.5°C units */
}
```

---

## 14. DMA (Direct Memory Access)

DMA allows peripherals to transfer data to/from memory without CPU intervention, freeing the processor for other tasks.

### DMA Transfer Types

```
Memory-to-Peripheral:   RAM → UART TX (send a buffer of data)
Peripheral-to-Memory:   ADC → RAM (collect samples continuously)
Memory-to-Memory:       RAM → RAM (fast memory copy/fill)
```

### DMA Configuration Example

See [`examples/08_dma_driver.c`](examples/08_dma_driver.c) for the complete implementation.

```c
typedef struct {
    volatile uint32_t CCR;     /* Channel configuration */
    volatile uint32_t CNDTR;   /* Number of data items */
    volatile uint32_t CPAR;    /* Peripheral address */
    volatile uint32_t CMAR;    /* Memory address */
} DMA_Channel_TypeDef;

typedef struct {
    volatile uint32_t ISR;     /* Interrupt status */
    volatile uint32_t IFCR;    /* Interrupt flag clear */
} DMA_TypeDef;

#define DMA1       ((DMA_TypeDef *)0x40020000U)
#define DMA1_CH4   ((DMA_Channel_TypeDef *)0x40020044U)  /* USART1_TX */

void dma_uart_tx_init(const uint8_t *buffer, uint16_t length)
{
    RCC->AHBENR |= (1U << 0);  /* Enable DMA1 clock */

    DMA1_CH4->CCR = 0;         /* Disable channel first */

    DMA1_CH4->CPAR  = (uint32_t)&USART1->DR;   /* Peripheral address */
    DMA1_CH4->CMAR  = (uint32_t)buffer;         /* Memory address */
    DMA1_CH4->CNDTR = length;                   /* Number of items */

    DMA1_CH4->CCR  = (1U << 4)   /* Direction: memory-to-peripheral */
                   | (1U << 7)    /* Memory increment mode */
                   | (0U << 6)    /* Peripheral address fixed */
                   | (0U << 8)    /* Peripheral size: 8-bit */
                   | (0U << 10)   /* Memory size: 8-bit */
                   | (1U << 1);   /* Transfer complete interrupt */

    /* Enable USART1 DMA transmit */
    USART1->CR3 |= (1U << 7);

    /* Start DMA transfer */
    DMA1_CH4->CCR |= (1U << 0);
}

volatile uint8_t dma_tx_complete = 0;

void DMA1_Channel4_IRQHandler(void)
{
    if (DMA1->ISR & (1U << 13)) {   /* Transfer complete flag */
        DMA1->IFCR = (1U << 13);    /* Clear flag */
        DMA1_CH4->CCR &= ~(1U << 0); /* Disable channel */
        dma_tx_complete = 1;
    }
}
```

### Double-Buffered DMA for Continuous ADC Sampling

```c
#define ADC_BUF_SIZE 256

static uint16_t adc_buffer_a[ADC_BUF_SIZE];
static uint16_t adc_buffer_b[ADC_BUF_SIZE];
static volatile uint16_t *active_buffer = adc_buffer_a;
static volatile uint8_t buffer_ready = 0;

void adc_dma_continuous_init(void)
{
    DMA_Channel_TypeDef *ch = DMA1_CH1;

    ch->CCR   = 0;
    ch->CPAR  = (uint32_t)&ADC1->DR;
    ch->CMAR  = (uint32_t)adc_buffer_a;
    ch->CNDTR = ADC_BUF_SIZE;

    ch->CCR  = (1U << 5)    /* Circular mode */
             | (1U << 7)    /* Memory increment */
             | (1U << 8)    /* Peripheral size: 16-bit */
             | (1U << 10)   /* Memory size: 16-bit */
             | (1U << 2)    /* Half-transfer interrupt */
             | (1U << 1);   /* Transfer complete interrupt */

    ch->CCR |= (1U << 0);   /* Enable */
}

void DMA1_Channel1_IRQHandler(void)
{
    if (DMA1->ISR & (1U << 2)) {
        /* Half transfer: first half ready to process */
        DMA1->IFCR = (1U << 2);
        active_buffer = adc_buffer_a;
        buffer_ready = 1;
    }

    if (DMA1->ISR & (1U << 1)) {
        /* Transfer complete: second half ready to process */
        DMA1->IFCR = (1U << 1);
        active_buffer = adc_buffer_a + (ADC_BUF_SIZE / 2);
        buffer_ready = 1;
    }
}
```

---

## 15. Finite State Machines

FSMs are the backbone of embedded control logic. They provide a structured, maintainable way to handle complex behavior.

### Table-Driven State Machine

See [`examples/09_state_machine.c`](examples/09_state_machine.c) for the complete implementation.

```c
#include <stdint.h>

typedef enum {
    STATE_IDLE,
    STATE_HEATING,
    STATE_TARGET_REACHED,
    STATE_COOLING,
    STATE_ERROR,
    STATE_COUNT
} state_t;

typedef enum {
    EVT_START,
    EVT_STOP,
    EVT_TEMP_HIGH,
    EVT_TEMP_LOW,
    EVT_TEMP_OK,
    EVT_FAULT,
    EVT_RESET,
    EVT_COUNT
} event_t;

/* Action function type */
typedef void (*action_fn)(void);

/* Transition table entry */
typedef struct {
    state_t   next_state;
    action_fn action;
} transition_t;

/* Action functions */
void action_start_heater(void)  { /* Turn on heater relay */ }
void action_stop_heater(void)   { /* Turn off heater relay */ }
void action_alarm(void)         { /* Sound alarm */ }
void action_log(void)           { /* Log event */ }
void action_none(void)          { /* No action */ }

/* Transition table: [current_state][event] → {next_state, action} */
static const transition_t fsm_table[STATE_COUNT][EVT_COUNT] = {
    /* STATE_IDLE */
    [STATE_IDLE] = {
        [EVT_START]     = {STATE_HEATING,        action_start_heater},
        [EVT_STOP]      = {STATE_IDLE,           action_none},
        [EVT_FAULT]     = {STATE_ERROR,          action_alarm},
    },
    /* STATE_HEATING */
    [STATE_HEATING] = {
        [EVT_TEMP_OK]   = {STATE_TARGET_REACHED, action_log},
        [EVT_TEMP_HIGH] = {STATE_COOLING,        action_stop_heater},
        [EVT_STOP]      = {STATE_IDLE,           action_stop_heater},
        [EVT_FAULT]     = {STATE_ERROR,          action_alarm},
    },
    /* STATE_TARGET_REACHED */
    [STATE_TARGET_REACHED] = {
        [EVT_TEMP_LOW]  = {STATE_HEATING,        action_start_heater},
        [EVT_TEMP_HIGH] = {STATE_COOLING,        action_stop_heater},
        [EVT_STOP]      = {STATE_IDLE,           action_stop_heater},
        [EVT_FAULT]     = {STATE_ERROR,          action_alarm},
    },
    /* STATE_COOLING */
    [STATE_COOLING] = {
        [EVT_TEMP_OK]   = {STATE_TARGET_REACHED, action_log},
        [EVT_TEMP_LOW]  = {STATE_HEATING,        action_start_heater},
        [EVT_STOP]      = {STATE_IDLE,           action_none},
        [EVT_FAULT]     = {STATE_ERROR,          action_alarm},
    },
    /* STATE_ERROR */
    [STATE_ERROR] = {
        [EVT_RESET]     = {STATE_IDLE,           action_stop_heater},
    },
};

static state_t current_state = STATE_IDLE;

void fsm_process_event(event_t evt)
{
    if (evt >= EVT_COUNT) return;

    const transition_t *t = &fsm_table[current_state][evt];

    if (t->action) {
        t->action();
    }

    current_state = t->next_state;
}
```

---

## 16. RTOS Fundamentals

An RTOS (Real-Time Operating System) provides multitasking, synchronization, and timing services for complex embedded applications.

### When to Use an RTOS

| Bare-Metal (Superloop) | RTOS |
|---|---|
| Simple applications | Multiple concurrent activities |
| Tight resource constraints | Need priority-based preemption |
| Predictable timing is easy | Complex timing dependencies |
| < 3–4 independent tasks | Many independent modules |

### RTOS Core Concepts

```
┌─────────────────────────────────────────────┐
│                 Application                  │
│  ┌────────┐ ┌────────┐ ┌────────┐          │
│  │ Task 1 │ │ Task 2 │ │ Task 3 │  ...     │
│  │ (High) │ │ (Med)  │ │ (Low)  │          │
│  └───┬────┘ └───┬────┘ └───┬────┘          │
│      │          │          │                 │
│  ┌───┴──────────┴──────────┴───┐            │
│  │         RTOS Kernel         │            │
│  │  Scheduler │ IPC │ Timers   │            │
│  └─────────────────────────────┘            │
├─────────────────────────────────────────────┤
│              Hardware (MCU)                  │
└─────────────────────────────────────────────┘
```

### RTOS Task Example (FreeRTOS-Style API)

See [`examples/10_rtos_tasks.c`](examples/10_rtos_tasks.c) for the complete implementation.

```c
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

/* Shared resources */
static QueueHandle_t     sensor_queue;
static SemaphoreHandle_t uart_mutex;

typedef struct {
    uint8_t  sensor_id;
    int16_t  value;
    uint32_t timestamp;
} sensor_msg_t;

/* High-priority task: reads sensors periodically */
void sensor_task(void *params)
{
    (void)params;
    sensor_msg_t msg;

    while (1) {
        msg.sensor_id  = 0;
        msg.value      = adc_read(0);
        msg.timestamp  = xTaskGetTickCount();

        xQueueSend(sensor_queue, &msg, portMAX_DELAY);

        vTaskDelay(pdMS_TO_TICKS(100));  /* 100 ms period */
    }
}

/* Medium-priority task: processes sensor data and logs it */
void logger_task(void *params)
{
    (void)params;
    sensor_msg_t msg;

    while (1) {
        if (xQueueReceive(sensor_queue, &msg, portMAX_DELAY) == pdTRUE) {
            xSemaphoreTake(uart_mutex, portMAX_DELAY);
            uart_printf(USART1, "[%lu] Sensor %u: %d\r\n",
                        msg.timestamp, msg.sensor_id, msg.value);
            xSemaphoreGive(uart_mutex);
        }
    }
}

/* Low-priority task: blinks an LED to show system is alive */
void heartbeat_task(void *params)
{
    (void)params;

    while (1) {
        gpio_toggle(GPIOA, 5);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

int main(void)
{
    system_clock_init();
    gpio_init();
    uart_init(USART1, 115200, 72000000);

    sensor_queue = xQueueCreate(16, sizeof(sensor_msg_t));
    uart_mutex   = xSemaphoreCreateMutex();

    xTaskCreate(sensor_task,    "Sensor",    256, NULL, 3, NULL);
    xTaskCreate(logger_task,    "Logger",    512, NULL, 2, NULL);
    xTaskCreate(heartbeat_task, "Heartbeat", 128, NULL, 1, NULL);

    vTaskStartScheduler();

    while (1); /* Should never reach here */
}
```

### Inter-Task Communication Patterns

```c
/* ── Binary Semaphore: ISR to Task signaling ──────── */
SemaphoreHandle_t rx_sem;

void USART1_IRQHandler(void)
{
    BaseType_t woken = pdFALSE;
    /* ... handle RX ... */
    xSemaphoreGiveFromISR(rx_sem, &woken);
    portYIELD_FROM_ISR(woken);
}

void rx_handler_task(void *params)
{
    (void)params;
    while (1) {
        xSemaphoreTake(rx_sem, portMAX_DELAY);
        process_received_data();
    }
}

/* ── Event Groups: multiple conditions ────────────── */
#include "event_groups.h"

#define EVT_SENSOR_READY  (1 << 0)
#define EVT_BUTTON_PRESS  (1 << 1)
#define EVT_TIMER_EXPIRED (1 << 2)

EventGroupHandle_t events;

void control_task(void *params)
{
    (void)params;
    while (1) {
        EventBits_t bits = xEventGroupWaitBits(events,
            EVT_SENSOR_READY | EVT_BUTTON_PRESS,
            pdTRUE, pdTRUE, portMAX_DELAY);

        if (bits & EVT_SENSOR_READY) { /* ... */ }
        if (bits & EVT_BUTTON_PRESS)  { /* ... */ }
    }
}
```

---

## 17. Memory Management Strategies

Dynamic memory allocation (`malloc`/`free`) is generally avoided in safety-critical embedded systems due to fragmentation, non-deterministic timing, and heap exhaustion risks.

### Static Allocation (Preferred)

```c
/* All memory is allocated at compile time. Sizes known a priori. */
static uint8_t uart_rx_buffer[256];
static uint8_t uart_tx_buffer[256];
static sensor_msg_t sensor_pool[16];
```

### Memory Pool (Fixed-Block Allocator)

See [`examples/11_memory_pool.c`](examples/11_memory_pool.c) for the complete implementation.

```c
#include <stdint.h>
#include <string.h>

#define POOL_BLOCK_SIZE  64
#define POOL_BLOCK_COUNT 16

typedef struct {
    uint8_t  memory[POOL_BLOCK_COUNT][POOL_BLOCK_SIZE];
    uint8_t  used[POOL_BLOCK_COUNT];
    uint16_t free_count;
} mem_pool_t;

static mem_pool_t pool;

void pool_init(void)
{
    memset(pool.used, 0, sizeof(pool.used));
    pool.free_count = POOL_BLOCK_COUNT;
}

void *pool_alloc(void)
{
    for (uint16_t i = 0; i < POOL_BLOCK_COUNT; i++) {
        if (!pool.used[i]) {
            pool.used[i] = 1;
            pool.free_count--;
            return pool.memory[i];
        }
    }
    return (void *)0;  /* Pool exhausted */
}

void pool_free(void *ptr)
{
    for (uint16_t i = 0; i < POOL_BLOCK_COUNT; i++) {
        if (ptr == pool.memory[i]) {
            pool.used[i] = 0;
            pool.free_count++;
            return;
        }
    }
}

uint16_t pool_available(void)
{
    return pool.free_count;
}
```

### Stack Usage Analysis

```c
/* Fill the stack with a known pattern at startup.
   Later, scan from the bottom to find the high-water mark. */

#define STACK_FILL_PATTERN 0xDEADBEEF

extern uint32_t _estack;   /* Defined in linker script */
extern uint32_t _sstack;

void stack_paint(void)
{
    volatile uint32_t *p = &_sstack;
    uint32_t *sp;
    __asm volatile ("MOV %0, SP" : "=r" (sp));

    while (p < (sp - 16)) {
        *p++ = STACK_FILL_PATTERN;
    }
}

uint32_t stack_usage_bytes(void)
{
    uint32_t *p = (uint32_t *)&_sstack;
    while (*p == STACK_FILL_PATTERN && p < &_estack) {
        p++;
    }
    return (uint32_t)((uint8_t *)&_estack - (uint8_t *)p);
}
```

---

## 18. Low-Power Design Techniques

Power management is critical for battery-powered embedded devices.

### ARM Cortex-M Sleep Modes

| Mode | CPU | Peripherals | SRAM | Wake-Up Time |
|---|---|---|---|---|
| Run | Active | Active | Retained | N/A |
| Sleep | Stopped | Active | Retained | ~1 µs |
| Stop | Stopped | Stopped | Retained | ~5 µs |
| Standby | Stopped | Stopped | Lost | ~50 µs + boot |

### Low-Power Techniques

```c
#include <stdint.h>

/* System Control Block for ARM Cortex-M */
#define SCB_SCR (*(volatile uint32_t *)0xE000ED10U)

void enter_sleep_mode(void)
{
    SCB_SCR &= ~(1U << 2);  /* Clear SLEEPDEEP bit */
    __asm volatile ("WFI");   /* Wait For Interrupt */
}

void enter_stop_mode(void)
{
    SCB_SCR |= (1U << 2);   /* Set SLEEPDEEP bit */

    /* Configure power controller for Stop mode */
    PWR->CR |= (1U << 0);    /* Low-power deepsleep */
    PWR->CR &= ~(1U << 1);   /* Stop mode (not Standby) */

    __asm volatile ("WFI");

    /* After wake-up: reconfigure system clock (HSI is active) */
    system_clock_init();
}

void enter_standby_mode(void)
{
    SCB_SCR |= (1U << 2);

    PWR->CR |= (1U << 1);    /* Standby mode */
    PWR->CR |= (1U << 2);    /* Clear wake-up flag */

    __asm volatile ("WFI");
    /* System resets on wake-up — execution restarts from Reset_Handler */
}
```

### Peripheral Clock Gating

```c
/* Disable clocks to unused peripherals to save power */
void disable_unused_peripherals(void)
{
    RCC->APB1ENR &= ~(1U << 0);   /* Disable TIM2 if not used */
    RCC->APB1ENR &= ~(1U << 17);  /* Disable USART2 if not used */
    RCC->APB2ENR &= ~(1U << 12);  /* Disable SPI1 if not used */
}

/* Only enable a peripheral when needed, disable after use */
uint16_t adc_read_low_power(uint8_t channel)
{
    RCC->APB2ENR |= (1U << 9);    /* Enable ADC clock */
    ADC1->CR2 |= ADC_CR2_ADON;    /* Power on ADC */

    for (volatile int i = 0; i < 100; i++);  /* Stabilization */

    uint16_t result = adc_read(channel);

    ADC1->CR2 &= ~ADC_CR2_ADON;   /* Power off ADC */
    RCC->APB2ENR &= ~(1U << 9);   /* Disable ADC clock */

    return result;
}
```

---

## 19. Watchdog Timers and System Reliability

A watchdog timer (WDT) is a hardware countdown timer that resets the system if software fails to "kick" (refresh) it periodically. It detects firmware hangs, infinite loops, and deadlocks.

### Independent Watchdog (IWDG)

```c
typedef struct {
    volatile uint32_t KR;    /* Key register */
    volatile uint32_t PR;    /* Prescaler register */
    volatile uint32_t RLR;   /* Reload register */
    volatile uint32_t SR;    /* Status register */
} IWDG_TypeDef;

#define IWDG ((IWDG_TypeDef *)0x40003000U)

/* IWDG runs on independent 40 kHz LSI oscillator.
   Timeout = (Prescaler × Reload) / 40000 seconds */

void iwdg_init(uint32_t timeout_ms)
{
    IWDG->KR = 0x5555;  /* Enable register access */

    IWDG->PR  = 4;      /* Prescaler = /64 → 625 Hz */
    IWDG->RLR = (timeout_ms * 625) / 1000;

    IWDG->KR = 0xCCCC;  /* Start watchdog */
}

void iwdg_refresh(void)
{
    IWDG->KR = 0xAAAA;  /* Reload counter */
}

/* Typical usage pattern */
int main(void)
{
    system_init();
    iwdg_init(1000);  /* 1-second timeout */

    while (1) {
        task_a();
        task_b();
        task_c();

        iwdg_refresh();
    }
}
```

### Multi-Task Watchdog Pattern

```c
#define TASK_COUNT 4
static volatile uint32_t task_checkin[TASK_COUNT];

void task_alive(uint8_t task_id)
{
    task_checkin[task_id] = systick_count;
}

void watchdog_monitor_task(void *params)
{
    (void)params;
    while (1) {
        uint8_t all_alive = 1;
        uint32_t now = systick_count;

        for (uint8_t i = 0; i < TASK_COUNT; i++) {
            if ((now - task_checkin[i]) > 2000) {  /* 2s timeout per task */
                all_alive = 0;
                log_error(ERR_TASK_TIMEOUT, i);
            }
        }

        if (all_alive) {
            iwdg_refresh();
        }

        vTaskDelay(pdMS_TO_TICKS(200));
    }
}
```

---

## 20. Debugging and Testing

### Assert Macros for Embedded

```c
#ifdef DEBUG
#define ASSERT(expr) do {                                   \
    if (!(expr)) {                                          \
        assert_failed(__FILE__, __LINE__, #expr);           \
    }                                                       \
} while (0)
#else
#define ASSERT(expr) ((void)0)
#endif

void assert_failed(const char *file, uint32_t line, const char *expr)
{
    __asm volatile ("CPSID i");  /* Disable interrupts */

    uart_printf(USART1, "ASSERT FAILED: %s:%lu: %s\r\n", file, line, expr);

    /* Flash LED rapidly to indicate error */
    while (1) {
        gpio_toggle(GPIOA, 5);
        for (volatile uint32_t i = 0; i < 50000; i++);
    }
}

/* Usage */
void process_buffer(uint8_t *buf, uint16_t len)
{
    ASSERT(buf != (void *)0);
    ASSERT(len > 0 && len <= 1024);
    /* ... */
}
```

### Lightweight Logging Framework

```c
typedef enum {
    LOG_DEBUG   = 0,
    LOG_INFO    = 1,
    LOG_WARNING = 2,
    LOG_ERROR   = 3,
    LOG_NONE    = 4
} log_level_t;

static log_level_t current_level = LOG_INFO;

#ifdef DEBUG
#define LOG(level, fmt, ...) do {                            \
    if ((level) >= current_level) {                          \
        static const char *lvl_str[] =                      \
            {"DBG", "INF", "WRN", "ERR"};                   \
        uart_printf(USART1, "[%s] " fmt "\r\n",             \
                    lvl_str[(level)], ##__VA_ARGS__);        \
    }                                                       \
} while (0)
#else
#define LOG(level, fmt, ...) ((void)0)
#endif

/* Usage */
void sensor_read_example(void)
{
    uint16_t raw = adc_read(0);
    LOG(LOG_DEBUG, "ADC raw: %u", raw);

    if (raw > 3800) {
        LOG(LOG_WARNING, "Sensor near saturation: %u", raw);
    }

    if (raw == 0) {
        LOG(LOG_ERROR, "Sensor disconnected on channel 0");
    }
}
```

### Hardware Breakpoint Trigger

```c
/* Trigger a breakpoint in the debugger programmatically */
static inline void breakpoint(void)
{
    __asm volatile ("BKPT #0");
}

/* ITM (Instrumentation Trace Macrocell) printf-style output.
   Visible in debugger's SWO trace window — zero overhead when
   no debugger is attached. */
#define ITM_STIM0 (*(volatile uint32_t *)0xE0000000U)
#define ITM_TER   (*(volatile uint32_t *)0xE0000E00U)

void itm_send_char(char c)
{
    if (ITM_TER & 1) {
        while (!(ITM_STIM0 & 1));
        ITM_STIM0 = (uint32_t)c;
    }
}

void itm_send_string(const char *s)
{
    while (*s) {
        itm_send_char(*s++);
    }
}
```

---

## 21. Coding Standards and Best Practices

### MISRA C Guidelines (Key Subset)

| Rule | Rationale |
|---|---|
| Use fixed-width types (`uint32_t`) | Portable across architectures |
| No `goto` | Improves code flow clarity |
| No recursion | Stack depth must be bounded |
| No dynamic memory (`malloc`) | Prevents fragmentation, heap exhaustion |
| All `switch` cases have `break`/`return` | Prevents fall-through bugs |
| All `if-else if` chains end with `else` | Handles unexpected conditions |
| No implicit type conversions | Use explicit casts |

### Defensive Programming

```c
/* Always validate inputs */
i2c_status_t i2c_safe_read(I2C_TypeDef *i2c, uint8_t addr,
                            uint8_t *buf, uint16_t len)
{
    if (i2c == (void *)0 || buf == (void *)0 || len == 0) {
        return I2C_ERR_BUS;
    }

    return i2c_read(i2c, addr, buf, len);
}

/* Use default cases in switch statements */
void handle_command(uint8_t cmd)
{
    switch (cmd) {
    case CMD_START:
        motor_start();
        break;
    case CMD_STOP:
        motor_stop();
        break;
    case CMD_STATUS:
        send_status();
        break;
    default:
        LOG(LOG_WARNING, "Unknown command: 0x%02X", cmd);
        break;
    }
}

/* Use sizeof for buffer operations */
void safe_copy(uint8_t *dst, const uint8_t *src, uint16_t len)
{
    if (len > sizeof(dst)) {
        len = sizeof(dst);
    }
    memcpy(dst, src, len);
}
```

### Naming Conventions

```c
/* Module prefix for all public symbols (avoids collisions) */
void    uart_init(USART_TypeDef *uart, uint32_t baud, uint32_t pclk);
void    uart_send_byte(USART_TypeDef *uart, uint8_t data);
uint8_t uart_receive_byte(USART_TypeDef *uart);

/* Type suffixes */
typedef uint8_t  gpio_pin_t;
typedef uint32_t timer_tick_t;
typedef enum { ... } motor_state_t;

/* Constants: UPPER_CASE */
#define UART_BAUD_DEFAULT   115200U
#define MAX_RETRY_COUNT     3U

/* File-local (static) functions: no module prefix needed */
static void configure_pins(void);
static void start_conversion(void);
```

### Project Organization

```
project/
├── src/
│   ├── main.c                  # Application entry point
│   ├── system_init.c           # Clock, power, startup config
│   ├── drivers/
│   │   ├── gpio.c / gpio.h     # GPIO driver
│   │   ├── uart.c / uart.h     # UART driver
│   │   ├── spi.c  / spi.h      # SPI driver
│   │   ├── i2c.c  / i2c.h      # I2C driver
│   │   ├── adc.c  / adc.h      # ADC driver
│   │   └── timer.c / timer.h   # Timer driver
│   ├── hal/
│   │   └── stm32f1xx.h         # MCU register definitions
│   ├── middleware/
│   │   ├── ring_buffer.c / .h  # Ring buffer utility
│   │   ├── state_machine.c     # FSM engine
│   │   └── mem_pool.c / .h     # Memory pool allocator
│   └── app/
│       ├── sensor_task.c       # Sensor reading logic
│       └── comm_task.c         # Communication handler
├── inc/                        # Public header files
├── startup/
│   ├── startup_stm32f103.s     # Vector table, Reset_Handler
│   └── stm32f103_linker.ld     # Linker script
├── Makefile                    # Build system
└── README.md
```

---

## Quick Reference Card

### Common Register Manipulation Patterns

```c
/* Set bits */       REG |= MASK;
/* Clear bits */     REG &= ~MASK;
/* Toggle bits */    REG ^= MASK;
/* Check bits */     if (REG & MASK) { ... }
/* Write field */    REG = (REG & ~FIELD_MASK) | (VALUE << SHIFT);
/* Atomic set */     BSRR = (1 << pin);          /* Write-only register */
/* Atomic clear */   BSRR = (1 << (pin + 16));   /* Write-only register */
/* Wait for flag */  while (!(REG & FLAG));
/* Clear flag */     REG = FLAG;                  /* Write-1-to-clear */
```

### Common Timing Calculations

```
Timer tick frequency = System_Clock / (Prescaler + 1)
Timer overflow period = (ARR + 1) / tick_frequency
PWM frequency = tick_frequency / (ARR + 1)
PWM duty cycle = CCR / (ARR + 1) × 100%
UART baud divisor = PCLK / (16 × Baud_Rate)
I2C SCL period = 2 × CCR × TPCLK  (standard mode)
SPI bit rate = PCLK / 2^(BR+1)
```

### Interrupt Priority Rules

1. Lower numeric priority = higher urgency (ARM Cortex-M)
2. ISRs must be short — set flags, copy data, exit
3. Never call blocking functions from an ISR
4. Use `volatile` for all variables shared with ISRs
5. Protect read-modify-write sequences with critical sections
6. Use `FromISR` API variants in RTOS ISR handlers

---

## Further Reading

- **ARM Cortex-M Architecture Reference Manual** — ARM Limited
- **STM32 Reference Manuals** — STMicroelectronics
- **Making Embedded Systems** — Elecia White (O'Reilly)
- **The Definitive Guide to ARM Cortex-M3/M4** — Joseph Yiu
- **MISRA C:2012 Guidelines** — Motor Industry Software Reliability Association
- **FreeRTOS Documentation** — freertos.org

---

*This guide provides a foundation for embedded C development. Each section's concepts build on previous ones. The accompanying example files in the `examples/` directory contain complete, compilable implementations that can be adapted to specific microcontroller platforms.*
