/**
 * Example 05: ADC — Analog-to-Digital Conversion
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Reads an analog voltage from PA0 (ADC1 channel 0) and sends the
 * result over UART.  Could be connected to a potentiometer, light
 * sensor, temperature sensor, or any 0–3.3 V analog source.
 *
 * Concepts demonstrated:
 *   - ADC peripheral configuration (single conversion mode)
 *   - Analog GPIO pin setup
 *   - ADC calibration and conversion timing
 *   - Converting raw ADC values to voltage
 *   - Continuous conversion mode
 */

#include <stdint.h>
#include <stdbool.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define APB1_BASE         (PERIPH_BASE)
#define APB2_BASE         (PERIPH_BASE + 0x00010000)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE  + 0x3800)
#define GPIOA_BASE        (AHB1_BASE  + 0x0000)
#define ADC1_BASE         (APB2_BASE  + 0x2000)
#define USART2_BASE       (APB1_BASE  + 0x4400)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

/* RCC */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)
#define RCC_APB2ENR       REG32(RCC_BASE + 0x44)

/* GPIOA */
#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)

/* ADC1 */
#define ADC1_SR           REG32(ADC1_BASE + 0x00)   /* Status register      */
#define ADC1_CR1          REG32(ADC1_BASE + 0x04)   /* Control register 1   */
#define ADC1_CR2          REG32(ADC1_BASE + 0x08)   /* Control register 2   */
#define ADC1_SMPR2        REG32(ADC1_BASE + 0x10)   /* Sample time (ch 0-9) */
#define ADC1_SQR1         REG32(ADC1_BASE + 0x2C)   /* Sequence register 1  */
#define ADC1_SQR3         REG32(ADC1_BASE + 0x34)   /* Sequence register 3  */
#define ADC1_DR           REG32(ADC1_BASE + 0x4C)   /* Data register        */

/* USART2 (reused from example 04) */
#define USART2_SR         REG32(USART2_BASE + 0x00)
#define USART2_DR         REG32(USART2_BASE + 0x04)
#define USART2_BRR        REG32(USART2_BASE + 0x08)
#define USART2_CR1        REG32(USART2_BASE + 0x0C)

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

/* ADC Status Register bits */
#define ADC_SR_EOC        BIT(1)    /* End of conversion */

/* ADC CR2 bits */
#define ADC_CR2_ADON      BIT(0)    /* ADC on/off        */
#define ADC_CR2_SWSTART   BIT(30)   /* Start conversion  */
#define ADC_CR2_CONT      BIT(1)    /* Continuous mode   */

/* USART */
#define USART_SR_TXE      BIT(7)
#define USART_CR1_UE      BIT(13)
#define USART_CR1_TE      BIT(3)

#define V_REF             3.3f      /* Reference voltage */
#define ADC_MAX           4095      /* 12-bit ADC max    */

/* ───────────────────── UART (minimal for output) ────────── */

static void uart_init(void)
{
    RCC_AHB1ENR |= BIT(0);
    RCC_APB1ENR |= BIT(17);

    GPIOA_MODER &= ~(0x03UL << (2 * 2));
    GPIOA_MODER |=  (0x02UL << (2 * 2));

    REG32(GPIOA_BASE + 0x20) &= ~(0x0FUL << (2 * 4));
    REG32(GPIOA_BASE + 0x20) |=  (0x07UL << (2 * 4));

    USART2_CR1 = 0;
    USART2_BRR = 0x008B;
    USART2_CR1 = USART_CR1_UE | USART_CR1_TE;
}

static void uart_putc(uint8_t ch)
{
    while (!(USART2_SR & USART_SR_TXE)) { }
    USART2_DR = ch;
}

static void uart_puts(const char *s)
{
    while (*s) uart_putc((uint8_t)*s++);
}

static void uart_print_uint(uint32_t val)
{
    char buf[11];
    int i = 0;
    if (val == 0) { uart_putc('0'); return; }
    while (val > 0) { buf[i++] = '0' + (val % 10); val /= 10; }
    while (i > 0) uart_putc(buf[--i]);
}

