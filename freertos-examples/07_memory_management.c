/**
 * FreeRTOS Example 07 — Memory Management
 *
 * Demonstrates:
 *   - Heap usage monitoring (pvPortMalloc, vPortFree)
 *   - Static vs dynamic object creation
 *   - Stack high-water mark monitoring and tuning
 *   - Custom fixed-block memory pool (zero fragmentation)
 *   - Malloc failed hook
 *   - heap_5 multi-region configuration
 *   - Runtime heap statistics (vPortGetHeapStats)
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 *
 * Key Concept: FreeRTOS provides 5 heap implementations in
 * portable/MemMang/heap_1.c through heap_5.c. Only ONE is linked into
 * the application. The choice depends on whether you need to free memory,
 * whether you have multiple RAM regions, and fragmentation tolerance.
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
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
 * Example 1: Heap Statistics Monitoring
 *
 * FreeRTOS tracks two heap metrics:
 *   - xPortGetFreeHeapSize(): Current free bytes
 *   - xPortGetMinimumEverFreeHeapSize(): Lowest free bytes ever (high-water mark)
 *
 * The difference between configTOTAL_HEAP_SIZE and MinimumEverFree tells
 * you the peak heap usage. This is critical for sizing configTOTAL_HEAP_SIZE.
 *
 * In FreeRTOS v10.5+, vPortGetHeapStats() provides detailed statistics:
 *   - Available free bytes
 *   - Largest free block
 *   - Smallest free block
 *   - Number of free blocks
 *   - Minimum ever free bytes
 *   - Number of successful allocations
 *   - Number of successful frees
 * --------------------------------------------------------------------------- */
void vHeapMonitorTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        safe_print("\r\n=== Heap Statistics ===\r\n");

        char buf[128];

        snprintf(buf, sizeof(buf),
                 "  Total heap size:    %u bytes\r\n",
                 (unsigned)configTOTAL_HEAP_SIZE);
        safe_print(buf);

        size_t free_now = xPortGetFreeHeapSize();
        size_t min_free = xPortGetMinimumEverFreeHeapSize();

        snprintf(buf, sizeof(buf),
                 "  Current free:       %u bytes\r\n",
                 (unsigned)free_now);
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Peak usage:         %u bytes\r\n",
                 (unsigned)(configTOTAL_HEAP_SIZE - min_free));
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Min ever free:      %u bytes\r\n",
                 (unsigned)min_free);
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Used right now:     %u bytes (%.1f%%)\r\n",
                 (unsigned)(configTOTAL_HEAP_SIZE - free_now),
                 100.0f * (configTOTAL_HEAP_SIZE - free_now) / configTOTAL_HEAP_SIZE);
        safe_print(buf);

#if (configSUPPORT_DYNAMIC_ALLOCATION == 1)
        /*
         * vPortGetHeapStats (FreeRTOS 10.5+) provides a full breakdown.
         * Requires heap_4 or heap_5 to be meaningful.
         */
        HeapStats_t xStats;
        vPortGetHeapStats(&xStats);

        snprintf(buf, sizeof(buf),
                 "  Largest free block: %u bytes\r\n",
                 (unsigned)xStats.xSizeOfLargestFreeBlockInBytes);
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Smallest free blk:  %u bytes\r\n",
                 (unsigned)xStats.xSizeOfSmallestFreeBlockInBytes);
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Free block count:   %u\r\n",
                 (unsigned)xStats.xNumberOfFreeBlocks);
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Alloc calls:        %u\r\n",
                 (unsigned)xStats.xNumberOfSuccessfulAllocations);
        safe_print(buf);

        snprintf(buf, sizeof(buf),
                 "  Free calls:         %u\r\n",
                 (unsigned)xStats.xNumberOfSuccessfulFrees);
        safe_print(buf);
#endif

        safe_print("=======================\r\n\r\n");

        vTaskDelay(pdMS_TO_TICKS(10000));
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Stack High-Water Mark Monitoring
 *
 * Each task's stack usage should be checked during development.
 * uxTaskGetStackHighWaterMark returns the minimum free stack (in words)
 * since the task started.
 *
 * On ARM Cortex-M, 1 word = 4 bytes. So a return value of 50 means
 * 200 bytes of stack were never used — this is the safety margin.
 *
 * Stack overflow detection levels:
 *   configCHECK_FOR_STACK_OVERFLOW = 1:
 *     Checks if SP went past the stack boundary on each context switch.
 *     Fast but may miss overflows that occur and recover between switches.
 *
 *   configCHECK_FOR_STACK_OVERFLOW = 2:
 *     Fills the last 20 bytes of the stack with 0xA5A5A5A5 at creation.
 *     Checks this pattern on each context switch. Catches overflows that
 *     corrupt the bottom of the stack even if SP recovered.
 * --------------------------------------------------------------------------- */
