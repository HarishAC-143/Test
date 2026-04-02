/**
 * FreeRTOS Example 05: Event Groups
 *
 * Demonstrates:
 *   - Event group creation and bit operations
 *   - Waiting for ANY bit (OR logic)
 *   - Waiting for ALL bits (AND logic)
 *   - Auto-clearing bits on exit
 *   - xEventGroupSync for task rendezvous/barrier
 *   - ISR-to-task signaling with event groups
 *   - Multi-stage initialization synchronization
 *
 * Internal details:
 *   An event group stores up to 24 bits (upper 8 of 32-bit word reserved
 *   for kernel control flags). The structure contains:
 *   - uxEventBits: the actual bit storage
 *   - xTasksWaitingForBits: list of blocked tasks with their conditions
 *
 *   When bits are set (xEventGroupSetBits):
 *   1. Set the requested bits in uxEventBits
 *   2. Walk xTasksWaitingForBits and evaluate each task's condition
 *   3. For each task whose condition is now met:
 *      - If xClearOnExit was set, clear those bits
 *      - Move the task to the ready list
 *   4. Yield if any unblocked task has higher priority
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include "event_groups.h"
#include <stdint.h>
#include <stdio.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Simulated Hardware                                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

static void uart_printf(const char *fmt, ...) { (void)fmt; }

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: System Initialization with Event Group                         */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Use case: Multiple subsystems initialize independently. The main application
 * task must wait until ALL subsystems are ready before proceeding.
 *
 * Each subsystem sets its bit when initialization is complete.
 * The main task waits for ALL bits with xWaitForAllBits = pdTRUE (AND logic).
 */

#define EVT_WIFI_READY     (1 << 0)
#define EVT_SENSOR_READY   (1 << 1)
#define EVT_STORAGE_READY  (1 << 2)
#define EVT_DISPLAY_READY  (1 << 3)
#define EVT_ALL_READY      (EVT_WIFI_READY | EVT_SENSOR_READY | EVT_STORAGE_READY | EVT_DISPLAY_READY)

static EventGroupHandle_t xInitEventGroup;

static void vWiFiInitTask(void *pvParameters) {
    (void)pvParameters;
    uart_printf("[%lu] WiFi: initializing...\r\n", xTaskGetTickCount());

    vTaskDelay(pdMS_TO_TICKS(800)); /* Simulate WiFi connection time */

    uart_printf("[%lu] WiFi: connected!\r\n", xTaskGetTickCount());

    /**
     * xEventGroupSetBits(xEventGroup, uxBitsToSet):
     *   - Atomically ORs uxBitsToSet into uxEventBits
     *   - Evaluates all waiting tasks' conditions
     *   - Unblocks any task whose condition is now met
     *   - Returns the event bits AFTER setting (may already have cleared
     *     bits if a waiting task had xClearOnExit set)
     */
    xEventGroupSetBits(xInitEventGroup, EVT_WIFI_READY);

    vTaskDelete(NULL);
}

static void vSensorInitTask(void *pvParameters) {
    (void)pvParameters;
    uart_printf("[%lu] Sensor: calibrating...\r\n", xTaskGetTickCount());
    vTaskDelay(pdMS_TO_TICKS(500));
    uart_printf("[%lu] Sensor: ready!\r\n", xTaskGetTickCount());
    xEventGroupSetBits(xInitEventGroup, EVT_SENSOR_READY);
    vTaskDelete(NULL);
}

static void vStorageInitTask(void *pvParameters) {
    (void)pvParameters;
    uart_printf("[%lu] Storage: mounting filesystem...\r\n", xTaskGetTickCount());
    vTaskDelay(pdMS_TO_TICKS(1200));
    uart_printf("[%lu] Storage: mounted!\r\n", xTaskGetTickCount());
    xEventGroupSetBits(xInitEventGroup, EVT_STORAGE_READY);
    vTaskDelete(NULL);
}

static void vDisplayInitTask(void *pvParameters) {
    (void)pvParameters;
    uart_printf("[%lu] Display: initializing...\r\n", xTaskGetTickCount());
    vTaskDelay(pdMS_TO_TICKS(300));
    uart_printf("[%lu] Display: ready!\r\n", xTaskGetTickCount());
    xEventGroupSetBits(xInitEventGroup, EVT_DISPLAY_READY);
    vTaskDelete(NULL);
}

