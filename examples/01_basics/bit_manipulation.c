/**
 * Embedded C Bit Manipulation Demo
 *
 * Demonstrates the fundamental bit operations used in every embedded project:
 * set, clear, toggle, test, and multi-bit field manipulation.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o bit_manipulation bit_manipulation.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

/* ---------- Bit Manipulation Macros ---------- */

#define BIT(n)              (1U << (n))
#define BIT_SET(reg, n)     ((reg) |= BIT(n))
#define BIT_CLEAR(reg, n)   ((reg) &= ~BIT(n))
#define BIT_TOGGLE(reg, n)  ((reg) ^= BIT(n))
#define BIT_CHECK(reg, n)   (((reg) >> (n)) & 1U)

#define FIELD_SET(reg, mask, shift, val) \
    ((reg) = ((reg) & ~((mask) << (shift))) | (((val) & (mask)) << (shift)))

#define FIELD_GET(reg, mask, shift) \
    (((reg) >> (shift)) & (mask))

/* ---------- Helper: Print Binary ---------- */

static void print_binary(const char *label, uint32_t value, int bits)
{
    printf("%-20s = 0x%08X = ", label, value);
    for (int i = bits - 1; i >= 0; i--) {
        printf("%c", (value & (1U << i)) ? '1' : '0');
        if (i > 0 && i % 4 == 0)
            printf("_");
    }
    printf("\n");
}

/* ---------- Demo: Basic Bit Operations ---------- */

static void demo_basic_operations(void)
{
    printf("=== Basic Bit Operations ===\n\n");

    uint32_t reg = 0x00000000;
    print_binary("Initial", reg, 16);

    BIT_SET(reg, 5);
    print_binary("After SET bit 5", reg, 16);

    BIT_SET(reg, 0);
    BIT_SET(reg, 3);
    print_binary("After SET bits 0,3", reg, 16);

    BIT_CLEAR(reg, 3);
    print_binary("After CLEAR bit 3", reg, 16);

    BIT_TOGGLE(reg, 5);
    print_binary("After TOGGLE bit 5", reg, 16);

    BIT_TOGGLE(reg, 5);
    print_binary("After TOGGLE bit 5", reg, 16);

    printf("\nBit 5 is %s\n", BIT_CHECK(reg, 5) ? "SET" : "CLEAR");
    printf("Bit 3 is %s\n", BIT_CHECK(reg, 3) ? "SET" : "CLEAR");
    printf("\n");
}

/* ---------- Demo: Multi-Bit Fields ---------- */

static void demo_multi_bit_fields(void)
{
    printf("=== Multi-Bit Field Operations ===\n\n");
    printf("Simulating GPIO MODER register (2 bits per pin):\n");
    printf("  00 = Input, 01 = Output, 10 = Alt Function, 11 = Analog\n\n");

    uint32_t moder = 0x00000000;
    print_binary("Initial MODER", moder, 16);

    /* Set pin 0 to Output (01) at bits [1:0] */
    FIELD_SET(moder, 0x3, 0, 0x1);
    print_binary("Pin 0 = Output", moder, 16);

    /* Set pin 1 to Alt Function (10) at bits [3:2] */
    FIELD_SET(moder, 0x3, 2, 0x2);
    print_binary("Pin 1 = AF", moder, 16);

    /* Set pin 5 to Output (01) at bits [11:10] */
    FIELD_SET(moder, 0x3, 10, 0x1);
    print_binary("Pin 5 = Output", moder, 16);

    /* Set pin 7 to Analog (11) at bits [15:14] */
    FIELD_SET(moder, 0x3, 14, 0x3);
    print_binary("Pin 7 = Analog", moder, 16);

    /* Read back pin modes */
    printf("\nReading pin modes:\n");
    const char *mode_names[] = {"Input", "Output", "AltFunc", "Analog"};
    for (int pin = 0; pin < 8; pin++) {
        uint32_t mode = FIELD_GET(moder, 0x3, pin * 2);
        printf("  Pin %d: %s (%u)\n", pin, mode_names[mode], mode);
    }
    printf("\n");
}

/* ---------- Demo: Practical Patterns ---------- */

static uint8_t count_set_bits(uint32_t value)
{
    uint8_t count = 0;
    while (value) {
        value &= (value - 1);  /* Brian Kernighan's trick */
        count++;
    }
    return count;
}

static bool is_power_of_two(uint32_t value)
{
    return value && !(value & (value - 1));
}

