/**
 * FreeRTOS Example 05 — Software Timers
 *
 * Demonstrates:
 *   - One-shot and auto-reload (periodic) timers
 *   - Timer callbacks and the timer daemon task
 *   - xTimerReset() for inactivity/timeout patterns
 *   - xTimerChangePeriod() for dynamic period adjustment
 *   - pvTimerGetTimerID() for shared callbacks
 *   - Timer control from ISR
 *   - xTimerPendFunctionCall() for deferred ISR processing
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 *
 * Key Concept: All timer callbacks execute in the context of the
 * timer daemon task (prvTimerTask), NOT in interrupt context.
 * The daemon task priority is set by configTIMER_TASK_PRIORITY.
 * Timer API calls send commands to the timer command queue
 * (xTimerQueue); the daemon processes them sequentially.
 */

#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "semphr.h"
#include <stdio.h>
#include <string.h>

/* ---------------------------------------------------------------------------
 * Hardware stubs
 * --------------------------------------------------------------------------- */
static void hw_init(void)              { }
static void uart_print(const char *s)  { printf("%s", s); }
static void led_toggle(int led)        { (void)led; }
static void led_on(int led)            { (void)led; }
static void led_off(int led)           { (void)led; }
static void enter_low_power(void)      { }
static void beep(int hz, int ms)       { (void)hz; (void)ms; }

static SemaphoreHandle_t xPrintMtx = NULL;
static void safe_print(const char *s)
{
    xSemaphoreTake(xPrintMtx, portMAX_DELAY);
    uart_print(s);
    xSemaphoreGive(xPrintMtx);
}

/* ---------------------------------------------------------------------------
 * Timer handles
 * --------------------------------------------------------------------------- */
static TimerHandle_t xHeartbeatTimer   = NULL;  /* Periodic LED blink */
static TimerHandle_t xInactivityTimer  = NULL;  /* One-shot inactivity timeout */
static TimerHandle_t xDebounceTimer    = NULL;  /* One-shot button debounce */
static TimerHandle_t xSamplingTimer    = NULL;  /* Periodic sensor sampling */
static TimerHandle_t xLEDTimers[4]     = {NULL}; /* Multiple timers, shared callback */

/* ---------------------------------------------------------------------------
 * Example 1: Periodic Heartbeat Timer
 *
 * An auto-reload timer that toggles an LED every 500 ms. The callback
 * runs in the timer daemon task context, so it must be short and
 * non-blocking.
 *
 * Timer daemon internals:
 *   - The daemon maintains two timer lists (like the task delay lists,
 *     to handle tick overflow).
 *   - Timers are sorted by expiry time in the list.
 *   - The daemon blocks on the timer command queue with a timeout equal
 *     to the time until the next timer expires.
 *   - When a timer expires, the daemon calls the callback, then (if
 *     auto-reload) recalculates the next expiry and re-inserts.
 * --------------------------------------------------------------------------- */
