/**
 * FreeRTOS Example 03 — Semaphores and Mutexes
 *
 * Demonstrates:
 *   - Binary semaphores for ISR-to-task signaling
 *   - Counting semaphores for resource management
 *   - Mutexes with priority inheritance
 *   - Recursive mutexes for nested locking
 *   - Priority inversion demonstration and prevention
 *   - Gate keeper (gateway) pattern
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 */

#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include "queue.h"
#include <stdio.h>
#include <string.h>

/* ---------------------------------------------------------------------------
 * Hardware stubs
 * --------------------------------------------------------------------------- */
static void hw_init(void)             { }
static void uart_print(const char *s) { printf("%s", s); }

/* Simulated shared hardware resources */
static volatile uint32_t shared_counter = 0;
static volatile int      i2c_busy = 0;

/* ---------------------------------------------------------------------------
 * Handle declarations
 * --------------------------------------------------------------------------- */
static SemaphoreHandle_t xBinarySem    = NULL;
static SemaphoreHandle_t xCountingSem  = NULL;
static SemaphoreHandle_t xI2CMutex     = NULL;
static SemaphoreHandle_t xRecursiveMtx = NULL;
static SemaphoreHandle_t xPrintMutex   = NULL;

/* Thread-safe print using a mutex */
static void safe_print(const char *s)
{
    xSemaphoreTake(xPrintMutex, portMAX_DELAY);
    uart_print(s);
    xSemaphoreGive(xPrintMutex);
}

/* ---------------------------------------------------------------------------
 * Example 1: Binary Semaphore — ISR-to-Task Signaling
 *
 * A binary semaphore acts as a flag: "an event has occurred." The ISR
 * signals (gives) the semaphore, and the task waits (takes) it.
 *
 * Binary semaphores are created EMPTY. The task blocks on take until
 * the ISR gives. This is the standard deferred interrupt pattern.
 *
 * Internal: A binary semaphore is a queue with uxLength=1 and uxItemSize=0.
 * "Give" sets uxMessagesWaiting to 1; "Take" sets it to 0.
 * Multiple gives without a take only set the count to 1 (events merge).
 * --------------------------------------------------------------------------- */
static TaskHandle_t xDataProcessHandle = NULL;

