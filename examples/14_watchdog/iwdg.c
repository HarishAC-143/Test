/**
 * @file    iwdg.c
 * @brief   Independent Watchdog Timer (IWDG) driver and usage patterns.
 * @target  STM32F4xx
 *
 * The watchdog timer resets the microcontroller if software hangs, enters
 * an infinite loop, or fails to complete its main loop within the timeout.
 * It must be periodically "fed" (refreshed) to prevent a reset.
 *
 * The IWDG uses the LSI oscillator (~32 kHz), which runs independently
 * of the main clock — it works even if the main oscillator fails.
 *
 * Demonstrates:
 *  - IWDG configuration and timeout calculation
 *  - Proper watchdog feeding in a super-loop
 *  - Watchdog feeding in an RTOS environment
 *  - Detecting watchdog-caused resets
 *  - Window watchdog (WWDG) concept
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

typedef struct {
    volatile uint32_t KR;     /* 0x00: Key register       */
    volatile uint32_t PR;     /* 0x04: Prescaler register  */
    volatile uint32_t RLR;    /* 0x08: Reload register     */
    volatile uint32_t SR;     /* 0x0C: Status register     */
} IWDG_TypeDef;

#define IWDG    ((IWDG_TypeDef *)0x40003000U)

/* Key register values */
#define IWDG_KEY_ENABLE     0xCCCCU
#define IWDG_KEY_WRITE      0x5555U
#define IWDG_KEY_REFRESH    0xAAAAU

/* Prescaler divider values (LSI ≈ 32 kHz) */
#define IWDG_PR_DIV4        0   /* 32000/4   = 8000 Hz  → max 512 ms    */
#define IWDG_PR_DIV8        1   /* 32000/8   = 4000 Hz  → max 1024 ms   */
#define IWDG_PR_DIV16       2   /* 32000/16  = 2000 Hz  → max 2048 ms   */
#define IWDG_PR_DIV32       3   /* 32000/32  = 1000 Hz  → max 4096 ms   */
#define IWDG_PR_DIV64       4   /* 32000/64  = 500  Hz  → max 8192 ms   */
#define IWDG_PR_DIV128      5   /* 32000/128 = 250  Hz  → max 16384 ms  */
#define IWDG_PR_DIV256      6   /* 32000/256 = 125  Hz  → max 32768 ms  */

/* RCC Reset Status */
#define RCC_CSR         (*(volatile uint32_t *)0x40023874U)
#define RCC_CSR_IWDGRSTF    (1U << 29)  /* IWDG reset flag      */
#define RCC_CSR_WWDGRSTF    (1U << 30)  /* WWDG reset flag      */
#define RCC_CSR_LPWRRSTF    (1U << 31)  /* Low-power reset flag */
#define RCC_CSR_RMVF        (1U << 24)  /* Clear reset flags    */

/* ========================================================================== */
/*  IWDG Driver                                                                */
/* ========================================================================== */

/**
 * Initialize the Independent Watchdog Timer.
 *
 * Once started, the IWDG CANNOT be stopped (hardware limitation).
 * This is a safety feature — malicious or buggy code can't disable it.
 *
 * @param timeout_ms  Desired timeout in milliseconds (max depends on prescaler)
 *
 * Timeout calculation:
 *   timeout = (reload + 1) × prescaler / LSI_freq
 *   reload  = (timeout × LSI_freq / prescaler) - 1
 *
 * Example: 1000 ms with DIV64
 *   reload = (1.0 × 32000 / 64) - 1 = 499
 */
void iwdg_init(uint32_t timeout_ms)
{
    /* Start IWDG */
    IWDG->KR = IWDG_KEY_ENABLE;

    /* Enable register writes */
    IWDG->KR = IWDG_KEY_WRITE;

    /* Select prescaler and calculate reload value */
    uint32_t prescaler;
    uint32_t divider;
    uint32_t reload;

    /* Auto-select the smallest prescaler that fits the timeout */
    if (timeout_ms <= 512) {
        prescaler = IWDG_PR_DIV4;
        divider = 4;
    } else if (timeout_ms <= 1024) {
        prescaler = IWDG_PR_DIV8;
        divider = 8;
    } else if (timeout_ms <= 2048) {
        prescaler = IWDG_PR_DIV16;
        divider = 16;
    } else if (timeout_ms <= 4096) {
        prescaler = IWDG_PR_DIV32;
        divider = 32;
    } else if (timeout_ms <= 8192) {
        prescaler = IWDG_PR_DIV64;
        divider = 64;
    } else if (timeout_ms <= 16384) {
        prescaler = IWDG_PR_DIV128;
        divider = 128;
    } else {
        prescaler = IWDG_PR_DIV256;
        divider = 256;
    }

    IWDG->PR = prescaler;

    reload = (timeout_ms * 32) / divider - 1;
    if (reload > 0xFFF) reload = 0xFFF;  /* Max 12-bit value */
    IWDG->RLR = reload;

    /* Wait for registers to be updated */
    while (IWDG->SR != 0) { }

    /* Initial refresh */
    IWDG->KR = IWDG_KEY_REFRESH;
}

