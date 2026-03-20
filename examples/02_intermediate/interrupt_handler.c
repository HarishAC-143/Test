/**
 * Interrupt Handler Patterns
 *
 * Demonstrates interrupt-driven programming concepts using simulation.
 * Covers ISR design, flag-based communication, critical sections,
 * and priority handling.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ----------------------------------------------------------------
 * Simulated NVIC and interrupt infrastructure
 * ---------------------------------------------------------------- */

#define MAX_IRQ 16

typedef void (*isr_fn)(void);

static struct {
    isr_fn   handlers[MAX_IRQ];
    uint8_t  priority[MAX_IRQ];
    uint8_t  enabled[MAX_IRQ];
    uint8_t  pending[MAX_IRQ];
    uint8_t  active;
    uint8_t  global_enable;
} sim_nvic;

static void nvic_init(void) {
    memset(&sim_nvic, 0, sizeof(sim_nvic));
    sim_nvic.global_enable = 1;
}

static void nvic_register_handler(uint8_t irq, isr_fn handler, uint8_t priority) {
    if (irq < MAX_IRQ) {
        sim_nvic.handlers[irq] = handler;
        sim_nvic.priority[irq] = priority;
        sim_nvic.enabled[irq] = 1;
    }
}

static void nvic_trigger_irq(uint8_t irq) {
    if (irq < MAX_IRQ) {
        sim_nvic.pending[irq] = 1;
    }
}

static void nvic_process_pending(void) {
    if (!sim_nvic.global_enable) return;

    for (int pri = 0; pri < 16; pri++) {
        for (int irq = 0; irq < MAX_IRQ; irq++) {
            if (sim_nvic.pending[irq] &&
                sim_nvic.enabled[irq] &&
                sim_nvic.priority[irq] == pri &&
                sim_nvic.handlers[irq]) {
                sim_nvic.pending[irq] = 0;
                sim_nvic.active = (uint8_t)irq;
                printf("  [NVIC] Entering IRQ %d (priority %d)\n", irq, pri);
                sim_nvic.handlers[irq]();
                printf("  [NVIC] Exiting IRQ %d\n", irq);
            }
        }
    }
}

static void disable_irq(void) { sim_nvic.global_enable = 0; }
static void enable_irq(void)  { sim_nvic.global_enable = 1; }

/* ----------------------------------------------------------------
 * Pattern 1: Simple flag-based ISR
 * ---------------------------------------------------------------- */

#define IRQ_BUTTON  0
#define IRQ_TIMER   1
#define IRQ_UART_RX 2

static volatile uint8_t  button_flag = 0;
static volatile uint32_t button_count = 0;

static void button_isr(void) {
    button_flag = 1;
    button_count++;
}

static void demo_flag_based_isr(void) {
    printf("=== Pattern 1: Flag-Based ISR ===\n\n");

    nvic_init();
    button_flag = 0;
    button_count = 0;

    nvic_register_handler(IRQ_BUTTON, button_isr, 2);

    printf("  Main loop running...\n");

    /* Simulate 3 button presses */
    for (int press = 0; press < 3; press++) {
        /* Simulate: hardware detects button press */
        nvic_trigger_irq(IRQ_BUTTON);
        nvic_process_pending();

        /* Main loop checks the flag */
        if (button_flag) {
            button_flag = 0;
            printf("  Main: Button press #%u detected! Processing...\n",
                   button_count);
        }
    }

    printf("\n  KEY INSIGHT: ISR sets a flag and returns immediately.\n");
    printf("  Main loop does the heavy processing.\n\n");
}

/* ----------------------------------------------------------------
 * Pattern 2: Timer tick with multiple subscribers
 * ---------------------------------------------------------------- */

static volatile uint32_t system_ticks = 0;

typedef struct {
    const char *name;
    uint32_t    period;
    uint32_t    last_tick;
    void       (*callback)(void);
} TimerSubscriber;

#define MAX_SUBSCRIBERS 4
static TimerSubscriber subscribers[MAX_SUBSCRIBERS];
static int num_subscribers = 0;

static void timer_subscribe(const char *name, uint32_t period, void (*cb)(void)) {
    if (num_subscribers < MAX_SUBSCRIBERS) {
        subscribers[num_subscribers].name      = name;
        subscribers[num_subscribers].period    = period;
        subscribers[num_subscribers].last_tick = 0;
        subscribers[num_subscribers].callback  = cb;
        num_subscribers++;
    }
}

static void timer_isr(void) {
    system_ticks++;
}

static void task_led_blink(void)   { printf("    [LED] Toggle\n"); }
static void task_sensor_read(void) { printf("    [SENSOR] Read ADC\n"); }
static void task_heartbeat(void)   { printf("    [HEARTBEAT] Alive\n"); }

