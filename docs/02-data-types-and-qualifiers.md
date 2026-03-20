# Chapter 2: Data Types and Qualifiers

In embedded systems, every byte of RAM matters and every variable's behavior must be precisely controlled. This chapter covers the data types and qualifiers that are essential for writing correct, efficient embedded code.

## Fixed-Width Integer Types

Standard C types like `int` and `long` have platform-dependent sizes. In embedded C, we use **fixed-width types** from `<stdint.h>` to guarantee exact sizes:

```c
#include <stdint.h>

uint8_t  sensor_id;      /* Exactly 8 bits, unsigned  (0 to 255) */
int8_t   temperature;    /* Exactly 8 bits, signed    (-128 to 127) */
uint16_t adc_value;      /* Exactly 16 bits, unsigned (0 to 65535) */
int16_t  motor_speed;    /* Exactly 16 bits, signed */
uint32_t timestamp;      /* Exactly 32 bits, unsigned */
int32_t  encoder_count;  /* Exactly 32 bits, signed */
```

### Why Fixed-Width Types Matter

Consider a protocol that sends a 16-bit value over UART. If you use `int`, it might be 16 bits on an AVR but 32 bits on an ARM — your code silently breaks. Using `uint16_t` guarantees the same size everywhere.

### Minimum-Width and Fast Types

`<stdint.h>` also provides:

```c
uint_least8_t  x;  /* At least 8 bits — guaranteed to exist */
uint_fast8_t   y;  /* At least 8 bits — fastest type of that width */
```

`uint_fast8_t` may be 32 bits on a 32-bit ARM to avoid byte-access penalties.

## The `volatile` Qualifier

**`volatile` is the single most important qualifier in embedded C.** It tells the compiler: "This variable can change at any time outside the current code flow — do not optimize accesses to it."

### When to Use `volatile`

1. **Hardware registers** (memory-mapped I/O)
2. **Variables modified by interrupt service routines (ISRs)**
3. **Variables modified by DMA**
4. **Variables shared between threads in an RTOS**

### Example: Without `volatile` (Bug!)

```c
#define STATUS_REG (*(uint32_t *)0x40001000)

void wait_for_ready(void)
{
    while ((STATUS_REG & 0x01) == 0)
        ;  /* Wait for bit 0 to be set by hardware */
}
```

The compiler sees that `STATUS_REG` is never modified inside the loop. With optimization enabled (`-O2`), it reads the register **once**, caches the value in a CPU register, and loops forever — the program hangs.

### Example: With `volatile` (Correct)

```c
#define STATUS_REG (*(volatile uint32_t *)0x40001000)

void wait_for_ready(void)
{
    while ((STATUS_REG & 0x01) == 0)
        ;  /* Compiler re-reads the register every iteration */
}
```

Now the compiler generates a load instruction on every loop iteration.

### `volatile` with ISR-Shared Variables

```c
volatile uint8_t data_ready = 0;

/* Interrupt handler — called by hardware */
void USART1_IRQHandler(void)
{
    received_byte = USART1->DR;
    data_ready = 1;
}

/* Main loop */
int main(void)
{
    while (1) {
        if (data_ready) {
            process(received_byte);
            data_ready = 0;
        }
    }
}
```

Without `volatile`, the compiler may optimize `data_ready` into a register and never see the ISR's write.

## The `const` Qualifier

`const` in embedded C serves two purposes:

### 1. Preventing Accidental Modification

```c
const uint32_t BAUD_RATE = 115200;
```

### 2. Placing Data in Flash (Read-Only Memory)

On most embedded targets, `const` global data is stored in Flash rather than RAM. This is critical when RAM is scarce:

```c
/* Stored in Flash — saves RAM */
const uint8_t sine_table[256] = {
    128, 131, 134, 137, 140, 143, 146, 149,
    /* ... 248 more entries ... */
};

/* Stored in RAM — wastes precious memory */
uint8_t other_table[256] = { /* ... */ };
```

### Combining `const` and `volatile`

A read-only hardware register is both `const` (your code must not write to it) and `volatile` (its value can change due to hardware):

```c
#define ADC_DATA (*(const volatile uint16_t *)0x4001204C)

uint16_t reading = ADC_DATA;  /* OK: read */
/* ADC_DATA = 0;              ERROR: write to const */
```

## The `static` Qualifier

`static` has two distinct meanings depending on where it is used:

### 1. File Scope — Internal Linkage

A `static` global variable or function is **private to the file** it is declared in:

```c
/* gpio.c */
static uint8_t pin_states = 0;  /* Not visible outside gpio.c */

static void configure_pin(uint8_t pin)  /* Internal helper */
{
    /* ... */
}

void gpio_init(void)  /* Public API */
{
    configure_pin(5);
}
```

This is how you achieve **encapsulation** in C — critical for maintaining large firmware projects.

### 2. Function Scope — Persistent Local Variable

A `static` local variable retains its value between function calls:

```c
uint32_t get_tick_count(void)
{
    static uint32_t ticks = 0;  /* Initialized once, persists forever */
    return ticks++;
}
```

## The `register` Keyword

`register` suggests the compiler keep a variable in a CPU register for faster access. In modern embedded compilers, this is almost always ignored — the optimizer makes better decisions than the programmer. It is mentioned here only because you may encounter it in legacy code.

## The `extern` Keyword

`extern` declares a variable or function that is **defined in another file**:

```c
/* main.c */
extern volatile uint32_t system_ticks;  /* Defined in systick.c */
```

## Choosing the Right Data Type

| Data Width Needed | Unsigned Type | Signed Type | Typical Use |
|-------------------|---------------|-------------|-------------|
| 1 bit             | Use bit manipulation | — | Single flags |
| 8 bits            | `uint8_t` | `int8_t` | Byte buffers, GPIO states |
| 16 bits           | `uint16_t` | `int16_t` | ADC values, PWM duty |
| 32 bits           | `uint32_t` | `int32_t` | Timestamps, register access |
| Boolean           | `#include <stdbool.h>` → `bool` | — | Flags |

**Rule of thumb:** Use the **smallest type** that fits your data range to minimize RAM usage, but be aware that on 32-bit ARMs, smaller types may incur sign/zero-extension overhead.

## Practical Example

See [`examples/01_basics/data_types.c`](../examples/01_basics/data_types.c) for a runnable demonstration of these concepts.

## Summary

- Always use `<stdint.h>` fixed-width types in embedded code.
- Mark hardware registers and ISR-shared variables as `volatile`.
- Use `const` to save RAM by keeping data in Flash.
- Use `static` for encapsulation and persistent local state.
- Choose the smallest data type that fits your requirements.

---

**Next:** [Chapter 3 — Bit Manipulation](03-bit-manipulation.md)
