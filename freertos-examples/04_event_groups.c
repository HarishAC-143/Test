/**
 * FreeRTOS Example 04 — Event Groups
 *
 * Demonstrates:
 *   - Event group creation and bit manipulation
 *   - Waiting for ANY bit (OR logic)
 *   - Waiting for ALL bits (AND logic)
 *   - Auto-clear on exit behavior
 *   - xEventGroupSync() for task barrier/rendezvous
 *   - Setting bits from ISR (via timer daemon)
 *   - System initialization synchronization
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 */

#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include "semphr.h"
#include <stdio.h>
#include <string.h>

/* ---------------------------------------------------------------------------
 * Hardware stubs
 * --------------------------------------------------------------------------- */
static void hw_init(void)             { }
static void uart_print(const char *s) { printf("%s", s); }

static SemaphoreHandle_t xPrintMtx = NULL;
static void safe_print(const char *s)
{
    xSemaphoreTake(xPrintMtx, portMAX_DELAY);
    uart_print(s);
    xSemaphoreGive(xPrintMtx);
}

/* ---------------------------------------------------------------------------
 * Event bit definitions
 *
 * On a 32-bit architecture, bits 0–23 are available for user events.
 * Bits 24–31 are reserved for internal FreeRTOS control flags
 * (e.g., clear-on-exit, wait-for-all).
 * --------------------------------------------------------------------------- */

/* System initialization events */
#define EVT_WIFI_READY      (1 << 0)
#define EVT_SENSOR_READY    (1 << 1)
#define EVT_STORAGE_READY   (1 << 2)
#define EVT_DISPLAY_READY   (1 << 3)
#define EVT_ALL_INIT        (EVT_WIFI_READY | EVT_SENSOR_READY | EVT_STORAGE_READY | EVT_DISPLAY_READY)

/* Runtime events */
#define EVT_NEW_DATA        (1 << 4)
#define EVT_BUTTON_PRESS    (1 << 5)
#define EVT_ALARM           (1 << 6)
#define EVT_LOW_BATTERY     (1 << 7)

/* Sync barrier bits */
#define SYNC_TASK_0         (1 << 0)
#define SYNC_TASK_1         (1 << 1)
#define SYNC_TASK_2         (1 << 2)
#define SYNC_ALL            (SYNC_TASK_0 | SYNC_TASK_1 | SYNC_TASK_2)

static EventGroupHandle_t xInitEvents    = NULL;
static EventGroupHandle_t xRuntimeEvents = NULL;
static EventGroupHandle_t xSyncEvents    = NULL;

/* ---------------------------------------------------------------------------
 * Example 1: System Initialization Synchronization
 *
 * Multiple subsystem tasks initialize independently and signal completion
 * by setting their bit. A main application task waits for ALL bits before
 * proceeding.
 *
 * xEventGroupSetBits() internally:
 * 1. ORs the specified bits into uxEventBits.
 * 2. Walks xTasksWaitingForBits — for each waiting task, checks if
 *    its condition is now satisfied (all bits or any bit, depending
 *    on the task's wait parameters).
 * 3. Unblocks satisfied tasks and optionally clears bits if xClearOnExit.
 * --------------------------------------------------------------------------- */
void vWifiInitTask(void *pvParameters)
{
    (void)pvParameters;
    safe_print("[WIFI] Initializing...\r\n");
    vTaskDelay(pdMS_TO_TICKS(300));
    safe_print("[WIFI] Ready!\r\n");

    xEventGroupSetBits(xInitEvents, EVT_WIFI_READY);

    vTaskDelete(NULL);
}

void vSensorInitTask(void *pvParameters)
{
    (void)pvParameters;
    safe_print("[SENSOR] Initializing...\r\n");
    vTaskDelay(pdMS_TO_TICKS(150));
    safe_print("[SENSOR] Ready!\r\n");

    xEventGroupSetBits(xInitEvents, EVT_SENSOR_READY);

    vTaskDelete(NULL);
}

