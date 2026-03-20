/**
 * @file    adc_multichannel.c
 * @brief   Multi-channel ADC with oversampling and averaging.
 * @target  STM32F4xx (ADC1, channels on PA0-PA3)
 *
 * Demonstrates:
 *  - ADC initialization with configurable resolution
 *  - Single-channel polling read
 *  - Multi-channel sequential scanning
 *  - Oversampling for noise reduction and increased effective resolution
 *  - Moving average filter
 *  - Voltage and temperature conversion
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))
#define RCC_APB2ENR     (*(volatile uint32_t *)(RCC_BASE + 0x44))

/* GPIOA */
typedef struct {
    volatile uint32_t MODER;
    volatile uint32_t OTYPER;
    volatile uint32_t OSPEEDR;
    volatile uint32_t PUPDR;
    volatile uint32_t IDR;
    volatile uint32_t ODR;
    volatile uint32_t BSRR;
} GPIO_TypeDef;

#define GPIOA   ((GPIO_TypeDef *)0x40020000U)

/* ADC1 */
typedef struct {
    volatile uint32_t SR;       /* 0x00: Status               */
    volatile uint32_t CR1;      /* 0x04: Control 1            */
    volatile uint32_t CR2;      /* 0x08: Control 2            */
    volatile uint32_t SMPR1;    /* 0x0C: Sample time (ch10-18) */
    volatile uint32_t SMPR2;    /* 0x10: Sample time (ch0-9)   */
    volatile uint32_t JOFR[4];  /* 0x14-0x20: Injected offsets */
    volatile uint32_t HTR;      /* 0x24: Watchdog high        */
    volatile uint32_t LTR;      /* 0x28: Watchdog low         */
    volatile uint32_t SQR1;     /* 0x2C: Regular sequence 1   */
    volatile uint32_t SQR2;     /* 0x30: Regular sequence 2   */
    volatile uint32_t SQR3;     /* 0x34: Regular sequence 3   */
    volatile uint32_t JSQR;     /* 0x38: Injected sequence    */
    volatile uint32_t JDR[4];   /* 0x3C-0x48: Injected data   */
    volatile uint32_t DR;       /* 0x4C: Regular data         */
} ADC_TypeDef;

/* ADC Common registers */
typedef struct {
    volatile uint32_t CSR;      /* 0x00: Common status        */
    volatile uint32_t CCR;      /* 0x04: Common control       */
    volatile uint32_t CDR;      /* 0x08: Common data          */
} ADC_Common_TypeDef;

#define ADC1        ((ADC_TypeDef *)0x40012000U)
#define ADC_COMMON  ((ADC_Common_TypeDef *)0x40012300U)

/* ADC bits */
#define ADC_SR_EOC          (1U << 1)   /* End of conversion     */
#define ADC_CR1_RES_12BIT   (0U << 24)
#define ADC_CR1_RES_10BIT   (1U << 24)
#define ADC_CR1_RES_8BIT    (2U << 24)
#define ADC_CR2_ADON        (1U << 0)   /* ADC on                */
#define ADC_CR2_SWSTART     (1U << 30)  /* Start conversion      */
#define ADC_CR2_CONT        (1U << 1)   /* Continuous mode       */

/* ========================================================================== */
/*  Configuration                                                              */
/* ========================================================================== */

#define ADC_VREF_MV         3300    /* Reference voltage in mV */
#define ADC_MAX_VALUE       4095    /* 12-bit resolution       */

#define NUM_ADC_CHANNELS    4
#define OVERSAMPLE_COUNT    16      /* 16× oversampling = +2 bits resolution */
#define FILTER_LENGTH       8       /* Moving average window */

/* ========================================================================== */
/*  ADC Driver                                                                 */
/* ========================================================================== */

/**
 * Initialize the ADC for single-conversion polling mode.
 */
void adc_init(void)
{
    /* Enable clocks */
    RCC_AHB1ENR |= (1U << 0);   /* GPIOA */
    RCC_APB2ENR |= (1U << 8);   /* ADC1  */

    /* Configure PA0-PA3 as analog inputs */
    for (int pin = 0; pin < NUM_ADC_CHANNELS; pin++) {
        GPIOA->MODER |= (3U << (pin * 2));  /* 11 = Analog mode */
    }

    /* ADC common: prescaler /4 (ADC clock = APB2/4 = 21 MHz) */
    ADC_COMMON->CCR = (1U << 16);

    /* ADC1 configuration */
    ADC1->CR1 = ADC_CR1_RES_12BIT;  /* 12-bit resolution */

    /* Sample time: 84 cycles for all channels (good balance of speed/accuracy) */
    ADC1->SMPR2 = (4U << 0) | (4U << 3) | (4U << 6) | (4U << 9);

    /* Internal temperature sensor: enable with longer sample time */
    ADC_COMMON->CCR |= (1U << 23);  /* TSVREFE: temp sensor enable */
    ADC1->SMPR1 |= (7U << 18);      /* 480 cycles for channel 16   */

    /* Power on */
    ADC1->CR2 = ADC_CR2_ADON;
}

/**
 * Read a single ADC channel (blocking).
 *
 * @param channel  ADC channel number (0-18)
 * @return         12-bit ADC value (0-4095)
 */
uint16_t adc_read_channel(uint8_t channel)
{
    /* Set channel in regular sequence (single conversion) */
    ADC1->SQR3 = channel;
    ADC1->SQR1 = 0;  /* 1 conversion in sequence */

    /* Start conversion */
    ADC1->CR2 |= ADC_CR2_SWSTART;

    /* Wait for end of conversion */
    while (!(ADC1->SR & ADC_SR_EOC)) { }

    return (uint16_t)(ADC1->DR & 0xFFF);
}

