/**
 * GPIO Control — The "Hello World" of Embedded Systems
 *
 * Simulates GPIO operations (input, output, pull-up/down, alternate function)
 * on a host PC. On real hardware, replace the simulated registers with
 * actual memory-mapped addresses from your MCU's datasheet.
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ----------------------------------------------------------------
 * Simulated GPIO peripheral registers (mirrors STM32 GPIO layout)
 * ---------------------------------------------------------------- */
typedef struct {
    volatile uint32_t MODER;   /* 0x00: Mode (input/output/AF/analog) */
    volatile uint32_t OTYPER;  /* 0x04: Output type (push-pull/open-drain) */
    volatile uint32_t OSPEEDR; /* 0x08: Output speed */
    volatile uint32_t PUPDR;   /* 0x0C: Pull-up / pull-down */
    volatile uint32_t IDR;     /* 0x10: Input data */
    volatile uint32_t ODR;     /* 0x14: Output data */
    volatile uint32_t BSRR;    /* 0x18: Bit set/reset */
    volatile uint32_t LCKR;    /* 0x1C: Lock */
    volatile uint32_t AFR[2];  /* 0x20: Alternate function low/high */
} GPIO_TypeDef;

static GPIO_TypeDef sim_gpioa;
static GPIO_TypeDef sim_gpiob;

#define GPIOA (&sim_gpioa)
#define GPIOB (&sim_gpiob)

/* Simulated RCC (clock enable) */
static uint32_t sim_rcc_ahb1enr = 0;
#define RCC_AHB1ENR sim_rcc_ahb1enr

/* GPIO mode values (2 bits per pin) */
#define GPIO_MODE_INPUT     0x00
#define GPIO_MODE_OUTPUT    0x01
#define GPIO_MODE_AF        0x02
#define GPIO_MODE_ANALOG    0x03

/* Pull resistor values (2 bits per pin) */
#define GPIO_PULL_NONE      0x00
#define GPIO_PULL_UP        0x01
#define GPIO_PULL_DOWN      0x02

/* Output type */
#define GPIO_OTYPE_PUSHPULL   0
#define GPIO_OTYPE_OPENDRAIN  1

/* Speed */
#define GPIO_SPEED_LOW      0x00
#define GPIO_SPEED_MEDIUM   0x01
#define GPIO_SPEED_HIGH     0x02
#define GPIO_SPEED_VERY_HIGH 0x03

/* ----------------------------------------------------------------
 * GPIO Helper Functions
 * ---------------------------------------------------------------- */

static void gpio_set_mode(GPIO_TypeDef *port, uint8_t pin, uint8_t mode) {
    uint32_t shift = pin * 2;
    port->MODER &= ~(3U << shift);
    port->MODER |= ((uint32_t)mode << shift);
}

static void gpio_set_pull(GPIO_TypeDef *port, uint8_t pin, uint8_t pull) {
    uint32_t shift = pin * 2;
    port->PUPDR &= ~(3U << shift);
    port->PUPDR |= ((uint32_t)pull << shift);
}

static void gpio_set_speed(GPIO_TypeDef *port, uint8_t pin, uint8_t speed) {
    uint32_t shift = pin * 2;
    port->OSPEEDR &= ~(3U << shift);
    port->OSPEEDR |= ((uint32_t)speed << shift);
}

static void gpio_set_output_type(GPIO_TypeDef *port, uint8_t pin, uint8_t type) {
    if (type == GPIO_OTYPE_OPENDRAIN) {
        port->OTYPER |= (1U << pin);
    } else {
        port->OTYPER &= ~(1U << pin);
    }
}

static void gpio_write_pin(GPIO_TypeDef *port, uint8_t pin, uint8_t state) {
    if (state) {
        port->BSRR = (1U << pin);         /* Atomic set */
        port->ODR |= (1U << pin);         /* Simulate BSRR effect on ODR */
    } else {
        port->BSRR = (1U << (pin + 16));  /* Atomic reset */
        port->ODR &= ~(1U << pin);
    }
}

static uint8_t gpio_read_pin(GPIO_TypeDef *port, uint8_t pin) {
    return (port->IDR >> pin) & 1U;
}

static void gpio_toggle_pin(GPIO_TypeDef *port, uint8_t pin) {
    port->ODR ^= (1U << pin);
}

