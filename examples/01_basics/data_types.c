/**
 * @file    data_types.c
 * @brief   Embedded C data types, sizes, and fixed-width integer usage.
 *
 * Demonstrates why fixed-width types from <stdint.h> are essential in
 * embedded programming, where type sizes vary across architectures.
 *
 * Target: ARM Cortex-M (32-bit), concepts apply to all platforms.
 */

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* -------------------------------------------------------------------------- */
/*  Fixed-Width Integer Types                                                  */
/* -------------------------------------------------------------------------- */

static uint8_t  sensor_id       = 0x3A;       /*  8-bit: 0 to 255            */
static int8_t   temperature_c   = -15;         /*  8-bit: -128 to 127         */
static uint16_t adc_raw         = 2048;        /* 16-bit: 0 to 65535          */
static int16_t  motor_rpm       = -3200;       /* 16-bit: -32768 to 32767     */
static uint32_t uptime_seconds  = 0;           /* 32-bit: 0 to 4294967295     */
static int32_t  encoder_ticks   = -100000;     /* 32-bit: ±2 billion          */

/* -------------------------------------------------------------------------- */
/*  Boolean Type                                                               */
/* -------------------------------------------------------------------------- */

static bool led_state    = false;
static bool alarm_active = true;

/* -------------------------------------------------------------------------- */
/*  Enum for Named Constants                                                   */
/* -------------------------------------------------------------------------- */

typedef enum {
    SYSTEM_OK       = 0,
    SYSTEM_ERROR    = 1,
    SYSTEM_BUSY     = 2,
    SYSTEM_TIMEOUT  = 3
} system_status_t;

/* -------------------------------------------------------------------------- */
/*  Struct for Grouping Related Data                                           */
/* -------------------------------------------------------------------------- */

typedef struct {
    uint8_t  id;
    int16_t  value;
    uint32_t timestamp_ms;
    bool     valid;
} sensor_reading_t;

/* -------------------------------------------------------------------------- */
/*  Demonstrate Type Sizes and Ranges                                          */
/* -------------------------------------------------------------------------- */

/**
 * Verify type sizes at compile time using _Static_assert (C11).
 * If any assertion fails, the build stops with a clear error message.
 */
_Static_assert(sizeof(uint8_t)  == 1, "uint8_t must be 1 byte");
_Static_assert(sizeof(uint16_t) == 2, "uint16_t must be 2 bytes");
_Static_assert(sizeof(uint32_t) == 4, "uint32_t must be 4 bytes");
_Static_assert(sizeof(bool)     == 1, "bool is typically 1 byte");

/* -------------------------------------------------------------------------- */
/*  Type Conversion and Casting                                                */
/* -------------------------------------------------------------------------- */

/**
 * Safely convert a 16-bit ADC reading to millivolts.
 *
 * @param raw_adc  12-bit ADC value (0-4095)
 * @param vref_mv  Reference voltage in millivolts (e.g., 3300 for 3.3V)
 * @return         Voltage in millivolts
 */
uint32_t adc_to_millivolts(uint16_t raw_adc, uint16_t vref_mv)
{
    /*
     * Promote to uint32_t BEFORE multiplication to avoid 16-bit overflow.
     * 4095 × 3300 = 13,513,500 which exceeds uint16_t max (65535).
     */
    return ((uint32_t)raw_adc * vref_mv) / 4095;
}

/**
 * Demonstrate safe narrowing conversion with range checking.
 */
uint8_t safe_uint32_to_uint8(uint32_t value)
{
    if (value > UINT8_MAX) {
        return UINT8_MAX;  /* Saturate instead of silently truncating */
    }
    return (uint8_t)value;
}

/* -------------------------------------------------------------------------- */
/*  Practical Example: Sensor Data Packing                                     */
/* -------------------------------------------------------------------------- */

/**
 * Pack a sensor reading into a compact 4-byte transmission format.
 *
 * Format: [ID:8][VALUE_H:8][VALUE_L:8][FLAGS:8]
 */
void pack_sensor_data(const sensor_reading_t *reading, uint8_t *out)
{
    out[0] = reading->id;
    out[1] = (uint8_t)(reading->value >> 8);   /* High byte */
    out[2] = (uint8_t)(reading->value & 0xFF); /* Low byte  */
    out[3] = reading->valid ? 0x01 : 0x00;
}

/**
 * Unpack sensor data from a received byte stream.
 */
void unpack_sensor_data(const uint8_t *in, sensor_reading_t *reading)
{
    reading->id    = in[0];
    reading->value = (int16_t)((uint16_t)in[1] << 8 | in[2]);
    reading->valid = (in[3] != 0);
}

/* -------------------------------------------------------------------------- */
/*  Endianness Handling                                                        */
/* -------------------------------------------------------------------------- */

/**
 * Convert a 32-bit value from host byte order to big-endian (network order).
 * ARM Cortex-M is little-endian; many protocols use big-endian.
 */
uint32_t host_to_big_endian_32(uint32_t value)
{
    return ((value & 0xFF000000) >> 24)
         | ((value & 0x00FF0000) >>  8)
         | ((value & 0x0000FF00) <<  8)
         | ((value & 0x000000FF) << 24);
}

uint16_t host_to_big_endian_16(uint16_t value)
{
    return (value >> 8) | (value << 8);
}

/* -------------------------------------------------------------------------- */
/*  Main — Demonstration                                                       */
/* -------------------------------------------------------------------------- */

int main(void)
{
    sensor_reading_t reading = {
        .id           = sensor_id,
        .value        = (int16_t)adc_raw,
        .timestamp_ms = uptime_seconds * 1000,
        .valid        = true
    };

    uint8_t packed[4];
    pack_sensor_data(&reading, packed);

    sensor_reading_t unpacked;
    unpack_sensor_data(packed, &unpacked);

    uint32_t voltage = adc_to_millivolts(adc_raw, 3300);
    (void)voltage;

    uint8_t clamped = safe_uint32_to_uint8(1000);
    (void)clamped;  /* 255 (saturated) */

    /* Suppress unused warnings for demonstration variables */
    (void)temperature_c;
    (void)motor_rpm;
    (void)encoder_ticks;
    (void)led_state;
    (void)alarm_active;

    while (1) {
        /* Main loop */
    }
}
