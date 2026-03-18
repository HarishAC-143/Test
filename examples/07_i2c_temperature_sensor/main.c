/**
 * Example 07: I2C — Temperature Sensor Communication
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Communicates with an LM75 / TMP102 temperature sensor over I2C1
 * (PB6 = SCL, PB7 = SDA) and prints the temperature over UART.
 *
 * Concepts demonstrated:
 *   - I2C peripheral initialization
 *   - I2C master transmit and receive sequences
 *   - Open-drain GPIO configuration for I2C
 *   - Address + register read protocol
 *   - Start, stop, ACK/NACK generation
 *   - Timeout handling to avoid hangs
 */

#include <stdint.h>
#include <stdbool.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define APB1_BASE         (PERIPH_BASE)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE + 0x3800)
#define GPIOB_BASE        (AHB1_BASE + 0x0400)
#define I2C1_BASE         (APB1_BASE + 0x5400)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

/* RCC */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)

/* GPIOB */
#define GPIOB_MODER       REG32(GPIOB_BASE + 0x00)
#define GPIOB_OTYPER      REG32(GPIOB_BASE + 0x04)
#define GPIOB_OSPEEDR     REG32(GPIOB_BASE + 0x08)
#define GPIOB_PUPDR       REG32(GPIOB_BASE + 0x0C)
#define GPIOB_AFRL        REG32(GPIOB_BASE + 0x20)

/* I2C1 */
#define I2C1_CR1          REG32(I2C1_BASE + 0x00)
#define I2C1_CR2          REG32(I2C1_BASE + 0x04)
#define I2C1_OAR1         REG32(I2C1_BASE + 0x08)
#define I2C1_DR           REG32(I2C1_BASE + 0x10)
#define I2C1_SR1          REG32(I2C1_BASE + 0x14)
#define I2C1_SR2          REG32(I2C1_BASE + 0x18)
#define I2C1_CCR          REG32(I2C1_BASE + 0x1C)
#define I2C1_TRISE        REG32(I2C1_BASE + 0x20)

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

/* I2C CR1 bits */
#define I2C_CR1_PE        BIT(0)     /* Peripheral enable     */
#define I2C_CR1_START     BIT(8)     /* Generate START        */
#define I2C_CR1_STOP      BIT(9)     /* Generate STOP         */
#define I2C_CR1_ACK       BIT(10)    /* Acknowledge enable    */
#define I2C_CR1_SWRST     BIT(15)    /* Software reset        */

/* I2C SR1 bits */
#define I2C_SR1_SB        BIT(0)     /* Start bit generated   */
#define I2C_SR1_ADDR      BIT(1)     /* Address sent          */
#define I2C_SR1_BTF       BIT(2)     /* Byte transfer finished*/
#define I2C_SR1_RXNE      BIT(6)     /* Data register not empty*/
#define I2C_SR1_TXE       BIT(7)     /* Data register empty    */

/* LM75 / TMP102 temperature sensor */
#define TEMP_SENSOR_ADDR  0x48       /* 7-bit I2C address     */
#define TEMP_REG          0x00       /* Temperature register  */

#define I2C_TIMEOUT       100000

/* ───────────────────── UART (minimal) ───────────────────── */

/* Reuse UART from previous examples */
#define GPIOA_BASE        (AHB1_BASE + 0x0000)
#define USART2_BASE       (APB1_BASE + 0x4400)

#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_AFRL        REG32(GPIOA_BASE + 0x20)
#define USART2_SR         REG32(USART2_BASE + 0x00)
#define USART2_DR         REG32(USART2_BASE + 0x04)
#define USART2_BRR        REG32(USART2_BASE + 0x08)
#define USART2_CR1_REG    REG32(USART2_BASE + 0x0C)

