/**
 * FreeRTOS Example 01: Task Creation, Scheduling, and Lifecycle
 *
 * Demonstrates:
 *   - Dynamic and static task creation
 *   - Task priorities and preemption
 *   - vTaskDelay vs xTaskDelayUntil for periodic execution
 *   - Task deletion and self-deletion
 *   - Stack high water mark monitoring
 *   - Runtime statistics and task listing
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Simulated Hardware Abstraction                                            */
/* ──────────────────────────────────────────────────────────────────────────── */

static void uart_printf(const char *fmt, ...) {
    /* In a real system, this writes to UART.
       Replace with your platform's serial output. */
    (void)fmt;
}

static uint16_t adc_read_channel(uint8_t channel) {
    /* Simulated ADC reading */
    static uint16_t counter = 0;
    return (counter++ * 37 + channel * 13) & 0x0FFF;
}

static void led_toggle(uint8_t led_num) {
    /* Simulated LED toggle */
    (void)led_num;
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: Basic Dynamic Task Creation                                    */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * A simple task that blinks an LED at a fixed rate using vTaskDelay.
 *
 * vTaskDelay(xTicksToDelay):
 *   - Places the calling task into the Blocked state for xTicksToDelay ticks
 *   - The delay is RELATIVE to the current tick count
 *   - pdMS_TO_TICKS() converts milliseconds to ticks using configTICK_RATE_HZ
 *   - The actual blocked time may be up to one tick less than specified
 *     (depends on when the call occurs relative to the tick interrupt)
 */
static void vBlinkTask(void *pvParameters) {
    uint8_t led_num = (uint8_t)(uintptr_t)pvParameters;
    const TickType_t xDelay = pdMS_TO_TICKS(500);

    for (;;) {
        led_toggle(led_num);
        uart_printf("[%lu] LED %u toggled\r\n", xTaskGetTickCount(), led_num);
        vTaskDelay(xDelay);
    }
}

/**
 * Create the blink task dynamically.
 *
 * xTaskCreate internally:
 *   1. Calls pvPortMalloc to allocate the TCB (Task Control Block)
 *   2. Calls pvPortMalloc to allocate the task's stack
 *   3. Initializes the stack with an artificial exception frame so the
 *      scheduler can "return" into the task function on first context switch
 *   4. Adds the task to the appropriate ready list based on its priority
 *   5. If the scheduler is already running and the new task's priority is
 *      higher than the current task, triggers an immediate context switch
 */
static void example1_dynamic_creation(void) {
    TaskHandle_t xBlinkHandle = NULL;

    BaseType_t xResult = xTaskCreate(
        vBlinkTask,                       /* Task function pointer */
        "Blink",                          /* Name (max configMAX_TASK_NAME_LEN chars) */
        configMINIMAL_STACK_SIZE,         /* Stack depth in words (not bytes) */
        (void *)(uintptr_t)0,             /* Parameter: LED 0 */
        1,                                /* Priority: 1 (above idle) */
        &xBlinkHandle                     /* Output: task handle */
    );

    if (xResult != pdPASS) {
        uart_printf("ERROR: Failed to create Blink task (out of heap?)\r\n");
        return;
    }

    uart_printf("Blink task created, handle=%p\r\n", (void *)xBlinkHandle);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: Static Task Creation                                           */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Static allocation avoids heap fragmentation and makes memory usage
 * fully deterministic at compile time. Required for safety-critical systems.
 *
 * xTaskCreateStatic internally:
 *   - Skips the pvPortMalloc calls (uses the provided buffers instead)
 *   - Otherwise identical to xTaskCreate: initializes the stack, sets up
 *     the TCB, and adds the task to the ready list
 *   - Returns the task handle directly (cannot fail if buffers are non-NULL)
 */

#define MONITOR_STACK_SIZE  256

static StackType_t  xMonitorStack[MONITOR_STACK_SIZE];
static StaticTask_t xMonitorTCB;

static void vMonitorTask(void *pvParameters) {
    (void)pvParameters;
    char pcStatsBuffer[512];

    for (;;) {
        uart_printf("\r\n===== System Monitor =====\r\n");

        /* vTaskList: generates a formatted table of all tasks.
         * Columns: Name, State (X=running, R=ready, B=blocked, S=suspended, D=deleted),
         * Priority, Stack High Water Mark (minimum free stack ever, in words), Task Number.
         *
         * Requires configUSE_TRACE_FACILITY == 1 and
         * configUSE_STATS_FORMATTING_FUNCTIONS == 1.
         */
        vTaskList(pcStatsBuffer);
        uart_printf("Task List:\r\n%s\r\n", pcStatsBuffer);

        /* vTaskGetRunTimeStats: shows each task's CPU utilization.
         * Requires configGENERATE_RUN_TIME_STATS == 1 and a high-resolution
         * timer configured via portCONFIGURE_TIMER_FOR_RUN_TIME_STATS() and
         * portGET_RUN_TIME_COUNTER_VALUE(). */
#if (configGENERATE_RUN_TIME_STATS == 1)
        vTaskGetRunTimeStats(pcStatsBuffer);
        uart_printf("Runtime Stats:\r\n%s\r\n", pcStatsBuffer);
#endif

        /* Report heap usage */
        uart_printf("Free heap: %u bytes (min ever: %u bytes)\r\n",
                     (unsigned)xPortGetFreeHeapSize(),
                     (unsigned)xPortGetMinimumEverFreeHeapSize());

        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}

static void example2_static_creation(void) {
    TaskHandle_t xHandle = xTaskCreateStatic(
        vMonitorTask,
        "Monitor",
        MONITOR_STACK_SIZE,
        NULL,
        configMAX_PRIORITIES - 1,   /* Highest application priority */
        xMonitorStack,
        &xMonitorTCB
    );

    /* xTaskCreateStatic only returns NULL if the buffer pointers are NULL */
    configASSERT(xHandle != NULL);
    uart_printf("Monitor task created (static), handle=%p\r\n", (void *)xHandle);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: Periodic Task with xTaskDelayUntil                             */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xTaskDelayUntil (formerly vTaskDelayUntil before v10.4.4):
 *   - Blocks until an ABSOLUTE tick count
 *   - Compensates for the task's own execution time
 *   - Produces jitter-free periodic execution
 *
 * How it works internally:
 *   1. Computes the target wake time: *pxPreviousWakeTime + xTimeIncrement
 *   2. If the target is in the future, blocks the task until that time
 *   3. Updates *pxPreviousWakeTime to the target time
 *   4. Returns pdTRUE if the task was actually delayed, pdFALSE if the
 *      deadline was already missed (the task ran longer than the period)
 *
 * Contrast with vTaskDelay:
 *   - vTaskDelay(N) delays N ticks FROM NOW → total period = execution_time + N
 *   - xTaskDelayUntil(&last, N) delays until last + N → total period = exactly N
 */
static void vSamplingTask(void *pvParameters) {
    (void)pvParameters;
    TickType_t xLastWakeTime;
    const TickType_t xPeriod = pdMS_TO_TICKS(100); /* 100 ms = 10 Hz sampling */

    /* Initialize xLastWakeTime with the current tick count.
       Must be done ONCE before the first call to xTaskDelayUntil. */
    xLastWakeTime = xTaskGetTickCount();

    for (;;) {
        /* Read sensor (variable execution time) */
        uint16_t sample = adc_read_channel(0);
        uart_printf("[%lu] ADC sample: %u\r\n", xTaskGetTickCount(), sample);

        /* Block until exactly 100 ms after the last wake time.
           If the ADC read took 12 ms, we'll block for 88 ms.
           If it took 3 ms, we'll block for 97 ms.
           Either way, the task runs at a precise 10 Hz rate. */
        xTaskDelayUntil(&xLastWakeTime, xPeriod);
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: Task Priorities and Preemption                                 */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Demonstrates how the scheduler always runs the highest-priority ready task.
 *
 * Scheduler rules:
 *   1. The highest-priority READY task always runs (preemptive scheduling)
 *   2. Equal-priority tasks share CPU via round-robin time-slicing
 *      (one tick slice each, if configUSE_TIME_SLICING == 1)
 *   3. A task becomes "ready" when its delay expires, a semaphore is given,
 *      a queue item arrives, etc.
 *   4. A context switch happens:
 *      - On every tick interrupt (for time-slicing)
 *      - When a higher-priority task becomes ready
 *      - When the running task blocks, yields, or is suspended
 */

static void vHighPriorityTask(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        uart_printf("[%lu] HIGH priority task running\r\n", xTaskGetTickCount());

        /* Simulate work */
        volatile uint32_t i;
        for (i = 0; i < 100000; i++) { }

        /* Release CPU to allow lower-priority tasks to run */
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void vMediumPriorityTask(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        uart_printf("[%lu] MEDIUM priority task running\r\n", xTaskGetTickCount());
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

static void vLowPriorityTask(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        uart_printf("[%lu] LOW priority task running\r\n", xTaskGetTickCount());
        vTaskDelay(pdMS_TO_TICKS(50));
    }
}

static void example4_priorities(void) {
    xTaskCreate(vHighPriorityTask,   "High",   configMINIMAL_STACK_SIZE, NULL, 3, NULL);
    xTaskCreate(vMediumPriorityTask, "Medium", configMINIMAL_STACK_SIZE, NULL, 2, NULL);
    xTaskCreate(vLowPriorityTask,    "Low",    configMINIMAL_STACK_SIZE, NULL, 1, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 5: Dynamic Priority Adjustment                                    */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * vTaskPrioritySet(xTask, uxNewPriority):
 *   - Changes a task's priority at runtime
 *   - Pass NULL as xTask to change the calling task's own priority
 *   - If the new priority is higher than the currently running task's priority,
 *     a context switch occurs immediately
 *   - If the task has inherited a higher priority via mutex inheritance,
 *     vTaskPrioritySet changes the BASE priority; the effective priority
 *     remains at the inherited level until the mutex is released
 */

static TaskHandle_t xWorkerHandle = NULL;

static void vWorkerTask(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        UBaseType_t uxPriority = uxTaskPriorityGet(NULL);
        uart_printf("[%lu] Worker running at priority %lu\r\n",
                     xTaskGetTickCount(), (unsigned long)uxPriority);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vPriorityControllerTask(void *pvParameters) {
    (void)pvParameters;
    UBaseType_t uxNewPriority = 1;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(3000));

        /* Cycle worker between priority 1, 2, and 3 */
        uxNewPriority = (uxNewPriority % 3) + 1;
        uart_printf("[%lu] Setting Worker priority to %lu\r\n",
                     xTaskGetTickCount(), (unsigned long)uxNewPriority);
        vTaskPrioritySet(xWorkerHandle, uxNewPriority);
    }
}

static void example5_priority_adjustment(void) {
    xTaskCreate(vWorkerTask, "Worker", configMINIMAL_STACK_SIZE, NULL, 1, &xWorkerHandle);
    xTaskCreate(vPriorityControllerTask, "PriCtrl", configMINIMAL_STACK_SIZE, NULL, 4, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 6: Task Deletion                                                  */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * vTaskDelete(xTaskToDelete):
 *   - Removes the task from all kernel lists (ready, blocked, suspended, event)
 *   - If the task was dynamically created, its memory (TCB + stack) is freed
 *     by the IDLE task (not immediately)
 *   - Pass NULL to delete the calling task (self-deletion)
 *   - WARNING: Any mutexes held by the deleted task are NOT released.
 *     Design your system so tasks release all resources before deletion.
 *
 * INCLUDE_vTaskDelete must be set to 1 in FreeRTOSConfig.h.
 */

static void vOneTimeSetupTask(void *pvParameters) {
    (void)pvParameters;

    uart_printf("[%lu] One-time setup: initializing peripherals...\r\n",
                 xTaskGetTickCount());

    /* Simulate initialization work */
    volatile uint32_t i;
    for (i = 0; i < 500000; i++) { }

    uart_printf("[%lu] Setup complete — deleting self\r\n", xTaskGetTickCount());

    /* Self-delete: the task function does not need to return.
       The idle task will reclaim the stack and TCB memory. */
    vTaskDelete(NULL);

    /* Code here is unreachable. */
}

static TaskHandle_t xTemporaryTaskHandle = NULL;

static void vSupervisorTask(void *pvParameters) {
    (void)pvParameters;

    /* Create a temporary worker */
    xTaskCreate(vOneTimeSetupTask, "Setup", configMINIMAL_STACK_SIZE, NULL, 2,
                &xTemporaryTaskHandle);

    for (;;) {
        /* Check if the setup task still exists */
        eTaskState eState = eTaskGetState(xTemporaryTaskHandle);
        if (eState == eDeleted || eState == eInvalid) {
            uart_printf("[%lu] Setup task has been deleted\r\n", xTaskGetTickCount());
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }

    /* Supervisor continues with normal operation */
    for (;;) {
        uart_printf("[%lu] Supervisor running normally\r\n", xTaskGetTickCount());
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 7: Stack High Water Mark Monitoring                               */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * uxTaskGetStackHighWaterMark(xTask):
 *   - Returns the minimum number of FREE stack WORDS the task has ever had
 *   - Internally, the kernel fills the stack with a known pattern (0xA5A5A5A5)
 *     at creation and scans from the bottom to find how far the pattern extends
 *   - A return value close to 0 indicates the task is at risk of stack overflow
 *   - Use this during development to right-size your stack allocations
 *
 * Requires INCLUDE_uxTaskGetStackHighWaterMark == 1 in FreeRTOSConfig.h.
 *
 * Stack sizing strategy:
 *   1. Start with generous stacks (e.g., 512 or 1024 words)
 *   2. Exercise all code paths under load
 *   3. Check high water marks and reduce stack sizes, keeping at least
 *      50-100 words of margin for ISR nesting and unexpected recursion
 */

static void vStackTestTask(void *pvParameters) {
    (void)pvParameters;
    char localBuffer[128]; /* deliberate stack usage */

    for (;;) {
        memset(localBuffer, 0, sizeof(localBuffer));

        UBaseType_t uxHighWaterMark = uxTaskGetStackHighWaterMark(NULL);
        uart_printf("[%lu] StackTest: high water mark = %lu words (%lu bytes free)\r\n",
                     xTaskGetTickCount(),
                     (unsigned long)uxHighWaterMark,
                     (unsigned long)(uxHighWaterMark * sizeof(StackType_t)));

        /* Warn if stack is getting low */
        if (uxHighWaterMark < 50) {
            uart_printf("WARNING: Stack dangerously low in StackTest task!\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 8: Task Suspension and Resumption                                 */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * vTaskSuspend(xTask):
 *   - Moves the task to the Suspended state (removed from all ready/blocked lists)
 *   - The scheduler completely ignores suspended tasks
 *   - Unlike blocking, suspension has NO timeout — the task stays suspended
 *     until explicitly resumed
 *   - Pass NULL to suspend the calling task (self-suspend)
 *
 * vTaskResume(xTask):
 *   - Moves the task from Suspended to Ready
 *   - If the resumed task's priority > current task's priority, triggers context switch
 *
 * xTaskResumeFromISR(xTask):
 *   - ISR-safe version of vTaskResume
 *   - Returns pdTRUE if the resumed task has higher priority than the interrupted task
 *   - Caller should use portYIELD_FROM_ISR() with the return value
 */

static TaskHandle_t xDataLoggerHandle = NULL;

static void vDataLoggerTask(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulSampleCount = 0;

    for (;;) {
        uint16_t sample = adc_read_channel(1);
        ulSampleCount++;
        uart_printf("[%lu] Logger sample #%lu: %u\r\n",
                     xTaskGetTickCount(), ulSampleCount, sample);
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void vControlTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        uart_printf("[%lu] Control: suspending data logger for 5 seconds\r\n",
                     xTaskGetTickCount());
        vTaskSuspend(xDataLoggerHandle);

        vTaskDelay(pdMS_TO_TICKS(5000));

        uart_printf("[%lu] Control: resuming data logger\r\n", xTaskGetTickCount());
        vTaskResume(xDataLoggerHandle);

        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Required FreeRTOS Callbacks                                               */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * vApplicationIdleHook:
 *   Called on each iteration of the idle task's loop.
 *   Must NOT block or call any blocking API.
 *   Use for background maintenance or low-power sleep entry.
 */
void vApplicationIdleHook(void) {
    /* Enter low-power mode or perform background work */
}

/**
 * vApplicationStackOverflowHook:
 *   Called when a stack overflow is detected (requires configCHECK_FOR_STACK_OVERFLOW > 0).
 *   xTask: the offending task's handle.
 *   pcTaskName: the offending task's name.
 */
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask;
    uart_printf("FATAL: Stack overflow in task '%s'!\r\n", pcTaskName);
    for (;;) { }
}

/**
 * vApplicationMallocFailedHook:
 *   Called when pvPortMalloc returns NULL (requires configUSE_MALLOC_FAILED_HOOK == 1).
 */
void vApplicationMallocFailedHook(void) {
    uart_printf("FATAL: Heap allocation failed! Free heap: %u\r\n",
                 (unsigned)xPortGetFreeHeapSize());
    for (;;) { }
}

/**
 * vApplicationGetIdleTaskMemory / vApplicationGetTimerTaskMemory:
 *   Required when configSUPPORT_STATIC_ALLOCATION == 1.
 *   The kernel calls these to get memory for the idle task and timer daemon task.
 */
#if (configSUPPORT_STATIC_ALLOCATION == 1)
static StaticTask_t xIdleTaskTCB;
static StackType_t  xIdleTaskStack[configMINIMAL_STACK_SIZE];

void vApplicationGetIdleTaskMemory(StaticTask_t **ppxIdleTaskTCBBuffer,
                                   StackType_t **ppxIdleTaskStackBuffer,
                                   uint32_t *pulIdleTaskStackSize) {
    *ppxIdleTaskTCBBuffer   = &xIdleTaskTCB;
    *ppxIdleTaskStackBuffer = xIdleTaskStack;
    *pulIdleTaskStackSize   = configMINIMAL_STACK_SIZE;
}

static StaticTask_t xTimerTaskTCB;
static StackType_t  xTimerTaskStack[configTIMER_TASK_STACK_DEPTH];

void vApplicationGetTimerTaskMemory(StaticTask_t **ppxTimerTaskTCBBuffer,
                                    StackType_t **ppxTimerTaskStackBuffer,
                                    uint32_t *pulTimerTaskStackSize) {
    *ppxTimerTaskTCBBuffer   = &xTimerTaskTCB;
    *ppxTimerTaskStackBuffer = xTimerTaskStack;
    *pulTimerTaskStackSize   = configTIMER_TASK_STACK_DEPTH;
}
#endif

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main Entry Point                                                          */
/* ──────────────────────────────────────────────────────────────────────────── */

int main(void) {
    /* Initialize hardware (clocks, UART, etc.) — platform-specific */

    /* Create all tasks before starting the scheduler.
       This is the recommended pattern: create everything first, then start. */

    /* Example 1: Dynamic task creation */
    example1_dynamic_creation();

    /* Example 2: Static task creation with system monitoring */
    example2_static_creation();

    /* Example 3: Precise periodic sampling */
    xTaskCreate(vSamplingTask, "Sample", 256, NULL, 3, NULL);

    /* Example 4: Priority demonstration */
    example4_priorities();

    /* Example 5: Runtime priority adjustment */
    example5_priority_adjustment();

    /* Example 7: Stack monitoring */
    xTaskCreate(vStackTestTask, "StackTest", 512, NULL, 1, NULL);

    /* Example 8: Suspend/resume */
    xTaskCreate(vDataLoggerTask, "Logger", 256, NULL, 2, &xDataLoggerHandle);
    xTaskCreate(vControlTask, "Control", 256, NULL, 3, NULL);

    /**
     * vTaskStartScheduler():
     *   1. Creates the idle task (priority 0)
     *   2. Creates the timer daemon task (if configUSE_TIMERS == 1)
     *   3. Starts the SysTick timer for tick interrupts
     *   4. Enables interrupts
     *   5. Starts the first task via SVC exception
     *   6. NEVER RETURNS — execution continues inside the highest-priority ready task
     *
     * If this function returns, it means there wasn't enough heap memory
     * to create the idle task or timer task.
     */
    vTaskStartScheduler();

    /* Execution only reaches here if the scheduler fails to start */
    uart_printf("FATAL: Scheduler failed to start (insufficient heap?)\r\n");
    for (;;) { }

    return 0;
}
