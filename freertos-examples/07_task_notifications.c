/**
 * FreeRTOS Example 07: Task Notifications
 *
 * Demonstrates:
 *   - Task notifications as binary semaphore replacement
 *   - Task notifications as counting semaphore replacement
 *   - Task notifications as event group replacement
 *   - Task notifications as lightweight mailbox
 *   - Indexed notifications (multiple notification slots per task)
 *   - Performance comparison patterns
 *
 * Internal details:
 *   Each task has a built-in notification array (size = configTASK_NOTIFICATION_ARRAY_ENTRIES,
 *   default 1). Each slot contains:
 *     - ulNotifiedValue[i]: a 32-bit value
 *     - ucNotifyState[i]: one of:
 *         taskNOT_WAITING_NOTIFICATION (0) — not waiting
 *         taskWAITING_NOTIFICATION (1) — blocked on this slot
 *         taskNOTIFICATION_RECEIVED (2) — notification pending
 *
 *   Sending a notification (xTaskNotify):
 *     1. Modify ulNotifiedValue according to eAction
 *     2. Set ucNotifyState = taskNOTIFICATION_RECEIVED
 *     3. If the target task was in WAITING state, move it to the ready list
 *
 *   Receiving a notification (ulTaskNotifyTake / xTaskNotifyWait):
 *     1. If ucNotifyState == RECEIVED: return the value, optionally clear/decrement
 *     2. If ucNotifyState != RECEIVED: set state to WAITING, block
 *
 *   Performance advantages over semaphores:
 *     - No separate kernel object needed (no pvPortMalloc)
 *     - No queue structure overhead (saves ~80 bytes per notification)
 *     - ~45% faster than semaphore give/take (fewer list operations)
 *     - Notification value and state stored directly in the TCB
 *
 *   Limitations:
 *     - Only the target task can receive (unidirectional)
 *     - Cannot broadcast to multiple tasks
 *     - Task handle must be known to the sender
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Simulated Hardware                                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

static void uart_printf(const char *fmt, ...) { (void)fmt; }

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: Binary Semaphore Replacement                                   */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xTaskNotifyGive / ulTaskNotifyTake provide a lightweight alternative
 * to binary semaphores for ISR-to-task signaling.
 *
 * xTaskNotifyGive(xTask):
 *   - Equivalent to xTaskNotify(xTask, 0, eIncrement)
 *   - Increments the target task's notification value
 *   - Sets notification state to RECEIVED
 *   - Unblocks the task if it was waiting
 *
 * ulTaskNotifyTake(xClearCountOnExit, xTicksToWait):
 *   - If xClearCountOnExit == pdTRUE: clears notification value to 0 on return
 *     (binary semaphore behavior)
 *   - If xClearCountOnExit == pdFALSE: decrements notification value by 1
 *     (counting semaphore behavior)
 *   - Returns the notification value BEFORE clear/decrement
 *   - Blocks if notification value is 0
 */

static TaskHandle_t xUARTHandlerTaskHandle;

