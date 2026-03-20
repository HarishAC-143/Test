/**
 * @file    03_uart_driver.c
 * @brief   Polled UART driver with printf support
 *
 * Demonstrates:
 *  - UART initialization with baud rate calculation
 *  - Polled transmit and receive
 *  - String and formatted output (printf-style)
 *  - Simple command-line interface (CLI) over serial
 *  - Hex dump utility
 *
 * Target: Generic ARM Cortex-M with STM32-like USART peripheral
 */

#include <stdint.h>
#include <stdarg.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────
 * USART Register Definitions
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    volatile uint32_t SR;     /* 0x00 Status register       */
    volatile uint32_t DR;     /* 0x04 Data register          */
    volatile uint32_t BRR;    /* 0x08 Baud rate register     */
    volatile uint32_t CR1;    /* 0x0C Control register 1     */
    volatile uint32_t CR2;    /* 0x10 Control register 2     */
    volatile uint32_t CR3;    /* 0x14 Control register 3     */
    volatile uint32_t GTPR;   /* 0x18 Guard time / prescaler */
} USART_TypeDef;

#define USART1  ((USART_TypeDef *)0x40011000U)
#define USART2  ((USART_TypeDef *)0x40004400U)
#define USART3  ((USART_TypeDef *)0x40004800U)

/* Status register bits */
#define USART_SR_PE     (1U << 0)   /* Parity error */
#define USART_SR_FE     (1U << 1)   /* Framing error */
#define USART_SR_NE     (1U << 2)   /* Noise error */
#define USART_SR_ORE    (1U << 3)   /* Overrun error */
#define USART_SR_IDLE   (1U << 4)   /* IDLE line detected */
#define USART_SR_RXNE   (1U << 5)   /* Read data register not empty */
#define USART_SR_TC     (1U << 6)   /* Transmission complete */
#define USART_SR_TXE    (1U << 7)   /* Transmit data register empty */

/* Control register 1 bits */
#define USART_CR1_RE    (1U << 2)   /* Receiver enable */
#define USART_CR1_TE    (1U << 3)   /* Transmitter enable */
#define USART_CR1_RXNEIE (1U << 5)  /* RXNE interrupt enable */
#define USART_CR1_TXEIE (1U << 7)   /* TXE interrupt enable */
#define USART_CR1_M     (1U << 12)  /* Word length: 0=8bit, 1=9bit */
#define USART_CR1_UE    (1U << 13)  /* USART enable */

/* Control register 2 bits */
#define USART_CR2_STOP_1   (0U << 12)  /* 1 stop bit */
#define USART_CR2_STOP_2   (2U << 12)  /* 2 stop bits */

/* ──────────────────────────────────────────────────────────────────────────
 * UART Configuration
 * ────────────────────────────────────────────────────────────────────────── */

typedef enum {
    UART_PARITY_NONE = 0,
    UART_PARITY_EVEN = 1,
    UART_PARITY_ODD  = 2
} uart_parity_t;

typedef enum {
    UART_STOP_1 = 0,
    UART_STOP_2 = 1
} uart_stop_t;

typedef struct {
    uint32_t       baudrate;
    uart_parity_t  parity;
    uart_stop_t    stop_bits;
} uart_config_t;

/* ──────────────────────────────────────────────────────────────────────────
 * UART Driver API
 * ────────────────────────────────────────────────────────────────────────── */

void uart_init(USART_TypeDef *uart, const uart_config_t *cfg, uint32_t pclk)
{
    uart->CR1 = 0;  /* Disable USART before configuration */

    /* Baud rate: BRR = pclk / baudrate (with rounding) */
    uart->BRR = (pclk + (cfg->baudrate / 2)) / cfg->baudrate;

    /* Stop bits */
    uart->CR2 &= ~(0x3U << 12);
    if (cfg->stop_bits == UART_STOP_2) {
        uart->CR2 |= USART_CR2_STOP_2;
    }

    /* Parity and word length */
    uint32_t cr1 = USART_CR1_TE | USART_CR1_RE | USART_CR1_UE;
    if (cfg->parity != UART_PARITY_NONE) {
        cr1 |= (1U << 10);     /* Parity control enable */
        cr1 |= USART_CR1_M;    /* 9-bit word (8 data + 1 parity) */
        if (cfg->parity == UART_PARITY_ODD) {
            cr1 |= (1U << 9);  /* Odd parity */
        }
    }

    uart->CR1 = cr1;
}

