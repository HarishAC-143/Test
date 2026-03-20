/**
 * PROJECT: Serial Command-Line Interface
 *
 * A complete command-line parser for UART-based interaction.
 * Supports command registration, argument parsing, help system,
 * and history.
 *
 * Concepts demonstrated:
 *   - UART receive with ring buffer
 *   - Line editing (backspace)
 *   - Command dispatch table with function pointers
 *   - Argument tokenization and parsing
 *   - String-to-integer conversion
 *   - Extensible command architecture
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

/* ================================================================
 * Configuration
 * ================================================================ */
#define CMD_MAX_LENGTH    64
#define CMD_MAX_ARGS      8
#define CMD_MAX_COMMANDS  16
#define CMD_PROMPT        "> "
#define CMD_HISTORY_SIZE  4

/* ================================================================
 * Ring Buffer (for UART RX)
 * ================================================================ */
#define RX_BUF_SIZE 128

typedef struct {
    char     data[RX_BUF_SIZE];
    uint16_t head;
    uint16_t tail;
} RxBuffer;

static RxBuffer rx_buf = { .head = 0, .tail = 0 };

static void rx_put(char c) {
    uint16_t next = (rx_buf.head + 1) % RX_BUF_SIZE;
    if (next != rx_buf.tail) {
        rx_buf.data[rx_buf.head] = c;
        rx_buf.head = next;
    }
}

__attribute__((unused))
static bool rx_get(char *c) {
    if (rx_buf.head == rx_buf.tail) return false;
    *c = rx_buf.data[rx_buf.tail];
    rx_buf.tail = (rx_buf.tail + 1) % RX_BUF_SIZE;
    return true;
}

/* ================================================================
 * Simulated System State
 * ================================================================ */
static struct {
    bool     led_on;
    uint16_t adc_values[4];
    uint32_t uptime_sec;
    uint8_t  gpio_state;
} sys_state = {
    .led_on = false,
    .adc_values = { 1024, 2048, 3072, 4000 },
    .uptime_sec = 3661,
    .gpio_state = 0x00
};

/* ================================================================
 * Command Parser Engine
 * ================================================================ */
typedef int (*CmdHandler)(int argc, const char *argv[]);

typedef struct {
    const char  *name;
    const char  *help;
    const char  *usage;
    CmdHandler   handler;
} Command;

static Command cmd_table[CMD_MAX_COMMANDS];
static int cmd_count = 0;

static char history_buf[CMD_HISTORY_SIZE][CMD_MAX_LENGTH];
static int history_count = 0;

static void cmd_register(const char *name, const char *help,
                         const char *usage, CmdHandler handler) {
    if (cmd_count < CMD_MAX_COMMANDS) {
        cmd_table[cmd_count].name    = name;
        cmd_table[cmd_count].help    = help;
        cmd_table[cmd_count].usage   = usage;
        cmd_table[cmd_count].handler = handler;
        cmd_count++;
    }
}

static void history_add(const char *cmd) {
    if (history_count < CMD_HISTORY_SIZE) {
        snprintf(history_buf[history_count], CMD_MAX_LENGTH, "%s", cmd);
        history_count++;
    } else {
        for (int i = 0; i < CMD_HISTORY_SIZE - 1; i++) {
            memcpy(history_buf[i], history_buf[i + 1], CMD_MAX_LENGTH);
        }
        snprintf(history_buf[CMD_HISTORY_SIZE - 1], CMD_MAX_LENGTH, "%s", cmd);
    }
}

static int tokenize(char *line, const char *argv[], int max_args) {
    int argc = 0;
    char *p = line;

    while (*p && argc < max_args) {
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '\0') break;

        argv[argc++] = p;

        while (*p && *p != ' ' && *p != '\t') p++;
        if (*p) *p++ = '\0';
    }

    return argc;
}

static int cmd_execute(char *line) {
    const char *argv[CMD_MAX_ARGS];
    int argc = tokenize(line, argv, CMD_MAX_ARGS);

    if (argc == 0) return 0;

    for (int i = 0; i < cmd_count; i++) {
        if (strcmp(argv[0], cmd_table[i].name) == 0) {
            return cmd_table[i].handler(argc, argv);
        }
    }

    printf("  Unknown command: '%s'. Type 'help' for available commands.\n", argv[0]);
    return -1;
}

