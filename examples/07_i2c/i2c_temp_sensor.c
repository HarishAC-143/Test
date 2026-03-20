/**
 * @file    i2c_temp_sensor.c
 * @brief   I2C driver with a practical temperature sensor example (LM75/TMP102).
 * @target  STM32F4xx (I2C1: PB6=SCL, PB7=SDA)
 *
 * Demonstrates:
 *  - I2C peripheral initialization
 *  - Start/stop condition generation
 *  - Address transmission (7-bit)
 *  - Single-byte and multi-byte read/write
 *  - Practical temperature sensor communication
 *  - Bus scanning to discover devices
 *
 * I2C Protocol:
 *   Master: [START][ADDR+W][ACK][REG][ACK][START][ADDR+R][ACK][DATA][NACK][STOP]
 *   Slave:                  ↑          ↑                  ↑
 *                          ACK        ACK                ACK
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))
#define RCC_APB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x40))

/* GPIOB (PB6=SCL, PB7=SDA) */
typedef struct {
    volatile uint32_t MODER;
    volatile uint32_t OTYPER;
    volatile uint32_t OSPEEDR;
    volatile uint32_t PUPDR;
    volatile uint32_t IDR;
    volatile uint32_t ODR;
    volatile uint32_t BSRR;
    volatile uint32_t LCKR;
    volatile uint32_t AFR[2];
} GPIO_TypeDef;

#define GPIOB   ((GPIO_TypeDef *)0x40020400U)

/* I2C1 */
typedef struct {
    volatile uint32_t CR1;      /* 0x00 */
    volatile uint32_t CR2;      /* 0x04 */
    volatile uint32_t OAR1;     /* 0x08 */
    volatile uint32_t OAR2;     /* 0x0C */
    volatile uint32_t DR;       /* 0x10 */
    volatile uint32_t SR1;      /* 0x14 */
    volatile uint32_t SR2;      /* 0x18 */
    volatile uint32_t CCR;      /* 0x1C */
    volatile uint32_t TRISE;    /* 0x20 */
} I2C_TypeDef;

#define I2C1    ((I2C_TypeDef *)0x40005400U)

/* I2C CR1 bits */
#define I2C_CR1_PE          (1U << 0)
#define I2C_CR1_START       (1U << 8)
#define I2C_CR1_STOP        (1U << 9)
#define I2C_CR1_ACK         (1U << 10)
#define I2C_CR1_SWRST       (1U << 15)

/* I2C SR1 bits */
#define I2C_SR1_SB          (1U << 0)   /* Start bit              */
#define I2C_SR1_ADDR        (1U << 1)   /* Address sent/matched   */
#define I2C_SR1_BTF         (1U << 2)   /* Byte transfer finished */
#define I2C_SR1_TXE         (1U << 7)   /* Data register empty    */
#define I2C_SR1_RXNE        (1U << 6)   /* Data register not empty */
#define I2C_SR1_AF          (1U << 10)  /* Acknowledge failure     */

/* ========================================================================== */
/*  I2C Driver                                                                 */
/* ========================================================================== */

#define I2C_TIMEOUT     10000

typedef enum {
    I2C_OK = 0,
    I2C_ERROR_START,
    I2C_ERROR_ADDR,
    I2C_ERROR_DATA,
    I2C_ERROR_TIMEOUT,
    I2C_ERROR_NACK
} i2c_status_t;

/**
 * Initialize I2C1 at the specified speed.
 *
 * @param speed_hz  Bus speed (100000 for standard, 400000 for fast mode)
 */
void i2c_init(uint32_t speed_hz)
{
    RCC_AHB1ENR |= (1U << 1);   /* GPIOB clock */
    RCC_APB1ENR |= (1U << 21);  /* I2C1 clock  */

    /* PB6 (SCL) and PB7 (SDA): AF4 (I2C1), open-drain, pull-up */
    for (int pin = 6; pin <= 7; pin++) {
        GPIOB->MODER &= ~(3U << (pin * 2));
        GPIOB->MODER |=  (2U << (pin * 2));     /* AF mode      */
        GPIOB->OTYPER |= (1U << pin);           /* Open-drain   */
        GPIOB->OSPEEDR |= (3U << (pin * 2));    /* High speed   */
        GPIOB->PUPDR &= ~(3U << (pin * 2));
        GPIOB->PUPDR |=  (1U << (pin * 2));     /* Pull-up      */
        GPIOB->AFR[0] &= ~(0xFU << (pin * 4));
        GPIOB->AFR[0] |=  (4U << (pin * 4));    /* AF4 = I2C1   */
    }

    /* Reset I2C */
    I2C1->CR1 = I2C_CR1_SWRST;
    I2C1->CR1 = 0;

    uint32_t pclk_mhz = 42;  /* APB1 clock in MHz */
    I2C1->CR2 = pclk_mhz;

    /* Clock Control Register */
    if (speed_hz <= 100000) {
        I2C1->CCR = (pclk_mhz * 1000000) / (2 * speed_hz);
        I2C1->TRISE = pclk_mhz + 1;  /* 1 µs max rise time */
    } else {
        I2C1->CCR = (pclk_mhz * 1000000) / (3 * speed_hz) | (1U << 15);
        I2C1->TRISE = (pclk_mhz * 300 / 1000) + 1;  /* 300 ns */
    }

    I2C1->CR1 = I2C_CR1_PE;
}

