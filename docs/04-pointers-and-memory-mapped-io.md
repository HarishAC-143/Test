# Chapter 4: Pointers and Memory-Mapped I/O

Pointers are arguably the most powerful feature of C. In embedded systems, they become indispensable — they are the mechanism through which your code talks to hardware.

## Memory-Mapped I/O: The Big Idea

In most microcontrollers, hardware peripherals (GPIO, UART, timers, etc.) are controlled through **registers** that appear at fixed addresses in the processor's memory space. Reading from or writing to these addresses controls the hardware.

This is called **memory-mapped I/O** — the same load/store instructions used for RAM also access peripheral registers.

```
CPU → address bus → memory controller → {
    if address in 0x20000000–0x2001FFFF → SRAM
    if address in 0x40000000–0x40007FFF → APB1 peripherals (UART, I2C, ...)
    if address in 0x40010000–0x40014BFF → APB2 peripherals (GPIO, SPI, ...)
}
```

## Accessing a Single Register

The most basic pattern — cast an integer address to a `volatile` pointer:

```c
/* Define the register as a dereferenced pointer to a volatile uint32_t */
#define GPIOA_ODR (*(volatile uint32_t *)0x40020014)

/* Now use it like a variable */
GPIOA_ODR = 0x00000020;          /* Write: turn on LED on pin 5 */
uint32_t val = GPIOA_ODR;        /* Read:  get current output state */
GPIOA_ODR |= (1U << 5);         /* Read-modify-write: set bit 5 */
```

Breaking down `*(volatile uint32_t *)0x40020014`:

1. `0x40020014` — the raw hardware address (an integer literal)
2. `(volatile uint32_t *)` — cast it to a pointer to `volatile uint32_t`
3. `*` — dereference the pointer to read/write the value at that address

## Accessing a Peripheral as a Structure

Real peripherals have many registers at consecutive addresses. Instead of defining each one separately, map the entire peripheral to a `struct`:

```c
typedef struct {
    volatile uint32_t MODER;    /* Offset 0x00: Mode register */
    volatile uint32_t OTYPER;   /* Offset 0x04: Output type */
    volatile uint32_t OSPEEDR;  /* Offset 0x08: Output speed */
    volatile uint32_t PUPDR;    /* Offset 0x0C: Pull-up/pull-down */
    volatile uint32_t IDR;      /* Offset 0x10: Input data */
    volatile uint32_t ODR;      /* Offset 0x14: Output data */
    volatile uint32_t BSRR;     /* Offset 0x18: Bit set/reset */
    volatile uint32_t LCKR;     /* Offset 0x1C: Lock */
    volatile uint32_t AFR[2];   /* Offset 0x20: Alternate function */
} GPIO_TypeDef;

#define GPIOA ((GPIO_TypeDef *)0x40020000)
#define GPIOB ((GPIO_TypeDef *)0x40020400)
#define GPIOC ((GPIO_TypeDef *)0x40020800)
```

Now access registers with arrow notation:

```c
GPIOA->MODER |= (1U << 10);    /* Set PA5 to output mode */
GPIOA->ODR   |= (1U << 5);     /* Set PA5 high */
GPIOA->ODR   &= ~(1U << 5);    /* Set PA5 low */

if (GPIOC->IDR & (1U << 13)) { /* Read PC13 */
    /* Pin is high */
}
```

This is exactly how STM32 CMSIS headers (`stm32f4xx.h`) define peripheral access — the vendor provides the struct definitions for you.

## Pointer Arithmetic in Embedded C

Pointer arithmetic follows C rules: incrementing a pointer advances it by `sizeof(*pointer)` bytes.

```c
uint32_t *p = (uint32_t *)0x40020000;

p[0];   /* Address 0x40020000 — MODER */
p[1];   /* Address 0x40020004 — OTYPER */
p[5];   /* Address 0x40020014 — ODR */
```

This is equivalent to:

```c
*(p + 5)   /* Same as p[5] */
```

## Function Pointers

Function pointers are heavily used in embedded systems for:

- **Interrupt vector tables**
- **Callback mechanisms**
- **State machines** (dispatch tables)
- **Bootloaders** (jumping to application code)

### Interrupt Vector Table Example

