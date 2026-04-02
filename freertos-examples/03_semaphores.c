/**
 * FreeRTOS Example 03: Semaphores — Binary and Counting
 *
 * Demonstrates:
 *   - Binary semaphore for ISR-to-task synchronization (deferred interrupt processing)
 *   - Counting semaphore for event counting
 *   - Counting semaphore for resource pool management
 *   - Multiple ISRs signaling a single handler task
 *   - Gatekeeper task pattern using binary semaphore
 *
 * Internal details:
 *   Semaphores are implemented as queues with uxItemSize == 0.
 *   - Binary semaphore: queue length 1
 *   - Counting semaphore: queue length = max count
 *   "Give" = xQueueSend (increments uxMessagesWaiting up to uxLength)
 *   "Take" = xQueueReceive (decrements uxMessagesWaiting, blocks if 0)
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Simulated Hardware                                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

static void uart_printf(const char *fmt, ...) { (void)fmt; }

static volatile uint8_t g_uart_rx_buffer[256];
static volatile uint16_t g_uart_rx_count = 0;

static void gpio_write(uint8_t pin, uint8_t value) {
    (void)pin; (void)value;
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: Binary Semaphore — Deferred Interrupt Processing               */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * The deferred interrupt processing pattern:
 *
 * Problem: ISRs must be fast. Complex data processing in an ISR delays
 * all lower-priority interrupts and increases system latency.
 *
 * Solution: The ISR does minimal work (save data, clear flags) and signals
 * a task via a binary semaphore. The task does the heavy processing.
 *
 * Binary semaphore internals:
 *   - Created with uxQueueLength = 1, uxItemSize = 0
 *   - Initial state: EMPTY (count = 0, not available)
 *   - xSemaphoreGive → uxMessagesWaiting goes from 0 → 1
 *   - xSemaphoreTake → uxMessagesWaiting goes from 1 → 0
 *   - Multiple gives without intervening takes don't accumulate: count stays at 1
 *     (this is why it's called "binary")
 *
 * WARNING: Binary semaphores can "lose" events. If the ISR fires twice before
 * the task runs, only one event is recorded. Use counting semaphores if every
 * event must be processed.
 */

static SemaphoreHandle_t xUARTBinarySem;

/**
 * Simulated UART Receive interrupt handler.
 *
 * xSemaphoreGiveFromISR internals:
 *   1. Checks if uxMessagesWaiting < uxLength (for binary sem: 0 < 1)
 *   2. Increments uxMessagesWaiting
 *   3. Checks xTasksWaitingToReceive list
 *   4. If a task is waiting, removes it from the blocked list and adds to ready list
 *   5. Sets *pxHigherPriorityTaskWoken = pdTRUE if the unblocked task has
 *      higher priority than the task that was running when the ISR fired
 *   6. Does NOT perform a context switch (deferred to portYIELD_FROM_ISR)
 */
void USART1_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Read received byte (hardware register access) */
    uint8_t ucByte = 0; /* = USART1->DR; */
    g_uart_rx_buffer[g_uart_rx_count++ & 0xFF] = ucByte;

    /* Clear interrupt flag */
    /* USART1->SR &= ~USART_SR_RXNE; */

    /* Signal the processing task */
    xSemaphoreGiveFromISR(xUARTBinarySem, &xHigherPriorityTaskWoken);

    /**
     * portYIELD_FROM_ISR(x):
     *   On ARM Cortex-M, if x == pdTRUE, sets the PendSV pending bit.
     *   PendSV fires after all ISRs have completed (it has the lowest priority).
     *   The PendSV handler performs the context switch.
     *   
     *   It is safe to call this with pdFALSE — it simply does nothing.
     *   Always call it with the flag from the FromISR function.
     */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void vUARTHandlerTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        /**
         * xSemaphoreTake:
         *   - If uxMessagesWaiting > 0: decrements it and returns pdPASS
         *   - If uxMessagesWaiting == 0: blocks the task for up to xTicksToWait
         *     - Task is placed on xTasksWaitingToReceive list
         *     - Task is placed on the delayed task list (for timeout)
         *     - A context switch occurs to run the next ready task
         *   - When the semaphore is given (from ISR or task):
         *     - The waiting task is moved from blocked to ready list
         *     - On the next context switch, the task resumes after xSemaphoreTake
         *     - xSemaphoreTake returns pdPASS
         */
        if (xSemaphoreTake(xUARTBinarySem, portMAX_DELAY) == pdPASS) {
            /* Process all received bytes */
            uint16_t usCount = g_uart_rx_count;
            uart_printf("[%lu] UART handler: processing %u bytes\r\n",
                         xTaskGetTickCount(), usCount);

            /* Parse and handle the data... */
            g_uart_rx_count = 0;
        }
    }
}

