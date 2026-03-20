# Chapter 14: RTOS Fundamentals

As firmware complexity grows, bare-metal super-loops become hard to manage. A Real-Time Operating System (RTOS) provides structured concurrency — multiple independent tasks running on a single CPU with predictable timing guarantees.

## Bare-Metal vs. RTOS

### Bare-Metal Super-Loop

```c
int main(void)
{
    system_init();
    while (1) {
        read_sensors();       /* Takes 5 ms */
        update_display();     /* Takes 15 ms */
        check_buttons();      /* Takes 1 ms */
        run_motor_control();  /* Takes 2 ms */
        handle_communication();  /* Variable — 0 to 50 ms */
    }
}
```

Problems:
- `run_motor_control()` may not run for up to 70 ms
- Communication delays affect everything else
- Priority management is manual and fragile

### RTOS Multi-Task

```c
void task_motor_control(void *params)
{
    while (1) {
        update_motor_pid();
        vTaskDelay(pdMS_TO_TICKS(2));  /* Runs every 2 ms, guaranteed */
    }
}

void task_display(void *params)
{
    while (1) {
        refresh_display();
        vTaskDelay(pdMS_TO_TICKS(100));  /* Lower priority, 100 ms is fine */
    }
}

void task_communication(void *params)
{
    while (1) {
        handle_serial_data();  /* Can block without affecting motor control */
    }
}
```

## Key RTOS Concepts

### Tasks (Threads)

Each task is an independent function with its own:
- **Stack** — local variables, return addresses
- **Priority** — determines scheduling order
- **State** — running, ready, blocked, suspended

```c
/* FreeRTOS task creation */
xTaskCreate(
    task_motor_control,    /* Task function */
    "MotorCtrl",           /* Name (for debugging) */
    256,                   /* Stack size (words) */
    NULL,                  /* Parameter */
    3,                     /* Priority (higher = more important) */
    &motor_task_handle     /* Task handle */
);
```

### Scheduler

The scheduler decides which task runs. Common scheduling policies:

| Policy | Description |
|--------|-------------|
| **Preemptive Priority** | Highest-priority ready task always runs. Interrupts lower-priority tasks. |
| **Round-Robin** | Equal-priority tasks share CPU time in time slices. |
| **Cooperative** | Tasks run until they explicitly yield. |

Most embedded RTOS (FreeRTOS, Zephyr, ThreadX) use **preemptive priority with round-robin for equal priorities**.

### Task States

```
                    ┌───────────┐
        Create ────▶│   READY   │◀──── Event/Timeout
                    └─────┬─────┘
                          │ Scheduled
                          ▼
                    ┌───────────┐
                    │  RUNNING  │
                    └─────┬─────┘
                     │         │
            Preempted│         │Wait for event
                     │         │
                     ▼         ▼
              ┌─────────┐  ┌──────────┐
              │  READY  │  │ BLOCKED  │
              └─────────┘  └──────────┘
```

## Synchronization Primitives

### Semaphores

A semaphore is a signaling mechanism. A **binary semaphore** is used to signal from an ISR to a task:

```c
SemaphoreHandle_t uart_rx_sem;

void setup(void)
{
    uart_rx_sem = xSemaphoreCreateBinary();
}

void USART1_IRQHandler(void)
{
    if (USART1->SR & (1U << 5)) {
        received_byte = USART1->DR;
        BaseType_t woken = pdFALSE;
        xSemaphoreGiveFromISR(uart_rx_sem, &woken);
        portYIELD_FROM_ISR(woken);
    }
}

void task_uart_handler(void *params)
{
    while (1) {
        /* Block until ISR signals data available */
        xSemaphoreTake(uart_rx_sem, portMAX_DELAY);
        process_byte(received_byte);
    }
}
```

### Mutexes

A mutex provides **mutual exclusion** — only one task can hold it at a time:

```c
SemaphoreHandle_t spi_mutex;

void task_sensor_read(void *params)
{
    while (1) {
        xSemaphoreTake(spi_mutex, portMAX_DELAY);
        spi_read_sensor();
        xSemaphoreGive(spi_mutex);

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void task_sd_card_write(void *params)
{
    while (1) {
        xSemaphoreTake(spi_mutex, portMAX_DELAY);
        spi_write_sd_card(data, len);
        xSemaphoreGive(spi_mutex);

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
```

