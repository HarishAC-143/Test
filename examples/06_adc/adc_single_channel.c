/**
 * Single-Channel ADC Reading
 *
 * Demonstrates ADC configuration, conversion, and voltage calculation
 * with both floating-point and fixed-point approaches.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -lm -o adc_single_channel adc_single_channel.c
 */

#include <stdint.h>
#include <stdio.h>
#include <math.h>

/* ---- ADC Configuration Constants ---- */

#define ADC_RESOLUTION   12
#define ADC_MAX_VALUE    ((1U << ADC_RESOLUTION) - 1)  /* 4095 */
#define VREF_MV          3300  /* Reference voltage in millivolts */

/* ---- Simulated ADC Readings ---- */

static const uint16_t simulated_readings[] = {
    0, 512, 1024, 1365, 2048, 2731, 3072, 3584, 4095,
    /* Simulate a noisy sensor */
    2048, 2055, 2040, 2060, 2035, 2050, 2045, 2058, 2042, 2051,
    2047, 2053, 2039, 2062, 2044, 2056, 2048, 2050, 2041, 2057,
};

#define NUM_READINGS (sizeof(simulated_readings) / sizeof(simulated_readings[0]))

static uint32_t reading_idx = 0;

static uint16_t adc_read(void)
{
    uint16_t val = simulated_readings[reading_idx % NUM_READINGS];
    reading_idx++;
    return val;
}

/* ---- Voltage Conversion ---- */

static float adc_to_voltage_float(uint16_t adc_value)
{
    return (float)adc_value * 3.3f / (float)ADC_MAX_VALUE;
}

static uint32_t adc_to_millivolts(uint16_t adc_value)
{
    return (uint32_t)adc_value * VREF_MV / ADC_MAX_VALUE;
}

/* ---- Software Averaging ---- */

static uint16_t adc_read_averaged(uint8_t num_samples)
{
    uint32_t sum = 0;
    for (uint8_t i = 0; i < num_samples; i++) {
        sum += adc_read();
    }
    return (uint16_t)(sum / num_samples);
}

/* ---- Moving Average Filter ---- */

#define MA_WINDOW 8

typedef struct {
    uint16_t samples[MA_WINDOW];
    uint8_t  index;
    uint32_t sum;
    uint8_t  count;
} MovingAverage;

static void ma_init(MovingAverage *ma)
{
    for (int i = 0; i < MA_WINDOW; i++)
        ma->samples[i] = 0;
    ma->index = 0;
    ma->sum = 0;
    ma->count = 0;
}

static uint16_t ma_update(MovingAverage *ma, uint16_t new_sample)
{
    ma->sum -= ma->samples[ma->index];
    ma->samples[ma->index] = new_sample;
    ma->sum += new_sample;
    ma->index = (ma->index + 1) % MA_WINDOW;
    if (ma->count < MA_WINDOW) ma->count++;
    return (uint16_t)(ma->sum / ma->count);
}

/* ---- Demo ---- */

static void demo_basic_conversion(void)
{
    printf("=== ADC Basics ===\n\n");

    printf("  Resolution: %u bits\n", ADC_RESOLUTION);
    printf("  Max value:  %u\n", ADC_MAX_VALUE);
    printf("  Vref:       %u mV (%.1f V)\n\n", VREF_MV, VREF_MV / 1000.0);

    printf("  Conversion formulas:\n");
    printf("    Voltage = (ADC_value / %u) × %.1f V\n", ADC_MAX_VALUE, VREF_MV / 1000.0);
    printf("    ADC_value = (Voltage / %.1f) × %u\n\n", VREF_MV / 1000.0, ADC_MAX_VALUE);

    printf("  ADC Value    Float (V)    Integer (mV)    Fraction\n");
    printf("  ---------    ---------    ------------    --------\n");

    reading_idx = 0;
    for (int i = 0; i < 9; i++) {
        uint16_t raw = adc_read();
        float voltage = adc_to_voltage_float(raw);
        uint32_t mv = adc_to_millivolts(raw);

        printf("  %9u    %9.4f    %12u    %u/%u\n",
               raw, voltage, mv, raw, ADC_MAX_VALUE);
    }
    printf("\n");
}

static void demo_noise_filtering(void)
{
    printf("=== Noise Filtering ===\n\n");

    printf("Raw ADC readings from a noisy sensor (nominal ~2048):\n\n");

    MovingAverage ma;
    ma_init(&ma);

    printf("  Sample  Raw    MA(%d)   Deviation\n", MA_WINDOW);
    printf("  ------  ----   ------   ---------\n");

    reading_idx = 9;  /* Start at the noisy readings */
    for (int i = 0; i < 20; i++) {
        uint16_t raw = adc_read();
        uint16_t filtered = ma_update(&ma, raw);
        int16_t deviation = (int16_t)raw - 2048;

        printf("  %6d  %4u   %6u     %+4d\n",
               i + 1, raw, filtered, deviation);
    }

    printf("\n  The moving average smooths out noise.\n");
    printf("  Larger window = smoother but slower response.\n\n");

    printf("  Oversampling: Read 16 samples, sum, shift right by 2.\n");
    printf("  This gives you 2 extra bits of effective resolution.\n");
    printf("  (12-bit ADC → 14-bit effective with 16x oversampling)\n");
}

static void demo_practical_sensors(void)
{
    printf("\n=== Practical Sensor Examples ===\n\n");

    /* Potentiometer: 0-3.3V maps to 0-100% */
    printf("1. Potentiometer (voltage divider):\n");
    uint16_t pot_raw = 2048;
    uint32_t pot_percent = (uint32_t)pot_raw * 100 / ADC_MAX_VALUE;
    printf("   Raw=%u → %u%%\n\n", pot_raw, pot_percent);

    /* LM35 temperature sensor: 10 mV/°C */
    printf("2. LM35 Temperature Sensor (10 mV/°C):\n");
    uint16_t temp_raw = 310;
    uint32_t temp_mv = adc_to_millivolts(temp_raw);
    uint32_t temp_c = temp_mv / 10;
    printf("   Raw=%u → %u mV → %u °C\n\n", temp_raw, temp_mv, temp_c);

    /* Voltage divider for battery monitoring */
    printf("3. Battery Monitor (voltage divider R1=10k, R2=10k):\n");
    uint16_t bat_raw = 2048;
    uint32_t bat_mv = adc_to_millivolts(bat_raw);
    uint32_t actual_mv = bat_mv * 2;  /* Voltage divider ratio = 2:1 */
    printf("   Raw=%u → ADC=%u mV → Battery=%u mV (%.2f V)\n\n",
           bat_raw, bat_mv, actual_mv, actual_mv / 1000.0);

    /* Light-dependent resistor */
    printf("4. LDR (Light-Dependent Resistor) with 10k pull-down:\n");
    printf("   High ADC value = bright, Low ADC value = dark\n");
    uint16_t thresholds[] = {500, 1500, 2500, 3500};
    const char *levels[] = {"Dark", "Dim", "Normal", "Bright"};
    for (int i = 0; i < 4; i++) {
        printf("   Raw=%u → %s (%u mV)\n",
               thresholds[i], levels[i], adc_to_millivolts(thresholds[i]));
    }
}

/* ---- Main ---- */

int main(void)
{
    printf("Single-Channel ADC Reading Demo\n");
    printf("================================\n\n");

    demo_basic_conversion();
    demo_noise_filtering();
    demo_practical_sensors();

    return 0;
}
