/**
 * Embedded C Data Types and Qualifiers Demo
 *
 * Demonstrates fixed-width integer types, volatile, const, and static
 * qualifiers as used in embedded systems.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o data_types data_types.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

/* ---------- Fixed-Width Integer Types ---------- */

static void demo_fixed_width_types(void)
{
    uint8_t  sensor_id   = 42;
    int8_t   temperature = -15;
    uint16_t adc_reading = 3200;
    int16_t  motor_speed = -1500;
    uint32_t timestamp   = 1000000;
    int32_t  encoder_pos = -234567;

    printf("=== Fixed-Width Integer Types ===\n");
    printf("uint8_t  sensor_id   = %u   (size: %zu bytes)\n", sensor_id, sizeof(sensor_id));
    printf("int8_t   temperature = %d   (size: %zu bytes)\n", temperature, sizeof(temperature));
    printf("uint16_t adc_reading = %u  (size: %zu bytes)\n", adc_reading, sizeof(adc_reading));
    printf("int16_t  motor_speed = %d (size: %zu bytes)\n", motor_speed, sizeof(motor_speed));
    printf("uint32_t timestamp   = %u  (size: %zu bytes)\n", timestamp, sizeof(timestamp));
    printf("int32_t  encoder_pos = %d (size: %zu bytes)\n\n", encoder_pos, sizeof(encoder_pos));
}

/* ---------- The volatile Qualifier ---------- */

/*
 * In real embedded code, this would be a hardware register address.
 * volatile prevents the compiler from optimizing away repeated reads.
 */
static volatile uint32_t simulated_hardware_register = 0;

/*
 * Simulates polling a hardware status register.
 * Without volatile, the compiler would read the register once and loop forever.
 */
static void demo_volatile(void)
{
    printf("=== volatile Qualifier ===\n");

    simulated_hardware_register = 0x00000042;
    volatile uint32_t *reg = &simulated_hardware_register;

    printf("Register value: 0x%08X\n", *reg);
    printf("In real code, this register would be at a fixed hardware address\n");
    printf("e.g., #define STATUS_REG (*(volatile uint32_t *)0x40001000)\n\n");
}

/* ---------- The const Qualifier ---------- */

/*
 * On an embedded target, const data at file scope is placed in Flash
 * (read-only memory), saving precious RAM.
 */
static const uint8_t sine_table[16] = {
    128, 176, 218, 245, 255, 245, 218, 176,
    128,  79,  37,  10,   0,  10,  37,  79
};

static const uint32_t BAUD_RATE = 115200;

static void demo_const(void)
{
    printf("=== const Qualifier ===\n");
    printf("BAUD_RATE = %u (stored in Flash on embedded targets)\n", BAUD_RATE);
    printf("Sine table (stored in Flash, saves RAM):\n  ");
    for (int i = 0; i < 16; i++) {
        printf("%3u ", sine_table[i]);
    }
    printf("\n\n");
}

/* ---------- The static Qualifier ---------- */

/*
 * static local variable: retains value between function calls.
 * Used for counters, state tracking, and accumulated values.
 */
static uint32_t get_tick_count(void)
{
    static uint32_t ticks = 0;
    return ticks++;
}

static void demo_static(void)
{
    printf("=== static Local Variables ===\n");
    printf("Calling get_tick_count() repeatedly:\n");
    for (int i = 0; i < 5; i++) {
        printf("  Call %d: tick = %u\n", i + 1, get_tick_count());
    }
    printf("The counter persists between calls.\n\n");
}

/* ---------- Type Size Comparison ---------- */

static void demo_type_sizes(void)
{
    printf("=== Type Sizes on This Platform ===\n");
    printf("char:      %zu bytes\n", sizeof(char));
    printf("short:     %zu bytes\n", sizeof(short));
    printf("int:       %zu bytes\n", sizeof(int));
    printf("long:      %zu bytes\n", sizeof(long));
    printf("long long: %zu bytes\n", sizeof(long long));
    printf("float:     %zu bytes\n", sizeof(float));
    printf("double:    %zu bytes\n", sizeof(double));
    printf("void*:     %zu bytes\n", sizeof(void *));
    printf("bool:      %zu bytes\n", sizeof(bool));
    printf("\n");
    printf("On a 32-bit ARM MCU, int and long are typically 4 bytes,\n");
    printf("but on an 8-bit AVR, int is 2 bytes and long is 4 bytes.\n");
    printf("This is why we use fixed-width types (uint8_t, uint16_t, etc.)\n");
}

/* ---------- Main ---------- */

int main(void)
{
    printf("Embedded C Data Types and Qualifiers Demo\n");
    printf("==========================================\n\n");

    demo_fixed_width_types();
    demo_volatile();
    demo_const();
    demo_static();
    demo_type_sizes();

    return 0;
}