static TaskHandle_t xSmallStackHandle  = NULL;
static TaskHandle_t xMediumStackHandle = NULL;
static TaskHandle_t xLargeStackHandle  = NULL;

void vSmallStackTask(void *pvParameters)
{
    (void)pvParameters;
    uint8_t small_buf[32];

    for (;;) {
        memset(small_buf, 0xAA, sizeof(small_buf));
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void vMediumStackTask(void *pvParameters)
{
    (void)pvParameters;
    char medium_buf[128];

    for (;;) {
        snprintf(medium_buf, sizeof(medium_buf),
                 "Medium stack task at tick %lu",
                 (unsigned long)xTaskGetTickCount());
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void vLargeStackTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t large_buf[64]; /* 256 bytes */
    float    float_buf[32]; /* 128 bytes — FPU context adds to stack */

    for (;;) {
        for (int i = 0; i < 64; i++) large_buf[i] = i * i;
        for (int i = 0; i < 32; i++) float_buf[i] = (float)large_buf[i] / 3.14f;
        (void)float_buf;
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void vStackMonitorTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(5000));

        safe_print("\r\n=== Stack Monitor ===\r\n");

        char buf[128];

        struct { TaskHandle_t h; const char *name; uint32_t alloc; } tasks[] = {
            { xSmallStackHandle,  "SmallStack",  128 },
            { xMediumStackHandle, "MediumStack", 256 },
            { xLargeStackHandle,  "LargeStack",  512 },
        };

        for (int i = 0; i < 3; i++) {
            if (tasks[i].h != NULL) {
                UBaseType_t hwm = uxTaskGetStackHighWaterMark(tasks[i].h);
                uint32_t used = tasks[i].alloc - hwm;
                snprintf(buf, sizeof(buf),
                         "  %-12s: allocated=%lu words, free_min=%lu words, peak_used=%lu words (%.0f%%)\r\n",
                         tasks[i].name,
                         (unsigned long)tasks[i].alloc,
                         (unsigned long)hwm,
                         (unsigned long)used,
                         100.0f * used / tasks[i].alloc);
                safe_print(buf);

                if (hwm < 20) {
                    snprintf(buf, sizeof(buf),
                             "  !! WARNING: %s stack margin is dangerously low!\r\n",
                             tasks[i].name);
                    safe_print(buf);
                }
            }
        }

        safe_print("====================\r\n\r\n");
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Static vs Dynamic Allocation Comparison
 *
 * Dynamic: FreeRTOS allocates memory from its heap (pvPortMalloc).
 *   + Simple API
 *   - Allocation can fail at runtime
 *   - Heap fragmentation possible
 *
 * Static: Caller provides all memory.
 *   + Deterministic — all memory is reserved at compile time
 *   + No fragmentation
 *   + Required for safety certifications (MISRA, DO-178C)
 *   - More verbose API
 *   - Caller must manage buffer lifetimes
 * --------------------------------------------------------------------------- */

/* Static task */
#define STATIC_TASK_STACK  256
static StackType_t  xStaticStack[STATIC_TASK_STACK];
static StaticTask_t xStaticTCB;

void vStaticTask(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        safe_print("[STATIC-TASK] Running — zero heap used\r\n");
        vTaskDelay(pdMS_TO_TICKS(3000));
    }
}

/* Static queue */
#define STATIC_QUEUE_LEN   8
#define STATIC_QUEUE_ITEM  sizeof(uint32_t)
static uint8_t       ucStaticQueueStorage[STATIC_QUEUE_LEN * STATIC_QUEUE_ITEM];
static StaticQueue_t xStaticQueueStruct;
static QueueHandle_t xStaticQueue = NULL;

/* Static semaphore */
static StaticSemaphore_t xStaticSemStruct;
static SemaphoreHandle_t xStaticSem = NULL;

void vStaticObjectsDemo(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Use static queue */
        uint32_t val = xTaskGetTickCount();
        xQueueSend(xStaticQueue, &val, 0);
        xQueueReceive(xStaticQueue, &val, 0);

        /* Use static semaphore */
        xSemaphoreTake(xStaticSem, 0);
        xSemaphoreGive(xStaticSem);

        char buf[80];
        snprintf(buf, sizeof(buf),
                 "[STATIC-OBJ] Queue and semaphore working, heap still free: %u\r\n",
                 (unsigned)xPortGetFreeHeapSize());
        safe_print(buf);

        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}

/* ---------------------------------------------------------------------------
 * Example 4: Fixed-Block Memory Pool
 *
 * For applications needing deterministic alloc/free with zero fragmentation,
 * implement a fixed-block pool on top of static memory. Each block is
 * the same size — no fragmentation is possible.
 *
 * This is conceptually similar to the memory pool in examples/11_memory_pool.c
 * but simplified for FreeRTOS integration with mutex protection.
 * --------------------------------------------------------------------------- */
#define POOL_BLOCK_SIZE  64
#define POOL_BLOCK_COUNT 16

typedef struct {
    uint8_t             memory[POOL_BLOCK_COUNT][POOL_BLOCK_SIZE];
    uint8_t             free_map[POOL_BLOCK_COUNT]; /* 1 = free, 0 = allocated */
    SemaphoreHandle_t   mutex;
    SemaphoreHandle_t   available;  /* Counting semaphore = free block count */
    uint32_t            alloc_count;
    uint32_t            free_count;
} MemPool_t;

static MemPool_t xPool;

static void pool_init(MemPool_t *pool)
{
    memset(pool->memory, 0, sizeof(pool->memory));
    memset(pool->free_map, 1, sizeof(pool->free_map));
    pool->mutex     = xSemaphoreCreateMutex();
    pool->available = xSemaphoreCreateCounting(POOL_BLOCK_COUNT, POOL_BLOCK_COUNT);
    pool->alloc_count = 0;
    pool->free_count  = 0;
}

static void *pool_alloc(MemPool_t *pool, TickType_t timeout)
{
    if (xSemaphoreTake(pool->available, timeout) != pdTRUE) {
        return NULL;
    }

    xSemaphoreTake(pool->mutex, portMAX_DELAY);
    void *ptr = NULL;
    for (int i = 0; i < POOL_BLOCK_COUNT; i++) {
        if (pool->free_map[i]) {
            pool->free_map[i] = 0;
            ptr = pool->memory[i];
            pool->alloc_count++;
            break;
        }
    }
    xSemaphoreGive(pool->mutex);

    return ptr;
}

static void pool_free(MemPool_t *pool, void *ptr)
{
    if (ptr == NULL) return;

    uintptr_t offset = (uintptr_t)ptr - (uintptr_t)pool->memory;
    int index = (int)(offset / POOL_BLOCK_SIZE);

    if (index < 0 || index >= POOL_BLOCK_COUNT) return;

    xSemaphoreTake(pool->mutex, portMAX_DELAY);
    pool->free_map[index] = 1;
    pool->free_count++;
    xSemaphoreGive(pool->mutex);

    xSemaphoreGive(pool->available);
}

void vPoolUserTask(void *pvParameters)
{
    int task_id = (int)(uintptr_t)pvParameters;

    for (;;) {
        char buf[128];
        void *block = pool_alloc(&xPool, pdMS_TO_TICKS(1000));

        if (block != NULL) {
            snprintf(buf, sizeof(buf),
                     "[POOL-%d] Allocated block at %p (free: %u/%d)\r\n",
                     task_id, block,
                     (unsigned)uxSemaphoreGetCount(xPool.available),
                     POOL_BLOCK_COUNT);
            safe_print(buf);

            memset(block, task_id, POOL_BLOCK_SIZE);
            vTaskDelay(pdMS_TO_TICKS(500 + task_id * 200));

            pool_free(&xPool, block);

            snprintf(buf, sizeof(buf),
                     "[POOL-%d] Freed block (free: %u/%d)\r\n",
                     task_id,
                     (unsigned)uxSemaphoreGetCount(xPool.available),
                     POOL_BLOCK_COUNT);
            safe_print(buf);
        } else {
            snprintf(buf, sizeof(buf),
                     "[POOL-%d] Alloc timeout\r\n", task_id);
            safe_print(buf);
        }

        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

/* ---------------------------------------------------------------------------
 * Example 5: heap_5 Multi-Region Configuration
 *
 * heap_5 extends heap_4 to span multiple non-contiguous memory regions.
 * This is common on MCUs with internal SRAM, CCM RAM, and external SRAM.
 *
 * vPortDefineHeapRegions() MUST be called before any pvPortMalloc() —
 * meaning before xTaskCreate or xQueueCreate calls.
 *
 * Uncomment to use with heap_5.c:
 * --------------------------------------------------------------------------- */
#if 0
static void configure_heap_5(void)
{
    /*
     * Define memory regions. The array must be terminated with { NULL, 0 }.
     * Regions should be listed in order of preference — allocations
     * use the first region with enough space.
     */
    static const HeapRegion_t xHeapRegions[] = {
        { (uint8_t *)0x20000000, 64 * 1024 },   /* 64 KB internal SRAM */
        { (uint8_t *)0x10000000, 64 * 1024 },   /* 64 KB CCM RAM */
        { (uint8_t *)0x60000000, 512 * 1024 },  /* 512 KB external SRAM */
        { NULL, 0 }                              /* Terminator */
    };

    vPortDefineHeapRegions(xHeapRegions);
}
#endif

/* ---------------------------------------------------------------------------
 * Hooks
 * --------------------------------------------------------------------------- */
#if (configUSE_MALLOC_FAILED_HOOK == 1)
void vApplicationMallocFailedHook(void)
{
    /*
     * Called when pvPortMalloc returns NULL. This hook provides a centralized
     * place to handle allocation failures.
     *
     * Common actions:
     *   - Log the failure with task name and requested size
     *   - Trigger a system reset
     *   - Assert (halt in debug builds)
     */
    safe_print("!! MALLOC FAILED — system out of heap !!\r\n");

    char buf[128];
    snprintf(buf, sizeof(buf),
             "  Free: %u, Min ever: %u\r\n",
             (unsigned)xPortGetFreeHeapSize(),
             (unsigned)xPortGetMinimumEverFreeHeapSize());
    safe_print(buf);

    taskDISABLE_INTERRUPTS();
    for (;;);
}
#endif

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    (void)xTask;
    char buf[80];
    snprintf(buf, sizeof(buf), "!! STACK OVERFLOW: %s !!\r\n", pcTaskName);
    uart_print(buf);
    taskDISABLE_INTERRUPTS();
    for (;;);
}

void vApplicationIdleHook(void) { __asm volatile("wfi"); }

/* ---------------------------------------------------------------------------
 * Main
 * --------------------------------------------------------------------------- */
int main(void)
{
    hw_init();

    /* For heap_5, call vPortDefineHeapRegions() FIRST */
    /* configure_heap_5(); */

    xPrintMtx = xSemaphoreCreateMutex();

    /* Static objects */
    xStaticQueue = xQueueCreateStatic(STATIC_QUEUE_LEN, STATIC_QUEUE_ITEM,
                                       ucStaticQueueStorage, &xStaticQueueStruct);
    xStaticSem = xSemaphoreCreateBinaryStatic(&xStaticSemStruct);
    xSemaphoreGive(xStaticSem);

    /* Memory pool */
    pool_init(&xPool);

    /* Stack monitoring targets */
    xTaskCreate(vSmallStackTask,  "SmallStk",  128, NULL, 1, &xSmallStackHandle);
    xTaskCreate(vMediumStackTask, "MedStk",    256, NULL, 1, &xMediumStackHandle);
    xTaskCreate(vLargeStackTask,  "LargeStk",  512, NULL, 1, &xLargeStackHandle);

    /* Monitor tasks */
    xTaskCreate(vHeapMonitorTask,  "HeapMon",  512, NULL, 1, NULL);
    xTaskCreate(vStackMonitorTask, "StkMon",   512, NULL, 1, NULL);

    /* Static allocation demo */
    xTaskCreateStatic(vStaticTask, "StaticT", STATIC_TASK_STACK,
                      NULL, 1, xStaticStack, &xStaticTCB);
    xTaskCreate(vStaticObjectsDemo, "StatObj", 256, NULL, 1, NULL);

    /* Memory pool users */
    for (int i = 0; i < 4; i++) {
        char name[12];
        snprintf(name, sizeof(name), "Pool%d", i);
        xTaskCreate(vPoolUserTask, name, 256, (void *)(uintptr_t)i, 2, NULL);
    }

    vTaskStartScheduler();
    for (;;);
}
