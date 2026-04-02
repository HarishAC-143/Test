/*
 * FreeRTOS Complete IoT Sensor Monitoring Application
 *
 * A production-style application that ties together all major FreeRTOS
 * primitives into a cohesive embedded IoT sensor monitoring system.
 *
 * Architecture:
 *   ┌──────────┐  Queue   ┌────────────┐  Notify   ┌──────────┐
 *   │ Sensor   │ ───────► │ Data       │ ────────► │ Display  │
 *   │ Tasks    │          │ Aggregator │           │ Task     │
 *   └──────────┘          └─────┬──────┘           └──────────┘
 *                               │ MsgBuf
 *                               ▼
 *                         ┌────────────┐
 *                         │ Comm       │  ← Mutex protects radio
 *                         │ Manager    │
 *                         └─────┬──────┘
 *                               │
 *                         ┌─────▼──────┐
 *                         │ Logger     │  ← StreamBuffer
 *                         │ Task       │
 *                         └────────────┘
 *
 * FreeRTOS primitives used:
 *   - Tasks (xTaskCreate, static tasks, priorities)
 *   - Queues (sensor data pipeline)
 *   - Mutex (shared SPI bus, shared radio)
 *   - Binary semaphore (ISR sync)
 *   - Counting semaphore (resource pool)
 *   - Event group (system state, startup sync)
 *   - Software timers (watchdog, heartbeat, telemetry)
 *   - Task notifications (display update trigger)
 *   - Stream buffer (log output)
 *   - Message buffer (telemetry packets)
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10.x/v11.x
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "event_groups.h"
#include "timers.h"
#include "stream_buffer.h"
#include "message_buffer.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdarg.h>

/* =====================================================================
 * Hardware Abstraction (Stubs)
 * ===================================================================== */

static inline void HAL_Init(void) {}
static inline void SystemClock_Config(void) {}

static volatile uint32_t uptime_seconds = 0;
static volatile uint32_t sim_counter = 0;

static float sim_temperature(void) { return 22.0f + (float)(sim_counter++ % 80) * 0.1f; }
static float sim_humidity(void)    { return 40.0f + (float)(sim_counter % 40) * 0.5f; }
static float sim_pressure(void)    { return 1010.0f + (float)(sim_counter % 60) * 0.2f; }
static float sim_light(void)       { return 100.0f + (float)(sim_counter % 900); }
static float sim_battery(void)     { return 3.7f - (float)(uptime_seconds % 100) * 0.005f; }

static volatile uint32_t gpio_odr = 0;
static void led_set(uint32_t pin, uint32_t on) {
    if (on) gpio_odr |= (1U << pin);
    else    gpio_odr &= ~(1U << pin);
}
static void led_toggle(uint32_t pin) { gpio_odr ^= (1U << pin); }

#define LED_STATUS    12
#define LED_ERROR     14
#define LED_COMM      15

/* =====================================================================
 * System Configuration
 * ===================================================================== */

#define SENSOR_QUEUE_DEPTH      16
#define TELEMETRY_MSG_BUF_SIZE  512
#define LOG_STREAM_BUF_SIZE     1024
#define MAX_SENSOR_CHANNELS     4

/* Task priorities */
#define PRIO_SENSOR         3
#define PRIO_AGGREGATOR     4
#define PRIO_COMM           3
#define PRIO_DISPLAY        2
#define PRIO_LOGGER         1
#define PRIO_WATCHDOG       5
#define PRIO_MONITOR        1

/* Event group bits — system state */
#define SYS_EVT_SENSORS_READY   (1 << 0)
#define SYS_EVT_COMM_READY      (1 << 1)
#define SYS_EVT_DISPLAY_READY   (1 << 2)
#define SYS_EVT_LOGGER_READY    (1 << 3)
#define SYS_EVT_ALL_READY       (SYS_EVT_SENSORS_READY | SYS_EVT_COMM_READY | \
                                  SYS_EVT_DISPLAY_READY | SYS_EVT_LOGGER_READY)
#define SYS_EVT_LOW_BATTERY     (1 << 4)
#define SYS_EVT_SENSOR_ALARM    (1 << 5)
#define SYS_EVT_COMM_ERROR      (1 << 6)

