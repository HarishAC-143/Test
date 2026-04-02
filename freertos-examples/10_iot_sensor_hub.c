/**
 * FreeRTOS Example 10: Complete IoT Sensor Hub — Real-World Project
 *
 * A production-quality embedded application demonstrating how all FreeRTOS
 * primitives work together in a realistic system.
 *
 * System Architecture:
 *
 *   ┌──────────────┐    Queue     ┌─────────────────┐
 *   │ Sensor Tasks │ ──────────── │  Data Processor  │
 *   │ (3x periodic)│              │  (filtering,     │
 *   └──────────────┘              │   aggregation)   │
 *          │                      └────────┬─────────┘
 *          │                               │
 *   Event Group                    Notification
 *          │                               │
 *          ▼                               ▼
 *   ┌──────────────┐              ┌─────────────────┐
 *   │ System       │              │  MQTT Publisher  │
 *   │ Supervisor   │              │  (cloud upload)  │
 *   └──────────────┘              └─────────────────┘
 *          │                               │
 *       Mutex                        Msg Buffer
 *          │                               │
 *          ▼                               ▼
 *   ┌──────────────┐              ┌─────────────────┐
 *   │ Display Task │              │  Logger Task     │
 *   │ (LCD update) │              │  (serial output) │
 *   └──────────────┘              └─────────────────┘
 *          │
 *    Software Timer
 *          │
 *          ▼
 *   ┌──────────────┐
 *   │ Watchdog &   │
 *   │ Heartbeat    │
 *   └──────────────┘
 *
 * FreeRTOS primitives used:
 *   - Tasks (7 tasks at different priorities)
 *   - Queue (sensor readings pipeline)
 *   - Mutex (shared display resource)
 *   - Event Group (system-wide state flags)
 *   - Task Notifications (lightweight data-ready signal)
 *   - Software Timer (heartbeat LED, watchdog feeding)
 *   - Message Buffer (variable-length log messages)
 *   - Counting Semaphore (connection pool)
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "timers.h"
#include "message_buffer.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Hardware Abstraction Layer (Simulated)                                    */
/* ──────────────────────────────────────────────────────────────────────────── */

static void hal_uart_transmit(const char *data, uint16_t len) {
    (void)data; (void)len;
}

static void hal_gpio_toggle(uint8_t pin) { (void)pin; }
static void hal_gpio_write(uint8_t pin, uint8_t val) { (void)pin; (void)val; }

static float hal_adc_read_temperature(void) {
    static float t = 22.0f;
    t += 0.1f;
    if (t > 35.0f) t = 18.0f;
    return t;
}

static float hal_adc_read_humidity(void) {
    static float h = 50.0f;
    h += 0.3f;
    if (h > 90.0f) h = 30.0f;
    return h;
}

static float hal_i2c_read_pressure(void) {
    static float p = 1013.25f;
    p -= 0.05f;
    if (p < 990.0f) p = 1020.0f;
    return p;
}

static int hal_wifi_send(const uint8_t *data, uint16_t len) {
    (void)data; (void)len;
    return 0; /* 0 = success */
}

static void hal_lcd_write(uint8_t row, uint8_t col, const char *text) {
    (void)row; (void)col; (void)text;
}

static void hal_iwdg_refresh(void) { /* Feed hardware watchdog */ }

/* ──────────────────────────────────────────────────────────────────────────── */
/*  System Configuration                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

#define SENSOR_QUEUE_DEPTH       16
#define LOG_BUFFER_SIZE          1024
#define MQTT_CONNECTION_SLOTS    2

/* Task priorities */
#define PRIO_SENSOR              3
#define PRIO_PROCESSOR           4
#define PRIO_MQTT                3
#define PRIO_DISPLAY             2
#define PRIO_LOGGER              2
#define PRIO_SUPERVISOR          5

/* Pin assignments */
#define PIN_LED_HEARTBEAT        13
#define PIN_LED_STATUS           14
#define PIN_LED_ERROR            15

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Data Types                                                                */
/* ──────────────────────────────────────────────────────────────────────────── */

