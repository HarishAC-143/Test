/**
 * @file    01_gpio_driver.c
 * @brief   Complete GPIO driver for ARM Cortex-M (STM32-style registers)
 *
 * Demonstrates:
 *  - Structure overlay for register access
 *  - Pin mode configuration (input, output, alternate function, analog)
 *  - Pull-up / pull-down configuration
 *  - Atomic set/reset via BSRR
 *  - Software debounce for button inputs
 *  - External interrupt configuration (EXTI)
 *
 * Target: Generic ARM Cortex-M with STM32-like GPIO peripheral
 */

#include <stdint.h>

/* ──────────────────────────────────────────────────────────────────────────
 * Register Definitions
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    volatile uint32_t MODER;    /* 0x00 Mode register              */
    volatile uint32_t OTYPER;   /* 0x04 Output type register       */
    volatile uint32_t OSPEEDR;  /* 0x08 Output speed register      */
    volatile uint32_t PUPDR;    /* 0x0C Pull-up/pull-down register */
    volatile uint32_t IDR;      /* 0x10 Input data register        */
    volatile uint32_t ODR;      /* 0x14 Output data register       */
    volatile uint32_t BSRR;     /* 0x18 Bit set/reset register     */
    volatile uint32_t LCKR;     /* 0x1C Configuration lock         */
    volatile uint32_t AFRL;     /* 0x20 Alternate function low     */
    volatile uint32_t AFRH;     /* 0x24 Alternate function high    */
} GPIO_TypeDef;

typedef struct {
    volatile uint32_t IMR;      /* Interrupt mask           */
    volatile uint32_t EMR;      /* Event mask               */
    volatile uint32_t RTSR;     /* Rising trigger selection */
    volatile uint32_t FTSR;     /* Falling trigger selection*/
    volatile uint32_t SWIER;    /* Software interrupt event */
    volatile uint32_t PR;       /* Pending register         */
} EXTI_TypeDef;

/* Port base addresses */
#define GPIOA   ((GPIO_TypeDef *)0x48000000U)
#define GPIOB   ((GPIO_TypeDef *)0x48000400U)
#define GPIOC   ((GPIO_TypeDef *)0x48000800U)
#define GPIOD   ((GPIO_TypeDef *)0x48000C00U)

#define EXTI    ((EXTI_TypeDef *)0x40010400U)

/* RCC register to enable GPIO clocks */
#define RCC_AHB1ENR (*(volatile uint32_t *)0x40023830U)

/* ──────────────────────────────────────────────────────────────────────────
 * Type Definitions
 * ────────────────────────────────────────────────────────────────────────── */

typedef enum {
    GPIO_MODE_INPUT  = 0x00,
    GPIO_MODE_OUTPUT = 0x01,
    GPIO_MODE_AF     = 0x02,
    GPIO_MODE_ANALOG = 0x03
} gpio_mode_t;

typedef enum {
    GPIO_OTYPE_PUSH_PULL  = 0x00,
    GPIO_OTYPE_OPEN_DRAIN = 0x01
} gpio_otype_t;

typedef enum {
    GPIO_SPEED_LOW    = 0x00,
    GPIO_SPEED_MEDIUM = 0x01,
    GPIO_SPEED_HIGH   = 0x02,
    GPIO_SPEED_VHIGH  = 0x03
} gpio_speed_t;

typedef enum {
    GPIO_PULL_NONE = 0x00,
    GPIO_PULL_UP   = 0x01,
    GPIO_PULL_DOWN = 0x02
} gpio_pull_t;

typedef struct {
    gpio_mode_t  mode;
    gpio_otype_t otype;
    gpio_speed_t speed;
    gpio_pull_t  pull;
    uint8_t      af;      /* Alternate function number (0–15) */
} gpio_config_t;

/* ──────────────────────────────────────────────────────────────────────────
 * GPIO Driver API
 * ────────────────────────────────────────────────────────────────────────── */

void gpio_enable_clock(GPIO_TypeDef *port)
{
    uint32_t bit;
    if      (port == GPIOA) bit = 0;
    else if (port == GPIOB) bit = 1;
    else if (port == GPIOC) bit = 2;
    else if (port == GPIOD) bit = 3;
    else return;

    RCC_AHB1ENR |= (1U << bit);

    /* Dummy reads for clock propagation delay */
    volatile uint32_t tmp = RCC_AHB1ENR;
    (void)tmp;
}

void gpio_config_pin(GPIO_TypeDef *port, uint8_t pin,
                     const gpio_config_t *cfg)
{
    /* Mode: 2 bits per pin */
    port->MODER &= ~(0x3U << (pin * 2));
    port->MODER |= ((uint32_t)cfg->mode << (pin * 2));

    /* Output type: 1 bit per pin */
    port->OTYPER &= ~(0x1U << pin);
    port->OTYPER |= ((uint32_t)cfg->otype << pin);

    /* Speed: 2 bits per pin */
    port->OSPEEDR &= ~(0x3U << (pin * 2));
    port->OSPEEDR |= ((uint32_t)cfg->speed << (pin * 2));

    /* Pull-up/pull-down: 2 bits per pin */
    port->PUPDR &= ~(0x3U << (pin * 2));
    port->PUPDR |= ((uint32_t)cfg->pull << (pin * 2));

    /* Alternate function: 4 bits per pin, split across AFRL and AFRH */
    if (cfg->mode == GPIO_MODE_AF) {
        volatile uint32_t *afr = (pin < 8) ? &port->AFRL : &port->AFRH;
        uint8_t pos = (pin % 8) * 4;
        *afr &= ~(0xFU << pos);
        *afr |= ((uint32_t)(cfg->af & 0xF) << pos);
    }
}