/* =====================================================================
 * Data Types
 * ===================================================================== */

typedef enum {
    SENSOR_TEMPERATURE = 0,
    SENSOR_HUMIDITY,
    SENSOR_PRESSURE,
    SENSOR_LIGHT,
    SENSOR_TYPE_COUNT
} SensorType_t;

typedef struct {
    SensorType_t type;
    float        value;
    uint32_t     timestamp;
    uint8_t      quality;     /* 0-100 signal quality */
} SensorReading_t;

typedef struct {
    float    values[SENSOR_TYPE_COUNT];
    float    min_values[SENSOR_TYPE_COUNT];
    float    max_values[SENSOR_TYPE_COUNT];
    uint32_t sample_counts[SENSOR_TYPE_COUNT];
    uint32_t last_update[SENSOR_TYPE_COUNT];
    float    battery_voltage;
    uint32_t uptime;
} SystemState_t;

typedef struct {
    uint8_t  msg_type;      /* 0=telemetry, 1=alarm, 2=status */
    uint32_t timestamp;
    uint8_t  payload_len;
    uint8_t  payload[48];
} TelemetryPacket_t;

/* =====================================================================
 * Global Kernel Objects
 * ===================================================================== */

static QueueHandle_t         xSensorQueue;
static SemaphoreHandle_t     xRadioMutex;
static SemaphoreHandle_t     xAdcSem;
static EventGroupHandle_t    xSystemEvents;
static StreamBufferHandle_t  xLogStream;
static MessageBufferHandle_t xTelemetryBuf;
static TimerHandle_t         xHeartbeatTimer;
static TimerHandle_t         xWatchdogTimer;
static TimerHandle_t         xTelemetryTimer;

static TaskHandle_t xDisplayTaskHandle;
static TaskHandle_t xCommTaskHandle;

static SystemState_t g_system_state;
static SemaphoreHandle_t xStateMutex;

/* =====================================================================
 * Logging Subsystem (Stream Buffer)
 * ===================================================================== */

static void sys_log(const char *fmt, ...)
{
    char buf[128];
    va_list args;
    va_start(args, fmt);
    int len = vsnprintf(buf, sizeof(buf) - 2, fmt, args);
    va_end(args);

    if (len > 0) {
        buf[len++] = '\n';
        buf[len] = '\0';
        xStreamBufferSend(xLogStream, buf, len, pdMS_TO_TICKS(5));
    }
}

static void vLoggerTask(void *pv)
{
    char buf[128];

    xEventGroupSetBits(xSystemEvents, SYS_EVT_LOGGER_READY);

    for (;;) {
        size_t received = xStreamBufferReceive(xLogStream, buf, sizeof(buf) - 1,
                                                portMAX_DELAY);
        if (received > 0) {
            buf[received] = '\0';
            printf("[LOG] %s", buf);
        }
    }
}

/* =====================================================================
 * FreeRTOS Hooks
 * ===================================================================== */

void vApplicationMallocFailedHook(void)
{
    printf("[FATAL] Malloc failed!\r\n");
    for (;;);
}

void vApplicationStackOverflowHook(TaskHandle_t t, char *name)
{
    printf("[FATAL] Stack overflow: %s\r\n", name);
    for (;;);
}

void vApplicationIdleHook(void) {}

/* =====================================================================
 * Sensor Tasks (Multiple instances, parameterized)
 * ===================================================================== */

typedef struct {
    SensorType_t type;
    const char  *name;
    uint32_t     period_ms;
    float        alarm_low;
    float        alarm_high;
} SensorConfig_t;

static const SensorConfig_t sensor_configs[SENSOR_TYPE_COUNT] = {
    { SENSOR_TEMPERATURE, "Temp",  500,   -10.0f,  50.0f  },
    { SENSOR_HUMIDITY,    "Hum",   1000,   10.0f,  95.0f  },
    { SENSOR_PRESSURE,    "Press", 2000,  950.0f, 1050.0f },
    { SENSOR_LIGHT,       "Light", 250,     0.0f, 1000.0f },
};

