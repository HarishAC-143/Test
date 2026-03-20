/**
 * @file    spi_master.c
 * @brief   SPI master driver with practical sensor communication example.
 * @target  STM32F4xx (SPI1: PA5=SCK, PA6=MISO, PA7=MOSI, PA4=CS)
 *
 * Demonstrates:
 *  - SPI peripheral initialization (mode, speed, bit order)
 *  - Full-duplex byte transfer
 *  - Multi-byte transactions
 *  - Chip select management
 *  - Reading a SPI accelerometer (LIS3DH-style register protocol)
 *
 * SPI Modes:
 *   Mode 0: CPOL=0, CPHA=0 — Clock idle LOW,  sample on rising edge  (most common)
 *   Mode 1: CPOL=0, CPHA=1 — Clock idle LOW,  sample on falling edge
 *   Mode 2: CPOL=1, CPHA=0 — Clock idle HIGH, sample on falling edge
 *   Mode 3: CPOL=1, CPHA=1 — Clock idle HIGH, sample on rising edge
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))
#define RCC_APB2ENR     (*(volatile uint32_t *)(RCC_BASE + 0x44))

/* GPIO */
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

#define GPIOA   ((GPIO_TypeDef *)0x40020000U)

/* SPI1 */
typedef struct {
    volatile uint32_t CR1;      /* 0x00 */
    volatile uint32_t CR2;      /* 0x04 */
    volatile uint32_t SR;       /* 0x08 */
    volatile uint32_t DR;       /* 0x0C */
    volatile uint32_t CRCPR;    /* 0x10 */
    volatile uint32_t RXCRCR;   /* 0x14 */
    volatile uint32_t TXCRCR;   /* 0x18 */
    volatile uint32_t I2SCFGR;  /* 0x1C */
    volatile uint32_t I2SPR;    /* 0x20 */
} SPI_TypeDef;

#define SPI1    ((SPI_TypeDef *)0x40013000U)

/* SPI_CR1 bits */
#define SPI_CR1_CPHA        (1U << 0)
#define SPI_CR1_CPOL        (1U << 1)
#define SPI_CR1_MSTR        (1U << 2)
#define SPI_CR1_BR_DIV2     (0U << 3)
#define SPI_CR1_BR_DIV4     (1U << 3)
#define SPI_CR1_BR_DIV8     (2U << 3)
#define SPI_CR1_BR_DIV16    (3U << 3)
#define SPI_CR1_BR_DIV32    (4U << 3)
#define SPI_CR1_BR_DIV64    (5U << 3)
#define SPI_CR1_BR_DIV128   (6U << 3)
#define SPI_CR1_BR_DIV256   (7U << 3)
#define SPI_CR1_SPE         (1U << 6)
#define SPI_CR1_LSBFIRST    (1U << 7)
#define SPI_CR1_SSI         (1U << 8)
#define SPI_CR1_SSM         (1U << 9)

/* SPI_SR bits */
#define SPI_SR_RXNE         (1U << 0)
#define SPI_SR_TXE          (1U << 1)
#define SPI_SR_BSY          (1U << 7)

/* Chip Select pin (PA4, manual control) */
#define CS_PIN  4

/* ========================================================================== */
/*  SPI Driver                                                                 */
/* ========================================================================== */

typedef enum {
    SPI_MODE_0 = 0,                                 /* CPOL=0, CPHA=0 */
    SPI_MODE_1 = SPI_CR1_CPHA,                      /* CPOL=0, CPHA=1 */
    SPI_MODE_2 = SPI_CR1_CPOL,                      /* CPOL=1, CPHA=0 */
    SPI_MODE_3 = SPI_CR1_CPOL | SPI_CR1_CPHA        /* CPOL=1, CPHA=1 */
} spi_mode_t;

/**
 * Initialize SPI1 in master mode.
 *
 * @param mode          SPI mode (0-3)
 * @param prescaler_br  Baud rate prescaler (SPI_CR1_BR_DIVx)
 */
