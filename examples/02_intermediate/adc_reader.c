/**
 * ADC (Analog-to-Digital Converter) Reader
 *
 * Demonstrates ADC concepts: single and multi-channel readings,
 * voltage conversion, averaging filters, and oversampling.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

/* ----------------------------------------------------------------
 * ADC configuration constants
 * ---------------------------------------------------------------- */
#define ADC_RESOLUTION_BITS  12
#define ADC_MAX_VALUE        ((1 << ADC_RESOLUTION_BITS) - 1)  /* 4095 */
#define ADC_VREF             3.3f
#define ADC_NUM_CHANNELS     4

/* ----------------------------------------------------------------
 * Simulated ADC
 * ---------------------------------------------------------------- */
static float sim_analog_voltages[ADC_NUM_CHANNELS] = {
    1.65f,   /* Channel 0: mid-range voltage */
    0.82f,   /* Channel 1: quarter range */
    2.50f,   /* Channel 2: ~76% of range */
    3.10f    /* Channel 3: near max */
};

static uint16_t adc_simulate_read(uint8_t channel) {
    if (channel >= ADC_NUM_CHANNELS) return 0;

    float ideal = (sim_analog_voltages[channel] / ADC_VREF) * ADC_MAX_VALUE;

    /* Add realistic noise (±0.5% of full scale) */
    float noise = ((float)(rand() % 100) - 50.0f) / 100.0f * ADC_MAX_VALUE * 0.005f;
    float raw = ideal + noise;

    if (raw < 0) raw = 0;
    if (raw > ADC_MAX_VALUE) raw = ADC_MAX_VALUE;

    return (uint16_t)raw;
}

/* ----------------------------------------------------------------
 * Conversion utilities
 * ---------------------------------------------------------------- */
static float adc_to_voltage(uint16_t raw) {
    return ((float)raw / ADC_MAX_VALUE) * ADC_VREF;
}

static float adc_to_temperature_lm35(uint16_t raw) {
    /* LM35: 10 mV/°C, output = temperature × 0.01 V */
    float voltage = adc_to_voltage(raw);
    return voltage / 0.01f;
}

static float adc_to_temperature_ntc(uint16_t raw) {
    /*
     * NTC thermistor in voltage divider (10kΩ pull-up):
     *   V_adc = Vref × R_ntc / (R_pullup + R_ntc)
     *   R_ntc = R_pullup × V_adc / (Vref - V_adc)
     *   Then use Steinhart-Hart equation for temperature.
     */
    float v = adc_to_voltage(raw);
    if (v >= ADC_VREF - 0.01f) return -999.0f;

    float r_pullup = 10000.0f;
    float r_ntc = r_pullup * v / (ADC_VREF - v);

    /* Simplified Steinhart-Hart: 1/T = A + B*ln(R) + C*ln(R)^3 */
    float a = 1.009249e-3f;
    float b = 2.378405e-4f;
    float c = 2.019202e-7f;

    float ln_r = logf(r_ntc);
    float inv_t = a + b * ln_r + c * ln_r * ln_r * ln_r;
    float temp_k = 1.0f / inv_t;

    return temp_k - 273.15f;
}

/* ----------------------------------------------------------------
 * Demo: Basic single-channel reading
 * ---------------------------------------------------------------- */
