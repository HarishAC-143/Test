/**
 * FreeRTOS Example 08: Memory Management — Heap Schemes and Strategies
 *
 * Demonstrates:
 *   - Heap usage monitoring
 *   - Static vs dynamic allocation patterns
 *   - Fragmentation-safe pool allocators
 *   - heap_4 behavior (first-fit with coalescence)
 *   - heap_5 multi-region configuration
 *   - Malloc failed hook and defensive allocation
 *   - Compile-time memory budget analysis
 *
 * FreeRTOS provides five heap implementations (heap_1 through heap_5).
 * Link exactly ONE into your project. This example demonstrates patterns
 * that work with any scheme, with special focus on heap_4 and heap_5.
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Simulated Hardware                                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

static void uart_printf(const char *fmt, ...) { (void)fmt; }

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Heap Scheme Overview                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * heap_1: Allocate only. pvPortMalloc bumps a pointer; vPortFree is a no-op.
 *         Best for systems that create all objects at startup.
 *         Deterministic O(1) allocation.
 *         No fragmentation possible (since memory is never freed).
 *
 * heap_2: Best-fit with linked free-list. No coalescence.
 *         pvPortMalloc searches the free list for the smallest fitting block.
 *         vPortFree returns the block to the free list.
 *         Adjacent free blocks are NOT merged → fragmentation over time.
 *         Only suitable for same-size allocations (e.g., fixed-size tasks).
 *
 * heap_3: Thread-safe wrapper around the standard C library's malloc/free.
 *         Uses vTaskSuspendAll/xTaskResumeAll for thread safety.
 *         configTOTAL_HEAP_SIZE is NOT used (heap size = linker script).
 *         Behavior depends entirely on the toolchain's allocator.
 *
 * heap_4: First-fit with linked free-list and COALESCENCE.
 *         pvPortMalloc finds the first block large enough.
 *         vPortFree merges adjacent free blocks to combat fragmentation.
 *         Free list is sorted by address for efficient merging.
 *         This is the most commonly used scheme.
 *
 * heap_5: Same as heap_4 but supports non-contiguous memory regions.
 *         Must call vPortDefineHeapRegions() before any allocation.
 *         Useful when you have internal SRAM + external SDRAM.
 */

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: Heap Monitoring Task                                           */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xPortGetFreeHeapSize():
 *   Returns the current number of free bytes in the FreeRTOS heap.
 *   Available in heap_1, heap_2, heap_4, and heap_5.
 *   NOT available in heap_3 (which wraps the standard library).
 *
 * xPortGetMinimumEverFreeHeapSize():
 *   Returns the LOWEST number of free bytes ever recorded.
 *   This is the "high water mark" for heap usage.
 *   Use it to determine how much margin you have.
 *   Available in heap_4 and heap_5 only.
 *
 * These functions are NOT ISR-safe — call from task context only.
 */

typedef struct {
    size_t     xFreeHeap;
    size_t     xMinEverFreeHeap;
    size_t     xTotalHeap;
    uint32_t   ulAllocCount;
    uint32_t   ulFreeCount;
    TickType_t xTimestamp;
} HeapSnapshot_t;

static volatile uint32_t g_alloc_count = 0;
static volatile uint32_t g_free_count = 0;

/* Trace hooks to count allocations (define in FreeRTOSConfig.h):
 *   #define traceMALLOC(pvAddress, uiSize) g_alloc_count++
 *   #define traceFREE(pvAddress, uiSize)   g_free_count++
 */

