/**
 * FreeRTOS Example 10 — Real-World IoT Sensor Node Application
 *
 * A complete multi-task application demonstrating how all FreeRTOS
 * primitives work together in a realistic IoT sensor node.
 *
 * System Architecture:
 *
 *   ┌─────────────┐    ┌──────────────┐    ┌───────────────┐
 *   │ Sensor Task  │───>│ Data Queue   │───>│ Processing    │
 *   │ (10 Hz)      │    │ (16 items)   │    │ Task          │
 *   └─────────────┘    └──────────────┘    └───────┬───────┘
 *                                                   │
 *   ┌─────────────┐    ┌──────────────┐             │
 *   │ Button ISR   │───>│ Event Group  │             ▼
 *   └─────────────┘    │              │    ┌───────────────┐
 *   ┌─────────────┐    │              │───>│ Display Task  │
 *   │ WiFi Task    │───>│              │    │               │
 *   └─────────────┘    └──────────────┘    └───────────────┘
 *                                                   │
 *   ┌─────────────┐         ┌─────────┐             │
 *   │ Heartbeat   │         │ Status  │<────────────┘
 *   │ Timer       │         │ Queue   │
 *   └─────────────┘         │ (len=1) │
 *                           └────┬────┘
 *   ┌─────────────┐              │
 *   │ Watchdog    │<─────────────┘
 *   │ Task        │    ┌──────────────┐
 *   └─────────────┘    │ I2C Mutex    │
 *                      │ (gateway)    │
 *   ┌─────────────┐    └──────────────┘
 *   │ Monitor     │
 *   │ Task        │ ← Stack/heap diagnostics
 *   └─────────────┘
 *
 * Primitives Used:
 *   - Tasks (6 application tasks + idle + timer daemon)
 *   - Queue (sensor data, length=16)
 *   - Queue overwrite (system status, length=1)
 *   - Mutex (I2C bus, UART print)
 *   - Binary semaphore (ADC ISR signaling)
 *   - Event group (system events)
 *   - Software timer (heartbeat LED, inactivity timeout)
 *   - Task notification (DMA completion)
 *   - Message buffer (log messages)
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "timers.h"
#include "message_buffer.h"
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

/* ===========================================================================
 * Hardware Abstraction Layer (Stubs)
 * =========================================================================== */
static void hw_init(void)                { }
static void uart_write(const char *s)    { printf("%s", s); }
static void led_toggle(int n)            { (void)n; }
static void led_set(int n, int on)       { (void)n; (void)on; }
static void watchdog_reload(void)        { }
static void enter_sleep(void)            { }

static int  i2c_read_temp(void)          { static int t = 220; t = 220 + (t % 50); return t; }
static int  i2c_read_humidity(void)      { static int h = 55; h = 40 + (h % 60); return h; }
static int  i2c_read_pressure(void)      { static int p = 10130; return p + (p % 20); }
static int  i2c_read_light(void)         { static int l = 500; return l + (l % 300); }
static int  read_battery_mv(void)        { return 3700; }
static int  wifi_is_connected(void)      { static int c = 0; c++; return c > 3; }

/* ===========================================================================
 * Configuration
 * =========================================================================== */
#define SENSOR_SAMPLE_RATE_HZ    10
#define SENSOR_QUEUE_LEN         16
#define LOG_BUFFER_SIZE          512
#define DISPLAY_REFRESH_MS       1000
#define WATCHDOG_CHECK_MS        5000
#define INACTIVITY_TIMEOUT_MS    30000

/* ===========================================================================
 * Event Bit Definitions
 * =========================================================================== */
#define EVT_SENSOR_DATA_READY   (1 << 0)
#define EVT_BUTTON_PRESS        (1 << 1)
#define EVT_WIFI_CONNECTED      (1 << 2)
#define EVT_WIFI_DISCONNECTED   (1 << 3)
#define EVT_ALARM_TEMP_HIGH     (1 << 4)
#define EVT_ALARM_BATT_LOW      (1 << 5)
#define EVT_DATA_UPLOADED       (1 << 6)

/* Watchdog alive bits */
#define WD_SENSOR_ALIVE         (1 << 0)
#define WD_PROCESS_ALIVE        (1 << 1)
#define WD_DISPLAY_ALIVE        (1 << 2)
#define WD_WIFI_ALIVE           (1 << 3)
#define WD_ALL_ALIVE            (WD_SENSOR_ALIVE | WD_PROCESS_ALIVE | \
                                 WD_DISPLAY_ALIVE | WD_WIFI_ALIVE)