static void demo_timer_subscribers(void) {
    printf("=== Pattern 2: Timer Tick with Subscribers ===\n\n");

    nvic_init();
    system_ticks = 0;
    num_subscribers = 0;

    nvic_register_handler(IRQ_TIMER, timer_isr, 0);

    timer_subscribe("LED Blink",   5, task_led_blink);
    timer_subscribe("Sensor Read", 10, task_sensor_read);
    timer_subscribe("Heartbeat",   20, task_heartbeat);

    printf("  Simulating 25 timer ticks:\n\n");

    for (int tick = 0; tick < 25; tick++) {
        nvic_trigger_irq(IRQ_TIMER);
        nvic_process_pending();

        /* Main loop: check each subscriber */
        for (int i = 0; i < num_subscribers; i++) {
            if (system_ticks - subscribers[i].last_tick >= subscribers[i].period) {
                subscribers[i].last_tick = system_ticks;
                printf("  Tick %2u: %s fires\n", system_ticks, subscribers[i].name);
                subscribers[i].callback();
            }
        }
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Pattern 3: Critical section for shared data
 * ---------------------------------------------------------------- */

static volatile uint64_t shared_timestamp = 0;

static void timestamp_isr(void) {
    shared_timestamp = 0x123456789ABCULL;
}

static void demo_critical_section(void) {
    printf("=== Pattern 3: Critical Sections ===\n\n");

    nvic_init();
    shared_timestamp = 0;

    nvic_register_handler(IRQ_TIMER, timestamp_isr, 0);

    printf("  Problem: Reading a 64-bit value on a 32-bit CPU is NOT atomic.\n");
    printf("  The ISR can fire between reading the upper and lower halves.\n\n");

    /* Safe read using critical section */
    uint64_t safe_copy;

    /* Simulate: ISR updates the timestamp */
    nvic_trigger_irq(IRQ_TIMER);
    nvic_process_pending();

    /* Enter critical section */
    disable_irq();
    safe_copy = shared_timestamp;
    enable_irq();

    printf("  Safe read (with critical section): 0x%012llX\n",
           (unsigned long long)safe_copy);

    printf("\n  Rule: Protect any shared data wider than the CPU word size.\n");
    printf("  On 32-bit ARM: 8-bit, 16-bit, 32-bit reads ARE atomic.\n");
    printf("  64-bit reads, structs, and multi-step operations are NOT.\n\n");
}

/* ----------------------------------------------------------------
 * Pattern 4: ISR-to-main ring buffer communication
 * ---------------------------------------------------------------- */

#define RX_BUF_SIZE 16

static volatile uint8_t  rx_buffer[RX_BUF_SIZE];
static volatile uint16_t rx_head = 0;
static volatile uint16_t rx_tail = 0;

static void uart_rx_isr(void) {
    static uint8_t fake_data = 'A';
    uint16_t next = (rx_head + 1) % RX_BUF_SIZE;
    if (next != rx_tail) {
        rx_buffer[rx_head] = fake_data++;
        rx_head = next;
    }
}

static bool rx_available(void) {
    return rx_head != rx_tail;
}

static uint8_t rx_read(void) {
    uint8_t data = rx_buffer[rx_tail];
    rx_tail = (rx_tail + 1) % RX_BUF_SIZE;
    return data;
}

static void demo_isr_ring_buffer(void) {
    printf("=== Pattern 4: ISR Ring Buffer ===\n\n");

    nvic_init();
    rx_head = 0;
    rx_tail = 0;

    nvic_register_handler(IRQ_UART_RX, uart_rx_isr, 1);

    printf("  Simulating 8 UART byte receptions:\n  ");

    for (int i = 0; i < 8; i++) {
        nvic_trigger_irq(IRQ_UART_RX);
        nvic_process_pending();
    }

    printf("\n  Main loop reads from ring buffer: ");
    while (rx_available()) {
        printf("%c ", rx_read());
    }
    printf("\n");

    printf("\n  The ring buffer decouples the ISR (producer) from the\n");
    printf("  main loop (consumer) without needing locks.\n\n");
}

/* ----------------------------------------------------------------
 * Pattern 5: Nested interrupt priority demo
 * ---------------------------------------------------------------- */

static void high_priority_isr(void) {
    printf("    [HIGH PRI] Critical task executing\n");
}

static void low_priority_isr(void) {
    printf("    [LOW PRI] Start\n");
    /* On real HW, a higher-priority IRQ could preempt here */
    printf("    [LOW PRI] End\n");
}

static void demo_priority(void) {
    printf("=== Pattern 5: Interrupt Priority ===\n\n");

    nvic_init();

    /* Priority 0 = highest, 15 = lowest */
    nvic_register_handler(3, high_priority_isr, 0);
    nvic_register_handler(4, low_priority_isr, 3);

    printf("  Triggering both IRQs simultaneously:\n");
    nvic_trigger_irq(3);
    nvic_trigger_irq(4);
    nvic_process_pending();

    printf("\n  Higher priority (0) executes first.\n");
    printf("  On real hardware, a high-priority IRQ can preempt\n");
    printf("  a lower-priority one mid-execution (nested interrupts).\n\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Interrupt Handler Patterns              ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_flag_based_isr();
    demo_timer_subscribers();
    demo_critical_section();
    demo_isr_ring_buffer();
    demo_priority();

    printf("═══ End of Interrupt Handler Demo ═══\n");
    return 0;
}
