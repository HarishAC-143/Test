/**
 * @file    06_spi_driver.c
 * @brief   SPI master driver with Flash memory and sensor examples
 *
 * Demonstrates:
 *  - SPI master mode initialization (all 4 clock modes)
 *  - Byte and block transfers with CS management
 *  - W25Q SPI Flash memory operations (read, write, erase)
 *  - MAX31855 thermocouple sensor reading
 *  - MCP4921 DAC output
 *
 * Target: Generic ARM Cortex-M with STM32-like SPI peripheral
 */

#include <stdint.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────
 * SPI Register Definitions
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    volatile uint32_t CR1;      /* 0x00 Control register 1      */
    volatile uint32_t CR2;      /* 0x04 Control register 2      */
    volatile uint32_t SR;       /* 0x08 Status register         */
    volatile uint32_t DR;       /* 0x0C Data register           */
    volatile uint32_t CRCPR;    /* 0x10 CRC polynomial register */
    volatile uint32_t RXCRCR;   /* 0x14 RX CRC register         */
    volatile uint32_t TXCRCR;   /* 0x18 TX CRC register         */
} SPI_TypeDef;

#define SPI1 ((SPI_TypeDef *)0x40013000U)
#define SPI2 ((SPI_TypeDef *)0x40003800U)

/* CR1 bits */
#define SPI_CR1_CPHA    (1U << 0)
#define SPI_CR1_CPOL    (1U << 1)
#define SPI_CR1_MSTR    (1U << 2)
#define SPI_CR1_SPE     (1U << 6)
#define SPI_CR1_SSI     (1U << 8)
#define SPI_CR1_SSM     (1U << 9)
#define SPI_CR1_DFF     (1U << 11)  /* 0 = 8-bit, 1 = 16-bit */

/* SR bits */
#define SPI_SR_RXNE     (1U << 0)
#define SPI_SR_TXE      (1U << 1)
#define SPI_SR_BSY      (1U << 7)

/* GPIO definitions (abbreviated) */
typedef struct {
    volatile uint32_t MODER;
    volatile uint32_t OTYPER;
    volatile uint32_t OSPEEDR;
    volatile uint32_t PUPDR;
    volatile uint32_t IDR;
    volatile uint32_t ODR;
    volatile uint32_t BSRR;
    volatile uint32_t LCKR;
    volatile uint32_t AFRL;
    volatile uint32_t AFRH;
} GPIO_TypeDef;

#define GPIOA ((GPIO_TypeDef *)0x48000000U)
#define GPIOB ((GPIO_TypeDef *)0x48000400U)

/* ──────────────────────────────────────────────────────────────────────────
 * SPI Handle and Configuration
 * ────────────────────────────────────────────────────────────────────────── */

typedef enum {
    SPI_MODE_0 = 0,  /* CPOL=0 CPHA=0 */
    SPI_MODE_1 = 1,  /* CPOL=0 CPHA=1 */
    SPI_MODE_2 = 2,  /* CPOL=1 CPHA=0 */
    SPI_MODE_3 = 3   /* CPOL=1 CPHA=1 */
} spi_mode_t;

typedef enum {
    SPI_PRESCALER_2   = 0,
    SPI_PRESCALER_4   = 1,
    SPI_PRESCALER_8   = 2,
    SPI_PRESCALER_16  = 3,
    SPI_PRESCALER_32  = 4,
    SPI_PRESCALER_64  = 5,
    SPI_PRESCALER_128 = 6,
    SPI_PRESCALER_256 = 7
} spi_prescaler_t;

typedef struct {
    SPI_TypeDef  *hw;
    GPIO_TypeDef *cs_port;
    uint8_t       cs_pin;
} spi_device_t;

/* ──────────────────────────────────────────────────────────────────────────
 * SPI Driver API
 * ────────────────────────────────────────────────────────────────────────── */

void spi_init(SPI_TypeDef *spi, spi_mode_t mode, spi_prescaler_t prescaler)
{
    spi->CR1 = 0;

    uint32_t cr1 = SPI_CR1_MSTR | SPI_CR1_SSM | SPI_CR1_SSI;
    cr1 |= ((uint32_t)prescaler << 3);

    if (mode & 0x02) cr1 |= SPI_CR1_CPOL;
    if (mode & 0x01) cr1 |= SPI_CR1_CPHA;

    spi->CR1 = cr1;
    spi->CR1 |= SPI_CR1_SPE;
}

