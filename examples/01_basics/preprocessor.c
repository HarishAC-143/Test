/**
 * @file    preprocessor.c
 * @brief   Preprocessor techniques commonly used in embedded C projects.
 *
 * Covers conditional compilation, feature flags, debug macros, compile-time
 * assertions, and X-macros for maintaining parallel data structures.
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Platform Selection                                                         */
/* ========================================================================== */

/* Typically defined via compiler flag: -DPLATFORM_STM32F4 */
#if defined(PLATFORM_STM32F4)
    #define CPU_FREQ_HZ     168000000U
    #define FLASH_SIZE_KB   1024
    #define SRAM_SIZE_KB    192
    #define HAS_FPU         1
#elif defined(PLATFORM_STM32L0)
    #define CPU_FREQ_HZ     32000000U
    #define FLASH_SIZE_KB   64
    #define SRAM_SIZE_KB    8
    #define HAS_FPU         0
#elif defined(PLATFORM_ATMEGA328)
    #define CPU_FREQ_HZ     16000000U
    #define FLASH_SIZE_KB   32
    #define SRAM_SIZE_KB    2
    #define HAS_FPU         0
#else
    /* Default for demonstration/simulation */
    #define CPU_FREQ_HZ     16000000U
    #define FLASH_SIZE_KB   256
    #define SRAM_SIZE_KB    64
    #define HAS_FPU         0
#endif

/* ========================================================================== */
/*  Feature Flags                                                              */
/* ========================================================================== */

#define FEATURE_ENABLE_UART         1
#define FEATURE_ENABLE_SPI          1
#define FEATURE_ENABLE_I2C          0   /* Disabled for this build */
#define FEATURE_ENABLE_USB          0
#define FEATURE_ENABLE_WATCHDOG     1

#define UART_BAUD_RATE              115200
#define SPI_MAX_FREQ_HZ             10000000

/* Validate configuration */
#if FEATURE_ENABLE_UART && (UART_BAUD_RATE < 1200 || UART_BAUD_RATE > 4500000)
    #error "UART_BAUD_RATE is out of valid range (1200 - 4500000)"
#endif

#if FEATURE_ENABLE_SPI && (SPI_MAX_FREQ_HZ > CPU_FREQ_HZ / 2)
    #error "SPI_MAX_FREQ_HZ cannot exceed CPU_FREQ / 2"
#endif

/* ========================================================================== */
/*  Debug and Logging Macros                                                   */
/* ========================================================================== */

/* Define DEBUG_LEVEL via compiler flag: -DDEBUG_LEVEL=3 */
#ifndef DEBUG_LEVEL
    #define DEBUG_LEVEL 2  /* Default: warnings and errors */
#endif

/*
 * Level 0: No output
 * Level 1: Errors only
 * Level 2: Errors + warnings
 * Level 3: Errors + warnings + info
 * Level 4: All of above + verbose debug
 */

/* Stub for uart_printf — would be a real function in production */
extern int uart_printf(const char *fmt, ...);

