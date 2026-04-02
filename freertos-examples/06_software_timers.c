/**
 * FreeRTOS Example 06: Software Timers
 *
 * Demonstrates:
 *   - One-shot timers
 *   - Auto-reload (periodic) timers
 *   - Timer ID for multiplexing callbacks
 *   - Dynamic period changes
 *   - Timer reset for activity timeout (watchdog pattern)
 *   - Pending function calls from ISR
 *
 * Internal architecture:
 *   Software timers run in the context of the Timer Daemon Task (also called
 *   Timer Service Task). This task is created automatically by vTaskStartScheduler
 *   when configUSE_TIMERS == 1.
 *
 *   Timer API functions (Start, Stop, Reset, ChangePeriod) do NOT execute
 *   directly. Instead, they send a COMMAND to the Timer Command Queue
 *   (length = configTIMER_QUEUE_LENGTH). The daemon task blocks on this queue
 *   and processes commands one at a time.
 *
 *   Timer daemon task loop:
 *     1. Block on the command queue (with timeout = time until next timer expires)
 *     2. Process any received commands (start, stop, reset, delete, change period)
 *     3. Check the timer list for expired timers
 *     4. Call expired timer callbacks
 *     5. For auto-reload timers: reinsert into the timer list
 *
 *   Timer callbacks:
 *     - Execute in the daemon task's context (NOT an ISR)
 *     - Must NOT block (would prevent other timers from being serviced)
 *     - Receive the timer handle as parameter
 *     - Share the daemon task's stack
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include "timers.h"
#include "queue.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Simulated Hardware                                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

static void uart_printf(const char *fmt, ...) { (void)fmt; }
static void gpio_toggle(uint8_t pin) { (void)pin; }
static void gpio_write(uint8_t pin, uint8_t val) { (void)pin; (void)val; }
static void buzzer_beep(uint16_t freq, uint16_t duration_ms) { (void)freq; (void)duration_ms; }

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: Auto-Reload Timer — LED Heartbeat                              */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * An auto-reload timer fires periodically at a fixed interval.
 * After each expiry, the kernel automatically restarts the timer.
 *
 * xTimerCreate parameters:
 *   pcTimerName          — debug name (no functional use)
 *   xTimerPeriodInTicks  — period between callback invocations
 *   uxAutoReload         — pdTRUE: periodic, pdFALSE: one-shot
 *   pvTimerID            — user-defined pointer stored in the timer
 *   pxCallbackFunction   — function called when timer expires
 *
 * The timer is NOT running after creation — you must call xTimerStart.
 */

static void vHeartbeatCallback(TimerHandle_t xTimer) {
    (void)xTimer;
    static uint32_t ulCount = 0;

    gpio_toggle(13); /* Toggle LED on pin 13 */
    ulCount++;

    if (ulCount % 10 == 0) {
        uart_printf("[%lu] Heartbeat: %lu toggles\r\n",
                     xTaskGetTickCount(), ulCount);
    }
}

static TimerHandle_t xHeartbeatTimer;

