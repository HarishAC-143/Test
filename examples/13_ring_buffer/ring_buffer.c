/**
 * @file    ring_buffer.c
 * @brief   Ring buffer usage example and test.
 *
 * Demonstrates practical use cases:
 *  - UART RX buffering (ISR puts, main loop gets)
 *  - Line-oriented message parsing
 *  - Logging buffer
 */

#include "ring_buffer.h"
#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Example 1: UART RX with Ring Buffer                                        */
/* ========================================================================== */

static ring_buffer_t uart_rx_buf;

/**
 * Called from UART RX interrupt — stores received byte.
 */
void uart_rx_isr_handler(uint8_t received_byte)
{
    /* ISR is the sole producer — lock-free with single consumer in main loop */
    ring_buf_put(&uart_rx_buf, received_byte);
}

/**
 * Called from main loop — reads a complete line if available.
 *
 * @param line      Output buffer for the line
 * @param max_len   Maximum line length
 * @return          Length of line read, or 0 if no complete line available
 */
uint16_t uart_read_line(char *line, uint16_t max_len)
{
    uint16_t count = ring_buf_count(&uart_rx_buf);
    if (count == 0) return 0;

    /* Scan for newline without consuming data */
    bool found = false;
    uint16_t line_len = 0;
    uint16_t scan_idx = uart_rx_buf.tail;

    for (uint16_t i = 0; i < count; i++) {
        uint8_t c = uart_rx_buf.data[scan_idx];
        scan_idx = (scan_idx + 1) & (RING_BUF_CAPACITY - 1);

        if (c == '\n' || c == '\r') {
            found = true;
            line_len = i;  /* Length excluding the newline */
            break;
        }
    }

    if (!found) return 0;

    /* Extract the line */
    uint16_t copy_len = (line_len < max_len - 1) ? line_len : max_len - 1;
    ring_buf_read(&uart_rx_buf, (uint8_t *)line, copy_len);
    line[copy_len] = '\0';

    /* Skip the newline character(s) */
    uint8_t dummy;
    ring_buf_get(&uart_rx_buf, &dummy);  /* Consume \r or \n */
    if (!ring_buf_is_empty(&uart_rx_buf)) {
        ring_buf_peek(&uart_rx_buf, &dummy);
        if (dummy == '\n' || dummy == '\r') {
            ring_buf_get(&uart_rx_buf, &dummy);  /* Consume second char of \r\n */
        }
    }

    /* If we had to truncate, skip remaining characters of this line */
    if (line_len > copy_len) {
        ring_buf_skip(&uart_rx_buf, line_len - copy_len);
    }

    return copy_len;
}

/* ========================================================================== */
/*  Example 2: Fixed-Size Message Buffer                                       */
/* ========================================================================== */

/**
 * A typed ring buffer for fixed-size messages.
 * Each element is a complete struct rather than a single byte.
 */

typedef struct {
    uint8_t  type;
    uint8_t  priority;
    uint16_t data;
    uint32_t timestamp;
} message_t;

#define MSG_QUEUE_SIZE  16  /* Must be power of 2 */

typedef struct {
    message_t msgs[MSG_QUEUE_SIZE];
    volatile uint8_t head;
    volatile uint8_t tail;
} message_queue_t;

static message_queue_t msg_queue;

void msg_queue_init(message_queue_t *q)
{
    q->head = 0;
    q->tail = 0;
}

bool msg_queue_put(message_queue_t *q, const message_t *msg)
{
    uint8_t next = (q->head + 1) & (MSG_QUEUE_SIZE - 1);
    if (next == q->tail) return false;  /* Full */

    q->msgs[q->head] = *msg;
    q->head = next;
    return true;
}

bool msg_queue_get(message_queue_t *q, message_t *msg)
{
    if (q->head == q->tail) return false;  /* Empty */

    *msg = q->msgs[q->tail];
    q->tail = (q->tail + 1) & (MSG_QUEUE_SIZE - 1);
    return true;
}

/* ========================================================================== */
/*  Example 3: Logging Ring Buffer (Overwrites Oldest)                         */
/* ========================================================================== */

/**
 * A ring buffer that OVERWRITES the oldest data when full, instead of
 * rejecting new writes. Useful for debug logs where recent data matters most.
 */

#define LOG_BUF_SIZE    1024

typedef struct {
    char data[LOG_BUF_SIZE];
    uint16_t head;
    uint16_t tail;
    uint32_t overwrite_count;
} log_buffer_t;

static log_buffer_t debug_log;

void log_init(log_buffer_t *lb)
{
    lb->head = 0;
    lb->tail = 0;
    lb->overwrite_count = 0;
}

/**
 * Write a string to the log buffer. Overwrites oldest data if full.
 */
void log_write(log_buffer_t *lb, const char *str)
{
    while (*str) {
        lb->data[lb->head] = *str++;
        lb->head = (lb->head + 1) % LOG_BUF_SIZE;

        if (lb->head == lb->tail) {
            /* Buffer full — advance tail (discard oldest byte) */
            lb->tail = (lb->tail + 1) % LOG_BUF_SIZE;
            lb->overwrite_count++;
        }
    }
}

/**
 * Read all log contents into a buffer.
 * Returns number of bytes read.
 */
uint16_t log_read_all(log_buffer_t *lb, char *out, uint16_t max_len)
{
    uint16_t count = 0;
    uint16_t idx = lb->tail;

    while (idx != lb->head && count < max_len - 1) {
        out[count++] = lb->data[idx];
        idx = (idx + 1) % LOG_BUF_SIZE;
    }

    out[count] = '\0';
    return count;
}

/* ========================================================================== */
/*  Main — Demonstration                                                       */
/* ========================================================================== */

int main(void)
{
    /* Initialize buffers */
    ring_buf_init(&uart_rx_buf);
    msg_queue_init(&msg_queue);
    log_init(&debug_log);

    /* Simulate UART reception */
    const char *sim_data = "Hello\r\nWorld\r\n";
    for (int i = 0; sim_data[i]; i++) {
        uart_rx_isr_handler((uint8_t)sim_data[i]);
    }

    /* Read lines */
    char line[64];
    while (uart_read_line(line, sizeof(line)) > 0) {
        log_write(&debug_log, "Received: ");
        log_write(&debug_log, line);
        log_write(&debug_log, "\n");
    }

    /* Message queue usage */
    message_t msg = { .type = 1, .priority = 3, .data = 42, .timestamp = 1000 };
    msg_queue_put(&msg_queue, &msg);

    message_t received;
    if (msg_queue_get(&msg_queue, &received)) {
        (void)received;
    }

    /* Read debug log */
    char log_output[256];
    log_read_all(&debug_log, log_output, sizeof(log_output));
    (void)log_output;

    while (1) {
        /* Main loop */
    }
}
