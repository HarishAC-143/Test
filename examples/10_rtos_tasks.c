/**
 * @file    10_rtos_tasks.c
 * @brief   RTOS-based multitasking with FreeRTOS-style API
 *
 * Demonstrates:
 *  - Task creation with priorities
 *  - Inter-task communication via queues
 *  - Mutual exclusion with mutexes
 *  - Binary semaphores for ISR-to-task signaling
 *  - Software timers
 *  - Task notifications
 *  - Practical multi-sensor monitoring system
 *
 * Target: ARM Cortex-M running FreeRTOS
 *
 * Note: This file requires FreeRTOS headers. It serves as a reference
 *       implementation and will not compile without a FreeRTOS port.
 */

#include <stdint.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────
 * FreeRTOS API Declarations (normally from FreeRTOS headers)
 *
 * Included here as prototypes for reference. In a real project,
 * #include "FreeRTOS.h", "task.h", "queue.h", "semphr.h", "timers.h"
 * ────────────────────────────────────────────────────────────────────────── */

typedef void *TaskHandle_t;
typedef void *QueueHandle_t;
typedef void *SemaphoreHandle_t;
typedef void *TimerHandle_t;
typedef void *EventGroupHandle_t;
typedef uint32_t TickType_t;
typedef long BaseType_t;
typedef unsigned long UBaseType_t;
typedef uint32_t EventBits_t;

#define pdTRUE   1
#define pdFALSE  0
#define pdPASS   1
#define pdFAIL   0
#define portMAX_DELAY  0xFFFFFFFFUL

extern TickType_t xTaskGetTickCount(void);
extern void vTaskDelay(TickType_t ticks);
extern void vTaskDelayUntil(TickType_t *prev, TickType_t period);
extern BaseType_t xTaskCreate(void (*fn)(void *), const char *name,
    uint16_t stack, void *param, UBaseType_t prio, TaskHandle_t *handle);
extern void vTaskStartScheduler(void);
extern void vTaskSuspend(TaskHandle_t task);
extern void vTaskResume(TaskHandle_t task);

extern QueueHandle_t xQueueCreate(UBaseType_t len, UBaseType_t item_size);
extern BaseType_t xQueueSend(QueueHandle_t q, const void *item,
    TickType_t wait);
extern BaseType_t xQueueReceive(QueueHandle_t q, void *item,
    TickType_t wait);
extern BaseType_t xQueueSendFromISR(QueueHandle_t q, const void *item,
    BaseType_t *woken);

extern SemaphoreHandle_t xSemaphoreCreateBinary(void);
extern SemaphoreHandle_t xSemaphoreCreateMutex(void);
extern SemaphoreHandle_t xSemaphoreCreateCounting(UBaseType_t max,
    UBaseType_t initial);
extern BaseType_t xSemaphoreTake(SemaphoreHandle_t s, TickType_t wait);
extern BaseType_t xSemaphoreGive(SemaphoreHandle_t s);
extern BaseType_t xSemaphoreGiveFromISR(SemaphoreHandle_t s,
    BaseType_t *woken);

extern TimerHandle_t xTimerCreate(const char *name, TickType_t period,
    BaseType_t reload, void *id, void (*cb)(TimerHandle_t));
extern BaseType_t xTimerStart(TimerHandle_t t, TickType_t wait);
extern BaseType_t xTimerStop(TimerHandle_t t, TickType_t wait);

extern EventGroupHandle_t xEventGroupCreate(void);
extern EventBits_t xEventGroupSetBits(EventGroupHandle_t g, EventBits_t bits);
extern EventBits_t xEventGroupWaitBits(EventGroupHandle_t g,
    EventBits_t bits, BaseType_t clear, BaseType_t all, TickType_t wait);
extern EventBits_t xEventGroupSetBitsFromISR(EventGroupHandle_t g,
    EventBits_t bits, BaseType_t *woken);

extern BaseType_t xTaskNotifyGive(TaskHandle_t task);
extern uint32_t ulTaskNotifyTake(BaseType_t clear, TickType_t wait);
extern BaseType_t xTaskNotifyGiveFromISR(TaskHandle_t task,
    BaseType_t *woken);

extern void portYIELD_FROM_ISR(BaseType_t woken);

static inline TickType_t pdMS_TO_TICKS(uint32_t ms)
{
    return ms;  /* Assume configTICK_RATE_HZ = 1000 */
}

/* ──────────────────────────────────────────────────────────────────────────
 * Placeholder Hardware API
 * ────────────────────────────────────────────────────────────────────────── */

