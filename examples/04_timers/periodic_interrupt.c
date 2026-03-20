/**
 * Periodic Timer Interrupt
 *
 * Demonstrates how a hardware timer generates periodic interrupts
 * for time-critical operations (e.g., motor control, sampling).
 *
 * The timer counts up to the Auto-Reload value, generates an
 * interrupt, resets, and repeats.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o periodic_interrupt periodic_interrupt.c
 */

#include <stdint.h>
#include <stdio.h>

/* ---- Timer Configuration Calculation ---- */

static void explain_timer_config(void)
{
    printf("=== Timer Configuration ===\n\n");

    printf("A timer counts at a rate determined by:\n");
    printf("  Timer_clock = System_clock / (PSC + 1)\n\n");
    printf("It generates an event every:\n");
    printf("  Period = (ARR + 1) / Timer_clock\n\n");
    printf("Or equivalently:\n");
    printf("  Overflow_freq = System_clock / ((PSC + 1) * (ARR + 1))\n\n");

    printf("--- Example Configurations ---\n\n");

    struct {
        const char *desc;
        uint32_t sys_clk;
        uint32_t psc;
        uint32_t arr;
    } configs[] = {
        {"1 ms (1 kHz) interrupt",    84000000, 83,   999},
        {"10 ms (100 Hz) interrupt",  84000000, 839,  999},
        {"1 second (1 Hz) interrupt", 84000000, 8399, 9999},
        {"50 µs (20 kHz) for PWM",    84000000, 0,    4199},
        {"20 ms (50 Hz) for servo",   84000000, 83,   19999},
    };

    printf("  %-30s  PSC=%5u  ARR=%5u  Freq\n", "Description", 0, 0);
    printf("  %-30s  --------  --------  ----------\n", "");

    for (int i = 0; i < 5; i++) {
        double freq = (double)configs[i].sys_clk /
                      ((configs[i].psc + 1.0) * (configs[i].arr + 1.0));
        printf("  %-30s  PSC=%5u  ARR=%5u  %.1f Hz\n",
               configs[i].desc,
               configs[i].psc, configs[i].arr, freq);
    }
    printf("\n");
}

/* ---- Simulated Timer Registers ---- */

typedef struct {
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t SMCR;
    volatile uint32_t DIER;
    volatile uint32_t SR;
    volatile uint32_t EGR;
    volatile uint32_t CCMR1;
    volatile uint32_t CCMR2;
    volatile uint32_t CCER;
    volatile uint32_t CNT;
    volatile uint32_t PSC;
    volatile uint32_t ARR;
} TIM_TypeDef;

static TIM_TypeDef _tim2 = {0};
#define TIM2 (&_tim2)

/* ---- ISR Variables ---- */

static volatile uint32_t isr_tick_count = 0;
static volatile uint32_t task_a_counter = 0;
static volatile uint32_t task_b_counter = 0;

/* ---- Timer ISR ---- */

void TIM2_IRQHandler(void)
{
    if (TIM2->SR & (1U << 0)) {
        TIM2->SR &= ~(1U << 0);   /* Clear update interrupt flag */

        isr_tick_count++;

        /* Run different tasks at different rates using the ISR */
        task_a_counter++;  /* Every tick */

        if ((isr_tick_count % 10) == 0)
            task_b_counter++;  /* Every 10th tick */
    }
}

/* ---- Timer Initialization ---- */

static void timer_init(uint32_t psc, uint32_t arr)
{
    printf("Initializing TIM2:\n");
    printf("  PSC = %u\n", psc);
    printf("  ARR = %u\n", arr);

    /* In real code: RCC->APB1ENR |= (1U << 0); */

    TIM2->PSC  = psc;
    TIM2->ARR  = arr;
    TIM2->DIER |= (1U << 0);    /* Enable update interrupt */
    TIM2->CR1  |= (1U << 0);    /* Enable counter */

    /* In real code: NVIC_EnableIRQ(TIM2_IRQn); */
    printf("  Timer started, update interrupt enabled\n\n");
}

/* ---- Demo: Periodic Interrupt Simulation ---- */

static void demo_periodic_interrupt(void)
{
    printf("=== Simulating Periodic Interrupts ===\n\n");

    timer_init(83, 999);  /* 84 MHz / (84 * 1000) = 1 kHz */

    printf("Simulating 50 timer ticks:\n");
    printf("  Tick  Task_A  Task_B  Note\n");
    printf("  ----  ------  ------  ----\n");

    for (int i = 0; i < 50; i++) {
        /* Simulate: timer overflow triggers ISR */
        TIM2->SR |= (1U << 0);
        TIM2_IRQHandler();

        if ((isr_tick_count % 10) == 0 || isr_tick_count <= 3) {
            printf("  %4u  %6u  %6u", isr_tick_count, task_a_counter, task_b_counter);
            if ((isr_tick_count % 10) == 0)
                printf("  <-- Task B fires (every 10 ticks)");
            printf("\n");
        }
    }
    printf("  ...\n\n");
}

/* ---- Demo: Multiple Timer Rates ---- */

static void demo_rate_division(void)
{
    printf("=== Rate Division in Timer ISR ===\n\n");

    printf("A single timer ISR can run tasks at different rates\n");
    printf("by using modular counters:\n\n");

    printf("  void TIM2_IRQHandler(void) {\n");
    printf("      TIM2->SR &= ~(1U << 0);\n");
    printf("      tick++;\n\n");
    printf("      // Every tick (1 ms) — fast tasks\n");
    printf("      read_encoder();\n\n");
    printf("      // Every 10 ticks (10 ms) — medium tasks\n");
    printf("      if (tick %% 10 == 0)\n");
    printf("          update_pid_controller();\n\n");
    printf("      // Every 100 ticks (100 ms) — slow tasks\n");
    printf("      if (tick %% 100 == 0)\n");
    printf("          update_display();\n\n");
    printf("      // Every 1000 ticks (1 s) — very slow tasks\n");
    printf("      if (tick %% 1000 == 0)\n");
    printf("          log_telemetry();\n");
    printf("  }\n\n");

    printf("This pattern avoids the overhead of multiple timers\n");
    printf("and keeps all timing synchronized to one source.\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("Periodic Timer Interrupt Demo\n");
    printf("==============================\n\n");

    explain_timer_config();
    demo_periodic_interrupt();
    demo_rate_division();

    return 0;
}
