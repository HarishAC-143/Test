# Chapter 3: Advanced Embedded C

## 3.1 DMA (Direct Memory Access)

DMA allows peripherals to transfer data to/from memory without CPU intervention. The CPU sets up the transfer and then continues executing other code while the DMA controller handles the data movement in the background.

### Why DMA Matters

```
Without DMA (CPU-driven):              With DMA:
┌──────┐   byte   ┌──────┐            ┌──────┐         ┌──────┐
│ UART ├──────────►│ CPU  │            │ UART ├────┐    │ CPU  │
└──────┘   by     └──┬───┘            └──────┘    │    └──────┘
           byte      │                        ┌───▼───┐ (free to
                     ▼                        │  DMA  │  do other
                  ┌──────┐                    │Engine │  work)
                  │Memory│                    └───┬───┘
                  └──────┘                        │
                                              ┌───▼───┐
                                              │Memory │
                                              └───────┘
```

### DMA Configuration

```c
typedef struct {
    volatile uint32_t CR;     // Control register
    volatile uint32_t NDTR;   // Number of data to transfer
    volatile uint32_t PAR;    // Peripheral address
    volatile uint32_t M0AR;   // Memory 0 address
    volatile uint32_t M1AR;   // Memory 1 address (double buffer)
    volatile uint32_t FCR;    // FIFO control
} DMA_Stream_TypeDef;

void dma_uart_rx_init(uint8_t *buffer, uint16_t length) {
    // Enable DMA1 clock
    RCC->AHB1ENR |= (1 << 21);

    DMA_Stream_TypeDef *stream = DMA1_Stream5;  // USART2_RX

    stream->CR = 0;                       // Disable stream first
    while (stream->CR & (1 << 0));        // Wait until disabled

    stream->PAR  = (uint32_t)&USART2->DR; // Source: UART data register
    stream->M0AR = (uint32_t)buffer;      // Destination: memory buffer
    stream->NDTR = length;                // Number of bytes

    stream->CR = (4 << 25)               // Channel 4 (USART2_RX)
               | (0 << 6)               // Peripheral-to-memory
               | (1 << 10)              // Memory increment
               | (0 << 9)               // Peripheral address fixed
               | (1 << 8)               // Circular mode
               | (1 << 4);              // Transfer complete interrupt

    stream->CR |= (1 << 0);              // Enable stream
    USART2->CR3 |= (1 << 6);            // DMAR: enable UART DMA receive
}
```

### Double Buffering

Double buffering lets the DMA fill one buffer while the CPU processes the other:

```c
uint8_t buffer_a[256];
uint8_t buffer_b[256];
volatile uint8_t active_buffer = 0;

void dma_double_buffer_init(void) {
    DMA_Stream_TypeDef *stream = DMA1_Stream5;

    stream->M0AR = (uint32_t)buffer_a;
    stream->M1AR = (uint32_t)buffer_b;
    stream->CR |= (1 << 18);  // Enable double buffer mode

    stream->CR |= (1 << 0);   // Start
}

void DMA1_Stream5_IRQHandler(void) {
    if (DMA1->HISR & (1 << 11)) {
        DMA1->HIFCR |= (1 << 11);  // Clear transfer complete flag

        if (DMA1_Stream5->CR & (1 << 19)) {
            // DMA is now writing to buffer_b → process buffer_a
            process_data(buffer_a, 256);
        } else {
            // DMA is now writing to buffer_a → process buffer_b
            process_data(buffer_b, 256);
        }
    }
}
```

## 3.2 RTOS Fundamentals

A Real-Time Operating System manages multiple tasks, giving the illusion of parallel execution on a single-core processor.

### Task States

```
                    ┌─────────┐
         create     │         │
        ────────►   │  Ready  │ ◄────────────────┐
                    │         │                   │
                    └────┬────┘                   │
                         │                        │
                    scheduler                  event/
                    picks task                 timeout
                         │                        │
                    ┌────▼────┐             ┌─────┴─────┐
                    │         │   wait()    │           │
                    │ Running ├────────────►│  Blocked  │
                    │         │             │ (Waiting) │
                    └────┬────┘             └───────────┘
                         │
                    preempted /
                    yield
                         │
                    ┌────▼────┐
                    │  Ready  │
                    └─────────┘
```

### A Minimal Cooperative Scheduler