/* ----------------------------------------------------------------
 * Demo: LED Blinking (Output)
 * ---------------------------------------------------------------- */
static void demo_led_output(void) {
    printf("=== Demo: LED Output (Pin PA5) ===\n\n");

    memset(GPIOA, 0, sizeof(GPIO_TypeDef));

    /* Step 1: Enable GPIOA clock */
    RCC_AHB1ENR |= (1 << 0);
    printf("  1. GPIOA clock enabled (RCC_AHB1ENR = 0x%08X)\n", RCC_AHB1ENR);

    /* Step 2: Configure PA5 as push-pull output */
    gpio_set_mode(GPIOA, 5, GPIO_MODE_OUTPUT);
    gpio_set_output_type(GPIOA, 5, GPIO_OTYPE_PUSHPULL);
    gpio_set_speed(GPIOA, 5, GPIO_SPEED_LOW);
    gpio_set_pull(GPIOA, 5, GPIO_PULL_NONE);

    printf("  2. PA5 configured: MODER=0x%08X OTYPER=0x%08X\n",
           GPIOA->MODER, GPIOA->OTYPER);

    /* Step 3: Set pin high, then blink */
    gpio_write_pin(GPIOA, 5, 1);
    printf("  3. Set PA5 HIGH via gpio_write_pin (ODR=0x%04X)\n", GPIOA->ODR);
    gpio_write_pin(GPIOA, 5, 0);

    printf("  4. Blinking LED:\n");
    for (int i = 0; i < 6; i++) {
        gpio_toggle_pin(GPIOA, 5);
        printf("     Cycle %d: LED is %s (ODR=0x%04X)\n",
               i + 1,
               (GPIOA->ODR & (1 << 5)) ? "ON " : "OFF",
               GPIOA->ODR);
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Button Input with Pull-Up
 * ---------------------------------------------------------------- */
static void demo_button_input(void) {
    printf("=== Demo: Button Input (Pin PA0) ===\n\n");

    memset(GPIOA, 0, sizeof(GPIO_TypeDef));

    /* Configure PA0 as input with pull-up */
    gpio_set_mode(GPIOA, 0, GPIO_MODE_INPUT);
    gpio_set_pull(GPIOA, 0, GPIO_PULL_UP);

    printf("  PA0 configured as input with pull-up\n");
    printf("  MODER=0x%08X PUPDR=0x%08X\n\n", GPIOA->MODER, GPIOA->PUPDR);

    /* Simulate button states */
    printf("  Simulating button presses:\n");

    /* Button not pressed (pull-up keeps it HIGH) */
    GPIOA->IDR = (1 << 0);
    printf("    Button state: %s (IDR bit 0 = %u)\n",
           gpio_read_pin(GPIOA, 0) ? "RELEASED (HIGH)" : "PRESSED (LOW)",
           gpio_read_pin(GPIOA, 0));

    /* Button pressed (connects to GND, goes LOW) */
    GPIOA->IDR = 0;
    printf("    Button state: %s (IDR bit 0 = %u)\n",
           gpio_read_pin(GPIOA, 0) ? "RELEASED (HIGH)" : "PRESSED (LOW)",
           gpio_read_pin(GPIOA, 0));

    printf("\n  With pull-up: released=HIGH, pressed=LOW (active-low logic)\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Multiple LED control (port-wide operations)
 * ---------------------------------------------------------------- */
static void demo_multi_led(void) {
    printf("=== Demo: Multi-LED Control (PB0–PB7) ===\n\n");

    memset(GPIOB, 0, sizeof(GPIO_TypeDef));

    /* Configure PB0–PB7 as outputs */
    for (uint8_t pin = 0; pin < 8; pin++) {
        gpio_set_mode(GPIOB, pin, GPIO_MODE_OUTPUT);
    }
    printf("  PB0-PB7 set as outputs (MODER = 0x%08X)\n\n", GPIOB->MODER);

    /* Write patterns to lower 8 bits */
    uint8_t patterns[] = { 0xFF, 0xAA, 0x55, 0x0F, 0xF0, 0x01 };
    const char *names[] = { "All ON", "Alternating A", "Alternating B",
                            "Lower 4", "Upper 4", "Single LED" };
    int n = sizeof(patterns) / sizeof(patterns[0]);

    for (int i = 0; i < n; i++) {
        GPIOB->ODR = (GPIOB->ODR & 0xFFFFFF00) | patterns[i];
        printf("  %-16s  ODR = 0x%02X  [", names[i], patterns[i]);
        for (int b = 7; b >= 0; b--) {
            printf("%c", (patterns[i] & (1 << b)) ? '*' : '.');
        }
        printf("]\n");
    }

    printf("\n  '*' = LED on, '.' = LED off\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Alternate Function (UART pins)
 * ---------------------------------------------------------------- */
static void demo_alternate_function(void) {
    printf("=== Demo: Alternate Function (UART on PA2/PA3) ===\n\n");

    memset(GPIOA, 0, sizeof(GPIO_TypeDef));

    /* PA2 = USART2_TX (AF7), PA3 = USART2_RX (AF7) */

    /* Set mode to Alternate Function */
    gpio_set_mode(GPIOA, 2, GPIO_MODE_AF);
    gpio_set_mode(GPIOA, 3, GPIO_MODE_AF);

    /* Set alternate function number (AFR[0] for pins 0–7) */
    /* Each pin uses 4 bits in AFR */
    GPIOA->AFR[0] |= (7U << (2 * 4));  /* PA2 = AF7 */
    GPIOA->AFR[0] |= (7U << (3 * 4));  /* PA3 = AF7 */

    /* Set PA2 as push-pull, PA3 with pull-up (for RX idle high) */
    gpio_set_output_type(GPIOA, 2, GPIO_OTYPE_PUSHPULL);
    gpio_set_pull(GPIOA, 3, GPIO_PULL_UP);
    gpio_set_speed(GPIOA, 2, GPIO_SPEED_HIGH);

    printf("  PA2 (TX): AF mode, push-pull, high speed\n");
    printf("  PA3 (RX): AF mode, pull-up\n");
    printf("  MODER   = 0x%08X\n", GPIOA->MODER);
    printf("  AFR[0]  = 0x%08X\n", GPIOA->AFR[0]);
    printf("  OTYPER  = 0x%08X\n", GPIOA->OTYPER);
    printf("  PUPDR   = 0x%08X\n", GPIOA->PUPDR);
    printf("  OSPEEDR = 0x%08X\n\n", GPIOA->OSPEEDR);
}

/* ----------------------------------------------------------------
 * Demo: Open-Drain Output (I2C pins)
 * ---------------------------------------------------------------- */
static void demo_open_drain(void) {
    printf("=== Demo: Open-Drain Output (I2C on PB6/PB7) ===\n\n");

    memset(GPIOB, 0, sizeof(GPIO_TypeDef));

    /* I2C requires open-drain outputs with external pull-ups */
    for (uint8_t pin = 6; pin <= 7; pin++) {
        gpio_set_mode(GPIOB, pin, GPIO_MODE_AF);
        gpio_set_output_type(GPIOB, pin, GPIO_OTYPE_OPENDRAIN);
        gpio_set_pull(GPIOB, pin, GPIO_PULL_UP);
        gpio_set_speed(GPIOB, pin, GPIO_SPEED_HIGH);
    }

    /* Set AF4 for I2C1 */
    GPIOB->AFR[0] |= (4U << (6 * 4));
    GPIOB->AFR[0] |= (4U << (7 * 4));

    printf("  PB6 (SCL): AF mode, open-drain, pull-up\n");
    printf("  PB7 (SDA): AF mode, open-drain, pull-up\n");
    printf("  MODER   = 0x%08X\n", GPIOB->MODER);
    printf("  OTYPER  = 0x%08X\n", GPIOB->OTYPER);
    printf("  AFR[0]  = 0x%08X\n", GPIOB->AFR[0]);

    printf("\n  Open-drain allows multiple devices to share a bus line.\n");
    printf("  External pull-up resistors (typically 4.7kΩ) pull the\n");
    printf("  line HIGH when no device is driving it LOW.\n\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  GPIO Control — Embedded C Fundamentals  ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_led_output();
    demo_button_input();
    demo_multi_led();
    demo_alternate_function();
    demo_open_drain();

    printf("═══ End of GPIO Control Demo ═══\n");
    return 0;
}
