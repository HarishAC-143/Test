# Chapter 11: ADC and DAC

The real world is analog — temperature, pressure, light intensity, battery voltage. The ADC (Analog-to-Digital Converter) bridges the gap between the continuous analog world and the discrete digital world of a microcontroller.

## ADC Fundamentals

An ADC converts an analog voltage into a digital number:

```
Analog input voltage (0V to Vref) → Digital value (0 to 2^N - 1)
```

| Parameter | Meaning | Typical Values |
|-----------|---------|----------------|
| **Resolution** | Number of output bits | 8, 10, 12, 16 bits |
| **Reference voltage (Vref)** | Maximum input voltage | 3.3V, 5.0V |
| **Sampling rate** | Conversions per second | 1 Ksps to 5 Msps |
| **Channels** | Number of analog inputs | 8 to 24 |

### Conversion Formula

```
Digital Value = (Vin / Vref) × (2^N - 1)
Vin = (Digital Value / (2^N - 1)) × Vref
```

**Example:** 12-bit ADC, Vref = 3.3V, reading = 2048

```
Vin = (2048 / 4095) × 3.3V = 1.65V
```

## Single-Channel ADC Read (Polling)

```c
void adc_init(void)
{
    /* Enable clocks */
    RCC->AHB1ENR |= (1U << 0);   /* GPIOA */
    RCC->APB2ENR |= (1U << 8);   /* ADC1 */

    /* PA0 as analog input */
    GPIOA->MODER |= (3U << 0);   /* Analog mode */

    /* ADC configuration */
    ADC1->CR2 = 0;
    ADC1->SQR3 = 0;               /* Channel 0 as first conversion */
    ADC1->SMPR2 |= (7U << 0);     /* Max sample time for channel 0 */
    ADC1->CR2 |= (1U << 0);       /* Enable ADC (ADON) */
}

uint16_t adc_read(void)
{
    ADC1->CR2 |= (1U << 30);      /* Start conversion (SWSTART) */

    while (!(ADC1->SR & (1U << 1)))  /* Wait for EOC (end of conversion) */
        ;

    return (uint16_t)ADC1->DR;
}
```

### Converting to Voltage

```c
float adc_to_voltage(uint16_t adc_value)
{
    return (float)adc_value * 3.3f / 4095.0f;
}
```

### Avoiding Floating Point

On MCUs without an FPU, floating-point is emulated in software and very slow. Use fixed-point arithmetic:

```c
/* Returns voltage in millivolts (integer) */
uint32_t adc_to_millivolts(uint16_t adc_value)
{
    return (uint32_t)adc_value * 3300U / 4095U;
}
```

## Multi-Channel ADC with Scan Mode

Read multiple analog inputs in sequence:

```c
#define NUM_CHANNELS 4
volatile uint16_t adc_values[NUM_CHANNELS];

void adc_multi_init(void)
{
    /* Configure PA0..PA3 as analog */
    GPIOA->MODER |= (3U << 0) | (3U << 2) | (3U << 4) | (3U << 6);

    /* ADC configuration */
    ADC1->CR1 |= (1U << 8);       /* SCAN mode */
    ADC1->CR2 |= (1U << 1);       /* Continuous conversion */

    /* Sequence: 4 conversions */
    ADC1->SQR1 = ((NUM_CHANNELS - 1) << 20);  /* Sequence length */
    ADC1->SQR3 = (0 << 0) |  /* 1st: Channel 0 */
                 (1 << 5) |  /* 2nd: Channel 1 */
                 (2 << 10) | /* 3rd: Channel 2 */
                 (3 << 15);  /* 4th: Channel 3 */

    ADC1->CR2 |= (1U << 0);  /* Enable ADC */
}
```

For multi-channel ADC, DMA is typically used to transfer results automatically (see DMA chapter concepts).

## Temperature Sensor Reading

Most MCUs have an internal temperature sensor connected to an ADC channel:

```c
uint16_t read_internal_temp(void)
{
    /* Enable temperature sensor (STM32-specific) */
    ADC->CCR |= (1U << 23);

    /* Select internal temp channel (usually channel 18) */
    ADC1->SQR3 = 18;

    ADC1->CR2 |= (1U << 30);
    while (!(ADC1->SR & (1U << 1)))
        ;

    return (uint16_t)ADC1->DR;
}

int32_t adc_to_temperature_c(uint16_t adc_value)
{
    /* STM32F4 formula: Temp(°C) = ((Vsense - V25) / Avg_Slope) + 25 */
    int32_t vsense_mv = (int32_t)adc_value * 3300 / 4095;
    return ((vsense_mv - 760) * 10 / 25) + 25;
}
```

