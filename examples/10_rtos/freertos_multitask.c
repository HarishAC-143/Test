/**
 * @file    freertos_multitask.c
 * @brief   FreeRTOS multi-task application with inter-task communication.
 * @target  ARM Cortex-M with FreeRTOS
 *
 * Demonstrates:
 *  - Creating tasks with different priorities
 *  - Queue for passing data between tasks
 *  - Mutex for protecting shared resources (UART)
 *  - Binary semaphore for ISR-to-task signaling
 *  - Software timer for periodic operations
 *  - Task notifications (lightweight alternative to semaphores)
 *  - Idle hook for power saving
 *
 * Task Architecture:
 *
 *   ┌──────────────┐     Queue      ┌──────────────┐
 *   │ Sensor Task  │ ──────────────► │ Display Task │
 *   │ (Priority 3) │                 │ (Priority 2) │
 *   └──────────────┘                 └──────┬───────┘
 *                                           │ Mutex
 *   ┌──────────────┐                 ┌──────▼───────┐
 *   │ Heartbeat    │                 │  UART        │
 *   │ (Priority 1) │                 │  (shared)    │
 *   └──────────────┘                 └──────────────┘
 *
 *   ┌──────────────┐   Semaphore    ┌──────────────┐
 *   │  ADC ISR     │ ─────────────► │ Process Task │
 *   └──────────────┘                │ (Priority 4) │
 *                                   └──────────────┘
 */

/* FreeRTOS headers (paths depend on your project setup) */
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"
#include "event_groups.h"

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ========================================================================== */
/*  Application Data Types                                                     */
/* ========================================================================== */

typedef struct {
    uint8_t  channel;
    uint16_t value;
    uint32_t timestamp;
} sensor_data_t;

typedef enum {
    ALARM_NONE       = 0,
    ALARM_OVER_TEMP  = (1 << 0),
    ALARM_LOW_BATT   = (1 << 1),
    ALARM_SENSOR_ERR = (1 << 2)
} alarm_flags_t;

/* ========================================================================== */
/*  RTOS Handles                                                               */
/* ========================================================================== */

static QueueHandle_t       sensor_queue      = NULL;
static SemaphoreHandle_t   uart_mutex        = NULL;
static SemaphoreHandle_t   adc_complete_sem  = NULL;
static EventGroupHandle_t  alarm_events      = NULL;
static TimerHandle_t       watchdog_timer    = NULL;
static TaskHandle_t        process_task_handle = NULL;

/* ========================================================================== */
/*  Hardware Stubs (replace with real implementations)                         */
/* ========================================================================== */

extern void uart_printf(const char *fmt, ...);
extern uint16_t adc_read(uint8_t channel);
extern void led_toggle(void);
extern void led_set(bool on);
extern void watchdog_feed(void);

/* ========================================================================== */
/*  Task 1: Sensor Reading (High Priority)                                     */
/* ========================================================================== */

/**
 * Periodically reads sensor data and sends it via a queue.
 * Uses vTaskDelayUntil for precise periodic execution.
 */
static void sensor_task(void *params)
{
    (void)params;
    TickType_t last_wake_time = xTaskGetTickCount();
    uint32_t sample_count = 0;

    while (1) {
        sensor_data_t data;
        data.channel   = 0;
        data.value     = adc_read(0);
        data.timestamp = xTaskGetTickCount();

        /* Send to processing/display via queue */
        if (xQueueSend(sensor_queue, &data, pdMS_TO_TICKS(10)) != pdTRUE) {
            /* Queue full — data lost. Increment error counter. */
        }

        /* Check alarm conditions */
        if (data.value > 3500) {
            xEventGroupSetBits(alarm_events, ALARM_OVER_TEMP);
        }
        if (data.value < 500) {
            xEventGroupSetBits(alarm_events, ALARM_LOW_BATT);
        }

        sample_count++;

        /* Precise 100 ms period — compensates for execution time */
        vTaskDelayUntil(&last_wake_time, pdMS_TO_TICKS(100));
    }
}