void spi_init(spi_mode_t mode, uint32_t prescaler_br)
{
    /* Enable clocks */
    RCC_AHB1ENR |= (1U << 0);   /* GPIOA */
    RCC_APB2ENR |= (1U << 12);  /* SPI1  */

    /*
     * Pin configuration:
     *   PA4 = CS   → General-purpose output (manual control)
     *   PA5 = SCK  → Alternate Function 5 (SPI1)
     *   PA6 = MISO → Alternate Function 5 (SPI1)
     *   PA7 = MOSI → Alternate Function 5 (SPI1)
     */

    /* PA4: Output for CS */
    GPIOA->MODER &= ~(3U << (CS_PIN * 2));
    GPIOA->MODER |=  (1U << (CS_PIN * 2));
    GPIOA->BSRR = (1U << CS_PIN);  /* CS HIGH (deselect) */

    /* PA5, PA6, PA7: AF5 */
    for (int pin = 5; pin <= 7; pin++) {
        GPIOA->MODER &= ~(3U << (pin * 2));
        GPIOA->MODER |=  (2U << (pin * 2));     /* AF mode */
        GPIOA->AFR[0] &= ~(0xFU << (pin * 4));
        GPIOA->AFR[0] |=  (5U << (pin * 4));    /* AF5 = SPI1 */
    }

    /* High speed for SPI pins */
    GPIOA->OSPEEDR |= (3U << 10) | (3U << 12) | (3U << 14);

    /* Configure SPI1 */
    SPI1->CR1 = 0;  /* Disable first */

    SPI1->CR1 = SPI_CR1_MSTR        /* Master mode              */
              | prescaler_br        /* Baud rate                */
              | (uint32_t)mode      /* Clock polarity and phase */
              | SPI_CR1_SSM         /* Software slave management */
              | SPI_CR1_SSI         /* Internal slave select     */
              | SPI_CR1_SPE;        /* Enable SPI                */
}

/**
 * Transfer one byte (full-duplex: sends tx_data, returns received byte).
 */
uint8_t spi_transfer_byte(uint8_t tx_data)
{
    while (!(SPI1->SR & SPI_SR_TXE)) { }   /* Wait for TX empty    */
    SPI1->DR = tx_data;                      /* Write data to send   */
    while (!(SPI1->SR & SPI_SR_RXNE)) { }  /* Wait for RX complete */
    return (uint8_t)SPI1->DR;                /* Read received data   */
}

/**
 * Transfer multiple bytes (full-duplex).
 */
void spi_transfer(const uint8_t *tx_buf, uint8_t *rx_buf, uint16_t length)
{
    for (uint16_t i = 0; i < length; i++) {
        uint8_t tx = tx_buf ? tx_buf[i] : 0xFF;
        uint8_t rx = spi_transfer_byte(tx);
        if (rx_buf) rx_buf[i] = rx;
    }
}

/**
 * Assert chip select (drive LOW).
 */
static inline void spi_cs_select(void)
{
    GPIOA->BSRR = (1U << (CS_PIN + 16));  /* Reset = LOW */
}

/**
 * Deassert chip select (drive HIGH).
 */
static inline void spi_cs_deselect(void)
{
    GPIOA->BSRR = (1U << CS_PIN);  /* Set = HIGH */
}

/**
 * Wait for SPI to finish all pending operations.
 */
void spi_wait_idle(void)
{
    while (SPI1->SR & SPI_SR_BSY) { }
}

/* ========================================================================== */
/*  LIS3DH Accelerometer Example                                              */
/* ========================================================================== */

/*
 * LIS3DH SPI register protocol:
 *   Byte 0: [R/W | MS | ADDR[5:0]]
 *     R/W = 1 for read, 0 for write
 *     MS  = 1 for multi-byte (auto-increment address)
 *     ADDR = 6-bit register address
 */

#define LIS3DH_READ         0x80
#define LIS3DH_WRITE        0x00
#define LIS3DH_MULTI_BYTE   0x40

