/*
 * FreeRTOS Software Timers and Event Groups Examples
 *
 * Demonstrates: xTimerCreate, xTimerStart, xTimerStop, xTimerReset,
 *               xTimerChangePeriod, pvTimerGetTimerID,
 *               xEventGroupCreate, xEventGroupSetBits, xEventGroupWaitBits,
 *               xEventGroupSync, xEventGroupClearBits,
 *               xEventGroupSetBitsFromISR
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10.x/v11.x
 */

#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "event_groups.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ---------- Hardware Stubs ---------- */

static inline void HAL_Init(void) {}
static inline void SystemClock_Config(void) {}

static volatile uint32_t gpio_odr = 0;
static inline void led_toggle(uint32_t pin) { gpio_odr ^= (1U << pin); }
static inline void led_on(uint32_t pin)     { gpio_odr |= (1U << pin); }
static inline void led_off(uint32_t pin)    { gpio_odr &= ~(1U << pin); }

/* ---------- FreeRTOS Hooks ---------- */

void vApplicationMallocFailedHook(void)  { for (;;); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *n) { for (;;); }
void vApplicationIdleHook(void) {}

/* =====================================================================
 * Example 1: Basic Software Timers (Periodic and One-Shot)
 *
 * Creates a periodic timer for LED blinking and a one-shot timer
 * for a delayed action (e.g., auto-shutdown after inactivity).
 * ===================================================================== */

static void vLedBlinkCallback(TimerHandle_t xTimer)
{
    uint32_t led_pin = (uint32_t)(uintptr_t)pvTimerGetTimerID(xTimer);
    led_toggle(led_pin);

    static uint32_t blink_count = 0;
    blink_count++;
    if ((blink_count % 10) == 0) {
        printf("[Blink] LED pin %lu toggled %lu times\r\n", led_pin, blink_count);
    }
}

static void vAutoShutdownCallback(TimerHandle_t xTimer)
{
    printf("[AutoOff] Inactivity timeout! Entering low-power mode...\r\n");
    led_off(12);
    led_off(14);
    led_off(15);
}

static void vUserActivityTask(void *pv)
{
    TimerHandle_t xShutdownTimer = (TimerHandle_t)pv;
    uint32_t event = 0;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(3000));

        event++;
        printf("[User] Activity detected (event #%lu) — resetting shutdown timer\r\n",
               event);

        /* Reset the one-shot timer — postpones the shutdown */
        xTimerReset(xShutdownTimer, portMAX_DELAY);
    }
}

/* =====================================================================
 * Example 2: Timer ID to Multiplex One Callback
 *
 * A single callback handles multiple timers, differentiated by their
 * pvTimerID. Useful for periodic sensor sampling at different rates.
 * ===================================================================== */

typedef struct {
    const char *name;
    uint32_t    channel;
    uint32_t    sample_count;
} SensorTimerCtx_t;

static SensorTimerCtx_t sensor_contexts[] = {
    { "Temperature", 0, 0 },
    { "Humidity",    1, 0 },
    { "Pressure",   2, 0 },
    { "Light",      3, 0 },
};

static void vSensorSampleCallback(TimerHandle_t xTimer)
{
    SensorTimerCtx_t *ctx = (SensorTimerCtx_t *)pvTimerGetTimerID(xTimer);
    ctx->sample_count++;

    printf("[Timer] %s (CH%lu) sample #%lu @ tick %lu\r\n",
           ctx->name, ctx->channel, ctx->sample_count,
           (unsigned long)xTaskGetTickCount());
}

/* =====================================================================
 * Example 3: Dynamic Timer Period Change
 *
 * A task monitors system state and adjusts a timer's period at runtime.
 * Fast polling when active, slow polling when idle.
 * ===================================================================== */

static TimerHandle_t xAdaptiveTimer;
static volatile uint32_t system_load = 0;

static void vAdaptiveTimerCallback(TimerHandle_t xTimer)
{
    TickType_t period = xTimerGetPeriod(xTimer);
    printf("[Adaptive] Tick @ period=%lu ms, load=%lu\r\n",
           (unsigned long)(period * 1000 / configTICK_RATE_HZ), system_load);
}

