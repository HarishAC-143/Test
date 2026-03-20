/**
 * @file    led_blink.c
 * @brief   LED blink — the "Hello World" of embedded programming.
 * @target  STM32F4xx (Nucleo-F446RE: LED on PA5)
 *
 * Demonstrates:
 *  - Enabling a peripheral clock
 *  - Configuring a GPIO pin as output
 *  - Toggling an output pin
 *  - Simple busy-wait delay
 */

#include <stdint.h>

/* ========================================================================== */
/*  Hardware Register Definitions                                              */
/* ========================================================================== */

/* Reset and Clock Control (RCC) */
#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))
#define RCC_AHB1ENR_GPIOAEN    (1U << 0)

/* GPIO Port A */
#define GPIOA_BASE      0x40020000U
#define GPIOA_MODER     (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_OTYPER    (*(volatile uint32_t *)(GPIOA_BASE + 0x04))
#define GPIOA_OSPEEDR   (*(volatile uint32_t *)(GPIOA_BASE + 0x08))
#define GPIOA_PUPDR     (*(volatile uint32_t *)(GPIOA_BASE + 0x0C))
#define GPIOA_ODR       (*(volatile uint32_t *)(GPIOA_BASE + 0x14))
#define GPIOA_BSRR      (*(volatile uint32_t *)(GPIOA_BASE + 0x18))

/* LED is connected to PA5 */
#define LED_PIN         5

/* ========================================================================== */
/*  GPIO Mode Constants                                                        */
/* ========================================================================== */

#define GPIO_MODE_INPUT     0x00
#define GPIO_MODE_OUTPUT    0x01
#define GPIO_MODE_ALTFN     0x02
#define GPIO_MODE_ANALOG    0x03

/* ========================================================================== */
/*  Functions                                                                  */
/* ========================================================================== */

/**
 * Simple busy-wait delay.
 * The volatile qualifier prevents the compiler from optimizing away the loop.
 * Timing is approximate and depends on clock speed and compiler optimization.
 */
static void delay(volatile uint32_t count)
{
    while (count--) { }
}

/**
 * Configure PA5 as a general-purpose push-pull output.
 *
 * Each GPIO pin is controlled by a 2-bit field in MODER:
 *   00 = Input, 01 = Output, 10 = Alternate Function, 11 = Analog
 *
 * PA5 uses bits [11:10] of MODER (pin * 2 = bit position).
 */
static void led_gpio_init(void)
{
    /* Enable GPIOA peripheral clock — GPIOs are unpowered at reset */
    RCC_AHB1ENR |= RCC_AHB1ENR_GPIOAEN;

    /* Configure PA5 as general-purpose output */
    GPIOA_MODER &= ~(3U << (LED_PIN * 2));   /* Clear mode bits [11:10] */
    GPIOA_MODER |=  (GPIO_MODE_OUTPUT << (LED_PIN * 2));  /* Set to 01   */

    /* Push-pull output type (0 = push-pull, 1 = open-drain) */
    GPIOA_OTYPER &= ~(1U << LED_PIN);

    /* Low speed is sufficient for an LED */
    GPIOA_OSPEEDR &= ~(3U << (LED_PIN * 2));

    /* No pull-up or pull-down (00 = none) */
    GPIOA_PUPDR &= ~(3U << (LED_PIN * 2));
}

/**
 * Turn the LED on using the Bit Set/Reset Register (BSRR).
 * Writing to bits [15:0] SETS the corresponding pin.
 * BSRR writes are atomic — no read-modify-write race condition.
 */
static void led_on(void)
{
    GPIOA_BSRR = (1U << LED_PIN);  /* Set PA5 HIGH */
}

/**
 * Turn the LED off.
 * Writing to bits [31:16] of BSRR RESETS (clears) the corresponding pin.
 */
static void led_off(void)
{
    GPIOA_BSRR = (1U << (LED_PIN + 16));  /* Set PA5 LOW */
}

/**
 * Toggle the LED using the Output Data Register (ODR).
 * XOR flips the bit: 0→1 or 1→0.
 */
static void led_toggle(void)
{
    GPIOA_ODR ^= (1U << LED_PIN);
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    led_gpio_init();

    /* Blink pattern: ON 500ms → OFF 500ms */
    while (1) {
        led_toggle();
        delay(1000000);  /* ~500 ms at 16 MHz, varies with clock & optimization */
    }

    /* Alternative: explicit on/off with different duty cycle */
    /*
    while (1) {
        led_on();
        delay(200000);   // Short on pulse
        led_off();
        delay(1800000);  // Long off period
    }
    */
}