/* ===========================================================================
 * Data Structures
 * =========================================================================== */
typedef struct {
    int16_t    temperature_x10;  /* Celsius * 10 */
    uint8_t    humidity;         /* 0–100% */
    uint16_t   pressure_x10;    /* hPa * 10 */
    uint16_t   light_lux;
    TickType_t timestamp;
} SensorData_t;

typedef struct {
    uint32_t uptime_seconds;
    int16_t  last_temperature;
    uint8_t  last_humidity;
    uint8_t  battery_percent;
    uint8_t  wifi_connected;
    uint8_t  alarm_active;
    uint32_t samples_processed;
    uint32_t upload_count;
} SystemStatus_t;

/* ===========================================================================
 * Global FreeRTOS Objects
 * =========================================================================== */
static QueueHandle_t         xSensorQueue       = NULL;
static QueueHandle_t         xStatusQueue        = NULL;
static SemaphoreHandle_t     xI2CMutex           = NULL;
static SemaphoreHandle_t     xPrintMutex         = NULL;
static EventGroupHandle_t    xSystemEvents       = NULL;
static EventGroupHandle_t    xWatchdogEvents     = NULL;
static TimerHandle_t         xHeartbeatTimer     = NULL;
static TimerHandle_t         xInactivityTimer    = NULL;
static MessageBufferHandle_t xLogBuffer          = NULL;

static TaskHandle_t xSensorTaskHandle   = NULL;
static TaskHandle_t xProcessTaskHandle  = NULL;
static TaskHandle_t xDisplayTaskHandle  = NULL;
static TaskHandle_t xWifiTaskHandle     = NULL;

/* ===========================================================================
 * Utility: Thread-Safe Logging
 * =========================================================================== */
static void sys_log(const char *tag, const char *fmt, ...)
{
    char msg[128];
    va_list args;
    va_start(args, fmt);
    int n = snprintf(msg, sizeof(msg), "[%8lu] [%-8s] ",
                     (unsigned long)xTaskGetTickCount(), tag);
    n += vsnprintf(msg + n, sizeof(msg) - (size_t)n, fmt, args);
    va_end(args);

    if (n > 0 && (size_t)n < sizeof(msg) - 2) {
        msg[n++] = '\r';
        msg[n++] = '\n';
        msg[n]   = '\0';
    }

    /* Send to log message buffer (non-blocking) */
    xMessageBufferSend(xLogBuffer, msg, strlen(msg), 0);

    /* Also direct print (protected by mutex) */
    xSemaphoreTake(xPrintMutex, portMAX_DELAY);
    uart_write(msg);
    xSemaphoreGive(xPrintMutex);
}

/* ===========================================================================
 * Sensor Task — Producer
 *
 * Reads sensor data via I2C at a fixed rate using vTaskDelayUntil.
 * Sends readings to the sensor data queue for processing.
 * Signals EVT_SENSOR_DATA_READY via event group.
 * Reports alive status to watchdog.
 * =========================================================================== */
void vSensorTask(void *pvParameters)
{
    (void)pvParameters;
    TickType_t xLastWake = xTaskGetTickCount();
    const TickType_t xPeriod = pdMS_TO_TICKS(1000 / SENSOR_SAMPLE_RATE_HZ);

    sys_log("SENSOR", "Started at %d Hz", SENSOR_SAMPLE_RATE_HZ);

    for (;;) {
        SensorData_t data;

        /* Acquire I2C bus via mutex */
        if (xSemaphoreTake(xI2CMutex, pdMS_TO_TICKS(50)) == pdTRUE) {
            data.temperature_x10 = (int16_t)i2c_read_temp();
            data.humidity        = (uint8_t)i2c_read_humidity();
            data.pressure_x10   = (uint16_t)i2c_read_pressure();
            data.light_lux      = (uint16_t)i2c_read_light();
            data.timestamp       = xTaskGetTickCount();
            xSemaphoreGive(xI2CMutex);

            /* Send to processing queue */
            if (xQueueSend(xSensorQueue, &data, 0) != pdPASS) {
                sys_log("SENSOR", "Queue full — sample dropped!");
            }

            /* Signal that new data is available */
            xEventGroupSetBits(xSystemEvents, EVT_SENSOR_DATA_READY);

            /* Temperature alarm check */
            if (data.temperature_x10 > 350) {
                xEventGroupSetBits(xSystemEvents, EVT_ALARM_TEMP_HIGH);
            }
        } else {
            sys_log("SENSOR", "I2C mutex timeout");
        }

        /* Report alive to watchdog */
        xEventGroupSetBits(xWatchdogEvents, WD_SENSOR_ALIVE);

        xTaskDelayUntil(&xLastWake, xPeriod);
    }
}

