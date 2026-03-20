# Chapter 16: Debugging and Best Practices

Embedded bugs are often harder to find than desktop bugs — there is no debugger breakpoint in a deployed sensor node, no stack trace from a field-installed motor controller. Defensive coding and systematic debugging skills are essential.

## Defensive Coding

### Assertions

Catch bugs early by checking assumptions at runtime:

```c
#ifdef DEBUG
    #define ASSERT(expr) do {                               \
        if (!(expr)) {                                      \
            assert_failed(__FILE__, __LINE__, #expr);       \
        }                                                   \
    } while (0)
#else
    #define ASSERT(expr) ((void)0)
#endif

void assert_failed(const char *file, int line, const char *expr)
{
    __disable_irq();
    uart_send_string("ASSERT FAIL: ");
    uart_send_string(expr);
    uart_send_string(" at ");
    uart_send_string(file);
    uart_send_string(":");
    uart_print_int(line);
    uart_send_string("\r\n");

    while (1) {
        /* Halt — or trigger a watchdog reset */
    }
}
```

Use assertions to check:

```c
void buffer_write(Buffer *buf, uint8_t byte)
{
    ASSERT(buf != NULL);
    ASSERT(buf->index < buf->size);
    buf->data[buf->index++] = byte;
}

void set_pwm_duty(uint8_t percent)
{
    ASSERT(percent <= 100);
    TIM2->CCR1 = (TIM2->ARR + 1) * percent / 100;
}
```

### Compile-Time Assertions

Catch configuration errors at build time with zero runtime cost:

```c
_Static_assert(BUFFER_SIZE >= 64, "Buffer too small for protocol");
_Static_assert(sizeof(PacketFrame) == 8, "Packet frame size mismatch");
_Static_assert((RING_BUF_SIZE & (RING_BUF_SIZE - 1)) == 0,
               "Ring buffer size must be a power of 2");
```

### Defensive `switch` Statements

Always handle the default case:

```c
switch (state) {
case STATE_IDLE:
    break;
case STATE_RUNNING:
    break;
case STATE_ERROR:
    break;
default:
    error_handler("Invalid state");
    break;
}
```

Enable `-Wswitch-enum` to get warnings for missing enum cases.

## Error Handling Patterns

### Return Codes

```c
typedef enum {
    STATUS_OK = 0,
    STATUS_ERROR,
    STATUS_TIMEOUT,
    STATUS_BUSY,
    STATUS_INVALID_PARAM
} StatusCode;

StatusCode uart_send(const uint8_t *data, uint16_t len, uint32_t timeout_ms)
{
    if (data == NULL)
        return STATUS_INVALID_PARAM;
    if (len == 0)
        return STATUS_INVALID_PARAM;

    uint32_t start = get_tick();
    for (uint16_t i = 0; i < len; i++) {
        while (!(USART1->SR & (1U << 7))) {
            if ((get_tick() - start) > timeout_ms)
                return STATUS_TIMEOUT;
        }
        USART1->DR = data[i];
    }
    return STATUS_OK;
}
```

Always check return codes:

```c
StatusCode status = uart_send(buffer, length, 1000);
if (status != STATUS_OK) {
    handle_uart_error(status);
}
```

### Error Counters

Track error frequency for diagnostics:

```c
typedef struct {
    uint32_t uart_overrun;
    uint32_t uart_framing;
    uint32_t crc_mismatch;
    uint32_t buffer_overflow;
    uint32_t assert_failures;
    uint32_t watchdog_resets;
} ErrorCounters;

volatile ErrorCounters errors = {0};
```

## Hard Fault Debugging (ARM Cortex-M)

When the processor encounters an unrecoverable error (null pointer dereference, unaligned access, divide by zero), it triggers a **Hard Fault**:

```c
void HardFault_Handler(void)
{
    /* Read stacked registers to find the fault location */
    __asm volatile (
        "TST   LR, #4          \n"
        "ITE   EQ               \n"
        "MRSEQ R0, MSP          \n"
        "MRSNE R0, PSP          \n"
        "B     hard_fault_diag  \n"
    );
}

void hard_fault_diag(uint32_t *stack_frame)
{
    volatile uint32_t r0  = stack_frame[0];
    volatile uint32_t r1  = stack_frame[1];
    volatile uint32_t r2  = stack_frame[2];
    volatile uint32_t r3  = stack_frame[3];
    volatile uint32_t r12 = stack_frame[4];
    volatile uint32_t lr  = stack_frame[5];
    volatile uint32_t pc  = stack_frame[6];  /* Address of faulting instruction */
    volatile uint32_t psr = stack_frame[7];

    (void)r0; (void)r1; (void)r2; (void)r3;
    (void)r12; (void)lr; (void)psr;

    /* 'pc' tells you exactly which instruction caused the fault.
       Use addr2line to map it to source:
       arm-none-eabi-addr2line -e firmware.elf 0x08001234
    */

    while (1)
        ;
}
```

## Memory Safety

### Stack Overflow Detection

Fill the stack with a known pattern and check if it has been overwritten:

```c
#define STACK_CANARY 0xDEADBEEF

void check_stack_usage(void)
{
    extern uint32_t _estack;
    extern uint32_t _Min_Stack_Size;

    uint32_t *stack_bottom = &_estack - (uint32_t)&_Min_Stack_Size / 4;

    if (*stack_bottom != STACK_CANARY) {
        error_handler("Stack overflow detected!");
    }
}
```

