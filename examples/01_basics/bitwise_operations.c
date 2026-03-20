/**
 * Bitwise Operations for Embedded Systems
 *
 * Demonstrates every bitwise technique an embedded C programmer needs:
 * set, clear, toggle, test, masks, shifts, and multi-bit field manipulation.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

/* ----------------------------------------------------------------
 * Helper: print a value in binary
 * ---------------------------------------------------------------- */
static void print_binary(const char *label, uint32_t value, int bits) {
    printf("  %-20s 0x%08X = ", label, value);
    for (int i = bits - 1; i >= 0; i--) {
        printf("%c", (value & (1U << i)) ? '1' : '0');
        if (i % 4 == 0 && i != 0) printf("_");
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Basic bit operations: set, clear, toggle, test
 * ---------------------------------------------------------------- */
static void demo_basic_operations(void) {
    printf("=== Basic Bit Operations ===\n\n");

    uint32_t reg = 0x00000000;
    print_binary("Initial:", reg, 16);

    /* SET bit 3: reg |= (1 << n) */
    reg |= (1 << 3);
    print_binary("Set bit 3:", reg, 16);

    /* SET bits 7 and 5 */
    reg |= (1 << 7) | (1 << 5);
    print_binary("Set bits 7,5:", reg, 16);

    /* CLEAR bit 3: reg &= ~(1 << n) */
    reg &= ~(1 << 3);
    print_binary("Clear bit 3:", reg, 16);

    /* TOGGLE bit 5: reg ^= (1 << n) */
    reg ^= (1 << 5);
    print_binary("Toggle bit 5:", reg, 16);
    reg ^= (1 << 5);
    print_binary("Toggle bit 5 again:", reg, 16);

    /* TEST bit 7: if (reg & (1 << n)) */
    printf("  Bit 7 is %s\n", (reg & (1 << 7)) ? "SET" : "CLEAR");
    printf("  Bit 3 is %s\n", (reg & (1 << 3)) ? "SET" : "CLEAR");
    printf("\n");
}

/* ----------------------------------------------------------------
 * Multi-bit field manipulation
 * ---------------------------------------------------------------- */
#define FIELD_MASK(width, shift)  (((1U << (width)) - 1) << (shift))
#define SET_FIELD(reg, width, shift, val) \
    ((reg) = ((reg) & ~FIELD_MASK(width, shift)) | (((val) & ((1U << (width)) - 1)) << (shift)))
#define GET_FIELD(reg, width, shift) \
    (((reg) & FIELD_MASK(width, shift)) >> (shift))

static void demo_field_manipulation(void) {
    printf("=== Multi-Bit Field Manipulation ===\n\n");

    /*
     * Simulated GPIO mode register:
     * Bits [1:0]   = Pin 0 mode (2 bits)
     * Bits [3:2]   = Pin 1 mode
     * Bits [5:4]   = Pin 2 mode
     * Bits [7:6]   = Pin 3 mode
     *
     * Mode values: 00=Input, 01=Output, 10=Alternate, 11=Analog
     */
    uint32_t moder = 0x00000000;

    printf("GPIO Mode register (2 bits per pin):\n");
    printf("  Modes: 00=Input, 01=Output, 10=Alternate, 11=Analog\n\n");

    /* Set pin 0 to output mode (01) */
    SET_FIELD(moder, 2, 0, 0x01);
    print_binary("Pin 0 = Output:", moder, 16);

    /* Set pin 1 to alternate function mode (10) */
    SET_FIELD(moder, 2, 2, 0x02);
    print_binary("Pin 1 = Alt:", moder, 16);

    /* Set pin 2 to analog mode (11) */
    SET_FIELD(moder, 2, 4, 0x03);
    print_binary("Pin 2 = Analog:", moder, 16);

    /* Read back pin 1 mode */
    uint32_t pin1_mode = GET_FIELD(moder, 2, 2);
    printf("  Read pin 1 mode: %u (%s)\n\n",
           pin1_mode,
           pin1_mode == 2 ? "Alternate" : "Other");
}

/* ----------------------------------------------------------------
 * Bit masking patterns
 * ---------------------------------------------------------------- */
static void demo_masking_patterns(void) {
    printf("=== Common Masking Patterns ===\n\n");

    /* Create a mask of N consecutive bits starting at position P */
    uint32_t mask_4bits_at_8 = FIELD_MASK(4, 8);
    print_binary("4-bit mask at pos 8:", mask_4bits_at_8, 16);

    /* Extract lower nibble */
    uint32_t value = 0xABCD;
    uint32_t lower_nibble = value & 0x0F;
    uint32_t upper_nibble = (value >> 4) & 0x0F;
    printf("  Value 0x%04X: lower nibble = 0x%X, upper nibble = 0x%X\n",
           value, lower_nibble, upper_nibble);

    /* Swap nibbles of a byte */
    uint8_t byte = 0xA5;
    uint8_t swapped = (uint8_t)((byte >> 4) | (byte << 4));
    printf("  Swap nibbles: 0x%02X -> 0x%02X\n", byte, swapped);

    /* Create bitmask from bit range [high:low] */
    int high = 11, low = 4;
    uint32_t range_mask = ((1U << (high - low + 1)) - 1) << low;
    print_binary("Mask [11:4]:", range_mask, 16);

    printf("\n");
}

/* ----------------------------------------------------------------
 * Practical: simulated register configuration
 * ---------------------------------------------------------------- */
static void demo_register_config(void) {
    printf("=== Practical Register Configuration ===\n\n");

    /*
     * Simulated UART control register:
     *   Bit  0    : UART Enable
     *   Bit  1    : TX Enable
     *   Bit  2    : RX Enable
     *   Bits [4:3]: Word length (00=7bit, 01=8bit, 10=9bit)
     *   Bit  5    : Parity enable
     *   Bit  6    : Parity type (0=even, 1=odd)
     *   Bits [9:7]: Stop bits (000=0.5, 001=1, 010=1.5, 011=2)
     */
    uint32_t uart_cr = 0;

    printf("Configuring UART: 8-N-1, TX+RX enabled\n");

    /* Enable UART, TX, RX */
    uart_cr |= (1 << 0) | (1 << 1) | (1 << 2);

    /* Set word length to 8 bits (01 in bits [4:3]) */
    SET_FIELD(uart_cr, 2, 3, 0x01);

    /* No parity (bit 5 = 0, already default) */

    /* 1 stop bit (001 in bits [9:7]) */
    SET_FIELD(uart_cr, 3, 7, 0x01);

    print_binary("UART CR:", uart_cr, 16);

    printf("  UART Enable: %s\n",  (uart_cr & (1 << 0)) ? "Yes" : "No");
    printf("  TX Enable:   %s\n",  (uart_cr & (1 << 1)) ? "Yes" : "No");
    printf("  RX Enable:   %s\n",  (uart_cr & (1 << 2)) ? "Yes" : "No");
    printf("  Word Length:  %u-bit\n", GET_FIELD(uart_cr, 2, 3) + 7);
    printf("  Parity:      %s\n",  (uart_cr & (1 << 5)) ? "Enabled" : "None");
    printf("  Stop bits:   %u\n",  GET_FIELD(uart_cr, 3, 7));
    printf("\n");
}

/* ----------------------------------------------------------------
 * Bit counting and manipulation tricks
 * ---------------------------------------------------------------- */
static void demo_bit_tricks(void) {
    printf("=== Useful Bit Tricks ===\n\n");

    /* Check if a number is a power of 2 */
    uint32_t values[] = {0, 1, 2, 3, 4, 7, 8, 16, 255, 256};
    int n = sizeof(values) / sizeof(values[0]);

    printf("Power of 2 check (n > 0 && !(n & (n-1))):\n");
    for (int i = 0; i < n; i++) {
        uint32_t v = values[i];
        bool is_pow2 = (v > 0) && !(v & (v - 1));
        printf("  %3u: %s\n", v, is_pow2 ? "Yes" : "No");
    }

    /* Round up to next power of 2 */
    uint32_t x = 200;
    uint32_t p = 1;
    while (p < x) p <<= 1;
    printf("\nNext power of 2 >= %u: %u\n", x, p);

    /* Count set bits (popcount) — portable version */
    uint32_t val = 0xDEADBEEF;
    int count = 0;
    uint32_t tmp = val;
    while (tmp) {
        count += tmp & 1;
        tmp >>= 1;
    }
    printf("Bits set in 0x%08X: %d\n", val, count);

    /* Find lowest set bit */
    uint32_t lowest = val & (-val);
    printf("Lowest set bit of 0x%08X: 0x%08X\n", val, lowest);

    /* Clear lowest set bit */
    uint32_t cleared = val & (val - 1);
    printf("Clear lowest bit: 0x%08X -> 0x%08X\n", val, cleared);

    printf("\n");
}

/* ----------------------------------------------------------------
 * Endianness conversion
 * ---------------------------------------------------------------- */
static void demo_endianness(void) {
    printf("=== Endianness Conversion ===\n\n");

    uint32_t native = 0x12345678;

    /* Byte-swap (convert between big-endian and little-endian) */
    uint32_t swapped = ((native & 0xFF000000) >> 24)
                     | ((native & 0x00FF0000) >> 8)
                     | ((native & 0x0000FF00) << 8)
                     | ((native & 0x000000FF) << 24);

    printf("Native:  0x%08X\n", native);
    printf("Swapped: 0x%08X\n", swapped);

    /* 16-bit swap */
    uint16_t val16 = 0xABCD;
    uint16_t swapped16 = (uint16_t)((val16 >> 8) | (val16 << 8));
    printf("16-bit:  0x%04X -> 0x%04X\n", val16, swapped16);

    /* Detect host endianness */
    uint32_t test = 1;
    bool is_little = (*(uint8_t *)&test == 1);
    printf("Host is %s-endian\n", is_little ? "little" : "big");
    printf("\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Bitwise Operations for Embedded C       ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_basic_operations();
    demo_field_manipulation();
    demo_masking_patterns();
    demo_register_config();
    demo_bit_tricks();
    demo_endianness();

    printf("═══ End of Bitwise Operations Demo ═══\n");
    return 0;
}
