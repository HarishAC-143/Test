# Chapter 1: Embedded C Basics

## 1.1 What Makes Embedded C Different?

Standard C runs on general-purpose operating systems with virtual memory, standard I/O, and dynamic memory management. Embedded C operates in a fundamentally different environment:

| Aspect | Standard C | Embedded C |
|--------|-----------|------------|
| Memory | Virtual, abundant | Physical, constrained (KB–MB) |
| OS | Full OS with scheduler | Bare-metal or lightweight RTOS |
| I/O | `printf`, file I/O | Direct hardware register access |
| Timing | Non-deterministic | Hard real-time requirements |
| Power | Always on | Battery-powered, low-power modes |

## 1.2 Data Types for Embedded Systems

### Fixed-Width Integer Types

In embedded programming, you must know the exact size of your data types. The `<stdint.h>` header provides fixed-width integers:

```c
#include <stdint.h>

uint8_t   sensor_reading;    // Exactly 8 bits, unsigned (0–255)
int8_t    temperature;       // Exactly 8 bits, signed (-128 to 127)
uint16_t  adc_value;         // Exactly 16 bits, unsigned (0–65535)
int16_t   position;          // Exactly 16 bits, signed
uint32_t  system_tick;       // Exactly 32 bits, unsigned
int32_t   encoder_count;     // Exactly 32 bits, signed
```

**Why fixed-width types matter**: On a 16-bit microcontroller, `int` is 16 bits. On a 32-bit ARM, `int` is 32 bits. Using `uint16_t` guarantees 16 bits regardless of architecture.

### The `volatile` Qualifier

The `volatile` keyword is one of the most important concepts in embedded C. It tells the compiler that a variable's value may change at any time — due to hardware, interrupts, or other threads — and must not be optimized away.

```c
// WITHOUT volatile — compiler may optimize away repeated reads
uint32_t *status_reg = (uint32_t *)0x40000000;
while (*status_reg & 0x01) {
    // Compiler might read status_reg only once and cache the value,
    // creating an infinite loop even after hardware clears the bit
}

// WITH volatile — compiler re-reads from hardware every iteration
volatile uint32_t *status_reg = (volatile uint32_t *)0x40000000;
while (*status_reg & 0x01) {
    // Compiler generates a fresh load instruction each iteration
}
```

**When to use `volatile`**:
- Memory-mapped hardware registers
- Variables modified by interrupt service routines (ISRs)
- Variables shared between tasks in an RTOS
- Variables modified by DMA

### The `const` Qualifier

In embedded systems, `const` places data in Flash (ROM) instead of RAM, saving precious SRAM:

```c
// Stored in Flash — saves RAM
const uint8_t lookup_table[256] = { 0, 1, 1, 2, 1, 2, 2, 3, /* ... */ };

// Stored in RAM — consumes SRAM
uint8_t mutable_buffer[256];
```

### Combining `volatile` and `const`

A read-only hardware register that changes on its own:

```c
// "const" means we cannot write to it; "volatile" means the hardware can change it
const volatile uint32_t *hw_timer = (const volatile uint32_t *)0x40001000;

uint32_t timestamp = *hw_timer;  // Read the current timer value
// *hw_timer = 0;                // Compiler error — we declared it const
```

## 1.3 Memory-Mapped I/O and Register Access

Microcontrollers expose their peripherals through memory-mapped registers. Each register has a fixed address defined in the MCU datasheet.

### Direct Address Access

```c
// Define register addresses (from the MCU datasheet)
#define GPIOA_BASE      0x40020000
#define GPIOA_MODER     (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_ODR       (*(volatile uint32_t *)(GPIOA_BASE + 0x14))
#define GPIOA_IDR       (*(volatile uint32_t *)(GPIOA_BASE + 0x10))

// Set pin 5 as output (each pin uses 2 bits in MODER)
GPIOA_MODER |= (1 << 10);   // Set bit 10
GPIOA_MODER &= ~(1 << 11);  // Clear bit 11

// Set pin 5 high
GPIOA_ODR |= (1 << 5);

// Read pin 3 state
uint32_t pin3_state = (GPIOA_IDR >> 3) & 0x01;
```

### Structure-Based Register Access

A more readable approach uses C structs that mirror the register layout:

```c
typedef struct {
    volatile uint32_t MODER;    // Offset 0x00: Mode register
    volatile uint32_t OTYPER;   // Offset 0x04: Output type
    volatile uint32_t OSPEEDR;  // Offset 0x08: Output speed
    volatile uint32_t PUPDR;    // Offset 0x0C: Pull-up/pull-down
    volatile uint32_t IDR;      // Offset 0x10: Input data
    volatile uint32_t ODR;      // Offset 0x14: Output data
    volatile uint32_t BSRR;     // Offset 0x18: Bit set/reset
    volatile uint32_t LCKR;     // Offset 0x1C: Lock
    volatile uint32_t AFR[2];   // Offset 0x20: Alternate function
} GPIO_TypeDef;

#define GPIOA ((GPIO_TypeDef *)0x40020000)
#define GPIOB ((GPIO_TypeDef *)0x40020400)

// Now we can use struct syntax
GPIOA->MODER |= (1 << 10);
GPIOA->ODR   |= (1 << 5);
```

## 1.4 Bitwise Operations

Bitwise operations are the bread and butter of embedded programming. They let you manipulate individual bits in registers without affecting others.

### The Core Operations

