/**
 * @file    systick.c
 * @brief   SysTick timer for millisecond timekeeping and delay functions.
 * @target  ARM Cortex-M (any — SysTick is a core peripheral)
 *
 * The SysTick timer is a 24-bit decrementing counter built into every
 * Cortex-M core. It's the simplest way to get accurate timing without
 * using a peripheral timer.
 *
 * Demonstrates:
 *  - SysTick configuration for 1 ms ticks
 *  - Blocking delay_ms()
 *  - Non-blocking timeout pattern
 *  - Periodic callback scheduler (cooperative time-slicing)
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  SysTick Registers (Cortex-M System Control Block)                          */
/* ========================================================================== */

#define SYSTICK_BASE    0xE000E010U

typedef struct {
    volatile uint32_t CTRL;   /* Control and Status */
    volatile uint32_t LOAD;   /* Reload Value       */
    volatile uint32_t VAL;    /* Current Value       */
    volatile uint32_t CALIB;  /* Calibration         */
} SysTick_TypeDef;

#define SysTick     ((SysTick_TypeDef *)SYSTICK_BASE)

#define SYSTICK_CTRL_ENABLE      (1U << 0)
#define SYSTICK_CTRL_TICKINT     (1U << 1)
#define SYSTICK_CTRL_CLKSOURCE   (1U << 2)  /* 1 = processor clock */
#define SYSTICK_CTRL_COUNTFLAG   (1U << 16)

/* ========================================================================== */
/*  Tick Counter                                                               */
/* ========================================================================== */

static volatile uint32_t s_tick_ms = 0;

/**
 * SysTick interrupt handler — called every 1 ms.
 * Increments the global tick counter.
 */
void SysTick_Handler(void)
{
    s_tick_ms++;
}

/* ========================================================================== */
/*  Initialization                                                             */
/* ========================================================================== */

/**
 * Configure SysTick to fire every 1 ms.
 *
 * @param cpu_freq_hz  System clock frequency in Hz (e.g., 168000000 for 168 MHz)
 *
 * The reload value = (clock_freq / desired_freq) - 1
 * For 1 ms at 168 MHz: (168000000 / 1000) - 1 = 167999
 *
 * Max reload = 2^24 - 1 = 16777215 → max period at 168 MHz ≈ 99.9 ms.
 */
void systick_init(uint32_t cpu_freq_hz)
{
    uint32_t ticks_per_ms = cpu_freq_hz / 1000;

    SysTick->LOAD = ticks_per_ms - 1;
    SysTick->VAL  = 0;  /* Writing any value clears the counter and COUNTFLAG */
    SysTick->CTRL = SYSTICK_CTRL_ENABLE
                  | SYSTICK_CTRL_TICKINT
                  | SYSTICK_CTRL_CLKSOURCE;
}

/* ========================================================================== */
/*  Timing Functions                                                           */
/* ========================================================================== */

/**
 * Get the current tick count in milliseconds.
 * Safe to call from any context (ISR or main).
 */
uint32_t millis(void)
{
    return s_tick_ms;
}

/**
 * Get microsecond-resolution timestamp by combining tick count with
 * the SysTick current-value register.
 *
 * Handles the case where SysTick wraps between reading s_tick_ms and VAL.
 */
uint32_t micros(void)
{
    uint32_t ms, val, ms2;

    do {
        ms  = s_tick_ms;
        val = SysTick->VAL;
        ms2 = s_tick_ms;
    } while (ms != ms2);

    uint32_t ticks_per_ms = SysTick->LOAD + 1;
    uint32_t elapsed_us = ((ticks_per_ms - val) * 1000) / ticks_per_ms;

    return ms * 1000 + elapsed_us;
}

/**
 * Blocking delay for the specified number of milliseconds.
 * Uses WFI to sleep between ticks for power efficiency.
 */
void delay_ms(uint32_t ms)
{
    uint32_t start = s_tick_ms;
    while ((s_tick_ms - start) < ms) {
        __asm volatile ("wfi");
    }
}

/* ========================================================================== */
/*  Non-Blocking Timeout Pattern                                               */
/* ========================================================================== */

/**
 * A "software timer" that doesn't block.
 * Use this when you need periodic actions without stalling the main loop.
 */
typedef struct {
    uint32_t interval_ms;
    uint32_t last_trigger;
    bool     running;
} soft_timer_t;

void soft_timer_start(soft_timer_t *timer, uint32_t interval_ms)
{
    timer->interval_ms = interval_ms;
    timer->last_trigger = millis();
    timer->running = true;
}

void soft_timer_stop(soft_timer_t *timer)
{
    timer->running = false;
}

/**
 * Check if the timer has expired. Call this in the main loop.
 * Returns true once per interval period and auto-resets.
 */
bool soft_timer_expired(soft_timer_t *timer)
{
    if (!timer->running) return false;

    uint32_t now = millis();
    if ((now - timer->last_trigger) >= timer->interval_ms) {
        timer->last_trigger += timer->interval_ms;  /* Phase-correct: no drift */
        return true;
    }
    return false;
}

/* ========================================================================== */
/*  Cooperative Scheduler                                                      */
/* ========================================================================== */

typedef void (*task_func_t)(void);

typedef struct {
    task_func_t func;
    uint32_t    period_ms;
    uint32_t    last_run;
    bool        enabled;
} scheduled_task_t;

#define MAX_TASKS   8
static scheduled_task_t s_tasks[MAX_TASKS];
static uint8_t s_task_count = 0;

void scheduler_add_task(task_func_t func, uint32_t period_ms)
{
    if (s_task_count >= MAX_TASKS) return;

    s_tasks[s_task_count].func      = func;
    s_tasks[s_task_count].period_ms = period_ms;
    s_tasks[s_task_count].last_run  = millis();
    s_tasks[s_task_count].enabled   = true;
    s_task_count++;
}

void scheduler_run(void)
{
    uint32_t now = millis();

    for (uint8_t i = 0; i < s_task_count; i++) {
        if (s_tasks[i].enabled &&
            (now - s_tasks[i].last_run) >= s_tasks[i].period_ms) {
            s_tasks[i].last_run += s_tasks[i].period_ms;
            s_tasks[i].func();
        }
    }
}

/* ========================================================================== */
/*  Example Tasks                                                              */
/* ========================================================================== */

static void task_read_sensor(void)
{
    /* Read sensor every 100 ms */
}

static void task_update_display(void)
{
    /* Refresh display every 250 ms */
}

static void task_heartbeat_led(void)
{
    /* Toggle LED every 500 ms */
    /* GPIOA->ODR ^= (1 << 5); */
}

static void task_check_watchdog(void)
{
    /* Feed watchdog every 200 ms */
    /* IWDG->KR = 0xAAAA; */
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    systick_init(168000000);  /* 168 MHz Cortex-M4 */

    /* Register periodic tasks */
    scheduler_add_task(task_read_sensor,     100);
    scheduler_add_task(task_update_display,  250);
    scheduler_add_task(task_heartbeat_led,   500);
    scheduler_add_task(task_check_watchdog,  200);

    /* Main super-loop */
    while (1) {
        scheduler_run();

        /* Other non-periodic work can go here */

        __asm volatile ("wfi");  /* Sleep until next SysTick */
    }
}
