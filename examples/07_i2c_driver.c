/**
 * @file    07_i2c_driver.c
 * @brief   I2C master driver with sensor and EEPROM examples
 *
 * Demonstrates:
 *  - I2C master initialization (standard and fast mode)
 *  - Byte-level and block transfers with error handling
 *  - I2C bus scanning
 *  - LM75 temperature sensor driver
 *  - BMP280 pressure/temperature sensor driver
 *  - AT24C EEPROM driver
 *  - MPU6050 accelerometer/gyroscope driver
 *
 * Target: Generic ARM Cortex-M with STM32-like I2C peripheral
 */

#include <stdint.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────
 * I2C Register Definitions
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    volatile uint32_t CR1;     /* 0x00 Control register 1        */
    volatile uint32_t CR2;     /* 0x04 Control register 2        */
    volatile uint32_t OAR1;    /* 0x08 Own address register 1    */
    volatile uint32_t OAR2;    /* 0x0C Own address register 2    */
    volatile uint32_t DR;      /* 0x10 Data register             */
    volatile uint32_t SR1;     /* 0x14 Status register 1         */
    volatile uint32_t SR2;     /* 0x18 Status register 2         */
    volatile uint32_t CCR;     /* 0x1C Clock control register    */
    volatile uint32_t TRISE;   /* 0x20 Rise time register        */
} I2C_TypeDef;

#define I2C1 ((I2C_TypeDef *)0x40005400U)
#define I2C2 ((I2C_TypeDef *)0x40005800U)

/* CR1 bits */
#define I2C_CR1_PE      (1U << 0)
#define I2C_CR1_START   (1U << 8)
#define I2C_CR1_STOP    (1U << 9)
#define I2C_CR1_ACK     (1U << 10)
#define I2C_CR1_SWRST   (1U << 15)

/* SR1 bits */
#define I2C_SR1_SB      (1U << 0)   /* Start bit */
#define I2C_SR1_ADDR    (1U << 1)   /* Address sent */
#define I2C_SR1_BTF     (1U << 2)   /* Byte transfer finished */
#define I2C_SR1_RXNE    (1U << 6)   /* Data register not empty */
#define I2C_SR1_TXE     (1U << 7)   /* Data register empty */
#define I2C_SR1_AF      (1U << 10)  /* Acknowledge failure */

/* ──────────────────────────────────────────────────────────────────────────
 * Error Codes
 * ────────────────────────────────────────────────────────────────────────── */

typedef enum {
    I2C_OK          = 0,
    I2C_ERR_TIMEOUT = -1,
    I2C_ERR_NACK    = -2,
    I2C_ERR_BUS     = -3,
    I2C_ERR_PARAM   = -4
} i2c_status_t;

#define I2C_TIMEOUT 50000U

/* ──────────────────────────────────────────────────────────────────────────
 * I2C Driver API
 * ────────────────────────────────────────────────────────────────────────── */

void i2c_init(I2C_TypeDef *i2c, uint32_t pclk_mhz, uint32_t speed_hz)
{
    /* Software reset */
    i2c->CR1 |= I2C_CR1_SWRST;
    i2c->CR1 &= ~I2C_CR1_SWRST;

    /* Set peripheral clock frequency */
    i2c->CR2 = pclk_mhz & 0x3F;

    if (speed_hz <= 100000) {
        /* Standard mode: T_high = T_low = CCR × T_PCLK */
        uint32_t ccr = (pclk_mhz * 1000000U) / (2 * speed_hz);
        if (ccr < 4) ccr = 4;
        i2c->CCR = ccr;
        i2c->TRISE = pclk_mhz + 1;  /* 1000 ns max rise time */
    } else {
        /* Fast mode: T_low = 2 × T_high (duty cycle 2:1) */
        uint32_t ccr = (pclk_mhz * 1000000U) / (3 * speed_hz);
        if (ccr < 1) ccr = 1;
        i2c->CCR = (1U << 15) | ccr;  /* F/S = 1 (fast mode) */
        i2c->TRISE = (pclk_mhz * 300 / 1000) + 1;  /* 300 ns */
    }

    i2c->CR1 |= I2C_CR1_PE;
}