static void example1_binary_semaphore(void) {
    /**
     * xSemaphoreCreateBinary:
     *   - Allocates a Queue_t structure with uxLength=1, uxItemSize=0
     *   - uxMessagesWaiting is initialized to 0 (semaphore NOT available)
     *   - You must give the semaphore before the first take (or have an ISR give it)
     *
     * Contrast with xSemaphoreCreateMutex, which starts AVAILABLE (count = 1).
     */
    xUARTBinarySem = xSemaphoreCreateBinary();
    configASSERT(xUARTBinarySem != NULL);

    xTaskCreate(vUARTHandlerTask, "UARTHdl", 256, NULL, 5, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: Counting Semaphore — Event Counting                            */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Counting semaphores solve the "lost event" problem of binary semaphores.
 *
 * If a producer fires faster than the consumer can process:
 *   - Binary semaphore: events are lost (count can't exceed 1)
 *   - Counting semaphore: each give increments the count (up to max)
 *     The consumer processes one event per take until count reaches 0
 *
 * xSemaphoreCreateCounting(uxMaxCount, uxInitialCount):
 *   - Creates a queue with uxLength = uxMaxCount, uxItemSize = 0
 *   - Sets uxMessagesWaiting = uxInitialCount
 *   - For event counting: uxInitialCount = 0 (no events pending)
 *   - For resource management: uxInitialCount = uxMaxCount (all resources free)
 */

static SemaphoreHandle_t xButtonEventSem;

void EXTI0_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Clear interrupt flag */
    /* EXTI->PR = EXTI_PR_PR0; */

    /* Each button press increments the semaphore count */
    xSemaphoreGiveFromISR(xButtonEventSem, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void vButtonHandlerTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulPressCount = 0;

    for (;;) {
        /* Each take decrements the count by 1 and processes one button event.
           If 5 button presses occurred while this task was processing,
           the semaphore count will be 5, and this loop will process all 5
           before blocking again. */
        if (xSemaphoreTake(xButtonEventSem, portMAX_DELAY) == pdPASS) {
            ulPressCount++;
            uart_printf("[%lu] Button press #%lu processed (pending: %lu)\r\n",
                         xTaskGetTickCount(), ulPressCount,
                         (unsigned long)uxSemaphoreGetCount(xButtonEventSem));

            /* Simulate non-trivial processing */
            vTaskDelay(pdMS_TO_TICKS(50));
        }
    }
}

static void example2_counting_event(void) {
    /* Max 20 queued events, starts at 0 */
    xButtonEventSem = xSemaphoreCreateCounting(20, 0);
    configASSERT(xButtonEventSem != NULL);

    xTaskCreate(vButtonHandlerTask, "BtnHdl", 256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: Counting Semaphore — Resource Pool                             */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Resource pool pattern:
 *   - N identical resources (e.g., DMA channels, connection slots, buffer blocks)
 *   - Counting semaphore with initial count = N
 *   - Take before using a resource (blocks if all in use)
 *   - Give after releasing a resource
 *
 * This is different from a mutex:
 *   - Mutex: one resource, owned by one task at a time
 *   - Counting semaphore: N resources, any task can take/give (no ownership)
 */

#define NUM_CONNECTIONS   3

static SemaphoreHandle_t xConnectionPool;

typedef struct {
    uint8_t ucSlotId;
    uint8_t ucInUse;
    char    cClientInfo[32];
} ConnectionSlot_t;

static ConnectionSlot_t xSlots[NUM_CONNECTIONS];

static int8_t allocate_slot(void) {
    for (int i = 0; i < NUM_CONNECTIONS; i++) {
        if (!xSlots[i].ucInUse) {
            xSlots[i].ucInUse = 1;
            return (int8_t)i;
        }
    }
    return -1;
}

static void release_slot(int8_t slot) {
    if (slot >= 0 && slot < NUM_CONNECTIONS) {
        xSlots[slot].ucInUse = 0;
        xSlots[slot].cClientInfo[0] = '\0';
    }
}

static void vClientTask(void *pvParameters) {
    uint32_t ulClientId = (uint32_t)(uintptr_t)pvParameters;

    for (;;) {
        uart_printf("[%lu] Client %lu: requesting connection (available: %lu)\r\n",
                     xTaskGetTickCount(), ulClientId,
                     (unsigned long)uxSemaphoreGetCount(xConnectionPool));

        /* Block until a connection slot is available */
        if (xSemaphoreTake(xConnectionPool, pdMS_TO_TICKS(5000)) == pdPASS) {
            int8_t slot = allocate_slot();
            uart_printf("[%lu] Client %lu: connected on slot %d\r\n",
                         xTaskGetTickCount(), ulClientId, slot);

            /* Simulate network activity */
            vTaskDelay(pdMS_TO_TICKS(2000 + ulClientId * 500));

            /* Release the slot and give back the semaphore */
            release_slot(slot);
            xSemaphoreGive(xConnectionPool);

            uart_printf("[%lu] Client %lu: disconnected, released slot %d\r\n",
                         xTaskGetTickCount(), ulClientId, slot);
        } else {
            uart_printf("[%lu] Client %lu: TIMEOUT waiting for connection\r\n",
                         xTaskGetTickCount(), ulClientId);
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void example3_resource_pool(void) {
    /* Initial count = max = NUM_CONNECTIONS (all slots available) */
    xConnectionPool = xSemaphoreCreateCounting(NUM_CONNECTIONS, NUM_CONNECTIONS);
    configASSERT(xConnectionPool != NULL);

    for (int i = 0; i < NUM_CONNECTIONS; i++) {
        xSlots[i].ucSlotId = (uint8_t)i;
        xSlots[i].ucInUse  = 0;
    }

    /* Create 5 clients competing for 3 connection slots */
    for (uint32_t i = 0; i < 5; i++) {
        char name[16];
        snprintf(name, sizeof(name), "Client%lu", (unsigned long)i);
        xTaskCreate(vClientTask, name, 256, (void *)(uintptr_t)i, 2, NULL);
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: Multiple ISRs Signaling One Task                               */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Multiple interrupt sources can give the same semaphore.
 * The handler task wakes up for each event and determines which source fired.
 *
 * This pattern avoids creating one task per interrupt source.
 */

static SemaphoreHandle_t xPeripheralSem;
static volatile uint8_t g_isr_source = 0;

void DMA1_Stream0_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    g_isr_source |= 0x01;
    xSemaphoreGiveFromISR(xPeripheralSem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

void TIM2_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    g_isr_source |= 0x02;
    xSemaphoreGiveFromISR(xPeripheralSem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

void SPI1_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    g_isr_source |= 0x04;
    xSemaphoreGiveFromISR(xPeripheralSem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

static void vPeripheralHandlerTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        xSemaphoreTake(xPeripheralSem, portMAX_DELAY);

        /* Read and clear the source flags atomically */
        taskENTER_CRITICAL();
        uint8_t ucSources = g_isr_source;
        g_isr_source = 0;
        taskEXIT_CRITICAL();

        if (ucSources & 0x01) {
            uart_printf("[%lu] Handling DMA transfer complete\r\n", xTaskGetTickCount());
        }
        if (ucSources & 0x02) {
            uart_printf("[%lu] Handling Timer event\r\n", xTaskGetTickCount());
        }
        if (ucSources & 0x04) {
            uart_printf("[%lu] Handling SPI transaction\r\n", xTaskGetTickCount());
        }
    }
}

static void example4_multi_isr(void) {
    /* Using counting semaphore so events aren't lost when multiple ISRs fire */
    xPeripheralSem = xSemaphoreCreateCounting(10, 0);
    configASSERT(xPeripheralSem != NULL);

    xTaskCreate(vPeripheralHandlerTask, "PeriHdl", 256, NULL, 5, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 5: Gatekeeper Task — Serialized Resource Access                   */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * The gatekeeper pattern uses a single task to serialize access to a
 * non-reentrant resource (e.g., UART, display, file). Instead of using
 * a mutex, other tasks send their data to the gatekeeper via a queue.
 *
 * Advantages over mutex:
 *   - No risk of priority inversion
 *   - No risk of deadlock
 *   - ISRs can safely use the resource (via FromISR queue send)
 *   - Cleaner separation of concerns
 *
 * Disadvantage:
 *   - Additional task and queue overhead
 *   - Asynchronous (caller doesn't wait for write to complete)
 */

typedef struct {
    char     cMessage[64];
    uint8_t  ucPriority;  /* 0 = normal, 1 = warning, 2 = error */
} LogEntry_t;

static QueueHandle_t xLogQueue;

static void vLogGatekeeperTask(void *pvParameters) {
    (void)pvParameters;
    LogEntry_t xEntry;
    const char *pcPrefixes[] = {"[INFO] ", "[WARN] ", "[ERR!] "};

    for (;;) {
        if (xQueueReceive(xLogQueue, &xEntry, portMAX_DELAY) == pdPASS) {
            /* Only this task writes to UART — no mutex needed */
            uint8_t idx = xEntry.ucPriority < 3 ? xEntry.ucPriority : 0;
            uart_printf("%s%s\r\n", pcPrefixes[idx], xEntry.cMessage);
        }
    }
}

static void log_message(uint8_t priority, const char *msg) {
    LogEntry_t xEntry;
    xEntry.ucPriority = priority;
    strncpy(xEntry.cMessage, msg, sizeof(xEntry.cMessage) - 1);
    xEntry.cMessage[sizeof(xEntry.cMessage) - 1] = '\0';

    xQueueSend(xLogQueue, &xEntry, pdMS_TO_TICKS(10));
}

static void vAppTask1(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        log_message(0, "Temperature reading normal");
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void vAppTask2(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        log_message(1, "Battery voltage low");
        vTaskDelay(pdMS_TO_TICKS(3000));
    }
}

static void example5_gatekeeper(void) {
    xLogQueue = xQueueCreate(16, sizeof(LogEntry_t));
    configASSERT(xLogQueue != NULL);

    xTaskCreate(vLogGatekeeperTask, "LogGate", 512, NULL, 4, NULL);
    xTaskCreate(vAppTask1, "App1", 256, NULL, 2, NULL);
    xTaskCreate(vAppTask2, "App2", 256, NULL, 2, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main                                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) { }
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName; for (;;) { }
}

int main(void) {
    example1_binary_semaphore();
    example2_counting_event();
    example3_resource_pool();
    example4_multi_isr();
    example5_gatekeeper();

    vTaskStartScheduler();
    for (;;) { }
    return 0;
}