static float read_sensor_value(SensorType_t type)
{
    switch (type) {
        case SENSOR_TEMPERATURE: return sim_temperature();
        case SENSOR_HUMIDITY:    return sim_humidity();
        case SENSOR_PRESSURE:    return sim_pressure();
        case SENSOR_LIGHT:       return sim_light();
        default:                 return 0.0f;
    }
}

static void vSensorTask(void *pv)
{
    const SensorConfig_t *cfg = (const SensorConfig_t *)pv;
    TickType_t xLastWake = xTaskGetTickCount();
    TickType_t period = pdMS_TO_TICKS(cfg->period_ms);

    sys_log("[%s] Sensor initialized (period=%lums)", cfg->name, cfg->period_ms);

    for (;;) {
        xTaskDelayUntil(&xLastWake, period);

        float value = read_sensor_value(cfg->type);

        SensorReading_t reading = {
            .type      = cfg->type,
            .value     = value,
            .timestamp = (uint32_t)xTaskGetTickCount(),
            .quality   = 95
        };

        if (xQueueSend(xSensorQueue, &reading, pdMS_TO_TICKS(50)) != pdPASS) {
            sys_log("[%s] Queue full — sample dropped", cfg->name);
        }

        if (value < cfg->alarm_low || value > cfg->alarm_high) {
            sys_log("[%s] ALARM: %.2f outside [%.1f, %.1f]",
                    cfg->name, (double)value,
                    (double)cfg->alarm_low, (double)cfg->alarm_high);
            xEventGroupSetBits(xSystemEvents, SYS_EVT_SENSOR_ALARM);
        }
    }
}

/* =====================================================================
 * Data Aggregator Task
 *
 * Receives sensor readings from the queue, updates the system state,
 * and notifies the display and communication tasks.
 * ===================================================================== */

static void vAggregatorTask(void *pv)
{
    sys_log("[Aggregator] Started");
    uint32_t total_readings = 0;

    for (;;) {
        SensorReading_t reading;

        if (xQueueReceive(xSensorQueue, &reading, portMAX_DELAY) == pdPASS) {
            total_readings++;

            xSemaphoreTake(xStateMutex, portMAX_DELAY);
            {
                SensorType_t t = reading.type;
                g_system_state.values[t] = reading.value;
                g_system_state.last_update[t] = reading.timestamp;
                g_system_state.sample_counts[t]++;

                if (g_system_state.sample_counts[t] == 1) {
                    g_system_state.min_values[t] = reading.value;
                    g_system_state.max_values[t] = reading.value;
                } else {
                    if (reading.value < g_system_state.min_values[t])
                        g_system_state.min_values[t] = reading.value;
                    if (reading.value > g_system_state.max_values[t])
                        g_system_state.max_values[t] = reading.value;
                }

                g_system_state.battery_voltage = sim_battery();
                g_system_state.uptime = uptime_seconds;
            }
            xSemaphoreGive(xStateMutex);

            if (g_system_state.battery_voltage < 3.3f) {
                xEventGroupSetBits(xSystemEvents, SYS_EVT_LOW_BATTERY);
            }

            /* Notify display task that new data is available */
            if (xDisplayTaskHandle != NULL) {
                xTaskNotify(xDisplayTaskHandle, (1U << reading.type), eSetBits);
            }

            if ((total_readings % 100) == 0) {
                sys_log("[Aggregator] %lu total readings processed", total_readings);
            }
        }
    }
}

/* =====================================================================
 * Display Task (Notification-Driven)
 *
 * Wakes up when notified by the aggregator. Reads system state
 * and formats it for a display (simulated via printf).
 * ===================================================================== */

static const char *sensor_name(SensorType_t t)
{
    switch (t) {
        case SENSOR_TEMPERATURE: return "Temp";
        case SENSOR_HUMIDITY:    return "Hum";
        case SENSOR_PRESSURE:    return "Press";
        case SENSOR_LIGHT:       return "Light";
        default:                 return "?";
    }
}