static i2c_status_t i2c_wait_flag(I2C_TypeDef *i2c, uint32_t flag)
{
    uint32_t timeout = I2C_TIMEOUT;
    while (!(i2c->SR1 & flag)) {
        if (i2c->SR1 & I2C_SR1_AF) {
            i2c->SR1 &= ~I2C_SR1_AF;
            i2c->CR1 |= I2C_CR1_STOP;
            return I2C_ERR_NACK;
        }
        if (--timeout == 0) {
            i2c->CR1 |= I2C_CR1_STOP;
            return I2C_ERR_TIMEOUT;
        }
    }
    return I2C_OK;
}

i2c_status_t i2c_write(I2C_TypeDef *i2c, uint8_t addr,
                        const uint8_t *data, uint16_t len)
{
    i2c_status_t status;

    /* Generate START */
    i2c->CR1 |= I2C_CR1_START;
    status = i2c_wait_flag(i2c, I2C_SR1_SB);
    if (status != I2C_OK) return status;

    /* Send address + write */
    i2c->DR = (addr << 1) | 0;
    status = i2c_wait_flag(i2c, I2C_SR1_ADDR);
    if (status != I2C_OK) return status;
    (void)i2c->SR2;  /* Clear ADDR by reading SR2 */

    /* Send data */
    for (uint16_t i = 0; i < len; i++) {
        status = i2c_wait_flag(i2c, I2C_SR1_TXE);
        if (status != I2C_OK) return status;
        i2c->DR = data[i];
    }

    /* Wait for last byte */
    status = i2c_wait_flag(i2c, I2C_SR1_BTF);
    if (status != I2C_OK) return status;

    /* Generate STOP */
    i2c->CR1 |= I2C_CR1_STOP;

    return I2C_OK;
}

i2c_status_t i2c_read(I2C_TypeDef *i2c, uint8_t addr,
                       uint8_t *data, uint16_t len)
{
    i2c_status_t status;

    if (len == 0) return I2C_OK;

    i2c->CR1 |= I2C_CR1_ACK;

    /* Generate START */
    i2c->CR1 |= I2C_CR1_START;
    status = i2c_wait_flag(i2c, I2C_SR1_SB);
    if (status != I2C_OK) return status;

    /* Send address + read */
    i2c->DR = (addr << 1) | 1;
    status = i2c_wait_flag(i2c, I2C_SR1_ADDR);
    if (status != I2C_OK) return status;

    if (len == 1) {
        i2c->CR1 &= ~I2C_CR1_ACK;  /* NACK after single byte */
        (void)i2c->SR2;
        i2c->CR1 |= I2C_CR1_STOP;
    } else {
        (void)i2c->SR2;
    }

    for (uint16_t i = 0; i < len; i++) {
        if (i == len - 1 && len > 1) {
            i2c->CR1 &= ~I2C_CR1_ACK;
            i2c->CR1 |= I2C_CR1_STOP;
        }

        status = i2c_wait_flag(i2c, I2C_SR1_RXNE);
        if (status != I2C_OK) return status;
        data[i] = (uint8_t)i2c->DR;
    }

    return I2C_OK;
}

/* Write register address, then read data (combined write+read) */
i2c_status_t i2c_mem_read(I2C_TypeDef *i2c, uint8_t addr,
                           uint8_t reg, uint8_t *data, uint16_t len)
{
    i2c_status_t status = i2c_write(i2c, addr, &reg, 1);
    if (status != I2C_OK) return status;
    return i2c_read(i2c, addr, data, len);
}

/* Write register address + data in one transaction */
i2c_status_t i2c_mem_write(I2C_TypeDef *i2c, uint8_t addr,
                            uint8_t reg, const uint8_t *data, uint16_t len)
{
    i2c_status_t status;

    i2c->CR1 |= I2C_CR1_START;
    status = i2c_wait_flag(i2c, I2C_SR1_SB);
    if (status != I2C_OK) return status;

    i2c->DR = (addr << 1) | 0;
    status = i2c_wait_flag(i2c, I2C_SR1_ADDR);
    if (status != I2C_OK) return status;
    (void)i2c->SR2;

    /* Register address */
    status = i2c_wait_flag(i2c, I2C_SR1_TXE);
    if (status != I2C_OK) return status;
    i2c->DR = reg;

    /* Data */
    for (uint16_t i = 0; i < len; i++) {
        status = i2c_wait_flag(i2c, I2C_SR1_TXE);
        if (status != I2C_OK) return status;
        i2c->DR = data[i];
    }

    status = i2c_wait_flag(i2c, I2C_SR1_BTF);
    if (status != I2C_OK) return status;
    i2c->CR1 |= I2C_CR1_STOP;

    return I2C_OK;
}