/* ========================================================================== */
/*  Task 2: Display / Logger (Medium Priority)                                 */
/* ========================================================================== */

/**
 * Receives sensor data from the queue and displays it via UART.
 * Blocks on the queue — only runs when data is available.
 */
static void display_task(void *params)
{
    (void)params;
    sensor_data_t data;

    while (1) {
        /* Block until data is available (no CPU time wasted polling) */
        if (xQueueReceive(sensor_queue, &data, portMAX_DELAY) == pdTRUE) {
            uint32_t voltage_mv = ((uint32_t)data.value * 3300) / 4095;

            /* Protect UART with mutex (multiple tasks may print) */
            if (xSemaphoreTake(uart_mutex, pdMS_TO_TICKS(100)) == pdTRUE) {
                uart_printf("[%lu] CH%d: %u mV\r\n",
                           (unsigned long)data.timestamp,
                           data.channel,
                           (unsigned int)voltage_mv);
                xSemaphoreGive(uart_mutex);
            }
        }
    }
}

/* ========================================================================== */
/*  Task 3: Heartbeat LED (Low Priority)                                       */
/* ========================================================================== */

/**
 * Blinks an LED to indicate the system is alive.
 * Runs at the lowest priority — only executes when no other task needs CPU.
 */
static void heartbeat_task(void *params)
{
    (void)params;

    while (1) {
        led_toggle();
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/* ========================================================================== */
/*  Task 4: ADC Processing (Highest Priority)                                  */
/* ========================================================================== */

/**
 * Waits for a semaphore from the ADC ISR, then processes the data.
 * This is the "deferred interrupt processing" pattern.
 */
static void adc_process_task(void *params)
{
    (void)params;

    while (1) {
        /* Block until ADC ISR signals data is ready */
        if (xSemaphoreTake(adc_complete_sem, portMAX_DELAY) == pdTRUE) {
            /* Process ADC data (heavy computation deferred from ISR) */
            uint16_t raw = adc_read(0);
            (void)raw;
        }
    }
}

/* ========================================================================== */
/*  Task 5: Alarm Monitor                                                      */
/* ========================================================================== */

/**
 * Waits for alarm events and handles them.
 * Uses Event Groups to wait for any combination of alarm flags.
 */
static void alarm_task(void *params)
{
    (void)params;

    while (1) {
        /* Wait for ANY alarm bit to be set */
        EventBits_t bits = xEventGroupWaitBits(
            alarm_events,
            ALARM_OVER_TEMP | ALARM_LOW_BATT | ALARM_SENSOR_ERR,
            pdTRUE,    /* Clear bits on exit  */
            pdFALSE,   /* Wait for ANY bit    */
            portMAX_DELAY
        );

        if (xSemaphoreTake(uart_mutex, pdMS_TO_TICKS(100)) == pdTRUE) {
            if (bits & ALARM_OVER_TEMP) {
                uart_printf("[ALARM] Over-temperature!\r\n");
            }
            if (bits & ALARM_LOW_BATT) {
                uart_printf("[ALARM] Low battery!\r\n");
            }
            if (bits & ALARM_SENSOR_ERR) {
                uart_printf("[ALARM] Sensor error!\r\n");
            }
            xSemaphoreGive(uart_mutex);
        }
    }
}

/* ========================================================================== */
/*  ISR: ADC Conversion Complete                                               */
/* ========================================================================== */

/**
 * ADC interrupt handler — gives a semaphore to wake the processing task.
 * ISR must use the "FromISR" variants of FreeRTOS API.
 */
void ADC_IRQHandler(void)
{
    BaseType_t higher_priority_task_woken = pdFALSE;

    xSemaphoreGiveFromISR(adc_complete_sem, &higher_priority_task_woken);

    /* If a higher-priority task was woken, request a context switch */
    portYIELD_FROM_ISR(higher_priority_task_woken);
}

/* ========================================================================== */
/*  Software Timer Callback                                                    */
/* ========================================================================== */

/**
 * Called periodically by FreeRTOS timer daemon task.
 * Feeds the hardware watchdog timer.
 */
static void watchdog_timer_callback(TimerHandle_t timer)
{
    (void)timer;
    watchdog_feed();
}

/* ========================================================================== */
/*  Idle Hook — Power Saving                                                   */
/* ========================================================================== */

/**
 * Called by the idle task when no other task is ready to run.
 * Perfect place to put the CPU into low-power sleep.
 *
 * Requires configUSE_IDLE_HOOK = 1 in FreeRTOSConfig.h
 */
void vApplicationIdleHook(void)
{
    __asm volatile ("wfi");  /* Wait For Interrupt — sleep until next tick */
}

/**
 * Called when a stack overflow is detected.
 * Requires configCHECK_FOR_STACK_OVERFLOW = 2 in FreeRTOSConfig.h
 */
void vApplicationStackOverflowHook(TaskHandle_t task, char *task_name)
{
    (void)task;
    (void)task_name;
    /* Log error and halt */
    while (1) { }
}

/* ========================================================================== */
/*  System Initialization                                                      */
/* ========================================================================== */

static void create_rtos_objects(void)
{
    /* Create queue: holds up to 10 sensor readings */
    sensor_queue = xQueueCreate(10, sizeof(sensor_data_t));
    configASSERT(sensor_queue != NULL);

    /* Create mutex for UART access */
    uart_mutex = xSemaphoreCreateMutex();
    configASSERT(uart_mutex != NULL);

    /* Create binary semaphore for ADC ISR → task signaling */
    adc_complete_sem = xSemaphoreCreateBinary();
    configASSERT(adc_complete_sem != NULL);

    /* Create event group for alarm flags */
    alarm_events = xEventGroupCreate();
    configASSERT(alarm_events != NULL);

    /* Create software timer for watchdog feeding (every 500 ms) */
    watchdog_timer = xTimerCreate(
        "Watchdog",                        /* Name (for debugging)    */
        pdMS_TO_TICKS(500),                /* Period                  */
        pdTRUE,                            /* Auto-reload             */
        NULL,                              /* Timer ID (unused)       */
        watchdog_timer_callback            /* Callback function       */
    );
    configASSERT(watchdog_timer != NULL);
}

static void create_tasks(void)
{
    BaseType_t ret;

    /*
     * Stack sizes are in WORDS (not bytes) on ARM.
     * 256 words = 1024 bytes.
     *
     * Higher priority number = higher priority in FreeRTOS.
     */

    ret = xTaskCreate(sensor_task,    "Sensor",    256, NULL, 3, NULL);
    configASSERT(ret == pdPASS);

    ret = xTaskCreate(display_task,   "Display",   512, NULL, 2, NULL);
    configASSERT(ret == pdPASS);

    ret = xTaskCreate(heartbeat_task, "Heartbeat", 128, NULL, 1, NULL);
    configASSERT(ret == pdPASS);

    ret = xTaskCreate(adc_process_task, "ADC_Proc", 256, NULL, 4, &process_task_handle);
    configASSERT(ret == pdPASS);

    ret = xTaskCreate(alarm_task,     "Alarm",     256, NULL, 3, NULL);
    configASSERT(ret == pdPASS);
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    /* Hardware initialization (before scheduler starts) */
    /* system_init(); */
    /* uart_init(115200); */
    /* adc_init(); */
    /* gpio_init(); */

    /* Create RTOS objects and tasks */
    create_rtos_objects();
    create_tasks();

    /* Start the watchdog timer */
    xTimerStart(watchdog_timer, 0);

    uart_printf("FreeRTOS starting...\r\n");

    /* Start the scheduler — this function never returns */
    vTaskStartScheduler();

    /* Should never reach here */
    while (1) { }
}