static void uart_init(void)
{
    RCC_AHB1ENR |= BIT(0);
    RCC_APB1ENR |= BIT(17);
    GPIOA_MODER = (GPIOA_MODER & ~(0x03UL << 4)) | (0x02UL << 4);
    GPIOA_AFRL  = (GPIOA_AFRL  & ~(0x0FUL << 8)) | (0x07UL << 8);
    USART2_CR1_REG = 0;
    USART2_BRR = 0x008B;
    USART2_CR1_REG = BIT(13) | BIT(3);
}

static void uart_putc(uint8_t ch) { while (!(USART2_SR & BIT(7))); USART2_DR = ch; }
static void uart_puts(const char *s) { while (*s) uart_putc(*s++); }

static void uart_print_int(int32_t val)
{
    char buf[12];
    int i = 0;
    if (val < 0) { uart_putc('-'); val = -val; }
    if (val == 0) { uart_putc('0'); return; }
    while (val > 0) { buf[i++] = '0' + (val % 10); val /= 10; }
    while (i > 0) uart_putc(buf[--i]);
}

/* ───────────────────── I2C Setup ────────────────────────── */

static void i2c_init(void)
{
    /* Enable GPIOB and I2C1 clocks */
    RCC_AHB1ENR |= BIT(1);     /* GPIOB */
    RCC_APB1ENR |= BIT(21);    /* I2C1  */

    /*
     * Configure PB6 (SCL) and PB7 (SDA):
     *   - Alternate function mode (MODER = 10)
     *   - Open-drain output (OTYPER bit = 1) — required by I2C spec
     *   - High speed (OSPEEDR = 11)
     *   - Pull-up (PUPDR = 01) — external pull-ups are preferred
     *   - AF4 (I2C1)
     */
    for (int pin = 6; pin <= 7; pin++) {
        GPIOB_MODER   = (GPIOB_MODER   & ~(0x03UL << (pin * 2))) | (0x02UL << (pin * 2));
        GPIOB_OTYPER  |= BIT(pin);
        GPIOB_OSPEEDR = (GPIOB_OSPEEDR & ~(0x03UL << (pin * 2))) | (0x03UL << (pin * 2));
        GPIOB_PUPDR   = (GPIOB_PUPDR   & ~(0x03UL << (pin * 2))) | (0x01UL << (pin * 2));
        GPIOB_AFRL    = (GPIOB_AFRL    & ~(0x0FUL << (pin * 4))) | (0x04UL << (pin * 4));
    }

    /* Reset I2C peripheral */
    I2C1_CR1 |= I2C_CR1_SWRST;
    I2C1_CR1 &= ~I2C_CR1_SWRST;

    /*
     * Configure I2C clock:
     *
     * APB1 clock = 16 MHz (HSI / 1).
     * CR2 FREQ field = APB1 clock in MHz = 16.
     *
     * Standard mode (100 kHz):
     *   CCR = F_APB1 / (2 × F_I2C) = 16,000,000 / (2 × 100,000) = 80
     *
     * TRISE = (max rise time / T_APB1) + 1
     *   Standard mode max rise time = 1000 ns
     *   T_APB1 = 1/16 MHz = 62.5 ns
     *   TRISE = 1000/62.5 + 1 = 17
     */
    I2C1_CR2 = 16;         /* APB1 frequency in MHz */
    I2C1_CCR = 80;         /* 100 kHz standard mode */
    I2C1_TRISE = 17;

    /* Enable I2C */
    I2C1_CR1 |= I2C_CR1_PE;
}

/* ───────────────────── I2C Primitives ───────────────────── */

static bool i2c_wait_flag(volatile uint32_t *reg, uint32_t flag)
{
    uint32_t timeout = I2C_TIMEOUT;
    while (!(*reg & flag)) {
        if (--timeout == 0) return false;
    }
    return true;
}

/**
 * Generate a START condition and send the slave address.
 * dir: 0 = write, 1 = read.
 */