static void vLoadMonitorTask(void *pv)
{
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(5000));

        system_load = (system_load + 37) % 100;

        TickType_t new_period;
        if (system_load > 70) {
            new_period = pdMS_TO_TICKS(100);    /* Fast: 10 Hz */
            printf("[LoadMon] High load (%lu%%) → 100ms period\r\n", system_load);
        } else if (system_load > 30) {
            new_period = pdMS_TO_TICKS(500);    /* Medium: 2 Hz */
            printf("[LoadMon] Medium load (%lu%%) → 500ms period\r\n", system_load);
        } else {
            new_period = pdMS_TO_TICKS(2000);   /* Slow: 0.5 Hz */
            printf("[LoadMon] Low load (%lu%%) → 2000ms period\r\n", system_load);
        }

        xTimerChangePeriod(xAdaptiveTimer, new_period, portMAX_DELAY);
    }
}

/* =====================================================================
 * Example 4: Watchdog-Style Timer with Reset
 *
 * A timer acts as a software watchdog. A task must periodically reset
 * ("kick") the timer. If it expires, an error handler runs.
 * ===================================================================== */

static volatile uint32_t watchdog_trip_count = 0;

static void vWatchdogCallback(TimerHandle_t xTimer)
{
    watchdog_trip_count++;
    printf("[WATCHDOG] Timer expired! Trip #%lu — system may be hung\r\n",
           watchdog_trip_count);

    if (watchdog_trip_count >= 3) {
        printf("[WATCHDOG] 3 consecutive trips — triggering system reset\r\n");
    }
}

static void vWatchdogKickTask(void *pv)
{
    TimerHandle_t xWdTimer = (TimerHandle_t)pv;
    uint32_t kick = 0;

    for (;;) {
        /* Normal operation: kick the watchdog every 200ms (well within 1s timeout) */
        vTaskDelay(pdMS_TO_TICKS(200));
        xTimerReset(xWdTimer, portMAX_DELAY);
        kick++;

        if ((kick % 25) == 0) {
            printf("[WdKick] Kick #%lu\r\n", kick);
        }

        /* Simulate a stall every 30 kicks */
        if ((kick % 30) == 0) {
            printf("[WdKick] Simulating 1.5s stall...\r\n");
            vTaskDelay(pdMS_TO_TICKS(1500));
            printf("[WdKick] Stall over — resuming normal kicks\r\n");
            xTimerReset(xWdTimer, portMAX_DELAY);
            watchdog_trip_count = 0;
        }
    }
}

/* =====================================================================
 * Example 5: Event Group — Waiting for Multiple Subsystems
 *
 * A startup coordinator waits for WiFi, Bluetooth, and sensor
 * subsystems to initialize. Each subsystem sets its ready bit.
 * ===================================================================== */

#define EVT_WIFI_READY    (1 << 0)
#define EVT_BT_READY      (1 << 1)
#define EVT_SENSOR_READY  (1 << 2)
#define EVT_NTP_SYNCED    (1 << 3)
#define EVT_ALL_READY     (EVT_WIFI_READY | EVT_BT_READY | EVT_SENSOR_READY)

static EventGroupHandle_t xStartupEvents;

static void vWifiInitTask(void *pv)
{
    printf("[WiFi] Initializing...\r\n");
    vTaskDelay(pdMS_TO_TICKS(2000));
    printf("[WiFi] Connected to AP\r\n");

    xEventGroupSetBits(xStartupEvents, EVT_WIFI_READY);

    /* Continue with WiFi-specific work */
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(5000));
        printf("[WiFi] Heartbeat\r\n");
    }
}

static void vBluetoothInitTask(void *pv)
{
    printf("[BT] Initializing...\r\n");
    vTaskDelay(pdMS_TO_TICKS(1500));
    printf("[BT] Stack ready\r\n");

    xEventGroupSetBits(xStartupEvents, EVT_BT_READY);

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(5000));
        printf("[BT] Scanning...\r\n");
    }
}

