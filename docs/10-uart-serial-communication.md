# Chapter 10: UART / Serial Communication

UART (Universal Asynchronous Receiver/Transmitter) is the most common communication interface in embedded systems. It is used for debugging output, sensor communication, GPS modules, Bluetooth modules, and inter-processor communication.

## UART Fundamentals

UART transmits data **asynchronously** — there is no shared clock line. Both sides must agree on the data format:

| Parameter | Common Value |
|-----------|-------------|
| Baud rate | 9600, 115200 |
| Data bits | 8 |
| Parity | None |
| Stop bits | 1 |

A UART frame:

```
Idle ──┐   ┌───┬───┬───┬───┬───┬───┬───┬───┬───┐   ┌── Idle
  (1)  └───┤ D0│ D1│ D2│ D3│ D4│ D5│ D6│ D7│Stp│───┘   (1)
       Start                                  Stop
       bit                                    bit
       (0)        8 data bits (LSB first)     (1)
```

## UART Registers (STM32)

```c
typedef struct {
    volatile uint32_t SR;    /* Status register */
    volatile uint32_t DR;    /* Data register */
    volatile uint32_t BRR;   /* Baud rate register */
    volatile uint32_t CR1;   /* Control register 1 */
    volatile uint32_t CR2;   /* Control register 2 */
    volatile uint32_t CR3;   /* Control register 3 */
    volatile uint32_t GTPR;  /* Guard time and prescaler */
} USART_TypeDef;

#define USART1 ((USART_TypeDef *)0x40011000)
#define USART2 ((USART_TypeDef *)0x40004400)
```

### Key Status Flags

| Bit | Flag | Meaning |
|-----|------|---------|
| 5 | RXNE | Receive data register not empty (data available) |
| 6 | TC | Transmission complete |
| 7 | TXE | Transmit data register empty (ready to send) |
| 3 | ORE | Overrun error |

## Basic UART Driver

### Initialization

```c
void uart_init(uint32_t baudrate)
{
    /* Enable clocks */
    RCC->AHB1ENR |= (1U << 0);   /* GPIOA */
    RCC->APB2ENR |= (1U << 4);   /* USART1 */

    /* PA9 = TX, PA10 = RX — alternate function 7 */
    GPIOA->MODER &= ~((3U << 18) | (3U << 20));
    GPIOA->MODER |=  ((2U << 18) | (2U << 20));  /* AF mode */
    GPIOA->AFR[1] |= (7U << 4) | (7U << 8);      /* AF7 for PA9, PA10 */

    /* Configure baud rate */
    USART1->BRR = SystemCoreClock / baudrate;

    /* Enable USART: TX, RX, USART enable */
    USART1->CR1 = (1U << 3) |   /* TE: Transmitter enable */
                  (1U << 2) |   /* RE: Receiver enable */
                  (1U << 13);   /* UE: USART enable */
}
```

### Polling-Based Transmit

```c
void uart_send_byte(uint8_t byte)
{
    while (!(USART1->SR & (1U << 7)))  /* Wait for TXE */
        ;
    USART1->DR = byte;
}

void uart_send_string(const char *str)
{
    while (*str) {
        uart_send_byte(*str++);
    }
}

void uart_send_buffer(const uint8_t *buf, uint32_t len)
{
    for (uint32_t i = 0; i < len; i++) {
        uart_send_byte(buf[i]);
    }
}
```

### Polling-Based Receive

```c
uint8_t uart_receive_byte(void)
{
    while (!(USART1->SR & (1U << 5)))  /* Wait for RXNE */
        ;
    return (uint8_t)USART1->DR;
}
```

**Problem with polling:** The CPU is blocked waiting. If data arrives while the CPU is doing something else, it is lost.

## Interrupt-Driven UART with Ring Buffer

The proper way to handle UART in production code: use interrupts with a ring buffer.

### Ring Buffer for UART

```c
#define RX_BUF_SIZE 128

typedef struct {
    uint8_t  buffer[RX_BUF_SIZE];
    volatile uint16_t head;
    volatile uint16_t tail;
} RingBuffer;

static RingBuffer rx_buf = { .head = 0, .tail = 0 };

static inline uint8_t ringbuf_is_empty(const RingBuffer *rb)
{
    return rb->head == rb->tail;
}

static inline uint8_t ringbuf_is_full(const RingBuffer *rb)
{
    return ((rb->head + 1) % RX_BUF_SIZE) == rb->tail;
}

static inline void ringbuf_put(RingBuffer *rb, uint8_t byte)
{
    if (!ringbuf_is_full(rb)) {
        rb->buffer[rb->head] = byte;
        rb->head = (rb->head + 1) % RX_BUF_SIZE;
    }
}

static inline int16_t ringbuf_get(RingBuffer *rb)
{
    if (ringbuf_is_empty(rb))
        return -1;
    uint8_t byte = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) % RX_BUF_SIZE;
    return byte;
}
```

