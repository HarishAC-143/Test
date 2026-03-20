/**
 * Low-Power Sleep Mode Patterns
 *
 * Demonstrates the concepts and patterns used for power-efficient
 * embedded systems. Covers sleep modes, wake-up sources, and
 * power budget estimation.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o sleep_modes sleep_modes.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

/* ---- Power Mode Definitions ---- */

typedef enum {
    MODE_RUN,
    MODE_SLEEP,
    MODE_STOP,
    MODE_STANDBY,
    MODE_SHUTDOWN,
    MODE_COUNT
} PowerMode;

typedef struct {
    const char *name;
    uint32_t   current_ua;   /* Current draw in microamps */
    uint32_t   wakeup_us;    /* Wake-up time in microseconds */
    bool       ram_retained;
    bool       peripherals_active;
    const char *wake_sources;
} ModeInfo;

static const ModeInfo mode_table[] = {
    { "Run @ 80 MHz",   10000,   0, true,  true,  "N/A (already running)" },
    { "Sleep",           1000,   1, true,  true,  "Any interrupt" },
    { "Stop",              10,   5, true,  false, "EXTI, RTC, LPUART" },
    { "Standby",            1,  50, false, false, "WKUP pin, RTC alarm" },
    { "Shutdown",           0,  50, false, false, "WKUP pin only" },
};

/* ---- Power Budget Calculator ---- */

typedef struct {
    const char *phase;
    PowerMode  mode;
    uint32_t   duration_ms;
} DutyCyclePhase;

static void calculate_power_budget(const DutyCyclePhase *phases, uint8_t count,
                                   uint32_t battery_mah)
{
    uint64_t total_charge_ua_ms = 0;
    uint32_t total_duration_ms = 0;

    printf("  Phase             Mode           Duration    Current\n");
    printf("  ------            ----           --------    -------\n");

    for (uint8_t i = 0; i < count; i++) {
        uint32_t current = mode_table[phases[i].mode].current_ua;
        total_charge_ua_ms += (uint64_t)current * phases[i].duration_ms;
        total_duration_ms += phases[i].duration_ms;

        printf("  %-18s %-14s %6u ms   %6u µA\n",
               phases[i].phase,
               mode_table[phases[i].mode].name,
               phases[i].duration_ms,
               current);
    }

    uint32_t avg_current_ua = (uint32_t)(total_charge_ua_ms / total_duration_ms);
    uint32_t battery_hours = battery_mah * 1000 / avg_current_ua;
    uint32_t battery_days = battery_hours / 24;

    printf("\n  Cycle period:       %u ms\n", total_duration_ms);
    printf("  Average current:    %u µA\n", avg_current_ua);
    printf("  Battery capacity:   %u mAh\n", battery_mah);
    printf("  Estimated life:     %u hours (%u days / %.1f years)\n\n",
           battery_hours, battery_days, battery_days / 365.0);
}

/* ---- Demo: Sleep Mode Comparison ---- */

static void demo_mode_comparison(void)
{
    printf("=== Power Mode Comparison ===\n\n");

    printf("  %-18s  %8s  %8s  %-4s  %-6s  %s\n",
           "Mode", "Current", "Wake-up", "RAM", "Periph", "Wake Sources");
    printf("  %-18s  %8s  %8s  %-4s  %-6s  %s\n",
           "--", "--", "--", "--", "--", "--");

    for (int i = 0; i < MODE_COUNT; i++) {
        printf("  %-18s  %5u µA  %5u µs  %-4s  %-6s  %s\n",
               mode_table[i].name,
               mode_table[i].current_ua,
               mode_table[i].wakeup_us,
               mode_table[i].ram_retained ? "Yes" : "No",
               mode_table[i].peripherals_active ? "Yes" : "No",
               mode_table[i].wake_sources);
    }
    printf("\n");
}

/* ---- Demo: IoT Sensor Node ---- */