void vStorageInitTask(void *pvParameters)
{
    (void)pvParameters;
    safe_print("[STORAGE] Initializing...\r\n");
    vTaskDelay(pdMS_TO_TICKS(500));
    safe_print("[STORAGE] Ready!\r\n");

    xEventGroupSetBits(xInitEvents, EVT_STORAGE_READY);

    vTaskDelete(NULL);
}

void vDisplayInitTask(void *pvParameters)
{
    (void)pvParameters;
    safe_print("[DISPLAY] Initializing...\r\n");
    vTaskDelay(pdMS_TO_TICKS(200));
    safe_print("[DISPLAY] Ready!\r\n");

    xEventGroupSetBits(xInitEvents, EVT_DISPLAY_READY);

    vTaskDelete(NULL);
}

void vApplicationMainTask(void *pvParameters)
{
    (void)pvParameters;

    safe_print("[MAIN] Waiting for all subsystems...\r\n");

    /*
     * xEventGroupWaitBits parameters:
     *   uxBitsToWaitFor: EVT_ALL_INIT — the bits we're interested in
     *   xClearOnExit:    pdTRUE — clear the matched bits when returning
     *   xWaitForAllBits: pdTRUE — require ALL bits to be set (AND logic)
     *   xTicksToWait:    pdMS_TO_TICKS(10000) — timeout
     *
     * Return value: the event bits at the time the condition was met
     *               (before clearing if xClearOnExit is pdTRUE)
     *
     * Internal flow:
     * 1. Check if condition is already satisfied.
     * 2. If not, encode wait parameters into xEventListItem's value
     *    (clear-on-exit flag in bit 24, wait-for-all in bit 26).
     * 3. Add task to xTasksWaitingForBits.
     * 4. Block with timeout.
     * 5. When unblocked (by SetBits or timeout), return current bits.
     */
    EventBits_t bits = xEventGroupWaitBits(
        xInitEvents,
        EVT_ALL_INIT,
        pdTRUE,              /* Clear bits on exit */
        pdTRUE,              /* Wait for ALL bits */
        pdMS_TO_TICKS(10000)
    );

    if ((bits & EVT_ALL_INIT) == EVT_ALL_INIT) {
        safe_print("[MAIN] All subsystems initialized! Starting application.\r\n");
    } else {
        char buf[128];
        snprintf(buf, sizeof(buf),
                 "[MAIN] TIMEOUT! Missing: WiFi=%c Sensor=%c Storage=%c Display=%c\r\n",
                 (bits & EVT_WIFI_READY)    ? 'Y' : 'N',
                 (bits & EVT_SENSOR_READY)  ? 'Y' : 'N',
                 (bits & EVT_STORAGE_READY) ? 'Y' : 'N',
                 (bits & EVT_DISPLAY_READY) ? 'Y' : 'N');
        safe_print(buf);
    }

    for (;;) {
        vTaskDelay(portMAX_DELAY);
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Runtime Events — Wait for ANY (OR logic)
 *
 * A handler task responds to any of several events. Setting xWaitForAllBits
 * to pdFALSE means the task wakes on ANY bit being set.
 *
 * Multiple bits can be set simultaneously. The returned value indicates
 * which bits were actually set, allowing the handler to process them.
 * --------------------------------------------------------------------------- */
void vEventSourceTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t cycle = 0;

    for (;;) {
        cycle++;

        if (cycle % 3 == 0) {
            safe_print("[SRC] → New data event\r\n");
            xEventGroupSetBits(xRuntimeEvents, EVT_NEW_DATA);
        }
        if (cycle % 5 == 0) {
            safe_print("[SRC] → Button press event\r\n");
            xEventGroupSetBits(xRuntimeEvents, EVT_BUTTON_PRESS);
        }
        if (cycle % 7 == 0) {
            safe_print("[SRC] → Alarm event\r\n");
            xEventGroupSetBits(xRuntimeEvents, EVT_ALARM);
        }
        if (cycle % 11 == 0) {
            safe_print("[SRC] → Low battery event\r\n");
            xEventGroupSetBits(xRuntimeEvents, EVT_LOW_BATTERY);
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void vEventHandlerTask(void *pvParameters)
{
    (void)pvParameters;
    const EventBits_t xAllEvents = EVT_NEW_DATA | EVT_BUTTON_PRESS |
                                    EVT_ALARM | EVT_LOW_BATTERY;

    for (;;) {
        /*
         * Wait for ANY event (OR logic): xWaitForAllBits = pdFALSE.
         * xClearOnExit = pdTRUE: bits that triggered the wakeup are cleared.
         *
         * Note: If bits are set between the xClearOnExit clear and the
         * next WaitBits call, they are NOT lost — they will be caught
         * on the next iteration.
         */
        EventBits_t bits = xEventGroupWaitBits(
            xRuntimeEvents,
            xAllEvents,
            pdTRUE,              /* Clear matched bits */
            pdFALSE,             /* OR — wake on ANY bit */
            portMAX_DELAY
        );

        char buf[128];

        if (bits & EVT_NEW_DATA)
            safe_print("[HANDLER] Processing new data\r\n");

        if (bits & EVT_BUTTON_PRESS)
            safe_print("[HANDLER] Handling button press\r\n");

        if (bits & EVT_ALARM) {
            safe_print("[HANDLER] !! ALARM triggered !!\r\n");
        }

        if (bits & EVT_LOW_BATTERY) {
            safe_print("[HANDLER] Low battery — entering power save\r\n");
        }

        /* Show raw bit value */
        snprintf(buf, sizeof(buf),
                 "[HANDLER] Processed bits: 0x%04lX\r\n",
                 (unsigned long)bits);
        safe_print(buf);
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Event Group Synchronization (Barrier / Rendezvous)
 *
 * xEventGroupSync() implements a barrier. Each task:
 *   1. Sets its own "done" bit
 *   2. Waits for all tasks' bits to be set
 *
 * When all bits are set, ALL tasks are unblocked simultaneously, and
 * all bits are cleared atomically.
 *
 * This is useful for multi-phase computation where all tasks must
 * complete phase N before any task starts phase N+1.
 *
 * Internal: xEventGroupSync calls xEventGroupSetBits (to set this task's
 * bit), then immediately checks if all bits are set. If yes, clears all
 * bits and returns. If no, blocks like xEventGroupWaitBits with
 * xWaitForAllBits = pdTRUE.
 * --------------------------------------------------------------------------- */
void vSyncTask(void *pvParameters)
{
    EventBits_t myBit = (EventBits_t)(uintptr_t)pvParameters;
    int task_id = (myBit == SYNC_TASK_0) ? 0 : (myBit == SYNC_TASK_1) ? 1 : 2;
    uint32_t phase = 0;

    for (;;) {
        phase++;
        char buf[128];

        /* Phase work — each task takes a different amount of time */
        snprintf(buf, sizeof(buf),
                 "[SYNC-%d] Phase %lu: working...\r\n",
                 task_id, (unsigned long)phase);
        safe_print(buf);
        vTaskDelay(pdMS_TO_TICKS(200 + task_id * 150));

        /* Sync point — set our bit and wait for all */
        snprintf(buf, sizeof(buf),
                 "[SYNC-%d] Phase %lu: reached barrier, waiting...\r\n",
                 task_id, (unsigned long)phase);
        safe_print(buf);

        EventBits_t result = xEventGroupSync(
            xSyncEvents,
            myBit,           /* Set our bit */
            SYNC_ALL,        /* Wait for all bits */
            pdMS_TO_TICKS(5000)
        );

        if ((result & SYNC_ALL) == SYNC_ALL) {
            snprintf(buf, sizeof(buf),
                     "[SYNC-%d] Phase %lu: barrier passed!\r\n",
                     task_id, (unsigned long)phase);
            safe_print(buf);
        } else {
            snprintf(buf, sizeof(buf),
                     "[SYNC-%d] Phase %lu: TIMEOUT at barrier!\r\n",
                     task_id, (unsigned long)phase);
            safe_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 4: Setting Event Bits from ISR
 *
 * xEventGroupSetBitsFromISR does NOT directly manipulate the event group.
 * Instead, it sends a command to the timer daemon task via the timer
 * command queue. The daemon task executes the actual SetBits operation.
 *
 * This is because SetBits may need to unblock multiple tasks and walk
 * the waiting list — operations too complex for ISR context.
 *
 * Consequence: There is a delay between the ISR call and the actual
 * bit setting (depends on timer daemon priority). For time-critical
 * ISR-to-task signaling, prefer binary semaphores or task notifications.
 * --------------------------------------------------------------------------- */
void EXTI1_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /*
     * This sends a "set bits" command to the timer daemon queue.
     * The daemon runs at configTIMER_TASK_PRIORITY and performs
     * the actual xEventGroupSetBits call.
     *
     * Return value: pdPASS if the command was sent to the queue,
     *               pdFAIL if the timer command queue was full.
     */
    xEventGroupSetBitsFromISR(xRuntimeEvents, EVT_BUTTON_PRESS,
                               &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

/* ---------------------------------------------------------------------------
 * Example 5: Polling event bits (non-blocking)
 *
 * xEventGroupGetBits() reads the current bits without blocking or clearing.
 * Useful for status checks or conditional logic.
 * --------------------------------------------------------------------------- */
void vStatusPollTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        EventBits_t bits = xEventGroupGetBits(xRuntimeEvents);

        char buf[80];
        snprintf(buf, sizeof(buf),
                 "[POLL] Event bits: 0x%04lX\r\n",
                 (unsigned long)bits);
        safe_print(buf);

        /*
         * xEventGroupClearBits returns the value of the bits BEFORE clearing.
         * This is atomic — no race between reading and clearing.
         */
        if (bits & EVT_ALARM) {
            EventBits_t before = xEventGroupClearBits(xRuntimeEvents, EVT_ALARM);
            snprintf(buf, sizeof(buf),
                     "[POLL] Cleared alarm bit (was 0x%04lX)\r\n",
                     (unsigned long)before);
            safe_print(buf);
        }

        vTaskDelay(pdMS_TO_TICKS(2000));
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

    xPrintMtx      = xSemaphoreCreateMutex();
    xInitEvents    = xEventGroupCreate();
    xRuntimeEvents = xEventGroupCreate();
    xSyncEvents    = xEventGroupCreate();

    /* System init synchronization */
    xTaskCreate(vWifiInitTask,        "WiFi",    256, NULL, 3, NULL);
    xTaskCreate(vSensorInitTask,      "SensI",   256, NULL, 3, NULL);
    xTaskCreate(vStorageInitTask,     "StorI",   256, NULL, 3, NULL);
    xTaskCreate(vDisplayInitTask,     "DispI",   256, NULL, 3, NULL);
    xTaskCreate(vApplicationMainTask, "Main",    256, NULL, 2, NULL);

    /* Runtime event handling */
    xTaskCreate(vEventSourceTask,  "EvtSrc", 256, NULL, 2, NULL);
    xTaskCreate(vEventHandlerTask, "EvtHdl", 256, NULL, 3, NULL);
    xTaskCreate(vStatusPollTask,   "Poll",   256, NULL, 1, NULL);

    /* Barrier synchronization */
    xTaskCreate(vSyncTask, "Sync0", 256, (void *)(uintptr_t)SYNC_TASK_0, 2, NULL);
    xTaskCreate(vSyncTask, "Sync1", 256, (void *)(uintptr_t)SYNC_TASK_1, 2, NULL);
    xTaskCreate(vSyncTask, "Sync2", 256, (void *)(uintptr_t)SYNC_TASK_2, 2, NULL);

    vTaskStartScheduler();
    for (;;);
}