/* ===========================================================================
 * Data Processing Task — Consumer
 *
 * Receives sensor data from the queue, applies filtering, checks thresholds,
 * and updates the system status (via queue overwrite).
 * =========================================================================== */
void vProcessingTask(void *pvParameters)
{
    (void)pvParameters;
    SensorData_t data;
    uint32_t samples_processed = 0;
    int32_t temp_sum = 0;
    uint32_t temp_count = 0;

    sys_log("PROCESS", "Started");

    for (;;) {
        if (xQueueReceive(xSensorQueue, &data, portMAX_DELAY) == pdPASS) {
            samples_processed++;

            /* Running average for temperature */
            temp_sum += data.temperature_x10;
            temp_count++;
            int16_t avg_temp = (int16_t)(temp_sum / (int32_t)temp_count);

            /* Update system status (overwrite = always latest) */
            SystemStatus_t status = {
                .uptime_seconds    = (uint32_t)(xTaskGetTickCount() / configTICK_RATE_HZ),
                .last_temperature  = avg_temp,
                .last_humidity     = data.humidity,
                .battery_percent   = (uint8_t)(read_battery_mv() * 100 / 4200),
                .wifi_connected    = (uint8_t)wifi_is_connected(),
                .alarm_active      = 0,
                .samples_processed = samples_processed,
                .upload_count      = 0
            };
            xQueueOverwrite(xStatusQueue, &status);

            if (samples_processed % 50 == 0) {
                sys_log("PROCESS", "Processed %lu samples, avg_temp=%d.%d°C",
                        (unsigned long)samples_processed,
                        avg_temp / 10, avg_temp % 10);
            }
        }

        xEventGroupSetBits(xWatchdogEvents, WD_PROCESS_ALIVE);
    }
}

/* ===========================================================================
 * Display Task — Status Display
 *
 * Periodically reads the system status and displays it. Also responds
 * to button press and alarm events.
 * =========================================================================== */
void vDisplayTask(void *pvParameters)
{
    (void)pvParameters;
    SystemStatus_t status;

    sys_log("DISPLAY", "Started");

    for (;;) {
        /* Wait for any display-relevant event OR timeout for periodic refresh */
        EventBits_t bits = xEventGroupWaitBits(
            xSystemEvents,
            EVT_SENSOR_DATA_READY | EVT_BUTTON_PRESS | EVT_ALARM_TEMP_HIGH,
            pdTRUE,              /* Clear on exit */
            pdFALSE,             /* OR — any bit */
            pdMS_TO_TICKS(DISPLAY_REFRESH_MS)
        );

        /* Read latest status */
        if (xQueuePeek(xStatusQueue, &status, 0) == pdPASS) {
            if (bits & EVT_ALARM_TEMP_HIGH) {
                sys_log("DISPLAY", "!!! HIGH TEMPERATURE ALARM !!!");
                led_set(2, 1);  /* Red LED on */
            }

            if (bits & EVT_BUTTON_PRESS) {
                sys_log("DISPLAY", "Button pressed — showing status");
                xTimerReset(xInactivityTimer, pdMS_TO_TICKS(100));
            }

            /* Periodic status display */
            static uint32_t refresh_count = 0;
            if (++refresh_count % 10 == 0) {
                sys_log("DISPLAY",
                        "T=%d.%d°C H=%u%% Batt=%u%% WiFi=%s Samples=%lu",
                        status.last_temperature / 10,
                        status.last_temperature % 10,
                        status.last_humidity,
                        status.battery_percent,
                        status.wifi_connected ? "YES" : "NO",
                        (unsigned long)status.samples_processed);
            }
        }

        xEventGroupSetBits(xWatchdogEvents, WD_DISPLAY_ALIVE);
    }
}

/* ===========================================================================
 * WiFi Task — Cloud Communication
 *
 * Periodically uploads sensor data to the cloud. Uses a task notification
 * to signal the processing task when upload is complete.
 * =========================================================================== */