void USART1_IRQHandler_v2(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Minimal ISR work: clear flag, signal task */
    /* USART1->SR &= ~USART_SR_RXNE; */

    /**
     * vTaskNotifyGiveFromISR:
     *   ISR-safe version of xTaskNotifyGive.
     *   Internally:
     *     1. Increments ulNotifiedValue[0] of the target task
     *     2. If the task was in WAITING state:
     *        - Removes it from the delayed task list
     *        - Adds it to the ready list (or pending ready list if scheduler suspended)
     *        - Sets *pxHigherPriorityTaskWoken if needed
     *     3. Uses the queue lock mechanism for thread safety
     */
    vTaskNotifyGiveFromISR(xUARTHandlerTaskHandle, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void vUARTHandlerTask_v2(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        /* pdTRUE = clear to 0 on exit (binary semaphore behavior).
           Blocks until notification is received. */
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        uart_printf("[%lu] UART handler: processing data (via notification)\r\n",
                     xTaskGetTickCount());
    }
}

static void example1_binary_replacement(void) {
    xTaskCreate(vUARTHandlerTask_v2, "UARTHdl2", 256, NULL, 5, &xUARTHandlerTaskHandle);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: Counting Semaphore Replacement                                 */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Using ulTaskNotifyTake with xClearCountOnExit == pdFALSE gives counting
 * semaphore behavior: each give increments, each take decrements.
 *
 * If the ISR fires 5 times before the task runs, the notification value
 * will be 5, and the task will process all 5 events (one take per iteration).
 */

static TaskHandle_t xCountingTaskHandle;

void TIM3_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Clear timer interrupt flag */
    /* TIM3->SR &= ~TIM_SR_UIF; */

    vTaskNotifyGiveFromISR(xCountingTaskHandle, &xHigherPriorityTaskWoken);
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void vCountingTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulTotalEvents = 0;

    for (;;) {
        /* pdFALSE = decrement by 1 (counting semaphore behavior).
           Returns the value BEFORE decrement. */
        uint32_t ulCount = ulTaskNotifyTake(pdFALSE, portMAX_DELAY);
        ulTotalEvents++;

        uart_printf("[%lu] Event processed (returned count: %lu, total: %lu)\r\n",
                     xTaskGetTickCount(), ulCount, ulTotalEvents);

        /* Simulate processing time */
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

static void example2_counting_replacement(void) {
    xTaskCreate(vCountingTask, "Counting", 256, NULL, 3, &xCountingTaskHandle);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: Event Group Replacement (Bit Flags)                            */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xTaskNotify with eSetBits performs a bitwise OR on the notification value,
 * similar to xEventGroupSetBits. xTaskNotifyWait can test and clear bits.
 *
 * Advantages over event groups:
 *   - Faster (no list traversal)
 *   - No separate kernel object
 *   - Full 32-bit flag space (event groups only have 24 bits)
 *
 * Limitation: only one task can wait (the target task), whereas event groups
 * allow multiple tasks to wait on the same bits.
 */

#define NOTIFY_WIFI_CONNECTED   (1 << 0)
#define NOTIFY_NTP_SYNCED       (1 << 1)
#define NOTIFY_MQTT_CONNECTED   (1 << 2)
#define NOTIFY_SENSOR_READY     (1 << 3)
#define NOTIFY_ALL_READY        (NOTIFY_WIFI_CONNECTED | NOTIFY_NTP_SYNCED | \
                                 NOTIFY_MQTT_CONNECTED | NOTIFY_SENSOR_READY)

static TaskHandle_t xMainControlTaskHandle;

static void vWiFiTask(void *pvParameters) {
    (void)pvParameters;

    vTaskDelay(pdMS_TO_TICKS(500)); /* Simulate WiFi connect time */

    /**
     * xTaskNotify(xTask, ulValue, eSetBits):
     *   - Performs: target->ulNotifiedValue |= ulValue
     *   - Sets target's ucNotifyState to RECEIVED
     *   - Unblocks the target if it was waiting
     */
    xTaskNotify(xMainControlTaskHandle, NOTIFY_WIFI_CONNECTED, eSetBits);
    uart_printf("[%lu] WiFi: connected, notified main\r\n", xTaskGetTickCount());

    vTaskDelete(NULL);
}

static void vNTPTask(void *pvParameters) {
    (void)pvParameters;
    vTaskDelay(pdMS_TO_TICKS(800));
    xTaskNotify(xMainControlTaskHandle, NOTIFY_NTP_SYNCED, eSetBits);
    uart_printf("[%lu] NTP: synced, notified main\r\n", xTaskGetTickCount());
    vTaskDelete(NULL);
}

static void vMQTTTask(void *pvParameters) {
    (void)pvParameters;
    vTaskDelay(pdMS_TO_TICKS(1200));
    xTaskNotify(xMainControlTaskHandle, NOTIFY_MQTT_CONNECTED, eSetBits);
    uart_printf("[%lu] MQTT: connected, notified main\r\n", xTaskGetTickCount());
    vTaskDelete(NULL);
}

static void vSensorInitTask(void *pvParameters) {
    (void)pvParameters;
    vTaskDelay(pdMS_TO_TICKS(300));
    xTaskNotify(xMainControlTaskHandle, NOTIFY_SENSOR_READY, eSetBits);
    uart_printf("[%lu] Sensor: ready, notified main\r\n", xTaskGetTickCount());
    vTaskDelete(NULL);
}

static void vMainControlTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulNotifiedValue;
    uint32_t ulAccumulatedBits = 0;

    uart_printf("[%lu] Main: waiting for all subsystems...\r\n", xTaskGetTickCount());

    /* Wait for all bits to be set (may require multiple waits since
       xTaskNotifyWait can return when ANY bit changes) */
    while ((ulAccumulatedBits & NOTIFY_ALL_READY) != NOTIFY_ALL_READY) {
        /**
         * xTaskNotifyWait:
         *
         * Parameters:
         *   ulBitsToClearOnEntry — bits to clear in ulNotifiedValue BEFORE checking
         *   ulBitsToClearOnExit  — bits to clear AFTER a notification is received
         *   pulNotificationValue — output: notification value when event occurred
         *   xTicksToWait         — timeout
         *
         * Returns pdPASS if a notification was received, pdFAIL on timeout.
         *
         * Internal flow:
         *   1. Clear bits specified by ulBitsToClearOnEntry
         *   2. If ucNotifyState == RECEIVED:
         *      - Copy ulNotifiedValue to *pulNotificationValue
         *      - Clear bits specified by ulBitsToClearOnExit
         *      - Set ucNotifyState = NOT_WAITING
         *      - Return pdPASS
         *   3. If ucNotifyState != RECEIVED:
         *      - Set ucNotifyState = WAITING
         *      - Block for up to xTicksToWait
         *      - When woken: copy value, clear exit bits, return pdPASS
         *      - On timeout: return pdFAIL
         */
        if (xTaskNotifyWait(
                0x00,              /* Don't clear any bits on entry */
                0xFFFFFFFF,        /* Clear all bits on exit */
                &ulNotifiedValue,
                pdMS_TO_TICKS(5000)
            ) == pdPASS) {

            ulAccumulatedBits |= ulNotifiedValue;

            uart_printf("[%lu] Main: received bits 0x%08lX (accumulated: 0x%08lX)\r\n",
                         xTaskGetTickCount(), ulNotifiedValue, ulAccumulatedBits);
        } else {
            uart_printf("[%lu] Main: TIMEOUT waiting for subsystems\r\n",
                         xTaskGetTickCount());
            break;
        }
    }

    if ((ulAccumulatedBits & NOTIFY_ALL_READY) == NOTIFY_ALL_READY) {
        uart_printf("[%lu] Main: all subsystems ready!\r\n", xTaskGetTickCount());
    }

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void example3_event_replacement(void) {
    xTaskCreate(vMainControlTask, "MainCtrl", 512, NULL, 3, &xMainControlTaskHandle);
    xTaskCreate(vWiFiTask,        "WiFi",     256, NULL, 2, NULL);
    xTaskCreate(vNTPTask,         "NTP",      256, NULL, 2, NULL);
    xTaskCreate(vMQTTTask,        "MQTT",     256, NULL, 2, NULL);
    xTaskCreate(vSensorInitTask,  "SnsInit",  256, NULL, 2, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: Lightweight Mailbox (Value Passing)                            */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * eSetValueWithOverwrite: sets ulNotifiedValue = ulValue, always succeeds.
 * This is like xQueueOverwrite on a length-1 queue — the latest value wins.
 *
 * eSetValueWithoutOverwrite: sets ulNotifiedValue = ulValue ONLY if the
 * previous notification was already consumed (ucNotifyState != RECEIVED).
 * This is like xQueueSend on a length-1 queue — blocks/fails if pending.
 */

static TaskHandle_t xDisplayTaskHandle;

typedef union {
    uint32_t ulRaw;
    struct {
        int16_t  sTemperature; /* Temperature * 10 (fixed-point) */
        uint16_t usHumidity;   /* Humidity * 10 */
    } fields;
} SensorPacket_t;

static void vSensorProducerTask(void *pvParameters) {
    (void)pvParameters;
    SensorPacket_t xPacket;
    int16_t sTemp = 220; /* 22.0 C */

    for (;;) {
        xPacket.fields.sTemperature = sTemp;
        xPacket.fields.usHumidity   = 550;  /* 55.0 % */
        sTemp += 1;
        if (sTemp > 350) sTemp = 200;

        /**
         * eSetValueWithOverwrite:
         *   - Always sets ulNotifiedValue = ulValue
         *   - Always sets ucNotifyState = RECEIVED
         *   - If the target task was WAITING, unblocks it
         *   - If a previous value was pending but not consumed, it is OVERWRITTEN
         *   - This is the "latest value wins" pattern
         */
        xTaskNotify(xDisplayTaskHandle, xPacket.ulRaw, eSetValueWithOverwrite);

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

static void vDisplayTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulNotifiedValue;
    SensorPacket_t xPacket;

    for (;;) {
        if (xTaskNotifyWait(0, 0xFFFFFFFF, &ulNotifiedValue, portMAX_DELAY) == pdPASS) {
            xPacket.ulRaw = ulNotifiedValue;
            uart_printf("[%lu] Display: T=%.1f C, H=%.1f %%\r\n",
                         xTaskGetTickCount(),
                         (float)xPacket.fields.sTemperature / 10.0f,
                         (float)xPacket.fields.usHumidity / 10.0f);
        }

        vTaskDelay(pdMS_TO_TICKS(500)); /* Display updates at 2 Hz */
    }
}

static void example4_mailbox(void) {
    xTaskCreate(vDisplayTask,          "Display", 256, NULL, 2, &xDisplayTaskHandle);
    xTaskCreate(vSensorProducerTask,   "SensProd", 256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 5: Indexed Notifications (Multiple Slots)                         */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * When configTASK_NOTIFICATION_ARRAY_ENTRIES > 1, each task has multiple
 * independent notification slots. Different subsystems can use different
 * slots without interfering with each other.
 *
 * xTaskNotifyIndexed(xTask, uxIndex, ulValue, eAction)
 * xTaskNotifyWaitIndexed(uxIndex, ulBitsToClearOnEntry, ulBitsToClearOnExit,
 *                         pulNotifiedValue, xTicksToWait)
 *
 * Slot 0 is the default (used by xTaskNotify/xTaskNotifyWait).
 * Additional slots are accessed via the Indexed variants.
 */

#if (configTASK_NOTIFICATION_ARRAY_ENTRIES >= 3)

#define NOTIFY_IDX_COMMAND  0  /* Slot 0: command from supervisor */
#define NOTIFY_IDX_DATA     1  /* Slot 1: data available flag */
#define NOTIFY_IDX_STATUS   2  /* Slot 2: status updates */

static TaskHandle_t xMultiSlotTaskHandle;

static void vMultiSlotTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulValue;

    for (;;) {
        /* Check command slot (index 0) — non-blocking */
        if (xTaskNotifyWaitIndexed(NOTIFY_IDX_COMMAND, 0, 0xFFFFFFFF,
                                    &ulValue, 0) == pdPASS) {
            uart_printf("[%lu] Received command: 0x%08lX\r\n",
                         xTaskGetTickCount(), ulValue);
        }

        /* Check data slot (index 1) — non-blocking */
        if (xTaskNotifyWaitIndexed(NOTIFY_IDX_DATA, 0, 0xFFFFFFFF,
                                    &ulValue, 0) == pdPASS) {
            uart_printf("[%lu] Data available signal: %lu\r\n",
                         xTaskGetTickCount(), ulValue);
        }

        /* Wait on status slot (index 2) — blocking with timeout */
        if (xTaskNotifyWaitIndexed(NOTIFY_IDX_STATUS, 0, 0xFFFFFFFF,
                                    &ulValue, pdMS_TO_TICKS(100)) == pdPASS) {
            uart_printf("[%lu] Status update: 0x%08lX\r\n",
                         xTaskGetTickCount(), ulValue);
        }
    }
}

static void vCommandSender(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulCmd = 0;

    for (;;) {
        ulCmd++;
        xTaskNotifyIndexed(xMultiSlotTaskHandle, NOTIFY_IDX_COMMAND,
                           ulCmd, eSetValueWithOverwrite);
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

static void vDataFlagSender(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        xTaskNotifyGiveIndexed(xMultiSlotTaskHandle, NOTIFY_IDX_DATA);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vStatusSender(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        uint32_t ulStatus = 0x00FF0000 | xTaskGetTickCount();
        xTaskNotifyIndexed(xMultiSlotTaskHandle, NOTIFY_IDX_STATUS,
                           ulStatus, eSetValueWithOverwrite);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void example5_indexed_notifications(void) {
    xTaskCreate(vMultiSlotTask,  "MultiSlot", 512, NULL, 3, &xMultiSlotTaskHandle);
    xTaskCreate(vCommandSender,  "CmdSend",   256, NULL, 2, NULL);
    xTaskCreate(vDataFlagSender, "DataFlag",  256, NULL, 2, NULL);
    xTaskCreate(vStatusSender,   "StatSend",  256, NULL, 2, NULL);
}

#endif /* configTASK_NOTIFICATION_ARRAY_ENTRIES >= 3 */

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 6: Notification State Management                                  */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xTaskNotifyStateClear(xTask):
 *   - Sets ucNotifyState to taskNOT_WAITING_NOTIFICATION
 *   - Does NOT change ulNotifiedValue
 *   - Useful when you want to clear a pending notification without consuming the value
 *
 * ulTaskNotifyValueClear(xTask, ulBitsToClear):
 *   - Performs: ulNotifiedValue &= ~ulBitsToClear
 *   - Returns the value BEFORE clearing
 *   - Useful for selectively clearing bits without full xTaskNotifyWait
 */

static TaskHandle_t xStateMgmtTaskHandle;

static void vStateMgmtTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulValue;

    for (;;) {
        /* Wait for any notification */
        if (xTaskNotifyWait(0, 0, &ulValue, pdMS_TO_TICKS(1000)) == pdPASS) {
            uart_printf("[%lu] Notification received: 0x%08lX\r\n",
                         xTaskGetTickCount(), ulValue);

            /* Clear specific bits we've handled */
            uint32_t ulOldValue = ulTaskNotifyValueClear(NULL, 0x000000FF);
            uart_printf("[%lu] Cleared low byte. Value was: 0x%08lX\r\n",
                         xTaskGetTickCount(), ulOldValue);
        }

        /* Periodically check and clear notification state */
        xTaskNotifyStateClear(NULL);
    }
}

static void vNotifySenderTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulVal = 0;

    for (;;) {
        ulVal += 0x11;
        xTaskNotify(xStateMgmtTaskHandle, ulVal, eSetValueWithOverwrite);
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

static void example6_state_management(void) {
    xTaskCreate(vStateMgmtTask,    "StateMgmt", 256, NULL, 3, &xStateMgmtTaskHandle);
    xTaskCreate(vNotifySenderTask, "NotifySend", 256, NULL, 2, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main                                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) { }
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName; for (;;) { }
}

int main(void) {
    example1_binary_replacement();
    example2_counting_replacement();
    example3_event_replacement();
    example4_mailbox();
#if (configTASK_NOTIFICATION_ARRAY_ENTRIES >= 3)
    example5_indexed_notifications();
#endif
    example6_state_management();

    vTaskStartScheduler();
    for (;;) { }
    return 0;
}