/* Simulated ISR — in real code this would be a hardware interrupt handler */
void ADC_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /*
     * xSemaphoreGiveFromISR is the ISR-safe version of xSemaphoreGive.
     * It never blocks and sets xHigherPriorityTaskWoken if a higher-priority
     * task was waiting on this semaphore.
     *
     * Multiple gives before the task takes are "lost" — binary semaphores
     * are for signaling, not counting. Use a counting semaphore if you
     * need to track the number of events.
     */
    xSemaphoreGiveFromISR(xBinarySem, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vDataProcessingTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /*
         * Block until the ISR signals us. portMAX_DELAY means wait forever.
         * The task consumes zero CPU while blocked.
         *
         * xSemaphoreTake is really xQueueSemaphoreTake internally, which
         * is a specialized version of xQueueReceive optimized for zero-size
         * queue items.
         */
        if (xSemaphoreTake(xBinarySem, portMAX_DELAY) == pdTRUE) {
            safe_print("[BIN SEM] ISR signaled — processing ADC data\r\n");
            vTaskDelay(pdMS_TO_TICKS(5));  /* Simulate processing */
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Counting Semaphore — Resource Pool
 *
 * A counting semaphore tracks available resources. The initial count is
 * the number of resources. Each "take" decrements (resource acquired);
 * each "give" increments (resource released).
 *
 * Internal: A counting semaphore is a queue with uxLength=maxCount and
 * uxItemSize=0. uxMessagesWaiting represents the current count.
 *
 * Here we simulate 3 DMA channels shared among multiple tasks.
 * --------------------------------------------------------------------------- */
#define NUM_DMA_CHANNELS  3

void vDMAUserTask(void *pvParameters)
{
    int task_id = (int)(uintptr_t)pvParameters;
    char buf[128];

    for (;;) {
        snprintf(buf, sizeof(buf),
                 "[DMA-%d] Requesting DMA channel... (available: %u)\r\n",
                 task_id, (unsigned)uxSemaphoreGetCount(xCountingSem));
        safe_print(buf);

        /*
         * Take: decrement the count. If count is 0, block until a
         * channel becomes available (another task gives the semaphore).
         */
        if (xSemaphoreTake(xCountingSem, pdMS_TO_TICKS(5000)) == pdTRUE) {
            snprintf(buf, sizeof(buf),
                     "[DMA-%d] Acquired channel (remaining: %u)\r\n",
                     task_id, (unsigned)uxSemaphoreGetCount(xCountingSem));
            safe_print(buf);

            /* Simulate DMA transfer */
            vTaskDelay(pdMS_TO_TICKS(500 + task_id * 200));

            /*
             * Give: increment the count, releasing the resource.
             * If another task was blocked waiting, it is unblocked.
             */
            xSemaphoreGive(xCountingSem);

            snprintf(buf, sizeof(buf),
                     "[DMA-%d] Released channel\r\n", task_id);
            safe_print(buf);
        } else {
            snprintf(buf, sizeof(buf),
                     "[DMA-%d] Timeout waiting for DMA channel!\r\n", task_id);
            safe_print(buf);
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Mutex — Protecting Shared I2C Bus
 *
 * A mutex provides mutual exclusion with PRIORITY INHERITANCE.
 *
 * When a high-priority task blocks on a mutex held by a low-priority task,
 * the low-priority task's effective priority is temporarily raised to match
 * the blocked task's priority. This prevents unbounded priority inversion.
 *
 * Internal differences from binary semaphore:
 *   - Created with count=1 (available), semaphore with count=0 (empty)
 *   - Tracks xMutexHolder in the queue structure
 *   - Only the holder can give (release) the mutex
 *   - Priority inheritance logic in xQueueSemaphoreTake and xQueueGenericSend
 * --------------------------------------------------------------------------- */
static void i2c_transfer(int addr, const char *task_name)
{
    char buf[128];
    snprintf(buf, sizeof(buf),
             "[I2C] %s: Transfer to 0x%02X start\r\n", task_name, addr);
    safe_print(buf);
    vTaskDelay(pdMS_TO_TICKS(50));
    snprintf(buf, sizeof(buf),
             "[I2C] %s: Transfer to 0x%02X complete\r\n", task_name, addr);
    safe_print(buf);
}

void vI2CTask1(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /*
         * xSemaphoreTake on a mutex:
         * 1. If mutex is available (count==1): take it, set xMutexHolder.
         * 2. If mutex is held by another task:
         *    a. If holder's priority < caller's priority: raise holder's
         *       priority (priority inheritance).
         *    b. Block the caller on xTasksWaitingToReceive.
         */
        if (xSemaphoreTake(xI2CMutex, pdMS_TO_TICKS(200)) == pdTRUE) {
            i2c_transfer(0x48, "TempSensor");
            i2c_transfer(0x68, "Accelerometer");

            /*
             * xSemaphoreGive on a mutex:
             * 1. Verifies the caller is the holder (configASSERT if not).
             * 2. If priority was inherited, restores uxBasePriority.
             * 3. Sets count to 1 (available).
             * 4. Unblocks the highest-priority waiting task, if any.
             */
            xSemaphoreGive(xI2CMutex);
        } else {
            safe_print("[I2C-1] Mutex timeout\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void vI2CTask2(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        if (xSemaphoreTake(xI2CMutex, pdMS_TO_TICKS(200)) == pdTRUE) {
            i2c_transfer(0x3C, "OLED Display");
            xSemaphoreGive(xI2CMutex);
        } else {
            safe_print("[I2C-2] Mutex timeout\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(800));
    }
}

/* ---------------------------------------------------------------------------
 * Example 4: Recursive Mutex — Nested Locking
 *
 * A recursive mutex can be taken multiple times by the SAME task without
 * deadlocking. An internal counter (uxRecursiveCallCount) tracks nesting
 * depth. The mutex is only released when give is called the same number
 * of times as take.
 *
 * Use case: function A takes the mutex and calls function B, which also
 * needs the mutex. With a normal mutex, function B would deadlock.
 * --------------------------------------------------------------------------- */
static void low_level_spi_write(uint8_t reg, uint8_t val)
{
    /*
     * This function needs the SPI bus mutex. It might be called directly
     * or from within spi_write_multiple which already holds the mutex.
     */
    xSemaphoreTakeRecursive(xRecursiveMtx, portMAX_DELAY);

    char buf[80];
    snprintf(buf, sizeof(buf), "  SPI: Write reg 0x%02X = 0x%02X\r\n", reg, val);
    safe_print(buf);
    vTaskDelay(pdMS_TO_TICKS(10));

    xSemaphoreGiveRecursive(xRecursiveMtx);
}

static void spi_write_multiple(uint8_t start_reg, const uint8_t *data, size_t len)
{
    /*
     * Takes the recursive mutex, then calls low_level_spi_write which
     * also takes it. Without recursive mutex, this would deadlock.
     *
     * uxRecursiveCallCount increments on each take and decrements on
     * each give. The mutex is only released when count reaches 0.
     */
    xSemaphoreTakeRecursive(xRecursiveMtx, portMAX_DELAY);

    safe_print("[SPI] Multi-write transaction start\r\n");
    for (size_t i = 0; i < len; i++) {
        low_level_spi_write(start_reg + i, data[i]);
    }
    safe_print("[SPI] Multi-write transaction end\r\n");

    xSemaphoreGiveRecursive(xRecursiveMtx);
}

void vSPITask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Direct call — takes mutex once */
        low_level_spi_write(0x01, 0xAA);

        /* Nested call — outer takes once, inner takes again (recursive) */
        uint8_t data[] = {0x10, 0x20, 0x30};
        spi_write_multiple(0x05, data, 3);

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* ---------------------------------------------------------------------------
 * Example 5: Priority Inversion Demonstration
 *
 * Three tasks demonstrate priority inversion and how mutexes prevent it:
 *   - High priority (5): Takes mutex, does critical work
 *   - Medium priority (3): CPU-bound, no mutex needed
 *   - Low priority (1): Takes mutex, does long work
 *
 * Without priority inheritance (binary semaphore):
 *   Low takes semaphore → Medium preempts Low → High is blocked by Low
 *   but Low can't run because Medium is running → HIGH IS STARVED
 *
 * With priority inheritance (mutex):
 *   Low takes mutex → High tries to take → Low is boosted to High's
 *   priority → Low finishes quickly → High runs → Low restored
 * --------------------------------------------------------------------------- */
static SemaphoreHandle_t xSharedMutex = NULL;

void vHighPriorityTask(void *pvParameters)
{
    (void)pvParameters;

    vTaskDelay(pdMS_TO_TICKS(100));

    for (;;) {
        TickType_t start = xTaskGetTickCount();
        safe_print("[HIGH] Waiting for mutex...\r\n");

        if (xSemaphoreTake(xSharedMutex, pdMS_TO_TICKS(5000)) == pdTRUE) {
            TickType_t wait = xTaskGetTickCount() - start;
            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[HIGH] Got mutex after %lu ms — doing critical work\r\n",
                     (unsigned long)wait);
            safe_print(buf);

            vTaskDelay(pdMS_TO_TICKS(20));
            xSemaphoreGive(xSharedMutex);
            safe_print("[HIGH] Released mutex\r\n");
        } else {
            safe_print("[HIGH] TIMEOUT — priority inversion!\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(3000));
    }
}

void vMediumPriorityTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        safe_print("[MED] Running CPU-bound work (no mutex)\r\n");
        /* Simulate CPU-bound work without yielding */
        volatile uint32_t i;
        for (i = 0; i < 100000; i++) { }
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

void vLowPriorityTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        if (xSemaphoreTake(xSharedMutex, portMAX_DELAY) == pdTRUE) {
            /*
             * When the high-priority task tries to take this mutex while
             * we hold it, FreeRTOS raises our priority to match the high
             * task's priority. This prevents the medium-priority task
             * from preempting us, allowing us to finish quickly.
             */
            safe_print("[LOW] Holding mutex — doing long work\r\n");
            vTaskDelay(pdMS_TO_TICKS(200));
            xSemaphoreGive(xSharedMutex);
            safe_print("[LOW] Released mutex\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/* ---------------------------------------------------------------------------
 * Example 6: Gatekeeper Pattern — Mutex-Free Serialization
 *
 * Instead of protecting a resource with a mutex, assign a single task to
 * "own" the resource. Other tasks send requests through a queue.
 *
 * Benefits:
 *   - No priority inversion (no mutex)
 *   - Clean separation of concerns
 *   - The gatekeeper handles all error recovery
 * --------------------------------------------------------------------------- */
static QueueHandle_t xPrintQueue = NULL;

#define MAX_PRINT_LEN  128

typedef struct {
    char     acMessage[MAX_PRINT_LEN];
    uint8_t  ucPriority;
} PrintRequest_t;

void vPrintGatekeeperTask(void *pvParameters)
{
    (void)pvParameters;
    PrintRequest_t request;

    for (;;) {
        if (xQueueReceive(xPrintQueue, &request, portMAX_DELAY) == pdPASS) {
            uart_print(request.acMessage);
        }
    }
}

static void gatekeeper_print(const char *msg, uint8_t priority)
{
    PrintRequest_t request;
    strncpy(request.acMessage, msg, MAX_PRINT_LEN - 1);
    request.acMessage[MAX_PRINT_LEN - 1] = '\0';
    request.ucPriority = priority;

    if (priority > 5) {
        xQueueSendToFront(xPrintQueue, &request, pdMS_TO_TICKS(10));
    } else {
        xQueueSend(xPrintQueue, &request, pdMS_TO_TICKS(10));
    }
}

void vGatekeeperClientTask(void *pvParameters)
{
    int id = (int)(uintptr_t)pvParameters;

    for (;;) {
        char buf[MAX_PRINT_LEN];
        snprintf(buf, sizeof(buf),
                 "[GATE-%d] Message at tick %lu\r\n",
                 id, (unsigned long)xTaskGetTickCount());
        gatekeeper_print(buf, (uint8_t)(id * 2));

        vTaskDelay(pdMS_TO_TICKS(500 + id * 300));
    }
}

/* ---------------------------------------------------------------------------
 * Hooks
 * --------------------------------------------------------------------------- */
void vApplicationMallocFailedHook(void)                              { for(;;); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *n)          { (void)t; (void)n; for(;;); }
void vApplicationIdleHook(void)                                      { __asm volatile("wfi"); }

/* ---------------------------------------------------------------------------
 * Main
 * --------------------------------------------------------------------------- */
int main(void)
{
    hw_init();

    /* Create synchronization primitives */
    xBinarySem    = xSemaphoreCreateBinary();
    xCountingSem  = xSemaphoreCreateCounting(NUM_DMA_CHANNELS, NUM_DMA_CHANNELS);
    xI2CMutex     = xSemaphoreCreateMutex();
    xRecursiveMtx = xSemaphoreCreateRecursiveMutex();
    xPrintMutex   = xSemaphoreCreateMutex();
    xSharedMutex  = xSemaphoreCreateMutex();
    xPrintQueue   = xQueueCreate(16, sizeof(PrintRequest_t));

    /* Binary semaphore demo */
    xTaskCreate(vDataProcessingTask, "BinSem", 256, NULL, 3, &xDataProcessHandle);

    /* Counting semaphore demo — 5 tasks sharing 3 DMA channels */
    for (int i = 0; i < 5; i++) {
        char name[12];
        snprintf(name, sizeof(name), "DMA%d", i);
        xTaskCreate(vDMAUserTask, name, 256, (void *)(uintptr_t)i, 2, NULL);
    }

    /* Mutex I2C protection */
    xTaskCreate(vI2CTask1, "I2C-1", 256, NULL, 2, NULL);
    xTaskCreate(vI2CTask2, "I2C-2", 256, NULL, 2, NULL);

    /* Recursive mutex */
    xTaskCreate(vSPITask, "SPI", 256, NULL, 2, NULL);

    /* Priority inversion demo */
    xTaskCreate(vLowPriorityTask,    "Low",  256, NULL, 1, NULL);
    xTaskCreate(vMediumPriorityTask, "Med",  256, NULL, 3, NULL);
    xTaskCreate(vHighPriorityTask,   "High", 256, NULL, 5, NULL);

    /* Gatekeeper pattern */
    xTaskCreate(vPrintGatekeeperTask, "GatePrt", 256, NULL, 4, NULL);
    for (int i = 0; i < 3; i++) {
        char name[12];
        snprintf(name, sizeof(name), "GCli%d", i);
        xTaskCreate(vGatekeeperClientTask, name, 256, (void *)(uintptr_t)i, 2, NULL);
    }

    vTaskStartScheduler();
    for (;;);
}