/* ──────────────────────────────────────────────────────────────────────────
 * I2C Bus Scanner
 * ────────────────────────────────────────────────────────────────────────── */

typedef void (*scan_callback_t)(uint8_t addr);

uint8_t i2c_scan(I2C_TypeDef *i2c, scan_callback_t found_cb)
{
    uint8_t count = 0;

    for (uint8_t addr = 0x08; addr < 0x78; addr++) {
        i2c->CR1 |= I2C_CR1_START;

        uint32_t timeout = 5000;
        while (!(i2c->SR1 & I2C_SR1_SB) && --timeout);
        if (!timeout) continue;

        i2c->DR = (addr << 1) | 0;

        timeout = 5000;
        while (--timeout) {
            if (i2c->SR1 & I2C_SR1_ADDR) {
                (void)i2c->SR2;
                i2c->CR1 |= I2C_CR1_STOP;
                if (found_cb) found_cb(addr);
                count++;
                break;
            }
            if (i2c->SR1 & I2C_SR1_AF) {
                i2c->SR1 &= ~I2C_SR1_AF;
                i2c->CR1 |= I2C_CR1_STOP;
                break;
            }
        }
    }

    return count;
}

/* ──────────────────────────────────────────────────────────────────────────
 * LM75 Temperature Sensor (I2C Address: 0x48–0x4F)
 * ────────────────────────────────────────────────────────────────────────── */

#define LM75_ADDR        0x48
#define LM75_REG_TEMP    0x00
#define LM75_REG_CONF    0x01
#define LM75_REG_THYST   0x02
#define LM75_REG_TOS     0x03

int16_t lm75_read_temp(I2C_TypeDef *i2c, uint8_t addr)
{
    uint8_t data[2];
    i2c_mem_read(i2c, addr, LM75_REG_TEMP, data, 2);

    /* 9-bit temperature: data[0] = integer, data[1] bit 7 = 0.5° */
    int16_t raw = ((int16_t)data[0] << 8) | data[1];
    return raw >> 7;  /* Result in 0.5°C units */
}

void lm75_set_overtemp(I2C_TypeDef *i2c, uint8_t addr, int8_t temp_c)
{
    uint8_t data[2] = {(uint8_t)temp_c, 0x00};
    i2c_mem_write(i2c, addr, LM75_REG_TOS, data, 2);
}

/* ──────────────────────────────────────────────────────────────────────────
 * AT24C EEPROM (I2C Address: 0x50–0x57)
 * ────────────────────────────────────────────────────────────────────────── */

#define AT24C_ADDR       0x50
#define AT24C_PAGE_SIZE  16    /* AT24C16 = 16 bytes/page */

i2c_status_t at24c_write_byte(I2C_TypeDef *i2c, uint8_t addr,
                               uint8_t mem_addr, uint8_t data)
{
    uint8_t buf[1] = {data};
    i2c_status_t status = i2c_mem_write(i2c, addr, mem_addr, buf, 1);

    /* EEPROM write cycle time: ~5 ms */
    for (volatile uint32_t i = 0; i < 50000; i++);

    return status;
}

i2c_status_t at24c_read_bytes(I2C_TypeDef *i2c, uint8_t addr,
                               uint8_t mem_addr, uint8_t *data,
                               uint16_t len)
{
    return i2c_mem_read(i2c, addr, mem_addr, data, len);
}

i2c_status_t at24c_write_page(I2C_TypeDef *i2c, uint8_t addr,
                               uint8_t mem_addr, const uint8_t *data,
                               uint8_t len)
{
    if (len > AT24C_PAGE_SIZE) len = AT24C_PAGE_SIZE;

    i2c_status_t status = i2c_mem_write(i2c, addr, mem_addr, data, len);

    for (volatile uint32_t i = 0; i < 50000; i++);

    return status;
}

/* ──────────────────────────────────────────────────────────────────────────
 * MPU6050 Accelerometer + Gyroscope (I2C Address: 0x68 or 0x69)
 * ────────────────────────────────────────────────────────────────────────── */

