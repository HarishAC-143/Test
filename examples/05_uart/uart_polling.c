/**
 * @file    uart_polling.c
 * @brief   Simple polling-based UART driver.
 * @target  STM32F4xx (USART2 on PA2/PA3 — connects to ST-Link VCP)
 *
 * Demonstrates:
 *  - UART peripheral initialization (baud rate, word length, parity)
 *  - Blocking send and receive
 *  - String and integer output
 *  - Simple command-line interface
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))
#define RCC_APB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x40))

/* GPIOA — PA2 = USART2_TX (AF7), PA3 = USART2_RX (AF7) */
#define GPIOA_BASE      0x40020000U
#define GPIOA_MODER     (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_AFRL      (*(volatile uint32_t *)(GPIOA_BASE + 0x20))

/* USART2 */
typedef struct {
    volatile uint32_t SR;     /* 0x00: Status register          */
    volatile uint32_t DR;     /* 0x04: Data register            */
    volatile uint32_t BRR;    /* 0x08: Baud rate register       */
    volatile uint32_t CR1;    /* 0x0C: Control register 1       */
    volatile uint32_t CR2;    /* 0x10: Control register 2       */
    volatile uint32_t CR3;    /* 0x14: Control register 3       */
    volatile uint32_t GTPR;   /* 0x18: Guard time and prescaler */
} USART_TypeDef;

#define USART2  ((USART_TypeDef *)0x40004400U)

/* Status register bits */
#define USART_SR_TXE    (1U << 7)   /* Transmit data register empty  */
#define USART_SR_TC     (1U << 6)   /* Transmission complete         */
#define USART_SR_RXNE   (1U << 5)   /* Read data register not empty  */
#define USART_SR_IDLE   (1U << 4)   /* Idle line detected            */
#define USART_SR_ORE    (1U << 3)   /* Overrun error                 */

/* Control register 1 bits */
#define USART_CR1_UE    (1U << 13)  /* USART enable                  */
#define USART_CR1_M     (1U << 12)  /* Word length (0=8bit, 1=9bit)  */
#define USART_CR1_PCE   (1U << 10)  /* Parity control enable         */
#define USART_CR1_PS    (1U << 9)   /* Parity selection (0=even)     */
#define USART_CR1_TE    (1U << 3)   /* Transmitter enable            */
#define USART_CR1_RE    (1U << 2)   /* Receiver enable               */

/* ========================================================================== */
/*  Configuration                                                              */
/* ========================================================================== */

#define APB1_CLOCK_HZ   42000000U   /* APB1 bus clock = 42 MHz */

/* ========================================================================== */
/*  UART Initialization                                                        */
/* ========================================================================== */

/**
 * Initialize USART2 at the specified baud rate.
 * Configuration: 8N1 (8 data bits, no parity, 1 stop bit).
 *
 * Baud rate calculation:
 *   USARTDIV = fCLK / (16 × baud)  for oversampling by 16
 *   BRR = mantissa[15:4] | fraction[3:0]
 *
 *   Example: 42 MHz / (16 × 115200) = 22.786
 *     Mantissa = 22 = 0x16
 *     Fraction = 0.786 × 16 = 12.6 ≈ 13 = 0xD
 *     BRR = 0x016D
 */
void uart_init(uint32_t baud_rate)
{
    /* Enable clocks */
    RCC_AHB1ENR |= (1U << 0);   /* GPIOA */
    RCC_APB1ENR |= (1U << 17);  /* USART2 */

    /* Configure PA2 (TX) and PA3 (RX) as Alternate Function 7 */
    GPIOA_MODER &= ~((3U << 4) | (3U << 6));
    GPIOA_MODER |=  ((2U << 4) | (2U << 6));   /* AF mode for PA2, PA3 */

    GPIOA_AFRL &= ~((0xFU << 8) | (0xFU << 12));
    GPIOA_AFRL |=  ((7U << 8) | (7U << 12));   /* AF7 = USART2 */

    /* Configure USART2 */
    USART2->CR1 = 0;  /* Disable USART before configuration */

    /* Calculate and set baud rate */
    uint32_t usart_div = APB1_CLOCK_HZ / baud_rate;
    USART2->BRR = usart_div;

    /* 8N1: M=0 (8 bits), PCE=0 (no parity), CR2 STOP=00 (1 stop bit) */
    USART2->CR2 = 0;
    USART2->CR3 = 0;

    /* Enable USART, TX, and RX */
    USART2->CR1 = USART_CR1_UE | USART_CR1_TE | USART_CR1_RE;
}

/* ========================================================================== */
/*  Basic I/O Functions                                                        */
/* ========================================================================== */

/**
 * Send a single byte (blocking).
 * Waits until the transmit data register is empty before writing.
 */
void uart_send_byte(uint8_t data)
{
    while (!(USART2->SR & USART_SR_TXE)) { }
    USART2->DR = data;
}

/**
 * Receive a single byte (blocking).
 * Waits until data is available in the receive data register.
 */
uint8_t uart_receive_byte(void)
{
    while (!(USART2->SR & USART_SR_RXNE)) { }
    return (uint8_t)(USART2->DR & 0xFF);
}