/* ================================================================
 * Command Handlers
 * ================================================================ */

static int cmd_help(int argc, const char *argv[]) {
    if (argc > 1) {
        for (int i = 0; i < cmd_count; i++) {
            if (strcmp(argv[1], cmd_table[i].name) == 0) {
                printf("  %s — %s\n", cmd_table[i].name, cmd_table[i].help);
                if (cmd_table[i].usage) {
                    printf("  Usage: %s\n", cmd_table[i].usage);
                }
                return 0;
            }
        }
        printf("  Unknown command: '%s'\n", argv[1]);
        return -1;
    }

    printf("  Available commands:\n");
    for (int i = 0; i < cmd_count; i++) {
        printf("    %-12s  %s\n", cmd_table[i].name, cmd_table[i].help);
    }
    printf("\n  Type 'help <command>' for detailed usage.\n");
    return 0;
}

static int cmd_led(int argc, const char *argv[]) {
    if (argc < 2) {
        printf("  LED is currently %s\n", sys_state.led_on ? "ON" : "OFF");
        return 0;
    }

    if (strcmp(argv[1], "on") == 0) {
        sys_state.led_on = true;
        printf("  LED turned ON\n");
    } else if (strcmp(argv[1], "off") == 0) {
        sys_state.led_on = false;
        printf("  LED turned OFF\n");
    } else if (strcmp(argv[1], "toggle") == 0) {
        sys_state.led_on = !sys_state.led_on;
        printf("  LED toggled to %s\n", sys_state.led_on ? "ON" : "OFF");
    } else {
        printf("  Invalid argument: '%s'. Use on/off/toggle.\n", argv[1]);
        return -1;
    }
    return 0;
}

static int cmd_adc(int argc, const char *argv[]) {
    if (argc < 3 || strcmp(argv[1], "read") != 0) {
        printf("  Usage: adc read <channel 0-3>\n");
        return -1;
    }

    int ch = atoi(argv[2]);
    if (ch < 0 || ch > 3) {
        printf("  Invalid channel: %d (must be 0-3)\n", ch);
        return -1;
    }

    uint16_t raw = sys_state.adc_values[ch];
    float voltage = (raw / 4095.0f) * 3.3f;
    printf("  ADC Channel %d: raw=%u (0x%03X), voltage=%.3f V\n",
           ch, raw, raw, voltage);
    return 0;
}

static int cmd_gpio(int argc, const char *argv[]) {
    if (argc < 3) {
        printf("  Current GPIO state: 0x%02X\n", sys_state.gpio_state);
        printf("  Usage: gpio set/clear/toggle <pin 0-7>\n");
        return 0;
    }

    int pin = atoi(argv[2]);
    if (pin < 0 || pin > 7) {
        printf("  Invalid pin: %d (must be 0-7)\n", pin);
        return -1;
    }

    if (strcmp(argv[1], "set") == 0) {
        sys_state.gpio_state |= (1 << pin);
        printf("  GPIO pin %d set HIGH\n", pin);
    } else if (strcmp(argv[1], "clear") == 0) {
        sys_state.gpio_state &= ~(1 << pin);
        printf("  GPIO pin %d set LOW\n", pin);
    } else if (strcmp(argv[1], "toggle") == 0) {
        sys_state.gpio_state ^= (1 << pin);
        printf("  GPIO pin %d toggled\n", pin);
    } else {
        printf("  Unknown action: '%s'\n", argv[1]);
        return -1;
    }

    printf("  GPIO state: 0x%02X [", sys_state.gpio_state);
    for (int i = 7; i >= 0; i--) {
        printf("%c", (sys_state.gpio_state & (1 << i)) ? '1' : '0');
    }
    printf("]\n");
    return 0;
}

