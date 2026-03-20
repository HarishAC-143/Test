# Chapter 7: GPIO Programming

GPIO (General-Purpose Input/Output) is the most fundamental peripheral. Every embedded project starts here — blinking an LED, reading a button, or driving a relay.

## GPIO Concepts

A GPIO pin can be configured as:

| Mode | Description |
|------|-------------|
| **Input** | Read external signals (buttons, sensors) |
| **Output** | Drive signals (LEDs, relays, control lines) |
| **Alternate Function** | Connect to a peripheral (UART TX, SPI CLK, PWM) |
| **Analog** | Used by the ADC/DAC |

Additional configuration per pin:

| Setting | Options |
|---------|---------|
| **Output type** | Push-pull (drives high and low) or Open-drain (drives low, floats high) |
| **Speed** | Low, Medium, High, Very High (affects slew rate and EMI) |
| **Pull resistor** | None, Pull-up, Pull-down |

## GPIO Registers (STM32 Example)

Each GPIO port (A, B, C, ...) has these registers:

```c
typedef struct {
    volatile uint32_t MODER;    /* Mode: input/output/AF/analog (2 bits per pin) */
    volatile uint32_t OTYPER;   /* Output type: push-pull/open-drain (1 bit per pin) */
    volatile uint32_t OSPEEDR;  /* Output speed (2 bits per pin) */
    volatile uint32_t PUPDR;    /* Pull-up/pull-down (2 bits per pin) */
    volatile uint32_t IDR;      /* Input data (read-only, 1 bit per pin) */
    volatile uint32_t ODR;      /* Output data (1 bit per pin) */
    volatile uint32_t BSRR;     /* Bit set/reset (write-only, atomic) */
    volatile uint32_t LCKR;     /* Configuration lock */
    volatile uint32_t AFR[2];   /* Alternate function selection (4 bits per pin) */
} GPIO_TypeDef;
```

## LED Blink: The "Hello World" of Embedded

### Step-by-Step

1. Enable the clock to the GPIO port
2. Configure the pin as output (push-pull)
3. Toggle the pin in a loop

```c
#include <stdint.h>

#define RCC_AHB1ENR  (*(volatile uint32_t *)0x40023830)
#define GPIOA_MODER  (*(volatile uint32_t *)0x40020000)
#define GPIOA_ODR    (*(volatile uint32_t *)0x40020014)

void delay(volatile uint32_t count)
{
    while (count--)
        ;
}

int main(void)
{
    /* 1. Enable GPIOA clock (bit 0 of AHB1ENR) */
    RCC_AHB1ENR |= (1U << 0);

    /* 2. Set PA5 as output: MODER[11:10] = 01 */
    GPIOA_MODER &= ~(3U << 10);  /* Clear bits 11:10 */
    GPIOA_MODER |=  (1U << 10);  /* Set bit 10 */

    /* 3. Toggle LED forever */
    while (1) {
        GPIOA_ODR ^= (1U << 5);
        delay(500000);
    }
}
```

### Using the BSRR Register (Atomic Set/Reset)

The BSRR (Bit Set/Reset Register) allows atomic pin control without read-modify-write:

```c
/* Set PA5 HIGH — write 1 to bit 5 of BSRR */
GPIOA->BSRR = (1U << 5);

/* Set PA5 LOW — write 1 to bit 21 (5 + 16) of BSRR */
GPIOA->BSRR = (1U << (5 + 16));
```

Why BSRR is preferred over read-modify-write on ODR:

- **Atomic** — cannot be interrupted mid-operation
- **No read step** — faster, no race condition
- **Interrupt-safe** — safe to use from both main code and ISRs

## Reading a Button

### Direct Polling

```c
#define GPIOC_IDR  (*(volatile uint32_t *)0x40020810)

void configure_button(void)
{
    /* Enable GPIOC clock */
    RCC_AHB1ENR |= (1U << 2);

    /* PC13 as input: MODER[27:26] = 00 (default after reset) */
    GPIOC->MODER &= ~(3U << 26);

    /* Enable pull-up: PUPDR[27:26] = 01 */
    GPIOC->PUPDR &= ~(3U << 26);
    GPIOC->PUPDR |=  (1U << 26);
}

int is_button_pressed(void)
{
    /* Active-low button: pressed = IDR bit 13 is 0 */
    return !(GPIOC->IDR & (1U << 13));
}
```

