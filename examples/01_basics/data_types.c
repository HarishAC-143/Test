/**
 * Embedded C Data Types and Qualifiers
 *
 * Demonstrates fixed-width integer types, volatile, const, and their
 * practical usage in embedded systems. This example compiles and runs
 * on a host PC for learning purposes.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <limits.h>

/* ----------------------------------------------------------------
 * Simulated hardware registers (on real hardware these would be
 * memory-mapped peripheral addresses)
 * ---------------------------------------------------------------- */
static volatile uint32_t SIM_STATUS_REG = 0x00000000;
static volatile uint32_t SIM_DATA_REG   = 0xDEADBEEF;
static volatile uint32_t SIM_CONTROL_REG = 0x00000000;

/* ----------------------------------------------------------------
 * Lookup table stored in Flash (ROM) on real hardware.
 * const ensures this goes into .rodata, not .data (RAM).
 * ---------------------------------------------------------------- */
static const uint8_t crc8_table[256] = {
    0x00, 0x5E, 0xBC, 0xE2, 0x61, 0x3F, 0xDD, 0x83,
    0xC2, 0x9C, 0x7E, 0x20, 0xA3, 0xFD, 0x1F, 0x41,
    0x9D, 0xC3, 0x21, 0x7F, 0xFC, 0xA2, 0x40, 0x1E,
    0x5F, 0x01, 0xE3, 0xBD, 0x3E, 0x60, 0x82, 0xDC,
    /* remaining 224 entries omitted for brevity */
};

/* ----------------------------------------------------------------
 * Demonstrate fixed-width integer types and their sizes
 * ---------------------------------------------------------------- */
static void demo_fixed_width_types(void) {
    printf("=== Fixed-Width Integer Types ===\n\n");

    uint8_t   byte_val   = 255;
    int8_t    sbyte_val  = -128;
    uint16_t  half_val   = 65535;
    int16_t   shalf_val  = -32768;
    uint32_t  word_val   = 4294967295U;
    int32_t   sword_val  = -2147483647 - 1;

    printf("Type         Size    Min                Max\n");
    printf("----------------------------------------------\n");
    printf("uint8_t      %zu B    0                  %u\n",   sizeof(uint8_t),  byte_val);
    printf("int8_t       %zu B    %d               %d\n",    sizeof(int8_t),   sbyte_val, INT8_MAX);
    printf("uint16_t     %zu B    0                  %u\n",   sizeof(uint16_t), half_val);
    printf("int16_t      %zu B    %d             %d\n",      sizeof(int16_t),  shalf_val, INT16_MAX);
    printf("uint32_t     %zu B    0                  %u\n",   sizeof(uint32_t), word_val);
    printf("int32_t      %zu B    %d        %d\n",           sizeof(int32_t),  sword_val, INT32_MAX);

    printf("\nNative 'int' size: %zu bytes\n", sizeof(int));
    printf("  On 16-bit MCUs this would be 2 bytes.\n");
    printf("  On 32-bit ARM this is 4 bytes.\n");
    printf("  Always use stdint.h types for predictable sizes!\n\n");
}

/* ----------------------------------------------------------------
 * Demonstrate the volatile qualifier
 * ---------------------------------------------------------------- */
static void demo_volatile(void) {
    printf("=== The volatile Qualifier ===\n\n");

    /* Simulate hardware changing a register in the background */
    SIM_STATUS_REG = 0x00;

    printf("Reading simulated status register:\n");

    /*
     * Without volatile, a compiler might optimize this into a single read
     * and cache the value, missing hardware updates.
     * With volatile, each access generates a real memory read.
     */
    printf("  Read 1: 0x%08X\n", SIM_STATUS_REG);

    /* Simulate hardware setting a "ready" bit */
    SIM_STATUS_REG |= (1 << 0);

    printf("  Read 2: 0x%08X (hardware set bit 0)\n", SIM_STATUS_REG);

    /* Check the ready bit */
    if (SIM_STATUS_REG & (1 << 0)) {
        printf("  -> Status: READY\n");
    }

    printf("\nKey rules:\n");
    printf("  1. Hardware registers       -> volatile\n");
    printf("  2. ISR-shared variables     -> volatile\n");
    printf("  3. DMA buffers              -> volatile\n");
    printf("  4. RTOS shared variables    -> volatile\n\n");
}