extern uint16_t adc_read(uint8_t channel);
extern uint8_t  gpio_read(void *port, uint8_t pin);
extern void     gpio_toggle(void *port, uint8_t pin);
extern void     gpio_write(void *port, uint8_t pin, uint8_t val);
extern void     uart_printf(void *uart, const char *fmt, ...);

#define GPIOA  ((void *)0x48000000U)
#define USART1 ((void *)0x40011000U)

/* ──────────────────────────────────────────────────────────────────────────
 * Shared Data Structures
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    uint8_t  sensor_id;
    int16_t  value;
    uint32_t timestamp_ms;
} sensor_reading_t;

typedef enum {
    ALARM_NONE         = 0,
    ALARM_OVER_TEMP    = (1 << 0),
    ALARM_UNDER_VOLT   = (1 << 1),
    ALARM_SENSOR_FAULT = (1 << 2)
} alarm_flags_t;

/* RTOS objects */
static QueueHandle_t      sensor_queue;
static SemaphoreHandle_t  uart_mutex;
static SemaphoreHandle_t  adc_sem;       /* ISR-to-task signaling */
static EventGroupHandle_t alarm_events;
static TaskHandle_t       display_task_handle;
static TimerHandle_t      watchdog_timer;

/* ──────────────────────────────────────────────────────────────────────────
 * Task 1: Sensor Sampling (High Priority)
 *
 * Reads multiple ADC channels at a fixed 100 ms rate and sends
 * readings to the processing queue.
 * ────────────────────────────────────────────────────────────────────────── */