/* Register addresses */
#define LIS3DH_WHO_AM_I     0x0F   /* Should return 0x33 */
#define LIS3DH_CTRL_REG1    0x20
#define LIS3DH_CTRL_REG4    0x23
#define LIS3DH_OUT_X_L      0x28
#define LIS3DH_OUT_X_H      0x29
#define LIS3DH_OUT_Y_L      0x2A
#define LIS3DH_OUT_Y_H      0x2B
#define LIS3DH_OUT_Z_L      0x2C
#define LIS3DH_OUT_Z_H      0x2D

/**
 * Read a single register from the LIS3DH.
 */
uint8_t lis3dh_read_reg(uint8_t reg)
{
    uint8_t value;

    spi_cs_select();
    spi_transfer_byte(reg | LIS3DH_READ);
    value = spi_transfer_byte(0x00);
    spi_cs_deselect();

    return value;
}

/**
 * Write a single register on the LIS3DH.
 */
void lis3dh_write_reg(uint8_t reg, uint8_t value)
{
    spi_cs_select();
    spi_transfer_byte(reg | LIS3DH_WRITE);
    spi_transfer_byte(value);
    spi_cs_deselect();
}

/**
 * Read multiple contiguous registers.
 */
void lis3dh_read_multi(uint8_t start_reg, uint8_t *buf, uint8_t length)
{
    spi_cs_select();
    spi_transfer_byte(start_reg | LIS3DH_READ | LIS3DH_MULTI_BYTE);
    for (uint8_t i = 0; i < length; i++) {
        buf[i] = spi_transfer_byte(0x00);
    }
    spi_cs_deselect();
}

typedef struct {
    int16_t x;
    int16_t y;
    int16_t z;
} accel_data_t;

/**
 * Initialize the LIS3DH accelerometer.
 *
 * @return true if the device responds correctly
 */
bool lis3dh_init(void)
{
    uint8_t who = lis3dh_read_reg(LIS3DH_WHO_AM_I);
    if (who != 0x33) {
        return false;  /* Device not found */
    }

    /* CTRL_REG1: 100 Hz data rate, enable X/Y/Z axes */
    lis3dh_write_reg(LIS3DH_CTRL_REG1, 0x57);

    /* CTRL_REG4: ±2g full scale, high resolution */
    lis3dh_write_reg(LIS3DH_CTRL_REG4, 0x08);

    return true;
}

/**
 * Read accelerometer XYZ data.
 */
accel_data_t lis3dh_read_accel(void)
{
    accel_data_t data;
    uint8_t raw[6];

    lis3dh_read_multi(LIS3DH_OUT_X_L, raw, 6);

    data.x = (int16_t)((uint16_t)raw[1] << 8 | raw[0]);
    data.y = (int16_t)((uint16_t)raw[3] << 8 | raw[2]);
    data.z = (int16_t)((uint16_t)raw[5] << 8 | raw[4]);

    return data;
}

/**
 * Convert raw accelerometer reading to milli-g (at ±2g, 12-bit resolution).
 */
int32_t lis3dh_raw_to_mg(int16_t raw)
{
    /* ±2g mode, 12-bit left-justified → divide by 16, then × (4000/4096) */
    return ((int32_t)(raw >> 4) * 1000) / 1024;
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    spi_init(SPI_MODE_0, SPI_CR1_BR_DIV16);  /* ~5 MHz at 84 MHz APB2 */

    if (!lis3dh_init()) {
        while (1) { }  /* Halt: accelerometer not found */
    }

    while (1) {
        accel_data_t accel = lis3dh_read_accel();

        int32_t x_mg = lis3dh_raw_to_mg(accel.x);
        int32_t y_mg = lis3dh_raw_to_mg(accel.y);
        int32_t z_mg = lis3dh_raw_to_mg(accel.z);

        (void)x_mg;
        (void)y_mg;
        (void)z_mg;

        /* Would typically send via UART or process for tilt detection */

        /* delay_ms(10); */
    }
}
