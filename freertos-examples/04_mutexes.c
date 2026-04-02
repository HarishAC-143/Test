/**
 * FreeRTOS Example 04: Mutexes and Priority Inheritance
 *
 * Demonstrates:
 *   - Standard mutex for mutual exclusion
 *   - Priority inheritance mechanism
 *   - Recursive mutex for nested locking
 *   - Deadlock avoidance strategies
 *   - Mutex vs binary semaphore comparison
 *   - Mutex holder queries for debugging
 *
 * Internal details:
 *   A mutex is a specialized queue (uxLength=1, uxItemSize=0) with:
 *   - Ownership tracking: xMutexHolder stores the TCB of the holding task
 *   - Priority inheritance: when a high-priority task waits for a mutex held
 *     by a low-priority task, the holder's priority is temporarily raised
 *   - The mutex starts AVAILABLE (uxMessagesWaiting = 1), unlike binary
 *     semaphores which start EMPTY (uxMessagesWaiting = 0)
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

static void uart_send_byte(uint8_t byte) { (void)byte; }

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: Basic Mutex — Protecting Shared Data                           */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Without mutual exclusion, concurrent access to shared data structures
 * causes race conditions. Consider two tasks updating the same struct:
 *
 *   Task A: xSensor.fValue = 25.3;    ← Context switch happens here!
 *   Task B: xSensor.fValue = 18.7;
 *   Task B: xSensor.ulTimestamp = 500;
 *   Task A: xSensor.ulTimestamp = 450; ← Value and timestamp are inconsistent!
 *
 * A mutex ensures that only one task can access the shared resource at a time.
 *
 * xSemaphoreCreateMutex internals:
 *   1. Creates a queue with uxLength=1, uxItemSize=0
 *   2. Sets uxQueueType = queueQUEUE_TYPE_MUTEX
 *   3. Sets uxMessagesWaiting = 1 (mutex is AVAILABLE)
 *   4. Sets xMutexHolder = NULL (no owner)
 *   5. Allocates TCB fields uxBasePriority and uxMutexesHeld
 */

typedef struct {
    float    fTemperature;
    float    fHumidity;
    float    fPressure;
    uint32_t ulUpdateCount;
    TickType_t xLastUpdate;
} SharedSensorData_t;

static SharedSensorData_t xSharedData;
static SemaphoreHandle_t  xDataMutex;

static void vSensorWriter(void *pvParameters) {
    uint32_t ulSensorId = (uint32_t)(uintptr_t)pvParameters;

    for (;;) {
        /**
         * xSemaphoreTake on a mutex:
         *   1. If uxMessagesWaiting == 1 (available):
         *      - Set uxMessagesWaiting = 0
         *      - Set xMutexHolder = pxCurrentTCB
         *      - Record uxBasePriority (for priority inheritance restoration)
         *      - Increment pxCurrentTCB->uxMutexesHeld
         *      - Return pdPASS
         *
         *   2. If uxMessagesWaiting == 0 (held by another task):
         *      - Check priority inheritance:
         *        If pxCurrentTCB->uxPriority > xMutexHolder->uxPriority:
         *          - Raise xMutexHolder->uxPriority to pxCurrentTCB->uxPriority
         *          - Move xMutexHolder to the higher-priority ready list
         *      - Place pxCurrentTCB on xTasksWaitingToReceive list
         *      - Block with timeout
         *      - Return pdPASS when acquired, pdFALSE on timeout
         */
        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(100)) == pdPASS) {
            /* Critical section — only one task at a time */
            xSharedData.fTemperature = 20.0f + (float)ulSensorId;
            xSharedData.fHumidity    = 45.0f + (float)ulSensorId * 2.0f;
            xSharedData.fPressure    = 1013.0f;
            xSharedData.ulUpdateCount++;
            xSharedData.xLastUpdate  = xTaskGetTickCount();

            uart_printf("[%lu] Writer %lu: updated (count=%lu)\r\n",
                         xTaskGetTickCount(), ulSensorId, xSharedData.ulUpdateCount);

            /**
             * xSemaphoreGive on a mutex:
             *   1. Verify the caller is the mutex holder (configASSERT in debug)
             *   2. Decrement pxCurrentTCB->uxMutexesHeld
             *   3. If priority was inherited:
             *      - Restore uxPriority to uxBasePriority
             *      - Move task to the correct ready list
             *   4. Set xMutexHolder = NULL
             *   5. Set uxMessagesWaiting = 1 (mutex available)
             *   6. If a task was waiting on xTasksWaitingToReceive:
             *      - Unblock the highest-priority waiting task
             *      - That task becomes the new mutex holder
             *      - If its priority > current task, yield
             */
            xSemaphoreGive(xDataMutex);
        } else {
            uart_printf("[%lu] Writer %lu: TIMEOUT acquiring mutex\r\n",
                         xTaskGetTickCount(), ulSensorId);
        }

        vTaskDelay(pdMS_TO_TICKS(200 + ulSensorId * 50));
    }
}