static void sensor_task(void *params)
{
    (void)params;
    TickType_t last_wake = xTaskGetTickCount();

    const uint8_t channels[] = {0, 1, 4, 5};
    const uint8_t num_channels = sizeof(channels) / sizeof(channels[0]);

    while (1) {
        for (uint8_t i = 0; i < num_channels; i++) {
            sensor_reading_t reading = {
                .sensor_id    = channels[i],
                .value        = (int16_t)adc_read(channels[i]),
                .timestamp_ms = (uint32_t)xTaskGetTickCount()
            };

            xQueueSend(sensor_queue, &reading, 0);
        }

        vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(100));
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Task 2: Data Processing (Medium Priority)
 *
 * Receives sensor readings, applies thresholds, and raises alarms.
 * ────────────────────────────────────────────────────────────────────────── */

#define TEMP_CHANNEL  0
#define VOLT_CHANNEL  1
#define TEMP_ALARM_RAW   3300   /* ~2.66V at 12-bit ADC → over-temperature */
#define VOLT_ALARM_RAW   500    /* ~0.40V → under-voltage */

static int16_t latest_values[8];

static void processing_task(void *params)
{
    (void)params;
    sensor_reading_t reading;

    while (1) {
        if (xQueueReceive(sensor_queue, &reading,
                          portMAX_DELAY) == pdTRUE) {
            latest_values[reading.sensor_id] = reading.value;

            /* Check thresholds */
            if (reading.sensor_id == TEMP_CHANNEL &&
                reading.value > TEMP_ALARM_RAW) {
                xEventGroupSetBits(alarm_events, ALARM_OVER_TEMP);
            }

            if (reading.sensor_id == VOLT_CHANNEL &&
                reading.value < VOLT_ALARM_RAW) {
                xEventGroupSetBits(alarm_events, ALARM_UNDER_VOLT);
            }

            /* Notify the display task that new data is ready */
            xTaskNotifyGive(display_task_handle);
        }
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Task 3: Display / Logging (Low Priority)
 *
 * Waits for notification, then prints latest values.
 * Uses a mutex to protect the shared UART.
 * ────────────────────────────────────────────────────────────────────────── */

static void display_task(void *params)
{
    (void)params;
    uint32_t notification_count;

    while (1) {
        notification_count = ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(1000));

        if (notification_count > 0) {
            xSemaphoreTake(uart_mutex, portMAX_DELAY);

            uart_printf(USART1,
                "[%lu] CH0:%d CH1:%d CH4:%d CH5:%d\r\n",
                (unsigned long)xTaskGetTickCount(),
                latest_values[0], latest_values[1],
                latest_values[4], latest_values[5]);

            xSemaphoreGive(uart_mutex);
        }
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Task 4: Alarm Handler
 *
 * Waits on event group flags. When an alarm is raised, takes
 * corrective action and logs the event.
 * ────────────────────────────────────────────────────────────────────────── */

static void alarm_task(void *params)
{
    (void)params;

    while (1) {
        EventBits_t bits = xEventGroupWaitBits(alarm_events,
            ALARM_OVER_TEMP | ALARM_UNDER_VOLT | ALARM_SENSOR_FAULT,
            pdTRUE,     /* Clear bits on exit */
            pdFALSE,    /* Any bit (OR) */
            portMAX_DELAY);

        xSemaphoreTake(uart_mutex, portMAX_DELAY);

        if (bits & ALARM_OVER_TEMP) {
            uart_printf(USART1, "*** ALARM: Over-temperature! ***\r\n");
            gpio_write(GPIOA, 6, 1);  /* Turn on warning LED */
        }

        if (bits & ALARM_UNDER_VOLT) {
            uart_printf(USART1, "*** ALARM: Under-voltage! ***\r\n");
            gpio_write(GPIOA, 7, 1);
        }

        if (bits & ALARM_SENSOR_FAULT) {
            uart_printf(USART1, "*** ALARM: Sensor fault! ***\r\n");
        }

        xSemaphoreGive(uart_mutex);
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Task 5: Heartbeat (Lowest Priority)
 *
 * Blinks an LED to show the system is alive.
 * ────────────────────────────────────────────────────────────────────────── */

static void heartbeat_task(void *params)
{
    (void)params;

    while (1) {
        gpio_toggle(GPIOA, 5);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Software Timer Callback: Watchdog Check
 *
 * Called periodically by the RTOS timer daemon to verify all tasks
 * are still running. Each task updates its check-in time.
 * ────────────────────────────────────────────────────────────────────────── */

#define NUM_MONITORED_TASKS 4
static volatile uint32_t task_checkin[NUM_MONITORED_TASKS];

void task_report_alive(uint8_t task_id)
{
    if (task_id < NUM_MONITORED_TASKS) {
        task_checkin[task_id] = (uint32_t)xTaskGetTickCount();
    }
}

static void watchdog_callback(TimerHandle_t timer)
{
    (void)timer;
    uint32_t now = (uint32_t)xTaskGetTickCount();

    for (uint8_t i = 0; i < NUM_MONITORED_TASKS; i++) {
        if ((now - task_checkin[i]) > 5000) {
            xSemaphoreTake(uart_mutex, pdMS_TO_TICKS(100));
            uart_printf(USART1,
                "WATCHDOG: Task %u not responding!\r\n", i);
            xSemaphoreGive(uart_mutex);
        }
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * ISR Example: ADC End-of-Conversion → Semaphore
 * ────────────────────────────────────────────────────────────────────────── */

void ADC1_IRQHandler(void)
{
    BaseType_t woken = pdFALSE;
    /* Clear ADC EOC flag here */
    xSemaphoreGiveFromISR(adc_sem, &woken);
    portYIELD_FROM_ISR(woken);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Main: Create RTOS Objects and Start Scheduler
 * ────────────────────────────────────────────────────────────────────────── */

int main(void)
{
    /* Hardware init (clocks, GPIO, UART, ADC — not shown) */

    /* Create RTOS objects */
    sensor_queue = xQueueCreate(32, sizeof(sensor_reading_t));
    uart_mutex   = xSemaphoreCreateMutex();
    adc_sem      = xSemaphoreCreateBinary();
    alarm_events = xEventGroupCreate();

    /* Create tasks (higher number = higher priority) */
    xTaskCreate(sensor_task,    "Sensor",    256, NULL, 4, NULL);
    xTaskCreate(processing_task,"Process",   256, NULL, 3, NULL);
    xTaskCreate(display_task,   "Display",   512, NULL, 2,
                &display_task_handle);
    xTaskCreate(alarm_task,     "Alarm",     256, NULL, 4, NULL);
    xTaskCreate(heartbeat_task, "Heartbeat", 128, NULL, 1, NULL);

    /* Create software watchdog timer (checks every 2 seconds) */
    watchdog_timer = xTimerCreate("WDog", pdMS_TO_TICKS(2000),
                                   pdTRUE, NULL, watchdog_callback);
    xTimerStart(watchdog_timer, 0);

    /* Initialize check-in timestamps */
    uint32_t now = (uint32_t)xTaskGetTickCount();
    for (uint8_t i = 0; i < NUM_MONITORED_TASKS; i++) {
        task_checkin[i] = now;
    }

    uart_printf(USART1, "=== RTOS Multi-Sensor System Started ===\r\n");

    vTaskStartScheduler();

    /* Should never reach here */
    while (1);
    return 0;
}
