/**
 * Low-Power Mode Management
 *
 * Demonstrates power management concepts: sleep modes, clock gating,
 * power budgeting, and wake-up source configuration.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>

/* ----------------------------------------------------------------
 * Power mode definitions
 * ---------------------------------------------------------------- */
typedef enum {
    POWER_RUN,
    POWER_SLEEP,
    POWER_STOP,
    POWER_STANDBY,
    POWER_SHUTDOWN,
    NUM_POWER_MODES
} PowerMode;

typedef struct {
    const char *name;
    float       current_uA;
    float       wakeup_time_us;
    bool        ram_retained;
    bool        rtc_active;
    bool        gpio_wake;
    const char *description;
} PowerModeInfo;

static const PowerModeInfo power_modes[NUM_POWER_MODES] = {
    {
        .name = "Run",
        .current_uA = 15000.0f,
        .wakeup_time_us = 0,
        .ram_retained = true,
        .rtc_active = true,
        .gpio_wake = true,
        .description = "Full speed, all peripherals available"
    },
    {
        .name = "Sleep",
        .current_uA = 2000.0f,
        .wakeup_time_us = 1.0f,
        .ram_retained = true,
        .rtc_active = true,
        .gpio_wake = true,
        .description = "CPU halted, peripherals run, fast wake-up"
    },
    {
        .name = "Stop",
        .current_uA = 5.0f,
        .wakeup_time_us = 5.0f,
        .ram_retained = true,
        .rtc_active = true,
        .gpio_wake = true,
        .description = "Most clocks stopped, RAM retained"
    },
    {
        .name = "Standby",
        .current_uA = 1.5f,
        .wakeup_time_us = 50.0f,
        .ram_retained = false,
        .rtc_active = true,
        .gpio_wake = true,
        .description = "RAM lost, only RTC and wake-up pins active"
    },
    {
        .name = "Shutdown",
        .current_uA = 0.3f,
        .wakeup_time_us = 500.0f,
        .ram_retained = false,
        .rtc_active = false,
        .gpio_wake = true,
        .description = "Absolute minimum power, GPIO wake only"
    },
};

/* ----------------------------------------------------------------
 * Simulated peripheral clock gating
 * ---------------------------------------------------------------- */
typedef struct {
    const char *name;
    float       current_mA;
    bool        enabled;
} Peripheral;

#define NUM_PERIPHERALS 8

static Peripheral peripherals[NUM_PERIPHERALS] = {
    { "GPIOA",   0.1f,  true  },
    { "GPIOB",   0.1f,  true  },
    { "USART1",  0.5f,  true  },
    { "USART2",  0.5f,  false },
    { "SPI1",    0.3f,  true  },
    { "I2C1",    0.2f,  false },
    { "TIM2",    0.2f,  true  },
    { "ADC1",    1.0f,  false },
};

/* ----------------------------------------------------------------
 * Demo: Power mode comparison
 * ---------------------------------------------------------------- */
