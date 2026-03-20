/**
 * UART Serial Communication Driver
 *
 * Demonstrates a complete UART driver with transmit, receive,
 * ring buffers, printf retargeting, and protocol framing.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdarg.h>

/* ----------------------------------------------------------------
 * Ring buffer implementation (used by UART RX/TX)
 * ---------------------------------------------------------------- */
#define UART_BUF_SIZE 64

typedef struct {
    volatile uint8_t  data[UART_BUF_SIZE];
    volatile uint16_t head;
    volatile uint16_t tail;
} UartRingBuffer;

static void rb_init(UartRingBuffer *rb) {
    rb->head = 0;
    rb->tail = 0;
}

static bool rb_put(UartRingBuffer *rb, uint8_t byte) {
    uint16_t next = (rb->head + 1) % UART_BUF_SIZE;
    if (next == rb->tail) return false;
    rb->data[rb->head] = byte;
    rb->head = next;
    return true;
}

static bool rb_get(UartRingBuffer *rb, uint8_t *byte) {
    if (rb->head == rb->tail) return false;
    *byte = rb->data[rb->tail];
    rb->tail = (rb->tail + 1) % UART_BUF_SIZE;
    return true;
}

static bool rb_empty(const UartRingBuffer *rb) {
    return rb->head == rb->tail;
}

/* ----------------------------------------------------------------
 * Simulated UART peripheral
 * ---------------------------------------------------------------- */
typedef struct {
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t BRR;
    volatile uint32_t SR;
    volatile uint32_t DR;
} USART_TypeDef;

static USART_TypeDef sim_usart2;
#define USART2 (&sim_usart2)

#define USART_SR_TXE   (1 << 7)
#define USART_SR_RXNE  (1 << 5)
#define USART_SR_TC    (1 << 6)

/* Loopback buffer (simulates the wire between TX and RX) */
static UartRingBuffer loopback_wire;
static UartRingBuffer uart_rx_buf;
static UartRingBuffer uart_tx_buf;

/* ----------------------------------------------------------------
 * UART driver functions
 * ---------------------------------------------------------------- */

typedef struct {
    uint32_t baudrate;
    uint8_t  word_length;   /* 8 or 9 */
    uint8_t  stop_bits;     /* 1 or 2 */
    char     parity;        /* 'N', 'E', 'O' */
} UartConfig;

static void uart_init(const UartConfig *cfg) {
    memset(USART2, 0, sizeof(USART_TypeDef));
    rb_init(&uart_rx_buf);
    rb_init(&uart_tx_buf);
    rb_init(&loopback_wire);

    /* Set baud rate (simulated with 36 MHz peripheral clock) */
    USART2->BRR = 36000000 / cfg->baudrate;

    /* Enable TX, RX, USART */
    USART2->CR1 = (1 << 13)   /* UE */
                | (1 << 3)    /* TE */
                | (1 << 2)    /* RE */
                | (1 << 5);   /* RXNEIE */

    USART2->SR = USART_SR_TXE | USART_SR_TC;

    printf("  UART initialized: %u baud, %u-%c-%u\n",
           cfg->baudrate, cfg->word_length, cfg->parity, cfg->stop_bits);
    printf("  BRR = %u, CR1 = 0x%08X\n\n", USART2->BRR, USART2->CR1);
}

static void uart_send_byte(uint8_t byte) {
    /* In real hardware: wait for TXE, then write DR */
    rb_put(&loopback_wire, byte);
    rb_put(&uart_tx_buf, byte);
}

static void uart_send_string(const char *str) {
    while (*str) {
        uart_send_byte((uint8_t)*str++);
    }
}

static void uart_send_buffer(const uint8_t *buf, uint16_t len) {
    for (uint16_t i = 0; i < len; i++) {
        uart_send_byte(buf[i]);
    }
}

/* Simulate ISR moving data from wire to RX buffer */
static void uart_sim_receive(void) {
    uint8_t byte;
    while (rb_get(&loopback_wire, &byte)) {
        rb_put(&uart_rx_buf, byte);
    }
}

static bool uart_rx_available(void) {
    return !rb_empty(&uart_rx_buf);
}

static uint8_t uart_read_byte(void) {
    uint8_t byte = 0;
    rb_get(&uart_rx_buf, &byte);
    return byte;
}

static uint16_t uart_read_line(char *buf, uint16_t max_len) {
    uint16_t idx = 0;
    while (idx < max_len - 1 && uart_rx_available()) {
        char c = (char)uart_read_byte();
        if (c == '\n' || c == '\r') break;
        buf[idx++] = c;
    }
    buf[idx] = '\0';
    return idx;
}

/* ----------------------------------------------------------------
 * Printf-style formatted output over UART
 * ---------------------------------------------------------------- */