```c
#include <stdint.h>

#define MAX_TASKS 8

typedef void (*task_fn)(void);

typedef struct {
    task_fn function;
    uint32_t period_ms;
    uint32_t last_run;
    uint8_t  enabled;
} Task;

static Task task_list[MAX_TASKS];
static uint8_t task_count = 0;

void scheduler_add_task(task_fn fn, uint32_t period_ms) {
    if (task_count < MAX_TASKS) {
        task_list[task_count].function  = fn;
        task_list[task_count].period_ms = period_ms;
        task_list[task_count].last_run  = 0;
        task_list[task_count].enabled   = 1;
        task_count++;
    }
}

void scheduler_run(void) {
    while (1) {
        uint32_t now = get_tick_ms();
        for (uint8_t i = 0; i < task_count; i++) {
            if (task_list[i].enabled &&
                (now - task_list[i].last_run >= task_list[i].period_ms)) {
                task_list[i].last_run = now;
                task_list[i].function();
            }
        }
    }
}

// Usage
void task_read_sensor(void)  { /* read ADC every 100 ms */ }
void task_update_display(void) { /* refresh display every 250 ms */ }
void task_check_buttons(void) { /* scan buttons every 50 ms */ }

int main(void) {
    system_init();
    scheduler_add_task(task_read_sensor,    100);
    scheduler_add_task(task_update_display,  250);
    scheduler_add_task(task_check_buttons,   50);
    scheduler_run();
}
```

### Preemptive Context Switching (Conceptual)

A preemptive RTOS saves and restores each task's CPU state (registers, stack pointer) when switching:

```c
typedef struct {
    uint32_t *stack_pointer;
    uint32_t  stack[256];
    uint8_t   priority;
    uint8_t   state;        // READY, RUNNING, BLOCKED
} TCB;                      // Task Control Block

// ARM Cortex-M context switch via PendSV exception
void PendSV_Handler(void) {
    // 1. Save current task's context
    //    - Push R4–R11 onto current task's stack
    //    - Save the updated stack pointer to current TCB
    //
    // 2. Select next task (highest priority ready task)
    //
    // 3. Restore next task's context
    //    - Load stack pointer from next TCB
    //    - Pop R4–R11 from new task's stack
    //    - Return from exception (hardware restores R0–R3, LR, PC, xPSR)
}
```

## 3.3 Finite State Machines

State machines are the standard pattern for managing complex behavior in embedded systems — from protocol parsers to motor controllers.

### Table-Driven State Machine

```c
typedef enum {
    STATE_IDLE,
    STATE_HEATING,
    STATE_TARGET_REACHED,
    STATE_COOLING,
    STATE_ERROR,
    NUM_STATES
} State;

typedef enum {
    EVENT_START,
    EVENT_TEMP_LOW,
    EVENT_TEMP_OK,
    EVENT_TEMP_HIGH,
    EVENT_STOP,
    EVENT_FAULT,
    NUM_EVENTS
} Event;

typedef struct {
    State   next_state;
    void    (*action)(void);
} Transition;

// Action functions
void action_start_heater(void)  { /* turn on heater element */ }
void action_stop_heater(void)   { /* turn off heater element */ }
void action_start_fan(void)     { /* turn on cooling fan */ }
void action_stop_fan(void)      { /* turn off fan */ }
void action_signal_error(void)  { /* activate alarm, log error */ }
void action_none(void)          { /* no operation */ }

// State transition table [current_state][event]
const Transition state_table[NUM_STATES][NUM_EVENTS] = {
    // STATE_IDLE
    [STATE_IDLE] = {
        [EVENT_START]     = { STATE_HEATING,        action_start_heater },
        [EVENT_TEMP_LOW]  = { STATE_IDLE,           action_none },
        [EVENT_TEMP_OK]   = { STATE_IDLE,           action_none },
        [EVENT_TEMP_HIGH] = { STATE_IDLE,           action_none },
        [EVENT_STOP]      = { STATE_IDLE,           action_none },
        [EVENT_FAULT]     = { STATE_ERROR,          action_signal_error },
    },
    // STATE_HEATING
    [STATE_HEATING] = {
        [EVENT_START]     = { STATE_HEATING,        action_none },
        [EVENT_TEMP_LOW]  = { STATE_HEATING,        action_none },
        [EVENT_TEMP_OK]   = { STATE_TARGET_REACHED, action_stop_heater },
        [EVENT_TEMP_HIGH] = { STATE_COOLING,        action_start_fan },
        [EVENT_STOP]      = { STATE_IDLE,           action_stop_heater },
        [EVENT_FAULT]     = { STATE_ERROR,          action_signal_error },
    },
    // ... fill remaining states similarly
};

State current_state = STATE_IDLE;

void fsm_handle_event(Event event) {
    const Transition *t = &state_table[current_state][event];
    if (t->action) {
        t->action();
    }
    current_state = t->next_state;
}
```

