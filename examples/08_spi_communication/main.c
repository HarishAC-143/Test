/**
 * Example 08: SPI — Serial Peripheral Interface Communication
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Communicates with an SPI slave device (e.g., W25Q flash memory or
 * MCP3008 ADC) via SPI1:
 *   PA5 = SCLK, PA6 = MISO, PA7 = MOSI, PA4 = CS (manual GPIO)
 *
 * Concepts demonstrated:
 *   - SPI master configuration
 *   - Clock polarity (CPOL) and clock phase (CPHA)
 *   - Manual chip-select control
 *   - Full-duplex transfer (simultaneous TX and RX)
 *   - Reading a device ID (JEDEC ID from SPI flash)
 */

#include <stdint.h>
#include <stdbool.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define APB1_BASE         (PERIPH_BASE)
#define APB2_BASE         (PERIPH_BASE + 0x00010000)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE + 0x3800)
#define GPIOA_BASE        (AHB1_BASE + 0x0000)
#define SPI1_BASE         (APB2_BASE + 0x3000)
#define USART2_BASE       (APB1_BASE + 0x4400)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))
#define REG16(addr)       (*(volatile uint16_t *)(addr))

/* RCC */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)
#define RCC_APB2ENR       REG32(RCC_BASE + 0x44)

/* GPIOA */
#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_OSPEEDR     REG32(GPIOA_BASE + 0x08)
#define GPIOA_PUPDR       REG32(GPIOA_BASE + 0x0C)
#define GPIOA_ODR         REG32(GPIOA_BASE + 0x14)
#define GPIOA_BSRR        REG32(GPIOA_BASE + 0x18)
#define GPIOA_AFRL        REG32(GPIOA_BASE + 0x20)

/* SPI1 */
#define SPI1_CR1          REG32(SPI1_BASE + 0x00)
#define SPI1_CR2          REG32(SPI1_BASE + 0x04)
#define SPI1_SR           REG32(SPI1_BASE + 0x08)
#define SPI1_DR           REG32(SPI1_BASE + 0x0C)

/* USART2 */
#define USART2_SR         REG32(USART2_BASE + 0x00)
#define USART2_DR         REG32(USART2_BASE + 0x04)
#define USART2_BRR        REG32(USART2_BASE + 0x08)
#define USART2_CR1_REG    REG32(USART2_BASE + 0x0C)

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

/* SPI CR1 bits */
#define SPI_CR1_CPHA      BIT(0)
#define SPI_CR1_CPOL      BIT(1)
#define SPI_CR1_MSTR      BIT(2)
#define SPI_CR1_SPE       BIT(6)
#define SPI_CR1_SSI       BIT(8)
#define SPI_CR1_SSM       BIT(9)

/* SPI SR bits */
#define SPI_SR_RXNE       BIT(0)
#define SPI_SR_TXE        BIT(1)
#define SPI_SR_BSY        BIT(7)

/* Chip Select pin (PA4 — manual GPIO control) */
#define CS_PIN            4

/* SPI Flash commands (W25Q series) */
#define CMD_READ_JEDEC_ID 0x9F
#define CMD_READ_STATUS   0x05
#define CMD_WRITE_ENABLE  0x06
#define CMD_SECTOR_ERASE  0x20
#define CMD_PAGE_PROGRAM  0x02
#define CMD_READ_DATA     0x03

/* ───────────────────── UART (minimal) ───────────────────── */

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

static void uart_print_hex8(uint8_t val)
{
    const char hex[] = "0123456789ABCDEF";
    uart_putc(hex[(val >> 4) & 0x0F]);
    uart_putc(hex[val & 0x0F]);
}

/* ───────────────────── CS Control ───────────────────────── */

static void cs_low(void)
{
    GPIOA_BSRR = BIT(CS_PIN + 16);    /* Reset PA4 → LOW (select slave) */
}

static void cs_high(void)
{
    GPIOA_BSRR = BIT(CS_PIN);          /* Set PA4 → HIGH (deselect slave) */
}

/* ───────────────────── SPI Setup ────────────────────────── */

