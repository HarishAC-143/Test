/**
 * SysTick Timer — Millisecond Delay
 *
 * Demonstrates how to use the ARM Cortex-M SysTick timer to maintain
 * a system tick counter and provide accurate millisecond delays.
 *
 * Key concepts:
 *   - SysTick configuration
 *   - Overflow-safe elapsed time calculation
 *   - Non-blocking delay using tick counter
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o systick_delay systick_delay.c
 */

#include <stdint.h>
#include <stdio.h>

/* ---- System Tick Counter ---- */

/*
 * In real code, this is incremented by the SysTick_Handler ISR.
 * volatile because it's shared between the ISR and main code.
 */
static volatile uint32_t system_ticks = 0;

/*
 * SysTick_Handler — called every 1 ms by the SysTick timer.
 *
 * void SysTick_Handler(void)
 * {
 *     system_ticks++;
 * }
 */

static void simulated_tick(void)
{
    system_ticks++;
}

/* ---- SysTick Initialization ---- */

static void systick_init_explained(void)
{
    printf("=== SysTick Initialization ===\n\n");

    printf("The SysTick timer is a 24-bit down-counter built into\n");
    printf("every ARM Cortex-M core. Registers:\n\n");

    printf("  SysTick->CTRL  — Control: enable, interrupt, clock source\n");
    printf("  SysTick->LOAD  — Reload value (counter resets to this)\n");
    printf("  SysTick->VAL   — Current counter value\n\n");

    printf("Configuration for 1 ms tick (assuming 168 MHz clock):\n\n");
    printf("  SysTick->LOAD = (168000000 / 1000) - 1;  // = 167999\n");
    printf("  SysTick->VAL  = 0;                        // Clear counter\n");
    printf("  SysTick->CTRL = (1 << 2) |   // Processor clock source\n");
    printf("                  (1 << 1) |   // Enable interrupt\n");
    printf("                  (1 << 0);    // Enable counter\n\n");

    printf("The counter counts down from LOAD to 0, then:\n");
    printf("  1. Reloads the LOAD value\n");
    printf("  2. Sets the COUNTFLAG\n");
    printf("  3. Triggers the SysTick_Handler ISR\n\n");
}

/* ---- Delay Functions ---- */

static uint32_t get_tick(void)
{
    return system_ticks;
}

/*
 * Blocking delay — waits for 'ms' milliseconds.
 * Uses subtraction to handle uint32_t overflow correctly.
 */
static void delay_ms(uint32_t ms)
{
    uint32_t start = get_tick();
    while ((get_tick() - start) < ms) {
        simulated_tick();  /* In real code, the ISR handles this */
    }
}

/* ---- Overflow-Safe Timing ---- */

static void demo_overflow_safety(void)
{
    printf("=== Overflow-Safe Timing ===\n\n");

    printf("uint32_t wraps at 4,294,967,295 (~49.7 days at 1 ms/tick).\n");
    printf("Using subtraction handles wraparound correctly:\n\n");

    /* Simulate near-overflow scenario */
    uint32_t near_max = UINT32_MAX - 5;  /* 5 ticks before overflow */

    printf("  start_tick = %u (near max)\n", near_max);
    printf("  current_tick after overflow = %u\n", near_max + 10);
    printf("  elapsed = current - start = %u - %u = %u ms\n\n",
           near_max + 10, near_max, (near_max + 10) - near_max);

    printf("Even though the counter wrapped, subtraction gives\n");
    printf("the correct elapsed time (10 ms).\n\n");

    printf("WRONG approach (does NOT handle overflow):\n");
    printf("  if (current_tick > start_tick + timeout)  // FAILS at overflow!\n\n");
    printf("CORRECT approach:\n");
    printf("  if ((current_tick - start_tick) >= timeout)  // Always works!\n\n");
}

/* ---- Non-Blocking Timer Pattern ---- */

typedef struct {
    uint32_t start;
    uint32_t interval;
} SoftTimer;

static void timer_start(SoftTimer *t, uint32_t interval_ms)
{
    t->start = get_tick();
    t->interval = interval_ms;
}

static int timer_expired(SoftTimer *t)
{
    if ((get_tick() - t->start) >= t->interval) {
        t->start += t->interval;  /* Reset for next period */
        return 1;
    }
    return 0;
}

static void demo_non_blocking_timers(void)
{
    printf("=== Non-Blocking Timer Pattern ===\n\n");

    printf("Instead of blocking delays, use soft timers:\n\n");
    printf("  SoftTimer led_timer, sensor_timer;\n");
    printf("  timer_start(&led_timer, 500);      // 500 ms\n");
    printf("  timer_start(&sensor_timer, 100);   // 100 ms\n\n");
    printf("  while (1) {\n");
    printf("      if (timer_expired(&led_timer))\n");
    printf("          toggle_led();\n");
    printf("      if (timer_expired(&sensor_timer))\n");
    printf("          read_sensor();\n");
    printf("  }\n\n");

    printf("Simulating 20 ticks with two timers:\n");
    printf("  LED timer: every 5 ticks\n");
    printf("  Sensor timer: every 3 ticks\n\n");

    SoftTimer led_timer, sensor_timer;
    timer_start(&led_timer, 5);
    timer_start(&sensor_timer, 3);

    printf("  Tick  LED    Sensor\n");
    printf("  ----  -----  ------\n");
    for (int tick = 0; tick < 20; tick++) {
        int led_fire = timer_expired(&led_timer);
        int sensor_fire = timer_expired(&sensor_timer);

        if (led_fire || sensor_fire) {
            printf("  %4d  %-5s  %-6s\n", tick,
                   led_fire ? "FIRE" : "  -",
                   sensor_fire ? "FIRE" : "  -");
        }
        simulated_tick();
    }
    printf("\n");

    printf("Both timers run independently without blocking.\n");
    printf("The main loop stays responsive to all events.\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("SysTick Timer — Millisecond Delay Demo\n");
    printf("========================================\n\n");

    systick_init_explained();
    demo_overflow_safety();
    demo_non_blocking_timers();

    return 0;
}