static inline void spi_cs_assert(const spi_device_t *dev)
{
    dev->cs_port->BSRR = (1U << (dev->cs_pin + 16));  /* Drive low */
}

static inline void spi_cs_deassert(const spi_device_t *dev)
{
    dev->cs_port->BSRR = (1U << dev->cs_pin);  /* Drive high */
}

uint8_t spi_transfer_byte(SPI_TypeDef *spi, uint8_t tx)
{
    while (!(spi->SR & SPI_SR_TXE));
    spi->DR = tx;
    while (!(spi->SR & SPI_SR_RXNE));
    return (uint8_t)(spi->DR & 0xFF);
}

void spi_transfer(const spi_device_t *dev, const uint8_t *tx,
                   uint8_t *rx, uint16_t len)
{
    spi_cs_assert(dev);

    for (uint16_t i = 0; i < len; i++) {
        uint8_t tx_byte = tx ? tx[i] : 0xFF;
        uint8_t rx_byte = spi_transfer_byte(dev->hw, tx_byte);
        if (rx) rx[i] = rx_byte;
    }

    while (dev->hw->SR & SPI_SR_BSY);  /* Wait until not busy */
    spi_cs_deassert(dev);
}

void spi_write(const spi_device_t *dev, const uint8_t *data, uint16_t len)
{
    spi_transfer(dev, data, (void *)0, len);
}

void spi_read(const spi_device_t *dev, uint8_t *data, uint16_t len)
{
    spi_transfer(dev, (void *)0, data, len);
}

/* Send a command byte then read response bytes */
void spi_cmd_read(const spi_device_t *dev, uint8_t cmd,
                  uint8_t *rx, uint16_t rx_len)
{
    spi_cs_assert(dev);
    spi_transfer_byte(dev->hw, cmd);
    for (uint16_t i = 0; i < rx_len; i++) {
        rx[i] = spi_transfer_byte(dev->hw, 0xFF);
    }
    while (dev->hw->SR & SPI_SR_BSY);
    spi_cs_deassert(dev);
}

/* ──────────────────────────────────────────────────────────────────────────
 * W25Q SPI Flash Driver (W25Q64, W25Q128, etc.)
 * ────────────────────────────────────────────────────────────────────────── */

#define W25Q_CMD_WRITE_ENABLE   0x06
#define W25Q_CMD_WRITE_DISABLE  0x04
#define W25Q_CMD_READ_STATUS1   0x05
#define W25Q_CMD_READ_STATUS2   0x35
#define W25Q_CMD_READ_DATA      0x03
#define W25Q_CMD_FAST_READ      0x0B
#define W25Q_CMD_PAGE_PROGRAM   0x02
#define W25Q_CMD_SECTOR_ERASE   0x20    /* 4 KB */
#define W25Q_CMD_BLOCK_ERASE32  0x52    /* 32 KB */
#define W25Q_CMD_BLOCK_ERASE64  0xD8    /* 64 KB */
#define W25Q_CMD_CHIP_ERASE     0xC7
#define W25Q_CMD_READ_JEDEC_ID  0x9F
#define W25Q_CMD_POWER_DOWN     0xB9
#define W25Q_CMD_RELEASE_PD     0xAB

#define W25Q_PAGE_SIZE          256
#define W25Q_SECTOR_SIZE        4096

typedef struct {
    spi_device_t dev;
    uint32_t     jedec_id;
    uint32_t     capacity_bytes;
} w25q_t;

static void w25q_write_enable(w25q_t *flash)
{
    spi_cs_assert(&flash->dev);
    spi_transfer_byte(flash->dev.hw, W25Q_CMD_WRITE_ENABLE);
    spi_cs_deassert(&flash->dev);
}

