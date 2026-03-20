/**
 * PROJECT: Temperature Monitoring System
 *
 * A complete temperature monitoring system that reads from an ADC,
 * applies a moving average filter, checks against configurable
 * thresholds with hysteresis, and outputs formatted data via UART.
 *
 * Concepts demonstrated:
 *   - ADC reading and voltage conversion
 *   - Moving average digital filter
 *   - Hysteresis-based threshold detection
 *   - State machine for alert management
 *   - Timer-driven periodic sampling
 *   - Formatted serial output
 *
 * This example runs on a host PC with simulated hardware.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

/* ================================================================
 * Configuration
 * ================================================================ */
#define SAMPLE_PERIOD_MS     1000
#define FILTER_WINDOW_SIZE   8
#define ADC_RESOLUTION       4096
#define ADC_VREF             3.3f

/* Temperature thresholds (in °C × 10 for integer math) */
#define TEMP_WARN_HIGH       350    /* 35.0 °C */
#define TEMP_ALARM_HIGH      450    /* 45.0 °C */
#define TEMP_WARN_LOW        100    /* 10.0 °C */
#define TEMP_ALARM_LOW       50     /*  5.0 °C */
#define TEMP_HYSTERESIS      20     /*  2.0 °C */

/* ================================================================
 * Simulated Hardware
 * ================================================================ */
static float sim_actual_temperature = 22.0f;
static float sim_temp_drift = 0.8f;
static uint32_t sim_time_ms = 0;

static uint16_t hw_adc_read(void) {
    /* Simulate LM35: 10 mV/°C */
    float voltage = sim_actual_temperature * 0.01f;
    float noise = ((float)(rand() % 100) - 50.0f) / 5000.0f;
    voltage += noise;

    if (voltage < 0) voltage = 0;
    if (voltage > ADC_VREF) voltage = ADC_VREF;

    return (uint16_t)((voltage / ADC_VREF) * (ADC_RESOLUTION - 1));
}

/* ================================================================
 * Moving Average Filter
 * ================================================================ */
typedef struct {
    int16_t  samples[FILTER_WINDOW_SIZE];
    uint8_t  index;
    uint8_t  count;
    int32_t  sum;
} TempFilter;

static void filter_init(TempFilter *f) {
    memset(f, 0, sizeof(*f));
}

static int16_t filter_add(TempFilter *f, int16_t sample) {
    f->sum -= f->samples[f->index];
    f->samples[f->index] = sample;
    f->sum += sample;
    f->index = (f->index + 1) % FILTER_WINDOW_SIZE;
    if (f->count < FILTER_WINDOW_SIZE) f->count++;
    return (int16_t)(f->sum / f->count);
}

/* ================================================================
 * Alert State Machine
 * ================================================================ */
typedef enum {
    ALERT_NORMAL,
    ALERT_WARN_HIGH,
    ALERT_ALARM_HIGH,
    ALERT_WARN_LOW,
    ALERT_ALARM_LOW
} AlertState;

static const char *alert_state_names[] = {
    "NORMAL", "WARN_HIGH", "ALARM_HIGH", "WARN_LOW", "ALARM_LOW"
};

static const char *alert_icons[] = {
    "  [OK]  ", " [WARN] ", "[ALARM!]", " [WARN] ", "[ALARM!]"
};

typedef struct {
    AlertState state;
    uint32_t   entered_at;
    uint32_t   alert_count;
} AlertManager;

static void alert_init(AlertManager *am) {
    am->state = ALERT_NORMAL;
    am->entered_at = 0;
    am->alert_count = 0;
}

static AlertState alert_evaluate(AlertManager *am, int16_t temp_x10, uint32_t now) {
    AlertState prev = am->state;
    AlertState next = prev;

    switch (prev) {
    case ALERT_NORMAL:
        if (temp_x10 >= TEMP_ALARM_HIGH)
            next = ALERT_ALARM_HIGH;
        else if (temp_x10 >= TEMP_WARN_HIGH)
            next = ALERT_WARN_HIGH;
        else if (temp_x10 <= TEMP_ALARM_LOW)
            next = ALERT_ALARM_LOW;
        else if (temp_x10 <= TEMP_WARN_LOW)
            next = ALERT_WARN_LOW;
        break;

    case ALERT_WARN_HIGH:
        if (temp_x10 >= TEMP_ALARM_HIGH)
            next = ALERT_ALARM_HIGH;
        else if (temp_x10 < TEMP_WARN_HIGH - TEMP_HYSTERESIS)
            next = ALERT_NORMAL;
        break;

    case ALERT_ALARM_HIGH:
        if (temp_x10 < TEMP_ALARM_HIGH - TEMP_HYSTERESIS)
            next = ALERT_WARN_HIGH;
        break;

    case ALERT_WARN_LOW:
        if (temp_x10 <= TEMP_ALARM_LOW)
            next = ALERT_ALARM_LOW;
        else if (temp_x10 > TEMP_WARN_LOW + TEMP_HYSTERESIS)
            next = ALERT_NORMAL;
        break;

    case ALERT_ALARM_LOW:
        if (temp_x10 > TEMP_ALARM_LOW + TEMP_HYSTERESIS)
            next = ALERT_WARN_LOW;
        break;
    }

    if (next != prev) {
        am->state = next;
        am->entered_at = now;
        am->alert_count++;
    }

    return next;
}

