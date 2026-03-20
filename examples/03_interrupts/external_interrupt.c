/**
 * @file    external_interrupt.c
 * @brief   External interrupt (EXTI) driven button with NVIC configuration.
 * @target  STM32F4xx (Nucleo: button PC13 → EXTI13, LED PA5)
 *
 * Demonstrates:
 *  - Configuring EXTI for falling-edge detection
 *  - NVIC interrupt enable and priority
 *  - ISR best practices (short, clear flag, set flag)
 *  - Main loop polling the flag set by the ISR
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

/* RCC */
#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))
#define RCC_APB2ENR     (*(volatile uint32_t *)(RCC_BASE + 0x44))

/* GPIOA */
#define GPIOA_BASE      0x40020000U
#define GPIOA_MODER     (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_ODR       (*(volatile uint32_t *)(GPIOA_BASE + 0x14))

/* GPIOC */
#define GPIOC_BASE      0x40020800U
#define GPIOC_MODER     (*(volatile uint32_t *)(GPIOC_BASE + 0x00))
#define GPIOC_PUPDR     (*(volatile uint32_t *)(GPIOC_BASE + 0x0C))

/* SYSCFG — routes GPIO pins to EXTI lines */
#define SYSCFG_BASE     0x40013800U
#define SYSCFG_EXTICR4  (*(volatile uint32_t *)(SYSCFG_BASE + 0x14))

/* EXTI (External Interrupt/Event Controller) */
#define EXTI_BASE       0x40013C00U
#define EXTI_IMR        (*(volatile uint32_t *)(EXTI_BASE + 0x00))  /* Interrupt mask   */
#define EXTI_FTSR       (*(volatile uint32_t *)(EXTI_BASE + 0x0C))  /* Falling trigger  */
#define EXTI_RTSR       (*(volatile uint32_t *)(EXTI_BASE + 0x08))  /* Rising trigger   */
#define EXTI_PR         (*(volatile uint32_t *)(EXTI_BASE + 0x14))  /* Pending register */

/* NVIC */
#define NVIC_ISER1      (*(volatile uint32_t *)0xE000E104)  /* IRQ 32-63 enable */
#define NVIC_IPR_BASE   0xE000E400U

#define LED_PIN         5
#define BUTTON_PIN      13

/* EXTI15_10 IRQ number on STM32F4 = 40 */
#define EXTI15_10_IRQn  40

/* ========================================================================== */
/*  Shared State (volatile because modified in ISR)                            */
/* ========================================================================== */

volatile bool g_button_event = false;
volatile uint32_t g_press_count = 0;

/* ========================================================================== */
/*  Initialization                                                             */
/* ========================================================================== */

static void gpio_init(void)
{
    RCC_AHB1ENR |= (1U << 0) | (1U << 2);  /* Enable GPIOA + GPIOC clocks */

    /* PA5: Output */
    GPIOA_MODER &= ~(3U << (LED_PIN * 2));
    GPIOA_MODER |=  (1U << (LED_PIN * 2));

    /* PC13: Input with pull-up */
    GPIOC_MODER &= ~(3U << (BUTTON_PIN * 2));
    GPIOC_PUPDR &= ~(3U << (BUTTON_PIN * 2));
    GPIOC_PUPDR |=  (1U << (BUTTON_PIN * 2));
}

/**
 * Configure EXTI line 13 for falling-edge interrupt from PC13.
 *
 * The EXTI controller has one line per pin number (0-15). SYSCFG selects
 * which port (A-H) drives each EXTI line. Line 13 can come from PA13,
 * PB13, PC13, etc.
 */
static void exti_init(void)
{
    /* Enable SYSCFG clock */
    RCC_APB2ENR |= (1U << 14);

    /*
     * Route EXTI13 to Port C.
     * SYSCFG_EXTICR4 covers EXTI lines 12-15.
     * Bits [7:4] select the port for EXTI13:
     *   0000 = PA13, 0001 = PB13, 0010 = PC13, ...
     */
    SYSCFG_EXTICR4 &= ~(0xF << 4);
    SYSCFG_EXTICR4 |=  (0x2 << 4);   /* Port C → EXTI13 */

    /* Enable falling-edge trigger (button press = HIGH→LOW) */
    EXTI_FTSR |= (1U << BUTTON_PIN);

    /* Unmask EXTI line 13 */
    EXTI_IMR |= (1U << BUTTON_PIN);
}

/**
 * Enable and set priority for the EXTI15_10 interrupt in the NVIC.
 *
 * IRQ 40 → ISER1 bit 8 (40 - 32 = 8)
 */
static void nvic_init(void)
{
    /* Set priority (lower number = higher priority) */
    volatile uint8_t *ipr = (volatile uint8_t *)(NVIC_IPR_BASE + EXTI15_10_IRQn);
    *ipr = (2 << 4);  /* Priority 2 (upper nibble on Cortex-M4) */

    /* Enable IRQ 40 → ISER1 bit 8 */
    NVIC_ISER1 = (1U << (EXTI15_10_IRQn - 32));
}

/* ========================================================================== */
/*  Interrupt Service Routine                                                  */
/* ========================================================================== */

/**
 * EXTI15_10 handles EXTI lines 10 through 15.
 * We must check the pending register to determine which line triggered.
 *
 * ISR rules followed here:
 *  1. Check which EXTI line caused the interrupt
 *  2. Clear the pending flag FIRST (prevents re-entry)
 *  3. Do minimal work (set a flag, increment a counter)
 *  4. Return quickly
 */
void EXTI15_10_IRQHandler(void)
{
    if (EXTI_PR & (1U << BUTTON_PIN)) {
        EXTI_PR = (1U << BUTTON_PIN);  /* Clear pending (write-1-to-clear) */

        g_button_event = true;
        g_press_count++;
    }
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    gpio_init();
    exti_init();
    nvic_init();

    /* Enable global interrupts (Cortex-M starts with them enabled) */
    __asm volatile ("cpsie i");

    while (1) {
        if (g_button_event) {
            g_button_event = false;

            /* Toggle LED */
            GPIOA_ODR ^= (1U << LED_PIN);

            /*
             * Here you could also do heavier processing that shouldn't
             * be done in the ISR: update display, log to storage, etc.
             */
        }

        /* CPU can do other work here, or sleep to save power */
        __asm volatile ("wfi");  /* Sleep until next interrupt */
    }
}