/* ========================================================================== */
/*  Oversampling                                                               */
/* ========================================================================== */

/**
 * Read with oversampling for improved resolution and noise reduction.
 *
 * Oversampling by N and decimating (right-shifting by log2(sqrt(N)))
 * increases effective resolution:
 *   4× → +1 bit (13-bit)
 *  16× → +2 bits (14-bit)
 *  64× → +3 bits (15-bit)
 * 256× → +4 bits (16-bit)
 */
uint16_t adc_read_oversampled(uint8_t channel, uint8_t num_samples)
{
    uint32_t sum = 0;

    for (uint8_t i = 0; i < num_samples; i++) {
        sum += adc_read_channel(channel);
    }

    /* For 16× oversampling, divide by 4 (right-shift by 2) for +2 bits */
    if (num_samples == 16) return (uint16_t)(sum >> 2);  /* 14-bit result */
    if (num_samples == 64) return (uint16_t)(sum >> 3);  /* 15-bit result */

    return (uint16_t)(sum / num_samples);  /* Simple average (no extra bits) */
}

/* ========================================================================== */
/*  Moving Average Filter                                                      */
/* ========================================================================== */

typedef struct {
    uint16_t samples[FILTER_LENGTH];
    uint8_t  index;
    uint32_t sum;
    bool     filled;  /* True after the buffer has been filled at least once */
} moving_avg_t;

void moving_avg_init(moving_avg_t *filter)
{
    for (int i = 0; i < FILTER_LENGTH; i++) {
        filter->samples[i] = 0;
    }
    filter->index  = 0;
    filter->sum    = 0;
    filter->filled = false;
}

/**
 * Add a new sample and return the filtered value.
 */
uint16_t moving_avg_update(moving_avg_t *filter, uint16_t new_sample)
{
    filter->sum -= filter->samples[filter->index];
    filter->samples[filter->index] = new_sample;
    filter->sum += new_sample;

    filter->index++;
    if (filter->index >= FILTER_LENGTH) {
        filter->index = 0;
        filter->filled = true;
    }

    uint8_t count = filter->filled ? FILTER_LENGTH : filter->index;
    return (uint16_t)(filter->sum / count);
}

/* ========================================================================== */
/*  Conversion Functions                                                       */
/* ========================================================================== */

/**
 * Convert raw ADC value to millivolts.
 */
uint32_t adc_to_mv(uint16_t raw)
{
    return ((uint32_t)raw * ADC_VREF_MV) / ADC_MAX_VALUE;
}

/**
 * Read internal temperature sensor (channel 16 on STM32F4).
 * Formula from datasheet:
 *   Temperature (°C) = (V_sense - V_25) / Avg_Slope + 25
 *   V_25 = 0.76V (typical at 25°C)
 *   Avg_Slope = 2.5 mV/°C
 *
 * @return Temperature in degrees Celsius × 10 (e.g., 253 = 25.3°C)
 */
int16_t adc_read_internal_temp_c10(void)
{
    uint16_t raw = adc_read_oversampled(16, 16);
    uint32_t mv  = adc_to_mv(raw);

    /* Temperature = ((mv - 760) / 2.5) + 25 = ((mv - 760) × 10 / 25) + 250 */
    int16_t temp_c10 = (int16_t)(((int32_t)mv - 760) * 10 / 25 + 250);
    return temp_c10;
}

/**
 * Read battery voltage via a resistor divider.
 *
 * Typical setup: Vbat ─── R1=100k ──┬── ADC_IN ─── R2=100k ──┬── GND
 *                                    │                         │
 * Divider ratio: Vadc = Vbat × R2/(R1+R2) = Vbat / 2
 */
uint32_t adc_read_battery_mv(uint8_t channel, uint8_t divider_ratio)
{
    uint16_t raw = adc_read_oversampled(channel, 16);
    return adc_to_mv(raw) * divider_ratio;
}

/* ========================================================================== */
/*  Multi-Channel Application                                                  */
/* ========================================================================== */

typedef struct {
    uint16_t raw[NUM_ADC_CHANNELS];
    uint32_t voltage_mv[NUM_ADC_CHANNELS];
    int16_t  internal_temp_c10;
} adc_readings_t;

static moving_avg_t channel_filters[NUM_ADC_CHANNELS];

void adc_read_all(adc_readings_t *readings)
{
    for (uint8_t ch = 0; ch < NUM_ADC_CHANNELS; ch++) {
        uint16_t raw = adc_read_channel(ch);
        readings->raw[ch] = moving_avg_update(&channel_filters[ch], raw);
        readings->voltage_mv[ch] = adc_to_mv(readings->raw[ch]);
    }

    readings->internal_temp_c10 = adc_read_internal_temp_c10();
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    adc_init();

    for (int i = 0; i < NUM_ADC_CHANNELS; i++) {
        moving_avg_init(&channel_filters[i]);
    }

    adc_readings_t readings;

    while (1) {
        adc_read_all(&readings);

        /*
         * readings.voltage_mv[0] = potentiometer voltage (0-3300 mV)
         * readings.voltage_mv[1] = light sensor voltage
         * readings.voltage_mv[2] = current sensor voltage
         * readings.voltage_mv[3] = battery voltage (via divider)
         * readings.internal_temp_c10 = MCU die temperature × 10
         */

        (void)readings;  /* Process or send via UART */

        /* delay_ms(100); */
    }
}