static void demo_power_modes(void) {
    printf("=== Power Mode Comparison ===\n\n");

    printf("  %-10s  %10s  %10s  %5s  %5s  %5s\n",
           "Mode", "Current", "Wake-up", "RAM", "RTC", "GPIO");
    printf("  %-10s  %10s  %10s  %5s  %5s  %5s\n",
           "----------", "----------", "----------", "-----", "-----", "-----");

    for (int i = 0; i < NUM_POWER_MODES; i++) {
        const PowerModeInfo *m = &power_modes[i];
        char current_str[16];

        if (m->current_uA >= 1000)
            snprintf(current_str, sizeof(current_str), "%.1f mA", m->current_uA / 1000);
        else
            snprintf(current_str, sizeof(current_str), "%.1f µA", m->current_uA);

        printf("  %-10s  %10s  %8.0f µs  %-5s  %-5s  %-5s\n",
               m->name, current_str, m->wakeup_time_us,
               m->ram_retained ? "Yes" : "No",
               m->rtc_active ? "Yes" : "No",
               m->gpio_wake ? "Yes" : "No");
    }

    printf("\n  Notes:\n");
    for (int i = 0; i < NUM_POWER_MODES; i++) {
        printf("    %s: %s\n", power_modes[i].name, power_modes[i].description);
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Clock gating to reduce power
 * ---------------------------------------------------------------- */
static void demo_clock_gating(void) {
    printf("=== Clock Gating (Disable Unused Peripherals) ===\n\n");

    float total_before = 0;
    printf("  Before optimization (all clocks enabled):\n\n");
    printf("  %-10s  %8s  %8s\n", "Peripheral", "Current", "Status");
    printf("  %-10s  %8s  %8s\n", "----------", "--------", "--------");

    for (int i = 0; i < NUM_PERIPHERALS; i++) {
        printf("  %-10s  %5.1f mA  %s\n",
               peripherals[i].name,
               peripherals[i].current_mA,
               peripherals[i].enabled ? "ACTIVE" : "unused");
        total_before += peripherals[i].current_mA;
    }
    printf("  %-10s  %5.1f mA\n\n", "TOTAL:", total_before);

    float total_after = 0;
    printf("  After clock gating (disable unused peripherals):\n\n");
    printf("  %-10s  %8s  %8s\n", "Peripheral", "Current", "Status");
    printf("  %-10s  %8s  %8s\n", "----------", "--------", "--------");

    for (int i = 0; i < NUM_PERIPHERALS; i++) {
        float current = peripherals[i].enabled ? peripherals[i].current_mA : 0.001f;
        printf("  %-10s  %5.3f mA  %s\n",
               peripherals[i].name, current,
               peripherals[i].enabled ? "ACTIVE" : "GATED");
        total_after += current;
    }
    printf("  %-10s  %5.3f mA\n\n", "TOTAL:", total_after);

    printf("  Savings: %.1f mA (%.0f%% reduction in peripheral current)\n\n",
           total_before - total_after,
           100.0f * (1.0f - total_after / total_before));
}

/* ----------------------------------------------------------------
 * Demo: Power budget calculation
 * ---------------------------------------------------------------- */
typedef struct {
    const char *component;
    float       current_active_mA;
    float       current_sleep_mA;
    float       duty_cycle;
} BudgetEntry;

static void demo_power_budget(void) {
    printf("=== Power Budget Calculator ===\n\n");

    BudgetEntry budget[] = {
        { "MCU (Run mode)",     15.0f,   0.005f,  0.02f  },
        { "MCU (Sleep mode)",    2.0f,   0.005f,  0.98f  },
        { "Temperature sensor",  0.5f,   0.001f,  0.01f  },
        { "Humidity sensor",     0.8f,   0.001f,  0.01f  },
        { "LoRa radio TX",     120.0f,   0.002f,  0.001f },
        { "LoRa radio RX",      12.0f,   0.002f,  0.005f },
        { "Status LED",          5.0f,   0.0f,    0.005f },
        { "Voltage regulator",   0.01f,  0.01f,   1.0f   },
    };
    int n = sizeof(budget) / sizeof(budget[0]);

    float battery_capacity_mAh = 2400.0f;

    printf("  IoT Sensor Node Power Budget\n");
    printf("  Battery: %.0f mAh (CR123A lithium)\n\n", battery_capacity_mAh);

    printf("  %-24s  %8s  %8s  %8s  %10s\n",
           "Component", "Active", "Sleep", "Duty", "Avg Current");
    printf("  %-24s  %8s  %8s  %8s  %10s\n",
           "------------------------", "--------", "--------", "--------", "----------");

    float total_avg = 0;

    for (int i = 0; i < n; i++) {
        float avg = budget[i].current_active_mA * budget[i].duty_cycle
                  + budget[i].current_sleep_mA * (1.0f - budget[i].duty_cycle);
        total_avg += avg;

        printf("  %-24s  %5.1f mA  %5.3f mA  %5.1f%%  %7.4f mA\n",
               budget[i].component,
               budget[i].current_active_mA,
               budget[i].current_sleep_mA,
               budget[i].duty_cycle * 100.0f,
               avg);
    }

    printf("  %-24s  %8s  %8s  %8s  %7.4f mA\n",
           "TOTAL", "", "", "", total_avg);

    float hours = battery_capacity_mAh / total_avg;
    float days = hours / 24.0f;
    float years = days / 365.0f;

    printf("\n  Estimated battery life:\n");
    printf("    %.0f hours = %.1f days = %.2f years\n\n", hours, days, years);

    /* Show what-if analysis */
    printf("  What-if: Reduce MCU duty cycle from 2%% to 0.5%%:\n");
    float reduced_avg = total_avg - (15.0f * 0.02f) + (15.0f * 0.005f);
    float reduced_years = (battery_capacity_mAh / reduced_avg) / (24.0f * 365.0f);
    printf("    New average: %.4f mA → %.2f years (+%.0f%%)\n\n",
           reduced_avg, reduced_years,
           100.0f * (reduced_years / years - 1.0f));
}

/* ----------------------------------------------------------------
 * Demo: Wake-up source configuration
 * ---------------------------------------------------------------- */
typedef enum {
    WAKE_RTC_ALARM,
    WAKE_GPIO_PIN,
    WAKE_UART_ACTIVITY,
    WAKE_COMPARATOR,
    WAKE_WATCHDOG,
    NUM_WAKE_SOURCES
} WakeSource;

static const char *wake_source_names[] = {
    "RTC Alarm", "GPIO Pin", "UART Activity", "Comparator", "Watchdog"
};

static void demo_wake_sources(void) {
    printf("=== Wake-Up Source Configuration ===\n\n");

    /* Compatibility matrix: which sources work in which modes */
    bool compat[NUM_WAKE_SOURCES][NUM_POWER_MODES] = {
        /* RTC */   { true,  true,  true,  true,  false },
        /* GPIO */  { true,  true,  true,  true,  true  },
        /* UART */  { true,  true,  true,  false, false },
        /* COMP */  { true,  true,  true,  false, false },
        /* WDG */   { true,  true,  false, false, false },
    };

    printf("  Wake source availability by power mode:\n\n");
    printf("  %-16s", "");
    for (int m = 0; m < NUM_POWER_MODES; m++) {
        printf("  %-9s", power_modes[m].name);
    }
    printf("\n  %-16s", "");
    for (int m = 0; m < NUM_POWER_MODES; m++) {
        printf("  %-9s", "---------");
    }
    printf("\n");

    for (int w = 0; w < NUM_WAKE_SOURCES; w++) {
        printf("  %-16s", wake_source_names[w]);
        for (int m = 0; m < NUM_POWER_MODES; m++) {
            printf("  %-9s", compat[w][m] ? "Yes" : "---");
        }
        printf("\n");
    }

    printf("\n  Typical wake-up strategies:\n");
    printf("    1. Periodic sensor reading: RTC alarm every 60 s → Stop mode\n");
    printf("    2. Button press: GPIO falling edge → Sleep or Stop\n");
    printf("    3. Incoming data: UART start bit detect → Sleep\n");
    printf("    4. Threshold crossing: Comparator → Stop mode\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Sleep/wake duty cycle simulation
 * ---------------------------------------------------------------- */
static void demo_duty_cycle(void) {
    printf("=== Sleep/Wake Duty Cycle Simulation ===\n\n");

    float wake_time_ms = 50.0f;
    float sleep_time_ms = 9950.0f;
    float total_period = wake_time_ms + sleep_time_ms;
    float duty_cycle = wake_time_ms / total_period;

    float run_current = 15.0f;
    float stop_current = 0.005f;

    printf("  Scenario: Sensor node waking every 10 seconds\n\n");
    printf("    Wake time:    %.0f ms (read sensors, transmit data)\n", wake_time_ms);
    printf("    Sleep time:   %.0f ms (Stop mode)\n", sleep_time_ms);
    printf("    Total period: %.0f ms\n", total_period);
    printf("    Duty cycle:   %.2f%%\n\n", duty_cycle * 100.0f);

    printf("  Timeline (each char = 500 ms):\n\n  ");
    for (int i = 0; i < 40; i++) {
        float t = i * 500.0f;
        float in_period = fmodf(t, total_period);
        printf("%c", in_period < wake_time_ms ? '#' : '.');
    }
    printf("\n  ");
    for (int i = 0; i < 40; i++) {
        if (i % 20 == 0) printf("▲");
        else printf(" ");
    }
    printf("\n  ");
    printf("wake                    wake\n\n");

    float avg_current = run_current * duty_cycle + stop_current * (1.0f - duty_cycle);
    printf("  Average current: %.3f mA\n", avg_current);
    printf("  vs always running: %.1f mA (%.0f× reduction!)\n\n",
           run_current, run_current / avg_current);
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Low-Power Mode Management               ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_power_modes();
    demo_clock_gating();
    demo_power_budget();
    demo_wake_sources();
    demo_duty_cycle();

    printf("═══ End of Low-Power Mode Demo ═══\n");
    return 0;
}