static void vHeapMonitorTask(void *pvParameters) {
    (void)pvParameters;
    HeapSnapshot_t xSnapshot;

    for (;;) {
        xSnapshot.xFreeHeap         = xPortGetFreeHeapSize();
        xSnapshot.xMinEverFreeHeap  = xPortGetMinimumEverFreeHeapSize();
        xSnapshot.xTotalHeap        = configTOTAL_HEAP_SIZE;
        xSnapshot.ulAllocCount      = g_alloc_count;
        xSnapshot.ulFreeCount       = g_free_count;
        xSnapshot.xTimestamp        = xTaskGetTickCount();

        size_t xUsed = xSnapshot.xTotalHeap - xSnapshot.xFreeHeap;
        uint32_t ulUsagePercent = (uint32_t)((xUsed * 100) / xSnapshot.xTotalHeap);

        uart_printf("\r\n===== Heap Status [%lu] =====\r\n", xSnapshot.xTimestamp);
        uart_printf("  Total:         %u bytes\r\n", (unsigned)xSnapshot.xTotalHeap);
        uart_printf("  Used:          %u bytes (%lu%%)\r\n", (unsigned)xUsed, ulUsagePercent);
        uart_printf("  Free:          %u bytes\r\n", (unsigned)xSnapshot.xFreeHeap);
        uart_printf("  Min ever free: %u bytes\r\n", (unsigned)xSnapshot.xMinEverFreeHeap);
        uart_printf("  Margin:        %u bytes\r\n", (unsigned)xSnapshot.xMinEverFreeHeap);
        uart_printf("  Allocs/Frees:  %lu / %lu\r\n",
                     xSnapshot.ulAllocCount, xSnapshot.ulFreeCount);

        /* Warn if heap usage is high */
        if (xSnapshot.xMinEverFreeHeap < 1024) {
            uart_printf("  *** WARNING: Heap margin critically low! ***\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(10000));
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: Safe Allocation Wrapper                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * pvPortMalloc(xSize):
 *   - Allocates xSize bytes from the FreeRTOS heap
 *   - Returns a pointer to the allocated memory, or NULL if insufficient space
 *   - The returned pointer is aligned to portBYTE_ALIGNMENT (typically 8 bytes)
 *   - Thread-safe (uses vTaskSuspendAll internally)
 *
 * vPortFree(pv):
 *   - Returns memory to the FreeRTOS heap (heap_2/3/4/5 only)
 *   - No-op in heap_1
 *   - Thread-safe
 *   - Does NOT zero the freed memory
 *   - Passing NULL is safe (no-op)
 *   - Passing a pointer not from pvPortMalloc is UNDEFINED BEHAVIOR
 *
 * In heap_4, each allocation has an 8-byte header (BlockLink_t) containing:
 *   - pxNextFreeBlock: next free block pointer (or NULL if allocated)
 *   - xBlockSize: size of this block including header, with MSB as "allocated" flag
 */

static void *safe_malloc(size_t xSize, const char *pcCaller) {
    /* Check if there's enough free heap before attempting */
    size_t xFree = xPortGetFreeHeapSize();
    if (xSize > xFree) {
        uart_printf("WARN [%s]: requested %u bytes but only %u free\r\n",
                     pcCaller, (unsigned)xSize, (unsigned)xFree);
        return NULL;
    }

    void *pv = pvPortMalloc(xSize);
    if (pv == NULL) {
        uart_printf("ERROR [%s]: pvPortMalloc(%u) failed (fragmentation?)\r\n",
                     pcCaller, (unsigned)xSize);
    } else {
        uart_printf("[%s]: allocated %u bytes at %p (free: %u → %u)\r\n",
                     pcCaller, (unsigned)xSize, pv,
                     (unsigned)xFree, (unsigned)xPortGetFreeHeapSize());
    }

    return pv;
}

static void safe_free(void *pv, const char *pcCaller) {
    if (pv != NULL) {
        size_t xFreeBefore = xPortGetFreeHeapSize();
        vPortFree(pv);
        size_t xFreeAfter = xPortGetFreeHeapSize();
        uart_printf("[%s]: freed %u bytes at %p\r\n",
                     pcCaller, (unsigned)(xFreeAfter - xFreeBefore), pv);
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: Fixed-Size Memory Pool (Fragmentation-Safe)                    */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * For systems that frequently allocate and free same-sized blocks,
 * a fixed-size pool eliminates fragmentation entirely and provides
 * O(1) deterministic allocation.
 *
 * This pool is built on top of pvPortMalloc (uses heap for the initial
 * bulk allocation) but could also use a static array.
 */

typedef struct PoolBlock {
    struct PoolBlock *pxNext;
} PoolBlock_t;

typedef struct {
    PoolBlock_t      *pxFreeList;
    SemaphoreHandle_t xMutex;
    uint8_t          *pucMemory;
    size_t            xBlockSize;
    size_t            xTotalBlocks;
    size_t            xFreeBlocks;
} MemoryPool_t;

static BaseType_t xPoolInit(MemoryPool_t *pxPool, size_t xBlockSize,
                             size_t xNumBlocks) {
    /* Ensure block size can hold a pointer (for free list linkage) */
    if (xBlockSize < sizeof(PoolBlock_t)) {
        xBlockSize = sizeof(PoolBlock_t);
    }

    /* Align block size */
    xBlockSize = (xBlockSize + (portBYTE_ALIGNMENT - 1)) & ~(portBYTE_ALIGNMENT - 1);

    pxPool->pucMemory = (uint8_t *)pvPortMalloc(xBlockSize * xNumBlocks);
    if (pxPool->pucMemory == NULL) {
        return pdFAIL;
    }

    pxPool->xMutex = xSemaphoreCreateMutex();
    if (pxPool->xMutex == NULL) {
        vPortFree(pxPool->pucMemory);
        return pdFAIL;
    }

    pxPool->xBlockSize   = xBlockSize;
    pxPool->xTotalBlocks = xNumBlocks;
    pxPool->xFreeBlocks  = xNumBlocks;

    /* Chain all blocks into the free list */
    pxPool->pxFreeList = NULL;
    for (size_t i = 0; i < xNumBlocks; i++) {
        PoolBlock_t *pxBlock = (PoolBlock_t *)(pxPool->pucMemory + i * xBlockSize);
        pxBlock->pxNext = pxPool->pxFreeList;
        pxPool->pxFreeList = pxBlock;
    }

    return pdPASS;
}

static void *pvPoolAlloc(MemoryPool_t *pxPool) {
    void *pv = NULL;

    xSemaphoreTake(pxPool->xMutex, portMAX_DELAY);
    if (pxPool->pxFreeList != NULL) {
        pv = (void *)pxPool->pxFreeList;
        pxPool->pxFreeList = pxPool->pxFreeList->pxNext;
        pxPool->xFreeBlocks--;
    }
    xSemaphoreGive(pxPool->xMutex);

    return pv;
}

static void vPoolFree(MemoryPool_t *pxPool, void *pv) {
    if (pv == NULL) return;

    xSemaphoreTake(pxPool->xMutex, portMAX_DELAY);
    PoolBlock_t *pxBlock = (PoolBlock_t *)pv;
    pxBlock->pxNext = pxPool->pxFreeList;
    pxPool->pxFreeList = pxBlock;
    pxPool->xFreeBlocks++;
    xSemaphoreGive(pxPool->xMutex);
}

/* Pool usage example */

typedef struct {
    uint32_t ulSequence;
    uint8_t  ucData[60];
} Packet_t;

#define PACKET_POOL_SIZE 16
static MemoryPool_t xPacketPool;

static void vPacketProducer(void *pvParameters) {
    (void)pvParameters;
    static QueueHandle_t xPacketQueue = NULL;

    if (xPacketQueue == NULL) {
        xPacketQueue = xQueueCreate(PACKET_POOL_SIZE, sizeof(Packet_t *));
    }

    uint32_t ulSeq = 0;

    for (;;) {
        Packet_t *pxPacket = (Packet_t *)pvPoolAlloc(&xPacketPool);
        if (pxPacket != NULL) {
            pxPacket->ulSequence = ulSeq++;
            memset(pxPacket->ucData, (uint8_t)ulSeq, sizeof(pxPacket->ucData));

            uart_printf("[%lu] Pool alloc: seq=%lu (free: %u/%u)\r\n",
                         xTaskGetTickCount(), pxPacket->ulSequence,
                         (unsigned)xPacketPool.xFreeBlocks,
                         (unsigned)xPacketPool.xTotalBlocks);

            /* Simulate processing and return to pool */
            vTaskDelay(pdMS_TO_TICKS(50));

            vPoolFree(&xPacketPool, pxPacket);
        } else {
            uart_printf("[%lu] Pool exhausted! Waiting...\r\n", xTaskGetTickCount());
            vTaskDelay(pdMS_TO_TICKS(100));
        }

        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void example3_memory_pool(void) {
    BaseType_t xResult = xPoolInit(&xPacketPool, sizeof(Packet_t), PACKET_POOL_SIZE);
    configASSERT(xResult == pdPASS);

    xTaskCreate(vPacketProducer, "PktProd0", 256, NULL, 2, NULL);
    xTaskCreate(vPacketProducer, "PktProd1", 256, NULL, 2, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: Static Allocation Pattern                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * When configSUPPORT_STATIC_ALLOCATION == 1, every kernel object can be
 * created without using the heap. The application provides the memory.
 *
 * Benefits:
 *   - No heap needed (can set configTOTAL_HEAP_SIZE = 0 with heap_1)
 *   - Memory usage fully determined at compile time
 *   - No risk of allocation failure at runtime
 *   - Required for some safety standards (MISRA, DO-178C)
 *
 * Every *Create function has a *CreateStatic counterpart:
 *   xTaskCreate          → xTaskCreateStatic
 *   xQueueCreate         → xQueueCreateStatic
 *   xSemaphoreCreateBinary    → xSemaphoreCreateBinaryStatic
 *   xSemaphoreCreateMutex     → xSemaphoreCreateMutexStatic
 *   xSemaphoreCreateCounting  → xSemaphoreCreateCountingStatic
 *   xTimerCreate         → xTimerCreateStatic
 *   xEventGroupCreate    → xEventGroupCreateStatic
 *   xStreamBufferCreate  → xStreamBufferCreateStatic
 *   xMessageBufferCreate → xMessageBufferCreateStatic
 */

#define STATIC_TASK_STACK_SIZE  256
#define STATIC_QUEUE_LENGTH     8
#define STATIC_QUEUE_ITEM_SIZE  sizeof(uint32_t)

/* Pre-allocated memory for a task */
static StackType_t  xStaticTaskStack[STATIC_TASK_STACK_SIZE];
static StaticTask_t xStaticTaskTCB;

/* Pre-allocated memory for a queue */
static uint8_t      ucStaticQueueStorage[STATIC_QUEUE_LENGTH * STATIC_QUEUE_ITEM_SIZE];
static StaticQueue_t xStaticQueueStruct;

/* Pre-allocated memory for a semaphore */
static StaticSemaphore_t xStaticSemaphoreStruct;

static QueueHandle_t     xStaticQueue;
static SemaphoreHandle_t xStaticSemaphore;

static void vStaticTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulValue;

    for (;;) {
        if (xQueueReceive(xStaticQueue, &ulValue, portMAX_DELAY) == pdPASS) {
            uart_printf("[%lu] Static task received: %lu\r\n",
                         xTaskGetTickCount(), ulValue);

            xSemaphoreGive(xStaticSemaphore);
        }
    }
}

static void vStaticSenderTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulCounter = 0;

    for (;;) {
        ulCounter++;
        xQueueSend(xStaticQueue, &ulCounter, portMAX_DELAY);

        /* Wait for processing confirmation */
        xSemaphoreTake(xStaticSemaphore, portMAX_DELAY);
        uart_printf("[%lu] Static sender: confirmed #%lu\r\n",
                     xTaskGetTickCount(), ulCounter);

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void example4_static_allocation(void) {
    /* Create queue with static storage */
    xStaticQueue = xQueueCreateStatic(
        STATIC_QUEUE_LENGTH,
        STATIC_QUEUE_ITEM_SIZE,
        ucStaticQueueStorage,
        &xStaticQueueStruct
    );

    /* Create semaphore with static storage */
    xStaticSemaphore = xSemaphoreCreateBinaryStatic(&xStaticSemaphoreStruct);

    /* Create task with static stack and TCB */
    TaskHandle_t xHandle = xTaskCreateStatic(
        vStaticTask,
        "StaticRx",
        STATIC_TASK_STACK_SIZE,
        NULL,
        3,
        xStaticTaskStack,
        &xStaticTaskTCB
    );
    configASSERT(xHandle != NULL);

    /* The sender can still use dynamic allocation — mixing is fine */
    xTaskCreate(vStaticSenderTask, "StaticTx", 256, NULL, 2, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 5: heap_5 Multi-Region Configuration                              */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * heap_5 extends heap_4 to support non-contiguous memory regions.
 * Typical use case: internal SRAM + external SDRAM on an MCU.
 *
 * vPortDefineHeapRegions(xHeapRegions):
 *   - Must be called BEFORE any pvPortMalloc (before creating any tasks)
 *   - Takes an array of HeapRegion_t structs, terminated by {NULL, 0}
 *   - Regions MUST be in ascending address order
 *   - The kernel links all regions into a single free list
 *   - After this call, pvPortMalloc/vPortFree work across all regions
 *
 * HeapRegion_t:
 *   { pucStartAddress, xSizeInBytes }
 */

/*
 * Uncomment this block when using heap_5:
 *
 * void configure_heap_5(void) {
 *     extern uint8_t __heap_start__;  // Defined in linker script
 *     extern uint8_t __heap_end__;
 *     
 *     // External SDRAM mapped at 0xD0000000
 *     #define SDRAM_START  0xD0000000
 *     #define SDRAM_SIZE   (8 * 1024 * 1024)  // 8 MB
 *     
 *     static HeapRegion_t xHeapRegions[] = {
 *         { &__heap_start__, (size_t)(&__heap_end__ - &__heap_start__) },
 *         { (uint8_t *)SDRAM_START, SDRAM_SIZE },
 *         { NULL, 0 }  // Terminator
 *     };
 *     
 *     // MUST be called before any pvPortMalloc
 *     vPortDefineHeapRegions(xHeapRegions);
 * }
 */

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 6: Compile-Time Memory Budget                                     */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Memory budget calculation for a typical FreeRTOS application.
 * Use this as a template to estimate your system's memory requirements.
 *
 * TCB size: ~92 bytes (varies with config options enabled)
 * Queue overhead: ~76 bytes + (length * item_size)
 * Semaphore: ~76 bytes (queue with item_size = 0)
 * Mutex: ~80 bytes (queue + mutex-specific fields)
 * Event Group: ~24 bytes
 * Timer: ~44 bytes
 * Stream Buffer: ~76 bytes + buffer_size
 * heap_4 block header: 8 bytes per allocation
 *
 * Stack usage per task (words → bytes):
 *   128 words = 512 bytes (minimal task)
 *   256 words = 1024 bytes (typical simple task)
 *   512 words = 2048 bytes (task with printf, floating point)
 */

/* Static compile-time memory budget verification */
#define NUM_APP_TASKS        5
#define AVG_TASK_STACK       (256 * sizeof(StackType_t))
#define NUM_QUEUES           3
#define AVG_QUEUE_OVERHEAD   (76 + 16 * 4)  /* 16 items of 4 bytes */
#define NUM_SEMAPHORES       4
#define SEMAPHORE_OVERHEAD   76
#define NUM_MUTEXES          2
#define MUTEX_OVERHEAD       80
#define NUM_TIMERS           3
#define TIMER_OVERHEAD       44
#define TCB_SIZE             92
#define HEAP4_HEADER         8

#define ESTIMATED_HEAP_USAGE                                    \
    ((NUM_APP_TASKS * (TCB_SIZE + AVG_TASK_STACK + HEAP4_HEADER * 2)) + \
     (NUM_QUEUES * (AVG_QUEUE_OVERHEAD + HEAP4_HEADER)) +       \
     (NUM_SEMAPHORES * (SEMAPHORE_OVERHEAD + HEAP4_HEADER)) +   \
     (NUM_MUTEXES * (MUTEX_OVERHEAD + HEAP4_HEADER)) +          \
     (NUM_TIMERS * (TIMER_OVERHEAD + HEAP4_HEADER)))

/* Verify at compile time that our heap is large enough */
#if (ESTIMATED_HEAP_USAGE > configTOTAL_HEAP_SIZE)
#warning "Estimated heap usage exceeds configTOTAL_HEAP_SIZE!"
#endif

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Required Hooks                                                            */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) { }

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask;
    uart_printf("FATAL: Stack overflow in '%s'\r\n", pcTaskName);
    for (;;) { }
}

/**
 * vApplicationMallocFailedHook:
 *   Called when pvPortMalloc returns NULL.
 *   Requires configUSE_MALLOC_FAILED_HOOK == 1.
 *
 *   Common responses:
 *   1. Log the error for debugging
 *   2. Assert/halt in debug builds
 *   3. Attempt recovery (e.g., free cached data and retry)
 */
void vApplicationMallocFailedHook(void) {
    uart_printf("FATAL: Heap allocation failed!\r\n");
    uart_printf("  Free heap: %u bytes\r\n", (unsigned)xPortGetFreeHeapSize());
    uart_printf("  Min ever:  %u bytes\r\n", (unsigned)xPortGetMinimumEverFreeHeapSize());

    for (;;) { }
}

#if (configSUPPORT_STATIC_ALLOCATION == 1)
static StaticTask_t xIdleTCB;
static StackType_t  xIdleStack[configMINIMAL_STACK_SIZE];
void vApplicationGetIdleTaskMemory(StaticTask_t **ppxIdleTaskTCBBuffer,
                                   StackType_t **ppxIdleTaskStackBuffer,
                                   uint32_t *pulIdleTaskStackSize) {
    *ppxIdleTaskTCBBuffer   = &xIdleTCB;
    *ppxIdleTaskStackBuffer = xIdleStack;
    *pulIdleTaskStackSize   = configMINIMAL_STACK_SIZE;
}

static StaticTask_t xTimerTCB;
static StackType_t  xTimerStack[configTIMER_TASK_STACK_DEPTH];
void vApplicationGetTimerTaskMemory(StaticTask_t **ppxTimerTaskTCBBuffer,
                                    StackType_t **ppxTimerTaskStackBuffer,
                                    uint32_t *pulTimerTaskStackSize) {
    *ppxTimerTaskTCBBuffer   = &xTimerTCB;
    *ppxTimerTaskStackBuffer = xTimerStack;
    *pulTimerTaskStackSize   = configTIMER_TASK_STACK_DEPTH;
}
#endif

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main                                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

int main(void) {
    /* For heap_5, call vPortDefineHeapRegions() HERE, before anything else */
    /* configure_heap_5(); */

    uart_printf("Estimated heap usage: %u bytes\r\n", (unsigned)ESTIMATED_HEAP_USAGE);
    uart_printf("Configured heap size: %u bytes\r\n", (unsigned)configTOTAL_HEAP_SIZE);

    example3_memory_pool();
    example4_static_allocation();

    /* Heap monitor task — runs at low priority */
    xTaskCreate(vHeapMonitorTask, "HeapMon", 512, NULL, 1, NULL);

    vTaskStartScheduler();
    for (;;) { }
    return 0;
}