### Hierarchical State Machines

For complex systems, states can contain sub-states:

```c
typedef enum { MOTOR_OFF, MOTOR_RUNNING, MOTOR_FAULT } MotorState;
typedef enum { RUN_ACCEL, RUN_CONSTANT, RUN_DECEL } RunSubState;

typedef struct {
    MotorState  top_state;
    RunSubState sub_state;     // Valid only when top_state == MOTOR_RUNNING
    uint16_t    target_rpm;
    uint16_t    current_rpm;
} MotorFSM;

void motor_fsm_update(MotorFSM *fsm) {
    switch (fsm->top_state) {
    case MOTOR_OFF:
        // Handle off-state events
        break;

    case MOTOR_RUNNING:
        switch (fsm->sub_state) {
        case RUN_ACCEL:
            fsm->current_rpm += 10;
            if (fsm->current_rpm >= fsm->target_rpm) {
                fsm->sub_state = RUN_CONSTANT;
            }
            break;
        case RUN_CONSTANT:
            // Maintain speed, check for decel command
            break;
        case RUN_DECEL:
            fsm->current_rpm -= 10;
            if (fsm->current_rpm == 0) {
                fsm->top_state = MOTOR_OFF;
            }
            break;
        }
        break;

    case MOTOR_FAULT:
        // Safe shutdown, wait for reset
        break;
    }
}
```

## 3.4 Low-Power Modes

Battery-powered devices must minimize energy consumption. Modern MCUs offer multiple sleep modes with different trade-offs between power savings and wake-up time.

### Power Mode Spectrum

```
Mode          │ CPU │ Peripherals │ RAM │ Wake-up Time │ Power
──────────────┼─────┼─────────────┼─────┼──────────────┼──────
Run           │ ON  │    ON       │ ON  │     N/A      │ High
Sleep         │ OFF │    ON       │ ON  │   ~1 µs      │ Medium
Stop          │ OFF │   Most OFF  │ ON  │  ~5 µs       │ Low
Standby       │ OFF │    OFF      │ OFF │  ~50 µs      │ Very Low
Shutdown      │ OFF │    OFF      │ OFF │  Full reset   │ Minimal
```

### Implementing Sleep Mode

```c
void enter_sleep_mode(void) {
    // Disable unused peripherals to reduce current
    RCC->AHB1ENR &= ~((1 << 1) | (1 << 2) | (1 << 3)); // Disable GPIO B,C,D

    // Configure wake-up source (e.g., EXTI on button press)
    configure_wakeup_interrupt();

    // Clear the SLEEPDEEP bit for normal sleep
    SCB->SCR &= ~(1 << 2);

    // Wait for interrupt — CPU halts, wakes on any enabled interrupt
    __WFI();

    // Execution resumes here after wake-up
    restore_peripherals();
}

void enter_stop_mode(void) {
    // Set SLEEPDEEP bit
    SCB->SCR |= (1 << 2);

    // Select Stop mode in PWR register
    PWR->CR &= ~(3 << 0);  // Clear PDDS and LPDS
    PWR->CR |= (1 << 0);   // LPDS: low-power regulator in Stop

    __WFI();

    // After wake-up: reconfigure system clock (HSI is active, not HSE/PLL)
    system_clock_config();
}
```

### Power Budgeting

```c
typedef struct {
    const char *component;
    float current_active_mA;
    float current_sleep_mA;
    float duty_cycle;          // Fraction of time active (0.0 – 1.0)
} PowerBudgetEntry;

const PowerBudgetEntry budget[] = {
    { "MCU Run",      15.0,   0.005,  0.01  },  // Active 1% of time
    { "MCU Sleep",     0.0,   0.005,  0.99  },
    { "Sensor",        0.5,   0.001,  0.02  },
    { "Radio TX",     25.0,   0.002,  0.005 },
    { "LED",           5.0,   0.0,    0.01  },
};

float calculate_average_current(void) {
    float total = 0;
    int n = sizeof(budget) / sizeof(budget[0]);
    for (int i = 0; i < n; i++) {
        total += budget[i].current_active_mA * budget[i].duty_cycle
               + budget[i].current_sleep_mA  * (1.0f - budget[i].duty_cycle);
    }
    return total;  // Average current in mA
}

// Battery life: capacity_mAh / average_current_mA = hours
```

