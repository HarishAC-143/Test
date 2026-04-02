/**
 * FreeRTOS Example 06 — Task Notifications
 *
 * Demonstrates:
 *   - Task notification as binary semaphore replacement (45% faster)
 *   - Task notification as counting semaphore replacement
 *   - Task notification as event group (bit flags)
 *   - Task notification as mailbox (value with overwrite)
 *   - Indexed notifications (FreeRTOS v10.4+)
 *   - FromISR notification variants
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 *
 * Key Concept: Every task has a built-in 32-bit notification value and
 * notification state (notWaiting / waiting / pending) as part of its TCB.
 * This means task notifications use ZERO extra RAM and require no
 * creation calls. The trade-off: only one task can wait on a given
 * notification (1:1 signaling, not 1:N).
 */

#include "FreeRTOS.h"
#include "task.h"
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

static TaskHandle_t xDMATaskHandle    = NULL;
static TaskHandle_t xCountingHandle   = NULL;
static TaskHandle_t xEventBitsHandle  = NULL;
static TaskHandle_t xMailboxHandle    = NULL;

/* ---------------------------------------------------------------------------
 * Example 1: Task Notification as Binary Semaphore
 *
 * xTaskNotifyGive / ulTaskNotifyTake replaces binary semaphore for
 * ISR-to-task signaling. The notification value acts as the count.
 *
 * xTaskNotifyGive internally calls xTaskGenericNotify with:
 *   eAction = eIncrement  (notification value += 1)
 *
 * ulTaskNotifyTake with xClearCountOnExit = pdTRUE:
 *   - If notification value > 0: clears to 0, returns the old value, unblocks
 *   - If notification value == 0: blocks until notified or timeout
 *
 * Performance: ~45% faster than xSemaphoreGiveFromISR because:
 *   - No queue structure to lock/unlock
 *   - No item copy (semaphore items are zero-size but still go through queue logic)
 *   - Direct TCB manipulation
 *
 * Limitation: Only ONE task can wait. Notifications are task-specific,
 * so you need the target task's handle to send a notification.
 * --------------------------------------------------------------------------- */