### Buffer Overflow Prevention

```c
void safe_string_copy(char *dest, const char *src, uint16_t dest_size)
{
    uint16_t i;
    for (i = 0; i < dest_size - 1 && src[i] != '\0'; i++) {
        dest[i] = src[i];
    }
    dest[i] = '\0';
}

uint16_t safe_buffer_write(uint8_t *buf, uint16_t buf_size,
                           uint16_t *offset, uint8_t byte)
{
    if (*offset >= buf_size)
        return 0;
    buf[(*offset)++] = byte;
    return 1;
}
```

## Debugging Techniques

### 1. UART Debug Output

The most common debug tool — print values over serial:

```c
#ifdef DEBUG
    #define DBG(msg)          uart_send_string(msg "\r\n")
    #define DBG_VAL(msg, val) do { \
        uart_send_string(msg ": "); \
        uart_print_int(val); \
        uart_send_string("\r\n"); \
    } while (0)
    #define DBG_HEX(msg, val) do { \
        uart_send_string(msg ": "); \
        uart_print_hex(val); \
        uart_send_string("\r\n"); \
    } while (0)
#else
    #define DBG(msg)          ((void)0)
    #define DBG_VAL(msg, val) ((void)0)
    #define DBG_HEX(msg, val) ((void)0)
#endif
```

### 2. LED Status Codes

When no UART is available, blink an LED with a pattern:

```c
void blink_error_code(uint8_t code)
{
    while (1) {
        for (uint8_t i = 0; i < code; i++) {
            led_on();
            delay_ms(200);
            led_off();
            delay_ms(200);
        }
        delay_ms(1000);
    }
}
```

### 3. GPIO Pin Toggling for Timing Analysis

Toggle a GPIO pin around critical sections and measure with an oscilloscope or logic analyzer:

```c
void critical_function(void)
{
    DEBUG_PIN_HIGH();   /* Oscilloscope trigger */

    do_important_work();

    DEBUG_PIN_LOW();
}
```

### 4. Post-Mortem Analysis

Store crash information in non-volatile memory for later retrieval:

```c
typedef struct {
    uint32_t reset_reason;
    uint32_t fault_pc;
    uint32_t fault_lr;
    uint32_t uptime_seconds;
    uint32_t error_code;
} CrashInfo;

#define CRASH_INFO_ADDR  0x20007F00  /* End of RAM */

void save_crash_info(uint32_t pc, uint32_t lr)
{
    CrashInfo *info = (CrashInfo *)CRASH_INFO_ADDR;
    info->fault_pc = pc;
    info->fault_lr = lr;
    info->uptime_seconds = get_uptime();
    info->error_code = last_error;
}

void check_previous_crash(void)
{
    CrashInfo *info = (CrashInfo *)CRASH_INFO_ADDR;
    if (info->fault_pc != 0) {
        report_crash(info);
        memset(info, 0, sizeof(CrashInfo));
    }
}
```

## Coding Standards and Best Practices

### 1. Use a Coding Standard

Follow MISRA C, BARR-C, or your organization's standard. Key rules:

- No dynamic memory allocation (`malloc`/`free`) in safety-critical code
- All `switch` statements have a `default` case
- No pointer arithmetic on `void *`
- All variables initialized before use
- Functions have a single exit point (optional, but reduces errors)

### 2. Compiler Warnings as Errors

```makefile
CFLAGS += -Wall -Wextra -Werror -Wshadow -Wdouble-promotion
CFLAGS += -Wformat=2 -Wundef -fno-common
CFLAGS += -Wconversion -Wsign-conversion
```

### 3. Code Organization

```
project/
├── src/
│   ├── main.c
│   ├── drivers/          # Hardware abstraction
│   │   ├── gpio.c/.h
│   │   ├── uart.c/.h
│   │   └── spi.c/.h
│   ├── app/              # Application logic
│   │   ├── sensor.c/.h
│   │   └── controller.c/.h
│   └── lib/              # Reusable libraries
│       ├── ring_buffer.c/.h
│       └── crc.c/.h
├── inc/                  # Shared headers
│   └── config.h
├── test/                 # Unit tests
├── Makefile
└── linker_script.ld
```

### 4. Version Tracking

Embed build information in the firmware:

```c
const char firmware_version[] __attribute__((section(".version"))) =
    "v" VERSION_MAJOR "." VERSION_MINOR "." VERSION_PATCH
    " built " __DATE__ " " __TIME__;
```

### 5. Watchdog Integration

Always use a watchdog timer in production code:

```c
int main(void)
{
    system_init();
    watchdog_init(2000);  /* 2-second timeout */

    while (1) {
        if (run_system_check() == STATUS_OK) {
            watchdog_feed();
        }
        /* If system_check fails, watchdog will reset the MCU */

        process_events();
    }
}
```

## Summary

- Use assertions liberally during development; disable in production.
- Return error codes from all functions that can fail.
- Implement a Hard Fault handler that captures the fault address.
- Enable all compiler warnings and treat them as errors.
- Use UART debug output, LED blink codes, and GPIO toggling for diagnosis.
- Follow a coding standard and organize your project logically.
- Always include a watchdog timer as a safety net.
- Save crash information to non-volatile memory for field debugging.

---

**End of Guide**

Return to [Table of Contents](../README.md)