void vHeartbeatCallback(TimerHandle_t xTimer)
{
    (void)xTimer;
    led_toggle(0);

    static uint32_t count = 0;
    count++;
    if (count % 10 == 0) {
        char buf[64];
        snprintf(buf, sizeof(buf),
                 "[HEARTBEAT] Tick #%lu (daemon tick=%lu)\r\n",
                 (unsigned long)count, (unsigned long)xTaskGetTickCount());
        safe_print(buf);
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Inactivity Timeout (One-Shot Timer)
 *
 * A one-shot timer that fires after 10 seconds of inactivity. Every user
 * action resets the timer with xTimerReset(), restarting the countdown.
 *
 * xTimerReset() internally sends a "reset" command to the timer daemon.
 * The daemon removes the timer from its current position in the timer
 * list and re-inserts it with a new expiry = now + period.
 *
 * This pattern is used for:
 *   - Screen backlight timeout
 *   - Communication watchdog
 *   - Auto-lock after inactivity
 * --------------------------------------------------------------------------- */
void vInactivityCallback(TimerHandle_t xTimer)
{
    (void)xTimer;
    safe_print("[INACTIVITY] Timeout! Entering low-power mode.\r\n");
    led_off(1);
    enter_low_power();
}

/* Simulate user interaction that resets the inactivity timer */
void vUserInteractionTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t action = 0;

    for (;;) {
        action++;
        char buf[80];
        snprintf(buf, sizeof(buf),
                 "[USER] Action %lu — resetting inactivity timer\r\n",
                 (unsigned long)action);
        safe_print(buf);

        led_on(1);
        xTimerReset(xInactivityTimer, pdMS_TO_TICKS(100));

        /* Vary the action interval — sometimes cause timeout */
        TickType_t delay = (action % 5 == 0) ? pdMS_TO_TICKS(12000)
                                              : pdMS_TO_TICKS(3000);
        vTaskDelay(delay);
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Button Debounce Timer (One-Shot)
 *
 * Hardware buttons bounce — a single press generates multiple edges over
 * ~5–50 ms. A debounce timer ignores bounces by restarting a short
 * timer on each edge. The actual button press is processed only when
 * the timer expires (no more edges for the debounce period).
 *
 * In the ISR: xTimerResetFromISR (restarts the timer on each edge)
 * In the callback: Process the stable button state
 * --------------------------------------------------------------------------- */
static volatile uint32_t button_press_count = 0;

void vDebounceCallback(TimerHandle_t xTimer)
{
    (void)xTimer;
    button_press_count++;
    char buf[64];
    snprintf(buf, sizeof(buf),
             "[DEBOUNCE] Button press #%lu confirmed\r\n",
             (unsigned long)button_press_count);
    safe_print(buf);
    beep(1000, 50);
}

/* Called from GPIO EXTI ISR on each edge */
void button_isr_handler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /*
     * Reset the debounce timer on every edge. If the timer is already
     * running, this restarts it. Multiple bounces keep restarting it.
     * The callback only fires when edges stop for the debounce period.
     */
    xTimerResetFromISR(xDebounceTimer, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

/* ---------------------------------------------------------------------------
 * Example 4: Dynamic Period Change
 *
 * xTimerChangePeriod() changes the timer's period and restarts it.
 * If the timer was stopped, it starts automatically.
 *
 * Use case: Adjust sampling rate based on system state (e.g., sample
 * faster when an anomaly is detected, slower during idle).
 * --------------------------------------------------------------------------- */
static volatile uint32_t sampling_rate_hz = 10;

void vSamplingCallback(TimerHandle_t xTimer)
{
    (void)xTimer;
    static uint32_t samples = 0;
    samples++;

    if (samples % 20 == 0) {
        char buf[64];
        snprintf(buf, sizeof(buf),
                 "[SAMPLE] #%lu at %lu Hz\r\n",
                 (unsigned long)samples, (unsigned long)sampling_rate_hz);
        safe_print(buf);
    }
}

void vSamplingControlTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(5000));

        /* Increase sampling rate */
        sampling_rate_hz = 50;
        safe_print("[CONTROL] Increasing sampling rate to 50 Hz\r\n");

        /*
         * xTimerChangePeriod sends a "change period" command to the daemon.
         * The second parameter is the new period in ticks.
         * The third parameter is how long to wait if the command queue is full.
         *
         * This also starts the timer if it was stopped.
         */
        xTimerChangePeriod(xSamplingTimer, pdMS_TO_TICKS(20), pdMS_TO_TICKS(100));

        vTaskDelay(pdMS_TO_TICKS(5000));

        /* Decrease sampling rate */
        sampling_rate_hz = 10;
        safe_print("[CONTROL] Decreasing sampling rate to 10 Hz\r\n");
        xTimerChangePeriod(xSamplingTimer, pdMS_TO_TICKS(100), pdMS_TO_TICKS(100));

        vTaskDelay(pdMS_TO_TICKS(5000));

        /* Stop sampling */
        safe_print("[CONTROL] Stopping sampling\r\n");
        xTimerStop(xSamplingTimer, pdMS_TO_TICKS(100));

        vTaskDelay(pdMS_TO_TICKS(5000));

        /* Resume */
        safe_print("[CONTROL] Resuming sampling at 10 Hz\r\n");
        xTimerStart(xSamplingTimer, pdMS_TO_TICKS(100));
    }
}

/* ---------------------------------------------------------------------------
 * Example 5: Shared Callback with Timer ID
 *
 * Multiple timers use the same callback function. Each timer stores
 * a unique ID via pvTimerGetTimerID() / vTimerSetTimerID().
 *
 * pvTimerGetTimerID() returns the pvTimerID that was passed to
 * xTimerCreate(). This can be any pointer — here we use it as
 * a simple integer identifying which LED to toggle.
 * --------------------------------------------------------------------------- */
void vSharedLEDCallback(TimerHandle_t xTimer)
{
    int led_id = (int)(uintptr_t)pvTimerGetTimerID(xTimer);

    led_toggle(led_id);

    char buf[64];
    snprintf(buf, sizeof(buf),
             "[LED-%d] Toggle (timer: %s)\r\n",
             led_id, pcTimerGetName(xTimer));
    safe_print(buf);
}

/* ---------------------------------------------------------------------------
 * Example 6: Deferred ISR Processing via Timer Daemon
 *
 * xTimerPendFunctionCall() and xTimerPendFunctionCallFromISR() let you
 * defer a function call to the timer daemon task without creating a
 * dedicated task or timer.
 *
 * The function signature is:
 *   void vFunction(void *pvParameter1, uint32_t ulParameter2);
 *
 * Requires: INCLUDE_xTimerPendFunctionCall = 1
 * --------------------------------------------------------------------------- */
void vDeferredISRHandler(void *pvParameter1, uint32_t ulParameter2)
{
    char buf[80];
    snprintf(buf, sizeof(buf),
             "[DEFERRED] Processing event: type=%lu, data=%lu\r\n",
             (unsigned long)(uintptr_t)pvParameter1, (unsigned long)ulParameter2);
    safe_print(buf);
}

void EXTI2_IRQHandler(void)
{
    BaseType_t xWoken = pdFALSE;

    /*
     * Defer the processing to the timer daemon task. The function
     * pointer, two parameters, and a woken flag are sent to the
     * timer command queue.
     */
    xTimerPendFunctionCallFromISR(
        vDeferredISRHandler,
        (void *)42,              /* pvParameter1 */
        1234,                    /* ulParameter2 */
        &xWoken
    );

    portYIELD_FROM_ISR(xWoken);
}

/* ---------------------------------------------------------------------------
 * Example 7: Timer Status Queries
 * --------------------------------------------------------------------------- */
void vTimerMonitorTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(8000));

        safe_print("\r\n=== Timer Status ===\r\n");

        char buf[128];

        snprintf(buf, sizeof(buf),
                 "  Heartbeat:  active=%d, period=%lu ms\r\n",
                 (int)xTimerIsTimerActive(xHeartbeatTimer),
                 (unsigned long)(xTimerGetPeriod(xHeartbeatTimer) * 1000 / configTICK_RATE_HZ));
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Inactivity: active=%d, period=%lu ms\r\n",
                 (int)xTimerIsTimerActive(xInactivityTimer),
                 (unsigned long)(xTimerGetPeriod(xInactivityTimer) * 1000 / configTICK_RATE_HZ));
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Sampling:   active=%d, period=%lu ms\r\n",
                 (int)xTimerIsTimerActive(xSamplingTimer),
                 (unsigned long)(xTimerGetPeriod(xSamplingTimer) * 1000 / configTICK_RATE_HZ));
        safe_print(buf);

        safe_print("====================\r\n\r\n");
    }
}