/* ----------------------------------------------------------------
 * Demonstrate const for Flash storage
 * ---------------------------------------------------------------- */
static void demo_const(void) {
    printf("=== The const Qualifier ===\n\n");

    printf("CRC8 table size: %zu bytes (stored in Flash/ROM)\n", sizeof(crc8_table));
    printf("First 8 entries: ");
    for (int i = 0; i < 8; i++) {
        printf("0x%02X ", crc8_table[i]);
    }
    printf("\n");

    /*
     * const + volatile: a read-only register whose value changes
     * on its own (e.g., a hardware timer counter).
     */
    const volatile uint32_t *hw_timer = &SIM_DATA_REG;
    printf("\nconst volatile register read: 0x%08X\n", *hw_timer);
    printf("  We can read it, but cannot write to it.\n");
    /* *hw_timer = 0; — would be a compile error */

    printf("\n");
}

/* ----------------------------------------------------------------
 * Demonstrate struct packing and alignment
 * ---------------------------------------------------------------- */
typedef struct {
    uint8_t  status;
    uint32_t data;
    uint16_t count;
} UnpackedStruct;

typedef struct __attribute__((packed)) {
    uint8_t  status;
    uint32_t data;
    uint16_t count;
} PackedStruct;

static void demo_struct_packing(void) {
    printf("=== Struct Packing and Alignment ===\n\n");

    printf("UnpackedStruct size: %zu bytes (with padding)\n", sizeof(UnpackedStruct));
    printf("PackedStruct size:   %zu bytes (no padding)\n", sizeof(PackedStruct));
    printf("\nPacked structs match hardware register layouts exactly,\n");
    printf("but unaligned access may be slower or unsupported on some architectures.\n\n");
}

/* ----------------------------------------------------------------
 * Demonstrate boolean and bit-field usage
 * ---------------------------------------------------------------- */
typedef struct {
    uint8_t led_on    : 1;
    uint8_t motor_on  : 1;
    uint8_t heater_on : 1;
    uint8_t alarm     : 1;
    uint8_t mode      : 2;
    uint8_t reserved  : 2;
} SystemFlags;

static void demo_bitfields(void) {
    printf("=== Bit Fields ===\n\n");

    SystemFlags flags = {0};
    printf("SystemFlags size: %zu byte(s)\n", sizeof(SystemFlags));

    flags.led_on = 1;
    flags.mode   = 3;

    printf("LED: %s, Motor: %s, Mode: %u\n",
           flags.led_on ? "ON" : "OFF",
           flags.motor_on ? "ON" : "OFF",
           flags.mode);

    printf("\nBit fields pack multiple boolean/small values into one byte.\n");
    printf("Caution: bit field layout is implementation-defined!\n");
    printf("For portable register access, use explicit bitwise operations instead.\n\n");
}

/* ----------------------------------------------------------------
 * Demonstrate type casting for register access
 * ---------------------------------------------------------------- */
static void demo_type_casting(void) {
    printf("=== Type Casting for Register Access ===\n\n");

    uint32_t raw_register = 0xABCD1234;

    uint8_t byte0 = (uint8_t)(raw_register & 0xFF);
    uint8_t byte1 = (uint8_t)((raw_register >> 8) & 0xFF);
    uint8_t byte2 = (uint8_t)((raw_register >> 16) & 0xFF);
    uint8_t byte3 = (uint8_t)((raw_register >> 24) & 0xFF);

    printf("Register value: 0x%08X\n", raw_register);
    printf("  Byte 0 (LSB): 0x%02X\n", byte0);
    printf("  Byte 1:       0x%02X\n", byte1);
    printf("  Byte 2:       0x%02X\n", byte2);
    printf("  Byte 3 (MSB): 0x%02X\n", byte3);

    /* Reconstructing from bytes (little-endian) */
    uint32_t reconstructed = (uint32_t)byte3 << 24
                           | (uint32_t)byte2 << 16
                           | (uint32_t)byte1 << 8
                           | (uint32_t)byte0;

    printf("  Reconstructed: 0x%08X %s\n\n",
           reconstructed,
           reconstructed == raw_register ? "(matches)" : "(MISMATCH!)");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Embedded C Data Types & Qualifiers      ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_fixed_width_types();
    demo_volatile();
    demo_const();
    demo_struct_packing();
    demo_bitfields();
    demo_type_casting();

    printf("═══ End of Data Types Demo ═══\n");
    return 0;
}