static void demo_single_read(void) {
    printf("=== ADC: Single Channel Reading ===\n\n");

    printf("  ADC Configuration:\n");
    printf("    Resolution: %d bits (%d levels)\n", ADC_RESOLUTION_BITS, ADC_MAX_VALUE + 1);
    printf("    Reference:  %.2f V\n", ADC_VREF);
    printf("    Step size:  %.4f mV\n\n", (ADC_VREF / (ADC_MAX_VALUE + 1)) * 1000);

    printf("  Channel 0 readings (actual voltage: %.2f V):\n\n", sim_analog_voltages[0]);
    printf("  Reading   Raw    Voltage   Error\n");
    printf("  -------   ----   -------   -----\n");

    for (int i = 0; i < 8; i++) {
        uint16_t raw = adc_simulate_read(0);
        float voltage = adc_to_voltage(raw);
        float error = voltage - sim_analog_voltages[0];
        printf("    %d       %4u   %.4f V  %+.4f V\n", i + 1, raw, voltage, error);
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Multi-channel scanning
 * ---------------------------------------------------------------- */
static void demo_multi_channel(void) {
    printf("=== ADC: Multi-Channel Scan ===\n\n");

    printf("  Scanning %d channels:\n\n", ADC_NUM_CHANNELS);
    printf("  Channel  Expected   Raw    Measured   Error\n");
    printf("  -------  --------   ----   --------   -----\n");

    for (int ch = 0; ch < ADC_NUM_CHANNELS; ch++) {
        uint16_t raw = adc_simulate_read((uint8_t)ch);
        float measured = adc_to_voltage(raw);
        float error_pct = 100.0f * (measured - sim_analog_voltages[ch]) / sim_analog_voltages[ch];

        printf("    %d      %.2f V   %4u   %.4f V   %+.2f%%\n",
               ch, sim_analog_voltages[ch], raw, measured, error_pct);
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Moving average filter
 * ---------------------------------------------------------------- */
#define AVG_WINDOW_SIZE 8

typedef struct {
    uint16_t samples[AVG_WINDOW_SIZE];
    uint8_t  index;
    uint8_t  count;
    uint32_t sum;
} MovingAverage;

static void mavg_init(MovingAverage *ma) {
    ma->index = 0;
    ma->count = 0;
    ma->sum = 0;
    for (int i = 0; i < AVG_WINDOW_SIZE; i++) {
        ma->samples[i] = 0;
    }
}

static uint16_t mavg_add(MovingAverage *ma, uint16_t sample) {
    ma->sum -= ma->samples[ma->index];
    ma->samples[ma->index] = sample;
    ma->sum += sample;
    ma->index = (ma->index + 1) % AVG_WINDOW_SIZE;

    if (ma->count < AVG_WINDOW_SIZE) ma->count++;

    return (uint16_t)(ma->sum / ma->count);
}

static void demo_moving_average(void) {
    printf("=== ADC: Moving Average Filter ===\n\n");

    MovingAverage filter;
    mavg_init(&filter);

    printf("  Window size: %d samples\n", AVG_WINDOW_SIZE);
    printf("  Input channel: 0 (actual: %.2f V)\n\n", sim_analog_voltages[0]);

    printf("  Sample   Raw    Filtered  Raw(V)    Filt(V)   Samples in window\n");
    printf("  ------   ----   --------  --------  --------  -----------------\n");

    for (int i = 0; i < 16; i++) {
        uint16_t raw = adc_simulate_read(0);
        uint16_t filtered = mavg_add(&filter, raw);

        printf("    %2d     %4u     %4u    %.4f V  %.4f V       %d\n",
               i + 1, raw, filtered,
               adc_to_voltage(raw), adc_to_voltage(filtered),
               filter.count);
    }

    printf("\n  The filtered signal converges toward the true value\n");
    printf("  as the window fills with samples.\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Oversampling for higher resolution
 * ---------------------------------------------------------------- */
static void demo_oversampling(void) {
    printf("=== ADC: Oversampling for Extra Resolution ===\n\n");

    /*
     * Oversampling theory:
     *   To gain N extra bits of resolution, take 4^N samples and
     *   divide by 2^N (or equivalently, sum 4^N samples and right-shift by N).
     *
     *   +1 bit:  4 samples,   >> 1   → 13-bit
     *   +2 bits: 16 samples,  >> 2   → 14-bit
     *   +3 bits: 64 samples,  >> 3   → 15-bit
     *   +4 bits: 256 samples, >> 4   → 16-bit
     */

    printf("  Native resolution: %d bits (%d levels)\n\n", ADC_RESOLUTION_BITS, ADC_MAX_VALUE + 1);

    struct { int extra_bits; int num_samples; } configs[] = {
        { 1,  4   },
        { 2,  16  },
        { 3,  64  },
        { 4,  256 },
    };
    int n = sizeof(configs) / sizeof(configs[0]);

    printf("  Extra Bits  Samples  Eff. Resolution  Result        Voltage\n");
    printf("  ----------  -------  ---------------  ------        -------\n");

    for (int c = 0; c < n; c++) {
        uint32_t sum = 0;
        for (int i = 0; i < configs[c].num_samples; i++) {
            sum += adc_simulate_read(0);
        }
        uint32_t oversampled = sum >> configs[c].extra_bits;
        int eff_bits = ADC_RESOLUTION_BITS + configs[c].extra_bits;
        float voltage = ((float)oversampled / ((1 << eff_bits) - 1)) * ADC_VREF;

        printf("    +%d          %3d        %2d-bit        %5u         %.4f V\n",
               configs[c].extra_bits, configs[c].num_samples,
               eff_bits, oversampled, voltage);
    }

    printf("\n  Oversampling trades speed for resolution.\n");
    printf("  Requires uncorrelated noise in the signal.\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Temperature sensor readings
 * ---------------------------------------------------------------- */
static void demo_temperature_sensor(void) {
    printf("=== ADC: Temperature Sensor Interfacing ===\n\n");

    /* Simulate LM35 at 25°C: output = 25 × 10 mV = 0.250 V */
    sim_analog_voltages[0] = 0.250f;

    printf("  LM35 Temperature Sensor (10 mV/°C):\n\n");
    printf("  Reading   Raw    Voltage    Temperature\n");
    printf("  -------   ----   -------    -----------\n");

    for (int i = 0; i < 5; i++) {
        uint16_t raw = adc_simulate_read(0);
        float voltage = adc_to_voltage(raw);
        float temp = adc_to_temperature_lm35(raw);
        printf("    %d       %4u   %.4f V    %.1f °C\n",
               i + 1, raw, voltage, temp);
    }

    /* Simulate NTC thermistor at ~25°C */
    /* At 25°C, NTC = 10kΩ, so voltage divider gives Vref/2 */
    sim_analog_voltages[1] = ADC_VREF / 2.0f;

    printf("\n  NTC Thermistor (10kΩ at 25°C, voltage divider):\n\n");
    printf("  Reading   Raw    Voltage    R_NTC      Temperature\n");
    printf("  -------   ----   -------    -------    -----------\n");

    for (int i = 0; i < 5; i++) {
        uint16_t raw = adc_simulate_read(1);
        float voltage = adc_to_voltage(raw);
        float r_ntc = 10000.0f * voltage / (ADC_VREF - voltage);
        float temp = adc_to_temperature_ntc(raw);
        printf("    %d       %4u   %.4f V    %.0f Ω   %.1f °C\n",
               i + 1, raw, voltage, r_ntc, temp);
    }

    /* Restore original voltages */
    sim_analog_voltages[0] = 1.65f;
    sim_analog_voltages[1] = 0.82f;

    printf("\n");
}

int main(void) {
    srand((unsigned int)time(NULL));

    printf("╔══════════════════════════════════════════╗\n");
    printf("║  ADC (Analog-to-Digital Converter)       ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_single_read();
    demo_multi_channel();
    demo_moving_average();
    demo_oversampling();
    demo_temperature_sensor();

    printf("═══ End of ADC Reader Demo ═══\n");
    return 0;
}
