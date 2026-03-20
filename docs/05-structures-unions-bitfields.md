# Chapter 5: Structures, Unions, and Bit-Fields

Structures and unions are the primary tools for modeling hardware registers, communication protocol frames, and complex data in embedded systems.

## Structures for Hardware Register Mapping

As introduced in Chapter 4, structs map naturally onto peripheral register blocks:

```c
typedef struct {
    volatile uint32_t CR;      /* Control register     (offset 0x00) */
    volatile uint32_t CFGR;    /* Configuration        (offset 0x04) */
    volatile uint32_t CIR;     /* Clock interrupt      (offset 0x08) */
    volatile uint32_t APB2RSTR;/* APB2 reset           (offset 0x0C) */
    volatile uint32_t APB1RSTR;/* APB1 reset           (offset 0x10) */
    volatile uint32_t AHB1ENR; /* AHB1 clock enable    (offset 0x14) */
} RCC_TypeDef;

#define RCC ((RCC_TypeDef *)0x40023800)
```

### Reserved / Unused Register Slots

Hardware often has gaps in the register map. Model them with dummy members:

```c
typedef struct {
    volatile uint32_t CR1;       /* 0x00 */
    volatile uint32_t CR2;       /* 0x04 */
    volatile uint32_t SMCR;      /* 0x08 */
    volatile uint32_t DIER;      /* 0x0C */
    volatile uint32_t SR;        /* 0x10 */
    volatile uint32_t EGR;       /* 0x14 */
    volatile uint32_t CCMR1;     /* 0x18 */
    volatile uint32_t CCMR2;     /* 0x1C */
    volatile uint32_t CCER;      /* 0x20 */
    volatile uint32_t CNT;       /* 0x24 */
    volatile uint32_t PSC;       /* 0x28 */
    volatile uint32_t ARR;       /* 0x2C */
    uint32_t          RESERVED;  /* 0x30 — unused register slot */
    volatile uint32_t CCR1;      /* 0x34 */
} TIM_TypeDef;
```

## Unions

A union stores all members at the **same memory location**. Each member provides a different view of the same underlying data. They are useful in two major patterns:

### Pattern 1: Multi-Format Register Access

Access a 32-bit register as a whole word or as individual bytes:

```c
typedef union {
    uint32_t word;
    uint8_t  bytes[4];
    struct {
        uint16_t low;
        uint16_t high;
    } halves;
} Register32;

volatile Register32 *data_reg = (volatile Register32 *)0x40004004;

data_reg->word = 0xDEADBEEF;
uint8_t lsb = data_reg->bytes[0];     /* 0xEF on little-endian */
uint16_t low = data_reg->halves.low;  /* 0xBEEF on little-endian */
```

### Pattern 2: Communication Protocol Frames

Parse an incoming data packet without manual byte extraction:

```c
typedef union {
    uint8_t raw[8];
    struct {
        uint8_t  start_byte;
        uint8_t  command;
        uint16_t payload;
        uint32_t crc;
    } fields;
} PacketFrame;

void process_packet(const uint8_t *buffer)
{
    PacketFrame frame;
    memcpy(frame.raw, buffer, sizeof(frame));

    if (frame.fields.start_byte == 0xAA) {
        handle_command(frame.fields.command, frame.fields.payload);
    }
}
```

**Caution:** Unions used for type-punning are technically implementation-defined behavior in C (though allowed in C99/C11 as a common extension). Also be aware of endianness and padding.

## Bit-Fields

Bit-fields let you define struct members with specific bit widths:

```c
typedef struct {
    uint32_t mode   : 2;    /* Bits [1:0]  */
    uint32_t speed  : 2;    /* Bits [3:2]  */
    uint32_t pull   : 2;    /* Bits [5:4]  */
    uint32_t output : 1;    /* Bit  [6]    */
    uint32_t        : 25;   /* Remaining bits (unnamed padding) */
} GPIO_PinConfig;
```

### Pros of Bit-Fields

- **Readable** — gives names to individual bits
- **Self-documenting** — the width is explicit

### Cons of Bit-Fields (Why Many Embedded Developers Avoid Them)