#if DEBUG_LEVEL >= 1
    #define LOG_ERROR(fmt, ...) \
        uart_printf("[ERR  %s:%d] " fmt "\r\n", __FILE__, __LINE__, ##__VA_ARGS__)
#else
    #define LOG_ERROR(fmt, ...) ((void)0)
#endif

#if DEBUG_LEVEL >= 2
    #define LOG_WARN(fmt, ...) \
        uart_printf("[WARN %s:%d] " fmt "\r\n", __FILE__, __LINE__, ##__VA_ARGS__)
#else
    #define LOG_WARN(fmt, ...) ((void)0)
#endif

#if DEBUG_LEVEL >= 3
    #define LOG_INFO(fmt, ...) \
        uart_printf("[INFO] " fmt "\r\n", ##__VA_ARGS__)
#else
    #define LOG_INFO(fmt, ...) ((void)0)
#endif

#if DEBUG_LEVEL >= 4
    #define LOG_DEBUG(fmt, ...) \
        uart_printf("[DBG  %s:%d %s()] " fmt "\r\n", \
                    __FILE__, __LINE__, __func__, ##__VA_ARGS__)
#else
    #define LOG_DEBUG(fmt, ...) ((void)0)
#endif

/* ========================================================================== */
/*  Compile-Time Assertions                                                    */
/* ========================================================================== */

_Static_assert(CPU_FREQ_HZ >= 1000000, "CPU frequency must be at least 1 MHz");
_Static_assert(SRAM_SIZE_KB >= 2, "Need at least 2 KB SRAM");

/* Verify struct packing matches hardware register layout */
typedef struct {
    uint32_t CR1;
    uint32_t CR2;
    uint32_t SR;
    uint32_t DR;
} periph_regs_t;

_Static_assert(sizeof(periph_regs_t) == 16, "Register struct must be 16 bytes");

/* ========================================================================== */
/*  Useful Utility Macros                                                      */
/* ========================================================================== */

#define ARRAY_SIZE(arr)         (sizeof(arr) / sizeof((arr)[0]))
#define UNUSED(x)               ((void)(x))

#define MIN(a, b)               (((a) < (b)) ? (a) : (b))
#define MAX(a, b)               (((a) > (b)) ? (a) : (b))
#define CLAMP(x, lo, hi)        (MIN(MAX((x), (lo)), (hi)))

#define ALIGN_UP(x, align)      (((x) + ((align) - 1)) & ~((align) - 1))
#define ALIGN_DOWN(x, align)    ((x) & ~((align) - 1))

#define STRINGIFY(x)            #x
#define EXPAND_AND_STRINGIFY(x) STRINGIFY(x)

#define CONCAT(a, b)            a ## b
#define EXPAND_AND_CONCAT(a, b) CONCAT(a, b)

/* Compile-time "message" — useful for development reminders */
#define COMPILE_MESSAGE(msg) \
    _Pragma(EXPAND_AND_STRINGIFY(message(msg)))

/* ========================================================================== */
/*  X-Macro Pattern                                                            */
/* ========================================================================== */

/*
 * X-macros maintain parallel data structures (enum, strings, init functions)
 * from a single source of truth, preventing them from getting out of sync.
 */

#define ERROR_LIST(X)                               \
    X(ERR_NONE,          "No error")                \
    X(ERR_TIMEOUT,       "Operation timed out")     \
    X(ERR_OVERFLOW,      "Buffer overflow")         \
    X(ERR_UNDERFLOW,     "Buffer underflow")        \
    X(ERR_INVALID_PARAM, "Invalid parameter")       \
    X(ERR_HARDWARE,      "Hardware failure")        \
    X(ERR_COMM,          "Communication error")

/* Generate the enum */
typedef enum {
    #define X_ENUM(id, str) id,
    ERROR_LIST(X_ENUM)
    #undef X_ENUM
    ERR_COUNT
} error_code_t;

/* Generate string lookup table */
static const char *error_strings[] = {
    #define X_STRING(id, str) str,
    ERROR_LIST(X_STRING)
    #undef X_STRING
};

const char *error_to_string(error_code_t code)
{
    if (code < ERR_COUNT) {
        return error_strings[code];
    }
    return "Unknown error";
}

/* ========================================================================== */
/*  Macro for Register Access with Timeout                                     */
/* ========================================================================== */

/**
 * Wait for a register bit to be set, with timeout.
 * Returns true if the bit was set within the timeout period.
 */
#define WAIT_FOR_BIT_SET(reg, bit, timeout_cycles, result)  \
    do {                                                     \
        uint32_t _timeout = (timeout_cycles);                \
        (result) = false;                                    \
        while (_timeout--) {                                 \
            if ((reg) & (1U << (bit))) {                     \
                (result) = true;                             \
                break;                                       \
            }                                                \
        }                                                    \
    } while (0)

/* ========================================================================== */
/*  Conditional Feature Compilation                                            */
/* ========================================================================== */

void system_init(void)
{
    LOG_INFO("System init: %s, CPU @ %lu Hz",
             EXPAND_AND_STRINGIFY(PLATFORM), (unsigned long)CPU_FREQ_HZ);

    #if FEATURE_ENABLE_UART
        LOG_INFO("Initializing UART at %d baud", UART_BAUD_RATE);
        /* uart_init(UART_BAUD_RATE); */
    #endif

    #if FEATURE_ENABLE_SPI
        LOG_INFO("Initializing SPI");
        /* spi_init(); */
    #endif

    #if FEATURE_ENABLE_I2C
        LOG_INFO("Initializing I2C");
        /* i2c_init(); */
    #endif

    #if FEATURE_ENABLE_WATCHDOG
        LOG_INFO("Initializing Watchdog");
        /* watchdog_init(1000); */
    #endif

    #if HAS_FPU
        LOG_INFO("FPU enabled");
        /* enable_fpu(); */
    #endif
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    system_init();

    /* X-macro usage example */
    error_code_t err = ERR_TIMEOUT;
    LOG_ERROR("System error: %s (code %d)", error_to_string(err), err);

    /* Utility macro examples */
    uint32_t data[] = {10, 20, 30, 40, 50};
    uint32_t count = ARRAY_SIZE(data);

    int16_t value = 500;
    int16_t clamped = CLAMP(value, 0, 255);

    uint32_t aligned = ALIGN_UP(0x1003, 4);  /* 0x1004 */

    UNUSED(count);
    UNUSED(clamped);
    UNUSED(aligned);

    while (1) {
        /* Main loop */
    }
}
