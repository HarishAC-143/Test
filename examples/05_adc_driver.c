/**
 * @file    05_adc_driver.c
 * @brief   ADC driver with single/multi-channel, averaging, and sensor examples
 *
 * Demonstrates:
 *  - ADC initialization and calibration
 *  - Single-channel polled conversion
 *  - Multi-channel scan mode
 *  - Oversampling and averaging for noise reduction
 *  - Voltage and temperature conversion
 *  - Analog watchdog for threshold monitoring
 *  - Moving average filter
 *
 * Target: Generic ARM Cortex-M with STM32-like 12-bit ADC
 */

#include <stdint.h>

/* ──────────────────────────────────────────────────────────────────────────
 * ADC Register Definitions
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    volatile uint32_t SR;      /* 0x00 Status register             */
    volatile uint32_t CR1;     /* 0x04 Control register 1          */
    volatile uint32_t CR2;     /* 0x08 Control register 2          */
    volatile uint32_t SMPR1;   /* 0x0C Sample time register 1      */
    volatile uint32_t SMPR2;   /* 0x10 Sample time register 2      */
    volatile uint32_t JOFR1;   /* 0x14 Injected offset register 1  */
    volatile uint32_t JOFR2;   /* 0x18 Injected offset register 2  */
    volatile uint32_t JOFR3;   /* 0x1C Injected offset register 3  */
    volatile uint32_t JOFR4;   /* 0x20 Injected offset register 4  */
    volatile uint32_t HTR;     /* 0x24 Watchdog high threshold     */
    volatile uint32_t LTR;     /* 0x28 Watchdog low threshold      */
    volatile uint32_t SQR1;    /* 0x2C Regular sequence register 1 */
    volatile uint32_t SQR2;    /* 0x30 Regular sequence register 2 */
    volatile uint32_t SQR3;    /* 0x34 Regular sequence register 3 */
    volatile uint32_t JSQR;    /* 0x38 Injected sequence register  */
    volatile uint32_t JDR1;    /* 0x3C Injected data register 1    */
    volatile uint32_t JDR2;    /* 0x40 Injected data register 2    */
    volatile uint32_t JDR3;    /* 0x44 Injected data register 3    */
    volatile uint32_t JDR4;    /* 0x48 Injected data register 4    */
    volatile uint32_t DR;      /* 0x4C Regular data register       */
} ADC_TypeDef;

#define ADC1 ((ADC_TypeDef *)0x40012400U)

/* SR bits */
#define ADC_SR_EOC       (1U << 1)   /* End of conversion */
#define ADC_SR_AWD       (1U << 0)   /* Analog watchdog */

/* CR1 bits */
#define ADC_CR1_AWDEN    (1U << 23)  /* Analog watchdog enable */
#define ADC_CR1_AWDIE    (1U << 6)   /* Analog watchdog interrupt enable */
#define ADC_CR1_AWDSGL   (1U << 9)   /* Watchdog on single channel */
#define ADC_CR1_SCAN     (1U << 8)   /* Scan mode */

/* CR2 bits */
#define ADC_CR2_ADON     (1U << 0)   /* ADC enable */
#define ADC_CR2_SWSTART  (1U << 30)  /* Software start */
#define ADC_CR2_CONT     (1U << 1)   /* Continuous mode */
#define ADC_CR2_DMA      (1U << 8)   /* DMA mode */

/* ADC resolution = 12 bits, Vref = 3.3V */
#define ADC_RESOLUTION   4095U
#define ADC_VREF_MV      3300U

/* Sample time options (in ADC clock cycles) */
typedef enum {
    ADC_SAMP_1_5   = 0,
    ADC_SAMP_7_5   = 1,
    ADC_SAMP_13_5  = 2,
    ADC_SAMP_28_5  = 3,
    ADC_SAMP_41_5  = 4,
    ADC_SAMP_55_5  = 5,
    ADC_SAMP_71_5  = 6,
    ADC_SAMP_239_5 = 7
} adc_sample_time_t;

/* ──────────────────────────────────────────────────────────────────────────
 * ADC Driver API
 * ────────────────────────────────────────────────────────────────────────── */

void adc_init(ADC_TypeDef *adc)
{
    /* Power on the ADC */
    adc->CR2 |= ADC_CR2_ADON;

    /* Wait for startup stabilization (~1 µs typically) */
    for (volatile uint32_t i = 0; i < 1000; i++);

    /* Start calibration (two writes to ADON) */
    adc->CR2 |= ADC_CR2_ADON;

    /* Wait for calibration to complete (busy-wait; hardware clears the flag) */
    for (volatile uint32_t i = 0; i < 5000; i++);
}