static void vSensorInitTask(void *pv)
{
    printf("[Sensor] Calibrating...\r\n");
    vTaskDelay(pdMS_TO_TICKS(3000));
    printf("[Sensor] Calibrated and ready\r\n");

    xEventGroupSetBits(xStartupEvents, EVT_SENSOR_READY);

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void vStartupCoordinatorTask(void *pv)
{
    printf("[Startup] Waiting for all subsystems...\r\n");

    EventBits_t bits = xEventGroupWaitBits(
        xStartupEvents,
        EVT_ALL_READY,
        pdFALSE,         /* Don't clear on exit — other tasks may check */
        pdTRUE,          /* Wait for ALL bits */
        pdMS_TO_TICKS(10000)
    );

    printf("[Startup] Wait returned, bits=0x%02lX\r\n", (unsigned long)bits);

    if ((bits & EVT_ALL_READY) == EVT_ALL_READY) {
        printf("[Startup] ✓ All subsystems ready! Starting application.\r\n");
        led_on(12);  /* Green LED */
    } else {
        printf("[Startup] TIMEOUT — not all subsystems ready:\r\n");
        if (!(bits & EVT_WIFI_READY))   printf("  - WiFi NOT ready\r\n");
        if (!(bits & EVT_BT_READY))     printf("  - Bluetooth NOT ready\r\n");
        if (!(bits & EVT_SENSOR_READY)) printf("  - Sensor NOT ready\r\n");
        led_on(14);  /* Red LED */
    }

    /* Coordinator is done — delete self */
    vTaskDelete(NULL);
}

/* =====================================================================
 * Example 6: Event Group — OR Wait (Any Bit)
 *
 * A task wakes up when ANY of several events occurs, processes the
 * event, and goes back to sleep.
 * ===================================================================== */

#define EVT_BUTTON_PRESS  (1 << 0)
#define EVT_UART_RX       (1 << 1)
#define EVT_TIMER_TICK    (1 << 2)
#define EVT_DMA_DONE      (1 << 3)
#define EVT_ANY           (EVT_BUTTON_PRESS | EVT_UART_RX | EVT_TIMER_TICK | EVT_DMA_DONE)

static EventGroupHandle_t xIOEvents;

static void vEventDispatcherTask(void *pv)
{
    for (;;) {
        EventBits_t bits = xEventGroupWaitBits(
            xIOEvents,
            EVT_ANY,
            pdTRUE,      /* Clear bits that woke us */
            pdFALSE,     /* OR — wake on ANY bit */
            portMAX_DELAY
        );

        printf("[Dispatch] Events: ");
        if (bits & EVT_BUTTON_PRESS) printf("BUTTON ");
        if (bits & EVT_UART_RX)      printf("UART_RX ");
        if (bits & EVT_TIMER_TICK)   printf("TIMER ");
        if (bits & EVT_DMA_DONE)     printf("DMA ");
        printf("(0x%02lX)\r\n", (unsigned long)bits);
    }
}

static void vEventGeneratorTask(void *pv)
{
    uint32_t cycle = 0;

    for (;;) {
        cycle++;

        if ((cycle % 3) == 0) {
            xEventGroupSetBits(xIOEvents, EVT_BUTTON_PRESS);
        }
        if ((cycle % 5) == 0) {
            xEventGroupSetBits(xIOEvents, EVT_UART_RX);
        }
        if ((cycle % 7) == 0) {
            xEventGroupSetBits(xIOEvents, EVT_TIMER_TICK);
        }
        if ((cycle % 11) == 0) {
            xEventGroupSetBits(xIOEvents, EVT_DMA_DONE);
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/* =====================================================================
 * Example 7: Event Group Sync (Barrier / Rendezvous)
 *
 * Three pipeline stages process data in lock-step. Each stage signals
 * completion and waits for all stages to finish before starting the
 * next iteration.
 * ===================================================================== */

#define SYNC_STAGE_0  (1 << 0)
#define SYNC_STAGE_1  (1 << 1)
#define SYNC_STAGE_2  (1 << 2)
#define SYNC_ALL      (SYNC_STAGE_0 | SYNC_STAGE_1 | SYNC_STAGE_2)

static EventGroupHandle_t xPipelineSync;

static void vPipelineStage(void *pv)
{
    uint32_t stage_id = (uint32_t)(uintptr_t)pv;
    EventBits_t my_bit = (1 << stage_id);
    uint32_t iteration = 0;

    for (;;) {
        /* Simulate varying processing times per stage */
        uint32_t work_ms = 100 + stage_id * 200;
        printf("[Stage%lu] Processing iteration %lu (%lu ms work)...\r\n",
               stage_id, iteration, work_ms);
        vTaskDelay(pdMS_TO_TICKS(work_ms));

        /* Signal completion and wait for all stages */
        EventBits_t result = xEventGroupSync(
            xPipelineSync,
            my_bit,         /* Set my bit */
            SYNC_ALL,       /* Wait for all bits */
            pdMS_TO_TICKS(5000)
        );

        if ((result & SYNC_ALL) == SYNC_ALL) {
            printf("[Stage%lu] All stages synchronized for iteration %lu\r\n",
                   stage_id, iteration);
        } else {
            printf("[Stage%lu] Sync timeout! result=0x%02lX\r\n",
                   stage_id, (unsigned long)result);
        }

        iteration++;
    }
}

/* =====================================================================
 * Example 8: Combined Timers and Event Groups
 *
 * Software timers set event bits periodically. A coordinator task
 * waits for specific combinations of timer events before acting.
 * ===================================================================== */

#define TMR_EVT_HEARTBEAT    (1 << 0)
#define TMR_EVT_SENSOR_READ  (1 << 1)
#define TMR_EVT_COMM_CHECK   (1 << 2)
#define TMR_EVT_LOG_FLUSH    (1 << 3)

static EventGroupHandle_t xTimerEvents;

static void vHeartbeatTimerCb(TimerHandle_t xTimer)
{
    xEventGroupSetBits(xTimerEvents, TMR_EVT_HEARTBEAT);
}

static void vSensorReadTimerCb(TimerHandle_t xTimer)
{
    xEventGroupSetBits(xTimerEvents, TMR_EVT_SENSOR_READ);
}

static void vCommCheckTimerCb(TimerHandle_t xTimer)
{
    xEventGroupSetBits(xTimerEvents, TMR_EVT_COMM_CHECK);
}

static void vLogFlushTimerCb(TimerHandle_t xTimer)
{
    xEventGroupSetBits(xTimerEvents, TMR_EVT_LOG_FLUSH);
}

static void vTimerEventCoordinator(void *pv)
{
    uint32_t cycle = 0;

    for (;;) {
        EventBits_t bits = xEventGroupWaitBits(
            xTimerEvents,
            TMR_EVT_HEARTBEAT | TMR_EVT_SENSOR_READ | TMR_EVT_COMM_CHECK | TMR_EVT_LOG_FLUSH,
            pdTRUE,      /* Clear all received bits */
            pdFALSE,     /* OR — process any event */
            pdMS_TO_TICKS(5000)
        );

        if (bits == 0) {
            printf("[Coord] No events in 5s — checking timers\r\n");
            continue;
        }

        cycle++;
        printf("[Coord] #%lu events:", cycle);

        if (bits & TMR_EVT_HEARTBEAT) {
            printf(" HEARTBEAT");
            led_toggle(12);
        }
        if (bits & TMR_EVT_SENSOR_READ) {
            printf(" SENSOR");
        }
        if (bits & TMR_EVT_COMM_CHECK) {
            printf(" COMM");
        }
        if (bits & TMR_EVT_LOG_FLUSH) {
            printf(" LOG_FLUSH");
        }

        printf("\r\n");
    }
}

/* =====================================================================
 * Main — select which example to run
 * ===================================================================== */

#ifndef EXAMPLE_SELECT
#define EXAMPLE_SELECT  1
#endif

int main(void)
{
    HAL_Init();
    SystemClock_Config();

    printf("\r\n=== FreeRTOS Timers & Event Groups ===\r\n");
    printf("Running Example %d\r\n\r\n", EXAMPLE_SELECT);

#if EXAMPLE_SELECT == 1
    {
        /* --- Basic timers: periodic blink + one-shot auto-shutdown --- */
        TimerHandle_t xBlinkTimer = xTimerCreate(
            "Blink", pdMS_TO_TICKS(500), pdTRUE,
            (void *)(uintptr_t)12, vLedBlinkCallback);

        TimerHandle_t xShutdownTimer = xTimerCreate(
            "AutoOff", pdMS_TO_TICKS(5000), pdFALSE,
            NULL, vAutoShutdownCallback);

        xTimerStart(xBlinkTimer, 0);
        xTimerStart(xShutdownTimer, 0);

        xTaskCreate(vUserActivityTask, "UserAct", 256, xShutdownTimer, 2, NULL);
    }

#elif EXAMPLE_SELECT == 2
    {
        /* --- Multiplexed timer callback via Timer ID --- */
        const TickType_t periods[] = {
            pdMS_TO_TICKS(1000),   /* Temperature: 1 Hz */
            pdMS_TO_TICKS(2000),   /* Humidity: 0.5 Hz */
            pdMS_TO_TICKS(5000),   /* Pressure: 0.2 Hz */
            pdMS_TO_TICKS(500),    /* Light: 2 Hz */
        };

        for (int i = 0; i < 4; i++) {
            TimerHandle_t t = xTimerCreate(
                sensor_contexts[i].name, periods[i], pdTRUE,
                &sensor_contexts[i], vSensorSampleCallback);
            xTimerStart(t, 0);
        }
    }

#elif EXAMPLE_SELECT == 3
    /* --- Dynamic timer period adjustment --- */
    xAdaptiveTimer = xTimerCreate(
        "Adaptive", pdMS_TO_TICKS(1000), pdTRUE,
        NULL, vAdaptiveTimerCallback);
    xTimerStart(xAdaptiveTimer, 0);

    xTaskCreate(vLoadMonitorTask, "LoadMon", 256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 4
    {
        /* --- Watchdog-style timer with reset --- */
        TimerHandle_t xWdTimer = xTimerCreate(
            "Watchdog", pdMS_TO_TICKS(1000), pdTRUE,
            NULL, vWatchdogCallback);
        xTimerStart(xWdTimer, 0);

        xTaskCreate(vWatchdogKickTask, "WdKick", 256, xWdTimer, 3, NULL);
    }

#elif EXAMPLE_SELECT == 5
    /* --- Event group: multi-subsystem startup coordination --- */
    xStartupEvents = xEventGroupCreate();
    configASSERT(xStartupEvents);

    xTaskCreate(vWifiInitTask,            "WiFi",      256, NULL, 2, NULL);
    xTaskCreate(vBluetoothInitTask,       "BT",        256, NULL, 2, NULL);
    xTaskCreate(vSensorInitTask,          "SensInit",  256, NULL, 2, NULL);
    xTaskCreate(vStartupCoordinatorTask,  "Startup",   512, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 6
    /* --- Event group: OR wait (any bit) --- */
    xIOEvents = xEventGroupCreate();
    configASSERT(xIOEvents);

    xTaskCreate(vEventDispatcherTask, "Dispatch", 256, NULL, 3, NULL);
    xTaskCreate(vEventGeneratorTask,  "EvtGen",   256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 7
    /* --- Event group sync: pipeline barrier --- */
    xPipelineSync = xEventGroupCreate();
    configASSERT(xPipelineSync);

    for (uint32_t i = 0; i < 3; i++) {
        char name[12];
        snprintf(name, sizeof(name), "Stage%lu", i);
        xTaskCreate(vPipelineStage, name, 256, (void *)(uintptr_t)i, 2, NULL);
    }

#elif EXAMPLE_SELECT == 8
    /* --- Combined timers and event groups --- */
    xTimerEvents = xEventGroupCreate();
    configASSERT(xTimerEvents);

    xTimerStart(xTimerCreate("HB",   pdMS_TO_TICKS(1000), pdTRUE, NULL, vHeartbeatTimerCb), 0);
    xTimerStart(xTimerCreate("Sens", pdMS_TO_TICKS(2000), pdTRUE, NULL, vSensorReadTimerCb), 0);
    xTimerStart(xTimerCreate("Comm", pdMS_TO_TICKS(3000), pdTRUE, NULL, vCommCheckTimerCb), 0);
    xTimerStart(xTimerCreate("Log",  pdMS_TO_TICKS(5000), pdTRUE, NULL, vLogFlushTimerCb), 0);

    xTaskCreate(vTimerEventCoordinator, "Coord", 512, NULL, 3, NULL);

#else
    printf("Invalid EXAMPLE_SELECT. Choose 1-8.\r\n");
#endif

    vTaskStartScheduler();

    for (;;);
}