void uart_deinit(USART_TypeDef *uart)
{
    while (!(uart->SR & USART_SR_TC));  /* Wait for last byte */
    uart->CR1 = 0;
}

/* ──────────────────────────────────────────────────────────────────────────
 * Polled Transmit / Receive
 * ────────────────────────────────────────────────────────────────────────── */

void uart_send_byte(USART_TypeDef *uart, uint8_t data)
{
    while (!(uart->SR & USART_SR_TXE));
    uart->DR = data;
}

uint8_t uart_recv_byte(USART_TypeDef *uart)
{
    while (!(uart->SR & USART_SR_RXNE));
    return (uint8_t)(uart->DR & 0xFF);
}

int uart_recv_byte_timeout(USART_TypeDef *uart, uint8_t *data,
                            uint32_t timeout_loops)
{
    while (timeout_loops--) {
        if (uart->SR & USART_SR_RXNE) {
            *data = (uint8_t)(uart->DR & 0xFF);
            return 0;
        }
    }
    return -1;  /* Timeout */
}

void uart_send_buffer(USART_TypeDef *uart, const uint8_t *buf, uint16_t len)
{
    for (uint16_t i = 0; i < len; i++) {
        uart_send_byte(uart, buf[i]);
    }
}

void uart_send_string(USART_TypeDef *uart, const char *str)
{
    while (*str) {
        uart_send_byte(uart, (uint8_t)*str++);
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Formatted Output (printf-style)
 * ────────────────────────────────────────────────────────────────────────── */

static char printf_buf[256];

void uart_printf(USART_TypeDef *uart, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    int len = vsnprintf(printf_buf, sizeof(printf_buf), fmt, args);
    va_end(args);

    if (len > 0) {
        if ((uint16_t)len > sizeof(printf_buf) - 1) {
            len = sizeof(printf_buf) - 1;
        }
        uart_send_buffer(uart, (const uint8_t *)printf_buf, (uint16_t)len);
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Utility: Hex Dump
 * ────────────────────────────────────────────────────────────────────────── */

static const char hex_chars[] = "0123456789ABCDEF";

void uart_hex_dump(USART_TypeDef *uart, const void *data, uint16_t len)
{
    const uint8_t *ptr = (const uint8_t *)data;

    for (uint16_t offset = 0; offset < len; offset += 16) {
        /* Address */
        uart_printf(uart, "%04X: ", offset);

        /* Hex bytes */
        for (uint8_t i = 0; i < 16; i++) {
            if (offset + i < len) {
                uint8_t b = ptr[offset + i];
                uart_send_byte(uart, hex_chars[b >> 4]);
                uart_send_byte(uart, hex_chars[b & 0x0F]);
                uart_send_byte(uart, ' ');
            } else {
                uart_send_string(uart, "   ");
            }
            if (i == 7) uart_send_byte(uart, ' ');
        }

        /* ASCII representation */
        uart_send_string(uart, " |");
        for (uint8_t i = 0; i < 16 && (offset + i) < len; i++) {
            uint8_t c = ptr[offset + i];
            uart_send_byte(uart, (c >= 0x20 && c <= 0x7E) ? c : '.');
        }
        uart_send_string(uart, "|\r\n");
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Simple Command-Line Interface (CLI)
 * ────────────────────────────────────────────────────────────────────────── */

#define CLI_MAX_CMD_LEN   64
#define CLI_MAX_ARGS       8
#define CLI_PROMPT         "> "

typedef void (*cli_handler_t)(uint8_t argc, const char *argv[]);

typedef struct {
    const char    *name;
    const char    *help;
    cli_handler_t  handler;
} cli_command_t;

/* Forward declarations for command handlers */
static void cmd_help(uint8_t argc, const char *argv[]);
static void cmd_led(uint8_t argc, const char *argv[]);
static void cmd_adc(uint8_t argc, const char *argv[]);
static void cmd_reset(uint8_t argc, const char *argv[]);

static const cli_command_t commands[] = {
    {"help",  "Show available commands",   cmd_help},
    {"led",   "Control LED: led <on|off>", cmd_led},
    {"adc",   "Read ADC: adc <channel>",   cmd_adc},
    {"reset", "Reset the system",          cmd_reset},
};
#define COMMAND_COUNT (sizeof(commands) / sizeof(commands[0]))

static USART_TypeDef *cli_uart;

static void cmd_help(uint8_t argc, const char *argv[])
{
    (void)argc;
    (void)argv;
    uart_send_string(cli_uart, "\r\nAvailable commands:\r\n");
    for (uint8_t i = 0; i < COMMAND_COUNT; i++) {
        uart_printf(cli_uart, "  %-10s %s\r\n",
                    commands[i].name, commands[i].help);
    }
}

static void cmd_led(uint8_t argc, const char *argv[])
{
    if (argc < 2) {
        uart_send_string(cli_uart, "Usage: led <on|off>\r\n");
        return;
    }
    if (strcmp(argv[1], "on") == 0) {
        uart_send_string(cli_uart, "LED ON\r\n");
        /* gpio_write(GPIOA, 5, 1); */
    } else if (strcmp(argv[1], "off") == 0) {
        uart_send_string(cli_uart, "LED OFF\r\n");
        /* gpio_write(GPIOA, 5, 0); */
    } else {
        uart_send_string(cli_uart, "Unknown option. Use 'on' or 'off'.\r\n");
    }
}

static void cmd_adc(uint8_t argc, const char *argv[])
{
    (void)argc;
    (void)argv;
    uart_printf(cli_uart, "ADC Channel 0: %u (placeholder)\r\n", 2048);
}

static void cmd_reset(uint8_t argc, const char *argv[])
{
    (void)argc;
    (void)argv;
    uart_send_string(cli_uart, "Resetting...\r\n");
    /* SCB->AIRCR = 0x05FA0004; */  /* System reset request */
}

static uint8_t parse_args(char *line, const char *argv[], uint8_t max_args)
{
    uint8_t argc = 0;
    char *p = line;

    while (*p && argc < max_args) {
        while (*p == ' ') p++;
        if (*p == '\0') break;
        argv[argc++] = p;
        while (*p && *p != ' ') p++;
        if (*p) *p++ = '\0';
    }

    return argc;
}

void cli_process_line(char *line)
{
    const char *argv[CLI_MAX_ARGS];
    uint8_t argc = parse_args(line, argv, CLI_MAX_ARGS);

    if (argc == 0) return;

    for (uint8_t i = 0; i < COMMAND_COUNT; i++) {
        if (strcmp(argv[0], commands[i].name) == 0) {
            commands[i].handler(argc, argv);
            return;
        }
    }

    uart_printf(cli_uart, "Unknown command: '%s'. Type 'help'.\r\n", argv[0]);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: Interactive Serial Console
 * ────────────────────────────────────────────────────────────────────────── */

int main(void)
{
    uart_config_t cfg = {
        .baudrate  = 115200,
        .parity    = UART_PARITY_NONE,
        .stop_bits = UART_STOP_1
    };
    uart_init(USART1, &cfg, 72000000U);
    cli_uart = USART1;

    uart_send_string(USART1, "\r\n=== Embedded C CLI Demo ===\r\n");
    uart_send_string(USART1, "Type 'help' for available commands.\r\n");

    char line[CLI_MAX_CMD_LEN];
    uint8_t pos = 0;

    uart_send_string(USART1, CLI_PROMPT);

    while (1) {
        uint8_t ch = uart_recv_byte(USART1);

        if (ch == '\r' || ch == '\n') {
            uart_send_string(USART1, "\r\n");
            line[pos] = '\0';
            cli_process_line(line);
            pos = 0;
            uart_send_string(USART1, CLI_PROMPT);
        } else if (ch == '\b' || ch == 0x7F) {
            if (pos > 0) {
                pos--;
                uart_send_string(USART1, "\b \b");
            }
        } else if (pos < CLI_MAX_CMD_LEN - 1) {
            line[pos++] = (char)ch;
            uart_send_byte(USART1, ch);  /* Echo */
        }
    }

    return 0;
}
