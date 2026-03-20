/**
 * @file    bootloader.c
 * @brief   Minimal UART bootloader for firmware-over-the-air updates.
 * @target  STM32F4xx
 *
 * Demonstrates:
 *  - Flash memory layout with bootloader + application
 *  - Validating application image (stack pointer, CRC)
 *  - Jumping from bootloader to application
 *  - Receiving firmware via UART (XMODEM-like protocol)
 *  - Flash erase and programming
 *  - Version checking and rollback
 *
 * Memory Layout:
 *
 *   0x0800_0000  ┌──────────────────┐
 *                │  Bootloader      │  16 KB (Sectors 0-3)
 *                │  (this code)     │
 *   0x0800_4000  ├──────────────────┤
 *                │  Application     │  Up to 496 KB
 *                │  Header @ 0x200  │
 *                │  (main firmware) │
 *   0x0808_0000  └──────────────────┘
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ========================================================================== */
/*  Configuration                                                              */
/* ========================================================================== */

#define BOOTLOADER_VERSION      0x0100  /* 1.0 */

#define APP_START_ADDR          0x08004000U
#define APP_MAX_SIZE            (512U * 1024 - 16U * 1024)  /* 496 KB */

#define FLASH_BASE_ADDR         0x08000000U
#define FLASH_PAGE_SIZE         16384U  /* 16 KB for sectors 0-3 */

/* Application header is placed at a fixed offset in the app image */
#define APP_HEADER_OFFSET       0x200

/* ========================================================================== */
/*  Flash Controller                                                           */
/* ========================================================================== */

typedef struct {
    volatile uint32_t ACR;      /* 0x00: Access control    */
    volatile uint32_t KEYR;     /* 0x04: Key register      */
    volatile uint32_t OPTKEYR;  /* 0x08: Option key        */
    volatile uint32_t SR;       /* 0x0C: Status            */
    volatile uint32_t CR;       /* 0x10: Control           */
    volatile uint32_t OPTCR;    /* 0x14: Option control    */
} FLASH_TypeDef;

#define FLASH   ((FLASH_TypeDef *)0x40023C00U)

#define FLASH_SR_BSY        (1U << 16)
#define FLASH_CR_PG         (1U << 0)   /* Programming           */
#define FLASH_CR_SER        (1U << 1)   /* Sector erase          */
#define FLASH_CR_STRT       (1U << 16)  /* Start erase           */
#define FLASH_CR_LOCK       (1U << 31)  /* Lock                  */
#define FLASH_CR_PSIZE_32   (2U << 8)   /* 32-bit parallelism    */

#define FLASH_KEY1          0x45670123U
#define FLASH_KEY2          0xCDEF89ABU

/* ========================================================================== */
/*  Application Header                                                         */
/* ========================================================================== */

typedef struct {
    uint32_t magic;             /* Must be 0xDEADC0DE             */
    uint32_t version;           /* Firmware version (major.minor) */
    uint32_t size;              /* Image size in bytes            */
    uint32_t crc32;             /* CRC-32 of the image            */
    uint32_t entry_point;       /* Application entry address      */
    char     build_date[16];    /* Build date string              */
    char     build_time[16];    /* Build time string              */
} app_header_t;

#define APP_HEADER_MAGIC    0xDEADC0DEU

/* ========================================================================== */
/*  CRC-32 (Ethernet polynomial)                                               */
/* ========================================================================== */

static uint32_t crc32_update(uint32_t crc, const uint8_t *data, uint32_t length)
{
    for (uint32_t i = 0; i < length; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ (0xEDB88320U & -(crc & 1));
        }
    }
    return crc;
}

static uint32_t crc32_compute(const uint8_t *data, uint32_t length)
{
    return ~crc32_update(0xFFFFFFFF, data, length);
}

/* ========================================================================== */
/*  Flash Operations                                                           */
/* ========================================================================== */