static void vSensorReader(void *pvParameters) {
    (void)pvParameters;
    SharedSensorData_t xLocalCopy;

    for (;;) {
        if (xSemaphoreTake(xDataMutex, portMAX_DELAY) == pdPASS) {
            /* Copy the entire struct while protected by the mutex.
               This ensures atomicity: all fields are from the same update. */
            memcpy(&xLocalCopy, &xSharedData, sizeof(SharedSensorData_t));
            xSemaphoreGive(xDataMutex);

            uart_printf("[%lu] Reader: T=%.1f H=%.1f P=%.1f (update #%lu)\r\n",
                         xTaskGetTickCount(),
                         xLocalCopy.fTemperature,
                         xLocalCopy.fHumidity,
                         xLocalCopy.fPressure,
                         xLocalCopy.ulUpdateCount);
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void example1_basic_mutex(void) {
    xDataMutex = xSemaphoreCreateMutex();
    configASSERT(xDataMutex != NULL);

    memset(&xSharedData, 0, sizeof(xSharedData));

    xTaskCreate(vSensorWriter, "Writer0", 256, (void *)0, 2, NULL);
    xTaskCreate(vSensorWriter, "Writer1", 256, (void *)1, 2, NULL);
    xTaskCreate(vSensorReader, "Reader",  256, NULL,       3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: Priority Inheritance Demonstration                             */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Priority inversion: a high-priority task is indirectly blocked by a
 * medium-priority task that has no relation to the shared resource.
 *
 * Scenario without priority inheritance:
 *   - Low (priority 1) takes the mutex
 *   - High (priority 3) tries to take the mutex → blocks
 *   - Medium (priority 2) preempts Low (it's ready and higher priority)
 *   - High is stuck waiting because Medium prevents Low from running
 *   - Result: High is effectively at priority < Medium (INVERSION)
 *
 * With priority inheritance:
 *   - When High blocks on the mutex, the kernel raises Low's priority to 3
 *   - Medium can no longer preempt Low
 *   - Low finishes quickly, releases mutex, priority drops back to 1
 *   - High immediately runs (it was waiting and has the highest priority)
 *   - Result: High's delay = only Low's remaining critical section time
 */

static SemaphoreHandle_t xInheritanceMutex;

static void vLowPriorityTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        uart_printf("[%lu] LOW: attempting to take mutex\r\n", xTaskGetTickCount());
        xSemaphoreTake(xInheritanceMutex, portMAX_DELAY);

        uart_printf("[%lu] LOW: got mutex (priority=%lu)\r\n",
                     xTaskGetTickCount(),
                     (unsigned long)uxTaskPriorityGet(NULL));

        /* Simulate long critical section */
        volatile uint32_t i;
        for (i = 0; i < 2000000; i++) { }

        /* Check if priority was inherited */
        uart_printf("[%lu] LOW: still in critical section (priority=%lu)\r\n",
                     xTaskGetTickCount(),
                     (unsigned long)uxTaskPriorityGet(NULL));

        xSemaphoreGive(xInheritanceMutex);

        uart_printf("[%lu] LOW: released mutex (priority now=%lu)\r\n",
                     xTaskGetTickCount(),
                     (unsigned long)uxTaskPriorityGet(NULL));

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vMediumPriorityTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        uart_printf("[%lu] MEDIUM: running (does NOT use the mutex)\r\n",
                     xTaskGetTickCount());

        /* Medium does NOT use the mutex — it just does computation */
        volatile uint32_t i;
        for (i = 0; i < 1000000; i++) { }

        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

static void vHighPriorityTask(void *pvParameters) {
    (void)pvParameters;

    /* Initial delay so Low can take the mutex first */
    vTaskDelay(pdMS_TO_TICKS(50));

    for (;;) {
        TickType_t xStartTime = xTaskGetTickCount();

        uart_printf("[%lu] HIGH: attempting to take mutex\r\n", xTaskGetTickCount());

        /* This will trigger priority inheritance:
           Low's priority will be raised to 3 (High's priority) */
        xSemaphoreTake(xInheritanceMutex, portMAX_DELAY);

        TickType_t xWaitTime = xTaskGetTickCount() - xStartTime;
        uart_printf("[%lu] HIGH: got mutex after %lu ms wait\r\n",
                     xTaskGetTickCount(), xWaitTime);

        /* Use the shared resource */
        uart_printf("[%lu] HIGH: accessing shared resource\r\n", xTaskGetTickCount());

        xSemaphoreGive(xInheritanceMutex);

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void example2_priority_inheritance(void) {
    xInheritanceMutex = xSemaphoreCreateMutex();
    configASSERT(xInheritanceMutex != NULL);

    /* Priorities: Low=1, Medium=2, High=3 */
    xTaskCreate(vLowPriorityTask,    "Low",    256, NULL, 1, NULL);
    xTaskCreate(vMediumPriorityTask, "Medium", 256, NULL, 2, NULL);
    xTaskCreate(vHighPriorityTask,   "High",   256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: Recursive Mutex                                                */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * A recursive mutex can be taken multiple times by the SAME task.
 * Each take increments an internal recursion counter.
 * The mutex is only released when the counter reaches zero
 * (every take must have a matching give).
 *
 * Use case: A library function takes the mutex, and it calls another
 * library function that also takes the same mutex. With a regular mutex,
 * this would deadlock. With a recursive mutex, it works correctly.
 *
 * xSemaphoreCreateRecursiveMutex internals:
 *   - Creates a queue with uxLength=1, uxItemSize=0
 *   - Sets uxQueueType = queueQUEUE_TYPE_RECURSIVE_MUTEX
 *   - Tracks recursion via uxRecursiveCallCount in the queue structure
 *
 * IMPORTANT: Must use xSemaphoreTakeRecursive / xSemaphoreGiveRecursive
 * (not the regular Take/Give). Using regular APIs on a recursive mutex
 * is undefined behavior.
 */

static SemaphoreHandle_t xDisplayMutex;

/* Low-level display write — acquires mutex */
static void display_write_raw(const char *data, uint16_t length) {
    xSemaphoreTakeRecursive(xDisplayMutex, portMAX_DELAY);

    for (uint16_t i = 0; i < length; i++) {
        uart_send_byte((uint8_t)data[i]);
    }

    xSemaphoreGiveRecursive(xDisplayMutex);
}

/* Higher-level function — also acquires mutex, then calls display_write_raw.
   Without recursive mutex, this would deadlock on the second take. */
static void display_write_line(uint8_t row, const char *text) {
    xSemaphoreTakeRecursive(xDisplayMutex, portMAX_DELAY);

    char header[4] = {0x1B, '[', (char)('0' + row), 'H'};
    display_write_raw(header, 4);         /* Nested take #2 — OK with recursive */
    display_write_raw(text, (uint16_t)strlen(text));  /* Nested take #3 */

    xSemaphoreGiveRecursive(xDisplayMutex); /* Match for take #1 */
}

/* Even higher level — three levels of nesting */
static void display_update_status(float temp, float humidity) {
    xSemaphoreTakeRecursive(xDisplayMutex, portMAX_DELAY);

    char buf[32];
    snprintf(buf, sizeof(buf), "T: %.1f C", temp);
    display_write_line(0, buf);   /* Nested calls, each taking the mutex */

    snprintf(buf, sizeof(buf), "H: %.1f %%", humidity);
    display_write_line(1, buf);

    xSemaphoreGiveRecursive(xDisplayMutex);
}

static void vDisplayTask(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        display_update_status(23.5f, 55.2f);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void example3_recursive_mutex(void) {
    xDisplayMutex = xSemaphoreCreateRecursiveMutex();
    configASSERT(xDisplayMutex != NULL);

    xTaskCreate(vDisplayTask, "Display", 512, NULL, 2, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: Deadlock Avoidance                                             */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Deadlock: Task A holds Mutex 1 and waits for Mutex 2.
 *           Task B holds Mutex 2 and waits for Mutex 1.
 *           Neither can proceed. System is permanently stuck.
 *
 * Prevention strategies:
 *
 *   1. CONSISTENT LOCK ORDERING: Always acquire mutexes in the same global
 *      order. If every task acquires Mutex 1 before Mutex 2, deadlock
 *      cannot occur.
 *
 *   2. TIMEOUTS: Use a finite timeout instead of portMAX_DELAY. If acquisition
 *      fails, release all held mutexes and retry.
 *
 *   3. TRY-LOCK: Attempt to acquire with zero timeout. If it fails, don't block.
 *
 *   4. REDESIGN: Use message passing (queues) instead of shared state.
 *      A single task owns each resource and other tasks send it commands.
 */

static SemaphoreHandle_t xMutexA;
static SemaphoreHandle_t xMutexB;

/* CORRECT: Both tasks acquire in the same order (A, then B) */
static void vCorrectTask1(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        xSemaphoreTake(xMutexA, portMAX_DELAY);
        uart_printf("[%lu] Task1: got A, getting B...\r\n", xTaskGetTickCount());
        xSemaphoreTake(xMutexB, portMAX_DELAY);

        uart_printf("[%lu] Task1: has both A and B\r\n", xTaskGetTickCount());

        /* Give in reverse order (good practice, not strictly required) */
        xSemaphoreGive(xMutexB);
        xSemaphoreGive(xMutexA);

        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void vCorrectTask2(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        /* SAME order as Task1: A first, then B */
        xSemaphoreTake(xMutexA, portMAX_DELAY);
        uart_printf("[%lu] Task2: got A, getting B...\r\n", xTaskGetTickCount());
        xSemaphoreTake(xMutexB, portMAX_DELAY);

        uart_printf("[%lu] Task2: has both A and B\r\n", xTaskGetTickCount());

        xSemaphoreGive(xMutexB);
        xSemaphoreGive(xMutexA);

        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

/* SAFE FALLBACK: Use timeouts to detect and recover from potential deadlock */
static void vTimeoutTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulRetries = 0;

    for (;;) {
        BaseType_t xGotBoth = pdFALSE;

        if (xSemaphoreTake(xMutexA, pdMS_TO_TICKS(100)) == pdPASS) {
            if (xSemaphoreTake(xMutexB, pdMS_TO_TICKS(100)) == pdPASS) {
                /* Success: have both mutexes */
                uart_printf("[%lu] TimeoutTask: accessing both resources\r\n",
                             xTaskGetTickCount());
                xGotBoth = pdTRUE;

                xSemaphoreGive(xMutexB);
            } else {
                /* Failed to get B — release A and retry */
                uart_printf("[%lu] TimeoutTask: timeout on B, releasing A (retry #%lu)\r\n",
                             xTaskGetTickCount(), ++ulRetries);
            }
            xSemaphoreGive(xMutexA);
        } else {
            uart_printf("[%lu] TimeoutTask: timeout on A\r\n", xTaskGetTickCount());
        }

        if (!xGotBoth) {
            /* Back off before retrying */
            vTaskDelay(pdMS_TO_TICKS(50));
        } else {
            vTaskDelay(pdMS_TO_TICKS(500));
        }
    }
}

static void example4_deadlock_avoidance(void) {
    xMutexA = xSemaphoreCreateMutex();
    xMutexB = xSemaphoreCreateMutex();
    configASSERT(xMutexA != NULL && xMutexB != NULL);

    xTaskCreate(vCorrectTask1, "Correct1", 256, NULL, 2, NULL);
    xTaskCreate(vCorrectTask2, "Correct2", 256, NULL, 2, NULL);
    xTaskCreate(vTimeoutTask,  "Timeout",  256, NULL, 2, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 5: Mutex Holder Query for Debugging                               */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xSemaphoreGetMutexHolder(xMutex):
 *   Returns the TaskHandle_t of the task that currently holds the mutex,
 *   or NULL if the mutex is available.
 *
 * xSemaphoreGetMutexHolderFromISR(xMutex):
 *   ISR-safe version (no critical section; reads the holder atomically).
 *
 * Useful for:
 *   - Debugging deadlocks (who holds the mutex?)
 *   - Implementing try-lock patterns
 *   - Diagnostic logging
 *
 * Requires configUSE_MUTEXES == 1 and
 * INCLUDE_xSemaphoreGetMutexHolder == 1 (defaults to INCLUDE_xQueueGetMutexHolder).
 */

static SemaphoreHandle_t xDebugMutex;

static void vMutexDebugTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        TaskHandle_t xHolder = xSemaphoreGetMutexHolder(xDebugMutex);

        if (xHolder != NULL) {
            uart_printf("[%lu] Debug: mutex held by task '%s'\r\n",
                         xTaskGetTickCount(), pcTaskGetName(xHolder));
        } else {
            uart_printf("[%lu] Debug: mutex is available\r\n",
                         xTaskGetTickCount());
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void vMutexUserTask(void *pvParameters) {
    uint32_t ulTaskId = (uint32_t)(uintptr_t)pvParameters;

    for (;;) {
        xSemaphoreTake(xDebugMutex, portMAX_DELAY);
        uart_printf("[%lu] User %lu: holding mutex\r\n",
                     xTaskGetTickCount(), ulTaskId);

        /* Hold the mutex for a noticeable period */
        vTaskDelay(pdMS_TO_TICKS(500 + ulTaskId * 200));

        xSemaphoreGive(xDebugMutex);
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

static void example5_mutex_debug(void) {
    xDebugMutex = xSemaphoreCreateMutex();
    configASSERT(xDebugMutex != NULL);

    xTaskCreate(vMutexUserTask,  "User0",  256, (void *)0, 2, NULL);
    xTaskCreate(vMutexUserTask,  "User1",  256, (void *)1, 2, NULL);
    xTaskCreate(vMutexDebugTask, "Debug",  256, NULL,       1, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main                                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) { }
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName; for (;;) { }
}

int main(void) {
    example1_basic_mutex();
    example2_priority_inheritance();
    example3_recursive_mutex();
    example4_deadlock_avoidance();
    example5_mutex_debug();

    vTaskStartScheduler();
    for (;;) { }
    return 0;
}