/* ---------------------------------------------------------------------------
 * Hooks
 * --------------------------------------------------------------------------- */
void vApplicationMallocFailedHook(void)                         { for(;;); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *n)     { (void)t; (void)n; for(;;); }
void vApplicationIdleHook(void)                                 { __asm volatile("wfi"); }

/* ---------------------------------------------------------------------------
 * Main
 * --------------------------------------------------------------------------- */
int main(void)
{
    hw_init();

    xPrintMtx = xSemaphoreCreateMutex();

    /*
     * Timer creation: xTimerCreate sends no commands — it only allocates
     * memory for the timer structure. The timer is in the "dormant" state
     * until started.
     *
     * Parameters:
     *   1. Name (for debugging)
     *   2. Period in ticks
     *   3. pdTRUE = auto-reload (periodic), pdFALSE = one-shot
     *   4. Timer ID (user data, any pointer)
     *   5. Callback function
     */
    xHeartbeatTimer = xTimerCreate(
        "Heartbeat",
        pdMS_TO_TICKS(500),
        pdTRUE,                 /* Auto-reload: fires every 500 ms */
        NULL,
        vHeartbeatCallback
    );

    xInactivityTimer = xTimerCreate(
        "Inactivity",
        pdMS_TO_TICKS(10000),
        pdFALSE,                /* One-shot: fires once after 10 s */
        NULL,
        vInactivityCallback
    );

    xDebounceTimer = xTimerCreate(
        "Debounce",
        pdMS_TO_TICKS(30),      /* 30 ms debounce period */
        pdFALSE,
        NULL,
        vDebounceCallback
    );

    xSamplingTimer = xTimerCreate(
        "Sampling",
        pdMS_TO_TICKS(100),     /* 10 Hz initial rate */
        pdTRUE,
        NULL,
        vSamplingCallback
    );

    /* Multiple LED timers with shared callback — identified by timer ID */
    const TickType_t led_periods[] = {
        pdMS_TO_TICKS(200), pdMS_TO_TICKS(500),
        pdMS_TO_TICKS(1000), pdMS_TO_TICKS(1500)
    };
    for (int i = 0; i < 4; i++) {
        char name[12];
        snprintf(name, sizeof(name), "LED%d", i);
        xLEDTimers[i] = xTimerCreate(
            name, led_periods[i], pdTRUE,
            (void *)(uintptr_t)i,       /* Timer ID = LED index */
            vSharedLEDCallback
        );
    }

    /* Start timers — sends "start" commands to the timer daemon queue */
    xTimerStart(xHeartbeatTimer,  0);
    xTimerStart(xInactivityTimer, 0);
    xTimerStart(xSamplingTimer,   0);
    for (int i = 0; i < 4; i++) {
        xTimerStart(xLEDTimers[i], 0);
    }

    /* Tasks */
    xTaskCreate(vUserInteractionTask,  "User",    256, NULL, 2, NULL);
    xTaskCreate(vSamplingControlTask,  "SampCtl", 256, NULL, 2, NULL);
    xTaskCreate(vTimerMonitorTask,     "TimMon",  256, NULL, 1, NULL);

    vTaskStartScheduler();
    for (;;);
}