/**
 * Generate START condition and wait for it.
 */
static i2c_status_t i2c_start(void)
{
    I2C1->CR1 |= I2C_CR1_START;

    uint32_t timeout = I2C_TIMEOUT;
    while (!(I2C1->SR1 & I2C_SR1_SB)) {
        if (--timeout == 0) return I2C_ERROR_TIMEOUT;
    }
    return I2C_OK;
}

/**
 * Generate STOP condition.
 */
static void i2c_stop(void)
{
    I2C1->CR1 |= I2C_CR1_STOP;
}

/**
 * Send 7-bit address + R/W bit.
 *
 * @param addr  7-bit slave address
 * @param rw    0 = write, 1 = read
 */
static i2c_status_t i2c_send_addr(uint8_t addr, uint8_t rw)
{
    I2C1->DR = (addr << 1) | rw;

    uint32_t timeout = I2C_TIMEOUT;
    while (!(I2C1->SR1 & I2C_SR1_ADDR)) {
        if (I2C1->SR1 & I2C_SR1_AF) {
            I2C1->SR1 &= ~I2C_SR1_AF;
            i2c_stop();
            return I2C_ERROR_NACK;
        }
        if (--timeout == 0) {
            i2c_stop();
            return I2C_ERROR_TIMEOUT;
        }
    }

    /* Clear ADDR flag by reading SR1 then SR2 */
    (void)I2C1->SR1;
    (void)I2C1->SR2;

    return I2C_OK;
}

/**
 * Write data to an I2C slave register.
 */
i2c_status_t i2c_write_reg(uint8_t dev_addr, uint8_t reg, uint8_t data)
{
    i2c_status_t status;

    status = i2c_start();
    if (status != I2C_OK) return status;

    status = i2c_send_addr(dev_addr, 0);
    if (status != I2C_OK) return status;

    /* Send register address */
    I2C1->DR = reg;
    uint32_t timeout = I2C_TIMEOUT;
    while (!(I2C1->SR1 & I2C_SR1_TXE)) {
        if (--timeout == 0) { i2c_stop(); return I2C_ERROR_TIMEOUT; }
    }

    /* Send data */
    I2C1->DR = data;
    timeout = I2C_TIMEOUT;
    while (!(I2C1->SR1 & I2C_SR1_BTF)) {
        if (--timeout == 0) { i2c_stop(); return I2C_ERROR_TIMEOUT; }
    }

    i2c_stop();
    return I2C_OK;
}

/**
 * Read one byte from an I2C slave register.
 */
i2c_status_t i2c_read_reg(uint8_t dev_addr, uint8_t reg, uint8_t *data)
{
    i2c_status_t status;

    /* Write phase: send register address */
    status = i2c_start();
    if (status != I2C_OK) return status;

    status = i2c_send_addr(dev_addr, 0);
    if (status != I2C_OK) return status;

    I2C1->DR = reg;
    uint32_t timeout = I2C_TIMEOUT;
    while (!(I2C1->SR1 & I2C_SR1_TXE)) {
        if (--timeout == 0) { i2c_stop(); return I2C_ERROR_TIMEOUT; }
    }

    /* Read phase: repeated start + read */
    status = i2c_start();
    if (status != I2C_OK) return status;

    I2C1->CR1 &= ~I2C_CR1_ACK;  /* NACK after single byte */

    status = i2c_send_addr(dev_addr, 1);
    if (status != I2C_OK) return status;

    i2c_stop();

    timeout = I2C_TIMEOUT;
    while (!(I2C1->SR1 & I2C_SR1_RXNE)) {
        if (--timeout == 0) return I2C_ERROR_TIMEOUT;
    }

    *data = (uint8_t)I2C1->DR;
    return I2C_OK;
}

/**
 * Read multiple bytes from consecutive registers.
 */
i2c_status_t i2c_read_multi(uint8_t dev_addr, uint8_t start_reg,
                             uint8_t *buf, uint8_t length)
{
    if (length == 0) return I2C_OK;

    i2c_status_t status;

    /* Write register address */
    status = i2c_start();
    if (status != I2C_OK) return status;

    status = i2c_send_addr(dev_addr, 0);
    if (status != I2C_OK) return status;

    I2C1->DR = start_reg;
    uint32_t timeout = I2C_TIMEOUT;
    while (!(I2C1->SR1 & I2C_SR1_TXE)) {
        if (--timeout == 0) { i2c_stop(); return I2C_ERROR_TIMEOUT; }
    }

    /* Repeated start + read */
    status = i2c_start();
    if (status != I2C_OK) return status;

    I2C1->CR1 |= I2C_CR1_ACK;  /* ACK enabled for multi-byte */

    status = i2c_send_addr(dev_addr, 1);
    if (status != I2C_OK) return status;

    for (uint8_t i = 0; i < length; i++) {
        if (i == length - 1) {
            I2C1->CR1 &= ~I2C_CR1_ACK;  /* NACK before last byte */
            i2c_stop();
        }

        timeout = I2C_TIMEOUT;
        while (!(I2C1->SR1 & I2C_SR1_RXNE)) {
            if (--timeout == 0) return I2C_ERROR_TIMEOUT;
        }
        buf[i] = (uint8_t)I2C1->DR;
    }

    return I2C_OK;
}