static void uart_printf(const char *fmt, ...) {
    char buf[128];
    va_list args;
    va_start(args, fmt);
    int len = vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);

    if (len > 0) {
        uart_send_buffer((uint8_t *)buf, (uint16_t)len);
    }
}

/* ----------------------------------------------------------------
 * Demo: Basic UART send and receive
 * ---------------------------------------------------------------- */
static void demo_basic_uart(void) {
    printf("=== Demo: Basic UART Communication ===\n\n");

    UartConfig cfg = {
        .baudrate    = 115200,
        .word_length = 8,
        .stop_bits   = 1,
        .parity      = 'N'
    };
    uart_init(&cfg);

    /* Send a string */
    const char *msg = "Hello, Embedded World!";
    uart_send_string(msg);
    printf("  TX: \"%s\" (%zu bytes)\n", msg, strlen(msg));

    /* Simulate reception */
    uart_sim_receive();

    /* Read back */
    char rx_buf[64];
    uint16_t len = uart_read_line(rx_buf, sizeof(rx_buf));
    printf("  RX: \"%s\" (%u bytes)\n\n", rx_buf, len);
}

/* ----------------------------------------------------------------
 * Demo: Formatted UART output
 * ---------------------------------------------------------------- */
static void demo_formatted_output(void) {
    printf("=== Demo: Formatted UART Output ===\n\n");

    UartConfig cfg = { .baudrate = 9600, .word_length = 8,
                       .stop_bits = 1, .parity = 'N' };
    uart_init(&cfg);

    /* Simulate sensor data */
    float temperature = 23.5f;
    uint16_t adc_raw = 2048;
    uint32_t uptime_sec = 3661;

    uart_printf("Temp: %.1f C\r\n", temperature);
    uart_printf("ADC:  %u (0x%03X)\r\n", adc_raw, adc_raw);
    uart_printf("Up:   %02u:%02u:%02u\r\n",
                uptime_sec / 3600,
                (uptime_sec % 3600) / 60,
                uptime_sec % 60);

    /* Show what was transmitted */
    uart_sim_receive();
    printf("  Data sent via uart_printf():\n");
    printf("  ");
    while (uart_rx_available()) {
        char c = (char)uart_read_byte();
        if (c == '\r') printf("\\r");
        else if (c == '\n') { printf("\\n\n  "); }
        else printf("%c", c);
    }
    printf("\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Hex dump utility
 * ---------------------------------------------------------------- */
static void uart_hex_dump(const uint8_t *data, uint16_t len) {
    for (uint16_t i = 0; i < len; i += 16) {
        printf("  %04X: ", i);

        for (uint16_t j = 0; j < 16; j++) {
            if (i + j < len)
                printf("%02X ", data[i + j]);
            else
                printf("   ");
            if (j == 7) printf(" ");
        }

        printf(" |");
        for (uint16_t j = 0; j < 16 && (i + j) < len; j++) {
            uint8_t c = data[i + j];
            printf("%c", (c >= 32 && c < 127) ? c : '.');
        }
        printf("|\n");
    }
}

static void demo_hex_dump(void) {
    printf("=== Demo: Hex Dump Utility ===\n\n");

    uint8_t test_data[] = {
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x57, 0x6F,
        0x72, 0x6C, 0x64, 0x21, 0x0D, 0x0A, 0x00, 0xFF,
        0x01, 0x02, 0x03, 0x04, 0xDE, 0xAD, 0xBE, 0xEF,
    };

    uart_hex_dump(test_data, sizeof(test_data));
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Simple packet protocol
 * ---------------------------------------------------------------- */

/*
 * Frame format:
 *   [SOF] [LEN] [CMD] [DATA...] [CHECKSUM]
 *   SOF:      0xAA (start of frame)
 *   LEN:      payload length (CMD + DATA bytes)
 *   CMD:      command byte
 *   DATA:     0 or more data bytes
 *   CHECKSUM: XOR of all bytes from LEN to last DATA byte
 */

#define FRAME_SOF 0xAA

typedef struct {
    uint8_t cmd;
    uint8_t data[32];
    uint8_t data_len;
} Packet;

static uint8_t calc_checksum(const uint8_t *buf, uint16_t len) {
    uint8_t cs = 0;
    for (uint16_t i = 0; i < len; i++) {
        cs ^= buf[i];
    }
    return cs;
}

static void packet_send(const Packet *pkt) {
    uint8_t frame[64];
    uint8_t idx = 0;

    frame[idx++] = FRAME_SOF;
    frame[idx++] = pkt->data_len + 1;  /* LEN = cmd + data */
    frame[idx++] = pkt->cmd;

    for (int i = 0; i < pkt->data_len; i++) {
        frame[idx++] = pkt->data[i];
    }

    /* Checksum over LEN, CMD, and DATA */
    frame[idx] = calc_checksum(&frame[1], idx - 1);
    idx++;

    printf("  TX frame: ");
    for (int i = 0; i < idx; i++) {
        printf("%02X ", frame[i]);
    }
    printf("\n");
}

typedef enum {
    PARSE_WAIT_SOF,
    PARSE_LEN,
    PARSE_PAYLOAD,
    PARSE_CHECKSUM
} ParseState;

static bool packet_parse(const uint8_t *stream, uint16_t stream_len, Packet *out) {
    ParseState state = PARSE_WAIT_SOF;
    uint8_t payload[34];
    uint8_t payload_len = 0;
    uint8_t payload_idx = 0;

    for (uint16_t i = 0; i < stream_len; i++) {
        switch (state) {
        case PARSE_WAIT_SOF:
            if (stream[i] == FRAME_SOF) state = PARSE_LEN;
            break;

        case PARSE_LEN:
            payload_len = stream[i];
            payload_idx = 0;
            payload[payload_idx++] = stream[i];
            state = PARSE_PAYLOAD;
            break;

        case PARSE_PAYLOAD:
            payload[payload_idx++] = stream[i];
            if (payload_idx >= (uint8_t)(payload_len + 1)) {
                state = PARSE_CHECKSUM;
            }
            break;

        case PARSE_CHECKSUM: {
            uint8_t expected = calc_checksum(payload, payload_idx);
            if (stream[i] == expected) {
                out->cmd = payload[1];
                out->data_len = payload_len - 1;
                memcpy(out->data, &payload[2], out->data_len);
                return true;
            }
            printf("  Checksum mismatch: got 0x%02X, expected 0x%02X\n",
                   stream[i], expected);
            return false;
        }
        }
    }
    return false;
}

static void demo_packet_protocol(void) {
    printf("=== Demo: Packet Protocol ===\n\n");

    printf("  Frame format: [SOF=0xAA] [LEN] [CMD] [DATA...] [CHECKSUM]\n\n");

    /* Build and send a packet */
    Packet tx_pkt = {
        .cmd = 0x01,
        .data = { 0x48, 0x69, 0x21 },
        .data_len = 3
    };

    printf("  Sending CMD=0x%02X, data=\"Hi!\" (%u bytes):\n", tx_pkt.cmd, tx_pkt.data_len);
    packet_send(&tx_pkt);

    /* Parse a raw byte stream */
    uint8_t raw_stream[] = { 0xAA, 0x04, 0x02, 0x0A, 0x0B, 0x0C, 0x01 };
    /* Checksum: 0x04 ^ 0x02 ^ 0x0A ^ 0x0B ^ 0x0C = 0x01 */

    printf("\n  Parsing incoming stream: ");
    for (int i = 0; i < (int)sizeof(raw_stream); i++) {
        printf("%02X ", raw_stream[i]);
    }
    printf("\n");

    Packet rx_pkt = {0};
    if (packet_parse(raw_stream, sizeof(raw_stream), &rx_pkt)) {
        printf("  Parsed OK: CMD=0x%02X, %u data bytes: ",
               rx_pkt.cmd, rx_pkt.data_len);
        for (int i = 0; i < rx_pkt.data_len; i++) {
            printf("0x%02X ", rx_pkt.data[i]);
        }
        printf("\n");
    } else {
        printf("  Parse failed!\n");
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Baud rate calculation
 * ---------------------------------------------------------------- */
static void demo_baud_rates(void) {
    printf("=== UART Baud Rate Reference ===\n\n");

    uint32_t periph_clock = 36000000;
    uint32_t bauds[] = { 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600 };
    int n = sizeof(bauds) / sizeof(bauds[0]);

    printf("  Peripheral clock: %u Hz\n\n", periph_clock);
    printf("  %-10s  %-10s  %-12s  %-8s\n",
           "Baud Rate", "BRR Value", "Actual Baud", "Error");
    printf("  %-10s  %-10s  %-12s  %-8s\n",
           "----------", "----------", "------------", "--------");

    for (int i = 0; i < n; i++) {
        uint32_t brr = periph_clock / bauds[i];
        uint32_t actual = periph_clock / brr;
        double error = 100.0 * ((double)actual - bauds[i]) / bauds[i];

        printf("  %-10u  %-10u  %-12u  %+.2f%%\n",
               bauds[i], brr, actual, error);
    }

    printf("\n  Error < 2%% is generally acceptable for UART.\n\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  UART Serial Communication Driver        ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_basic_uart();
    demo_formatted_output();
    demo_hex_dump();
    demo_packet_protocol();
    demo_baud_rates();

    printf("═══ End of UART Driver Demo ═══\n");
    return 0;
}
