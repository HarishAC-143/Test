/**
 * External Interrupt (EXTI) Example
 *
 * Demonstrates how to configure an external interrupt on an STM32
 * for a button press on PC13 (active-low, falling-edge trigger).
 *
 * Key concepts:
 *   - EXTI line configuration
 *   - NVIC interrupt enable and priority
 *   - ISR implementation with flag-and-process pattern
 *   - Critical section for shared variable access
 *
 * This is pseudo-code for educational purposes. It compiles on host
 * to illustrate the structure.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -DSIMULATION -o external_interrupt external_interrupt.c
 */

#include <stdint.h>
#include <stdio.h>

/* ---- Simulated Hardware ---- */

#ifdef SIMULATION

typedef struct { volatile uint32_t EXTICR[4]; } SYSCFG_TypeDef;
typedef struct {
    volatile uint32_t IMR;
    volatile uint32_t EMR;
    volatile uint32_t RTSR;
    volatile uint32_t FTSR;
    volatile uint32_t SWIER;
    volatile uint32_t PR;
} EXTI_TypeDef;

typedef struct {
    volatile uint32_t MODER;
    volatile uint32_t OTYPER;
    volatile uint32_t OSPEEDR;
    volatile uint32_t PUPDR;
    volatile uint32_t IDR;
    volatile uint32_t ODR;
    volatile uint32_t BSRR;
} GPIO_TypeDef;

static SYSCFG_TypeDef _syscfg = {0};
static EXTI_TypeDef   _exti = {0};
static GPIO_TypeDef   _gpioa = {0};
static GPIO_TypeDef   _gpioc = {0};

#define SYSCFG (&_syscfg)
#define EXTI   (&_exti)
#define GPIOA  (&_gpioa)
#define GPIOC  (&_gpioc)

#define EXTI15_10_IRQn 40

static void NVIC_EnableIRQ(int irq)  { (void)irq; printf("  NVIC: IRQ %d enabled\n", irq); }
static void NVIC_SetPriority(int irq, int prio) {
    (void)irq; (void)prio;
    printf("  NVIC: IRQ %d priority set to %d\n", irq, prio);
}

#endif /* SIMULATION */

/* ---- Shared Variables (ISR ↔ Main) ---- */

/*
 * These MUST be volatile because they are modified by the ISR
 * and read by the main loop. Without volatile, the compiler
 * may optimize away the reads in main().
 */
static volatile uint8_t  button_pressed_flag = 0;
static volatile uint32_t button_press_count = 0;

/* ---- ISR: EXTI15_10 Handler ---- */

/*
 * This ISR handles EXTI lines 10–15. Multiple sources share one IRQ,
 * so we must check the pending register to identify the source.
 */
void EXTI15_10_IRQHandler(void)
{
    if (EXTI->PR & (1U << 13)) {
        /* Clear the pending flag FIRST — writing 1 clears it */
        EXTI->PR = (1U << 13);

        /*
         * Do minimal work in the ISR:
         * - Set a flag for the main loop
         * - Increment a counter
         * - Do NOT call printf, delay, or blocking functions
         */
        button_pressed_flag = 1;
        button_press_count++;
    }
}

/* ---- Configuration ---- */

static void button_interrupt_init(void)
{
    printf("Configuring external interrupt on PC13:\n\n");

    /* 1. Enable GPIOC clock */
    printf("  Step 1: Enable GPIOC clock\n");
    printf("    RCC->AHB1ENR |= (1U << 2);\n\n");

    /* 2. Configure PC13 as input with pull-up */
    printf("  Step 2: Configure PC13 as input with pull-up\n");
    GPIOC->MODER &= ~(3U << 26);     /* Input mode (00) */
    GPIOC->PUPDR &= ~(3U << 26);
    GPIOC->PUPDR |=  (1U << 26);     /* Pull-up */
    printf("    GPIOC->MODER: bits [27:26] = 00 (input)\n");
    printf("    GPIOC->PUPDR: bits [27:26] = 01 (pull-up)\n\n");

    /* 3. Enable SYSCFG clock and map EXTI13 to Port C */
    printf("  Step 3: Map EXTI13 to Port C via SYSCFG\n");
    SYSCFG->EXTICR[3] &= ~(0xFU << 4);
    SYSCFG->EXTICR[3] |=  (0x2U << 4);  /* Port C = 0010 */
    printf("    SYSCFG->EXTICR[3]: bits [7:4] = 0x2 (Port C)\n\n");

    /* 4. Configure EXTI line 13 */
    printf("  Step 4: Configure EXTI line 13\n");
    EXTI->IMR  |= (1U << 13);    /* Unmask interrupt */
    EXTI->FTSR |= (1U << 13);    /* Falling edge trigger (button press) */
    printf("    EXTI->IMR:  unmask line 13\n");
    printf("    EXTI->FTSR: falling edge trigger (active-low button)\n\n");

    /* 5. Enable the interrupt in NVIC */
    printf("  Step 5: Enable EXTI15_10 in NVIC\n");
    NVIC_SetPriority(EXTI15_10_IRQn, 2);
    NVIC_EnableIRQ(EXTI15_10_IRQn);
    printf("\n");
}

/* ---- Main Application ---- */

int main(void)
{
    printf("External Interrupt (EXTI) Example\n");
    printf("==================================\n\n");

    button_interrupt_init();

    printf("--- Simulating Button Presses ---\n\n");
    printf("In real hardware, the main loop runs forever and\n");
    printf("the ISR fires asynchronously when the button is pressed.\n\n");

    /* Simulate several button press interrupts */
    for (int i = 0; i < 5; i++) {
        /* Simulate: hardware sets the pending bit */
        EXTI->PR |= (1U << 13);

        /* Simulate: CPU calls the ISR */
        EXTI15_10_IRQHandler();

        /* Main loop processes the flag */
        if (button_pressed_flag) {
            printf("  [Main] Button press #%u detected — processing...\n",
                   button_press_count);
            button_pressed_flag = 0;

            /* Toggle LED (simulated) */
            GPIOA->ODR ^= (1U << 5);
            printf("  [Main] LED toggled (PA5 = %u)\n\n",
                   (GPIOA->ODR >> 5) & 1);
        }
    }

    printf("--- ISR Best Practices Summary ---\n\n");
    printf("  1. Keep ISRs SHORT — set a flag, return\n");
    printf("  2. Always CLEAR the interrupt pending flag\n");
    printf("  3. Use VOLATILE for shared variables\n");
    printf("  4. No blocking calls (printf, delay, malloc)\n");
    printf("  5. Use critical sections for multi-byte shared data\n");

    return 0;
}