static const char *sensor_unit(SensorType_t t)
{
    switch (t) {
        case SENSOR_TEMPERATURE: return "C";
        case SENSOR_HUMIDITY:    return "%";
        case SENSOR_PRESSURE:    return "hPa";
        case SENSOR_LIGHT:       return "lux";
        default:                 return "";
    }
}

static void vDisplayTask(void *pv)
{
    xEventGroupSetBits(xSystemEvents, SYS_EVT_DISPLAY_READY);
    sys_log("[Display] Ready");
    uint32_t refresh = 0;

    for (;;) {
        uint32_t ulNotified;

        if (xTaskNotifyWait(0, 0xFFFFFFFF, &ulNotified, pdMS_TO_TICKS(2000)) == pdTRUE) {
            refresh++;

            if ((refresh % 20) == 0) {
                SystemState_t state;

                xSemaphoreTake(xStateMutex, portMAX_DELAY);
                state = g_system_state;
                xSemaphoreGive(xStateMutex);

                printf("\r\n╔══════════════ IoT Dashboard ══════════════╗\r\n");
                printf("║ Uptime: %lu s    Battery: %.2f V           ║\r\n",
                       state.uptime, (double)state.battery_voltage);
                printf("╠═══════════════════════════════════════════╣\r\n");

                for (int t = 0; t < SENSOR_TYPE_COUNT; t++) {
                    printf("║ %-5s: %8.2f %-4s  [%7.2f .. %7.2f] ║\r\n",
                           sensor_name(t),
                           (double)state.values[t], sensor_unit(t),
                           (double)state.min_values[t],
                           (double)state.max_values[t]);
                }

                EventBits_t evts = xEventGroupGetBits(xSystemEvents);
                printf("╠═══════════════════════════════════════════╣\r\n");
                printf("║ Alarms: %s%s%s%s                          ║\r\n",
                       (evts & SYS_EVT_LOW_BATTERY)  ? "LOW_BAT " : "",
                       (evts & SYS_EVT_SENSOR_ALARM) ? "SENSOR " : "",
                       (evts & SYS_EVT_COMM_ERROR)   ? "COMM " : "",
                       !(evts & (SYS_EVT_LOW_BATTERY | SYS_EVT_SENSOR_ALARM | SYS_EVT_COMM_ERROR))
                           ? "None" : "");
                printf("╚═══════════════════════════════════════════╝\r\n\r\n");
            }
        }
    }
}

/* =====================================================================
 * Communication Manager Task (Message Buffer + Mutex)
 *
 * Receives telemetry packets via message buffer. Acquires the radio
 * mutex before transmitting. Simulates network communication.
 * ===================================================================== */

static void vCommManagerTask(void *pv)
{
    xEventGroupSetBits(xSystemEvents, SYS_EVT_COMM_READY);
    sys_log("[Comm] Radio initialized");

    uint8_t pkt_buf[sizeof(TelemetryPacket_t)];
    uint32_t tx_count = 0;

    for (;;) {
        size_t rcvd = xMessageBufferReceive(xTelemetryBuf, pkt_buf, sizeof(pkt_buf),
                                             portMAX_DELAY);

        if (rcvd >= 6) {
            TelemetryPacket_t *pkt = (TelemetryPacket_t *)pkt_buf;

            if (xSemaphoreTake(xRadioMutex, pdMS_TO_TICKS(2000)) == pdTRUE) {
                tx_count++;
                led_set(LED_COMM, 1);

                /* Simulated radio transmission */
                vTaskDelay(pdMS_TO_TICKS(50));

                led_set(LED_COMM, 0);
                xSemaphoreGive(xRadioMutex);

                if ((tx_count % 10) == 0) {
                    sys_log("[Comm] TX #%lu: type=%u, %u bytes payload",
                            tx_count, pkt->msg_type, pkt->payload_len);
                }
            } else {
                sys_log("[Comm] Radio mutex timeout");
                xEventGroupSetBits(xSystemEvents, SYS_EVT_COMM_ERROR);
            }
        }
    }
}

/* =====================================================================
 * Software Timer Callbacks
 * ===================================================================== */

static void vHeartbeatCallback(TimerHandle_t xTimer)
{
    led_toggle(LED_STATUS);
    uptime_seconds++;
}