void vWifiTask(void *pvParameters)
{
    (void)pvParameters;
    SystemStatus_t status;
    uint32_t upload_count = 0;

    sys_log("WIFI", "Started");

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(5000));

        if (wifi_is_connected()) {
            /* Check if not already reported */
            static uint8_t reported_connected = 0;
            if (!reported_connected) {
                xEventGroupSetBits(xSystemEvents, EVT_WIFI_CONNECTED);
                sys_log("WIFI", "Connected to network");
                reported_connected = 1;
            }

            /* Upload latest status */
            if (xQueuePeek(xStatusQueue, &status, 0) == pdPASS) {
                sys_log("WIFI", "Uploading data to cloud...");
                vTaskDelay(pdMS_TO_TICKS(500)); /* Simulate upload */
                upload_count++;
                sys_log("WIFI", "Upload #%lu complete",
                        (unsigned long)upload_count);
                xEventGroupSetBits(xSystemEvents, EVT_DATA_UPLOADED);
            }
        } else {
            sys_log("WIFI", "Not connected — skipping upload");
        }

        xEventGroupSetBits(xWatchdogEvents, WD_WIFI_ALIVE);
    }
}

/* ===========================================================================
 * Watchdog Task — System Health Monitor
 *
 * Uses event groups to verify all tasks are alive. Each task sets its
 * "alive" bit periodically. The watchdog waits for all bits with a timeout.
 * If any task fails to report, the system is considered unhealthy.
 * =========================================================================== */
void vWatchdogTask(void *pvParameters)
{
    (void)pvParameters;

    sys_log("WATCHDOG", "Started (timeout=%dms)", WATCHDOG_CHECK_MS);

    for (;;) {
        EventBits_t bits = xEventGroupWaitBits(
            xWatchdogEvents,
            WD_ALL_ALIVE,
            pdTRUE,           /* Clear all bits */
            pdTRUE,           /* Wait for ALL */
            pdMS_TO_TICKS(WATCHDOG_CHECK_MS)
        );

        if ((bits & WD_ALL_ALIVE) == WD_ALL_ALIVE) {
            watchdog_reload();
            sys_log("WATCHDOG", "All tasks alive — watchdog fed");
        } else {
            sys_log("WATCHDOG", "TIMEOUT! Missing: S=%c P=%c D=%c W=%c",
                    (bits & WD_SENSOR_ALIVE)  ? 'Y' : 'N',
                    (bits & WD_PROCESS_ALIVE) ? 'Y' : 'N',
                    (bits & WD_DISPLAY_ALIVE) ? 'Y' : 'N',
                    (bits & WD_WIFI_ALIVE)    ? 'Y' : 'N');
        }
    }
}

/* ===========================================================================
 * System Monitor Task — Diagnostics
 *
 * Reports heap usage, stack high-water marks, and task list periodically.
 * This is a development/debugging aid.
 * =========================================================================== */
void vMonitorTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(15000));

        sys_log("MONITOR", "=== System Diagnostics ===");

        /* Heap */
        sys_log("MONITOR", "Heap: free=%u, min_ever=%u, used=%.1f%%",
                (unsigned)xPortGetFreeHeapSize(),
                (unsigned)xPortGetMinimumEverFreeHeapSize(),
                100.0 * (1.0 - (double)xPortGetFreeHeapSize() / configTOTAL_HEAP_SIZE));

        /* Stack HWM for all tasks */
        struct {
            TaskHandle_t handle;
            const char  *name;
        } tasks[] = {
            { xSensorTaskHandle,  "Sensor"  },
            { xProcessTaskHandle, "Process" },
            { xDisplayTaskHandle, "Display" },
            { xWifiTaskHandle,    "WiFi"    },
        };

        for (int i = 0; i < 4; i++) {
            if (tasks[i].handle != NULL) {
                UBaseType_t hwm = uxTaskGetStackHighWaterMark(tasks[i].handle);
                sys_log("MONITOR", "  %-8s stack HWM: %u words",
                        tasks[i].name, (unsigned)hwm);
            }
        }

        /* Queue utilization */
        sys_log("MONITOR", "Sensor queue: %u/%d items",
                (unsigned)uxQueueMessagesWaiting(xSensorQueue),
                SENSOR_QUEUE_LEN);

        /* Total task count */
        sys_log("MONITOR", "Total tasks: %u",
                (unsigned)uxTaskGetNumberOfTasks());

        sys_log("MONITOR", "=========================");
    }
}

/* ===========================================================================
 * Timer Callbacks
 * =========================================================================== */