### ISR-Based Receive

```c
void uart_init_with_irq(uint32_t baudrate)
{
    uart_init(baudrate);

    USART1->CR1 |= (1U << 5);   /* RXNEIE: RX interrupt enable */
    NVIC_EnableIRQ(USART1_IRQn);
    NVIC_SetPriority(USART1_IRQn, 3);
}

void USART1_IRQHandler(void)
{
    if (USART1->SR & (1U << 5)) {  /* RXNE */
        uint8_t byte = (uint8_t)USART1->DR;
        ringbuf_put(&rx_buf, byte);
    }
}
```

### Reading from the Ring Buffer in Main

```c
int main(void)
{
    uart_init_with_irq(115200);
    uart_send_string("System ready\r\n");

    while (1) {
        int16_t byte = ringbuf_get(&rx_buf);
        if (byte >= 0) {
            process_byte((uint8_t)byte);
        }
    }
}
```

## Redirecting `printf` to UART

Override the `_write` system call (for GCC/Newlib):

```c
#include <stdio.h>

int _write(int file, char *data, int len)
{
    (void)file;
    for (int i = 0; i < len; i++) {
        uart_send_byte((uint8_t)data[i]);
    }
    return len;
}
```

Now `printf("Temperature: %d C\n", temp);` sends output over UART.

**Warning:** `printf` is large (adds ~10-20 KB of Flash) and slow. In resource-constrained systems, use custom lightweight print functions:

```c
void uart_print_int(int32_t value)
{
    char buf[12];
    int i = 0;
    uint32_t abs_val;

    if (value < 0) {
        uart_send_byte('-');
        abs_val = (uint32_t)(-(value + 1)) + 1;
    } else {
        abs_val = (uint32_t)value;
    }

    if (abs_val == 0) {
        uart_send_byte('0');
        return;
    }

    while (abs_val > 0) {
        buf[i++] = '0' + (abs_val % 10);
        abs_val /= 10;
    }

    while (i > 0) {
        uart_send_byte(buf[--i]);
    }
}

void uart_print_hex(uint32_t value)
{
    const char hex[] = "0123456789ABCDEF";
    uart_send_string("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart_send_byte(hex[(value >> i) & 0xF]);
    }
}
```

## Command Parser

A simple line-based command parser over UART:

```c
#define CMD_BUF_SIZE 64

void command_loop(void)
{
    char cmd_buf[CMD_BUF_SIZE];
    uint8_t cmd_idx = 0;

    uart_send_string("> ");

    while (1) {
        int16_t byte = ringbuf_get(&rx_buf);
        if (byte < 0)
            continue;

        char c = (char)byte;

        if (c == '\r' || c == '\n') {
            cmd_buf[cmd_idx] = '\0';
            uart_send_string("\r\n");

            if (cmd_idx > 0) {
                process_command(cmd_buf);
                cmd_idx = 0;
            }
            uart_send_string("> ");
        } else if (c == '\b' || c == 127) {
            if (cmd_idx > 0) {
                cmd_idx--;
                uart_send_string("\b \b");
            }
        } else if (cmd_idx < CMD_BUF_SIZE - 1) {
            cmd_buf[cmd_idx++] = c;
            uart_send_byte(c);  /* Echo */
        }
    }
}

void process_command(const char *cmd)
{
    if (strcmp(cmd, "status") == 0) {
        uart_send_string("System OK\r\n");
    } else if (strcmp(cmd, "reset") == 0) {
        NVIC_SystemReset();
    } else if (strncmp(cmd, "led ", 4) == 0) {
        int state = atoi(cmd + 4);
        gpio_write_pin(GPIOA, 5, state ? GPIO_PIN_SET : GPIO_PIN_RESET);
    } else {
        uart_send_string("Unknown command: ");
        uart_send_string(cmd);
        uart_send_string("\r\n");
    }
}
```

## Practical Examples

- [`examples/05_uart/uart_polling.c`](../examples/05_uart/uart_polling.c) — Basic polling UART transmit/receive
- [`examples/05_uart/uart_interrupt.c`](../examples/05_uart/uart_interrupt.c) — Interrupt-driven UART with ring buffer

## Summary

- UART is the most common debug and communication interface in embedded systems.
- Polling is simple but wastes CPU cycles and risks data loss.
- Interrupt-driven UART with a ring buffer is the production-quality approach.
- Use lightweight print functions instead of `printf` on constrained targets.
- Ring buffers decouple the ISR (producer) from main-loop processing (consumer).

---

**Next:** [Chapter 11 — ADC and DAC](11-adc-and-dac.md)