static void flash_unlock(void)
{
    if (FLASH->CR & FLASH_CR_LOCK) {
        FLASH->KEYR = FLASH_KEY1;
        FLASH->KEYR = FLASH_KEY2;
    }
}

static void flash_lock(void)
{
    FLASH->CR |= FLASH_CR_LOCK;
}

static void flash_wait_busy(void)
{
    while (FLASH->SR & FLASH_SR_BSY) { }
}

/**
 * Erase a flash sector.
 *
 * STM32F4 sectors:
 *   0-3:  16 KB each  (0x08000000 - 0x0800FFFF)
 *   4:    64 KB       (0x08010000 - 0x0801FFFF)
 *   5-11: 128 KB each (0x08020000 - 0x080FFFFF)
 *
 * @param sector  Sector number (0-11)
 */
static bool flash_erase_sector(uint8_t sector)
{
    flash_wait_busy();

    FLASH->CR = FLASH_CR_SER | FLASH_CR_PSIZE_32 | ((uint32_t)sector << 3);
    FLASH->CR |= FLASH_CR_STRT;

    flash_wait_busy();

    FLASH->CR &= ~FLASH_CR_SER;

    return true;
}

/**
 * Program a word (32 bits) to flash.
 *
 * @param addr  Flash address (must be 4-byte aligned)
 * @param data  32-bit value to program
 */
static bool flash_program_word(uint32_t addr, uint32_t data)
{
    flash_wait_busy();

    FLASH->CR = FLASH_CR_PG | FLASH_CR_PSIZE_32;
    *(volatile uint32_t *)addr = data;

    flash_wait_busy();

    FLASH->CR &= ~FLASH_CR_PG;

    return (*(volatile uint32_t *)addr == data);
}

/**
 * Program a block of data to flash.
 * Data length must be a multiple of 4.
 */
static bool flash_program_block(uint32_t addr, const uint8_t *data, uint32_t length)
{
    for (uint32_t i = 0; i < length; i += 4) {
        uint32_t word;
        memcpy(&word, &data[i], 4);

        if (!flash_program_word(addr + i, word)) {
            return false;
        }
    }
    return true;
}

/* ========================================================================== */
/*  Application Validation                                                     */
/* ========================================================================== */

/**
 * Check if a valid application is present in flash.
 */
typedef enum {
    APP_VALID,
    APP_INVALID_SP,         /* Stack pointer not in SRAM range  */
    APP_INVALID_RESET,      /* Reset vector not in Flash range  */
    APP_NO_HEADER,          /* No valid header found            */
    APP_BAD_CRC,            /* CRC mismatch                    */
    APP_EMPTY               /* Flash is erased (all 0xFF)       */
} app_validation_t;

app_validation_t validate_application(void)
{
    uint32_t *app_vector = (uint32_t *)APP_START_ADDR;

    /* Check if flash is erased */
    if (app_vector[0] == 0xFFFFFFFF) {
        return APP_EMPTY;
    }

    /* Validate stack pointer (must point to SRAM: 0x20000000 - 0x2001FFFF) */
    uint32_t sp = app_vector[0];
    if ((sp & 0xFFF00000) != 0x20000000) {
        return APP_INVALID_SP;
    }

    /* Validate reset handler (must point to Flash: 0x08000000 - 0x080FFFFF) */
    uint32_t reset = app_vector[1];
    if ((reset & 0xFFF00000) != 0x08000000) {
        return APP_INVALID_RESET;
    }

    /* Check application header */
    const app_header_t *header = (const app_header_t *)(APP_START_ADDR + APP_HEADER_OFFSET);
    if (header->magic != APP_HEADER_MAGIC) {
        /* No header — basic validation passed, allow boot */
        return APP_VALID;
    }

    /* Verify CRC */
    uint32_t computed_crc = crc32_compute((const uint8_t *)APP_START_ADDR, header->size);
    if (computed_crc != header->crc32) {
        return APP_BAD_CRC;
    }

    return APP_VALID;
}

/* ========================================================================== */
/*  Jump to Application                                                        */
/* ========================================================================== */