static volatile uint32_t watchdog_kicks = 0;

static void vWatchdogCallback(TimerHandle_t xTimer)
{
    if (watchdog_kicks == 0) {
        sys_log("[WATCHDOG] System may be hung!");
        led_set(LED_ERROR, 1);
    }
    watchdog_kicks = 0;
}

static void kick_watchdog(void)
{
    watchdog_kicks++;
}

static void vTelemetryTimerCallback(TimerHandle_t xTimer)
{
    SystemState_t state;

    xSemaphoreTake(xStateMutex, pdMS_TO_TICKS(10));
    state = g_system_state;
    xSemaphoreGive(xStateMutex);

    TelemetryPacket_t pkt;
    pkt.msg_type    = 0;
    pkt.timestamp   = (uint32_t)xTaskGetTickCount();
    pkt.payload_len = sizeof(float) * SENSOR_TYPE_COUNT;
    memcpy(pkt.payload, state.values, pkt.payload_len);

    size_t total = offsetof(TelemetryPacket_t, payload) + pkt.payload_len;
    xMessageBufferSend(xTelemetryBuf, &pkt, total, 0);
}

/* =====================================================================
 * System Monitor Task
 *
 * Periodically reports task stack usage, heap status, and CPU stats.
 * ===================================================================== */

static void vMonitorTask(void *pv)
{
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(10000));

        kick_watchdog();

        printf("\r\n--- System Monitor ---\r\n");
        printf("  Free heap: %u bytes (min: %u)\r\n",
               (unsigned)xPortGetFreeHeapSize(),
               (unsigned)xPortGetMinimumEverFreeHeapSize());
        printf("  Tasks: %lu\r\n", (unsigned long)uxTaskGetNumberOfTasks());

        EventBits_t events = xEventGroupGetBits(xSystemEvents);
        printf("  System events: 0x%04lX\r\n", (unsigned long)events);
        printf("  Sensor queue depth: %lu/%d\r\n",
               (unsigned long)uxQueueMessagesWaiting(xSensorQueue),
               SENSOR_QUEUE_DEPTH);
        printf("  Uptime: %lu s\r\n", uptime_seconds);
        printf("----------------------\r\n\r\n");
    }
}

/* =====================================================================
 * Alarm Handler Task (Event Group Driven)
 *
 * Wakes when alarm-related event bits are set. Takes appropriate
 * action based on the alarm type.
 * ===================================================================== */

#define ALARM_EVENTS (SYS_EVT_LOW_BATTERY | SYS_EVT_SENSOR_ALARM | SYS_EVT_COMM_ERROR)

static void vAlarmHandlerTask(void *pv)
{
    for (;;) {
        EventBits_t bits = xEventGroupWaitBits(
            xSystemEvents,
            ALARM_EVENTS,
            pdTRUE,      /* Clear handled bits */
            pdFALSE,     /* OR — any alarm */
            portMAX_DELAY
        );

        if (bits & SYS_EVT_LOW_BATTERY) {
            sys_log("[ALARM] Low battery — reducing sampling rate");
            led_set(LED_ERROR, 1);
        }

        if (bits & SYS_EVT_SENSOR_ALARM) {
            sys_log("[ALARM] Sensor threshold exceeded");

            /* Send alarm telemetry */
            TelemetryPacket_t pkt = {
                .msg_type    = 1,
                .timestamp   = (uint32_t)xTaskGetTickCount(),
                .payload_len = 4,
            };
            memcpy(pkt.payload, "ALRM", 4);
            size_t total = offsetof(TelemetryPacket_t, payload) + pkt.payload_len;
            xMessageBufferSend(xTelemetryBuf, &pkt, total, pdMS_TO_TICKS(10));
        }

        if (bits & SYS_EVT_COMM_ERROR) {
            sys_log("[ALARM] Communication error — will retry");
            vTaskDelay(pdMS_TO_TICKS(1000));
            xEventGroupClearBits(xSystemEvents, SYS_EVT_COMM_ERROR);
        }
    }
}

/* =====================================================================
 * Main — System Initialization
 * ===================================================================== */