**Mutex vs. Binary Semaphore:** Mutexes support **priority inheritance** — if a high-priority task is blocked waiting for a mutex held by a low-priority task, the low-priority task temporarily runs at the higher priority. This prevents **priority inversion**.

### Message Queues

Queues pass data between tasks safely:

```c
QueueHandle_t sensor_queue;

typedef struct {
    uint8_t  sensor_id;
    int16_t  value;
    uint32_t timestamp;
} SensorData;

void setup(void)
{
    sensor_queue = xQueueCreate(10, sizeof(SensorData));
}

void task_sensor_read(void *params)
{
    while (1) {
        SensorData data = {
            .sensor_id = 1,
            .value = read_temperature(),
            .timestamp = xTaskGetTickCount()
        };
        xQueueSend(sensor_queue, &data, portMAX_DELAY);
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void task_data_logger(void *params)
{
    SensorData data;
    while (1) {
        if (xQueueReceive(sensor_queue, &data, portMAX_DELAY)) {
            log_to_sd_card(&data);
        }
    }
}
```

### Event Groups (Flags)

Wait for multiple events simultaneously:

```c
EventGroupHandle_t system_events;

#define EVT_SENSOR_READY  (1 << 0)
#define EVT_GPS_FIX       (1 << 1)
#define EVT_SD_MOUNTED    (1 << 2)

void task_startup(void *params)
{
    /* Wait until all three subsystems are ready */
    xEventGroupWaitBits(
        system_events,
        EVT_SENSOR_READY | EVT_GPS_FIX | EVT_SD_MOUNTED,
        pdTRUE,           /* Clear bits on exit */
        pdTRUE,           /* Wait for ALL bits */
        pdMS_TO_TICKS(10000)  /* 10-second timeout */
    );

    start_data_logging();
}
```

## Software Timers

Run a function periodically without dedicating a task:

```c
TimerHandle_t heartbeat_timer;

void heartbeat_callback(TimerHandle_t timer)
{
    gpio_toggle_pin(GPIOA, 5);  /* Toggle LED */
}

void setup(void)
{
    heartbeat_timer = xTimerCreate(
        "Heartbeat",
        pdMS_TO_TICKS(500),  /* Period */
        pdTRUE,              /* Auto-reload */
        NULL,                /* Timer ID */
        heartbeat_callback
    );
    xTimerStart(heartbeat_timer, 0);
}
```

## Common RTOS Pitfalls

### 1. Stack Overflow

Each task needs its own stack. Too small → crash. Too large → wasted RAM.

```c
/* FreeRTOS stack overflow hook */
void vApplicationStackOverflowHook(TaskHandle_t task, char *name)
{
    /* Log the task name and halt */
    error_handler("Stack overflow in: ", name);
}
```

### 2. Priority Inversion

A high-priority task blocked by a low-priority task because a medium-priority task preempted the low-priority one. Solution: use **mutexes** (not semaphores) for resource locking.

### 3. Deadlock

Two tasks each waiting for a mutex held by the other. Prevention:
- Always acquire mutexes in the same order
- Use timeouts instead of infinite waits
- Minimize the scope of mutex locks

### 4. Using Non-Thread-Safe APIs

Standard library functions like `printf`, `malloc`, and `strtok` are often not thread-safe. Use RTOS-aware versions or protect with mutexes.

## Choosing an RTOS

| RTOS | License | Notable Features |
|------|---------|------------------|
| **FreeRTOS** | MIT | Most popular, AWS-backed, vast ecosystem |
| **Zephyr** | Apache 2.0 | Linux Foundation, supports many architectures |
| **ThreadX** | MIT (Azure RTOS) | Safety-certified, efficient |
| **ChibiOS** | GPL/Commercial | Integrated HAL, well-documented |
| **CMSIS-RTOS2** | API standard | Common API wrapping various RTOS implementations |

## Summary

- An RTOS provides structured concurrency with predictable timing.
- Tasks have independent stacks, priorities, and states.
- Use semaphores for ISR-to-task signaling.
- Use mutexes for shared resource protection (with priority inheritance).
- Use queues for safe data passing between tasks.
- Watch for stack overflows, priority inversion, and deadlocks.

---

**Next:** [Chapter 15 — Low-Power Techniques](15-low-power-techniques.md)