static void vMainAppTask(void *pvParameters) {
    (void)pvParameters;

    uart_printf("[%lu] Main: waiting for all subsystems...\r\n", xTaskGetTickCount());

    /**
     * xEventGroupWaitBits:
     *
     * Parameters:
     *   xEventGroup      — the event group to wait on
     *   uxBitsToWaitFor   — bit mask of bits to test
     *   xClearOnExit      — pdTRUE: clear uxBitsToWaitFor bits when returning
     *   xWaitForAllBits   — pdTRUE: AND (all bits), pdFALSE: OR (any bit)
     *   xTicksToWait      — timeout
     *
     * Returns: the event bits at the moment the condition was met or timeout.
     * You MUST check the return value to distinguish success from timeout.
     *
     * Internal algorithm:
     *   1. Read current uxEventBits
     *   2. Test condition: (bits & mask) == mask for AND, != 0 for OR
     *   3. If met: optionally clear bits, return
     *   4. If not met: encode the wait condition in xEventListItem.xItemValue
     *      (upper bits store xClearOnExit and xWaitForAllBits flags)
     *   5. Add task to xTasksWaitingForBits
     *   6. Add task to delayed list (for timeout)
     *   7. Yield
     */
    EventBits_t uxBits = xEventGroupWaitBits(
        xInitEventGroup,
        EVT_ALL_READY,       /* Wait for all 4 subsystem bits */
        pdTRUE,              /* Clear the bits on exit */
        pdTRUE,              /* AND: require ALL bits */
        pdMS_TO_TICKS(10000) /* 10 second timeout */
    );

    if ((uxBits & EVT_ALL_READY) == EVT_ALL_READY) {
        uart_printf("[%lu] Main: ALL subsystems ready! Starting application.\r\n",
                     xTaskGetTickCount());
    } else {
        uart_printf("[%lu] Main: TIMEOUT! Missing subsystems: ", xTaskGetTickCount());
        if (!(uxBits & EVT_WIFI_READY))    uart_printf("WiFi ");
        if (!(uxBits & EVT_SENSOR_READY))  uart_printf("Sensor ");
        if (!(uxBits & EVT_STORAGE_READY)) uart_printf("Storage ");
        if (!(uxBits & EVT_DISPLAY_READY)) uart_printf("Display ");
        uart_printf("\r\n");
    }

    for (;;) {
        uart_printf("[%lu] Main: application running\r\n", xTaskGetTickCount());
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void example1_init_sync(void) {
    xInitEventGroup = xEventGroupCreate();
    configASSERT(xInitEventGroup != NULL);

    xTaskCreate(vWiFiInitTask,    "WiFiInit",    256, NULL, 2, NULL);
    xTaskCreate(vSensorInitTask,  "SensorInit",  256, NULL, 2, NULL);
    xTaskCreate(vStorageInitTask, "StorageInit", 256, NULL, 2, NULL);
    xTaskCreate(vDisplayInitTask, "DispInit",    256, NULL, 2, NULL);
    xTaskCreate(vMainAppTask,     "MainApp",     512, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: OR Wait — React to Any Event                                   */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Wait for ANY of several events. This is like a "select" on multiple
 * event sources. More memory-efficient than queue sets for simple
 * bit-flag events.
 */

#define EVT_BUTTON_PRESS   (1 << 0)
#define EVT_TIMER_EXPIRED  (1 << 1)
#define EVT_DATA_RECEIVED  (1 << 2)
#define EVT_ERROR_DETECTED (1 << 3)

static EventGroupHandle_t xAppEventGroup;

static void vEventProducerTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulCycle = 0;

    for (;;) {
        ulCycle++;

        switch (ulCycle % 4) {
            case 0:
                xEventGroupSetBits(xAppEventGroup, EVT_BUTTON_PRESS);
                break;
            case 1:
                xEventGroupSetBits(xAppEventGroup, EVT_TIMER_EXPIRED);
                break;
            case 2:
                xEventGroupSetBits(xAppEventGroup, EVT_DATA_RECEIVED);
                break;
            case 3:
                /* Set multiple bits at once */
                xEventGroupSetBits(xAppEventGroup, EVT_DATA_RECEIVED | EVT_ERROR_DETECTED);
                break;
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vEventHandlerTask(void *pvParameters) {
    (void)pvParameters;
    const EventBits_t uxAllEvents = EVT_BUTTON_PRESS | EVT_TIMER_EXPIRED |
                                     EVT_DATA_RECEIVED | EVT_ERROR_DETECTED;

    for (;;) {
        /* Wait for ANY event bit to be set */
        EventBits_t uxBits = xEventGroupWaitBits(
            xAppEventGroup,
            uxAllEvents,
            pdTRUE,              /* Clear matched bits on exit */
            pdFALSE,             /* OR: any bit triggers wake-up */
            portMAX_DELAY
        );

        /* Process all events that were set */
        if (uxBits & EVT_BUTTON_PRESS) {
            uart_printf("[%lu] Event: Button pressed\r\n", xTaskGetTickCount());
        }
        if (uxBits & EVT_TIMER_EXPIRED) {
            uart_printf("[%lu] Event: Timer expired\r\n", xTaskGetTickCount());
        }
        if (uxBits & EVT_DATA_RECEIVED) {
            uart_printf("[%lu] Event: Data received\r\n", xTaskGetTickCount());
        }
        if (uxBits & EVT_ERROR_DETECTED) {
            uart_printf("[%lu] Event: ERROR detected!\r\n", xTaskGetTickCount());
        }
    }
}

static void example2_or_wait(void) {
    xAppEventGroup = xEventGroupCreate();
    configASSERT(xAppEventGroup != NULL);

    xTaskCreate(vEventProducerTask, "EvtProd",  256, NULL, 2, NULL);
    xTaskCreate(vEventHandlerTask,  "EvtHandler", 256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: xEventGroupSync — Task Barrier / Rendezvous                    */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xEventGroupSync:
 *   Atomically:
 *     1. Sets the bits specified by uxBitsToSet (this task's "arrival" signal)
 *     2. Waits for ALL bits in uxBitsToWaitFor to be set (everyone else arrived)
 *     3. Clears ALL matched bits on exit
 *
 * This implements a classic barrier synchronization pattern.
 * N tasks independently compute a phase, then synchronize at the barrier
 * before proceeding to the next phase.
 *
 * Internal implementation:
 *   - Same as xEventGroupSetBits + xEventGroupWaitBits combined
 *   - But done atomically: no window where this task's bits are set
 *     but it hasn't started waiting yet
 */

#define WORKER_0_BIT  (1 << 0)
#define WORKER_1_BIT  (1 << 1)
#define WORKER_2_BIT  (1 << 2)
#define ALL_WORKERS   (WORKER_0_BIT | WORKER_1_BIT | WORKER_2_BIT)

static EventGroupHandle_t xBarrierGroup;

static void vSyncWorkerTask(void *pvParameters) {
    uint32_t ulWorkerId = (uint32_t)(uintptr_t)pvParameters;
    EventBits_t uxMyBit = (1 << ulWorkerId);
    uint32_t ulPhase = 0;

    for (;;) {
        ulPhase++;

        /* Phase work — each worker takes different time */
        TickType_t xWorkTime = pdMS_TO_TICKS(200 + ulWorkerId * 300);
        uart_printf("[%lu] Worker %lu: starting phase %lu (work time: %lu ms)\r\n",
                     xTaskGetTickCount(), ulWorkerId, ulPhase,
                     (unsigned long)(xWorkTime / portTICK_PERIOD_MS));

        vTaskDelay(xWorkTime);

        uart_printf("[%lu] Worker %lu: phase %lu complete, waiting at barrier\r\n",
                     xTaskGetTickCount(), ulWorkerId, ulPhase);

        /* Synchronize: set my bit and wait for all workers */
        EventBits_t uxResult = xEventGroupSync(
            xBarrierGroup,
            uxMyBit,        /* Set: signal that this worker is done */
            ALL_WORKERS,    /* Wait: for all 3 workers to signal */
            pdMS_TO_TICKS(10000)
        );

        if ((uxResult & ALL_WORKERS) == ALL_WORKERS) {
            uart_printf("[%lu] Worker %lu: barrier passed — all workers synchronized\r\n",
                         xTaskGetTickCount(), ulWorkerId);
        } else {
            uart_printf("[%lu] Worker %lu: BARRIER TIMEOUT — some workers missing\r\n",
                         xTaskGetTickCount(), ulWorkerId);
        }
    }
}

static void example3_barrier(void) {
    xBarrierGroup = xEventGroupCreate();
    configASSERT(xBarrierGroup != NULL);

    for (uint32_t i = 0; i < 3; i++) {
        char name[12];
        snprintf(name, sizeof(name), "Worker%lu", (unsigned long)i);
        xTaskCreate(vSyncWorkerTask, name, 256, (void *)(uintptr_t)i, 2, NULL);
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: ISR Event Signaling                                            */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xEventGroupSetBitsFromISR:
 *   Unlike xSemaphoreGiveFromISR which directly modifies kernel lists,
 *   setting event group bits can unblock MULTIPLE tasks and requires
 *   evaluating complex conditions. This work must not be done in an ISR.
 *
 *   Instead, xEventGroupSetBitsFromISR sends a command to the timer
 *   daemon task's queue. The daemon task (running at configTIMER_TASK_PRIORITY)
 *   processes the command and calls xEventGroupSetBits in task context.
 *
 *   Implication: there is a small delay between the ISR and the bits being
 *   set, equal to the time until the timer daemon task runs.
 *
 *   configTIMER_TASK_PRIORITY should be set high (e.g., configMAX_PRIORITIES - 1)
 *   to minimize this latency.
 */

#define EVT_DMA_COMPLETE   (1 << 4)
#define EVT_UART_RX_READY  (1 << 5)

static EventGroupHandle_t xISREventGroup;

void DMA1_Channel1_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Clear DMA interrupt flag */
    /* DMA1->IFCR = DMA_IFCR_CTCIF1; */

    xEventGroupSetBitsFromISR(
        xISREventGroup,
        EVT_DMA_COMPLETE,
        &xHigherPriorityTaskWoken
    );

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void USART2_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Read data, clear flag */

    xEventGroupSetBitsFromISR(
        xISREventGroup,
        EVT_UART_RX_READY,
        &xHigherPriorityTaskWoken
    );

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void vISREventTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        EventBits_t uxBits = xEventGroupWaitBits(
            xISREventGroup,
            EVT_DMA_COMPLETE | EVT_UART_RX_READY,
            pdTRUE,      /* Clear on exit */
            pdFALSE,     /* OR — any event */
            portMAX_DELAY
        );

        if (uxBits & EVT_DMA_COMPLETE) {
            uart_printf("[%lu] ISR Event: DMA transfer completed\r\n",
                         xTaskGetTickCount());
        }
        if (uxBits & EVT_UART_RX_READY) {
            uart_printf("[%lu] ISR Event: UART data received\r\n",
                         xTaskGetTickCount());
        }
    }
}

static void example4_isr_events(void) {
    xISREventGroup = xEventGroupCreate();
    configASSERT(xISREventGroup != NULL);

    xTaskCreate(vISREventTask, "ISREvt", 256, NULL, 4, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 5: Clearing Bits                                                  */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xEventGroupClearBits(xEventGroup, uxBitsToClear):
 *   - Clears specified bits from uxEventBits
 *   - Returns the value of uxEventBits BEFORE clearing
 *   - Can be used to "acknowledge" an event
 *
 * xEventGroupGetBits(xEventGroup):
 *   - Returns the current value of uxEventBits without modifying them
 *   - Implemented as xEventGroupClearBits(xEventGroup, 0)
 *
 * xEventGroupClearBitsFromISR(xEventGroup, uxBitsToClear):
 *   - Unlike SetBitsFromISR, this executes directly (not via timer daemon)
 *   - Safe because clearing bits never unblocks tasks
 */

#define STATUS_NORMAL   (1 << 0)
#define STATUS_WARNING  (1 << 1)
#define STATUS_FAULT    (1 << 2)

static EventGroupHandle_t xStatusGroup;

static void vStatusMonitor(void *pvParameters) {
    (void)pvParameters;

    /* Set initial normal status */
    xEventGroupSetBits(xStatusGroup, STATUS_NORMAL);

    for (;;) {
        /* Read current status without modifying */
        EventBits_t uxStatus = xEventGroupGetBits(xStatusGroup);

        uart_printf("[%lu] Status: Normal=%d Warning=%d Fault=%d\r\n",
                     xTaskGetTickCount(),
                     (uxStatus & STATUS_NORMAL) ? 1 : 0,
                     (uxStatus & STATUS_WARNING) ? 1 : 0,
                     (uxStatus & STATUS_FAULT) ? 1 : 0);

        /* Simulate fault detection */
        static uint32_t ulCycle = 0;
        ulCycle++;

        if (ulCycle % 10 == 5) {
            uart_printf("[%lu] Status: Fault detected! Clearing normal, setting fault\r\n",
                         xTaskGetTickCount());
            xEventGroupClearBits(xStatusGroup, STATUS_NORMAL);
            xEventGroupSetBits(xStatusGroup, STATUS_FAULT);
        } else if (ulCycle % 10 == 8) {
            uart_printf("[%lu] Status: Fault cleared, restoring normal\r\n",
                         xTaskGetTickCount());
            xEventGroupClearBits(xStatusGroup, STATUS_FAULT | STATUS_WARNING);
            xEventGroupSetBits(xStatusGroup, STATUS_NORMAL);
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void example5_clear_bits(void) {
    xStatusGroup = xEventGroupCreate();
    configASSERT(xStatusGroup != NULL);

    xTaskCreate(vStatusMonitor, "StatMon", 256, NULL, 2, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main                                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) { }
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName; for (;;) { }
}

int main(void) {
    example1_init_sync();
    example2_or_wait();
    example3_barrier();
    example4_isr_events();
    example5_clear_bits();

    vTaskStartScheduler();
    for (;;) { }
    return 0;
}