typedef enum {
    SENSOR_TEMP,
    SENSOR_HUMIDITY,
    SENSOR_PRESSURE,
    SENSOR_COUNT
} SensorId_t;

typedef struct {
    SensorId_t eSensorId;
    float      fRawValue;
    float      fFilteredValue;
    TickType_t xTimestamp;
    uint8_t    ucQuality;  /* 0-100, signal quality indicator */
} SensorReading_t;

typedef struct {
    float    fValues[SENSOR_COUNT];
    float    fMinValues[SENSOR_COUNT];
    float    fMaxValues[SENSOR_COUNT];
    uint32_t ulReadingCount[SENSOR_COUNT];
    TickType_t xLastUpdate;
} ProcessedData_t;

typedef struct {
    uint8_t  ucLevel;   /* 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR */
    char     cSource[8];
    char     cMessage[80];
} LogEntry_t;

/* ──────────────────────────────────────────────────────────────────────────── */
/*  System Event Flags                                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

#define EVT_SENSORS_READY      (1 << 0)
#define EVT_WIFI_CONNECTED     (1 << 1)
#define EVT_MQTT_CONNECTED     (1 << 2)
#define EVT_SYSTEM_RUNNING     (1 << 3)
#define EVT_ERROR_DETECTED     (1 << 4)
#define EVT_LOW_BATTERY        (1 << 5)
#define EVT_ALL_INIT           (EVT_SENSORS_READY | EVT_WIFI_CONNECTED | EVT_MQTT_CONNECTED)

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Kernel Objects (Global)                                                   */
/* ──────────────────────────────────────────────────────────────────────────── */

static QueueHandle_t          xSensorQueue;
static SemaphoreHandle_t      xDisplayMutex;
static EventGroupHandle_t     xSystemEvents;
static MessageBufferHandle_t  xLogBuffer;
static SemaphoreHandle_t      xMQTTConnPool;
static TimerHandle_t          xHeartbeatTimer;
static TimerHandle_t          xWatchdogTimer;

static TaskHandle_t           xProcessorTaskHandle;
static TaskHandle_t           xMQTTTaskHandle;

static ProcessedData_t        xSharedProcessedData;

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Logging System (Message Buffer)                                           */
/* ──────────────────────────────────────────────────────────────────────────── */

static void sys_log(uint8_t level, const char *source, const char *fmt, ...) {
    LogEntry_t xEntry;
    xEntry.ucLevel = level;
    strncpy(xEntry.cSource, source, sizeof(xEntry.cSource) - 1);
    xEntry.cSource[sizeof(xEntry.cSource) - 1] = '\0';

    va_list args;
    va_start(args, fmt);
    vsnprintf(xEntry.cMessage, sizeof(xEntry.cMessage), fmt, args);
    va_end(args);

    /* Non-blocking send — drop message if buffer full */
    xMessageBufferSend(xLogBuffer, &xEntry, sizeof(xEntry), 0);
}

#define LOG_DEBUG(src, ...) sys_log(0, src, __VA_ARGS__)
#define LOG_INFO(src, ...)  sys_log(1, src, __VA_ARGS__)
#define LOG_WARN(src, ...)  sys_log(2, src, __VA_ARGS__)
#define LOG_ERROR(src, ...) sys_log(3, src, __VA_ARGS__)

/* ──────────────────────────────────────────────────────────────────────────── */
/*  1. Sensor Tasks (Producers)                                               */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Each sensor runs in its own task at the same priority.
 * They sample at different rates and send readings through the shared queue.
 *
 * Uses xTaskDelayUntil for precise periodic timing.
 */

/* Exponential Moving Average filter */
static float ema_filter(float fNewSample, float fPrevFiltered, float fAlpha) {
    return fAlpha * fNewSample + (1.0f - fAlpha) * fPrevFiltered;
}