int main(void)
{
    HAL_Init();
    SystemClock_Config();

    printf("\r\n");
    printf("╔═════════════════════════════════════════════════════╗\r\n");
    printf("║     FreeRTOS IoT Sensor Monitoring Application     ║\r\n");
    printf("║     All Major Primitives Demonstrated              ║\r\n");
    printf("╚═════════════════════════════════════════════════════╝\r\n\r\n");

    /* --- Initialize system state --- */
    memset(&g_system_state, 0, sizeof(g_system_state));

    /* --- Create kernel objects --- */

    /* Queue: sensor data pipeline */
    xSensorQueue = xQueueCreate(SENSOR_QUEUE_DEPTH, sizeof(SensorReading_t));
    configASSERT(xSensorQueue);

    /* Mutexes */
    xRadioMutex = xSemaphoreCreateMutex();
    configASSERT(xRadioMutex);

    xStateMutex = xSemaphoreCreateMutex();
    configASSERT(xStateMutex);

    /* Binary semaphore for ADC synchronization */
    xAdcSem = xSemaphoreCreateBinary();
    configASSERT(xAdcSem);

    /* Event group: system state and alarms */
    xSystemEvents = xEventGroupCreate();
    configASSERT(xSystemEvents);

    /* Stream buffer: logging */
    xLogStream = xStreamBufferCreate(LOG_STREAM_BUF_SIZE, 1);
    configASSERT(xLogStream);

    /* Message buffer: telemetry packets */
    xTelemetryBuf = xMessageBufferCreate(TELEMETRY_MSG_BUF_SIZE);
    configASSERT(xTelemetryBuf);

    /* --- Create software timers --- */

    xHeartbeatTimer = xTimerCreate("HB", pdMS_TO_TICKS(1000), pdTRUE,
                                    NULL, vHeartbeatCallback);
    xWatchdogTimer  = xTimerCreate("WDT", pdMS_TO_TICKS(15000), pdTRUE,
                                    NULL, vWatchdogCallback);
    xTelemetryTimer = xTimerCreate("Telem", pdMS_TO_TICKS(5000), pdTRUE,
                                    NULL, vTelemetryTimerCallback);

    /* --- Create tasks --- */

    /* Sensor tasks — one per sensor type */
    for (int i = 0; i < SENSOR_TYPE_COUNT; i++) {
        xTaskCreate(vSensorTask, sensor_configs[i].name, 256,
                    (void *)&sensor_configs[i], PRIO_SENSOR, NULL);
    }

    /* Data aggregator */
    xTaskCreate(vAggregatorTask, "Aggr", 512, NULL, PRIO_AGGREGATOR, NULL);

    /* Display */
    xTaskCreate(vDisplayTask, "Display", 512, NULL, PRIO_DISPLAY, &xDisplayTaskHandle);

    /* Communication manager */
    xTaskCreate(vCommManagerTask, "Comm", 512, NULL, PRIO_COMM, &xCommTaskHandle);

    /* Logger */
    xTaskCreate(vLoggerTask, "Logger", 512, NULL, PRIO_LOGGER, NULL);

    /* Alarm handler */
    xTaskCreate(vAlarmHandlerTask, "Alarm", 256, NULL, PRIO_WATCHDOG, NULL);

    /* System monitor */
    xTaskCreate(vMonitorTask, "Monitor", 512, NULL, PRIO_MONITOR, NULL);

    /* --- Wait for subsystems to be ready, then start timers --- */
    printf("[Main] All tasks created. Starting scheduler...\r\n\r\n");

    /* Start timers (they will begin once the scheduler is running) */
    xTimerStart(xHeartbeatTimer, 0);
    xTimerStart(xWatchdogTimer, 0);
    xTimerStart(xTelemetryTimer, 0);

    /* Signal that sensors are ready (they initialize themselves) */
    xEventGroupSetBits(xSystemEvents, SYS_EVT_SENSORS_READY);

    /* Start the scheduler — this call does not return */
    vTaskStartScheduler();

    printf("[FATAL] Scheduler exited — insufficient memory?\r\n");
    for (;;);
}