static void demo_iot_sensor(void)
{
    printf("=== Example: IoT Sensor Node ===\n\n");

    printf("Scenario: Temperature sensor that transmits every 60 seconds.\n");
    printf("Battery: CR2032 coin cell (240 mAh)\n\n");

    DutyCyclePhase phases[] = {
        { "Wake + read ADC",   MODE_RUN,     5    },
        { "Transmit (radio)",  MODE_RUN,     15   },
        { "Sleep",             MODE_STOP,    59980 },
    };

    calculate_power_budget(phases, 3, 240);
}

/* ---- Demo: Wearable Device ---- */

static void demo_wearable(void)
{
    printf("=== Example: Wearable Fitness Tracker ===\n\n");

    printf("Scenario: Accelerometer sampling + hourly BLE sync.\n");
    printf("Battery: 100 mAh LiPo\n\n");

    DutyCyclePhase phases[] = {
        { "Accel sampling",    MODE_RUN,     10   },
        { "Process data",      MODE_RUN,     5    },
        { "Light sleep",       MODE_SLEEP,   985  },
    };

    printf("  --- Per-Second Duty Cycle ---\n\n");
    calculate_power_budget(phases, 3, 100);

    printf("  Note: BLE transmissions (~15 mA for 30 ms every hour)\n");
    printf("  add negligible average current at that duty cycle.\n\n");
}

/* ---- Demo: Event-Driven Architecture ---- */

static void demo_event_driven(void)
{
    printf("=== Event-Driven vs. Polling Architecture ===\n\n");

    printf("  --- Polling (BAD for power) ---\n\n");
    printf("    while (1) {\n");
    printf("        if (button_pressed())    // CPU busy 100%%!\n");
    printf("            handle_button();\n");
    printf("        if (uart_data_ready())\n");
    printf("            handle_uart();\n");
    printf("    }\n\n");

    printf("    Power: ~10 mA (CPU running continuously)\n");
    printf("    Battery life (240 mAh): %u hours = %u days\n\n",
           240000 / 10000, 240000 / 10000 / 24);

    printf("  --- Event-Driven (GOOD for power) ---\n\n");
    printf("    while (1) {\n");
    printf("        __WFI();  // Sleep until interrupt\n\n");
    printf("        if (button_flag) {\n");
    printf("            handle_button();\n");
    printf("            button_flag = 0;\n");
    printf("        }\n");
    printf("        if (uart_flag) {\n");
    printf("            handle_uart();\n");
    printf("            uart_flag = 0;\n");
    printf("        }\n");
    printf("    }\n\n");

    printf("    Power: ~10 µA average (CPU sleeps 99%%+ of the time)\n");
    printf("    Battery life (240 mAh): %u hours = %u days = %.1f years\n\n",
           240000 / 10, 240000 / 10 / 24, 240000.0 / 10 / 24 / 365);
}

/* ---- Checklist ---- */

static void power_optimization_checklist(void)
{
    printf("=== Power Optimization Checklist ===\n\n");

    const char *items[] = {
        "[ ] Disable unused peripheral clocks (RCC->AHBxENR)",
        "[ ] Configure unused GPIO pins as analog inputs",
        "[ ] Reduce clock speed when full performance is not needed",
        "[ ] Use WFI/WFE to sleep between events",
        "[ ] Use Stop mode for long idle periods (RAM retained)",
        "[ ] Use Standby mode for very long sleep (RAM lost)",
        "[ ] Use RTC wake-up for periodic tasks in Stop/Standby",
        "[ ] Disable brown-out detector if voltage is stable",
        "[ ] Use DMA instead of CPU for data transfers",
        "[ ] Minimize time spent in Run mode",
        "[ ] Use low-power UART (LPUART) for receive-in-sleep",
        "[ ] Disable debug interface (SWD) in production",
        "[ ] Measure actual current (don't rely on estimates alone)",
    };

    for (int i = 0; i < 13; i++) {
        printf("  %s\n", items[i]);
    }
}

/* ---- Main ---- */

int main(void)
{
    printf("Low-Power Sleep Mode Patterns\n");
    printf("==============================\n\n");

    demo_mode_comparison();
    demo_iot_sensor();
    demo_wearable();
    demo_event_driven();
    power_optimization_checklist();

    return 0;
}