### Software Debouncing

Mechanical buttons bounce — the contact opens and closes several times within a few milliseconds. Without debouncing, one press can register as multiple presses.

#### Simple Delay-Based Debounce

```c
int debounced_read(void)
{
    if (is_button_pressed()) {
        delay_ms(50);  /* Wait for bounce to settle */
        if (is_button_pressed()) {
            return 1;  /* Confirmed press */
        }
    }
    return 0;
}
```

#### Integration-Based Debounce (Better)

Sample the button repeatedly and require N consecutive matching readings:

```c
#define DEBOUNCE_SAMPLES 10

uint8_t debounce_button(void)
{
    static uint8_t state = 0;
    static uint8_t count = 0;

    uint8_t current = is_button_pressed();

    if (current != state) {
        count++;
        if (count >= DEBOUNCE_SAMPLES) {
            state = current;
            count = 0;
        }
    } else {
        count = 0;
    }
    return state;
}
```

Call this function periodically (e.g., from a 1 ms timer interrupt) for best results.

#### Shift Register Debounce

Use a shift register to track the last N readings:

```c
uint8_t debounce_shift(void)
{
    static uint16_t history = 0;

    history = (history << 1) | is_button_pressed();

    /* Stable pressed: last 8 readings all 1 */
    if ((history & 0xFF) == 0xFF)
        return 1;

    /* Stable released: last 8 readings all 0 */
    if ((history & 0xFF) == 0x00)
        return 0;

    /* Still bouncing — return last stable state */
    return (history >> 8) & 1;
}
```

## Driving Multiple LEDs

```c
void traffic_light_init(void)
{
    RCC->AHB1ENR |= (1U << 0);  /* GPIOA clock */

    /* PA0=Red, PA1=Yellow, PA2=Green — all outputs */
    GPIOA->MODER &= ~(0x3FU);        /* Clear bits [5:0] */
    GPIOA->MODER |=  (0x15U);        /* 01 01 01 = output for pins 0,1,2 */
}

void set_traffic_light(uint8_t red, uint8_t yellow, uint8_t green)
{
    uint32_t set_mask = 0;
    uint32_t reset_mask = 0;

    if (red)    set_mask |= (1U << 0); else reset_mask |= (1U << 0);
    if (yellow) set_mask |= (1U << 1); else reset_mask |= (1U << 1);
    if (green)  set_mask |= (1U << 2); else reset_mask |= (1U << 2);

    GPIOA->BSRR = set_mask | (reset_mask << 16);
}
```

## GPIO Abstraction Layer

Wrap raw register access in a clean API:

```c
typedef enum { GPIO_PIN_RESET = 0, GPIO_PIN_SET = 1 } GPIO_PinState;

void gpio_write_pin(GPIO_TypeDef *port, uint8_t pin, GPIO_PinState state)
{
    if (state == GPIO_PIN_SET)
        port->BSRR = (1U << pin);
    else
        port->BSRR = (1U << (pin + 16));
}

GPIO_PinState gpio_read_pin(GPIO_TypeDef *port, uint8_t pin)
{
    return (port->IDR & (1U << pin)) ? GPIO_PIN_SET : GPIO_PIN_RESET;
}

void gpio_toggle_pin(GPIO_TypeDef *port, uint8_t pin)
{
    port->ODR ^= (1U << pin);
}
```

## Practical Examples

- [`examples/02_gpio/led_blink.c`](../examples/02_gpio/led_blink.c) — Basic LED blink
- [`examples/02_gpio/button_debounce.c`](../examples/02_gpio/button_debounce.c) — Button reading with debounce
- [`examples/02_gpio/gpio_driver.c`](../examples/02_gpio/gpio_driver.c) — Reusable GPIO abstraction layer

## Summary

- Always enable the peripheral clock before accessing GPIO registers.
- Use BSRR for atomic pin control instead of read-modify-write on ODR.
- Debounce mechanical buttons — raw readings are unreliable.
- Wrap register access in abstraction functions for cleaner, portable code.

---

**Next:** [Chapter 8 — Interrupts and ISRs](08-interrupts-and-isrs.md)