/* ================================================================
 * Statistics
 * ================================================================ */
typedef struct {
    int16_t  min;
    int16_t  max;
    int32_t  sum;
    uint32_t count;
} TempStats;

static void stats_init(TempStats *s) {
    s->min = INT16_MAX;
    s->max = INT16_MIN;
    s->sum = 0;
    s->count = 0;
}

static void stats_update(TempStats *s, int16_t value) {
    if (value < s->min) s->min = value;
    if (value > s->max) s->max = value;
    s->sum += value;
    s->count++;
}

static int16_t stats_average(const TempStats *s) {
    return (s->count > 0) ? (int16_t)(s->sum / s->count) : 0;
}

/* ================================================================
 * Temperature Conversion
 * ================================================================ */
static int16_t adc_to_temp_x10(uint16_t adc_raw) {
    /* LM35: 10 mV/°C */
    float voltage = ((float)adc_raw / (ADC_RESOLUTION - 1)) * ADC_VREF;
    float temp_c = voltage / 0.01f;
    return (int16_t)(temp_c * 10.0f);
}

/* ================================================================
 * Display Functions
 * ================================================================ */
static void print_bar(int16_t temp_x10, int16_t min_x10, int16_t max_x10) {
    int bar_width = 30;
    int pos = (int)((float)(temp_x10 - min_x10) / (max_x10 - min_x10) * bar_width);
    if (pos < 0) pos = 0;
    if (pos > bar_width) pos = bar_width;

    printf("[");
    for (int i = 0; i < bar_width; i++) {
        if (i == pos) printf("|");
        else if (i == (TEMP_WARN_LOW - min_x10) * bar_width / (max_x10 - min_x10)) printf("w");
        else if (i == (TEMP_WARN_HIGH - min_x10) * bar_width / (max_x10 - min_x10)) printf("W");
        else if (i == (TEMP_ALARM_HIGH - min_x10) * bar_width / (max_x10 - min_x10)) printf("A");
        else printf("-");
    }
    printf("]");
}

/* ================================================================
 * Main Application
 * ================================================================ */
int main(void) {
    srand((unsigned int)time(NULL));

    printf("╔══════════════════════════════════════════════╗\n");
    printf("║  Temperature Monitoring System               ║\n");
    printf("╚══════════════════════════════════════════════╝\n\n");

    printf("  Configuration:\n");
    printf("    Sample period:  %d ms\n", SAMPLE_PERIOD_MS);
    printf("    Filter window:  %d samples\n", FILTER_WINDOW_SIZE);
    printf("    Warn high:      %.1f °C\n", TEMP_WARN_HIGH / 10.0f);
    printf("    Alarm high:     %.1f °C\n", TEMP_ALARM_HIGH / 10.0f);
    printf("    Warn low:       %.1f °C\n", TEMP_WARN_LOW / 10.0f);
    printf("    Alarm low:      %.1f °C\n", TEMP_ALARM_LOW / 10.0f);
    printf("    Hysteresis:     %.1f °C\n\n", TEMP_HYSTERESIS / 10.0f);

    TempFilter filter;
    AlertManager alert;
    TempStats stats;

    filter_init(&filter);
    alert_init(&alert);
    stats_init(&stats);

    printf("  Time(s)  Raw   Voltage  RawTemp  Filtered  Status     Bar\n");
    printf("  -------  ----  -------  -------  --------  --------   ---\n");

    /* Simulate temperature changes over time */
    for (int i = 0; i < 40; i++) {
        sim_time_ms += SAMPLE_PERIOD_MS;

        /* Simulate temperature drift */
        sim_actual_temperature += sim_temp_drift;
        if (sim_actual_temperature > 50.0f) sim_temp_drift = -1.2f;
        if (sim_actual_temperature < 3.0f) sim_temp_drift = 1.0f;

        /* Read ADC */
        uint16_t adc_raw = hw_adc_read();
        float voltage = ((float)adc_raw / (ADC_RESOLUTION - 1)) * ADC_VREF;

        /* Convert and filter */
        int16_t raw_temp = adc_to_temp_x10(adc_raw);
        int16_t filtered_temp = filter_add(&filter, raw_temp);

        /* Update stats */
        stats_update(&stats, filtered_temp);

        /* Evaluate alert */
        alert_evaluate(&alert, filtered_temp, sim_time_ms);

        /* Output */
        printf("  %5u    %4u  %5.3f V  %5.1f°C  %5.1f°C   %s ",
               sim_time_ms / 1000,
               adc_raw,
               voltage,
               raw_temp / 10.0f,
               filtered_temp / 10.0f,
               alert_icons[alert.state]);

        print_bar(filtered_temp, 0, 550);
        printf("\n");
    }

    /* Print summary */
    printf("\n  ═══ Session Summary ═══\n\n");
    printf("    Duration:       %u seconds\n", sim_time_ms / 1000);
    printf("    Samples:        %u\n", stats.count);
    printf("    Min temperature: %.1f °C\n", stats.min / 10.0f);
    printf("    Max temperature: %.1f °C\n", stats.max / 10.0f);
    printf("    Avg temperature: %.1f °C\n", stats_average(&stats) / 10.0f);
    printf("    Alert transitions: %u\n", alert.alert_count);
    printf("    Final state:    %s\n\n", alert_state_names[alert.state]);

    return 0;
}