The ARM Cortex-M vector table is simply an array of function pointers:

```c
typedef void (*IRQHandler)(void);

__attribute__((section(".isr_vector")))
const IRQHandler vector_table[] = {
    (IRQHandler)&_estack,       /* Initial stack pointer */
    Reset_Handler,              /* Reset handler */
    NMI_Handler,                /* NMI */
    HardFault_Handler,          /* Hard fault */
    /* ... more handlers ... */
    USART1_IRQHandler,          /* USART1 interrupt */
    TIM2_IRQHandler,            /* Timer 2 interrupt */
};
```

### Callback Pattern

```c
typedef void (*ButtonCallback)(uint8_t pin);

static ButtonCallback button_cb = NULL;

void button_register_callback(ButtonCallback cb)
{
    button_cb = cb;
}

void EXTI15_10_IRQHandler(void)
{
    if (button_cb != NULL) {
        button_cb(13);
    }
    EXTI->PR |= (1U << 13);  /* Clear pending flag */
}
```

### Jumping to Another Address (Bootloader Pattern)

```c
void jump_to_application(uint32_t app_address)
{
    uint32_t stack_ptr = *(volatile uint32_t *)app_address;
    uint32_t reset_handler = *(volatile uint32_t *)(app_address + 4);

    /* Set the main stack pointer */
    __set_MSP(stack_ptr);

    /* Cast the reset handler address to a function pointer and call it */
    void (*app_entry)(void) = (void (*)(void))reset_handler;
    app_entry();
}
```

## Pointer Qualifiers Revisited

### `const` Pointer vs. Pointer to `const`

```c
/* Pointer to const data — can't modify the data through this pointer */
const uint32_t *p1 = (const uint32_t *)0x40020010;
/* *p1 = 5;  ERROR */
/* p1 = other_addr;  OK */

/* Const pointer — can't change where the pointer points */
uint32_t *const p2 = (uint32_t *)0x40020014;
/* *p2 = 5;  OK */
/* p2 = other_addr;  ERROR */

/* Both — can't modify data or change the pointer */
const uint32_t *const p3 = (const uint32_t *)0x40020010;
```

Peripheral base addresses should be `const` pointers (the address never changes):

```c
GPIO_TypeDef *const GPIOA = (GPIO_TypeDef *)0x40020000;
```

## Practical Pattern: Register Abstraction Layer

```c
typedef struct {
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t SR;
    volatile uint32_t DR;
    volatile uint32_t BRR;
} USART_TypeDef;

#define USART1 ((USART_TypeDef *)0x40011000)
#define USART2 ((USART_TypeDef *)0x40004400)

void usart_send_byte(USART_TypeDef *usart, uint8_t byte)
{
    while (!(usart->SR & (1U << 7)))  /* Wait for TXE */
        ;
    usart->DR = byte;
}

/* Works for any USART instance */
usart_send_byte(USART1, 'A');
usart_send_byte(USART2, 'B');
```

## Common Pitfalls

### 1. Forgetting `volatile`

The most common embedded bug. Without `volatile`, the compiler may cache register values in CPU registers and never re-read them from hardware.

### 2. Misaligned Access

ARM Cortex-M3/M4 allow unaligned access (with a performance penalty), but Cortex-M0 does **not**. Casting arbitrary addresses to `uint32_t *` can cause a hard fault if the address is not 4-byte aligned.

### 3. Incorrect Struct Padding

The compiler may insert padding between struct members. Use `__attribute__((packed))` or `#pragma pack` when mapping structs to hardware registers with unusual layouts:

```c
typedef struct __attribute__((packed)) {
    uint8_t  status;
    uint32_t data;    /* Without 'packed', this would be at offset 4, not 1 */
} SensorFrame;
```

**Warning:** Packed structs can cause unaligned accesses — use them only when necessary.

## Summary

- Memory-mapped I/O allows you to control hardware by reading/writing memory addresses.
- Use `volatile` pointers for all hardware register access.
- Map peripherals to structs for clean, maintainable code.
- Function pointers enable callbacks, dispatch tables, and bootloader jumps.
- Be aware of alignment requirements on your target architecture.

---

**Next:** [Chapter 5 — Structures, Unions, and Bit-Fields](05-structures-unions-bitfields.md)