static void demo_practical_patterns(void)
{
    printf("=== Practical Bit Patterns ===\n\n");

    /* Counting set bits */
    uint32_t test_values[] = {0x00, 0xFF, 0x0F, 0xA5, 0xFFFF};
    printf("Population count (number of 1-bits):\n");
    for (int i = 0; i < 5; i++) {
        printf("  count_set_bits(0x%04X) = %u\n",
               test_values[i], count_set_bits(test_values[i]));
    }

    /* Power of two check */
    printf("\nPower-of-two check:\n");
    uint32_t pow2_values[] = {0, 1, 2, 3, 4, 7, 8, 15, 16, 255, 256};
    for (int i = 0; i < 11; i++) {
        printf("  is_power_of_two(%3u) = %s\n",
               pow2_values[i], is_power_of_two(pow2_values[i]) ? "true" : "false");
    }

    /* Byte extraction from a 32-bit word */
    printf("\nByte extraction from 0xDEADBEEF:\n");
    uint32_t word = 0xDEADBEEF;
    printf("  Byte 0 (LSB): 0x%02X\n", (uint8_t)(word & 0xFF));
    printf("  Byte 1:       0x%02X\n", (uint8_t)((word >> 8) & 0xFF));
    printf("  Byte 2:       0x%02X\n", (uint8_t)((word >> 16) & 0xFF));
    printf("  Byte 3 (MSB): 0x%02X\n", (uint8_t)((word >> 24) & 0xFF));

    /* Building a 32-bit word from bytes */
    uint8_t b0 = 0xEF, b1 = 0xBE, b2 = 0xAD, b3 = 0xDE;
    uint32_t rebuilt = ((uint32_t)b3 << 24) | ((uint32_t)b2 << 16) |
                       ((uint32_t)b1 << 8)  | (uint32_t)b0;
    printf("\nRebuilt word from bytes: 0x%08X\n", rebuilt);
    printf("\n");
}

/* ---------- Demo: Bitmask-Based Flags ---------- */

#define FLAG_SENSOR_READY   BIT(0)
#define FLAG_MOTOR_RUNNING  BIT(1)
#define FLAG_ERROR          BIT(2)
#define FLAG_LOW_BATTERY    BIT(3)
#define FLAG_GPS_FIX        BIT(4)
#define FLAG_DATA_LOGGED    BIT(5)

static void print_flags(uint32_t flags)
{
    printf("  Active flags: ");
    if (flags & FLAG_SENSOR_READY)  printf("[SENSOR_READY] ");
    if (flags & FLAG_MOTOR_RUNNING) printf("[MOTOR_RUNNING] ");
    if (flags & FLAG_ERROR)         printf("[ERROR] ");
    if (flags & FLAG_LOW_BATTERY)   printf("[LOW_BATTERY] ");
    if (flags & FLAG_GPS_FIX)       printf("[GPS_FIX] ");
    if (flags & FLAG_DATA_LOGGED)   printf("[DATA_LOGGED] ");
    if (flags == 0) printf("[none]");
    printf("\n");
}

static void demo_bitmask_flags(void)
{
    printf("=== Bitmask-Based Status Flags ===\n\n");

    uint32_t status = 0;
    printf("Initial state:\n");
    print_flags(status);

    status |= FLAG_SENSOR_READY | FLAG_GPS_FIX;
    printf("\nAfter sensor ready and GPS fix:\n");
    print_flags(status);

    status |= FLAG_MOTOR_RUNNING;
    printf("\nMotor started:\n");
    print_flags(status);

    status |= FLAG_LOW_BATTERY;
    printf("\nLow battery detected:\n");
    print_flags(status);

    status &= ~FLAG_MOTOR_RUNNING;
    printf("\nMotor stopped due to low battery:\n");
    print_flags(status);

    /* Check multiple flags */
    if ((status & (FLAG_SENSOR_READY | FLAG_GPS_FIX)) ==
        (FLAG_SENSOR_READY | FLAG_GPS_FIX)) {
        printf("\nBoth sensor and GPS are ready for data logging.\n");
    }
}

/* ---------- Main ---------- */

int main(void)
{
    printf("Embedded C Bit Manipulation Demo\n");
    printf("=================================\n\n");

    demo_basic_operations();
    demo_multi_bit_fields();
    demo_practical_patterns();
    demo_bitmask_flags();

    return 0;
}