## 3.5 Lock-Free Ring Buffer

Ring buffers (circular buffers) are essential for buffering data between producers (ISRs) and consumers (main loop) without locks.

### Implementation

```c
#include <stdint.h>
#include <stdbool.h>

#define RING_BUFFER_SIZE 256  // Must be a power of 2

typedef struct {
    volatile uint8_t  buffer[RING_BUFFER_SIZE];
    volatile uint16_t head;  // Write index (ISR)
    volatile uint16_t tail;  // Read index (main loop)
} RingBuffer;

void ring_buffer_init(RingBuffer *rb) {
    rb->head = 0;
    rb->tail = 0;
}

bool ring_buffer_put(RingBuffer *rb, uint8_t data) {
    uint16_t next_head = (rb->head + 1) & (RING_BUFFER_SIZE - 1);
    if (next_head == rb->tail) {
        return false;  // Full
    }
    rb->buffer[rb->head] = data;
    rb->head = next_head;
    return true;
}

bool ring_buffer_get(RingBuffer *rb, uint8_t *data) {
    if (rb->head == rb->tail) {
        return false;  // Empty
    }
    *data = rb->buffer[rb->tail];
    rb->tail = (rb->tail + 1) & (RING_BUFFER_SIZE - 1);
    return true;
}

uint16_t ring_buffer_count(const RingBuffer *rb) {
    return (rb->head - rb->tail) & (RING_BUFFER_SIZE - 1);
}
```

**Why this is lock-free**: Only one writer (ISR) modifies `head`, and only one reader (main loop) modifies `tail`. Since each index is written atomically, no critical section is needed.

## 3.6 Memory Management in Embedded Systems

Dynamic memory allocation (`malloc`/`free`) is generally avoided in embedded systems due to fragmentation, non-deterministic timing, and the lack of virtual memory. Here are the alternatives:

### Static Allocation (Preferred)

```c
// Allocate everything at compile time
static uint8_t sensor_buffer[128];
static Task    task_pool[MAX_TASKS];
static Message message_queue[16];
```

### Memory Pools (Fixed-Size Block Allocator)

```c
#define POOL_BLOCK_SIZE 32
#define POOL_NUM_BLOCKS 16

typedef struct {
    uint8_t  memory[POOL_NUM_BLOCKS][POOL_BLOCK_SIZE];
    uint8_t  free_mask[POOL_NUM_BLOCKS / 8 + 1];
    uint8_t  count;
} MemoryPool;

void pool_init(MemoryPool *pool) {
    pool->count = 0;
    for (int i = 0; i < (POOL_NUM_BLOCKS / 8 + 1); i++) {
        pool->free_mask[i] = 0xFF;  // All blocks free
    }
}

void *pool_alloc(MemoryPool *pool) {
    for (int i = 0; i < POOL_NUM_BLOCKS; i++) {
        int byte_idx = i / 8;
        int bit_idx  = i % 8;
        if (pool->free_mask[byte_idx] & (1 << bit_idx)) {
            pool->free_mask[byte_idx] &= ~(1 << bit_idx);
            pool->count++;
            return pool->memory[i];
        }
    }
    return NULL;  // Pool exhausted
}

void pool_free(MemoryPool *pool, void *ptr) {
    uintptr_t offset = (uintptr_t)ptr - (uintptr_t)pool->memory;
    int index = offset / POOL_BLOCK_SIZE;
    if (index < POOL_NUM_BLOCKS) {
        int byte_idx = index / 8;
        int bit_idx  = index % 8;
        pool->free_mask[byte_idx] |= (1 << bit_idx);
        pool->count--;
    }
}
```

## Summary

| Topic | Key Takeaway |
|-------|-------------|
| DMA | Offloads data transfers from CPU; essential for high-throughput peripherals |
| RTOS | Manages multiple tasks; cooperative is simpler, preemptive is more responsive |
| State Machines | Table-driven FSMs are maintainable and testable |
| Low Power | Profile your power budget; use deepest sleep mode that meets wake-up requirements |
| Ring Buffer | The lock-free pattern for ISR-to-main-loop data transfer |
| Memory Mgmt | Avoid `malloc`; use static allocation or memory pools |

**Next**: [Chapter 4 — Practical Projects](04_practical_projects.md)