static void w25q_wait_busy(w25q_t *flash)
{
    uint8_t status;
    spi_cs_assert(&flash->dev);
    spi_transfer_byte(flash->dev.hw, W25Q_CMD_READ_STATUS1);
    do {
        status = spi_transfer_byte(flash->dev.hw, 0xFF);
    } while (status & 0x01);
    spi_cs_deassert(&flash->dev);
}

uint32_t w25q_read_id(w25q_t *flash)
{
    uint8_t rx[3];
    spi_cmd_read(&flash->dev, W25Q_CMD_READ_JEDEC_ID, rx, 3);
    flash->jedec_id = ((uint32_t)rx[0] << 16) |
                      ((uint32_t)rx[1] << 8)  | rx[2];
    return flash->jedec_id;
}

void w25q_read(w25q_t *flash, uint32_t addr, uint8_t *buf, uint16_t len)
{
    spi_cs_assert(&flash->dev);
    spi_transfer_byte(flash->dev.hw, W25Q_CMD_READ_DATA);
    spi_transfer_byte(flash->dev.hw, (addr >> 16) & 0xFF);
    spi_transfer_byte(flash->dev.hw, (addr >> 8)  & 0xFF);
    spi_transfer_byte(flash->dev.hw, addr & 0xFF);

    for (uint16_t i = 0; i < len; i++) {
        buf[i] = spi_transfer_byte(flash->dev.hw, 0xFF);
    }
    spi_cs_deassert(&flash->dev);
}

void w25q_page_program(w25q_t *flash, uint32_t addr,
                        const uint8_t *data, uint16_t len)
{
    if (len > W25Q_PAGE_SIZE) len = W25Q_PAGE_SIZE;

    w25q_write_enable(flash);

    spi_cs_assert(&flash->dev);
    spi_transfer_byte(flash->dev.hw, W25Q_CMD_PAGE_PROGRAM);
    spi_transfer_byte(flash->dev.hw, (addr >> 16) & 0xFF);
    spi_transfer_byte(flash->dev.hw, (addr >> 8)  & 0xFF);
    spi_transfer_byte(flash->dev.hw, addr & 0xFF);

    for (uint16_t i = 0; i < len; i++) {
        spi_transfer_byte(flash->dev.hw, data[i]);
    }
    spi_cs_deassert(&flash->dev);

    w25q_wait_busy(flash);
}

void w25q_sector_erase(w25q_t *flash, uint32_t addr)
{
    w25q_write_enable(flash);

    spi_cs_assert(&flash->dev);
    spi_transfer_byte(flash->dev.hw, W25Q_CMD_SECTOR_ERASE);
    spi_transfer_byte(flash->dev.hw, (addr >> 16) & 0xFF);
    spi_transfer_byte(flash->dev.hw, (addr >> 8)  & 0xFF);
    spi_transfer_byte(flash->dev.hw, addr & 0xFF);
    spi_cs_deassert(&flash->dev);

    w25q_wait_busy(flash);
}