/**
 * Feed (refresh) the watchdog timer.
 * Must be called before the timeout expires to prevent reset.
 */
void iwdg_feed(void)
{
    IWDG->KR = IWDG_KEY_REFRESH;
}

/* ========================================================================== */
/*  Reset Cause Detection                                                      */
/* ========================================================================== */

typedef enum {
    RESET_CAUSE_UNKNOWN,
    RESET_CAUSE_POWER_ON,
    RESET_CAUSE_IWDG,        /* Independent watchdog */
    RESET_CAUSE_WWDG,        /* Window watchdog      */
    RESET_CAUSE_SOFTWARE,
    RESET_CAUSE_LOW_POWER,
    RESET_CAUSE_PIN           /* External NRST pin    */
} reset_cause_t;

/**
 * Determine what caused the last reset.
 * Call this early in main() before clearing the flags.
 */
reset_cause_t get_reset_cause(void)
{
    uint32_t csr = RCC_CSR;

    /* Clear all reset flags for next time */
    RCC_CSR |= RCC_CSR_RMVF;

    if (csr & RCC_CSR_IWDGRSTF)  return RESET_CAUSE_IWDG;
    if (csr & RCC_CSR_WWDGRSTF)  return RESET_CAUSE_WWDG;
    if (csr & RCC_CSR_LPWRRSTF)  return RESET_CAUSE_LOW_POWER;
    if (csr & (1U << 28))        return RESET_CAUSE_SOFTWARE;
    if (csr & (1U << 26))        return RESET_CAUSE_PIN;

    return RESET_CAUSE_POWER_ON;
}

/* ========================================================================== */
/*  Watchdog Patterns                                                          */
/* ========================================================================== */

/*
 * Pattern 1: Simple super-loop feeding.
 * The watchdog is fed once per main loop iteration.
 * If any function in the loop hangs, the watchdog triggers.
 */
void pattern_superloop(void)
{
    iwdg_init(1000);  /* 1-second timeout */

    while (1) {
        /* All of these must complete within 1 second combined */
        /* read_sensors(); */
        /* process_data(); */
        /* update_outputs(); */
        /* check_communications(); */

        iwdg_feed();
    }
}

/*
 * Pattern 2: Task-based feeding with health checks.
 * Instead of feeding the watchdog directly, each task reports its health.
 * A monitor task only feeds the watchdog if all tasks are healthy.
 */

#define NUM_MONITORED_TASKS  4

typedef struct {
    volatile bool alive[NUM_MONITORED_TASKS];
    uint32_t check_interval_ms;
    uint32_t last_check_ms;
} health_monitor_t;

static health_monitor_t monitor;

void health_monitor_init(uint32_t check_interval_ms)
{
    for (int i = 0; i < NUM_MONITORED_TASKS; i++) {
        monitor.alive[i] = false;
    }
    monitor.check_interval_ms = check_interval_ms;
    monitor.last_check_ms = 0;
}

/**
 * Each task calls this to report it's still running.
 * @param task_id  Index of the reporting task (0 to NUM_MONITORED_TASKS-1)
 */
void health_report_alive(uint8_t task_id)
{
    if (task_id < NUM_MONITORED_TASKS) {
        monitor.alive[task_id] = true;
    }
}

/**
 * Monitor task: checks all tasks and feeds watchdog only if all are healthy.
 * Call this periodically (e.g., every 200 ms).
 */
void health_monitor_check(uint32_t now_ms)
{
    if ((now_ms - monitor.last_check_ms) < monitor.check_interval_ms) {
        return;
    }
    monitor.last_check_ms = now_ms;

    bool all_alive = true;
    for (int i = 0; i < NUM_MONITORED_TASKS; i++) {
        if (!monitor.alive[i]) {
            all_alive = false;
            break;
        }
    }

    if (all_alive) {
        iwdg_feed();

        /* Reset all flags — tasks must report again before next check */
        for (int i = 0; i < NUM_MONITORED_TASKS; i++) {
            monitor.alive[i] = false;
        }
    }
    /* If not all alive → watchdog will eventually reset the system */
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

extern void uart_printf(const char *fmt, ...);

int main(void)
{
    /* system_init(); */
    /* uart_init(115200); */

    /* Check why we reset */
    reset_cause_t cause = get_reset_cause();

    switch (cause) {
    case RESET_CAUSE_IWDG:
        uart_printf("WARNING: Reset by watchdog!\r\n");
        /* Log error, possibly enter safe mode */
        break;
    case RESET_CAUSE_POWER_ON:
        uart_printf("Power-on reset.\r\n");
        break;
    default:
        uart_printf("Reset cause: %d\r\n", cause);
        break;
    }

    /* Start watchdog with 2-second timeout */
    iwdg_init(2000);

    /* Set up health monitoring */
    health_monitor_init(500);  /* Check every 500 ms */

    while (1) {
        /* Simulated tasks */
        /* task_sensor();    → health_report_alive(0); */
        /* task_comms();     → health_report_alive(1); */
        /* task_display();   → health_report_alive(2); */
        /* task_control();   → health_report_alive(3); */

        health_monitor_check(0 /* millis() */);
    }
}