void gpio_write(GPIO_TypeDef *port, uint8_t pin, uint8_t value)
{
    if (value) {
        port->BSRR = (1U << pin);          /* Atomic set */
    } else {
        port->BSRR = (1U << (pin + 16));   /* Atomic reset */
    }
}

uint8_t gpio_read(GPIO_TypeDef *port, uint8_t pin)
{
    return (uint8_t)((port->IDR >> pin) & 0x01U);
}

void gpio_toggle(GPIO_TypeDef *port, uint8_t pin)
{
    port->ODR ^= (1U << pin);
}

void gpio_write_port(GPIO_TypeDef *port, uint16_t value)
{
    port->ODR = value;
}

uint16_t gpio_read_port(GPIO_TypeDef *port)
{
    return (uint16_t)(port->IDR & 0xFFFFU);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Button Debounce
 *
 * Shift-register approach: reads one sample per call.
 * Call this function at a regular interval (e.g., every 5 ms via timer ISR).
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    GPIO_TypeDef *port;
    uint8_t       pin;
    uint8_t       history;      /* Shift register of recent samples */
    uint8_t       state;        /* Debounced output (0 or 1) */
    uint8_t       pressed;      /* Edge flag: set once on press */
    uint8_t       released;     /* Edge flag: set once on release */
} button_t;

void button_init(button_t *btn, GPIO_TypeDef *port, uint8_t pin)
{
    btn->port     = port;
    btn->pin      = pin;
    btn->history  = 0xFF;       /* Assume released (active-low button) */
    btn->state    = 0;
    btn->pressed  = 0;
    btn->released = 0;
}

void button_update(button_t *btn)
{
    btn->history = (btn->history << 1) | gpio_read(btn->port, btn->pin);

    uint8_t prev = btn->state;

    if (btn->history == 0x00) {
        btn->state = 1;  /* Stable pressed (active-low: all zeros) */
    } else if (btn->history == 0xFF) {
        btn->state = 0;  /* Stable released (all ones) */
    }

    btn->pressed  = (!prev && btn->state);   /* Rising edge */
    btn->released = (prev && !btn->state);    /* Falling edge */
}

/* ──────────────────────────────────────────────────────────────────────────
 * External Interrupt (EXTI) Configuration
 * ────────────────────────────────────────────────────────────────────────── */

typedef enum {
    EXTI_TRIGGER_RISING  = 0,
    EXTI_TRIGGER_FALLING = 1,
    EXTI_TRIGGER_BOTH    = 2
} exti_trigger_t;

void gpio_config_exti(uint8_t pin, exti_trigger_t trigger)
{
    switch (trigger) {
    case EXTI_TRIGGER_RISING:
        EXTI->RTSR |=  (1U << pin);
        EXTI->FTSR &= ~(1U << pin);
        break;
    case EXTI_TRIGGER_FALLING:
        EXTI->RTSR &= ~(1U << pin);
        EXTI->FTSR |=  (1U << pin);
        break;
    case EXTI_TRIGGER_BOTH:
        EXTI->RTSR |= (1U << pin);
        EXTI->FTSR |= (1U << pin);
        break;
    }

    EXTI->IMR |= (1U << pin);  /* Unmask interrupt */
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: LED Toggle on Button Press
 * ────────────────────────────────────────────────────────────────────────── */

#define LED_PIN     5   /* PA5 */
#define BUTTON_PIN  13  /* PC13 — user button on many dev boards */

static volatile uint32_t systick_ms = 0;

void SysTick_Handler(void)
{
    systick_ms++;
}

static void delay_ms(uint32_t ms)
{
    uint32_t start = systick_ms;
    while ((systick_ms - start) < ms);
}

int main(void)
{
    /* Enable clocks */
    gpio_enable_clock(GPIOA);
    gpio_enable_clock(GPIOC);

    /* Configure LED pin: output, push-pull */
    gpio_config_t led_cfg = {
        .mode  = GPIO_MODE_OUTPUT,
        .otype = GPIO_OTYPE_PUSH_PULL,
        .speed = GPIO_SPEED_LOW,
        .pull  = GPIO_PULL_NONE,
        .af    = 0
    };
    gpio_config_pin(GPIOA, LED_PIN, &led_cfg);

    /* Configure button pin: input, pull-up (active-low) */
    gpio_config_t btn_cfg = {
        .mode  = GPIO_MODE_INPUT,
        .otype = GPIO_OTYPE_PUSH_PULL,
        .speed = GPIO_SPEED_LOW,
        .pull  = GPIO_PULL_UP,
        .af    = 0
    };
    gpio_config_pin(GPIOC, BUTTON_PIN, &btn_cfg);

    /* Initialize button debouncer */
    button_t user_button;
    button_init(&user_button, GPIOC, BUTTON_PIN);

    /* Main loop: poll button, toggle LED on press */
    while (1) {
        button_update(&user_button);

        if (user_button.pressed) {
            gpio_toggle(GPIOA, LED_PIN);
        }

        delay_ms(5);  /* Sample every 5 ms for debounce */
    }

    return 0;
}