| Operation | Syntax | Purpose |
|-----------|--------|---------|
| Set a bit | `reg \|= (1 << n)` | Turn bit `n` ON |
| Clear a bit | `reg &= ~(1 << n)` | Turn bit `n` OFF |
| Toggle a bit | `reg ^= (1 << n)` | Flip bit `n` |
| Check a bit | `if (reg & (1 << n))` | Test if bit `n` is set |

### Bit Field Macros

```c
// Set a multi-bit field: clear old value, then OR in new value
#define SET_FIELD(reg, mask, shift, value) \
    do { (reg) = ((reg) & ~(mask)) | (((value) << (shift)) & (mask)); } while(0)

// Read a multi-bit field
#define GET_FIELD(reg, mask, shift) \
    (((reg) & (mask)) >> (shift))

// Example: Timer prescaler is bits [15:8]
#define PRESCALER_MASK  0xFF00
#define PRESCALER_SHIFT 8

SET_FIELD(TIMER->CR, PRESCALER_MASK, PRESCALER_SHIFT, 128);
uint8_t prescaler = GET_FIELD(TIMER->CR, PRESCALER_MASK, PRESCALER_SHIFT);
```

### Bit Banding (ARM Cortex-M)

ARM Cortex-M processors support "bit banding" — mapping each bit to a unique 32-bit address so you can atomically set/clear individual bits:

```c
#define BITBAND_SRAM(addr, bit) \
    (*(volatile uint32_t *)(0x22000000 + ((((uint32_t)(addr)) - 0x20000000) * 32) + ((bit) * 4)))

#define BITBAND_PERIPH(addr, bit) \
    (*(volatile uint32_t *)(0x42000000 + ((((uint32_t)(addr)) - 0x40000000) * 32) + ((bit) * 4)))

// Atomically set bit 5 of GPIOA ODR without read-modify-write
BITBAND_PERIPH(&GPIOA->ODR, 5) = 1;
```

## 1.5 GPIO (General-Purpose Input/Output)

GPIO is the most fundamental peripheral. Every embedded project starts with blinking an LED.

### Typical GPIO Configuration Steps

1. **Enable the peripheral clock** (the GPIO port must be powered on)
2. **Set the pin direction** (input or output)
3. **Configure pull-up/pull-down resistors** (for inputs)
4. **Set output type** (push-pull or open-drain)
5. **Read or write the pin**

```c
// Step 1: Enable GPIOA clock
RCC->AHB1ENR |= (1 << 0);

// Step 2: Set pin 5 as general-purpose output
GPIOA->MODER &= ~(3 << 10);  // Clear bits [11:10]
GPIOA->MODER |=  (1 << 10);  // Set to 01 (output mode)

// Step 3: No pull-up/pull-down
GPIOA->PUPDR &= ~(3 << 10);

// Step 4: Push-pull output
GPIOA->OTYPER &= ~(1 << 5);

// Step 5: Toggle the LED
while (1) {
    GPIOA->ODR ^= (1 << 5);  // Toggle pin 5
    delay_ms(500);
}
```

## 1.6 Startup Code and Memory Layout

When an embedded system powers on, it doesn't jump straight into `main()`. The startup sequence looks like this:

```
Power-On → Reset Vector → Startup Code → main()
```

### The Vector Table

The very first thing in Flash memory is the vector table — an array of function pointers:

```c
typedef void (*vector_fn)(void);

__attribute__((section(".isr_vector")))
const vector_fn vector_table[] = {
    (vector_fn)&_estack,       // Initial stack pointer
    Reset_Handler,             // Reset handler — entry point
    NMI_Handler,               // Non-maskable interrupt
    HardFault_Handler,         // Hard fault
    // ... more exception/interrupt vectors
};
```

### Linker Script Memory Layout

A typical embedded memory map:

```
Flash (ROM):          RAM (SRAM):
┌──────────────┐     ┌──────────────┐
│ Vector Table │     │    .data     │  ← Initialized globals (copied from Flash)
├──────────────┤     ├──────────────┤
│    .text     │     │    .bss      │  ← Zero-initialized globals
│  (code)      │     ├──────────────┤
├──────────────┤     │    Heap ↓    │
│   .rodata    │     │              │
│  (constants) │     │              │
├──────────────┤     │   Stack ↑    │
│  .data init  │     └──────────────┘
│  values      │
└──────────────┘
```

### Startup Code Responsibilities

```c
void Reset_Handler(void) {
    // 1. Copy .data section from Flash to RAM
    uint32_t *src = &_sidata;  // Start of .data in Flash
    uint32_t *dst = &_sdata;   // Start of .data in RAM
    while (dst < &_edata) {
        *dst++ = *src++;
    }

    // 2. Zero-fill the .bss section
    dst = &_sbss;
    while (dst < &_ebss) {
        *dst++ = 0;
    }

    // 3. (Optional) Initialize the FPU, clocks, etc.

    // 4. Call main
    main();

    // 5. If main returns, hang
    while (1);
}
```

## Summary

| Concept | Key Takeaway |
|---------|-------------|
| Fixed-width types | Always use `uint8_t`, `uint16_t`, etc. for predictable sizes |
| `volatile` | Required for hardware registers and ISR-shared variables |
| `const` | Places data in Flash, saving RAM |
| Register access | Use struct overlays for readability and maintainability |
| Bitwise ops | Master set, clear, toggle, and test operations |
| GPIO | The fundamental building block — always start here |
| Startup code | Understand what happens before `main()` |

**Next**: [Chapter 2 — Intermediate Topics](02_intermediate.md)