## ADC with Interrupt

```c
volatile uint16_t latest_adc_value = 0;
volatile uint8_t  conversion_done = 0;

void adc_init_irq(void)
{
    adc_init();
    ADC1->CR1 |= (1U << 5);    /* EOCIE: End-of-conversion interrupt */
    NVIC_EnableIRQ(ADC_IRQn);
}

void ADC_IRQHandler(void)
{
    if (ADC1->SR & (1U << 1)) {
        latest_adc_value = (uint16_t)ADC1->DR;
        conversion_done = 1;
    }
}

void adc_start_conversion(void)
{
    conversion_done = 0;
    ADC1->CR2 |= (1U << 30);
}
```

## Software Averaging (Noise Reduction)

Single ADC readings are noisy. Average multiple samples:

```c
uint16_t adc_read_averaged(uint8_t num_samples)
{
    uint32_t sum = 0;
    for (uint8_t i = 0; i < num_samples; i++) {
        sum += adc_read();
    }
    return (uint16_t)(sum / num_samples);
}
```

### Moving Average Filter

Maintain a running average for continuous readings:

```c
#define AVG_WINDOW 16

uint16_t moving_average(uint16_t new_sample)
{
    static uint16_t samples[AVG_WINDOW];
    static uint8_t  index = 0;
    static uint32_t sum = 0;
    static uint8_t  filled = 0;

    sum -= samples[index];
    samples[index] = new_sample;
    sum += new_sample;
    index = (index + 1) % AVG_WINDOW;

    if (filled < AVG_WINDOW) filled++;

    return (uint16_t)(sum / filled);
}
```

## DAC (Digital-to-Analog Converter)

The DAC does the reverse of an ADC — converts a digital value into an analog voltage:

```c
void dac_init(void)
{
    RCC->AHB1ENR |= (1U << 0);    /* GPIOA clock */
    RCC->APB1ENR |= (1U << 29);   /* DAC clock */

    /* PA4 as analog (DAC channel 1 output) */
    GPIOA->MODER |= (3U << 8);

    /* Enable DAC channel 1 */
    DAC->CR |= (1U << 0);
}

void dac_write(uint16_t value)
{
    DAC->DHR12R1 = value & 0x0FFF;  /* 12-bit right-aligned */
}

/* Generate a 1V output: 1.0 / 3.3 * 4095 ≈ 1241 */
dac_write(1241);
```

### Generating a Sine Wave with DAC

```c
const uint16_t sine_lut[64] = {
    2048, 2249, 2447, 2642, 2831, 3013, 3185, 3347,
    3496, 3631, 3750, 3854, 3940, 4007, 4056, 4086,
    4095, 4086, 4056, 4007, 3940, 3854, 3750, 3631,
    3496, 3347, 3185, 3013, 2831, 2642, 2447, 2249,
    2048, 1847, 1649, 1454, 1265, 1083,  911,  749,
     600,  465,  346,  242,  156,   89,   40,   10,
       0,   10,   40,   89,  156,  242,  346,  465,
     600,  749,  911, 1083, 1265, 1454, 1649, 1847
};

void generate_sine_wave(void)
{
    static uint8_t idx = 0;
    dac_write(sine_lut[idx]);
    idx = (idx + 1) % 64;
}
```

Call `generate_sine_wave()` from a timer interrupt to produce a continuous waveform.

## Practical Examples

- [`examples/06_adc/adc_single_channel.c`](../examples/06_adc/adc_single_channel.c) — Basic single-channel ADC reading
- [`examples/06_adc/adc_temperature.c`](../examples/06_adc/adc_temperature.c) — Internal temperature sensor reading

## Summary

- The ADC converts analog voltages to digital values; the DAC does the reverse.
- Use fixed-point arithmetic (millivolts) instead of floating-point when possible.
- Average multiple samples to reduce noise.
- Use DMA for multi-channel ADC to avoid CPU overhead.
- A lookup table with a timer interrupt can generate waveforms through the DAC.

---

**Next:** [Chapter 12 — State Machines](12-state-machines.md)
