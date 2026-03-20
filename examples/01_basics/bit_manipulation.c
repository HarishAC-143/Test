/**
 * @file    bit_manipulation.c
 * @brief   Comprehensive bit manipulation techniques for embedded systems.
 *
 * Covers single-bit operations, multi-bit fields, masks, and practical
 * patterns used in hardware register programming.
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Bit Operation Macros                                                       */
/* ========================================================================== */

#define BIT(n)                  (1U << (n))
#define BIT_SET(reg, n)         ((reg) |=  BIT(n))
#define BIT_CLEAR(reg, n)       ((reg) &= ~BIT(n))
#define BIT_TOGGLE(reg, n)      ((reg) ^=  BIT(n))
#define BIT_CHECK(reg, n)       (((reg) >> (n)) & 1U)

#define BITS_MASK(width, pos)   (((1U << (width)) - 1U) << (pos))

#define FIELD_GET(reg, pos, width)  \
    (((reg) >> (pos)) & ((1U << (width)) - 1U))

#define FIELD_SET(reg, pos, width, val)  do {   \
    (reg) &= ~BITS_MASK(width, pos);            \
    (reg) |= ((val) & ((1U << (width)) - 1U)) << (pos); \
} while (0)

/* ========================================================================== */
/*  Single-Bit Operations                                                      */
/* ========================================================================== */

void single_bit_demo(void)
{
    uint8_t flags = 0x00;  /* 0b00000000 */

    /*
     * Bit layout:
     *   Bit 7: alarm
     *   Bit 6: (unused)
     *   Bit 5: motor_running
     *   Bit 4: heater_on
     *   Bit 3: sensor_ready
     *   Bit 2: comms_active
     *   Bit 1: low_battery
     *   Bit 0: power_on
     */

    /* SET: Turn on power (bit 0) and sensor (bit 3) */
    BIT_SET(flags, 0);   /* flags = 0b00000001 */
    BIT_SET(flags, 3);   /* flags = 0b00001001 */

    /* CHECK: Is the sensor ready? */
    if (BIT_CHECK(flags, 3)) {
        BIT_SET(flags, 5);  /* Start motor */
    }

    /* TOGGLE: Blink an LED bit */
    BIT_TOGGLE(flags, 7);  /* flags = 0b10101001 */
    BIT_TOGGLE(flags, 7);  /* flags = 0b00101001 */

    /* CLEAR: Turn off heater */
    BIT_CLEAR(flags, 4);   /* Bit 4 → 0 */

    (void)flags;
}

/* ========================================================================== */
/*  Multi-Bit Field Operations                                                 */
/* ========================================================================== */

/*
 * Hardware Timer Control Register (hypothetical 32-bit):
 *
 *   Bits [31:16] : Reserved
 *   Bits [15:12] : Prescaler (4 bits, values 0-15)
 *   Bits [11:10] : Mode (2 bits: 00=off, 01=oneshot, 10=continuous, 11=PWM)
 *   Bit  [9]     : Interrupt enable
 *   Bit  [8]     : DMA enable
 *   Bits [7:0]   : Clock divider (8 bits, 0-255)
 */

#define TIM_PRESCALER_POS   12
#define TIM_PRESCALER_WIDTH 4
#define TIM_MODE_POS        10
#define TIM_MODE_WIDTH      2
#define TIM_INT_EN_BIT      9
#define TIM_DMA_EN_BIT      8
#define TIM_CLKDIV_POS      0
#define TIM_CLKDIV_WIDTH    8

#define TIM_MODE_OFF        0
#define TIM_MODE_ONESHOT    1
#define TIM_MODE_CONTINUOUS 2
#define TIM_MODE_PWM        3

void multi_bit_field_demo(void)
{
    uint32_t timer_cr = 0;

    /* Configure prescaler to 7 */
    FIELD_SET(timer_cr, TIM_PRESCALER_POS, TIM_PRESCALER_WIDTH, 7);

    /* Set mode to PWM */
    FIELD_SET(timer_cr, TIM_MODE_POS, TIM_MODE_WIDTH, TIM_MODE_PWM);

    /* Enable interrupt */
    BIT_SET(timer_cr, TIM_INT_EN_BIT);

    /* Set clock divider to 128 */
    FIELD_SET(timer_cr, TIM_CLKDIV_POS, TIM_CLKDIV_WIDTH, 128);

    /* Read back the mode field */
    uint8_t mode = FIELD_GET(timer_cr, TIM_MODE_POS, TIM_MODE_WIDTH);
    (void)mode;  /* Should be 3 (PWM) */

    /* Modify prescaler without affecting other fields */
    FIELD_SET(timer_cr, TIM_PRESCALER_POS, TIM_PRESCALER_WIDTH, 15);

    (void)timer_cr;
}

