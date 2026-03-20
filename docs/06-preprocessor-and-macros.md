# Chapter 6: Preprocessor and Macros

The C preprocessor is heavily used in embedded development for hardware abstraction, compile-time configuration, conditional compilation, and generic utilities. Mastering it is essential for writing portable, maintainable firmware.

## Header Guards

Every header file must have include guards to prevent double inclusion:

```c
#ifndef UART_DRIVER_H
#define UART_DRIVER_H

/* Header contents */

#endif /* UART_DRIVER_H */
```

Or the non-standard but widely supported:

```c
#pragma once
```

## Object-Like Macros

### Hardware Register Definitions

```c
#define PERIPH_BASE       0x40000000U
#define AHB1_BASE         (PERIPH_BASE + 0x00020000U)
#define GPIOA_BASE        (AHB1_BASE + 0x0000U)
#define GPIOB_BASE        (AHB1_BASE + 0x0400U)

#define GPIOA_MODER       (*(volatile uint32_t *)(GPIOA_BASE + 0x00U))
#define GPIOA_ODR         (*(volatile uint32_t *)(GPIOA_BASE + 0x14U))
```

### Configuration Constants

```c
#define SYSTEM_CLOCK_HZ   168000000U
#define UART_BAUD_RATE    115200U
#define ADC_RESOLUTION    12
#define MAX_SENSORS       8
#define BUFFER_SIZE       256
```

### Bit Positions and Masks

```c
#define USART_SR_TXE      (1U << 7)
#define USART_SR_RXNE     (1U << 5)
#define USART_SR_TC       (1U << 6)

#define GPIO_MODE_INPUT   0x00U
#define GPIO_MODE_OUTPUT  0x01U
#define GPIO_MODE_AF      0x02U
#define GPIO_MODE_ANALOG  0x03U
```

## Function-Like Macros

### Basic Utility Macros

```c
#define MIN(a, b)         (((a) < (b)) ? (a) : (b))
#define MAX(a, b)         (((a) > (b)) ? (a) : (b))
#define ABS(x)            (((x) < 0) ? -(x) : (x))
#define CLAMP(x, lo, hi)  (MIN(MAX(x, lo), hi))

#define ARRAY_SIZE(arr)   (sizeof(arr) / sizeof((arr)[0]))
```

**Always parenthesize every parameter and the entire expression** to avoid operator-precedence bugs:

```c
/* BAD — will produce wrong results with expressions like MIN(a+1, b) */
#define BAD_MIN(a, b)  a < b ? a : b

/* GOOD */
#define MIN(a, b)  (((a) < (b)) ? (a) : (b))
```

### Bit Manipulation Macros

```c
#define BIT(n)              (1U << (n))
#define BIT_SET(reg, n)     ((reg) |= BIT(n))
#define BIT_CLEAR(reg, n)   ((reg) &= ~BIT(n))
#define BIT_TOGGLE(reg, n)  ((reg) ^= BIT(n))
#define BIT_READ(reg, n)    (((reg) >> (n)) & 1U)
```

### Multi-Statement Macros

Use the `do { ... } while(0)` idiom so the macro works correctly in `if/else`:

```c
#define LED_ON(port, pin) do {       \
    (port)->BSRR = (1U << (pin));    \
} while (0)

#define LED_OFF(port, pin) do {      \
    (port)->BSRR = (1U << ((pin) + 16)); \
} while (0)
```

Why `do { ... } while(0)`? Without it:

```c
if (condition)
    LED_ON(GPIOA, 5);   /* This breaks if the macro expands to two statements */
else
    LED_OFF(GPIOA, 5);
```

## Conditional Compilation

### Feature Toggles

```c
#define USE_DMA       1
#define USE_RTOS      0
#define DEBUG_ENABLED 1

void uart_send(const uint8_t *data, uint32_t len)
{
#if USE_DMA
    dma_start_transfer(UART_TX_DMA, data, len);
#else
    for (uint32_t i = 0; i < len; i++) {
        while (!(USART1->SR & USART_SR_TXE))
            ;
        USART1->DR = data[i];
    }
#endif
}
```

### Debug Logging

```c
#ifdef DEBUG_ENABLED
    #define DBG_PRINT(fmt, ...) printf("[DBG] " fmt "\n", ##__VA_ARGS__)
#else
    #define DBG_PRINT(fmt, ...) ((void)0)
#endif
```

The `##__VA_ARGS__` syntax (a GCC extension, standardized in C23 as `__VA_OPT__`) removes the trailing comma when no extra arguments are passed:

```c
DBG_PRINT("System initialized");          /* No extra args — comma removed */
DBG_PRINT("Sensor value: %d", reading);   /* With extra args */
```

### Platform/Target Selection

```c
#if defined(STM32F407xx)
    #include "stm32f4xx.h"
    #define LED_PORT  GPIOD
    #define LED_PIN   12
#elif defined(STM32F103xB)
    #include "stm32f1xx.h"
    #define LED_PORT  GPIOC
    #define LED_PIN   13
#elif defined(__AVR_ATmega328P__)
    #include <avr/io.h>
    #define LED_PORT  PORTB
    #define LED_PIN   5
#else
    #error "Unsupported target platform"
#endif
```

## The `#error` and `#warning` Directives

Force a compilation error or warning:

```c
#ifndef SYSTEM_CLOCK_HZ
    #error "SYSTEM_CLOCK_HZ must be defined"
#endif

#if BUFFER_SIZE < 64
    #warning "Buffer size is very small — may cause data loss"
#endif
```

## The Stringify and Token-Pasting Operators

### `#` — Stringify

Convert a macro argument to a string literal:

```c
#define ASSERT(expr) do {                                   \
    if (!(expr)) {                                          \
        error_handler("Assertion failed: " #expr,           \
                      __FILE__, __LINE__);                   \
    }                                                       \
} while (0)

ASSERT(buffer != NULL);
/* Expands to: if (!(buffer != NULL)) error_handler("Assertion failed: buffer != NULL", ...) */
```

### `##` — Token Pasting

Concatenate tokens to form new identifiers:

```c
#define GPIO_CLOCK_ENABLE(port) (RCC->AHB1ENR |= RCC_AHB1ENR_GPIO##port##EN))

GPIO_CLOCK_ENABLE(A);  /* Expands to: RCC->AHB1ENR |= RCC_AHB1ENR_GPIOAEN */
GPIO_CLOCK_ENABLE(B);  /* Expands to: RCC->AHB1ENR |= RCC_AHB1ENR_GPIOBEN */
```

## Predefined Macros Useful in Embedded C

| Macro | Description |
|-------|-------------|
| `__FILE__` | Current source file name |
| `__LINE__` | Current line number |
| `__func__` | Current function name (C99) |
| `__DATE__` | Compilation date |
| `__TIME__` | Compilation time |
| `__COUNTER__` | Monotonically increasing counter (GCC/Clang) |

Build version strings:

```c
const char build_info[] = "Built: " __DATE__ " " __TIME__;
```

## Compile-Time Assertions

Verify assumptions at compile time with zero runtime cost:

```c
/* C11 _Static_assert */
_Static_assert(sizeof(uint32_t) == 4, "uint32_t must be 4 bytes");

/* Pre-C11 trick */
#define STATIC_ASSERT(cond, msg) \
    typedef char static_assert_##msg[(cond) ? 1 : -1]

STATIC_ASSERT(sizeof(GPIO_TypeDef) == 40, gpio_struct_size_mismatch);
```

## X-Macros: Advanced Code Generation

X-macros generate repetitive code from a single definition list:

```c
/* Define all error codes in one place */
#define ERROR_LIST(X) \
    X(ERR_NONE,       0, "No error")           \
    X(ERR_TIMEOUT,    1, "Operation timed out") \
    X(ERR_OVERFLOW,   2, "Buffer overflow")     \
    X(ERR_CHECKSUM,   3, "Checksum mismatch")

/* Generate the enum */
#define GENERATE_ENUM(name, code, str) name = code,
typedef enum {
    ERROR_LIST(GENERATE_ENUM)
} ErrorCode;

/* Generate the string lookup */
#define GENERATE_STRING(name, code, str) [code] = str,
const char *error_strings[] = {
    ERROR_LIST(GENERATE_STRING)
};

/* Generate the name lookup */
#define GENERATE_NAME(name, code, str) [code] = #name,
const char *error_names[] = {
    ERROR_LIST(GENERATE_NAME)
};
```

Now adding a new error code requires changing only one line in `ERROR_LIST`.

## Common Pitfalls

### 1. Multiple Evaluation

```c
#define MAX(a, b) (((a) > (b)) ? (a) : (b))

int x = MAX(i++, j++);  /* BUG: i or j incremented twice! */
```

For critical macros, use GCC's statement expression extension:

```c
#define MAX(a, b) ({         \
    __typeof__(a) _a = (a);  \
    __typeof__(b) _b = (b);  \
    _a > _b ? _a : _b;      \
})
```

Or simply use `static inline` functions in C99+.

### 2. Missing Parentheses

```c
#define SQUARE(x) x * x
int result = SQUARE(2 + 3);  /* Expands to: 2 + 3 * 2 + 3 = 11, not 25! */

#define SQUARE(x) ((x) * (x))  /* Correct */
```

### 3. Semicolons in Macros

```c
#define INIT_PORT(p) setup(p);  /* Trailing semicolon */

if (use_port_a)
    INIT_PORT(A);  /* Expands to: if (use_port_a) setup(A);; — harmless */
else               /* ERROR: else without matching if (due to extra ;) */
    INIT_PORT(B);
```

Use the `do { ... } while(0)` idiom to avoid this.

## When to Use Macros vs. Inline Functions

| Feature | Macros | `static inline` Functions |
|---------|--------|---------------------------|
| Type safety | None | Full |
| Debugging | Hard (no symbols) | Normal |
| Multiple evaluation | Risk | Safe |
| Type-generic | Yes | No (without `_Generic`) |
| Compile-time string/token manipulation | Yes | No |

**Rule of thumb:** Prefer `static inline` functions for anything that behaves like a function. Use macros for compile-time configuration, string manipulation, and code generation.

## Summary

- Use header guards in every `.h` file.
- Use object-like macros for constants, register addresses, and bit masks.
- Use function-like macros carefully — parenthesize everything.
- Use conditional compilation for platform selection and feature toggles.
- Use `do { ... } while(0)` for multi-statement macros.
- Prefer `static inline` over function-like macros when possible.
- X-macros are a powerful pattern for generating repetitive code.

---

**Next:** [Chapter 7 — GPIO Programming](07-gpio-programming.md)