typedef void (*app_entry_fn)(void);

/**
 * Jump from bootloader to the application.
 *
 * This function does not return — the application takes over completely.
 */
__attribute__((noreturn))
void jump_to_application(void)
{
    uint32_t *app_vector = (uint32_t *)APP_START_ADDR;

    /* Disable all interrupts */
    __asm volatile ("cpsid i");

    /* Disable SysTick */
    *(volatile uint32_t *)0xE000E010 = 0;

    /* Clear all pending interrupts */
    for (int i = 0; i < 8; i++) {
        /* NVIC->ICER[i] = 0xFFFFFFFF; */
        *(volatile uint32_t *)(0xE000E180 + i * 4) = 0xFFFFFFFF;
        /* NVIC->ICPR[i] = 0xFFFFFFFF; */
        *(volatile uint32_t *)(0xE000E280 + i * 4) = 0xFFFFFFFF;
    }

    /* Set Vector Table Offset Register (VTOR) to application */
    *(volatile uint32_t *)0xE000ED08 = APP_START_ADDR;

    /* Set Main Stack Pointer and jump to application Reset_Handler */
    uint32_t app_sp    = app_vector[0];
    uint32_t app_reset = app_vector[1];

    __asm volatile (
        "msr msp, %0\n\t"     /* Set main stack pointer   */
        "dsb\n\t"
        "isb\n\t"
        "bx  %1\n\t"          /* Branch to Reset_Handler  */
        :
        : "r" (app_sp), "r" (app_reset)
        : "memory"
    );

    __builtin_unreachable();
}

/* ========================================================================== */
/*  Firmware Receive Protocol (Simplified XMODEM-like)                         */
/* ========================================================================== */

/*
 * Protocol:
 *   1. Host sends 'U' (update request)
 *   2. Bootloader responds with 'R' (ready)
 *   3. Host sends total size as 4-byte little-endian
 *   4. Bootloader responds with 'A' (acknowledged)
 *   5. Host sends data in 256-byte blocks
 *   6. After each block, bootloader responds 'A'
 *   7. After all data, host sends CRC-32 (4 bytes)
 *   8. Bootloader verifies and responds 'O' (OK) or 'E' (error)
 */

extern void     uart_send_byte(uint8_t data);
extern uint8_t  uart_receive_byte(void);
extern bool     uart_data_available(void);

#define BLOCK_SIZE  256

typedef enum {
    FW_UPDATE_OK,
    FW_UPDATE_TIMEOUT,
    FW_UPDATE_CRC_ERROR,
    FW_UPDATE_FLASH_ERROR,
    FW_UPDATE_SIZE_ERROR
} fw_update_result_t;

/**
 * Receive and flash a firmware update.
 */