/* Write arbitrary length data spanning multiple pages */
void w25q_write(w25q_t *flash, uint32_t addr,
                const uint8_t *data, uint32_t len)
{
    while (len > 0) {
        uint16_t page_offset = addr % W25Q_PAGE_SIZE;
        uint16_t chunk = W25Q_PAGE_SIZE - page_offset;
        if (chunk > len) chunk = (uint16_t)len;

        w25q_page_program(flash, addr, data, chunk);

        addr += chunk;
        data += chunk;
        len  -= chunk;
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * MAX31855 Thermocouple-to-Digital Converter
 *
 * Read-only SPI device: 32-bit read produces temperature data.
 *   Bits 31:18 = thermocouple temperature (14-bit signed, 0.25°C)
 *   Bit 16     = fault flag
 *   Bits 15:4  = internal reference temperature (12-bit signed, 0.0625°C)
 *   Bit 2      = short to VCC
 *   Bit 1      = short to GND
 *   Bit 0      = open circuit
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    spi_device_t dev;
    int16_t      thermocouple_temp;  /* In 0.25°C units */
    int16_t      internal_temp;      /* In 0.0625°C units */
    uint8_t      fault;
} max31855_t;

void max31855_read(max31855_t *tc)
{
    uint8_t rx[4];
    spi_read(&tc->dev, rx, 4);

    uint32_t raw = ((uint32_t)rx[0] << 24) | ((uint32_t)rx[1] << 16) |
                   ((uint32_t)rx[2] << 8)  | rx[3];

    tc->fault = (raw >> 16) & 0x01;

    /* Thermocouple temperature: bits 31:18, 14-bit signed */
    int16_t tc_raw = (int16_t)(raw >> 18);
    if (tc_raw & 0x2000) tc_raw |= 0xC000;  /* Sign-extend */
    tc->thermocouple_temp = tc_raw;

    /* Internal temperature: bits 15:4, 12-bit signed */
    int16_t int_raw = (int16_t)((raw >> 4) & 0x0FFF);
    if (int_raw & 0x0800) int_raw |= 0xF000;
    tc->internal_temp = int_raw;
}

int16_t max31855_get_celsius(const max31855_t *tc)
{
    return tc->thermocouple_temp / 4;
}

/* ──────────────────────────────────────────────────────────────────────────
 * MCP4921 12-bit DAC
 *
 * 16-bit SPI write:
 *   Bit 15:   0 = DAC_A
 *   Bit 14:   BUF (0 = unbuffered)
 *   Bit 13:   GA (1 = 1x gain, 0 = 2x gain)
 *   Bit 12:   SHDN (1 = active, 0 = shutdown)
 *   Bits 11:0 = 12-bit data
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    spi_device_t dev;
} mcp4921_t;

void mcp4921_write(mcp4921_t *dac, uint16_t value)
{
    if (value > 4095) value = 4095;

    uint16_t cmd = (0U << 15)   /* DAC A */
                 | (0U << 14)   /* Unbuffered */
                 | (1U << 13)   /* 1x gain */
                 | (1U << 12)   /* Active */
                 | (value & 0x0FFF);

    uint8_t tx[2] = {(uint8_t)(cmd >> 8), (uint8_t)(cmd & 0xFF)};
    spi_write(&dac->dev, tx, 2);
}

void mcp4921_set_voltage(mcp4921_t *dac, uint32_t millivolts,
                          uint32_t vref_mv)
{
    uint16_t value = (uint16_t)((millivolts * 4095UL) / vref_mv);
    mcp4921_write(dac, value);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: Flash + Sensor + DAC System
 * ────────────────────────────────────────────────────────────────────────── */

extern void delay_ms(uint32_t ms);
extern void uart_printf(void *uart, const char *fmt, ...);

int main(void)
{
    spi_init(SPI1, SPI_MODE_0, SPI_PRESCALER_8);

    /* Setup devices with their CS pins */
    w25q_t flash = {
        .dev = {.hw = SPI1, .cs_port = GPIOA, .cs_pin = 4}
    };

    max31855_t thermocouple = {
        .dev = {.hw = SPI1, .cs_port = GPIOB, .cs_pin = 0}
    };

    mcp4921_t dac = {
        .dev = {.hw = SPI1, .cs_port = GPIOB, .cs_pin = 1}
    };

    /* Read Flash ID */
    uint32_t id = w25q_read_id(&flash);
    uart_printf((void *)0x40011000U, "Flash ID: 0x%06lX\r\n",
                (unsigned long)id);

    /* Store calibration data to Flash */
    uint8_t cal_data[16] = {0xCA, 0xFE, 0xBA, 0xBE};
    w25q_sector_erase(&flash, 0x000000);
    w25q_write(&flash, 0x000000, cal_data, sizeof(cal_data));

    /* Read it back and verify */
    uint8_t read_back[16];
    w25q_read(&flash, 0x000000, read_back, sizeof(read_back));

    while (1) {
        /* Read thermocouple */
        max31855_read(&thermocouple);
        int16_t temp_c = max31855_get_celsius(&thermocouple);

        uart_printf((void *)0x40011000U, "Temperature: %d°C\r\n", temp_c);

        /* Output proportional voltage on DAC (e.g., 10 mV/°C) */
        uint32_t dac_mv = (uint32_t)(temp_c * 10);
        if (dac_mv > 3300) dac_mv = 3300;
        mcp4921_set_voltage(&dac, dac_mv, 3300);

        delay_ms(1000);
    }

    return 0;
}