static void spi_init(void)
{
    RCC_AHB1ENR |= BIT(0);     /* GPIOA */
    RCC_APB2ENR |= BIT(12);    /* SPI1  */

    /*
     * PA4 = CS (output, push-pull, start HIGH)
     * PA5 = SCLK (AF5)
     * PA6 = MISO (AF5)
     * PA7 = MOSI (AF5)
     */

    /* PA4: General-purpose output for manual CS */
    GPIOA_MODER = (GPIOA_MODER & ~(0x03UL << (CS_PIN * 2))) | (0x01UL << (CS_PIN * 2));
    cs_high();

    /* PA5, PA6, PA7: Alternate function (AF5 = SPI1) */
    for (int pin = 5; pin <= 7; pin++) {
        GPIOA_MODER   = (GPIOA_MODER   & ~(0x03UL << (pin * 2))) | (0x02UL << (pin * 2));
        GPIOA_OSPEEDR = (GPIOA_OSPEEDR & ~(0x03UL << (pin * 2))) | (0x03UL << (pin * 2));
        GPIOA_AFRL    = (GPIOA_AFRL    & ~(0x0FUL << (pin * 4))) | (0x05UL << (pin * 4));
    }

    /*
     * SPI1 Configuration (CR1):
     *
     * - Master mode (MSTR = 1)
     * - Software slave management (SSM = 1, SSI = 1)
     * - CPOL = 0, CPHA = 0 (SPI Mode 0)
     * - Baud rate: F_APB2 / 16  (bits [5:3] = 011)
     *   APB2 = 16 MHz → SPI clock = 1 MHz
     * - 8-bit data frame (DFF = 0, default)
     * - MSB first (LSBFIRST = 0, default)
     */
    SPI1_CR1 = 0;
    SPI1_CR1 = SPI_CR1_MSTR
             | SPI_CR1_SSM
             | SPI_CR1_SSI
             | (0x03UL << 3);    /* BR = 011 → /16 */

    /* Enable SPI */
    SPI1_CR1 |= SPI_CR1_SPE;
}

/* ───────────────────── SPI Transfer ─────────────────────── */

/**
 * Full-duplex SPI transfer: send tx_byte, receive and return the
 * byte shifted in simultaneously from MISO.
 */
static uint8_t spi_transfer(uint8_t tx_byte)
{
    /* Wait until TX buffer is empty */
    while (!(SPI1_SR & SPI_SR_TXE)) { }

    /* Write data to send */
    SPI1_DR = tx_byte;

    /* Wait until RX buffer has data */
    while (!(SPI1_SR & SPI_SR_RXNE)) { }

    /* Read received data */
    return (uint8_t)(SPI1_DR & 0xFF);
}

/**
 * Send a command and read a response of `len` bytes.
 */
static void spi_command(uint8_t cmd, uint8_t *rx_buf, uint32_t len)
{
    cs_low();
    spi_transfer(cmd);
    for (uint32_t i = 0; i < len; i++) {
        rx_buf[i] = spi_transfer(0xFF);   /* Send dummy bytes to clock in data */
    }
    cs_high();
}

/* ───────────────────── Flash Operations ─────────────────── */

/**
 * Read JEDEC ID (Manufacturer, Memory Type, Capacity).
 * Returns 3 bytes: [manufacturer_id, memory_type, capacity].
 */
static void flash_read_jedec_id(uint8_t *id)
{
    spi_command(CMD_READ_JEDEC_ID, id, 3);
}

/**
 * Read the status register.
 */
static uint8_t flash_read_status(void)
{
    uint8_t status;
    spi_command(CMD_READ_STATUS, &status, 1);
    return status;
}

/**
 * Read data from flash at the given 24-bit address.
 */
static void flash_read(uint32_t addr, uint8_t *buf, uint32_t len)
{
    cs_low();
    spi_transfer(CMD_READ_DATA);
    spi_transfer((addr >> 16) & 0xFF);
    spi_transfer((addr >> 8)  & 0xFF);
    spi_transfer(addr & 0xFF);
    for (uint32_t i = 0; i < len; i++) {
        buf[i] = spi_transfer(0xFF);
    }
    cs_high();
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
    spi_init();

    uart_puts("=== SPI Communication Example ===\r\n");
    uart_puts("Reading JEDEC ID from SPI Flash (W25Q)\r\n\r\n");

    /* Read and display JEDEC ID */
    uint8_t jedec_id[3];
    flash_read_jedec_id(jedec_id);

    uart_puts("Manufacturer ID: 0x");
    uart_print_hex8(jedec_id[0]);
    uart_puts("\r\nMemory Type:     0x");
    uart_print_hex8(jedec_id[1]);
    uart_puts("\r\nCapacity:        0x");
    uart_print_hex8(jedec_id[2]);
    uart_puts("\r\n\r\n");

    /* Read first 16 bytes from flash address 0x000000 */
    uint8_t data[16];
    flash_read(0x000000, data, sizeof(data));

    uart_puts("First 16 bytes at 0x000000:\r\n");
    for (int i = 0; i < 16; i++) {
        uart_print_hex8(data[i]);
        uart_putc(' ');
        if ((i & 7) == 7) uart_puts("\r\n");
    }

    uart_puts("\r\nStatus Register: 0x");
    uart_print_hex8(flash_read_status());
    uart_puts("\r\n");

    while (1) {
        delay(1000000);
    }

    return 0;
}