1. **Non-portable** — the C standard does not specify bit ordering, padding, or alignment
2. **Compiler-dependent** — bit layout may differ between GCC, IAR, and Keil
3. **Cannot take the address** of a bit-field member
4. **Read-modify-write atomicity** — the compiler may generate non-atomic access for adjacent bit-fields in the same byte

### When Bit-Fields Are Safe to Use

- Internal data structures (not mapped to hardware registers)
- When the compiler and bit ordering are well-understood and fixed
- Protocol parsing where you control both ends

### When to Prefer Manual Bit Manipulation

- Hardware register access
- Cross-platform/cross-compiler code
- Any code requiring deterministic bit layout

## Struct Packing and Alignment

### Default Alignment

Compilers align struct members to their natural boundaries:

```c
struct Example {
    uint8_t  a;      /* 1 byte + 3 bytes padding */
    uint32_t b;      /* 4 bytes */
    uint8_t  c;      /* 1 byte + 3 bytes padding */
};
/* sizeof = 12 bytes (not 6!) */
```

### Packed Structs

Force the compiler to eliminate padding:

```c
struct __attribute__((packed)) PackedExample {
    uint8_t  a;      /* 1 byte, no padding */
    uint32_t b;      /* 4 bytes */
    uint8_t  c;      /* 1 byte */
};
/* sizeof = 6 bytes */
```

Use packed structs for:

- Communication protocol frames that must match a wire format
- File format headers
- Memory-constrained structures

**Warning:** Packed structs can cause **unaligned memory access** which may:
- Trigger a hard fault on Cortex-M0
- Reduce performance on Cortex-M3/M4/M7
- Produce incorrect results on some architectures

### Reordering Members to Minimize Padding

Instead of packing, reorder members by size (largest first):

```c
struct Optimized {
    uint32_t b;      /* 4 bytes */
    uint8_t  a;      /* 1 byte */
    uint8_t  c;      /* 1 byte + 2 bytes padding */
};
/* sizeof = 8 bytes — better than 12 without reordering */
```

## Practical Pattern: Configuration Structures

Use structs to pass peripheral configurations cleanly:

```c
typedef struct {
    uint32_t baudrate;
    uint8_t  word_length;  /* 8 or 9 */
    uint8_t  stop_bits;    /* 1 or 2 */
    uint8_t  parity;       /* 0=none, 1=even, 2=odd */
    uint8_t  flow_control; /* 0=none, 1=RTS/CTS */
} UART_Config;

void uart_init(USART_TypeDef *usart, const UART_Config *config)
{
    uint32_t brr = SystemCoreClock / config->baudrate;
    usart->BRR = brr;

    if (config->word_length == 9)
        usart->CR1 |= (1U << 12);

    if (config->stop_bits == 2)
        usart->CR2 |= (2U << 12);

    usart->CR1 |= (1U << 13);  /* Enable USART */
}

/* Usage */
UART_Config serial_config = {
    .baudrate     = 115200,
    .word_length  = 8,
    .stop_bits    = 1,
    .parity       = 0,
    .flow_control = 0
};
uart_init(USART1, &serial_config);
```

## Practical Pattern: Tagged Unions (Variant Types)

Represent data that can take different forms:

```c
typedef enum {
    SENSOR_TEMP,
    SENSOR_HUMIDITY,
    SENSOR_PRESSURE
} SensorType;

typedef struct {
    SensorType type;
    uint32_t   timestamp;
    union {
        float    temperature_c;
        float    humidity_pct;
        uint32_t pressure_pa;
    } data;
} SensorReading;

void log_reading(const SensorReading *r)
{
    switch (r->type) {
    case SENSOR_TEMP:
        log_temperature(r->data.temperature_c);
        break;
    case SENSOR_HUMIDITY:
        log_humidity(r->data.humidity_pct);
        break;
    case SENSOR_PRESSURE:
        log_pressure(r->data.pressure_pa);
        break;
    }
}
```

## Summary

- Structs model peripheral register layouts and configuration data.
- Unions provide multiple views of the same memory — useful for register access and protocol parsing.
- Bit-fields are readable but non-portable — prefer manual bit manipulation for hardware registers.
- Understand struct padding and alignment to avoid wasting RAM or causing hard faults.
- Use designated initializers (`.field = value`) for readable, maintainable configuration.

---

**Next:** [Chapter 6 — Preprocessor and Macros](06-preprocessor-and-macros.md)