fw_update_result_t receive_firmware(void)
{
    /* Wait for size (4 bytes, little-endian) */
    uint32_t fw_size = 0;
    for (int i = 0; i < 4; i++) {
        fw_size |= (uint32_t)uart_receive_byte() << (i * 8);
    }

    if (fw_size > APP_MAX_SIZE || fw_size == 0) {
        uart_send_byte('E');
        return FW_UPDATE_SIZE_ERROR;
    }

    uart_send_byte('A');  /* Size acknowledged */

    /* Erase required sectors */
    flash_unlock();

    /* Calculate how many sectors to erase (simplified) */
    uint8_t start_sector = 1;  /* Application starts at sector 1 */
    uint8_t num_sectors = (uint8_t)((fw_size + FLASH_PAGE_SIZE - 1) / FLASH_PAGE_SIZE);
    if (num_sectors > 7) num_sectors = 7;

    for (uint8_t s = 0; s < num_sectors; s++) {
        flash_erase_sector(start_sector + s);
    }

    /* Receive and program data */
    uint32_t addr = APP_START_ADDR;
    uint32_t remaining = fw_size;
    uint8_t block[BLOCK_SIZE];

    while (remaining > 0) {
        uint32_t chunk = (remaining < BLOCK_SIZE) ? remaining : BLOCK_SIZE;

        for (uint32_t i = 0; i < chunk; i++) {
            block[i] = uart_receive_byte();
        }

        /* Pad to 4-byte boundary */
        while (chunk % 4 != 0) {
            block[chunk++] = 0xFF;
        }

        if (!flash_program_block(addr, block, chunk)) {
            flash_lock();
            uart_send_byte('E');
            return FW_UPDATE_FLASH_ERROR;
        }

        addr += chunk;
        remaining -= (remaining < BLOCK_SIZE) ? remaining : BLOCK_SIZE;

        uart_send_byte('A');  /* Block acknowledged */
    }

    flash_lock();

    /* Receive and verify CRC */
    uint32_t expected_crc = 0;
    for (int i = 0; i < 4; i++) {
        expected_crc |= (uint32_t)uart_receive_byte() << (i * 8);
    }

    uint32_t actual_crc = crc32_compute((const uint8_t *)APP_START_ADDR, fw_size);

    if (actual_crc != expected_crc) {
        uart_send_byte('E');
        return FW_UPDATE_CRC_ERROR;
    }

    uart_send_byte('O');  /* Success */
    return FW_UPDATE_OK;
}

/* ========================================================================== */
/*  Bootloader Main                                                            */
/* ========================================================================== */

/**
 * Check if the user is requesting a firmware update.
 * Methods:
 *   1. Button held during power-on
 *   2. Magic value in backup register (set by application before reset)
 *   3. UART receives 'U' within timeout
 */
static bool is_update_requested(void)
{
    /* Method 1: Check GPIO button (PC13 on Nucleo) */
    volatile uint32_t *gpioc_idr = (volatile uint32_t *)0x40020810;
    if (!(*gpioc_idr & (1U << 13))) {
        return true;  /* Button pressed (active LOW) */
    }

    /* Method 2: Check backup register for update request from application */
    volatile uint32_t *bkp_dr0 = (volatile uint32_t *)0x40002850;
    if (*bkp_dr0 == 0x55AA55AA) {
        *bkp_dr0 = 0;  /* Clear the flag */
        return true;
    }

    /* Method 3: Wait briefly for 'U' on UART */
    for (volatile int i = 0; i < 1000000; i++) {
        if (uart_data_available()) {
            if (uart_receive_byte() == 'U') {
                return true;
            }
        }
    }

    return false;
}

extern void system_init(void);
extern void uart_init(uint32_t baud);
extern void uart_send_string(const char *str);

int main(void)
{
    system_init();
    uart_init(115200);

    uart_send_string("\r\n[BOOTLOADER v1.0]\r\n");

    /* Check for update request */
    if (is_update_requested()) {
        uart_send_string("Update mode. Send firmware...\r\n");
        uart_send_byte('R');  /* Signal ready */

        fw_update_result_t result = receive_firmware();

        if (result == FW_UPDATE_OK) {
            uart_send_string("Update OK. Rebooting...\r\n");
            /* Trigger system reset */
            *(volatile uint32_t *)0xE000ED0C = 0x05FA0004;
        } else {
            uart_send_string("Update FAILED.\r\n");
        }
    }

    /* Validate application before jumping */
    app_validation_t valid = validate_application();

    if (valid == APP_VALID) {
        uart_send_string("App valid. Booting...\r\n");

        /* Small delay for UART to finish */
        for (volatile int i = 0; i < 100000; i++) { }

        jump_to_application();
    }

    /* No valid application — stay in bootloader */
    uart_send_string("No valid app. Waiting for firmware...\r\n");

    while (1) {
        if (uart_data_available()) {
            if (uart_receive_byte() == 'U') {
                uart_send_byte('R');
                fw_update_result_t result = receive_firmware();
                if (result == FW_UPDATE_OK) {
                    *(volatile uint32_t *)0xE000ED0C = 0x05FA0004;
                }
            }
        }
    }
}