static void example1_heartbeat(void) {
    /**
     * xTimerCreate internally:
     *   1. Allocates a Timer_t structure from the heap
     *   2. Stores the name, period, auto-reload flag, ID, and callback
     *   3. The timer is in the "dormant" state (not in any timer list)
     *   4. Returns the timer handle, or NULL if allocation failed
     */
    xHeartbeatTimer = xTimerCreate(
        "Heartbeat",             /* Name */
        pdMS_TO_TICKS(500),      /* 500 ms period */
        pdTRUE,                  /* Auto-reload (periodic) */
        NULL,                    /* No ID needed */
        vHeartbeatCallback       /* Callback function */
    );
    configASSERT(xHeartbeatTimer != NULL);

    /**
     * xTimerStart(xTimer, xTicksToWait):
     *   - Sends a "start" command to the timer command queue
     *   - xTicksToWait is how long to wait if the command queue is full
     *     (NOT the timer period)
     *   - The daemon task will insert this timer into the active timer list
     *     sorted by expiry time
     *   - Returns pdPASS if the command was successfully queued
     *
     * Why the command queue pattern?
     *   Timer list manipulation must be done in the daemon task's context
     *   (single-threaded, no concurrent modification). The queue serializes
     *   all timer operations.
     */
    BaseType_t xResult = xTimerStart(xHeartbeatTimer, pdMS_TO_TICKS(100));
    configASSERT(xResult == pdPASS);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: One-Shot Timer — Delayed Action                                */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * A one-shot timer fires once and then stops automatically.
 * It must be manually restarted if you want it to fire again.
 *
 * Use cases:
 *   - Timeout detection (e.g., no response within N seconds)
 *   - Debouncing (ignore rapid button presses)
 *   - Delayed initialization
 */

static void vDebounceCallback(TimerHandle_t xTimer) {
    uint32_t ulButtonId = (uint32_t)(uintptr_t)pvTimerGetTimerID(xTimer);
    uart_printf("[%lu] Debounce: button %lu confirmed pressed\r\n",
                 xTaskGetTickCount(), ulButtonId);

    /* Process the confirmed button press */
}

static TimerHandle_t xDebounceTimers[4];

static void example2_oneshot(void) {
    for (uint32_t i = 0; i < 4; i++) {
        char name[16];
        snprintf(name, sizeof(name), "Debounce%lu", (unsigned long)i);

        xDebounceTimers[i] = xTimerCreate(
            name,
            pdMS_TO_TICKS(50),        /* 50 ms debounce window */
            pdFALSE,                   /* One-shot */
            (void *)(uintptr_t)i,      /* Timer ID = button index */
            vDebounceCallback
        );
        configASSERT(xDebounceTimers[i] != NULL);
    }
}

/**
 * Call this from the button ISR.
 * Each press resets the timer. Only after 50ms without another press
 * does the callback fire (effective debouncing).
 */
void button_isr_handler(uint8_t button_id) {
    if (button_id < 4) {
        BaseType_t xHigherPriorityTaskWoken = pdFALSE;

        /**
         * xTimerResetFromISR:
         *   - If the timer is running: restarts the count from now
         *   - If the timer is stopped: starts it
         *   - Sends a "reset" command to the timer command queue
         *   - ISR-safe: uses xQueueSendFromISR internally
         */
        xTimerResetFromISR(xDebounceTimers[button_id], &xHigherPriorityTaskWoken);

        portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: Timer ID for Callback Multiplexing                             */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * pvTimerGetTimerID / vTimerSetTimerID:
 *   The timer ID is a void* stored in the timer structure. The kernel
 *   does not use it — it's entirely for the application.
 *
 * Common uses:
 *   1. Store an integer identifier (cast to void*)
 *   2. Store a pointer to associated data
 *   3. Use as a counter or state variable within the callback
 *
 * Since the callback receives the timer handle, and the same callback can
 * serve multiple timers, the ID distinguishes which timer fired.
 */

typedef struct {
    uint8_t  ucLEDPin;
    uint16_t usBlinkCount;
    uint16_t usMaxBlinks;
} LEDTimerContext_t;

static LEDTimerContext_t xLEDContexts[3] = {
    { .ucLEDPin = 5,  .usBlinkCount = 0, .usMaxBlinks = 10 },
    { .ucLEDPin = 6,  .usBlinkCount = 0, .usMaxBlinks = 20 },
    { .ucLEDPin = 7,  .usBlinkCount = 0, .usMaxBlinks = 0  }, /* 0 = infinite */
};

static void vLEDTimerCallback(TimerHandle_t xTimer) {
    LEDTimerContext_t *pxCtx = (LEDTimerContext_t *)pvTimerGetTimerID(xTimer);

    gpio_toggle(pxCtx->ucLEDPin);
    pxCtx->usBlinkCount++;

    uart_printf("[%lu] LED pin %u: blink #%u\r\n",
                 xTaskGetTickCount(), pxCtx->ucLEDPin, pxCtx->usBlinkCount);

    /* Stop timer after reaching max blinks (0 = never stop) */
    if (pxCtx->usMaxBlinks > 0 && pxCtx->usBlinkCount >= pxCtx->usMaxBlinks) {
        /**
         * xTimerStop:
         *   Sends a "stop" command to the timer command queue.
         *   The daemon task removes the timer from the active list.
         *   The timer enters the "dormant" state.
         *   It can be restarted later with xTimerStart or xTimerReset.
         */
        xTimerStop(xTimer, 0);
        uart_printf("[%lu] LED pin %u: max blinks reached, timer stopped\r\n",
                     xTaskGetTickCount(), pxCtx->ucLEDPin);
    }
}

static void example3_timer_id(void) {
    const TickType_t xPeriods[] = { pdMS_TO_TICKS(200), pdMS_TO_TICKS(500), pdMS_TO_TICKS(1000) };

    for (int i = 0; i < 3; i++) {
        char name[16];
        snprintf(name, sizeof(name), "LED%d", i);

        TimerHandle_t xTimer = xTimerCreate(
            name,
            xPeriods[i],
            pdTRUE,                        /* Auto-reload */
            (void *)&xLEDContexts[i],      /* ID = pointer to context */
            vLEDTimerCallback              /* Shared callback */
        );
        configASSERT(xTimer != NULL);
        xTimerStart(xTimer, 0);
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: Dynamic Period Change                                          */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xTimerChangePeriod(xTimer, xNewPeriod, xTicksToWait):
 *   - Changes the timer's period
 *   - If the timer was dormant, this STARTS it with the new period
 *   - If the timer was active, the period change takes effect immediately
 *     (the timer restarts from now with the new period)
 *
 * Use case: Adaptive sampling rate — speed up when changes are detected,
 * slow down during stable periods.
 */

static TimerHandle_t xAdaptiveTimer;
static volatile float g_last_reading = 0.0f;
static volatile float g_current_reading = 0.0f;

static void vAdaptiveSampleCallback(TimerHandle_t xTimer) {
    g_last_reading = g_current_reading;
    g_current_reading = 22.0f; /* Simulated sensor read */

    float fDelta = g_current_reading - g_last_reading;
    if (fDelta < 0) fDelta = -fDelta;

    TickType_t xCurrentPeriod = xTimerGetPeriod(xTimer);

    uart_printf("[%lu] Sample: value=%.1f delta=%.1f period=%lu ms\r\n",
                 xTaskGetTickCount(), g_current_reading, fDelta,
                 (unsigned long)(xCurrentPeriod * portTICK_PERIOD_MS));

    /* Speed up if change is large, slow down if stable */
    if (fDelta > 2.0f && xCurrentPeriod > pdMS_TO_TICKS(50)) {
        xTimerChangePeriod(xTimer, pdMS_TO_TICKS(50), 0);
        uart_printf("  → Speeding up to 50ms\r\n");
    } else if (fDelta < 0.5f && xCurrentPeriod < pdMS_TO_TICKS(1000)) {
        xTimerChangePeriod(xTimer, pdMS_TO_TICKS(1000), 0);
        uart_printf("  → Slowing down to 1000ms\r\n");
    }
}

static void example4_dynamic_period(void) {
    xAdaptiveTimer = xTimerCreate(
        "Adaptive",
        pdMS_TO_TICKS(500),   /* Initial period */
        pdTRUE,                /* Auto-reload */
        NULL,
        vAdaptiveSampleCallback
    );
    configASSERT(xAdaptiveTimer != NULL);
    xTimerStart(xAdaptiveTimer, 0);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 5: Activity Timeout (Watchdog Pattern)                            */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xTimerReset:
 *   - Restarts the timer's count from NOW
 *   - If the timer was dormant, starts it
 *   - Effectively: "I'm still alive, reset the timeout"
 *
 * Pattern: A one-shot timer acts as an inactivity watchdog.
 * Each time activity is detected, the timer is reset.
 * If the timer expires, it means no activity for the entire period.
 */

static TimerHandle_t xInactivityTimer;

static void vInactivityCallback(TimerHandle_t xTimer) {
    (void)xTimer;

    uart_printf("[%lu] INACTIVITY TIMEOUT: No user input for 30 seconds!\r\n",
                 xTaskGetTickCount());

    /* Take action: dim display, enter sleep mode, lock screen, etc. */
    gpio_write(0, 0);  /* Turn off backlight */
    buzzer_beep(1000, 100);
}

static void example5_activity_timeout(void) {
    xInactivityTimer = xTimerCreate(
        "Inactivity",
        pdMS_TO_TICKS(30000),   /* 30 second timeout */
        pdFALSE,                /* One-shot */
        NULL,
        vInactivityCallback
    );
    configASSERT(xInactivityTimer != NULL);
    xTimerStart(xInactivityTimer, 0);
}

/* Called from input handlers (button press, touch, etc.) */
void on_user_activity(void) {
    /* Reset the inactivity timer — user is active */
    xTimerReset(xInactivityTimer, pdMS_TO_TICKS(10));

    /* Also re-enable backlight if it was dimmed */
    gpio_write(0, 1);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 6: Pending Function Calls                                         */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xTimerPendFunctionCall / xTimerPendFunctionCallFromISR:
 *   Execute an arbitrary function in the timer daemon task's context.
 *   This avoids creating a dedicated task for simple deferred processing.
 *
 *   The function is queued as a timer command and executed by the daemon
 *   when it processes the command queue.
 *
 *   Function signature: void vFunc(void *pvParam1, uint32_t ulParam2)
 *
 * Requires INCLUDE_xTimerPendFunctionCall == 1 in FreeRTOSConfig.h.
 */

static void vDeferredISRProcessing(void *pvParameter1, uint32_t ulParameter2) {
    uint8_t *pucData = (uint8_t *)pvParameter1;
    uint32_t ulLength = ulParameter2;

    uart_printf("[%lu] Deferred processing: %lu bytes of data\r\n",
                 xTaskGetTickCount(), ulLength);

    /* Process the data in task context (can use blocking APIs, etc.) */
    for (uint32_t i = 0; i < ulLength; i++) {
        /* ... process pucData[i] ... */
        (void)pucData[i];
    }
}

static uint8_t g_isr_data_buffer[64];

void SOME_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Copy data from hardware to buffer */
    uint32_t ulLen = 32; /* actual received length */
    /* memcpy(g_isr_data_buffer, PERIPHERAL->DATA, ulLen); */

    /* Defer processing to the timer daemon task */
    xTimerPendFunctionCallFromISR(
        vDeferredISRProcessing,
        (void *)g_isr_data_buffer,
        ulLen,
        &xHigherPriorityTaskWoken
    );

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 7: Timer Query Functions                                          */
/* ──────────────────────────────────────────────────────────────────────────── */

static void vTimerStatusTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        if (xHeartbeatTimer != NULL) {
            uart_printf("[%lu] Timer '%s':\r\n", xTaskGetTickCount(),
                         pcTimerGetName(xHeartbeatTimer));

            /**
             * xTimerIsTimerActive:
             *   Returns pdTRUE if the timer is in the active timer list
             *   (running and counting), pdFALSE if dormant (stopped).
             */
            uart_printf("  Active: %s\r\n",
                         xTimerIsTimerActive(xHeartbeatTimer) ? "Yes" : "No");

            /**
             * xTimerGetPeriod:
             *   Returns the timer's period in ticks.
             */
            uart_printf("  Period: %lu ms\r\n",
                         (unsigned long)(xTimerGetPeriod(xHeartbeatTimer)
                                         * portTICK_PERIOD_MS));

            /**
             * xTimerGetExpiryTime:
             *   Returns the tick count at which the timer will next expire.
             *   Only meaningful if the timer is active.
             */
            if (xTimerIsTimerActive(xHeartbeatTimer)) {
                TickType_t xExpiry = xTimerGetExpiryTime(xHeartbeatTimer);
                TickType_t xNow   = xTaskGetTickCount();
                uart_printf("  Next expiry in: %lu ms\r\n",
                             (unsigned long)((xExpiry - xNow) * portTICK_PERIOD_MS));
            }
        }

        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main                                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) { }
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName; for (;;) { }
}

int main(void) {
    example1_heartbeat();
    example2_oneshot();
    example3_timer_id();
    example4_dynamic_period();
    example5_activity_timeout();

    xTaskCreate(vTimerStatusTask, "TimerStat", 256, NULL, 1, NULL);

    vTaskStartScheduler();
    for (;;) { }
    return 0;
}
