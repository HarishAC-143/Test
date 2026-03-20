/**
 * GPIO Abstraction Layer
 *
 * A reusable GPIO driver that wraps raw register access in a clean API.
 * Demonstrates how to build portable driver layers in embedded C.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -DSIMULATION -o gpio_driver gpio_driver.c
 */

#include <stdint.h>
#include <stdio.h>

/* ---- GPIO Type Definitions ---- */

typedef enum {
    GPIO_MODE_INPUT  = 0x00,
    GPIO_MODE_OUTPUT = 0x01,
    GPIO_MODE_AF     = 0x02,
    GPIO_MODE_ANALOG = 0x03
} GPIO_Mode;

typedef enum {
    GPIO_PULL_NONE = 0x00,
    GPIO_PULL_UP   = 0x01,
    GPIO_PULL_DOWN = 0x02
} GPIO_Pull;

typedef enum {
    GPIO_SPEED_LOW    = 0x00,
    GPIO_SPEED_MEDIUM = 0x01,
    GPIO_SPEED_HIGH   = 0x02,
    GPIO_SPEED_VHIGH  = 0x03
} GPIO_Speed;

typedef enum {
    GPIO_PIN_RESET = 0,
    GPIO_PIN_SET   = 1
} GPIO_PinState;

typedef struct {
    uint8_t   pin;
    GPIO_Mode mode;
    GPIO_Pull pull;
    GPIO_Speed speed;
} GPIO_InitConfig;

/* ---- Simulated GPIO Port ---- */

typedef struct {
    volatile uint32_t MODER;
    volatile uint32_t OTYPER;
    volatile uint32_t OSPEEDR;
    volatile uint32_t PUPDR;
    volatile uint32_t IDR;
    volatile uint32_t ODR;
    volatile uint32_t BSRR;
    volatile uint32_t LCKR;
    volatile uint32_t AFR[2];
} GPIO_TypeDef;

#ifdef SIMULATION
static GPIO_TypeDef _gpioa_regs = {0};
static GPIO_TypeDef _gpioc_regs = {0};

#define GPIOA (&_gpioa_regs)
#define GPIOC (&_gpioc_regs)
#else
#define GPIOA ((GPIO_TypeDef *)0x40020000)
#define GPIOB ((GPIO_TypeDef *)0x40020400)
#define GPIOC ((GPIO_TypeDef *)0x40020800)
#endif

/* ---- GPIO Driver API ---- */

static void gpio_init_pin(GPIO_TypeDef *port, const GPIO_InitConfig *config)
{
    uint8_t pin = config->pin;
    uint32_t pos = pin * 2;

    /* Configure mode (2 bits per pin) */
    port->MODER &= ~(3U << pos);
    port->MODER |= ((uint32_t)config->mode << pos);

    /* Configure pull-up/pull-down (2 bits per pin) */
    port->PUPDR &= ~(3U << pos);
    port->PUPDR |= ((uint32_t)config->pull << pos);

    /* Configure speed (2 bits per pin) */
    port->OSPEEDR &= ~(3U << pos);
    port->OSPEEDR |= ((uint32_t)config->speed << pos);
}

static void gpio_write_pin(GPIO_TypeDef *port, uint8_t pin, GPIO_PinState state)
{
    if (state == GPIO_PIN_SET) {
        port->BSRR = (1U << pin);          /* Atomic set */
    } else {
        port->BSRR = (1U << (pin + 16));   /* Atomic reset */
    }
    /* Also update ODR for simulation visibility */
    if (state == GPIO_PIN_SET)
        port->ODR |= (1U << pin);
    else
        port->ODR &= ~(1U << pin);
}

static GPIO_PinState gpio_read_pin(GPIO_TypeDef *port, uint8_t pin)
{
    return (port->IDR & (1U << pin)) ? GPIO_PIN_SET : GPIO_PIN_RESET;
}

static void gpio_toggle_pin(GPIO_TypeDef *port, uint8_t pin)
{
    port->ODR ^= (1U << pin);
}

/* ---- Helper: Print Port State ---- */

static const char *mode_str(GPIO_Mode m)
{
    switch (m) {
    case GPIO_MODE_INPUT:  return "INPUT ";
    case GPIO_MODE_OUTPUT: return "OUTPUT";
    case GPIO_MODE_AF:     return "AF    ";
    case GPIO_MODE_ANALOG: return "ANALOG";
    default:               return "???   ";
    }
}