/* ───────────────────── Delay ────────────────────────────── */

static void delay(volatile uint32_t count)
{
    while (count--) { }
}

/* ───────────────────── ADC Setup ────────────────────────── */

static void adc_init(void)
{
    /* Enable GPIOA clock (if not already done by UART init) */
    RCC_AHB1ENR |= BIT(0);

    /*
     * Configure PA0 as analog input.
     * MODER bits [1:0] = 11 → Analog mode.
     */
    GPIOA_MODER |= (0x03UL << (0 * 2));

    /* Enable ADC1 clock (APB2) */
    RCC_APB2ENR |= BIT(8);

    /*
     * ADC Configuration:
     *
     * CR1:
     *   - 12-bit resolution (bits [25:24] = 00) — default
     *   - No scan mode
     *
     * CR2:
     *   - Single conversion mode (CONT = 0)
     *   - Software trigger (SWSTART)
     *
     * SMPR2 (Sample Time Register for channels 0–9):
     *   - Channel 0: bits [2:0]
     *   - 84 cycles sample time (value 100 = 4)
     *   - Longer sample time improves accuracy for high-impedance sources
     *
     * SQR3 (Regular Sequence Register 3):
     *   - First conversion in sequence = channel 0
     *   - bits [4:0] = channel number
     *
     * SQR1:
     *   - Sequence length = 1 conversion
     *   - bits [23:20] = L = 0 (1 conversion)
     */
    ADC1_CR1 = 0;
    ADC1_CR2 = 0;

    ADC1_SMPR2 &= ~(0x07UL << (0 * 3));
    ADC1_SMPR2 |=  (0x04UL << (0 * 3));     /* 84 cycles sample time */

    ADC1_SQR3 &= ~0x1FUL;
    ADC1_SQR3 |= 0;                          /* Channel 0 first      */

    ADC1_SQR1 &= ~(0x0FUL << 20);            /* 1 conversion          */

    /* Turn on the ADC */
    ADC1_CR2 |= ADC_CR2_ADON;

    /* Short stabilization delay after power-on */
    delay(10000);
}

/* ───────────────────── ADC Read ─────────────────────────── */

/**
 * Perform a single ADC conversion and return the 12-bit result.
 */
static uint16_t adc_read(void)
{
    /* Start conversion */
    ADC1_CR2 |= ADC_CR2_SWSTART;

    /* Wait for end of conversion */
    while (!(ADC1_SR & ADC_SR_EOC)) { }

    /* Read result (reading DR also clears EOC) */
    return (uint16_t)(ADC1_DR & 0x0FFF);
}

/**
 * Read ADC and convert to millivolts (integer math, no float).
 */
static uint32_t adc_read_mv(void)
{
    uint16_t raw = adc_read();
    return (uint32_t)raw * 3300 / ADC_MAX;
}

/**
 * Average multiple ADC readings for noise reduction.
 */
static uint16_t adc_read_averaged(uint8_t samples)
{
    uint32_t sum = 0;
    for (uint8_t i = 0; i < samples; i++) {
        sum += adc_read();
    }
    return (uint16_t)(sum / samples);
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    uart_init();
    adc_init();

    uart_puts("=== ADC Reading Example ===\r\n");
    uart_puts("Reading analog voltage on PA0 (ADC1 CH0)\r\n\r\n");

    while (1) {
        uint16_t raw       = adc_read_averaged(16);
        uint32_t millivolts = (uint32_t)raw * 3300 / ADC_MAX;

        uart_puts("ADC raw: ");
        uart_print_uint(raw);
        uart_puts("  Voltage: ");
        uart_print_uint(millivolts / 1000);
        uart_putc('.');
        /* Print 3 decimal digits */
        uint32_t frac = millivolts % 1000;
        if (frac < 100) uart_putc('0');
        if (frac < 10)  uart_putc('0');
        uart_print_uint(frac);
        uart_puts(" V\r\n");

        delay(2000000);  /* ~1 second delay */
    }

    return 0;
}