void vHeartbeatCallback(TimerHandle_t xTimer)
{
    (void)xTimer;
    led_toggle(0);
}

void vInactivityCallback(TimerHandle_t xTimer)
{
    (void)xTimer;
    sys_log("TIMER", "Inactivity timeout — dimming display");
    led_set(1, 0);
    enter_sleep();
}

/* ===========================================================================
 * ISR Handlers (Simulated)
 * =========================================================================== */
void EXTI0_IRQHandler(void)  /* Button press */
{
    BaseType_t xWoken = pdFALSE;
    xEventGroupSetBitsFromISR(xSystemEvents, EVT_BUTTON_PRESS, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

/* ===========================================================================
 * Log Drain Task — Writes buffered log messages
 * =========================================================================== */
void vLogDrainTask(void *pvParameters)
{
    (void)pvParameters;
    char msg[128];

    for (;;) {
        size_t n = xMessageBufferReceive(xLogBuffer, msg, sizeof(msg) - 1,
                                          portMAX_DELAY);
        if (n > 0) {
            msg[n] = '\0';
            /* In a real system, write to SD card, serial, or flash */
            (void)msg;
        }
    }
}

/* ===========================================================================
 * Required Hooks
 * =========================================================================== */
void vApplicationIdleHook(void)
{
    __asm volatile("wfi");
}

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    (void)xTask;
    char buf[64];
    snprintf(buf, sizeof(buf), "STACK OVERFLOW: %s\r\n", pcTaskName);
    uart_write(buf);
    taskDISABLE_INTERRUPTS();
    for (;;);
}

void vApplicationMallocFailedHook(void)
{
    uart_write("MALLOC FAILED\r\n");
    taskDISABLE_INTERRUPTS();
    for (;;);
}

/* ===========================================================================
 * Main — System Initialization
 * =========================================================================== */
int main(void)
{
    hw_init();

    /* Create synchronization primitives */
    xI2CMutex       = xSemaphoreCreateMutex();
    xPrintMutex     = xSemaphoreCreateMutex();
    xSystemEvents   = xEventGroupCreate();
    xWatchdogEvents = xEventGroupCreate();

    /* Create data channels */
    xSensorQueue = xQueueCreate(SENSOR_QUEUE_LEN, sizeof(SensorData_t));
    xStatusQueue = xQueueCreate(1, sizeof(SystemStatus_t));
    xLogBuffer   = xMessageBufferCreate(LOG_BUFFER_SIZE);

    /* Create timers */
    xHeartbeatTimer = xTimerCreate("HB", pdMS_TO_TICKS(500), pdTRUE,
                                    NULL, vHeartbeatCallback);
    xInactivityTimer = xTimerCreate("Inact", pdMS_TO_TICKS(INACTIVITY_TIMEOUT_MS),
                                     pdFALSE, NULL, vInactivityCallback);

    /* Create application tasks
     *
     * Priority assignment rationale:
     *   5: Watchdog — must always run to detect failures
     *   4: Sensor — precise timing for data acquisition
     *   3: Processing — must keep up with sensor data rate
     *   2: Display, WiFi — user-facing but less time-critical
     *   1: Monitor, LogDrain — background diagnostics
     *   0: Idle (created by kernel)
     */
    xTaskCreate(vSensorTask,     "Sensor",  256, NULL, 4, &xSensorTaskHandle);
    xTaskCreate(vProcessingTask, "Process", 256, NULL, 3, &xProcessTaskHandle);
    xTaskCreate(vDisplayTask,    "Display", 256, NULL, 2, &xDisplayTaskHandle);
    xTaskCreate(vWifiTask,       "WiFi",    512, NULL, 2, &xWifiTaskHandle);
    xTaskCreate(vWatchdogTask,   "WDog",    256, NULL, 5, NULL);
    xTaskCreate(vMonitorTask,    "Monitor", 512, NULL, 1, NULL);
    xTaskCreate(vLogDrainTask,   "LogDrn",  256, NULL, 1, NULL);

    /* Start timers */
    xTimerStart(xHeartbeatTimer, 0);
    xTimerStart(xInactivityTimer, 0);

    uart_write("\r\n=== IoT Sensor Node Starting ===\r\n");
    uart_write("Starting FreeRTOS scheduler...\r\n\r\n");

    vTaskStartScheduler();

    uart_write("ERROR: Scheduler failed!\r\n");
    for (;;);
}
