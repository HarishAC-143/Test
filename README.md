# Embedded C Programming: A Comprehensive Guide

A complete tutorial covering Embedded C fundamentals through advanced topics, with
practical code examples targeting ARM Cortex-M microcontrollers.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Development Environment](#2-development-environment)
3. [C Language Foundations for Embedded](#3-c-language-foundations-for-embedded)
4. [Memory Model and Data Types](#4-memory-model-and-data-types)
5. [Bit Manipulation](#5-bit-manipulation)
6. [Volatile, Const, and Static](#6-volatile-const-and-static)
7. [Pointers and Memory-Mapped I/O](#7-pointers-and-memory-mapped-io)
8. [Structures, Unions, and Bit-Fields](#8-structures-unions-and-bit-fields)
9. [GPIO Programming](#9-gpio-programming)
10. [Interrupts and ISRs](#10-interrupts-and-isrs)
11. [Timer/Counter Programming](#11-timercounter-programming)
12. [UART Communication](#12-uart-communication)
13. [SPI Communication](#13-spi-communication)
14. [I2C Communication](#14-i2c-communication)
15. [ADC Programming](#15-adc-programming)
16. [DMA (Direct Memory Access)](#16-dma-direct-memory-access)
17. [Watchdog Timers](#17-watchdog-timers)
18. [Low-Power Modes](#18-low-power-modes)
19. [RTOS Fundamentals](#19-rtos-fundamentals)
20. [Common Data Structures](#20-common-data-structures)
21. [State Machine Design](#21-state-machine-design)
22. [Bootloader Basics](#22-bootloader-basics)
23. [Debugging Techniques](#23-debugging-techniques)
24. [Best Practices](#24-best-practices)

---

## 1. Introduction

Embedded C is the most widely used language for programming microcontrollers and
embedded systems. While it follows the same syntax as standard C (C99/C11), embedded
programming introduces hardware-specific concepts that desktop C programmers rarely
encounter:

- **Direct hardware register access** via memory-mapped I/O
- **Interrupt-driven programming** with strict timing constraints
- **Severe resource constraints** (KB of RAM, KB-MB of Flash)
- **No operating system** (bare-metal) or a lightweight RTOS
- **Real-time requirements** where missing a deadline is a failure

This guide uses an **ARM Cortex-M** target (STM32) for examples, but the concepts
apply to any microcontroller family (AVR, PIC, RISC-V, MSP430, etc.).

### Who This Guide Is For

- C programmers transitioning to embedded development
- Electrical engineers learning firmware programming
- Students studying embedded systems courses
- Hobbyists building microcontroller projects

---

## 2. Development Environment

### Toolchain Components

| Component | Purpose | Example Tools |
|-----------|---------|---------------|
| Cross-compiler | Compiles C to target machine code | `arm-none-eabi-gcc`, IAR, Keil |
| Linker | Combines object files, places sections in memory | `arm-none-eabi-ld` (via gcc) |
| Debugger | Steps through code on the target | `arm-none-eabi-gdb`, OpenOCD, J-Link |
| Flash programmer | Writes binary to microcontroller Flash | `st-flash`, J-Flash, `openocd` |
| IDE (optional) | Integrated environment | STM32CubeIDE, Keil uVision, PlatformIO |

### Typical Build Flow

```
Source (.c/.h)  -->  Preprocessor  -->  Compiler  -->  Assembler  -->  Linker  -->  Binary (.elf/.bin/.hex)
                                                                        ^
                                                                        |
                                                                   Linker Script (.ld)
                                                                   (defines memory layout)
```

### Compiler Flags for Embedded

```bash
arm-none-eabi-gcc \
    -mcpu=cortex-m4          \  # Target CPU core
    -mthumb                  \  # Use Thumb-2 instruction set
    -mfloat-abi=hard         \  # Hardware floating point
    -mfpu=fpv4-sp-d16        \  # FPU type
    -Os                      \  # Optimize for size
    -Wall -Wextra            \  # Enable warnings
    -ffunction-sections      \  # Place each function in its own section
    -fdata-sections          \  # Place each variable in its own section
    -Wl,--gc-sections        \  # Remove unused sections at link time
    -T linker_script.ld      \  # Memory layout
    -o firmware.elf main.c
```

### Linker Script Basics

The linker script tells the linker where to place code and data in the
microcontroller's memory map:

```ld
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 512K
    SRAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
}

SECTIONS
{
    .text : {           /* Code and read-only data */
        *(.isr_vector)  /* Interrupt vector table (must be first) */
        *(.text*)
        *(.rodata*)
    } > FLASH

    .data : {           /* Initialized global/static variables */
        *(.data*)
    } > SRAM AT > FLASH /* Runs from SRAM, loaded from Flash */

    .bss : {            /* Zero-initialized global/static variables */
        *(.bss*)
    } > SRAM
}
```

---

## 3. C Language Foundations for Embedded

### Fixed-Width Integer Types

Standard C `int` is platform-dependent (16-bit on AVR, 32-bit on ARM). Embedded code
must use fixed-width types from `<stdint.h>`:

```c
#include <stdint.h>

uint8_t  sensor_reading;    /* Exactly 8 bits, unsigned  (0 to 255)         */
int8_t   temperature;       /* Exactly 8 bits, signed    (-128 to 127)      */
uint16_t adc_value;         /* Exactly 16 bits, unsigned (0 to 65535)       */
int16_t  motor_speed;       /* Exactly 16 bits, signed                      */
uint32_t timestamp_ms;      /* Exactly 32 bits, unsigned (0 to 4294967295)  */
int32_t  position;          /* Exactly 32 bits, signed                      */
```

**Why this matters:** Writing `unsigned int counter;` gives you 16 bits on an AVR
(ATmega328) but 32 bits on an STM32. Using `uint32_t` guarantees 32 bits everywhere.

### The `sizeof` Operator

Always verify assumptions about type sizes, especially when dealing with hardware
registers or communication protocols:

```c
#include <stdint.h>
#include <stdio.h>

void print_type_sizes(void)
{
    /* These are GUARANTEED by stdint.h */
    printf("uint8_t:  %zu bytes\n", sizeof(uint8_t));   /* Always 1 */
    printf("uint16_t: %zu bytes\n", sizeof(uint16_t));  /* Always 2 */
    printf("uint32_t: %zu bytes\n", sizeof(uint32_t));  /* Always 4 */

    /* These are PLATFORM-DEPENDENT — avoid in portable embedded code */
    printf("int:      %zu bytes\n", sizeof(int));       /* 2 or 4 */
    printf("long:     %zu bytes\n", sizeof(long));      /* 4 or 8 */
    printf("pointer:  %zu bytes\n", sizeof(void *));    /* 2, 4, or 8 */
}
```

### Preprocessor Directives

The preprocessor is heavily used in embedded C for hardware abstraction and
compile-time configuration:

```c
/* ---- Header guard (prevents double-inclusion) ---- */
#ifndef UART_DRIVER_H
#define UART_DRIVER_H

/* ---- Feature toggles ---- */
#define ENABLE_DEBUG_UART   1
#define BAUD_RATE           115200

/* ---- Compile-time assertions ---- */
#if BAUD_RATE < 9600 || BAUD_RATE > 921600
    #error "BAUD_RATE out of supported range"
#endif

/* ---- Conditional compilation ---- */
#ifdef ENABLE_DEBUG_UART
    #define DEBUG_PRINT(fmt, ...) uart_printf(fmt, ##__VA_ARGS__)
#else
    #define DEBUG_PRINT(fmt, ...) ((void)0)  /* Compiles to nothing */
#endif

/* ---- Platform selection ---- */
#if defined(STM32F4)
    #include "stm32f4xx.h"
#elif defined(STM32L0)
    #include "stm32l0xx.h"
#else
    #error "Unsupported platform"
#endif

#endif /* UART_DRIVER_H */
```

---

## 4. Memory Model and Data Types

### Microcontroller Memory Map

A typical Cortex-M microcontroller has this memory layout:

```
Address Range          Region           Description
─────────────────────────────────────────────────────────────
0x0000_0000  ┐
             │        Code             Aliased to Flash or SRAM
0x07FF_FFFF  ┘
0x0800_0000  ┐
             │        Flash            Program code + constants
0x080F_FFFF  ┘
0x2000_0000  ┐
             │        SRAM             Variables, stack, heap
0x2001_FFFF  ┘
0x4000_0000  ┐
             │        Peripherals      GPIO, UART, SPI, TIM, etc.
0x5FFF_FFFF  ┘
0xE000_0000  ┐
             │        System           NVIC, SysTick, SCB, etc.
0xE00F_FFFF  ┘
```

### Stack and Heap

```
SRAM Layout (growing addresses →)
┌─────────┬─────────────────┬──────────┬────────────────┬────────────┐
│  .data  │      .bss       │   Heap   │  (free space)  │   Stack    │
│(init'd) │ (zero-init'd)   │   →→→    │                │   ←←←     │
└─────────┴─────────────────┴──────────┴────────────────┴────────────┘
                                                         ↑
                                                    Stack Pointer (SP)
                                                    starts at top of SRAM
```

**Stack** grows downward from the top of SRAM. Used for:
- Local variables
- Function return addresses
- Interrupt context saving

**Heap** grows upward (if `malloc` is used — generally avoided in embedded).

### Storage Classes

```c
/* GLOBAL SCOPE */
int g_count;                /* .bss — zero-initialized, globally visible  */
static int s_module_count;  /* .bss — zero-initialized, file-scope only   */
const int VERSION = 3;      /* .rodata (Flash) — read-only                */

void example_function(void)
{
    /* LOCAL SCOPE */
    int local_var = 10;          /* Stack — created on entry, destroyed on exit */
    static int call_count = 0;   /* .data — persists across calls              */
    call_count++;

    const int THRESHOLD = 100;   /* Often optimized to an immediate value      */
}
```

---

## 5. Bit Manipulation

Bit manipulation is the **most fundamental embedded C skill**. Hardware registers
are controlled bit by bit, and wasting an entire byte for a boolean flag is
unacceptable when RAM is measured in kilobytes.

### Core Bit Operations

```c
#include <stdint.h>

/*
 * Bit numbering (for an 8-bit register):
 *
 *   Bit:  7   6   5   4   3   2   1   0
 *        [  ] [  ] [  ] [  ] [  ] [  ] [  ] [  ]
 *
 *   (1 << 0) = 0b00000001 = 0x01
 *   (1 << 3) = 0b00001000 = 0x08
 *   (1 << 7) = 0b10000000 = 0x80
 */

void bit_operations_demo(void)
{
    uint8_t reg = 0x00;

    /* SET a bit (force to 1) — use OR */
    reg |= (1 << 3);           /* reg = 0b00001000 */

    /* CLEAR a bit (force to 0) — use AND with inverted mask */
    reg &= ~(1 << 3);          /* reg = 0b00000000 */

    /* TOGGLE a bit (flip) — use XOR */
    reg ^= (1 << 3);           /* reg = 0b00001000 */

    /* TEST a bit (check if set) — use AND */
    if (reg & (1 << 3)) {
        /* Bit 3 is set */
    }

    /* SET multiple bits at once */
    reg |= (1 << 7) | (1 << 5) | (1 << 0);  /* Set bits 7, 5, 0 */

    /* CLEAR multiple bits at once */
    reg &= ~((1 << 7) | (1 << 5));           /* Clear bits 7, 5 */

    /* MODIFY a multi-bit field (e.g., bits [5:4]) */
    reg &= ~(0x3 << 4);        /* Clear the 2-bit field first    */
    reg |= (0x2 << 4);         /* Write new value (0b10) into it */
}
```

### Convenience Macros

```c
#define BIT_SET(reg, bit)       ((reg) |=  (1U << (bit)))
#define BIT_CLEAR(reg, bit)     ((reg) &= ~(1U << (bit)))
#define BIT_TOGGLE(reg, bit)    ((reg) ^=  (1U << (bit)))
#define BIT_CHECK(reg, bit)     ((reg) &   (1U << (bit)))

#define BITS_SET(reg, mask)     ((reg) |=  (mask))
#define BITS_CLEAR(reg, mask)   ((reg) &= ~(mask))

/* Extract a field: FIELD_GET(0xAB, 4, 0xF) => 0xA */
#define FIELD_GET(reg, shift, mask)        (((reg) >> (shift)) & (mask))
#define FIELD_SET(reg, shift, mask, val)   \
    do { (reg) = ((reg) & ~((mask) << (shift))) | (((val) & (mask)) << (shift)); } while(0)
```

---

## 6. Volatile, Const, and Static

### `volatile` — The Most Important Embedded Keyword

The `volatile` qualifier tells the compiler: **"This variable can change at any time
outside the program's normal flow — do not optimize away reads or writes."**

Three situations require `volatile`:

```c
/* 1. Hardware registers — changed by hardware */
#define GPIOA_IDR  (*(volatile uint32_t *)0x40020010)

/* 2. Variables modified in an ISR — changed asynchronously */
volatile uint32_t systick_count = 0;

void SysTick_Handler(void)
{
    systick_count++;  /* Modified in interrupt context */
}

void delay_ms(uint32_t ms)
{
    uint32_t start = systick_count;
    /*
     * Without volatile, the compiler might read systick_count once,
     * cache it in a register, and loop forever because the cached
     * value never changes.
     */
    while ((systick_count - start) < ms) {
        /* Wait */
    }
}

/* 3. Variables shared between threads (in an RTOS) */
volatile uint8_t data_ready = 0;
```

### What Happens Without `volatile`

```c
/* BUG: compiler may optimize this to a single read */
uint32_t *status_reg = (uint32_t *)0x40020000;

while (*status_reg & 0x01) {  /* Compiler may hoist this read out of the loop */
    /* Wait for bit 0 to clear */
}

/* FIX: */
volatile uint32_t *status_reg = (volatile uint32_t *)0x40020000;

while (*status_reg & 0x01) {  /* Compiler MUST re-read every iteration */
    /* Wait for bit 0 to clear */
}
```

### `const` — Enforcing Read-Only Access

```c
/* Place configuration in Flash (saves RAM) */
const uint32_t CALIBRATION_TABLE[256] = { /* ... */ };

/* Pointer to a hardware register we should only read */
const volatile uint32_t *adc_data = (const volatile uint32_t *)0x4001204C;
/*    ^^^^^                ^^^^^^^
 *    We won't write to it  Hardware updates it */
```

### `static` — Controlling Scope and Lifetime

```c
/* 1. File-scope static: visible only within this .c file */
static uint32_t error_count = 0;

/* 2. Function-scope static: persists across calls */
uint32_t get_unique_id(void)
{
    static uint32_t next_id = 0;
    return next_id++;
}

/* 3. Static function: internal linkage (not visible to other .c files) */
static void configure_clock(void)
{
    /* Only callable from within this file */
}
```

---

## 7. Pointers and Memory-Mapped I/O

### Memory-Mapped I/O Explained

On ARM Cortex-M, peripherals are controlled by reading and writing to specific
memory addresses. Each peripheral has a block of registers at fixed addresses:

```c
/*
 * Example: STM32 GPIOA registers start at 0x4002_0000
 *
 * Offset  Register  Description
 * 0x00    MODER     Mode register (input/output/alternate/analog)
 * 0x04    OTYPER    Output type (push-pull / open-drain)
 * 0x08    OSPEEDR   Output speed
 * 0x0C    PUPDR     Pull-up / pull-down
 * 0x10    IDR       Input data register (read pin states)
 * 0x14    ODR       Output data register (set pin states)
 * 0x18    BSRR      Bit set/reset register (atomic set/clear)
 */

/* Direct register access using pointers */
#define GPIOA_BASE      0x40020000U
#define GPIOA_MODER     (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_ODR       (*(volatile uint32_t *)(GPIOA_BASE + 0x14))
#define GPIOA_BSRR      (*(volatile uint32_t *)(GPIOA_BASE + 0x18))

void led_on(void)
{
    GPIOA_BSRR = (1 << 5);        /* Set bit 5 → PA5 goes HIGH */
}

void led_off(void)
{
    GPIOA_BSRR = (1 << (5 + 16)); /* Reset bit 5 → PA5 goes LOW */
}
```

### Structure Overlay — The Preferred Approach

Instead of individual `#define` macros, define a struct that maps to the register
layout:

```c
typedef struct {
    volatile uint32_t MODER;     /* Offset 0x00 */
    volatile uint32_t OTYPER;    /* Offset 0x04 */
    volatile uint32_t OSPEEDR;   /* Offset 0x08 */
    volatile uint32_t PUPDR;     /* Offset 0x0C */
    volatile uint32_t IDR;       /* Offset 0x10 */
    volatile uint32_t ODR;       /* Offset 0x14 */
    volatile uint32_t BSRR;      /* Offset 0x18 */
    volatile uint32_t LCKR;      /* Offset 0x1C */
    volatile uint32_t AFR[2];    /* Offset 0x20-0x24 */
} GPIO_TypeDef;

#define GPIOA   ((GPIO_TypeDef *)0x40020000U)
#define GPIOB   ((GPIO_TypeDef *)0x40020400U)
#define GPIOC   ((GPIO_TypeDef *)0x40020800U)

void configure_pa5_output(void)
{
    GPIOA->MODER &= ~(3U << 10);   /* Clear bits [11:10]           */
    GPIOA->MODER |=  (1U << 10);   /* Set to 01 = General-purpose output */
    GPIOA->OTYPER &= ~(1U << 5);   /* Push-pull                    */
    GPIOA->OSPEEDR |= (3U << 10);  /* High speed                   */
}
```

### Function Pointers

Function pointers are used extensively for callbacks, interrupt vector tables, and
plugin architectures:

```c
typedef void (*isr_handler_t)(void);

/* Interrupt vector table (array of function pointers) */
__attribute__((section(".isr_vector")))
const isr_handler_t vector_table[] = {
    (isr_handler_t)0x20020000,   /* Initial stack pointer         */
    Reset_Handler,                /* Reset handler                 */
    NMI_Handler,                  /* Non-maskable interrupt        */
    HardFault_Handler,            /* Hard fault                    */
    /* ... more entries ... */
};

/* Callback registration pattern */
typedef void (*button_callback_t)(uint8_t pin, uint8_t state);

static button_callback_t user_callback = NULL;

void button_register_callback(button_callback_t cb)
{
    user_callback = cb;
}

void EXTI0_IRQHandler(void)
{
    if (user_callback) {
        user_callback(0, 1);
    }
}
```

---

## 8. Structures, Unions, and Bit-Fields

### Packed Structures for Protocol Parsing

When dealing with communication protocols, structs must match the exact byte layout
of the data:

```c
/* Network packet header — must be exactly 8 bytes with no padding */
typedef struct __attribute__((packed)) {
    uint8_t  version;        /* Byte 0    */
    uint8_t  type;           /* Byte 1    */
    uint16_t length;         /* Bytes 2-3 */
    uint32_t sequence_num;   /* Bytes 4-7 */
} packet_header_t;

_Static_assert(sizeof(packet_header_t) == 8, "Header must be 8 bytes");

void parse_packet(const uint8_t *raw_data)
{
    const packet_header_t *hdr = (const packet_header_t *)raw_data;

    if (hdr->version != 0x01) {
        return;  /* Unsupported version */
    }

    /* Process based on type ... */
}
```

### Unions for Type Punning and Register Access

```c
/* Access a 32-bit register as bytes, halfwords, or a full word */
typedef union {
    uint32_t word;
    uint16_t halfword[2];
    uint8_t  byte[4];
} reg32_t;

void union_demo(void)
{
    reg32_t data;
    data.word = 0xDEADBEEF;
    /* data.byte[0] = 0xEF (little-endian ARM) */
    /* data.byte[3] = 0xDE                     */
}

/* IEEE 754 floating-point bit inspection */
typedef union {
    float    f;
    uint32_t u;
    struct {
        uint32_t mantissa : 23;
        uint32_t exponent : 8;
        uint32_t sign     : 1;
    } bits;
} float_inspect_t;
```

### Bit-Fields for Hardware Registers

```c
typedef union {
    uint32_t raw;
    struct {
        uint32_t enable      : 1;   /* Bit 0     */
        uint32_t int_enable  : 1;   /* Bit 1     */
        uint32_t mode        : 2;   /* Bits 3:2  */
        uint32_t prescaler   : 4;   /* Bits 7:4  */
        uint32_t reserved    : 24;  /* Bits 31:8 */
    } fields;
} timer_ctrl_t;

void configure_timer(volatile timer_ctrl_t *ctrl)
{
    timer_ctrl_t val = { .raw = 0 };
    val.fields.enable     = 1;
    val.fields.int_enable = 1;
    val.fields.mode       = 2;     /* 0b10 = PWM mode */
    val.fields.prescaler  = 7;     /* Divide by 128   */
    ctrl->raw = val.raw;           /* Single atomic write */
}
```

> **Caution:** Bit-field ordering (MSB-first vs LSB-first) is compiler-dependent.
> Always verify with your target compiler. For maximum portability, use explicit
> shift-and-mask operations.

---

## 9. GPIO Programming

GPIO (General-Purpose Input/Output) is the simplest peripheral and the starting
point for embedded programming.

### LED Blink — The "Hello World" of Embedded

See [`examples/02_gpio/led_blink.c`](examples/02_gpio/led_blink.c) for the full
source.

```c
#include <stdint.h>

/* RCC (Reset and Clock Control) — must enable GPIO clock first */
#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))

/* GPIOA registers */
#define GPIOA_BASE      0x40020000U
#define GPIOA_MODER     (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_ODR       (*(volatile uint32_t *)(GPIOA_BASE + 0x14))

#define LED_PIN         5   /* PA5 on STM32 Nucleo boards */

void delay(volatile uint32_t count)
{
    while (count--) { }
}

int main(void)
{
    /* Step 1: Enable GPIOA clock */
    RCC_AHB1ENR |= (1 << 0);

    /* Step 2: Configure PA5 as output */
    GPIOA_MODER &= ~(3U << (LED_PIN * 2));   /* Clear mode bits  */
    GPIOA_MODER |=  (1U << (LED_PIN * 2));    /* Set to output    */

    /* Step 3: Toggle LED forever */
    while (1) {
        GPIOA_ODR ^= (1 << LED_PIN);         /* Toggle PA5       */
        delay(1000000);                        /* Simple busy-wait */
    }
}
```

### Button Input with Debouncing

See [`examples/02_gpio/button_debounce.c`](examples/02_gpio/button_debounce.c):

```c
#include <stdint.h>

#define GPIOC_BASE      0x40020800U
#define GPIOC_IDR       (*(volatile uint32_t *)(GPIOC_BASE + 0x10))
#define BUTTON_PIN      13  /* PC13 = User button on Nucleo */

#define DEBOUNCE_MS     50
#define SYSTICK_FREQ_HZ 1000

volatile uint32_t tick_count = 0;

uint32_t get_tick(void)
{
    return tick_count;
}

typedef enum {
    BTN_RELEASED = 0,
    BTN_PRESSED  = 1
} button_state_t;

button_state_t read_button_debounced(void)
{
    static button_state_t last_state = BTN_RELEASED;
    static uint32_t last_change_tick = 0;

    /* Button is active-low: pressed = 0, released = 1 */
    button_state_t raw = (GPIOC_IDR & (1 << BUTTON_PIN)) ? BTN_RELEASED : BTN_PRESSED;

    if (raw != last_state) {
        if ((get_tick() - last_change_tick) >= DEBOUNCE_MS) {
            last_state = raw;
            last_change_tick = get_tick();
        }
    }

    return last_state;
}
```

---

## 10. Interrupts and ISRs

### What Is an Interrupt?

An interrupt is a hardware signal that pauses normal program execution, runs a
special function (the **Interrupt Service Routine** or **ISR**), then resumes
normal execution. This is more efficient than polling because the CPU can do
useful work instead of busy-waiting.

```
Normal code          ISR                Normal code
executing    ──►  (hardware event)  ──►  resumes
    │                   │                   │
    ▼                   ▼                   ▼
  main()          EXTI0_IRQHandler()      main()
                  - save context
                  - handle event
                  - clear flag
                  - restore context
```

### NVIC (Nested Vectored Interrupt Controller)

The Cortex-M NVIC manages all interrupts:

```c
#include <stdint.h>

/* NVIC registers */
#define NVIC_BASE           0xE000E100U
#define NVIC_ISER0          (*(volatile uint32_t *)(NVIC_BASE + 0x00))  /* Enable  */
#define NVIC_ICER0          (*(volatile uint32_t *)(NVIC_BASE + 0x80))  /* Disable */
#define NVIC_ISPR0          (*(volatile uint32_t *)(NVIC_BASE + 0x100)) /* Pending */
#define NVIC_IPR_BASE       (NVIC_BASE + 0x300)                        /* Priority */

void nvic_enable_irq(uint8_t irq_num)
{
    /* Each ISER register covers 32 IRQs */
    volatile uint32_t *iser = (volatile uint32_t *)(NVIC_BASE + (irq_num / 32) * 4);
    *iser = (1U << (irq_num % 32));
}

void nvic_set_priority(uint8_t irq_num, uint8_t priority)
{
    volatile uint8_t *ipr = (volatile uint8_t *)(NVIC_IPR_BASE + irq_num);
    *ipr = (priority << 4);  /* Upper 4 bits on most Cortex-M */
}

void nvic_disable_irq(uint8_t irq_num)
{
    volatile uint32_t *icer = (volatile uint32_t *)(NVIC_BASE + 0x80 + (irq_num / 32) * 4);
    *icer = (1U << (irq_num % 32));
}
```

### ISR Best Practices

```c
volatile uint8_t  g_button_pressed = 0;
volatile uint32_t g_adc_value      = 0;

/* GOOD ISR: Short, sets a flag, clears the interrupt source */
void EXTI0_IRQHandler(void)
{
    if (EXTI->PR & (1 << 0)) {     /* Check pending bit  */
        EXTI->PR = (1 << 0);       /* Clear by writing 1 */
        g_button_pressed = 1;      /* Set flag for main   */
    }
}

/* BAD ISR: Doing too much work inside the interrupt */
void EXTI0_IRQHandler_BAD(void)
{
    /* DON'T: lengthy computation in ISR */
    process_complex_algorithm();

    /* DON'T: blocking calls */
    delay_ms(100);

    /* DON'T: printf (it's slow and may not be reentrant) */
    printf("Button pressed!\n");
}
```

### Critical Sections

When shared variables are accessed by both main code and ISRs, you must protect
against race conditions:

```c
/* Global interrupt disable/enable (Cortex-M intrinsics) */
static inline void enter_critical(void)
{
    __asm volatile ("cpsid i" ::: "memory");  /* Disable interrupts */
}

static inline void exit_critical(void)
{
    __asm volatile ("cpsie i" ::: "memory");  /* Enable interrupts */
}

/* Save and restore interrupt state (nested-safe) */
static inline uint32_t save_and_disable_irq(void)
{
    uint32_t primask;
    __asm volatile ("mrs %0, primask\n\t"
                    "cpsid i"
                    : "=r" (primask) :: "memory");
    return primask;
}

static inline void restore_irq(uint32_t primask)
{
    __asm volatile ("msr primask, %0" :: "r" (primask) : "memory");
}

/* Usage */
volatile uint32_t shared_counter = 0;

void increment_counter(void)
{
    uint32_t state = save_and_disable_irq();
    shared_counter++;
    restore_irq(state);
}
```

See [`examples/03_interrupts/`](examples/03_interrupts/) for complete examples.

---

## 11. Timer/Counter Programming

Timers are among the most versatile peripherals, used for:
- Generating precise time delays
- Measuring pulse widths and frequencies
- Generating PWM signals for motor control, LED dimming
- Triggering periodic interrupts (e.g., SysTick)

### SysTick Timer (Cortex-M System Timer)

Every Cortex-M has a built-in 24-bit countdown timer:

```c
#include <stdint.h>

#define SYSTICK_BASE    0xE000E010U
#define STK_CTRL        (*(volatile uint32_t *)(SYSTICK_BASE + 0x00))
#define STK_LOAD        (*(volatile uint32_t *)(SYSTICK_BASE + 0x04))
#define STK_VAL         (*(volatile uint32_t *)(SYSTICK_BASE + 0x08))

#define STK_CTRL_ENABLE     (1 << 0)
#define STK_CTRL_TICKINT    (1 << 1)
#define STK_CTRL_CLKSOURCE  (1 << 2)

volatile uint32_t systick_ms = 0;

void systick_init(uint32_t cpu_freq_hz)
{
    STK_LOAD = (cpu_freq_hz / 1000) - 1;   /* Reload for 1 ms tick */
    STK_VAL  = 0;                            /* Clear current value  */
    STK_CTRL = STK_CTRL_ENABLE | STK_CTRL_TICKINT | STK_CTRL_CLKSOURCE;
}

void SysTick_Handler(void)
{
    systick_ms++;
}

void delay_ms(uint32_t ms)
{
    uint32_t start = systick_ms;
    while ((systick_ms - start) < ms) {
        __asm volatile ("wfi");  /* Sleep until next interrupt */
    }
}

uint32_t millis(void)
{
    return systick_ms;
}
```

### PWM Generation

```c
#include <stdint.h>

typedef struct {
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t SMCR;
    volatile uint32_t DIER;
    volatile uint32_t SR;
    volatile uint32_t EGR;
    volatile uint32_t CCMR1;
    volatile uint32_t CCMR2;
    volatile uint32_t CCER;
    volatile uint32_t CNT;
    volatile uint32_t PSC;
    volatile uint32_t ARR;
    volatile uint32_t RESERVED1;
    volatile uint32_t CCR1;
    volatile uint32_t CCR2;
    volatile uint32_t CCR3;
    volatile uint32_t CCR4;
} TIM_TypeDef;

#define TIM2    ((TIM_TypeDef *)0x40000000U)

void pwm_init(uint32_t frequency_hz, uint8_t duty_percent)
{
    uint32_t sys_clk = 84000000;  /* 84 MHz APB1 timer clock */
    uint32_t arr_val = (sys_clk / frequency_hz) - 1;

    TIM2->PSC  = 0;                             /* No prescaler          */
    TIM2->ARR  = arr_val;                        /* Period                */
    TIM2->CCR1 = (arr_val * duty_percent) / 100; /* Duty cycle            */
    TIM2->CCMR1 = (6 << 4);                     /* PWM mode 1 on CH1    */
    TIM2->CCER  = (1 << 0);                     /* Enable CH1 output    */
    TIM2->CR1   = (1 << 0);                     /* Enable timer          */
}

void pwm_set_duty(uint8_t duty_percent)
{
    TIM2->CCR1 = (TIM2->ARR * duty_percent) / 100;
}
```

See [`examples/04_timers/`](examples/04_timers/) for complete timer examples.

---

## 12. UART Communication

UART (Universal Asynchronous Receiver/Transmitter) is the most common debug and
communication interface in embedded systems.

### UART Protocol Basics

```
    ┌──┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌──┐ ┌──┐
    │  │ │   │ │   │ │   │ │   │ │   │ │   │ │   │ │   │ │  │ │  │
────┘  └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘   └─┘  └─┘  └───
   START  D0    D1    D2    D3    D4    D5    D6    D7   PARITY STOP
    bit                   (LSB first)                    (opt)  bit
```

- **Idle line** is HIGH
- **Start bit** pulls LOW
- **Data bits** (typically 8) are sent LSB first
- **Stop bit(s)** return to HIGH

### Bare-Metal UART Driver

```c
#include <stdint.h>

typedef struct {
    volatile uint32_t SR;    /* Status register     */
    volatile uint32_t DR;    /* Data register       */
    volatile uint32_t BRR;   /* Baud rate register  */
    volatile uint32_t CR1;   /* Control register 1  */
    volatile uint32_t CR2;   /* Control register 2  */
    volatile uint32_t CR3;   /* Control register 3  */
    volatile uint32_t GTPR;  /* Guard time/prescaler */
} USART_TypeDef;

#define USART2  ((USART_TypeDef *)0x40004400U)

#define USART_SR_TXE    (1 << 7)   /* Transmit data register empty */
#define USART_SR_RXNE   (1 << 5)   /* Read data register not empty */
#define USART_SR_TC     (1 << 6)   /* Transmission complete        */
#define USART_CR1_UE    (1 << 13)  /* USART enable                 */
#define USART_CR1_TE    (1 << 3)   /* Transmitter enable           */
#define USART_CR1_RE    (1 << 2)   /* Receiver enable              */

void uart_init(uint32_t baud_rate)
{
    uint32_t pclk = 42000000;  /* APB1 clock = 42 MHz */

    /* Baud rate = pclk / (16 * USARTDIV) */
    uint32_t usart_div = pclk / baud_rate;
    USART2->BRR = usart_div;

    USART2->CR1 = USART_CR1_UE | USART_CR1_TE | USART_CR1_RE;
}

void uart_send_byte(uint8_t data)
{
    while (!(USART2->SR & USART_SR_TXE)) { }  /* Wait until TX empty */
    USART2->DR = data;
}

uint8_t uart_receive_byte(void)
{
    while (!(USART2->SR & USART_SR_RXNE)) { }  /* Wait until RX ready */
    return (uint8_t)(USART2->DR & 0xFF);
}

void uart_send_string(const char *str)
{
    while (*str) {
        uart_send_byte((uint8_t)*str++);
    }
}

/* Minimal printf-like function for debugging */
void uart_printf(const char *fmt, ...)
{
    char buf[128];
    va_list args;
    va_start(args, fmt);
    int len = vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);

    for (int i = 0; i < len; i++) {
        uart_send_byte((uint8_t)buf[i]);
    }
}
```

### Interrupt-Driven UART with Ring Buffer

See [`examples/05_uart/uart_irq.c`](examples/05_uart/uart_irq.c) for the complete
implementation using a ring buffer for non-blocking I/O.

---

## 13. SPI Communication

SPI (Serial Peripheral Interface) is a synchronous, full-duplex bus used for
high-speed communication with sensors, displays, SD cards, and Flash memory.

### SPI Signal Lines

```
            Master                      Slave
         ┌──────────┐              ┌──────────┐
         │     MOSI  ├─────────────►  MOSI     │   Master Out, Slave In
         │     MISO  ◄─────────────┤  MISO     │   Master In, Slave Out
         │     SCK   ├─────────────►  SCK      │   Serial Clock
         │     CS    ├─────────────►  CS       │   Chip Select (active LOW)
         └──────────┘              └──────────┘
```

### SPI Driver

```c
#include <stdint.h>

typedef struct {
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t CRCPR;
    volatile uint32_t RXCRCR;
    volatile uint32_t TXCRCR;
} SPI_TypeDef;

#define SPI1    ((SPI_TypeDef *)0x40013000U)

#define SPI_CR1_SPE     (1 << 6)    /* SPI enable           */
#define SPI_CR1_MSTR    (1 << 2)    /* Master mode          */
#define SPI_CR1_BR_DIV8 (2 << 3)    /* Baud = fPCLK / 8    */
#define SPI_CR1_CPOL    (1 << 1)    /* Clock polarity       */
#define SPI_CR1_CPHA    (1 << 0)    /* Clock phase          */
#define SPI_SR_TXE      (1 << 1)    /* TX buffer empty      */
#define SPI_SR_RXNE     (1 << 0)    /* RX buffer not empty  */
#define SPI_SR_BSY      (1 << 7)    /* Busy flag            */

void spi_init(void)
{
    SPI1->CR1 = SPI_CR1_MSTR        /* Master mode      */
              | SPI_CR1_BR_DIV8     /* Clock / 8        */
              | SPI_CR1_SPE;        /* Enable SPI       */
    /* CPOL=0, CPHA=0 → SPI Mode 0 (most common) */
}

uint8_t spi_transfer(uint8_t tx_data)
{
    while (!(SPI1->SR & SPI_SR_TXE)) { }   /* Wait for TX empty    */
    SPI1->DR = tx_data;                      /* Send byte            */
    while (!(SPI1->SR & SPI_SR_RXNE)) { }   /* Wait for RX complete */
    return (uint8_t)SPI1->DR;                /* Return received byte */
}

void spi_cs_low(void)
{
    GPIOA->ODR &= ~(1 << 4);   /* PA4 = CS LOW (select) */
}

void spi_cs_high(void)
{
    GPIOA->ODR |= (1 << 4);    /* PA4 = CS HIGH (deselect) */
}

/* Read a register from an SPI sensor (e.g., accelerometer) */
uint8_t spi_read_register(uint8_t reg_addr)
{
    uint8_t value;

    spi_cs_low();
    spi_transfer(reg_addr | 0x80);  /* Bit 7 = 1 for read */
    value = spi_transfer(0x00);     /* Dummy byte to clock data in */
    spi_cs_high();

    return value;
}
```

See [`examples/06_spi/`](examples/06_spi/) for complete SPI examples.

---

## 14. I2C Communication

I2C (Inter-Integrated Circuit) is a two-wire bus used for low-to-medium speed
communication with sensors, EEPROMs, and RTCs.

### I2C Bus Structure

```
             ┌──────┐     ┌──────┐     ┌──────┐
    VDD ─────┤ Rp   ├──┬──┤ Rp   ├──┬──┤      │
             └──┬───┘  │  └──┬───┘  │  │Master│
                │      │     │      │  │      │
    SDA ────────┴──────┼─────┼──────┼──┤ SDA  │
                       │     │      │  │      │
    SCL ───────────────┴─────┴──────┼──┤ SCL  │
                                    │  └──────┘
                           ┌────────┘
                           │
                    ┌──────┴──┐
                    │  Slave  │
                    │ (addr)  │
                    └─────────┘

    Rp = Pull-up resistors (typically 4.7kΩ)
```

### I2C Driver

```c
#include <stdint.h>

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

#define I2C1    ((I2C_TypeDef *)0x40005400U)

#define I2C_CR1_PE      (1 << 0)
#define I2C_CR1_START   (1 << 8)
#define I2C_CR1_STOP    (1 << 9)
#define I2C_CR1_ACK     (1 << 10)
#define I2C_SR1_SB      (1 << 0)   /* Start bit generated   */
#define I2C_SR1_ADDR    (1 << 1)   /* Address sent          */
#define I2C_SR1_TXE     (1 << 7)   /* Data register empty   */
#define I2C_SR1_RXNE    (1 << 6)   /* Data register not empty */

void i2c_init(void)
{
    uint32_t pclk = 42000000;  /* APB1 = 42 MHz */

    I2C1->CR2 = (pclk / 1000000);          /* Peripheral clock in MHz */
    I2C1->CCR = pclk / (2 * 100000);       /* 100 kHz standard mode   */
    I2C1->TRISE = (pclk / 1000000) + 1;    /* Max rise time           */
    I2C1->CR1 = I2C_CR1_PE;                /* Enable I2C              */
}

static void i2c_start(void)
{
    I2C1->CR1 |= I2C_CR1_START;
    while (!(I2C1->SR1 & I2C_SR1_SB)) { }
}

static void i2c_stop(void)
{
    I2C1->CR1 |= I2C_CR1_STOP;
}

static void i2c_send_address(uint8_t addr, uint8_t rw)
{
    I2C1->DR = (addr << 1) | rw;
    while (!(I2C1->SR1 & I2C_SR1_ADDR)) { }
    (void)I2C1->SR2;  /* Clear ADDR flag by reading SR2 */
}

void i2c_write(uint8_t dev_addr, uint8_t reg, uint8_t data)
{
    i2c_start();
    i2c_send_address(dev_addr, 0);   /* Write mode */

    I2C1->DR = reg;
    while (!(I2C1->SR1 & I2C_SR1_TXE)) { }

    I2C1->DR = data;
    while (!(I2C1->SR1 & I2C_SR1_TXE)) { }

    i2c_stop();
}

uint8_t i2c_read(uint8_t dev_addr, uint8_t reg)
{
    uint8_t data;

    /* Send register address (write phase) */
    i2c_start();
    i2c_send_address(dev_addr, 0);
    I2C1->DR = reg;
    while (!(I2C1->SR1 & I2C_SR1_TXE)) { }

    /* Repeated start + read */
    i2c_start();
    i2c_send_address(dev_addr, 1);   /* Read mode */

    I2C1->CR1 &= ~I2C_CR1_ACK;      /* NACK after 1 byte */
    while (!(I2C1->SR1 & I2C_SR1_RXNE)) { }
    data = (uint8_t)I2C1->DR;

    i2c_stop();
    return data;
}
```

See [`examples/07_i2c/`](examples/07_i2c/) for a complete I2C temperature sensor
example.

---

## 15. ADC Programming

The ADC (Analog-to-Digital Converter) converts continuous analog voltages to
discrete digital values.

### ADC Concepts

```
                      Analog Input
    3.3V  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐
                                    │    12-bit ADC
    0V    ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤    Resolution: 3.3V / 4096 ≈ 0.8 mV
                                    │
              ADC Value = (Vin / Vref) × (2^N - 1)
              Vin = ADC_Value × Vref / (2^N - 1)

    Example: 12-bit, Vref = 3.3V
             ADC reads 2048 → Vin = 2048 × 3.3 / 4095 ≈ 1.65V
```

### ADC Driver

```c
#include <stdint.h>

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

#define ADC1    ((ADC_TypeDef *)0x40012000U)

#define ADC_CR2_ADON    (1 << 0)
#define ADC_CR2_SWSTART (1 << 30)
#define ADC_SR_EOC      (1 << 1)

void adc_init(void)
{
    ADC1->CR2 = ADC_CR2_ADON;          /* Power on ADC */
    ADC1->SMPR2 = (7 << 0);            /* 480 cycles sample time for ch0 */
    ADC1->SQR3 = 0;                    /* Channel 0 in first position */
    ADC1->SQR1 = 0;                    /* 1 conversion in sequence */
}

uint16_t adc_read(uint8_t channel)
{
    ADC1->SQR3 = channel;              /* Select channel */
    ADC1->CR2 |= ADC_CR2_SWSTART;     /* Start conversion */
    while (!(ADC1->SR & ADC_SR_EOC)) { }  /* Wait for completion */
    return (uint16_t)ADC1->DR;
}

/* Convert raw ADC value to millivolts */
uint32_t adc_to_millivolts(uint16_t adc_val)
{
    return ((uint32_t)adc_val * 3300) / 4095;
}

/* Read temperature from internal sensor (channel 16 on STM32F4) */
int32_t read_internal_temp_celsius(void)
{
    uint16_t raw = adc_read(16);
    int32_t temp_mv = (int32_t)adc_to_millivolts(raw);
    /* V_sense = 0.76V at 25°C, slope = 2.5 mV/°C */
    return ((temp_mv - 760) * 10 / 25) + 25;
}
```

See [`examples/08_adc/`](examples/08_adc/) for a multi-channel ADC with averaging.

---

## 16. DMA (Direct Memory Access)

DMA transfers data between memory and peripherals **without CPU intervention**,
freeing the processor for other tasks.

### DMA Concept

```
Without DMA:                        With DMA:
CPU reads peripheral → stores       CPU sets up DMA → DMA handles transfers
to memory, repeat N times           CPU does other work
                                    DMA signals completion via interrupt

CPU Utilization: ~100% during       CPU Utilization: ~0% during transfer
                 transfer
```

### DMA Configuration for UART TX

```c
#include <stdint.h>

typedef struct {
    volatile uint32_t CR;       /* Configuration         */
    volatile uint32_t NDTR;     /* Number of data items  */
    volatile uint32_t PAR;      /* Peripheral address    */
    volatile uint32_t M0AR;     /* Memory 0 address      */
    volatile uint32_t M1AR;     /* Memory 1 address      */
    volatile uint32_t FCR;      /* FIFO control          */
} DMA_Stream_TypeDef;

#define DMA1_BASE       0x40026000U
#define DMA1_Stream6    ((DMA_Stream_TypeDef *)(DMA1_BASE + 0x10 + 6 * 0x18))

#define DMA_CR_EN       (1 << 0)
#define DMA_CR_TCIE     (1 << 4)    /* Transfer complete interrupt  */
#define DMA_CR_DIR_M2P  (1 << 6)    /* Memory-to-peripheral         */
#define DMA_CR_MINC     (1 << 10)   /* Memory increment mode        */
#define DMA_CR_CHSEL(n) ((n) << 25) /* Channel selection            */

void dma_uart_tx(const uint8_t *data, uint16_t length)
{
    DMA1_Stream6->CR &= ~DMA_CR_EN;             /* Disable stream        */
    while (DMA1_Stream6->CR & DMA_CR_EN) { }    /* Wait until disabled   */

    DMA1_Stream6->PAR  = (uint32_t)&USART2->DR; /* Destination: UART DR  */
    DMA1_Stream6->M0AR = (uint32_t)data;         /* Source: memory buffer */
    DMA1_Stream6->NDTR = length;                 /* Number of bytes       */

    DMA1_Stream6->CR = DMA_CR_CHSEL(4)  /* Channel 4 = USART2_TX */
                     | DMA_CR_DIR_M2P   /* Memory → Peripheral   */
                     | DMA_CR_MINC      /* Increment memory addr  */
                     | DMA_CR_TCIE;     /* Interrupt on complete   */

    USART2->CR3 |= (1 << 7);           /* USART2 DMA TX enable   */
    DMA1_Stream6->CR |= DMA_CR_EN;     /* Start transfer         */
}

volatile uint8_t dma_tx_complete = 0;

void DMA1_Stream6_IRQHandler(void)
{
    /* Clear transfer complete flag */
    *(volatile uint32_t *)(DMA1_BASE + 0x14) = (1 << 21);
    dma_tx_complete = 1;
}
```

See [`examples/09_dma/`](examples/09_dma/) for complete DMA examples.

---

## 17. Watchdog Timers

A watchdog timer resets the microcontroller if software hangs or enters an
infinite loop. It must be periodically "fed" (refreshed) to prevent reset.

```c
#include <stdint.h>

typedef struct {
    volatile uint32_t KR;     /* Key register      */
    volatile uint32_t PR;     /* Prescaler         */
    volatile uint32_t RLR;    /* Reload register   */
    volatile uint32_t SR;     /* Status            */
} IWDG_TypeDef;

#define IWDG    ((IWDG_TypeDef *)0x40003000U)

#define IWDG_KEY_ENABLE     0xCCCC
#define IWDG_KEY_WRITE      0x5555
#define IWDG_KEY_REFRESH    0xAAAA

void watchdog_init(uint32_t timeout_ms)
{
    IWDG->KR = IWDG_KEY_ENABLE;    /* Start IWDG               */
    IWDG->KR = IWDG_KEY_WRITE;     /* Enable register writes    */
    IWDG->PR = 4;                   /* Prescaler /64 → 500 Hz   */

    uint32_t reload = (timeout_ms * 500) / 1000;
    if (reload > 0xFFF) reload = 0xFFF;
    IWDG->RLR = reload;

    while (IWDG->SR) { }           /* Wait for registers to update */
    IWDG->KR = IWDG_KEY_REFRESH;   /* Feed the watchdog            */
}

void watchdog_feed(void)
{
    IWDG->KR = IWDG_KEY_REFRESH;
}

/* Main loop pattern with watchdog */
int main(void)
{
    system_init();
    watchdog_init(1000);  /* 1-second timeout */

    while (1) {
        read_sensors();
        process_data();
        update_outputs();
        watchdog_feed();  /* Must reach this line within 1 second */
    }
}
```

See [`examples/14_watchdog/`](examples/14_watchdog/) for the complete example.

---

## 18. Low-Power Modes

Battery-powered devices must minimize power consumption. ARM Cortex-M provides
several sleep modes:

| Mode | CPU | Peripherals | SRAM | Wake-up Sources | Current |
|------|-----|------------|------|-----------------|---------|
| Run | Active | Active | Active | N/A | ~10-100 mA |
| Sleep | Stopped | Active | Active | Any interrupt | ~1-10 mA |
| Stop | Stopped | Stopped* | Active | EXTI, RTC | ~10-100 µA |
| Standby | Stopped | Stopped | Lost | Wakeup pin, RTC | ~1-5 µA |

*Some peripherals can remain active in Stop mode

```c
#include <stdint.h>

#define SCB_SCR     (*(volatile uint32_t *)0xE000ED10)
#define PWR_BASE    0x40007000U
#define PWR_CR      (*(volatile uint32_t *)(PWR_BASE + 0x00))
#define PWR_CSR     (*(volatile uint32_t *)(PWR_BASE + 0x04))

void enter_sleep_mode(void)
{
    SCB_SCR &= ~(1 << 2);    /* Clear SLEEPDEEP → Sleep (not Stop) */
    __asm volatile ("wfi");   /* Wait For Interrupt                 */
}

void enter_stop_mode(void)
{
    SCB_SCR |= (1 << 2);     /* Set SLEEPDEEP → Stop mode          */
    PWR_CR  |= (1 << 1);     /* PDDS=0, LPDS=1 → low-power regulator */
    PWR_CR  &= ~(1 << 1);    /* Clear PDDS for Stop (not Standby)  */
    __asm volatile ("wfi");   /* Enter Stop mode                    */

    /* After wakeup: reconfigure clocks (HSI is running, PLL is off) */
    system_clock_config();
}

void enter_standby_mode(void)
{
    SCB_SCR |= (1 << 2);     /* SLEEPDEEP                           */
    PWR_CR  |= (1 << 1);     /* PDDS=1 → Standby mode              */
    PWR_CR  |= (1 << 2);     /* Clear wakeup flag                   */
    __asm volatile ("wfi");   /* Enter Standby                       */
    /* After wakeup: full reset, execution starts from Reset_Handler */
}

/* Periodic wakeup pattern for sensor node */
void low_power_sensor_loop(void)
{
    while (1) {
        uint16_t temp = read_temperature();
        transmit_data(temp);

        configure_rtc_wakeup(60);  /* Wake up in 60 seconds */
        enter_stop_mode();
    }
}
```

See [`examples/11_low_power/`](examples/11_low_power/) for complete low-power
examples.

---

## 19. RTOS Fundamentals

An RTOS (Real-Time Operating System) provides multitasking for embedded systems.
Popular choices include FreeRTOS, Zephyr, and ThreadX.

### Why Use an RTOS?

| Bare-Metal (Super Loop) | RTOS |
|--------------------------|------|
| Single `while(1)` loop | Multiple concurrent tasks |
| Flag-based scheduling | Priority-based preemption |
| Blocking delays stall everything | Blocking in one task doesn't affect others |
| Simple, low overhead | Adds ~5-15 KB Flash, ~1-2 KB RAM |
| Best for simple systems | Best for complex, multi-function systems |

### FreeRTOS Example

```c
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

/* Shared resources */
QueueHandle_t       sensor_queue;
SemaphoreHandle_t   uart_mutex;

/* Task 1: Read sensor data periodically */
void sensor_task(void *params)
{
    (void)params;
    TickType_t last_wake = xTaskGetTickCount();

    while (1) {
        uint16_t reading = adc_read(0);

        /* Send reading to processing task via queue */
        xQueueSend(sensor_queue, &reading, portMAX_DELAY);

        /* Execute exactly every 100 ms regardless of execution time */
        vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(100));
    }
}

/* Task 2: Process and display data */
void display_task(void *params)
{
    (void)params;
    uint16_t reading;

    while (1) {
        /* Block until data is available */
        if (xQueueReceive(sensor_queue, &reading, portMAX_DELAY) == pdTRUE) {
            uint32_t voltage_mv = (reading * 3300) / 4095;

            /* Protect UART access with a mutex */
            xSemaphoreTake(uart_mutex, portMAX_DELAY);
            uart_printf("Voltage: %lu mV\r\n", voltage_mv);
            xSemaphoreGive(uart_mutex);
        }
    }
}

/* Task 3: Blink LED (heartbeat) */
void heartbeat_task(void *params)
{
    (void)params;

    while (1) {
        led_toggle();
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

int main(void)
{
    system_init();

    sensor_queue = xQueueCreate(10, sizeof(uint16_t));
    uart_mutex   = xSemaphoreCreateMutex();

    xTaskCreate(sensor_task,    "Sensor",    256, NULL, 3, NULL);
    xTaskCreate(display_task,   "Display",   512, NULL, 2, NULL);
    xTaskCreate(heartbeat_task, "Heartbeat", 128, NULL, 1, NULL);

    vTaskStartScheduler();

    while (1) { }  /* Should never reach here */
}
```

### RTOS Synchronization Primitives

```c
/* ---- Binary Semaphore (for signaling between ISR and task) ---- */
SemaphoreHandle_t data_ready_sem;

void ADC_IRQHandler(void)
{
    BaseType_t higher_priority_woken = pdFALSE;
    xSemaphoreGiveFromISR(data_ready_sem, &higher_priority_woken);
    portYIELD_FROM_ISR(higher_priority_woken);
}

void processing_task(void *params)
{
    (void)params;
    while (1) {
        xSemaphoreTake(data_ready_sem, portMAX_DELAY);
        process_adc_data();
    }
}

/* ---- Mutex (for protecting shared resources) ---- */
SemaphoreHandle_t spi_mutex;

void task_a(void *params)
{
    (void)params;
    while (1) {
        xSemaphoreTake(spi_mutex, portMAX_DELAY);
        spi_transfer_data(buffer_a, sizeof(buffer_a));
        xSemaphoreGive(spi_mutex);
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

/* ---- Event Groups (for multi-condition synchronization) ---- */
#include "event_groups.h"
EventGroupHandle_t system_events;

#define EVT_SENSOR_READY  (1 << 0)
#define EVT_GPS_READY     (1 << 1)
#define EVT_ALL_READY     (EVT_SENSOR_READY | EVT_GPS_READY)

void logger_task(void *params)
{
    (void)params;
    while (1) {
        /* Wait for BOTH events to be set */
        xEventGroupWaitBits(system_events, EVT_ALL_READY,
                           pdTRUE,   /* Clear bits on exit */
                           pdTRUE,   /* Wait for ALL bits  */
                           portMAX_DELAY);
        log_data_to_sdcard();
    }
}
```

See [`examples/10_rtos/`](examples/10_rtos/) for a complete multi-task example.

---

## 20. Common Data Structures

### Ring Buffer (Circular Buffer)

The ring buffer is the **most important data structure in embedded systems**. It's
used in every UART driver, DMA buffer, audio pipeline, and data logger.

```c
#include <stdint.h>
#include <stdbool.h>

#define RING_BUF_SIZE   256  /* Must be a power of 2 for masking trick */

typedef struct {
    uint8_t  buffer[RING_BUF_SIZE];
    volatile uint16_t head;  /* Write index (producer) */
    volatile uint16_t tail;  /* Read index (consumer)  */
} ring_buffer_t;

void ring_buf_init(ring_buffer_t *rb)
{
    rb->head = 0;
    rb->tail = 0;
}

bool ring_buf_is_empty(const ring_buffer_t *rb)
{
    return (rb->head == rb->tail);
}

bool ring_buf_is_full(const ring_buffer_t *rb)
{
    return (((rb->head + 1) & (RING_BUF_SIZE - 1)) == rb->tail);
}

uint16_t ring_buf_count(const ring_buffer_t *rb)
{
    return (rb->head - rb->tail) & (RING_BUF_SIZE - 1);
}

bool ring_buf_put(ring_buffer_t *rb, uint8_t data)
{
    if (ring_buf_is_full(rb)) {
        return false;
    }
    rb->buffer[rb->head] = data;
    rb->head = (rb->head + 1) & (RING_BUF_SIZE - 1);
    return true;
}

bool ring_buf_get(ring_buffer_t *rb, uint8_t *data)
{
    if (ring_buf_is_empty(rb)) {
        return false;
    }
    *data = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) & (RING_BUF_SIZE - 1);
    return true;
}
```

### Fixed-Point Arithmetic

When hardware floating-point is unavailable (Cortex-M0) or too slow, use
fixed-point math:

```c
#include <stdint.h>

/* Q16.16 fixed-point: 16 integer bits, 16 fractional bits */
typedef int32_t fixed16_t;

#define FIXED16_SHIFT   16
#define FIXED16_ONE     (1 << FIXED16_SHIFT)     /* 1.0 = 0x00010000 */

#define FLOAT_TO_FIXED(f)  ((fixed16_t)((f) * FIXED16_ONE))
#define FIXED_TO_FLOAT(x)  ((float)(x) / FIXED16_ONE)
#define INT_TO_FIXED(i)    ((fixed16_t)(i) << FIXED16_SHIFT)
#define FIXED_TO_INT(x)    ((int)(x) >> FIXED16_SHIFT)

fixed16_t fixed_mul(fixed16_t a, fixed16_t b)
{
    return (fixed16_t)(((int64_t)a * b) >> FIXED16_SHIFT);
}

fixed16_t fixed_div(fixed16_t a, fixed16_t b)
{
    return (fixed16_t)(((int64_t)a << FIXED16_SHIFT) / b);
}

/* Example: PID controller using fixed-point */
typedef struct {
    fixed16_t kp, ki, kd;
    fixed16_t integral;
    fixed16_t prev_error;
} pid_controller_t;

fixed16_t pid_update(pid_controller_t *pid, fixed16_t setpoint, fixed16_t measurement)
{
    fixed16_t error = setpoint - measurement;
    pid->integral += error;
    fixed16_t derivative = error - pid->prev_error;
    pid->prev_error = error;

    return fixed_mul(pid->kp, error)
         + fixed_mul(pid->ki, pid->integral)
         + fixed_mul(pid->kd, derivative);
}
```

See [`examples/13_ring_buffer/`](examples/13_ring_buffer/) for a complete ring
buffer implementation.

---

## 21. State Machine Design

State machines are the backbone of embedded control logic — from parsing protocols
to controlling motor sequences.

### Table-Driven State Machine

```c
#include <stdint.h>
#include <stdbool.h>

/* Traffic light controller */
typedef enum {
    STATE_RED,
    STATE_RED_YELLOW,
    STATE_GREEN,
    STATE_YELLOW,
    STATE_COUNT
} traffic_state_t;

typedef enum {
    EVT_TIMER_EXPIRED,
    EVT_EMERGENCY,
    EVT_RESET,
    EVT_COUNT
} traffic_event_t;

typedef struct {
    traffic_state_t next_state;
    void (*action)(void);
} transition_t;

/* Action functions */
static void set_red(void)        { /* Set red LED on     */ }
static void set_red_yellow(void) { /* Set red+yellow on  */ }
static void set_green(void)      { /* Set green LED on   */ }
static void set_yellow(void)     { /* Set yellow LED on  */ }
static void emergency_stop(void) { /* All red, flash     */ }

/* State transition table */
static const transition_t state_table[STATE_COUNT][EVT_COUNT] = {
    /*                  TIMER_EXPIRED              EMERGENCY                 RESET          */
    [STATE_RED]       = {{ STATE_RED_YELLOW, set_red_yellow }, { STATE_RED, emergency_stop }, { STATE_RED, set_red }},
    [STATE_RED_YELLOW]= {{ STATE_GREEN,      set_green      }, { STATE_RED, emergency_stop }, { STATE_RED, set_red }},
    [STATE_GREEN]     = {{ STATE_YELLOW,     set_yellow     }, { STATE_RED, emergency_stop }, { STATE_RED, set_red }},
    [STATE_YELLOW]    = {{ STATE_RED,        set_red        }, { STATE_RED, emergency_stop }, { STATE_RED, set_red }},
};

static traffic_state_t current_state = STATE_RED;

void traffic_fsm_process(traffic_event_t event)
{
    const transition_t *t = &state_table[current_state][event];
    if (t->action) {
        t->action();
    }
    current_state = t->next_state;
}
```

### Hierarchical State Machine (for complex systems)

```c
typedef enum {
    MOTOR_STATE_IDLE,
    MOTOR_STATE_STARTING,
    MOTOR_STATE_RUNNING,
    MOTOR_STATE_STOPPING,
    MOTOR_STATE_FAULT
} motor_state_t;

typedef enum {
    MOTOR_EVT_START,
    MOTOR_EVT_STOP,
    MOTOR_EVT_SPEED_OK,
    MOTOR_EVT_OVERCURRENT,
    MOTOR_EVT_TIMEOUT,
    MOTOR_EVT_RESET
} motor_event_t;

typedef struct {
    motor_state_t state;
    uint32_t      entry_time;
    uint16_t      current_rpm;
    uint8_t       retry_count;
} motor_context_t;

void motor_fsm(motor_context_t *ctx, motor_event_t event)
{
    switch (ctx->state) {
    case MOTOR_STATE_IDLE:
        if (event == MOTOR_EVT_START) {
            pwm_start(10);  /* 10% duty = soft start */
            ctx->entry_time = millis();
            ctx->state = MOTOR_STATE_STARTING;
        }
        break;

    case MOTOR_STATE_STARTING:
        if (event == MOTOR_EVT_SPEED_OK) {
            ctx->state = MOTOR_STATE_RUNNING;
        } else if (event == MOTOR_EVT_TIMEOUT) {
            ctx->retry_count++;
            if (ctx->retry_count >= 3) {
                pwm_stop();
                ctx->state = MOTOR_STATE_FAULT;
            } else {
                pwm_stop();
                ctx->state = MOTOR_STATE_IDLE;
            }
        } else if (event == MOTOR_EVT_OVERCURRENT) {
            pwm_stop();
            ctx->state = MOTOR_STATE_FAULT;
        }
        break;

    case MOTOR_STATE_RUNNING:
        if (event == MOTOR_EVT_STOP) {
            pwm_set_duty(0);
            ctx->entry_time = millis();
            ctx->state = MOTOR_STATE_STOPPING;
        } else if (event == MOTOR_EVT_OVERCURRENT) {
            pwm_stop();
            ctx->state = MOTOR_STATE_FAULT;
        }
        break;

    case MOTOR_STATE_STOPPING:
        if (event == MOTOR_EVT_SPEED_OK && ctx->current_rpm == 0) {
            pwm_stop();
            ctx->state = MOTOR_STATE_IDLE;
        } else if (event == MOTOR_EVT_TIMEOUT) {
            pwm_stop();
            ctx->state = MOTOR_STATE_IDLE;
        }
        break;

    case MOTOR_STATE_FAULT:
        if (event == MOTOR_EVT_RESET) {
            ctx->retry_count = 0;
            ctx->state = MOTOR_STATE_IDLE;
        }
        break;
    }
}
```

See [`examples/12_state_machine/`](examples/12_state_machine/) for the complete
implementation.

---

## 22. Bootloader Basics

A bootloader allows firmware updates in the field without a hardware debugger.

### Memory Layout with Bootloader

```
Flash Memory Layout
┌─────────────────────┐  0x0800_0000
│    Bootloader       │
│    (16 KB)          │
│  - Receives new FW  │
│  - Validates CRC    │
│  - Jumps to App     │
├─────────────────────┤  0x0800_4000
│    Application      │
│    (up to 496 KB)   │
│                     │
│  - Main firmware    │
│  - Has own vector   │
│    table            │
└─────────────────────┘  0x0808_0000
```

### Minimal Bootloader

```c
#include <stdint.h>

#define APP_START_ADDRESS   0x08004000U

typedef void (*app_entry_t)(void);

uint32_t calculate_crc(const uint8_t *data, uint32_t length)
{
    uint32_t crc = 0xFFFFFFFF;
    for (uint32_t i = 0; i < length; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
        }
    }
    return ~crc;
}

void jump_to_application(void)
{
    uint32_t *app_vector = (uint32_t *)APP_START_ADDRESS;

    /* Validate: first word should be a valid stack pointer (in SRAM range) */
    if ((app_vector[0] & 0x2FFE0000) != 0x20000000) {
        return;  /* Invalid application */
    }

    /* Disable all interrupts */
    __asm volatile ("cpsid i");

    /* Set the vector table offset to the application */
    *(volatile uint32_t *)0xE000ED08 = APP_START_ADDRESS;

    /* Set stack pointer and jump */
    __asm volatile (
        "msr msp, %0\n\t"   /* Set main stack pointer */
        "bx  %1"             /* Branch to app Reset_Handler */
        :: "r" (app_vector[0]), "r" (app_vector[1])
    );
}

int main(void)
{
    system_init();
    uart_init(115200);

    /* Check if firmware update is requested (e.g., button held during boot) */
    if (is_update_requested()) {
        uart_send_string("Bootloader: Waiting for firmware...\r\n");
        receive_and_flash_firmware();
    }

    uart_send_string("Bootloader: Jumping to application...\r\n");
    jump_to_application();

    while (1) { } /* Should never reach here */
}
```

See [`examples/15_bootloader/`](examples/15_bootloader/) for the complete
bootloader implementation.

---

## 23. Debugging Techniques

### SWD/JTAG Debugging

```bash
# Start OpenOCD for STM32F4
openocd -f interface/stlink-v2.cfg -f target/stm32f4x.cfg

# In another terminal, connect GDB
arm-none-eabi-gdb firmware.elf
(gdb) target remote localhost:3333
(gdb) monitor reset halt
(gdb) load
(gdb) break main
(gdb) continue
```

### Printf Debugging via UART

```c
#define DEBUG_LEVEL 2  /* 0=off, 1=error, 2=warn, 3=info, 4=debug */

#if DEBUG_LEVEL >= 1
    #define LOG_ERROR(fmt, ...) uart_printf("[ERR] " fmt "\r\n", ##__VA_ARGS__)
#else
    #define LOG_ERROR(fmt, ...) ((void)0)
#endif

#if DEBUG_LEVEL >= 3
    #define LOG_INFO(fmt, ...)  uart_printf("[INF] " fmt "\r\n", ##__VA_ARGS__)
#else
    #define LOG_INFO(fmt, ...)  ((void)0)
#endif

#if DEBUG_LEVEL >= 4
    #define LOG_DEBUG(fmt, ...) uart_printf("[DBG] %s:%d " fmt "\r\n", \
                                            __FILE__, __LINE__, ##__VA_ARGS__)
#else
    #define LOG_DEBUG(fmt, ...) ((void)0)
#endif
```

### Assert for Embedded

```c
#ifdef DEBUG
    #define ASSERT(expr) do { \
        if (!(expr)) { \
            uart_printf("ASSERT FAIL: %s at %s:%d\r\n", #expr, __FILE__, __LINE__); \
            __asm volatile ("bkpt #0");  /* Trigger breakpoint if debugger attached */ \
            while (1) { }  /* Halt */ \
        } \
    } while (0)
#else
    #define ASSERT(expr) ((void)0)
#endif

void spi_write(uint8_t *buf, uint16_t len)
{
    ASSERT(buf != NULL);
    ASSERT(len > 0 && len <= 256);
    /* ... */
}
```

### HardFault Debugging

```c
void HardFault_Handler(void)
{
    volatile uint32_t *stack;
    __asm volatile ("mrs %0, msp" : "=r" (stack));

    volatile uint32_t r0  = stack[0];
    volatile uint32_t r1  = stack[1];
    volatile uint32_t r2  = stack[2];
    volatile uint32_t r3  = stack[3];
    volatile uint32_t r12 = stack[4];
    volatile uint32_t lr  = stack[5];  /* Link register          */
    volatile uint32_t pc  = stack[6];  /* Program counter (fault address) */
    volatile uint32_t psr = stack[7];

    (void)r0; (void)r1; (void)r2; (void)r3;
    (void)r12; (void)lr; (void)pc; (void)psr;

    uart_printf("HardFault!\r\n");
    uart_printf("  PC=0x%08X  LR=0x%08X\r\n", pc, lr);
    uart_printf("  R0=0x%08X  R1=0x%08X\r\n", r0, r1);

    __asm volatile ("bkpt #0");
    while (1) { }
}
```

---

## 24. Best Practices

### Coding Standards

1. **Use MISRA-C** or a similar standard for safety-critical code.
2. **Always initialize variables** — uninitialized reads are undefined behavior.
3. **Use `stdint.h` types** — never use bare `int` for hardware-related code.
4. **Mark ISR-shared variables `volatile`** — the #1 embedded C bug.
5. **Keep ISRs short** — set a flag, defer work to the main loop or a task.
6. **Avoid dynamic allocation** — `malloc`/`free` fragment limited memory and are
   non-deterministic.

### Memory Safety

```c
/* GOOD: Bounded buffer operations */
void safe_copy(char *dst, const char *src, size_t dst_size)
{
    size_t i;
    for (i = 0; i < dst_size - 1 && src[i] != '\0'; i++) {
        dst[i] = src[i];
    }
    dst[i] = '\0';
}

/* GOOD: Array bounds checking */
#define ARRAY_SIZE(arr)  (sizeof(arr) / sizeof((arr)[0]))

void process_readings(const uint16_t *data, uint16_t count)
{
    uint16_t buffer[64];
    uint16_t n = (count < ARRAY_SIZE(buffer)) ? count : ARRAY_SIZE(buffer);

    for (uint16_t i = 0; i < n; i++) {
        buffer[i] = data[i];
    }
}
```

### Power Efficiency

```c
/* BAD: Busy-wait wastes power */
while (!data_ready) { }

/* GOOD: Sleep until interrupt */
while (!data_ready) {
    __asm volatile ("wfi");
}
```

### Defensive Programming

```c
/* Default case in switch statements */
switch (state) {
case STATE_IDLE:    handle_idle();    break;
case STATE_ACTIVE:  handle_active();  break;
case STATE_ERROR:   handle_error();   break;
default:
    /* Should never reach here — indicates corruption */
    log_error("Invalid state: %d", state);
    state = STATE_IDLE;
    break;
}

/* Check return values */
if (uart_send(data, len) != STATUS_OK) {
    error_count++;
    if (error_count > MAX_RETRIES) {
        enter_safe_state();
    }
}
```

---

## Repository Structure

```
.
├── README.md                           ← This guide
├── examples/
│   ├── 01_basics/
│   │   ├── data_types.c                ← Fixed-width types and sizeof
│   │   ├── bit_manipulation.c          ← Bit operations and macros
│   │   └── preprocessor.c             ← Preprocessor patterns
│   ├── 02_gpio/
│   │   ├── led_blink.c                ← LED blink (Hello World)
│   │   └── button_debounce.c          ← Button input with debouncing
│   ├── 03_interrupts/
│   │   ├── external_interrupt.c        ← EXTI button interrupt
│   │   └── critical_section.c         ← Protecting shared data
│   ├── 04_timers/
│   │   ├── systick.c                  ← SysTick millisecond timer
│   │   └── pwm.c                      ← PWM generation with TIM2
│   ├── 05_uart/
│   │   ├── uart_polling.c             ← Simple polling UART
│   │   └── uart_irq.c                ← Interrupt-driven UART + ring buffer
│   ├── 06_spi/
│   │   └── spi_master.c              ← SPI master driver
│   ├── 07_i2c/
│   │   └── i2c_temp_sensor.c          ← I2C temperature sensor
│   ├── 08_adc/
│   │   └── adc_multichannel.c         ← Multi-channel ADC with averaging
│   ├── 09_dma/
│   │   └── dma_uart_tx.c             ← DMA-accelerated UART transmission
│   ├── 10_rtos/
│   │   └── freertos_multitask.c       ← FreeRTOS multi-task example
│   ├── 11_low_power/
│   │   └── sleep_modes.c             ← Sleep/Stop/Standby modes
│   ├── 12_state_machine/
│   │   └── traffic_light_fsm.c        ← Table-driven state machine
│   ├── 13_ring_buffer/
│   │   ├── ring_buffer.h             ← Ring buffer header
│   │   └── ring_buffer.c             ← Ring buffer implementation
│   ├── 14_watchdog/
│   │   └── iwdg.c                    ← Independent watchdog timer
│   └── 15_bootloader/
│       └── bootloader.c              ← Minimal UART bootloader
└── Makefile                           ← Build system for examples
```

---

## Further Reading

- **ARM Cortex-M Architecture:** [ARM Developer Documentation](https://developer.arm.com/documentation)
- **STM32 Reference Manuals:** [ST Microelectronics](https://www.st.com/en/microcontrollers-microprocessors/stm32-32-bit-arm-cortex-mcus.html)
- **FreeRTOS:** [freertos.org](https://www.freertos.org/)
- **MISRA-C:2012:** Guidelines for safety-critical C code
- **Making Embedded Systems** by Elecia White (O'Reilly)
- **The Definitive Guide to ARM Cortex-M3 and Cortex-M4 Processors** by Joseph Yiu

---

*This guide targets ARM Cortex-M (STM32F4). Register addresses and peripheral details
vary by chip — always consult your specific microcontroller's reference manual.*