static void vTemperatureSensorTask(void *pvParameters) {
    (void)pvParameters;
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xPeriod = pdMS_TO_TICKS(500); /* 2 Hz sampling */
    SensorReading_t xReading;
    float fFiltered = 22.0f;

    LOG_INFO("TEMP", "Temperature sensor initialized");

    for (;;) {
        float fRaw = hal_adc_read_temperature();
        fFiltered = ema_filter(fRaw, fFiltered, 0.3f);

        xReading.eSensorId     = SENSOR_TEMP;
        xReading.fRawValue     = fRaw;
        xReading.fFilteredValue = fFiltered;
        xReading.xTimestamp    = xTaskGetTickCount();
        xReading.ucQuality     = 95;

        if (xQueueSend(xSensorQueue, &xReading, pdMS_TO_TICKS(50)) != pdPASS) {
            LOG_WARN("TEMP", "Queue full, reading dropped");
        }

        xTaskDelayUntil(&xLastWakeTime, xPeriod);
    }
}

static void vHumiditySensorTask(void *pvParameters) {
    (void)pvParameters;
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xPeriod = pdMS_TO_TICKS(1000); /* 1 Hz */
    SensorReading_t xReading;
    float fFiltered = 50.0f;

    LOG_INFO("HUM", "Humidity sensor initialized");

    for (;;) {
        float fRaw = hal_adc_read_humidity();
        fFiltered = ema_filter(fRaw, fFiltered, 0.2f);

        xReading.eSensorId     = SENSOR_HUMIDITY;
        xReading.fRawValue     = fRaw;
        xReading.fFilteredValue = fFiltered;
        xReading.xTimestamp    = xTaskGetTickCount();
        xReading.ucQuality     = 90;

        xQueueSend(xSensorQueue, &xReading, pdMS_TO_TICKS(50));
        xTaskDelayUntil(&xLastWakeTime, xPeriod);
    }
}