/* ========================================================================== */
/*  I2C Bus Scanner                                                            */
/* ========================================================================== */

/**
 * Scan the I2C bus for responding devices.
 * Sends the address byte and checks for ACK/NACK.
 *
 * @param found_addrs  Array to store found device addresses
 * @param max_devices  Maximum number of entries in found_addrs
 * @return             Number of devices found
 */
uint8_t i2c_scan(uint8_t *found_addrs, uint8_t max_devices)
{
    uint8_t count = 0;

    for (uint8_t addr = 0x08; addr < 0x78; addr++) {
        i2c_status_t status = i2c_start();
        if (status != I2C_OK) continue;

        status = i2c_send_addr(addr, 0);
        i2c_stop();

        if (status == I2C_OK) {
            if (count < max_devices) {
                found_addrs[count] = addr;
            }
            count++;
        }
    }

    return count;
}

/* ========================================================================== */
/*  TMP102 Temperature Sensor Example                                          */
/* ========================================================================== */

/*
 * TMP102 I2C Temperature Sensor
 *   Address: 0x48 (A0 pin = GND)
 *   Resolution: 12-bit (0.0625°C)
 *   Range: -40°C to +125°C
 *
 * Temperature register (0x00): 2 bytes, MSB first
 *   [D11 D10 D9 D8 D7 D6 D5 D4] [D3 D2 D1 D0 0 0 0 0]
 *   12-bit value, left-justified in the upper 12 bits
 */

#define TMP102_ADDR         0x48
#define TMP102_REG_TEMP     0x00
#define TMP102_REG_CONFIG   0x01
#define TMP102_REG_T_LOW    0x02
#define TMP102_REG_T_HIGH   0x03

/**
 * Read temperature from TMP102 in units of 0.0625°C.
 *
 * @param temp_raw  Output: raw 12-bit temperature value
 * @return          I2C status
 */
i2c_status_t tmp102_read_raw(int16_t *temp_raw)
{
    uint8_t buf[2];
    i2c_status_t status = i2c_read_multi(TMP102_ADDR, TMP102_REG_TEMP, buf, 2);

    if (status == I2C_OK) {
        *temp_raw = (int16_t)((uint16_t)buf[0] << 4 | buf[1] >> 4);

        /* Sign-extend 12-bit to 16-bit */
        if (*temp_raw & 0x0800) {
            *temp_raw |= (int16_t)0xF000;
        }
    }

    return status;
}

/**
 * Read temperature in degrees Celsius × 100 (fixed-point).
 * E.g., 2537 = 25.37°C
 */
i2c_status_t tmp102_read_temp_c100(int32_t *temp_c100)
{
    int16_t raw;
    i2c_status_t status = tmp102_read_raw(&raw);

    if (status == I2C_OK) {
        /* Each LSB = 0.0625°C = 625/10000°C */
        *temp_c100 = ((int32_t)raw * 625) / 100;
    }

    return status;
}

/**
 * Set high/low temperature alert thresholds.
 */
i2c_status_t tmp102_set_alert(int16_t low_c, int16_t high_c)
{
    i2c_status_t status;
    uint8_t buf[2];

    /* Convert °C to TMP102 12-bit format */
    int16_t low_raw = low_c * 16;
    buf[0] = (uint8_t)(low_raw >> 4);
    buf[1] = (uint8_t)((low_raw & 0xF) << 4);

    /* Would need i2c_write_multi here — simplified for demonstration */
    status = i2c_write_reg(TMP102_ADDR, TMP102_REG_T_LOW, buf[0]);
    if (status != I2C_OK) return status;

    int16_t high_raw = high_c * 16;
    buf[0] = (uint8_t)(high_raw >> 4);

    status = i2c_write_reg(TMP102_ADDR, TMP102_REG_T_HIGH, buf[0]);
    return status;
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    i2c_init(100000);  /* 100 kHz standard mode */

    /* Scan the bus */
    uint8_t devices[16];
    uint8_t num_devices = i2c_scan(devices, 16);
    (void)num_devices;

    /* Read temperature */
    while (1) {
        int32_t temp_c100;
        i2c_status_t status = tmp102_read_temp_c100(&temp_c100);

        if (status == I2C_OK) {
            int32_t whole = temp_c100 / 100;
            int32_t frac  = (temp_c100 >= 0) ? (temp_c100 % 100) : ((-temp_c100) % 100);
            (void)whole;
            (void)frac;
            /* uart_printf("Temp: %d.%02d C\r\n", whole, frac); */
        }

        /* delay_ms(1000); */
    }
}