static void print_port_config(const char *name, GPIO_TypeDef *port, uint8_t num_pins)
{
    printf("Port %s configuration:\n", name);
    printf("  Pin  Mode    Pull  State\n");
    printf("  ---  ------  ----  -----\n");
    for (uint8_t i = 0; i < num_pins; i++) {
        GPIO_Mode m = (GPIO_Mode)((port->MODER >> (i * 2)) & 0x3);
        uint8_t pull = (port->PUPDR >> (i * 2)) & 0x3;
        uint8_t state = (port->ODR >> i) & 1;
        const char *pull_str = pull == 1 ? "UP  " : pull == 2 ? "DOWN" : "NONE";
        printf("   %2u  %s  %s   %u\n", i, mode_str(m), pull_str, state);
    }
    printf("  MODER  = 0x%08X\n", port->MODER);
    printf("  PUPDR  = 0x%08X\n", port->PUPDR);
    printf("  ODR    = 0x%08X\n\n", port->ODR);
}

/* ---- Demo Application ---- */

int main(void)
{
    printf("GPIO Abstraction Layer Demo\n");
    printf("===========================\n\n");

    /* Configure LED on PA5 as output */
    GPIO_InitConfig led_config = {
        .pin   = 5,
        .mode  = GPIO_MODE_OUTPUT,
        .pull  = GPIO_PULL_NONE,
        .speed = GPIO_SPEED_LOW
    };
    gpio_init_pin(GPIOA, &led_config);

    /* Configure button on PC13 as input with pull-up */
    GPIO_InitConfig btn_config = {
        .pin   = 13,
        .mode  = GPIO_MODE_INPUT,
        .pull  = GPIO_PULL_UP,
        .speed = GPIO_SPEED_LOW
    };
    gpio_init_pin(GPIOC, &btn_config);

    /* Configure multiple output pins (PA0, PA1, PA2 for traffic light) */
    uint8_t traffic_pins[] = {0, 1, 2};
    for (int i = 0; i < 3; i++) {
        GPIO_InitConfig cfg = {
            .pin   = traffic_pins[i],
            .mode  = GPIO_MODE_OUTPUT,
            .pull  = GPIO_PULL_NONE,
            .speed = GPIO_SPEED_LOW
        };
        gpio_init_pin(GPIOA, &cfg);
    }

    print_port_config("A", GPIOA, 8);
    print_port_config("C", GPIOC, 16);

    /* Demonstrate pin operations */
    printf("--- Pin Operations ---\n\n");

    printf("Setting PA5 HIGH (LED on):\n");
    gpio_write_pin(GPIOA, 5, GPIO_PIN_SET);
    printf("  PA5 = %u\n\n", (GPIOA->ODR >> 5) & 1);

    printf("Setting PA5 LOW (LED off):\n");
    gpio_write_pin(GPIOA, 5, GPIO_PIN_RESET);
    printf("  PA5 = %u\n\n", (GPIOA->ODR >> 5) & 1);

    printf("Toggling PA5 three times:\n");
    for (int i = 0; i < 3; i++) {
        gpio_toggle_pin(GPIOA, 5);
        printf("  PA5 = %u\n", (GPIOA->ODR >> 5) & 1);
    }
    printf("\n");

    /* Simulate button read */
    printf("Reading PC13 (button):\n");
    GPIOC->IDR = (1U << 13);  /* Simulate button not pressed (active-low) */
    printf("  PC13 = %u (not pressed)\n",
           gpio_read_pin(GPIOC, 13) == GPIO_PIN_SET ? 1 : 0);

    GPIOC->IDR = 0;  /* Simulate button pressed */
    printf("  PC13 = %u (pressed)\n",
           gpio_read_pin(GPIOC, 13) == GPIO_PIN_SET ? 1 : 0);

    printf("\n--- Traffic Light Sequence ---\n\n");

    struct { uint8_t r, y, g; const char *phase; } sequence[] = {
        {1, 0, 0, "RED"},
        {1, 1, 0, "RED+YELLOW"},
        {0, 0, 1, "GREEN"},
        {0, 1, 0, "YELLOW"},
    };

    for (int i = 0; i < 4; i++) {
        gpio_write_pin(GPIOA, 0, sequence[i].r ? GPIO_PIN_SET : GPIO_PIN_RESET);
        gpio_write_pin(GPIOA, 1, sequence[i].y ? GPIO_PIN_SET : GPIO_PIN_RESET);
        gpio_write_pin(GPIOA, 2, sequence[i].g ? GPIO_PIN_SET : GPIO_PIN_RESET);
        printf("  %-12s  R=%u Y=%u G=%u  ODR=0x%02X\n",
               sequence[i].phase,
               sequence[i].r, sequence[i].y, sequence[i].g,
               GPIOA->ODR & 0x7);
    }

    return 0;
}