static void vPressureSensorTask(void *pvParameters) {
    (void)pvParameters;
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xPeriod = pdMS_TO_TICKS(2000); /* 0.5 Hz */
    SensorReading_t xReading;
    float fFiltered = 1013.25f;

    LOG_INFO("PRES", "Pressure sensor initialized");

    for (;;) {
        float fRaw = hal_i2c_read_pressure();
        fFiltered = ema_filter(fRaw, fFiltered, 0.1f);

        xReading.eSensorId     = SENSOR_PRESSURE;
        xReading.fRawValue     = fRaw;
        xReading.fFilteredValue = fFiltered;
        xReading.xTimestamp    = xTaskGetTickCount();
        xReading.ucQuality     = 85;

        xQueueSend(xSensorQueue, &xReading, pdMS_TO_TICKS(50));
        xTaskDelayUntil(&xLastWakeTime, xPeriod);
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  2. Data Processor Task (Consumer + Aggregation)                           */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Consumes sensor readings from the queue, updates shared processed data
 * (protected by mutex), and notifies the MQTT publisher when new data
 * is ready.
 */

static void vDataProcessorTask(void *pvParameters) {
    (void)pvParameters;
    SensorReading_t xReading;
    const char *pcSensorNames[] = {"Temp", "Humidity", "Pressure"};

    LOG_INFO("PROC", "Data processor started");

    /* Signal that sensors are ready */
    xEventGroupSetBits(xSystemEvents, EVT_SENSORS_READY);

    for (;;) {
        if (xQueueReceive(xSensorQueue, &xReading, portMAX_DELAY) == pdPASS) {
            uint8_t ucId = (uint8_t)xReading.eSensorId;
            if (ucId >= SENSOR_COUNT) continue;

            /* Update shared data with mutex protection */
            xSemaphoreTake(xDisplayMutex, portMAX_DELAY);

            xSharedProcessedData.fValues[ucId] = xReading.fFilteredValue;
            xSharedProcessedData.ulReadingCount[ucId]++;
            xSharedProcessedData.xLastUpdate = xReading.xTimestamp;

            /* Update min/max */
            if (xSharedProcessedData.ulReadingCount[ucId] == 1) {
                xSharedProcessedData.fMinValues[ucId] = xReading.fFilteredValue;
                xSharedProcessedData.fMaxValues[ucId] = xReading.fFilteredValue;
            } else {
                if (xReading.fFilteredValue < xSharedProcessedData.fMinValues[ucId])
                    xSharedProcessedData.fMinValues[ucId] = xReading.fFilteredValue;
                if (xReading.fFilteredValue > xSharedProcessedData.fMaxValues[ucId])
                    xSharedProcessedData.fMaxValues[ucId] = xReading.fFilteredValue;
            }

            xSemaphoreGive(xDisplayMutex);

            /* Anomaly detection */
            if (xReading.eSensorId == SENSOR_TEMP && xReading.fFilteredValue > 30.0f) {
                LOG_WARN("PROC", "%s high: %.1f", pcSensorNames[ucId],
                          xReading.fFilteredValue);
                xEventGroupSetBits(xSystemEvents, EVT_ERROR_DETECTED);
            }

            /* Notify MQTT publisher that new data is available */
            if (xMQTTTaskHandle != NULL) {
                xTaskNotify(xMQTTTaskHandle,
                            (uint32_t)(1 << ucId), eSetBits);
            }

            LOG_DEBUG("PROC", "%s: raw=%.2f filt=%.2f q=%u",
                       pcSensorNames[ucId], xReading.fRawValue,
                       xReading.fFilteredValue, xReading.ucQuality);
        }
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  3. MQTT Publisher Task                                                    */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Waits for data-ready notifications, acquires a connection from the pool,
 * and publishes aggregated sensor data to the cloud.
 *
 * Uses:
 *   - Task Notifications (data-ready signal from processor)
 *   - Counting Semaphore (connection pool)
 *   - Mutex (reading shared data)
 *   - Event Group (checking system state)
 */

static void vMQTTPublisherTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulNotifiedValue;

    LOG_INFO("MQTT", "Publisher waiting for system init...");

    /* Wait for all initialization to complete */
    xEventGroupWaitBits(xSystemEvents, EVT_ALL_INIT, pdFALSE, pdTRUE, portMAX_DELAY);

    LOG_INFO("MQTT", "System initialized, starting publish loop");

    for (;;) {
        /* Wait for data-ready notification from the processor */
        if (xTaskNotifyWait(0, 0xFFFFFFFF, &ulNotifiedValue,
                            pdMS_TO_TICKS(5000)) == pdPASS) {

            /* Acquire a connection slot from the pool */
            if (xSemaphoreTake(xMQTTConnPool, pdMS_TO_TICKS(1000)) == pdPASS) {

                /* Read shared data snapshot under mutex */
                ProcessedData_t xSnapshot;
                xSemaphoreTake(xDisplayMutex, portMAX_DELAY);
                memcpy(&xSnapshot, &xSharedProcessedData, sizeof(xSnapshot));
                xSemaphoreGive(xDisplayMutex);

                /* Format and publish */
                char cPayload[128];
                snprintf(cPayload, sizeof(cPayload),
                    "{\"temp\":%.1f,\"hum\":%.1f,\"pres\":%.1f,\"ts\":%lu}",
                    xSnapshot.fValues[SENSOR_TEMP],
                    xSnapshot.fValues[SENSOR_HUMIDITY],
                    xSnapshot.fValues[SENSOR_PRESSURE],
                    (unsigned long)xSnapshot.xLastUpdate);

                int result = hal_wifi_send((uint8_t *)cPayload, (uint16_t)strlen(cPayload));

                if (result == 0) {
                    LOG_INFO("MQTT", "Published: %s", cPayload);
                } else {
                    LOG_ERROR("MQTT", "Publish failed (err=%d)", result);
                }

                /* Release connection slot */
                xSemaphoreGive(xMQTTConnPool);
            } else {
                LOG_WARN("MQTT", "No connection slot available");
            }
        } else {
            LOG_DEBUG("MQTT", "No new data (timeout)");
        }
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  4. Display Task                                                           */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Periodically reads the shared processed data and updates the LCD.
 * Protected by mutex to ensure data consistency.
 */

static void vDisplayTask(void *pvParameters) {
    (void)pvParameters;
    char cLine[32];

    LOG_INFO("DISP", "Display task started");

    for (;;) {
        ProcessedData_t xSnapshot;

        xSemaphoreTake(xDisplayMutex, portMAX_DELAY);
        memcpy(&xSnapshot, &xSharedProcessedData, sizeof(xSnapshot));
        xSemaphoreGive(xDisplayMutex);

        /* Update LCD rows */
        snprintf(cLine, sizeof(cLine), "T: %5.1f C", xSnapshot.fValues[SENSOR_TEMP]);
        hal_lcd_write(0, 0, cLine);

        snprintf(cLine, sizeof(cLine), "H: %5.1f %%", xSnapshot.fValues[SENSOR_HUMIDITY]);
        hal_lcd_write(1, 0, cLine);

        snprintf(cLine, sizeof(cLine), "P: %6.1f hPa", xSnapshot.fValues[SENSOR_PRESSURE]);
        hal_lcd_write(2, 0, cLine);

        /* Status line */
        EventBits_t uxStatus = xEventGroupGetBits(xSystemEvents);
        snprintf(cLine, sizeof(cLine), "%s %s %s",
                 (uxStatus & EVT_WIFI_CONNECTED) ? "WiFi" : "----",
                 (uxStatus & EVT_MQTT_CONNECTED) ? "MQTT" : "----",
                 (uxStatus & EVT_ERROR_DETECTED) ? "ERR!" : "  OK");
        hal_lcd_write(3, 0, cLine);

        vTaskDelay(pdMS_TO_TICKS(250));
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  5. Logger Task (Message Buffer Consumer)                                  */
/* ──────────────────────────────────────────────────────────────────────────── */

static void vLoggerTask(void *pvParameters) {
    (void)pvParameters;
    LogEntry_t xEntry;
    const char *pcLevelStr[] = {"DBG", "INF", "WRN", "ERR"};
    char cOutput[128];

    for (;;) {
        size_t xBytes = xMessageBufferReceive(xLogBuffer, &xEntry,
                                               sizeof(xEntry), portMAX_DELAY);
        if (xBytes > 0) {
            uint8_t ucLevel = xEntry.ucLevel < 4 ? xEntry.ucLevel : 0;
            int len = snprintf(cOutput, sizeof(cOutput),
                "[%lu][%s][%s] %s\r\n",
                (unsigned long)xTaskGetTickCount(),
                pcLevelStr[ucLevel],
                xEntry.cSource,
                xEntry.cMessage);

            hal_uart_transmit(cOutput, (uint16_t)len);
        }
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  6. System Supervisor Task                                                 */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * The supervisor monitors system health: stack usage, heap state,
 * error flags, and task responsiveness.
 */

static void vSupervisorTask(void *pvParameters) {
    (void)pvParameters;

    /* Simulate WiFi and MQTT connection */
    vTaskDelay(pdMS_TO_TICKS(1000));
    LOG_INFO("SUP", "WiFi connected");
    xEventGroupSetBits(xSystemEvents, EVT_WIFI_CONNECTED);

    vTaskDelay(pdMS_TO_TICKS(500));
    LOG_INFO("SUP", "MQTT connected");
    xEventGroupSetBits(xSystemEvents, EVT_MQTT_CONNECTED);

    /* Set system running flag */
    xEventGroupSetBits(xSystemEvents, EVT_SYSTEM_RUNNING);
    LOG_INFO("SUP", "System fully operational");

    for (;;) {
        /* Monitor heap */
        size_t xFreeHeap    = xPortGetFreeHeapSize();
        size_t xMinFreeHeap = xPortGetMinimumEverFreeHeapSize();

        if (xFreeHeap < 2048) {
            LOG_ERROR("SUP", "CRITICAL: Free heap = %u bytes!", (unsigned)xFreeHeap);
        } else if (xMinFreeHeap < 4096) {
            LOG_WARN("SUP", "Low heap margin: min ever = %u bytes", (unsigned)xMinFreeHeap);
        }

        /* Monitor event group for errors */
        EventBits_t uxBits = xEventGroupGetBits(xSystemEvents);
        if (uxBits & EVT_ERROR_DETECTED) {
            hal_gpio_write(PIN_LED_ERROR, 1);
            LOG_WARN("SUP", "Error flag active, investigating...");

            /* Auto-clear error after handling */
            vTaskDelay(pdMS_TO_TICKS(5000));
            xEventGroupClearBits(xSystemEvents, EVT_ERROR_DETECTED);
            hal_gpio_write(PIN_LED_ERROR, 0);
            LOG_INFO("SUP", "Error cleared");
        }

        /* Report queue utilization */
        UBaseType_t uxQueueUsed = uxQueueMessagesWaiting(xSensorQueue);
        if (uxQueueUsed > SENSOR_QUEUE_DEPTH * 3 / 4) {
            LOG_WARN("SUP", "Sensor queue %lu/%d (near full)",
                      (unsigned long)uxQueueUsed, SENSOR_QUEUE_DEPTH);
        }

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  7. Software Timers — Heartbeat and Watchdog                               */
/* ──────────────────────────────────────────────────────────────────────────── */

static void vHeartbeatTimerCallback(TimerHandle_t xTimer) {
    (void)xTimer;
    hal_gpio_toggle(PIN_LED_HEARTBEAT);
}

static void vWatchdogTimerCallback(TimerHandle_t xTimer) {
    (void)xTimer;
    hal_iwdg_refresh();

    /* Additional software watchdog check: verify tasks are alive */
    EventBits_t uxBits = xEventGroupGetBits(xSystemEvents);
    if (!(uxBits & EVT_SYSTEM_RUNNING)) {
        LOG_ERROR("WDG", "System not running — watchdog detected issue");
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  System Initialization                                                     */
/* ──────────────────────────────────────────────────────────────────────────── */

static void create_kernel_objects(void) {
    /* Sensor data pipeline (queue) */
    xSensorQueue = xQueueCreate(SENSOR_QUEUE_DEPTH, sizeof(SensorReading_t));
    configASSERT(xSensorQueue != NULL);

    /* Display access mutex */
    xDisplayMutex = xSemaphoreCreateMutex();
    configASSERT(xDisplayMutex != NULL);

    /* System-wide event flags */
    xSystemEvents = xEventGroupCreate();
    configASSERT(xSystemEvents != NULL);

    /* Log message buffer */
    xLogBuffer = xMessageBufferCreate(LOG_BUFFER_SIZE);
    configASSERT(xLogBuffer != NULL);

    /* MQTT connection pool (2 concurrent connections max) */
    xMQTTConnPool = xSemaphoreCreateCounting(MQTT_CONNECTION_SLOTS, MQTT_CONNECTION_SLOTS);
    configASSERT(xMQTTConnPool != NULL);

    /* Heartbeat LED timer (500 ms toggle = 1 Hz blink) */
    xHeartbeatTimer = xTimerCreate("Heartbeat", pdMS_TO_TICKS(500),
                                    pdTRUE, NULL, vHeartbeatTimerCallback);
    configASSERT(xHeartbeatTimer != NULL);

    /* Watchdog refresh timer (200 ms, well within typical IWDG timeout) */
    xWatchdogTimer = xTimerCreate("Watchdog", pdMS_TO_TICKS(200),
                                   pdTRUE, NULL, vWatchdogTimerCallback);
    configASSERT(xWatchdogTimer != NULL);
}

static void create_tasks(void) {
    /* Sensor tasks — same priority, each with its own sampling rate */
    xTaskCreate(vTemperatureSensorTask, "TempSns",   256, NULL, PRIO_SENSOR,    NULL);
    xTaskCreate(vHumiditySensorTask,    "HumSns",    256, NULL, PRIO_SENSOR,    NULL);
    xTaskCreate(vPressureSensorTask,    "PresSns",   256, NULL, PRIO_SENSOR,    NULL);

    /* Data processor — higher priority than sensors to keep queue drained */
    xTaskCreate(vDataProcessorTask, "DataProc", 512, NULL, PRIO_PROCESSOR, &xProcessorTaskHandle);

    /* MQTT publisher */
    xTaskCreate(vMQTTPublisherTask, "MQTT", 512, NULL, PRIO_MQTT, &xMQTTTaskHandle);

    /* Display updater */
    xTaskCreate(vDisplayTask, "Display", 256, NULL, PRIO_DISPLAY, NULL);

    /* Serial logger */
    xTaskCreate(vLoggerTask, "Logger", 512, NULL, PRIO_LOGGER, NULL);

    /* System supervisor — highest application priority */
    xTaskCreate(vSupervisorTask, "Supervisor", 512, NULL, PRIO_SUPERVISOR, NULL);
}

static void start_timers(void) {
    xTimerStart(xHeartbeatTimer, 0);
    xTimerStart(xWatchdogTimer, 0);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Required FreeRTOS Hooks                                                   */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) {
    /* Enter low-power sleep until next interrupt */
    /* __WFI(); */
}

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask;
    /* Can't use LOG_ macros here — the stack is already corrupted */
    hal_gpio_write(PIN_LED_ERROR, 1);

    /* Spin forever — debugger will show pcTaskName */
    volatile const char *pName = pcTaskName;
    (void)pName;
    for (;;) { }
}

void vApplicationMallocFailedHook(void) {
    hal_gpio_write(PIN_LED_ERROR, 1);
    for (;;) { }
}

#if (configSUPPORT_STATIC_ALLOCATION == 1)
static StaticTask_t xIdleTCB;
static StackType_t  xIdleStack[configMINIMAL_STACK_SIZE];
void vApplicationGetIdleTaskMemory(StaticTask_t **ppxIdleTaskTCBBuffer,
                                   StackType_t **ppxIdleTaskStackBuffer,
                                   uint32_t *pulIdleTaskStackSize) {
    *ppxIdleTaskTCBBuffer   = &xIdleTCB;
    *ppxIdleTaskStackBuffer = xIdleStack;
    *pulIdleTaskStackSize   = configMINIMAL_STACK_SIZE;
}

static StaticTask_t xTimerTCB;
static StackType_t  xTimerStack[configTIMER_TASK_STACK_DEPTH];
void vApplicationGetTimerTaskMemory(StaticTask_t **ppxTimerTaskTCBBuffer,
                                    StackType_t **ppxTimerTaskStackBuffer,
                                    uint32_t *pulTimerTaskStackSize) {
    *ppxTimerTaskTCBBuffer   = &xTimerTCB;
    *ppxTimerTaskStackBuffer = xTimerStack;
    *pulTimerTaskStackSize   = configTIMER_TASK_STACK_DEPTH;
}
#endif

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main Entry Point                                                          */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Application startup sequence:
 *   1. Initialize hardware (clocks, peripherals)
 *   2. Create all kernel objects (queues, semaphores, timers, etc.)
 *   3. Create all tasks
 *   4. Start timers
 *   5. Start the scheduler (never returns)
 *
 * This order ensures all objects exist before any task tries to use them.
 * The scheduler is started LAST, after everything is set up.
 */

int main(void) {
    /* 1. Hardware initialization (platform-specific) */
    /* SystemClock_Config(); */
    /* HAL_Init(); */
    /* GPIO_Init(); */
    /* UART_Init(); */
    /* I2C_Init(); */
    /* ADC_Init(); */
    /* LCD_Init(); */
    /* WiFi_Init(); */
    /* IWDG_Init(); */

    /* 2. Create all FreeRTOS kernel objects */
    create_kernel_objects();

    /* 3. Create all application tasks */
    create_tasks();

    /* 4. Start software timers */
    start_timers();

    /* Initialize shared data */
    memset(&xSharedProcessedData, 0, sizeof(xSharedProcessedData));

    /* 5. Start the scheduler — this call never returns */
    vTaskStartScheduler();

    /* Execution only reaches here if scheduler fails */
    for (;;) {
        hal_gpio_toggle(PIN_LED_ERROR);
        volatile uint32_t i;
        for (i = 0; i < 1000000; i++) { }
    }

    return 0;
}