/* ========================================================================== */
/*  Bit Counting and Position Finding                                          */
/* ========================================================================== */

/**
 * Count the number of set bits (population count / Hamming weight).
 */
uint8_t count_set_bits(uint32_t value)
{
    uint8_t count = 0;
    while (value) {
        count += value & 1;
        value >>= 1;
    }
    return count;
}

/**
 * Optimized popcount using Brian Kernighan's algorithm.
 * Clears the lowest set bit in each iteration → only loops N times
 * where N is the number of set bits.
 */
uint8_t count_set_bits_fast(uint32_t value)
{
    uint8_t count = 0;
    while (value) {
        value &= (value - 1);  /* Clear lowest set bit */
        count++;
    }
    return count;
}

/**
 * Find the position of the lowest set bit (0-indexed).
 * Returns -1 if no bit is set.
 */
int8_t find_lowest_set_bit(uint32_t value)
{
    if (value == 0) return -1;

    int8_t pos = 0;
    while (!(value & 1)) {
        value >>= 1;
        pos++;
    }
    return pos;
}

/**
 * Find the position of the highest set bit (0-indexed).
 * Returns -1 if no bit is set.
 */
int8_t find_highest_set_bit(uint32_t value)
{
    if (value == 0) return -1;

    int8_t pos = 0;
    while (value >>= 1) {
        pos++;
    }
    return pos;
}

/* ========================================================================== */
/*  Practical Patterns                                                         */
/* ========================================================================== */

/**
 * Check if a value is a power of 2.
 * Useful for validating buffer sizes (must be power of 2 for ring buffers).
 */
bool is_power_of_two(uint32_t value)
{
    return (value != 0) && ((value & (value - 1)) == 0);
}

/**
 * Round up to the nearest power of 2.
 */
uint32_t next_power_of_two(uint32_t value)
{
    value--;
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    value |= value >> 8;
    value |= value >> 16;
    value++;
    return value;
}

/**
 * Swap two values without a temporary variable (XOR swap).
 */
void swap_xor(uint32_t *a, uint32_t *b)
{
    if (a != b) {
        *a ^= *b;
        *b ^= *a;
        *a ^= *b;
    }
}

/**
 * Reverse the bits in an 8-bit value.
 * Useful for SPI devices that transmit MSB-first vs LSB-first.
 */
uint8_t reverse_bits_8(uint8_t value)
{
    value = (uint8_t)(((value & 0xF0) >> 4) | ((value & 0x0F) << 4));
    value = (uint8_t)(((value & 0xCC) >> 2) | ((value & 0x33) << 2));
    value = (uint8_t)(((value & 0xAA) >> 1) | ((value & 0x55) << 1));
    return value;
}

/**
 * Pack 8 boolean flags into a single byte (space-efficient storage).
 */
uint8_t pack_flags(const bool flags[8])
{
    uint8_t packed = 0;
    for (int i = 0; i < 8; i++) {
        if (flags[i]) {
            packed |= (1U << i);
        }
    }
    return packed;
}

/**
 * Unpack a byte into 8 boolean flags.
 */
void unpack_flags(uint8_t packed, bool flags[8])
{
    for (int i = 0; i < 8; i++) {
        flags[i] = (packed >> i) & 1U;
    }
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    single_bit_demo();
    multi_bit_field_demo();

    /* Bit counting */
    uint8_t n = count_set_bits_fast(0xDEADBEEF);
    (void)n;  /* 24 bits set */

    /* Lowest/highest bits */
    int8_t lo = find_lowest_set_bit(0x00300000);   /* 20 */
    int8_t hi = find_highest_set_bit(0x00300000);  /* 21 */
    (void)lo;
    (void)hi;

    /* Power of 2 checks */
    bool p2 = is_power_of_two(256);   /* true  */
    bool np = is_power_of_two(300);   /* false */
    (void)p2;
    (void)np;

    uint32_t np2 = next_power_of_two(300);  /* 512 */
    (void)np2;

    /* Bit reversal */
    uint8_t rev = reverse_bits_8(0xCA);  /* 0xCA → 0x53 */
    (void)rev;

    while (1) {
        /* Main loop */
    }
}