void DMA1_Stream0_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /*
     * vTaskNotifyGiveFromISR increments the target task's notification value.
     * If the target task was blocked in ulTaskNotifyTake, it is unblocked.
     *
     * Internally:
     * 1. Enter critical section (BASEPRI on Cortex-M)
     * 2. Increment pxTCB->ulNotifiedValue[0]
     * 3. If task state == eWaitingNotification, move to ready list
     * 4. Set *pxHigherPriorityTaskWoken if the unblocked task has
     *    higher priority than the currently running task
     * 5. Exit critical section
     */
    vTaskNotifyGiveFromISR(xDMATaskHandle, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vDMAProcessTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /*
         * ulTaskNotifyTake with xClearCountOnExit = pdTRUE:
         *   - Blocks until notification value > 0
         *   - Returns the notification value, then clears it to 0
         *   - This is the binary semaphore pattern
         *
         * With xClearCountOnExit = pdFALSE:
         *   - Returns the value, then decrements by 1
         *   - This is the counting semaphore pattern
         */
        uint32_t count = ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        char buf[80];
        snprintf(buf, sizeof(buf),
                 "[DMA] Transfer complete (notifications pending: %lu)\r\n",
                 (unsigned long)count);
        safe_print(buf);
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Task Notification as Counting Semaphore
 *
 * Using xClearCountOnExit = pdFALSE, each ulTaskNotifyTake call decrements
 * the notification value by 1. This exactly mirrors a counting semaphore
 * where each "give" increments and each "take" decrements.
 * --------------------------------------------------------------------------- */
void vEventProducerTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t events = 0;

    for (;;) {
        events++;

        /* Simulate burst of 3 events */
        if (events % 5 == 0) {
            safe_print("[PRODUCER] Sending 3 events (burst)\r\n");
            xTaskNotifyGive(xCountingHandle);
            xTaskNotifyGive(xCountingHandle);
            xTaskNotifyGive(xCountingHandle);
        } else {
            safe_print("[PRODUCER] Sending 1 event\r\n");
            xTaskNotifyGive(xCountingHandle);
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void vEventCounterTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t total_processed = 0;

    for (;;) {
        /*
         * xClearCountOnExit = pdFALSE: decrement by 1, returns new value.
         * This means if 3 notifications arrived while we were processing,
         * the first take returns 2 (decremented from 3 to 2), the next
         * returns 1, and the last returns 0.
         *
         * After the last decrement (returns 0), the next take will block.
         */
        ulTaskNotifyTake(pdFALSE, portMAX_DELAY);
        total_processed++;

        char buf[80];
        snprintf(buf, sizeof(buf),
                 "[COUNTER] Processed event #%lu\r\n",
                 (unsigned long)total_processed);
        safe_print(buf);

        vTaskDelay(pdMS_TO_TICKS(100));  /* Simulate processing time */
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Task Notification as Event Group (Bit Flags)
 *
 * Using xTaskNotify with eSetBits, the notification value acts as a set
 * of event flags. xTaskNotifyWait reads the flags and optionally clears them.
 *
 * Advantages over xEventGroupWaitBits:
 *   - Faster (no walk of waiting task list)
 *   - No RAM overhead
 *   - All 32 bits available (event groups reserve 8 bits)
 *
 * Limitation: Only one task can wait on a task's notification.
 * --------------------------------------------------------------------------- */
#define NOTIFY_WIFI_CONNECTED   (1 << 0)
#define NOTIFY_DATA_READY       (1 << 1)
#define NOTIFY_UPLOAD_COMPLETE  (1 << 2)
#define NOTIFY_ERROR            (1 << 3)
#define NOTIFY_BATTERY_LOW      (1 << 4)

void vWifiTask(void *pvParameters)
{
    (void)pvParameters;

    vTaskDelay(pdMS_TO_TICKS(1000));

    for (;;) {
        /*
         * xTaskNotify with eSetBits: ORs ulValue into the target
         * task's notification value, similar to xEventGroupSetBits.
         */
        safe_print("[WIFI] Connected — notifying\r\n");
        xTaskNotify(xEventBitsHandle, NOTIFY_WIFI_CONNECTED, eSetBits);
        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}

void vDataCollectorTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(2000));
        safe_print("[DATA] Data ready — notifying\r\n");
        xTaskNotify(xEventBitsHandle, NOTIFY_DATA_READY, eSetBits);
    }
}

void vNotificationEventHandler(void *pvParameters)
{
    (void)pvParameters;
    uint32_t ulNotifiedValue;

    for (;;) {
        /*
         * xTaskNotifyWait parameters:
         *   ulBitsToClearOnEntry: Bits to clear BEFORE checking.
         *     0x00 = don't clear anything on entry.
         *   ulBitsToClearOnExit: Bits to clear AFTER reading.
         *     ULONG_MAX = clear all bits after reading.
         *   pulNotificationValue: Output — the notification value
         *     at the time the wait was satisfied.
         *   xTicksToWait: How long to block.
         *
         * Internal flow:
         * 1. Clear ulBitsToClearOnEntry bits from notification value.
         * 2. If notification state is already "pending" (bit was set
         *    before we started waiting), return immediately with the value.
         * 3. Otherwise, set state to "waiting" and block.
         * 4. When notified, copy value to *pulNotificationValue.
         * 5. Clear ulBitsToClearOnExit bits.
         * 6. Set state to "not waiting".
         */
        BaseType_t result = xTaskNotifyWait(
            0x00,           /* Don't clear on entry */
            0xFFFFFFFF,     /* Clear all on exit */
            &ulNotifiedValue,
            portMAX_DELAY
        );

        if (result == pdTRUE) {
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "[EVT-BITS] Notification value: 0x%08lX\r\n",
                     (unsigned long)ulNotifiedValue);
            safe_print(buf);

            if (ulNotifiedValue & NOTIFY_WIFI_CONNECTED)
                safe_print("  → WiFi connected\r\n");
            if (ulNotifiedValue & NOTIFY_DATA_READY)
                safe_print("  → Data ready\r\n");
            if (ulNotifiedValue & NOTIFY_UPLOAD_COMPLETE)
                safe_print("  → Upload complete\r\n");
            if (ulNotifiedValue & NOTIFY_ERROR)
                safe_print("  → ERROR!\r\n");
            if (ulNotifiedValue & NOTIFY_BATTERY_LOW)
                safe_print("  → Battery low\r\n");
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 4: Task Notification as Mailbox
 *
 * Using eSetValueWithOverwrite, the notification value becomes a 32-bit
 * mailbox that always contains the latest value.
 *
 * eSetValueWithOverwrite: Always sets the value (like xQueueOverwrite).
 * eSetValueWithoutOverwrite: Only sets if the task has already read the
 *   previous value (fails if value is still "pending").
 * --------------------------------------------------------------------------- */
typedef union {
    uint32_t raw;
    struct {
        uint16_t temperature_x10;
        uint8_t  humidity;
        uint8_t  flags;
    } fields;
} MailboxData_t;

void vMailboxWriterTask(void *pvParameters)
{
    (void)pvParameters;
    MailboxData_t data;

    for (;;) {
        static uint16_t temp = 250;
        static uint8_t  hum  = 60;
        temp += 5;
        if (temp > 400) temp = 200;
        hum = (hum + 3) % 100;

        data.fields.temperature_x10 = temp;
        data.fields.humidity        = hum;
        data.fields.flags           = 0x01;  /* data valid flag */

        /*
         * eSetValueWithOverwrite: Set notification value to data.raw,
         * regardless of whether the task has read the previous value.
         * If the task is blocked waiting, it is unblocked.
         */
        xTaskNotify(xMailboxHandle, data.raw, eSetValueWithOverwrite);

        char buf[80];
        snprintf(buf, sizeof(buf),
                 "[MAILBOX-W] Sent: temp=%u.%u°C, hum=%u%%\r\n",
                 temp / 10, temp % 10, hum);
        safe_print(buf);

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void vMailboxReaderTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t ulValue;
    MailboxData_t data;

    for (;;) {
        if (xTaskNotifyWait(0, 0, &ulValue, pdMS_TO_TICKS(2000)) == pdTRUE) {
            data.raw = ulValue;
            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[MAILBOX-R] Received: temp=%u.%u°C, hum=%u%%, flags=0x%02X\r\n",
                     data.fields.temperature_x10 / 10,
                     data.fields.temperature_x10 % 10,
                     data.fields.humidity,
                     data.fields.flags);
            safe_print(buf);
        } else {
            safe_print("[MAILBOX-R] Timeout — no data received\r\n");
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 5: eNoAction — Pure Unblock Without Value Change
 *
 * eNoAction simply unblocks the target task without modifying its
 * notification value. Useful for simple "wake up" signaling.
 * --------------------------------------------------------------------------- */
static TaskHandle_t xSleepyTaskHandle = NULL;

void vWakeupTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(3000));
        safe_print("[WAKEUP] Waking sleepy task\r\n");
        xTaskNotify(xSleepyTaskHandle, 0, eNoAction);
    }
}

void vSleepyTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        safe_print("[SLEEPY] Going to sleep...\r\n");
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        safe_print("[SLEEPY] Woke up! Doing work...\r\n");
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/* ---------------------------------------------------------------------------
 * Example 6: eSetValueWithoutOverwrite — Conditional Set
 *
 * Only updates the notification value if the task has already consumed
 * the previous one. Returns pdFAIL if the previous value hasn't been
 * read yet (notification state is still "pending").
 *
 * Use case: Avoid overwriting commands that haven't been processed yet.
 * --------------------------------------------------------------------------- */
static TaskHandle_t xCmdTaskHandle = NULL;

void vCommandSender(void *pvParameters)
{
    (void)pvParameters;
    uint32_t cmd = 0;

    for (;;) {
        cmd++;

        if (xTaskNotify(xCmdTaskHandle, cmd, eSetValueWithoutOverwrite) == pdPASS) {
            char buf[64];
            snprintf(buf, sizeof(buf),
                     "[CMD-TX] Command %lu sent\r\n", (unsigned long)cmd);
            safe_print(buf);
        } else {
            char buf[64];
            snprintf(buf, sizeof(buf),
                     "[CMD-TX] Command %lu DROPPED (previous not read)\r\n",
                     (unsigned long)cmd);
            safe_print(buf);
        }

        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

void vCommandReceiver(void *pvParameters)
{
    (void)pvParameters;
    uint32_t ulCmd;

    for (;;) {
        if (xTaskNotifyWait(0, 0xFFFFFFFF, &ulCmd, portMAX_DELAY) == pdTRUE) {
            char buf[64];
            snprintf(buf, sizeof(buf),
                     "[CMD-RX] Processing command %lu\r\n", (unsigned long)ulCmd);
            safe_print(buf);
            vTaskDelay(pdMS_TO_TICKS(800));
        }
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

    /* Binary semaphore replacement (DMA) */
    xTaskCreate(vDMAProcessTask, "DMA", 256, NULL, 4, &xDMATaskHandle);

    /* Counting semaphore replacement */
    xTaskCreate(vEventCounterTask,  "Counter",  256, NULL, 3, &xCountingHandle);
    xTaskCreate(vEventProducerTask, "Producer", 256, NULL, 2, NULL);

    /* Event group replacement */
    xTaskCreate(vNotificationEventHandler, "EvtHdl",  256, NULL, 3, &xEventBitsHandle);
    xTaskCreate(vWifiTask,                 "WiFi",    256, NULL, 2, NULL);
    xTaskCreate(vDataCollectorTask,        "DataCol", 256, NULL, 2, NULL);

    /* Mailbox */
    xTaskCreate(vMailboxReaderTask, "MboxR", 256, NULL, 2, &xMailboxHandle);
    xTaskCreate(vMailboxWriterTask, "MboxW", 256, NULL, 2, NULL);

    /* eNoAction pure unblock */
    xTaskCreate(vSleepyTask, "Sleepy", 256, NULL, 2, &xSleepyTaskHandle);
    xTaskCreate(vWakeupTask, "Wakeup", 256, NULL, 2, NULL);

    /* eSetValueWithoutOverwrite */
    xTaskCreate(vCommandReceiver, "CmdRX", 256, NULL, 2, &xCmdTaskHandle);
    xTaskCreate(vCommandSender,   "CmdTX", 256, NULL, 2, NULL);

    vTaskStartScheduler();
    for (;;);
}
