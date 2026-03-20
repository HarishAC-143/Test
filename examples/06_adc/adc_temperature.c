/**
 * Internal Temperature Sensor Reading
 *
 * Demonstrates reading the MCU's internal temperature sensor via ADC
 * and converting the raw value to degrees Celsius.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o adc_temperature adc_temperature.c
 */

#include <stdint.h>
#include <stdio.h>

/* ---- Constants ---- */

#define ADC_MAX        4095
#define VREF_MV        3300

/* STM32F4 internal temp sensor calibration values */
#define V25_MV         760    /* Voltage at 25°C (typical) */
#define AVG_SLOPE_UV   2500   /* Average slope: 2.5 mV/°C = 2500 µV/°C */

/* ---- Simulated ADC Readings ---- */

static const uint16_t temp_readings[] = {
    930, 935, 940, 945, 950,  /* Cold (~0°C range) */
    980, 985, 990, 995, 1000, /* Room temp (~25°C range) */
    1050, 1060, 1070, 1080,   /* Warm (~40-50°C range) */
};

#define NUM_READINGS (sizeof(temp_readings) / sizeof(temp_readings[0]))

/* ---- Temperature Conversion ---- */

/*
 * STM32F4 formula:
 *   Temperature (°C) = ((Vsense - V25) / Avg_Slope) + 25
 *
 * Where:
 *   Vsense = ADC reading converted to mV
 *   V25 = voltage at 25°C (760 mV typical)
 *   Avg_Slope = 2.5 mV/°C
 */

static int32_t adc_to_temperature_c(uint16_t adc_value)
{
    int32_t vsense_mv = (int32_t)adc_value * VREF_MV / ADC_MAX;
    int32_t temp_c = ((vsense_mv - V25_MV) * 1000 / AVG_SLOPE_UV) + 25;
    return temp_c;
}

/* Fixed-point version (10x resolution: 250 = 25.0°C) */
static int32_t adc_to_temperature_10x(uint16_t adc_value)
{
    int32_t vsense_mv = (int32_t)adc_value * VREF_MV / ADC_MAX;
    int32_t temp_10x = ((vsense_mv - V25_MV) * 10000 / AVG_SLOPE_UV) + 250;
    return temp_10x;
}

/* ---- Averaging for Stable Readings ---- */

static int32_t read_temperature_averaged(const uint16_t *readings, uint8_t count)
{
    uint32_t sum = 0;
    for (uint8_t i = 0; i < count; i++) {
        sum += readings[i];
    }
    uint16_t avg = (uint16_t)(sum / count);
    return adc_to_temperature_c(avg);
}

/* ---- Demo ---- */

static void demo_temp_conversion(void)
{
    printf("=== Internal Temperature Sensor ===\n\n");

    printf("Most MCUs have a built-in temperature sensor connected to\n");
    printf("an ADC channel. It measures the die temperature, not ambient.\n\n");

    printf("STM32F4 calibration values:\n");
    printf("  V25 (voltage at 25°C): %d mV\n", V25_MV);
    printf("  Average slope: %d µV/°C (%.1f mV/°C)\n\n",
           AVG_SLOPE_UV, AVG_SLOPE_UV / 1000.0);

    printf("Formula:\n");
    printf("  Temp(°C) = ((Vsense_mV - %d) / %.1f) + 25\n\n",
           V25_MV, AVG_SLOPE_UV / 1000.0);

    printf("  ADC Raw    Vsense(mV)    Temp(°C)    Temp(10x)\n");
    printf("  --------   ----------    --------    ---------\n");

    for (uint32_t i = 0; i < NUM_READINGS; i++) {
        uint16_t raw = temp_readings[i];
        int32_t vsense = (int32_t)raw * VREF_MV / ADC_MAX;
        int32_t temp = adc_to_temperature_c(raw);
        int32_t temp10 = adc_to_temperature_10x(raw);

        printf("  %8u   %10d    %8d    %4d.%d\n",
               raw, vsense, temp, temp10 / 10, (temp10 < 0 ? -temp10 : temp10) % 10);
    }
    printf("\n");
}

static void demo_temperature_monitoring(void)
{
    printf("=== Temperature Monitoring System ===\n\n");

    printf("Typical use cases for internal temperature sensor:\n");
    printf("  - Thermal protection (shutdown if MCU overheats)\n");
    printf("  - Temperature compensation for ADC readings\n");
    printf("  - Logging operating conditions\n\n");

    int32_t warning_threshold = 60;
    int32_t critical_threshold = 80;

    printf("  Threshold configuration:\n");
    printf("    Warning:  %d°C\n", warning_threshold);
    printf("    Critical: %d°C\n\n", critical_threshold);

    printf("  Simulated monitoring output:\n\n");

    /* Average groups of readings */
    uint8_t group_size = 5;
    for (uint32_t g = 0; g < NUM_READINGS / group_size; g++) {
        int32_t temp = read_temperature_averaged(
            &temp_readings[g * group_size], group_size);

        const char *status;
        if (temp >= critical_threshold)
            status = "CRITICAL — shutdown required!";
        else if (temp >= warning_threshold)
            status = "WARNING — reduce clock speed";
        else
            status = "OK";

        printf("    Sample group %u: %d°C — %s\n", g + 1, temp, status);
    }
    printf("\n");

    printf("  Implementation pattern:\n\n");
    printf("    void thermal_monitor(void) {\n");
    printf("        int32_t temp = read_mcu_temperature();\n");
    printf("        if (temp > CRITICAL_TEMP) {\n");
    printf("            emergency_shutdown();\n");
    printf("        } else if (temp > WARNING_TEMP) {\n");
    printf("            reduce_clock_speed();\n");
    printf("            set_warning_led();\n");
    printf("        }\n");
    printf("    }\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("Internal Temperature Sensor Demo\n");
    printf("=================================\n\n");

    demo_temp_conversion();
    demo_temperature_monitoring();

    return 0;
}