static bool i2c_start(uint8_t addr, uint8_t dir)
{
    /* Generate START */
    I2C1_CR1 |= I2C_CR1_START;

    /* Wait for SB (start bit) flag */
    if (!i2c_wait_flag(&I2C1_SR1, I2C_SR1_SB)) return false;

    /* Send address with R/W bit */
    I2C1_DR = (addr << 1) | (dir & 0x01);

    /* Wait for ADDR flag (address acknowledged) */
    if (!i2c_wait_flag(&I2C1_SR1, I2C_SR1_ADDR)) return false;

    /* Clear ADDR flag by reading SR1 then SR2 */
    (void)I2C1_SR1;
    (void)I2C1_SR2;

    return true;
}

/**
 * Generate a STOP condition.
 */
static void i2c_stop(void)
{
    I2C1_CR1 |= I2C_CR1_STOP;
}

/**
 * Write a single byte.
 */
static bool i2c_write_byte(uint8_t data)
{
    if (!i2c_wait_flag(&I2C1_SR1, I2C_SR1_TXE)) return false;
    I2C1_DR = data;
    if (!i2c_wait_flag(&I2C1_SR1, I2C_SR1_BTF)) return false;
    return true;
}

/**
 * Read a single byte with ACK.
 */
static uint8_t i2c_read_byte_ack(void)
{
    I2C1_CR1 |= I2C_CR1_ACK;
    i2c_wait_flag(&I2C1_SR1, I2C_SR1_RXNE);
    return (uint8_t)I2C1_DR;
}

/**
 * Read a single byte with NACK (last byte in a read sequence).
 */
static uint8_t i2c_read_byte_nack(void)
{
    I2C1_CR1 &= ~I2C_CR1_ACK;
    I2C1_CR1 |= I2C_CR1_STOP;
    i2c_wait_flag(&I2C1_SR1, I2C_SR1_RXNE);
    return (uint8_t)I2C1_DR;
}

/* ───────────────────── Temperature Reading ──────────────── */

/**
 * Read temperature from LM75 / TMP102 sensor.
 *
 * Protocol:
 *   1. START → Addr+W → Register pointer (0x00) → STOP
 *   2. START → Addr+R → Read MSB (ACK) → Read LSB (NACK) → STOP
 *
 * Temperature format (LM75): 16-bit, upper 9 bits are the temperature
 *   in 0.5°C resolution, two's complement.
 *
 * Returns temperature in tenths of a degree (e.g., 235 = 23.5°C).
 */
static int16_t read_temperature(void)
{
    uint8_t msb, lsb;

    /* Point to temperature register */
    if (!i2c_start(TEMP_SENSOR_ADDR, 0)) return -999;
    i2c_write_byte(TEMP_REG);
    i2c_stop();

    /* Read 2 bytes */
    if (!i2c_start(TEMP_SENSOR_ADDR, 1)) return -999;
    msb = i2c_read_byte_ack();
    lsb = i2c_read_byte_nack();

    /*
     * LM75 format: [MSB][LSB]
     *   MSB = integer part (signed)
     *   LSB bit 7 = 0.5°C
     *
     * Combine into a 16-bit value, shift right by 7 to get
     * 9-bit value, then multiply by 5 for tenths of a degree.
     */
    int16_t raw = (int16_t)((msb << 8) | lsb);
    raw >>= 7;

    return raw * 5;  /* tenths of a degree */
}

/* ───────────────────── Delay ────────────────────────────── */

static void delay(volatile uint32_t count)
{
    while (count--) { }
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    uart_init();
    i2c_init();

    uart_puts("=== I2C Temperature Sensor Example ===\r\n");
    uart_puts("Reading LM75/TMP102 on I2C1 (PB6=SCL, PB7=SDA)\r\n\r\n");

    while (1) {
        int16_t temp_tenths = read_temperature();

        if (temp_tenths == -9990) {
            uart_puts("ERROR: I2C communication failed\r\n");
        } else {
            int16_t whole = temp_tenths / 10;
            int16_t frac  = temp_tenths % 10;
            if (frac < 0) frac = -frac;

            uart_puts("Temperature: ");
            uart_print_int(whole);
            uart_putc('.');
            uart_print_int(frac);
            uart_puts(" C\r\n");
        }

        delay(5000000);
    }

    return 0;
}