static int cmd_status(int argc, const char *argv[]) {
    (void)argc; (void)argv;

    printf("  ╔═══════════════════════════════════╗\n");
    printf("  ║        System Status              ║\n");
    printf("  ╠═══════════════════════════════════╣\n");
    printf("  ║  Uptime:  %02u:%02u:%02u               ║\n",
           sys_state.uptime_sec / 3600,
           (sys_state.uptime_sec % 3600) / 60,
           sys_state.uptime_sec % 60);
    printf("  ║  LED:     %-3s                     ║\n",
           sys_state.led_on ? "ON" : "OFF");
    printf("  ║  GPIO:    0x%02X                    ║\n", sys_state.gpio_state);
    printf("  ║  ADC:     %4u %4u %4u %4u      ║\n",
           sys_state.adc_values[0], sys_state.adc_values[1],
           sys_state.adc_values[2], sys_state.adc_values[3]);
    printf("  ╚═══════════════════════════════════╝\n");
    return 0;
}

static int cmd_show_history(int argc, const char *argv[]) {
    (void)argc; (void)argv;

    printf("  Command history:\n");
    for (int i = 0; i < history_count; i++) {
        printf("    %d: %s\n", i + 1, history_buf[i]);
    }
    if (history_count == 0) {
        printf("    (empty)\n");
    }
    return 0;
}

static int cmd_echo(int argc, const char *argv[]) {
    for (int i = 1; i < argc; i++) {
        printf("%s%s", argv[i], (i < argc - 1) ? " " : "");
    }
    printf("\n");
    return 0;
}

static int cmd_mem(int argc, const char *argv[]) {
    (void)argc; (void)argv;

    printf("  Memory Layout (simulated):\n");
    printf("    Flash (ROM):    256 KB  [████████████████████] 100%%\n");
    printf("    Code (.text):    48 KB  [████                ]  19%%\n");
    printf("    Const (.rodata):  8 KB  [██                  ]   3%%\n");
    printf("    RAM (SRAM):      64 KB  [████████████████████] 100%%\n");
    printf("    Data (.data):     2 KB  [█                   ]   3%%\n");
    printf("    BSS (.bss):       4 KB  [██                  ]   6%%\n");
    printf("    Stack:            2 KB  [█                   ]   3%%\n");
    printf("    Heap:             0 KB  [                    ]   0%%\n");
    printf("    Free:            56 KB  [██████████████████  ]  88%%\n");
    return 0;
}

static int cmd_reset(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    printf("  Performing software reset...\n");
    printf("  (In real firmware: NVIC_SystemReset())\n");
    return 0;
}

/* ================================================================
 * Main Application
 * ================================================================ */
int main(void) {
    printf("╔══════════════════════════════════════════════╗\n");
    printf("║  Serial Command-Line Interface               ║\n");
    printf("╚══════════════════════════════════════════════╝\n\n");

    /* Register commands */
    cmd_register("help",    "Show available commands",    "help [command]", cmd_help);
    cmd_register("led",     "Control LED",                "led on|off|toggle", cmd_led);
    cmd_register("adc",     "Read ADC channel",           "adc read <0-3>", cmd_adc);
    cmd_register("gpio",    "Control GPIO pins",          "gpio set|clear|toggle <0-7>", cmd_gpio);
    cmd_register("status",  "Show system status",         "status", cmd_status);
    cmd_register("history", "Show command history",       "history", cmd_show_history);
    cmd_register("echo",    "Echo arguments",             "echo <text...>", cmd_echo);
    cmd_register("mem",     "Show memory usage",          "mem", cmd_mem);
    cmd_register("reset",   "Software reset",             "reset", cmd_reset);

    /* Simulate a sequence of commands (as if typed by a user) */
    const char *commands[] = {
        "help",
        "status",
        "led on",
        "adc read 0",
        "adc read 2",
        "gpio set 3",
        "gpio set 5",
        "gpio toggle 3",
        "status",
        "mem",
        "echo Hello from the embedded CLI!",
        "invalid_cmd test",
        "help adc",
        "history",
    };
    int num_commands = sizeof(commands) / sizeof(commands[0]);

    for (int i = 0; i < num_commands; i++) {
        printf("%s%s\n", CMD_PROMPT, commands[i]);

        /* Feed into RX buffer (simulates UART receive) */
        for (const char *p = commands[i]; *p; p++) {
            rx_put(*p);
        }

        /* Process the command */
        char line[CMD_MAX_LENGTH];
        strncpy(line, commands[i], CMD_MAX_LENGTH - 1);
        line[CMD_MAX_LENGTH - 1] = '\0';

        history_add(line);
        cmd_execute(line);
        printf("\n");
    }

    return 0;
}