void adc_set_sample_time(ADC_TypeDef *adc, uint8_t channel,
                          adc_sample_time_t time)
{
    if (channel < 10) {
        adc->SMPR2 &= ~(0x7U << (channel * 3));
        adc->SMPR2 |= ((uint32_t)time << (channel * 3));
    } else if (channel < 18) {
        adc->SMPR1 &= ~(0x7U << ((channel - 10) * 3));
        adc->SMPR1 |= ((uint32_t)time << ((channel - 10) * 3));
    }
}

uint16_t adc_read_channel(ADC_TypeDef *adc, uint8_t channel)
{
    /* Set channel in regular sequence (single conversion) */
    adc->SQR1 &= ~(0xFU << 20);        /* 1 conversion in sequence */
    adc->SQR3  = channel & 0x1F;        /* First (and only) channel */

    /* Start conversion */
    adc->CR2 |= ADC_CR2_SWSTART;

    /* Wait for end of conversion */
    while (!(adc->SR & ADC_SR_EOC));

    return (uint16_t)(adc->DR & 0x0FFF);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Oversampling / Averaging
 * ────────────────────────────────────────────────────────────────────────── */

uint16_t adc_read_averaged(ADC_TypeDef *adc, uint8_t channel,
                            uint8_t num_samples)
{
    uint32_t sum = 0;
    for (uint8_t i = 0; i < num_samples; i++) {
        sum += adc_read_channel(adc, channel);
    }
    return (uint16_t)(sum / num_samples);
}

/* Oversampling with decimation: n extra bits = 4^n oversamples.
   E.g., 16x oversampling gives 2 extra bits → 14-bit result. */
uint16_t adc_read_oversampled(ADC_TypeDef *adc, uint8_t channel,
                               uint8_t extra_bits)
{
    uint32_t num_samples = 1U;
    for (uint8_t i = 0; i < extra_bits * 2; i++) {
        num_samples *= 2;
    }

    uint32_t sum = 0;
    for (uint32_t i = 0; i < num_samples; i++) {
        sum += adc_read_channel(adc, channel);
    }

    return (uint16_t)(sum >> extra_bits);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Multi-Channel Scan
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    uint8_t  channel;
    uint16_t raw;
    uint32_t millivolts;
} adc_result_t;

void adc_scan_channels(ADC_TypeDef *adc, adc_result_t *results,
                        uint8_t count, uint8_t avg_samples)
{
    for (uint8_t i = 0; i < count; i++) {
        results[i].raw = adc_read_averaged(adc, results[i].channel,
                                            avg_samples);
        results[i].millivolts =
            ((uint32_t)results[i].raw * ADC_VREF_MV) / ADC_RESOLUTION;
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Conversion Helpers
 * ────────────────────────────────────────────────────────────────────────── */

uint32_t adc_to_millivolts(uint16_t raw)
{
    return ((uint32_t)raw * ADC_VREF_MV) / ADC_RESOLUTION;
}

/* Internal temperature sensor (channel 16 on many STM32).
   V_sense = (V_25 - T × Avg_Slope) where V_25 ≈ 1430 mV, slope ≈ 4.3 mV/°C */
int16_t adc_read_internal_temp(ADC_TypeDef *adc)
{
    adc_set_sample_time(adc, 16, ADC_SAMP_239_5);
    uint16_t raw = adc_read_averaged(adc, 16, 16);
    uint32_t mv = adc_to_millivolts(raw);

    return (int16_t)((1430 - (int32_t)mv) * 10 / 43 + 25);
}

/* Internal reference voltage (channel 17, Vrefint ≈ 1200 mV) */
uint32_t adc_read_vdda_mv(ADC_TypeDef *adc)
{
    adc_set_sample_time(adc, 17, ADC_SAMP_239_5);
    uint16_t raw = adc_read_averaged(adc, 17, 16);

    if (raw == 0) return 0;
    return (1200U * ADC_RESOLUTION) / raw;
}

/* ──────────────────────────────────────────────────────────────────────────
 * Moving Average Filter
 *
 * Lightweight IIR-style filter suitable for noisy analog signals.
 * ────────────────────────────────────────────────────────────────────────── */

#define FILTER_WINDOW  16

typedef struct {
    uint16_t samples[FILTER_WINDOW];
    uint8_t  index;
    uint32_t sum;
    uint8_t  filled;
} moving_avg_t;

void filter_init(moving_avg_t *f)
{
    for (uint8_t i = 0; i < FILTER_WINDOW; i++) {
        f->samples[i] = 0;
    }
    f->index  = 0;
    f->sum    = 0;
    f->filled = 0;
}

uint16_t filter_update(moving_avg_t *f, uint16_t new_sample)
{
    f->sum -= f->samples[f->index];
    f->samples[f->index] = new_sample;
    f->sum += new_sample;
    f->index = (f->index + 1) % FILTER_WINDOW;

    if (!f->filled && f->index == 0) {
        f->filled = 1;
    }

    uint8_t divisor = f->filled ? FILTER_WINDOW : f->index;
    if (divisor == 0) divisor = 1;

    return (uint16_t)(f->sum / divisor);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Analog Watchdog
 *
 * Generates an interrupt when the ADC value goes outside [low, high].
 * Useful for over-voltage/under-voltage detection.
 * ────────────────────────────────────────────────────────────────────────── */

void adc_config_watchdog(ADC_TypeDef *adc, uint8_t channel,
                          uint16_t low, uint16_t high)
{
    adc->HTR = high & 0x0FFF;
    adc->LTR = low  & 0x0FFF;

    adc->CR1 &= ~(0x1FU << 0);         /* Clear channel selection */
    adc->CR1 |= (channel & 0x1F);      /* Watchdog channel */
    adc->CR1 |= ADC_CR1_AWDSGL;        /* Single-channel watchdog */
    adc->CR1 |= ADC_CR1_AWDEN;         /* Enable on regular channels */
    adc->CR1 |= ADC_CR1_AWDIE;         /* Enable interrupt */
}

static volatile uint8_t watchdog_triggered = 0;

void ADC1_2_IRQHandler(void)
{
    if (ADC1->SR & ADC_SR_AWD) {
        ADC1->SR &= ~ADC_SR_AWD;
        watchdog_triggered = 1;
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: Multi-Sensor Monitor
 * ────────────────────────────────────────────────────────────────────────── */

extern void uart_printf(void *uart, const char *fmt, ...);
extern void delay_ms(uint32_t ms);

#define SENSOR_COUNT 4

int main(void)
{
    adc_init(ADC1);

    /* Configure sample times for all channels */
    for (uint8_t ch = 0; ch < 8; ch++) {
        adc_set_sample_time(ADC1, ch, ADC_SAMP_55_5);
    }

    /* Prepare multi-channel scan list */
    adc_result_t results[SENSOR_COUNT] = {
        {.channel = 0},  /* Potentiometer */
        {.channel = 1},  /* Light sensor (LDR) */
        {.channel = 4},  /* Current sensor */
        {.channel = 5},  /* Voltage divider */
    };

    /* Moving average filters for each channel */
    moving_avg_t filters[SENSOR_COUNT];
    for (uint8_t i = 0; i < SENSOR_COUNT; i++) {
        filter_init(&filters[i]);
    }

    /* Set watchdog on current sensor: alert if > 2.5V (overcurrent) */
    uint16_t threshold = (uint16_t)((2500UL * ADC_RESOLUTION) / ADC_VREF_MV);
    adc_config_watchdog(ADC1, 4, 0, threshold);

    while (1) {
        adc_scan_channels(ADC1, results, SENSOR_COUNT, 8);

        /* Apply filters */
        for (uint8_t i = 0; i < SENSOR_COUNT; i++) {
            results[i].raw = filter_update(&filters[i], results[i].raw);
            results[i].millivolts = adc_to_millivolts(results[i].raw);
        }

        /* Read internal sensors */
        int16_t  mcu_temp = adc_read_internal_temp(ADC1);
        uint32_t vdda     = adc_read_vdda_mv(ADC1);

        /* Print results */
        uart_printf((void *)0x40011000U,
            "Pot: %lumV  Light: %lumV  Current: %lumV  Vbat: %lumV  "
            "MCU: %d°C  VDDA: %lumV\r\n",
            (unsigned long)results[0].millivolts,
            (unsigned long)results[1].millivolts,
            (unsigned long)results[2].millivolts,
            (unsigned long)results[3].millivolts,
            mcu_temp, (unsigned long)vdda);

        if (watchdog_triggered) {
            watchdog_triggered = 0;
            uart_printf((void *)0x40011000U,
                        "*** OVERCURRENT ALERT ***\r\n");
        }

        delay_ms(500);
    }

    return 0;
}
