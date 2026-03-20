/**
 * LED Blink — The "Hello World" of Embedded Systems
 *
 * This example demonstrates bare-metal GPIO output on an STM32F4
 * (e.g., STM32F407 Discovery or STM32F411 Nucleo with LED on PA5).
 *
 * It shows:
 *   - Enabling a peripheral clock
 *   - Configuring a GPIO pin as output
 *   - Toggling the pin with a software delay
 *   - Using BSRR for atomic set/reset
 *
 * Target: STM32F4xx (conceptual — compiles with warnings on host for study)
 * For host compilation: gcc -Wall -std=c11 -DSIMULATION -o led_blink led_blink.c
 */

#include <stdint.h>

/* ---- Hardware Definitions ---- */

#ifdef SIMULATION
    /* Simulated registers for host compilation */
    static volatile uint32_t _RCC_AHB1ENR;
    static volatile uint32_t _GPIOA_MODER;
    static volatile uint32_t _GPIOA_ODR;
    static volatile uint32_t _GPIOA_BSRR;

    #define RCC_AHB1ENR   _RCC_AHB1ENR
    #define GPIOA_MODER   _GPIOA_MODER
    #define GPIOA_ODR     _GPIOA_ODR
    #define GPIOA_BSRR    _GPIOA_BSRR

    #include <stdio.h>
    #define LED_LOG(msg) printf("%s\n", msg)
#else
    /* Real hardware register addresses (STM32F4) */
    #define RCC_AHB1ENR   (*(volatile uint32_t *)0x40023830)
    #define GPIOA_MODER   (*(volatile uint32_t *)0x40020000)
    #define GPIOA_ODR     (*(volatile uint32_t *)0x40020014)
    #define GPIOA_BSRR    (*(volatile uint32_t *)0x40020018)

    #define LED_LOG(msg)  ((void)0)
#endif

#define LED_PIN 5  /* PA5 — onboard LED on Nucleo boards */

/* ---- Software Delay ---- */

static void delay(volatile uint32_t count)
{
    while (count--)
        ;
}

/* ---- GPIO Configuration ---- */

static void led_init(void)
{
    /* Step 1: Enable clock to GPIOA (bit 0 of AHB1ENR) */
    RCC_AHB1ENR |= (1U << 0);

    /* Step 2: Configure PA5 as General-Purpose Output
     * MODER register: 2 bits per pin
     * Bits [11:10] = Pin 5 mode
     * 00 = Input, 01 = Output, 10 = Alt Function, 11 = Analog
     */
    GPIOA_MODER &= ~(3U << (LED_PIN * 2));   /* Clear mode bits */
    GPIOA_MODER |=  (1U << (LED_PIN * 2));    /* Set to output (01) */

    LED_LOG("LED initialized on PA5");
}

/* ---- LED Control Functions ---- */

static void led_on(void)
{
    /*
     * Method 1: Read-modify-write on ODR (Output Data Register)
     * GPIOA_ODR |= (1U << LED_PIN);
     *
     * Method 2: Atomic set via BSRR (Bit Set/Reset Register)
     * Writing to bits [15:0] SETS the corresponding pin.
     * This is preferred because it's atomic — no read step.
     */
    GPIOA_BSRR = (1U << LED_PIN);
    LED_LOG("LED ON");
}

static void led_off(void)
{
    /*
     * BSRR bits [31:16] RESET the corresponding pin.
     * Writing bit (LED_PIN + 16) clears pin LED_PIN.
     */
    GPIOA_BSRR = (1U << (LED_PIN + 16));
    LED_LOG("LED OFF");
}

static void led_toggle(void)
{
    /*
     * Toggle via XOR on ODR. This IS a read-modify-write,
     * so it's not atomic. Use with care in ISR contexts.
     */
    GPIOA_ODR ^= (1U << LED_PIN);
    LED_LOG("LED TOGGLED");
}

/* ---- Main Application ---- */

int main(void)
{
    led_init();

#ifdef SIMULATION
    printf("=== LED Blink Simulation ===\n\n");
    printf("On real hardware, the LED on PA5 blinks.\n");
    printf("Simulating 10 toggles:\n\n");

    for (int i = 0; i < 10; i++) {
        led_toggle();
        delay(100000);
    }

    printf("\nDemonstrating explicit ON/OFF:\n\n");
    led_on();
    delay(100000);
    led_off();

    printf("\nSimulation complete.\n");
#else
    /* On real hardware: blink forever */
    while (1) {
        led_toggle();
        delay(500000);  /* ~500ms depending on clock speed */
    }
#endif

    return 0;
}