#define MPU6050_ADDR          0x68
#define MPU6050_REG_WHO_AM_I  0x75
#define MPU6050_REG_PWR_MGMT  0x6B
#define MPU6050_REG_ACCEL     0x3B  /* 6 bytes: AX_H, AX_L, AY_H, ... */
#define MPU6050_REG_GYRO      0x43  /* 6 bytes: GX_H, GX_L, GY_H, ... */
#define MPU6050_REG_TEMP      0x41  /* 2 bytes: TEMP_H, TEMP_L */

typedef struct {
    int16_t ax, ay, az;  /* Accelerometer raw (±2g default: 16384 LSB/g) */
    int16_t gx, gy, gz;  /* Gyroscope raw (±250°/s default: 131 LSB/°/s) */
    int16_t temp_raw;
} mpu6050_data_t;

i2c_status_t mpu6050_init(I2C_TypeDef *i2c, uint8_t addr)
{
    uint8_t who_am_i;
    i2c_status_t status = i2c_mem_read(i2c, addr, MPU6050_REG_WHO_AM_I,
                                        &who_am_i, 1);
    if (status != I2C_OK) return status;
    if (who_am_i != 0x68) return I2C_ERR_BUS;

    /* Wake up from sleep (clear bit 6) */
    uint8_t val = 0x00;
    return i2c_mem_write(i2c, addr, MPU6050_REG_PWR_MGMT, &val, 1);
}

i2c_status_t mpu6050_read(I2C_TypeDef *i2c, uint8_t addr,
                           mpu6050_data_t *data)
{
    uint8_t buf[14];
    i2c_status_t status = i2c_mem_read(i2c, addr, MPU6050_REG_ACCEL,
                                        buf, 14);
    if (status != I2C_OK) return status;

    data->ax = (int16_t)((buf[0]  << 8) | buf[1]);
    data->ay = (int16_t)((buf[2]  << 8) | buf[3]);
    data->az = (int16_t)((buf[4]  << 8) | buf[5]);
    data->temp_raw = (int16_t)((buf[6]  << 8) | buf[7]);
    data->gx = (int16_t)((buf[8]  << 8) | buf[9]);
    data->gy = (int16_t)((buf[10] << 8) | buf[11]);
    data->gz = (int16_t)((buf[12] << 8) | buf[13]);

    return I2C_OK;
}

int16_t mpu6050_temp_celsius(int16_t raw)
{
    return (raw / 340) + 36;
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: Multi-Sensor I2C System
 * ────────────────────────────────────────────────────────────────────────── */

extern void uart_printf(void *uart, const char *fmt, ...);
extern void delay_ms(uint32_t ms);

static void on_device_found(uint8_t addr)
{
    uart_printf((void *)0x40011000U, "  Found device at 0x%02X\r\n", addr);
}

int main(void)
{
    i2c_init(I2C1, 36, 400000);

    uart_printf((void *)0x40011000U, "Scanning I2C bus...\r\n");
    uint8_t found = i2c_scan(I2C1, on_device_found);
    uart_printf((void *)0x40011000U, "%u devices found.\r\n\r\n", found);

    /* Initialize MPU6050 */
    mpu6050_init(I2C1, MPU6050_ADDR);

    /* Store calibration offset in EEPROM */
    uint8_t cal_offset = 42;
    at24c_write_byte(I2C1, AT24C_ADDR, 0x00, cal_offset);

    uint8_t read_back;
    at24c_read_bytes(I2C1, AT24C_ADDR, 0x00, &read_back, 1);
    uart_printf((void *)0x40011000U, "EEPROM cal: %u\r\n", read_back);

    mpu6050_data_t imu;

    while (1) {
        /* Read temperature */
        int16_t temp = lm75_read_temp(I2C1, LM75_ADDR);
        uart_printf((void *)0x40011000U, "LM75: %d.%d°C  ",
                    temp / 2, (temp & 1) * 5);

        /* Read IMU */
        if (mpu6050_read(I2C1, MPU6050_ADDR, &imu) == I2C_OK) {
            uart_printf((void *)0x40011000U,
                "Accel: X=%d Y=%d Z=%d  Gyro: X=%d Y=%d Z=%d\r\n",
                imu.ax, imu.ay, imu.az, imu.gx, imu.gy, imu.gz);
        }

        delay_ms(500);
    }

    return 0;
}