/**
 * Check if data is available to read (non-blocking check).
 */
bool uart_data_available(void)
{
    return (USART2->SR & USART_SR_RXNE) != 0;
}

/**
 * Send a null-terminated string.
 */
void uart_send_string(const char *str)
{
    while (*str) {
        if (*str == '\n') {
            uart_send_byte('\r');  /* Convert LF to CR+LF for terminals */
        }
        uart_send_byte((uint8_t)*str++);
    }
}

/**
 * Send a buffer of known length.
 */
void uart_send_buffer(const uint8_t *data, uint16_t length)
{
    for (uint16_t i = 0; i < length; i++) {
        uart_send_byte(data[i]);
    }
}

/**
 * Wait for transmission to fully complete (last byte shifted out).
 */
void uart_flush(void)
{
    while (!(USART2->SR & USART_SR_TC)) { }
}

/* ========================================================================== */
/*  Number Formatting                                                          */
/* ========================================================================== */

/**
 * Send an unsigned 32-bit integer as decimal ASCII.
 */
void uart_send_uint(uint32_t value)
{
    char buf[11];  /* Max 10 digits + null */
    int i = 0;

    if (value == 0) {
        uart_send_byte('0');
        return;
    }

    while (value > 0) {
        buf[i++] = '0' + (char)(value % 10);
        value /= 10;
    }

    /* Reverse and send */
    while (--i >= 0) {
        uart_send_byte((uint8_t)buf[i]);
    }
}

/**
 * Send a signed 32-bit integer as decimal ASCII.
 */
void uart_send_int(int32_t value)
{
    if (value < 0) {
        uart_send_byte('-');
        uart_send_uint((uint32_t)(-value));
    } else {
        uart_send_uint((uint32_t)value);
    }
}

/**
 * Send a byte as two hex digits.
 */
void uart_send_hex8(uint8_t value)
{
    const char hex[] = "0123456789ABCDEF";
    uart_send_byte((uint8_t)hex[value >> 4]);
    uart_send_byte((uint8_t)hex[value & 0x0F]);
}

/**
 * Send a 32-bit value as 8 hex digits with "0x" prefix.
 */
void uart_send_hex32(uint32_t value)
{
    uart_send_string("0x");
    for (int i = 28; i >= 0; i -= 4) {
        const char hex[] = "0123456789ABCDEF";
        uart_send_byte((uint8_t)hex[(value >> i) & 0xF]);
    }
}

/* ========================================================================== */
/*  Simple Command-Line Interface                                              */
/* ========================================================================== */

#define CMD_BUF_SIZE    64

/**
 * Read a line from UART with echo.
 * Returns when Enter is pressed.
 */
uint8_t uart_read_line(char *buf, uint8_t max_len)
{
    uint8_t pos = 0;

    while (pos < max_len - 1) {
        uint8_t c = uart_receive_byte();

        if (c == '\r' || c == '\n') {
            uart_send_string("\r\n");
            break;
        } else if (c == '\b' || c == 0x7F) {  /* Backspace or Delete */
            if (pos > 0) {
                pos--;
                uart_send_string("\b \b");  /* Erase character on terminal */
            }
        } else if (c >= ' ' && c < 0x7F) {  /* Printable characters */
            buf[pos++] = (char)c;
            uart_send_byte(c);  /* Echo */
        }
    }

    buf[pos] = '\0';
    return pos;
}

/**
 * Simple string comparison (no stdlib dependency).
 */
static bool str_equal(const char *a, const char *b)
{
    while (*a && *b) {
        if (*a++ != *b++) return false;
    }
    return (*a == *b);
}

/**
 * Process a command entered by the user.
 */
void process_command(const char *cmd)
{
    if (str_equal(cmd, "help")) {
        uart_send_string("Commands:\n");
        uart_send_string("  help    - Show this message\n");
        uart_send_string("  status  - Show system status\n");
        uart_send_string("  led on  - Turn on LED\n");
        uart_send_string("  led off - Turn off LED\n");
        uart_send_string("  reset   - Reset system\n");
    } else if (str_equal(cmd, "status")) {
        uart_send_string("System: OK\n");
        uart_send_string("Uptime: ");
        uart_send_uint(0);  /* Would use millis() / 1000 */
        uart_send_string(" seconds\n");
    } else if (str_equal(cmd, "led on")) {
        uart_send_string("LED ON\n");
    } else if (str_equal(cmd, "led off")) {
        uart_send_string("LED OFF\n");
    } else if (cmd[0] != '\0') {
        uart_send_string("Unknown command: '");
        uart_send_string(cmd);
        uart_send_string("'\nType 'help' for available commands.\n");
    }
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    uart_init(115200);

    uart_send_string("\r\n");
    uart_send_string("================================\n");
    uart_send_string(" Embedded C UART Demo\n");
    uart_send_string(" Baud: 115200, 8N1\n");
    uart_send_string("================================\n");
    uart_send_string("Type 'help' for commands.\n\n");

    char cmd_buf[CMD_BUF_SIZE];

    while (1) {
        uart_send_string("> ");
        uart_read_line(cmd_buf, CMD_BUF_SIZE);
        process_command(cmd_buf);
    }
}
