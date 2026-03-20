# Chapter 3: Bit Manipulation

Bit manipulation is the bread and butter of embedded C programming. Every hardware register is a collection of individual bits or bit-fields, each controlling a different function. Mastering these operations is non-negotiable.

## The Six Bitwise Operators

| Operator | Name | Description |
|----------|------|-------------|
| `&` | AND | Both bits must be 1 |
| `\|` | OR | Either bit must be 1 |
| `^` | XOR | Bits must differ |
| `~` | NOT | Invert all bits |
| `<<` | Left Shift | Shift bits left (multiply by 2) |
| `>>` | Right Shift | Shift bits right (divide by 2) |

## The Four Fundamental Bit Operations

### 1. Set a Bit (Force to 1)

Use OR with a mask:

```c
register_value |= (1 << bit_position);
```

**Example:** Set bit 5 of `GPIOA_ODR` to turn on an LED:

```c
GPIOA_ODR |= (1 << 5);
```

How it works:

```
  GPIOA_ODR:   xxxx xxxx xx0x xxxx   (bit 5 is 0)
  (1 << 5):    0000 0000 0010 0000   (mask with only bit 5 set)
  OR result:   xxxx xxxx xx1x xxxx   (bit 5 is now 1, others unchanged)
```

### 2. Clear a Bit (Force to 0)

Use AND with the inverted mask:

```c
register_value &= ~(1 << bit_position);
```

**Example:** Clear bit 5 to turn off the LED:

```c
GPIOA_ODR &= ~(1 << 5);
```

How it works:

```
  GPIOA_ODR:   xxxx xxxx xx1x xxxx   (bit 5 is 1)
  ~(1 << 5):   1111 1111 1101 1111   (all 1s except bit 5)
  AND result:  xxxx xxxx xx0x xxxx   (bit 5 cleared, others unchanged)
```

### 3. Toggle a Bit (Flip)

Use XOR with a mask:

```c
register_value ^= (1 << bit_position);
```

**Example:** Toggle the LED:

```c
GPIOA_ODR ^= (1 << 5);
```

### 4. Test a Bit (Read)

Use AND to isolate the bit:

```c
if (register_value & (1 << bit_position)) {
    /* Bit is set (1) */
}
```

**Example:** Check if the button is pressed (bit 13):

```c
if (GPIOC_IDR & (1 << 13)) {
    /* Button is not pressed (active-low) */
}
```

## Working with Multi-Bit Fields

Hardware registers often have multi-bit fields. For example, GPIO mode registers use 2 bits per pin:

```
Bits [1:0]   → Pin 0 mode
Bits [3:2]   → Pin 1 mode
Bits [5:4]   → Pin 2 mode
...
Bits [11:10] → Pin 5 mode
```

### Clear a Multi-Bit Field

```c
/* Clear bits [11:10] (pin 5 mode field) */
GPIOA_MODER &= ~(0x3 << 10);   /* 0x3 = 0b11 = two-bit mask */
```

### Set a Multi-Bit Field

First clear, then set:

```c
/* Set pin 5 to mode 01 (general-purpose output) */
GPIOA_MODER &= ~(0x3 << 10);   /* Clear the field first */
GPIOA_MODER |=  (0x1 << 10);   /* Set desired value */
```

### A Cleaner Pattern: Clear-and-Set in One Step

```c
reg = (reg & ~(MASK << SHIFT)) | (VALUE << SHIFT);
```

**Example:**

```c
GPIOA_MODER = (GPIOA_MODER & ~(0x3 << 10)) | (0x1 << 10);
```

## Common Bit Manipulation Macros

Define these once and reuse everywhere:

```c
#define BIT_SET(reg, bit)       ((reg) |=  (1U << (bit)))
#define BIT_CLEAR(reg, bit)     ((reg) &= ~(1U << (bit)))
#define BIT_TOGGLE(reg, bit)    ((reg) ^=  (1U << (bit)))
#define BIT_CHECK(reg, bit)     ((reg) &   (1U << (bit)))

#define BITS_SET(reg, mask)     ((reg) |=  (mask))
#define BITS_CLEAR(reg, mask)   ((reg) &= ~(mask))

/* Set a multi-bit field */
#define FIELD_SET(reg, mask, shift, val) \
    ((reg) = ((reg) & ~((mask) << (shift))) | ((val) << (shift)))
```

Usage:

```c
BIT_SET(GPIOA_ODR, 5);          /* Turn on LED */
BIT_CLEAR(GPIOA_ODR, 5);        /* Turn off LED */
BIT_TOGGLE(GPIOA_ODR, 5);       /* Toggle LED */

if (BIT_CHECK(GPIOC_IDR, 13)) { /* Test button */
    /* ... */
}

FIELD_SET(GPIOA_MODER, 0x3, 10, 0x1);  /* Pin 5 → output mode */
```

## Practical Bit Manipulation Patterns

### Counting Set Bits (Population Count)

```c
uint8_t count_bits(uint32_t value)
{
    uint8_t count = 0;
    while (value) {
        count += value & 1;
        value >>= 1;
    }
    return count;
}
```

A faster approach using Brian Kernighan's trick:

```c
uint8_t count_bits_fast(uint32_t value)
{
    uint8_t count = 0;
    while (value) {
        value &= (value - 1);  /* Clears the lowest set bit */
        count++;
    }
    return count;
}
```

### Checking if a Value Is a Power of Two

```c
bool is_power_of_two(uint32_t value)
{
    return value && !(value & (value - 1));
}
```

### Extracting a Byte from a 32-Bit Value

```c
uint8_t byte0 = (uint8_t)(value & 0xFF);          /* Bits [7:0]   */
uint8_t byte1 = (uint8_t)((value >> 8) & 0xFF);   /* Bits [15:8]  */
uint8_t byte2 = (uint8_t)((value >> 16) & 0xFF);  /* Bits [23:16] */
uint8_t byte3 = (uint8_t)((value >> 24) & 0xFF);  /* Bits [31:24] */
```

### Building a 32-Bit Value from Bytes

```c
uint32_t value = ((uint32_t)byte3 << 24) |
                 ((uint32_t)byte2 << 16) |
                 ((uint32_t)byte1 << 8)  |
                 ((uint32_t)byte0);
```

## Common Pitfalls

### 1. Shifting by the Type Width

```c
uint8_t x = 1;
x << 8;  /* UNDEFINED BEHAVIOR — shifting by the width of the type */
```

### 2. Signed Right Shift

Right-shifting a signed negative number is implementation-defined:

```c
int8_t x = -4;
x >> 1;  /* Might be -2 (arithmetic shift) or 126 (logical shift) */
```

**Rule:** Always use **unsigned types** for bit manipulation.

### 3. Forgetting `1U`

On a 16-bit platform:

```c
1 << 15   /* Implementation-defined: may produce a negative int */
1U << 15  /* Well-defined: produces 0x8000 as unsigned */
```

Always write `1U << n` instead of `1 << n`.

## Practical Example

See [`examples/01_basics/bit_manipulation.c`](../examples/01_basics/bit_manipulation.c) for a runnable demonstration.

## Summary

- **Set:** `reg |= (1U << bit)`
- **Clear:** `reg &= ~(1U << bit)`
- **Toggle:** `reg ^= (1U << bit)`
- **Test:** `if (reg & (1U << bit))`
- Define macros for these operations and use them consistently.
- Always use unsigned types for bit operations.

---

**Next:** [Chapter 4 — Pointers and Memory-Mapped I/O](04-pointers-and-memory-mapped-io.md)
