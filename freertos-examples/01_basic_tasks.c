/**
 * FreeRTOS Example 01 — Basic Task Creation, Priorities, and Scheduling
 *
 * Demonstrates:
 *   - Creating tasks with xTaskCreate() and xTaskCreateStatic()
 *   - Task priorities and preemption behavior
 *   - vTaskDelay() vs vTaskDelayUntil() for periodic execution
 *   - Task deletion, suspension, and resumption
 *   - Stack high-water mark monitoring
 *   - vTaskList() for runtime task inspection
 *
 * Target: ARM Cortex-M4 (STM32F4xx) — concepts apply to any FreeRTOS port.
 */

#include "FreeRTOS.h"
#include "task.h"
#include <stdio.h>
#include <string.h>

/* ---------------------------------------------------------------------------
 * Hardware abstraction stubs — replace with real implementations
 * --------------------------------------------------------------------------- */
static void hw_init(void)        { /* SystemClock_Config, GPIO, UART init */ }
static void led_toggle(int led)  { /* Toggle LED on GPIO pin */  (void)led; }
static int  read_sensor(void)    { static int v = 0; return v++ % 100; }
static void uart_print(const char *s) { printf("%s", s); }

/* ---------------------------------------------------------------------------
 * Task handles — used for suspend/resume/delete/notify
 * --------------------------------------------------------------------------- */
static TaskHandle_t xLEDTaskHandle      = NULL;
static TaskHandle_t xSensorTaskHandle   = NULL;
static TaskHandle_t xMonitorTaskHandle  = NULL;
static TaskHandle_t xPeriodicTaskHandle = NULL;
static TaskHandle_t xStaticTaskHandle   = NULL;

/* ---------------------------------------------------------------------------
 * Example 1: Simple LED blink task
 *
 * This task toggles an LED every 500 ms. It demonstrates the most basic
 * FreeRTOS task pattern: an infinite loop with a delay.
 *
 * vTaskDelay() puts the task into the Blocked state for the specified number
 * of ticks. While blocked, the task consumes zero CPU time and the scheduler
 * runs other tasks (or the idle task).
 *
 * pdMS_TO_TICKS() converts milliseconds to tick counts, accounting for
 * configTICK_RATE_HZ. At 1000 Hz tick rate, pdMS_TO_TICKS(500) = 500 ticks.
 * --------------------------------------------------------------------------- */
void vLEDBlinkTask(void *pvParameters)
{
    const int led_num = (int)(uintptr_t)pvParameters;
    uint32_t toggle_count = 0;

    for (;;) {
        led_toggle(led_num);
        toggle_count++;

        if (toggle_count % 20 == 0) {
            char buf[64];
            snprintf(buf, sizeof(buf), "[LED] Toggled %lu times\r\n",
                     (unsigned long)toggle_count);
            uart_print(buf);
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Sensor reading task with periodic execution
 *
 * Uses vTaskDelayUntil() for drift-free periodic execution. Unlike vTaskDelay()
 * which delays relative to the current time, vTaskDelayUntil() delays until
 * an absolute tick count. This means the period remains constant regardless
 * of how long the task body takes to execute.
 *
 *   vTaskDelay(100):      |--work--|---delay 100 ticks---|--work--|---delay---|
 *                         Period = work_time + 100 ticks (varies!)
 *
 *   vTaskDelayUntil(100): |--work--|---delay---|--work--|---delay---|
 *                         Period = exactly 100 ticks (constant)
 * --------------------------------------------------------------------------- */
void vSensorReadTask(void *pvParameters)
{
    (void)pvParameters;
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xPeriod = pdMS_TO_TICKS(100); /* 10 Hz sampling */
    uint32_t sample_count = 0;

    for (;;) {
        int value = read_sensor();
        sample_count++;

        if (sample_count % 50 == 0) {
            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[SENSOR] Sample #%lu: value=%d, tick=%lu\r\n",
                     (unsigned long)sample_count, value,
                     (unsigned long)xTaskGetTickCount());
            uart_print(buf);
        }

        xTaskDelayUntil(&xLastWakeTime, xPeriod);
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Stack and task monitor
 *
 * Periodically checks the stack high-water mark of all tasks. The high-water
 * mark is the minimum number of free stack words ever recorded. If this
 * reaches zero, a stack overflow has (or will) occur.
 *
 * uxTaskGetStackHighWaterMark() returns the value in WORDS (not bytes).
 * On a 32-bit ARM, multiply by 4 to get bytes.
 *
 * vTaskList() fills a buffer with a formatted table of all tasks:
 *   Name          State  Priority  Stack   Num
 *   LED           R      2         180     1
 *   Sensor        B      3         120     2
 *   Monitor       B      1         200     3
 *   IDLE          R      0          90     4
 *
 * States: R=Ready, B=Blocked, S=Suspended, D=Deleted, X=Running
 * --------------------------------------------------------------------------- */
void vMonitorTask(void *pvParameters)
{
    (void)pvParameters;
    char pcStatsBuffer[512];

    for (;;) {
        uart_print("\r\n=== Task Monitor ===\r\n");

        /* Individual stack checks */
        if (xLEDTaskHandle != NULL) {
            UBaseType_t hwm = uxTaskGetStackHighWaterMark(xLEDTaskHandle);
            char buf[64];
            snprintf(buf, sizeof(buf), "  LED task stack HWM: %u words\r\n",
                     (unsigned)hwm);
            uart_print(buf);
        }

        if (xSensorTaskHandle != NULL) {
            UBaseType_t hwm = uxTaskGetStackHighWaterMark(xSensorTaskHandle);
            char buf[64];
            snprintf(buf, sizeof(buf), "  Sensor task stack HWM: %u words\r\n",
                     (unsigned)hwm);
            uart_print(buf);
        }

        /* Self stack check (passing NULL checks the calling task) */
        {
            UBaseType_t hwm = uxTaskGetStackHighWaterMark(NULL);
            char buf[64];
            snprintf(buf, sizeof(buf), "  Monitor task stack HWM: %u words\r\n",
                     (unsigned)hwm);
            uart_print(buf);
        }

        /* Full task list */
        uart_print("\r\nTask List:\r\n");
        uart_print("Name            State  Prio  Stack  Num\r\n");
        uart_print("--------------------------------------\r\n");

#if (configUSE_TRACE_FACILITY == 1)
        vTaskList(pcStatsBuffer);
        uart_print(pcStatsBuffer);
#endif

        /* Heap statistics */
        {
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "\r\nHeap free: %u bytes, Min ever free: %u bytes\r\n",
                     (unsigned)xPortGetFreeHeapSize(),
                     (unsigned)xPortGetMinimumEverFreeHeapSize());
            uart_print(buf);
        }

        uart_print("====================\r\n\r\n");

        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}

/* ---------------------------------------------------------------------------
 * Example 4: Task demonstrating suspension and resumption
 *
 * This task runs for a while, then suspends itself. Another task (or an
 * ISR via xTaskResumeFromISR) must call vTaskResume() to wake it up.
 *
 * vTaskSuspend(NULL) suspends the calling task. The task is removed from
 * all lists and placed in xSuspendedTaskList. Unlike blocking with a timeout,
 * suspended tasks NEVER wake up on their own — only vTaskResume() or
 * xTaskResumeFromISR() can move them back to the ready list.
 * --------------------------------------------------------------------------- */
void vPeriodicWorkTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t iterations = 0;

    for (;;) {
        iterations++;
        char buf[80];
        snprintf(buf, sizeof(buf),
                 "[PERIODIC] Iteration %lu at tick %lu\r\n",
                 (unsigned long)iterations,
                 (unsigned long)xTaskGetTickCount());
        uart_print(buf);

        vTaskDelay(pdMS_TO_TICKS(200));

        if (iterations % 10 == 0) {
            uart_print("[PERIODIC] Suspending self for external resume...\r\n");
            vTaskSuspend(NULL);
            uart_print("[PERIODIC] Resumed!\r\n");
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 5: Statically allocated task
 *
 * xTaskCreateStatic() does not allocate any memory from the FreeRTOS heap.
 * The caller provides both the stack memory (as a StackType_t array) and
 * the TCB memory (as a StaticTask_t). This is required when:
 *   - configSUPPORT_DYNAMIC_ALLOCATION is 0
 *   - You need deterministic memory usage (safety-critical systems)
 *   - You want to place stacks in specific memory regions (e.g., CCM RAM)
 * --------------------------------------------------------------------------- */
#define STATIC_TASK_STACK_SIZE  256
static StackType_t  xStaticTaskStack[STATIC_TASK_STACK_SIZE];
static StaticTask_t xStaticTaskTCB;

void vStaticAllocTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        uart_print("[STATIC] Running — no heap allocation used\r\n");

        UBaseType_t hwm = uxTaskGetStackHighWaterMark(NULL);
        char buf[64];
        snprintf(buf, sizeof(buf),
                 "[STATIC] Stack HWM: %u words (of %d total)\r\n",
                 (unsigned)hwm, STATIC_TASK_STACK_SIZE);
        uart_print(buf);

        vTaskDelay(pdMS_TO_TICKS(3000));
    }
}

/* ---------------------------------------------------------------------------
 * Example 6: Manager task — demonstrates dynamic priority changes and deletion
 *
 * vTaskPrioritySet() can change a task's priority at runtime. If the target
 * task's new priority is higher than the calling task's, a context switch
 * occurs immediately (in preemptive mode).
 *
 * vTaskDelete(xHandle) removes a task. If the task was dynamically allocated,
 * the idle task later frees its stack and TCB memory.
 * Passing NULL deletes the calling task.
 * --------------------------------------------------------------------------- */
void vManagerTask(void *pvParameters)
{
    (void)pvParameters;

    vTaskDelay(pdMS_TO_TICKS(15000));

    /* Demonstrate priority change */
    uart_print("[MANAGER] Boosting sensor task to priority 4\r\n");
    vTaskPrioritySet(xSensorTaskHandle, 4);
    vTaskDelay(pdMS_TO_TICKS(5000));

    uart_print("[MANAGER] Restoring sensor task to priority 3\r\n");
    vTaskPrioritySet(xSensorTaskHandle, 3);
    vTaskDelay(pdMS_TO_TICKS(2000));

    /* Demonstrate task resumption */
    if (eTaskGetState(xPeriodicTaskHandle) == eSuspended) {
        uart_print("[MANAGER] Resuming periodic task\r\n");
        vTaskResume(xPeriodicTaskHandle);
    }

    vTaskDelay(pdMS_TO_TICKS(5000));

    /* Demonstrate querying task state */
    eTaskState state = eTaskGetState(xLEDTaskHandle);
    const char *state_names[] = {"Running", "Ready", "Blocked", "Suspended", "Deleted", "Invalid"};
    char buf[64];
    snprintf(buf, sizeof(buf), "[MANAGER] LED task state: %s\r\n",
             state_names[state < 6 ? state : 5]);
    uart_print(buf);

    /* Self-delete */
    uart_print("[MANAGER] Task complete, deleting self\r\n");
    vTaskDelete(NULL);
}

/* ---------------------------------------------------------------------------
 * Required hooks — FreeRTOS calls these based on FreeRTOSConfig.h settings
 * --------------------------------------------------------------------------- */

#if (configUSE_IDLE_HOOK == 1)
void vApplicationIdleHook(void)
{
    __asm volatile ("wfi");  /* ARM Wait For Interrupt — low-power sleep */
}
#endif

#if (configCHECK_FOR_STACK_OVERFLOW >= 1)
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    (void)xTask;
    char buf[64];
    snprintf(buf, sizeof(buf), "STACK OVERFLOW: %s\r\n", pcTaskName);
    uart_print(buf);
    taskDISABLE_INTERRUPTS();
    for (;;) { }
}
#endif

#if (configUSE_MALLOC_FAILED_HOOK == 1)
void vApplicationMallocFailedHook(void)
{
    uart_print("MALLOC FAILED\r\n");
    taskDISABLE_INTERRUPTS();
    for (;;) { }
}
#endif

/* ---------------------------------------------------------------------------
 * Main — create tasks and start the scheduler
 *
 * Task creation order does not matter — the scheduler considers only
 * priorities. Higher-priority tasks preempt lower-priority ones.
 *
 * Priority assignments for this example:
 *   Priority 4: Manager (temporary task)
 *   Priority 3: Sensor reading (precise timing needed)
 *   Priority 2: LED blink, Periodic work
 *   Priority 1: Monitor (background diagnostics)
 *   Priority 0: Idle task (created by kernel), Static alloc demo
 * --------------------------------------------------------------------------- */
int main(void)
{
    hw_init();

    /* Dynamic tasks */
    xTaskCreate(vLEDBlinkTask,     "LED",      256, (void *)0, 2, &xLEDTaskHandle);
    xTaskCreate(vSensorReadTask,   "Sensor",   256, NULL,       3, &xSensorTaskHandle);
    xTaskCreate(vMonitorTask,      "Monitor",  512, NULL,       1, &xMonitorTaskHandle);
    xTaskCreate(vPeriodicWorkTask, "Periodic", 256, NULL,       2, &xPeriodicTaskHandle);
    xTaskCreate(vManagerTask,      "Manager",  256, NULL,       4, NULL);

    /* Static task — zero heap allocation */
    xStaticTaskHandle = xTaskCreateStatic(
        vStaticAllocTask, "Static", STATIC_TASK_STACK_SIZE,
        NULL, 0, xStaticTaskStack, &xStaticTaskTCB
    );

    uart_print("Starting FreeRTOS scheduler...\r\n");

    /*
     * vTaskStartScheduler() never returns. Internally it:
     *   1. Creates the idle task (priority 0)
     *   2. Creates the timer daemon task (if configUSE_TIMERS == 1)
     *   3. Disables interrupts
     *   4. Sets xSchedulerRunning = pdTRUE
     *   5. Calls xPortStartScheduler() which:
     *      a. Configures SysTick for configTICK_RATE_HZ
     *      b. Sets PendSV and SysTick to lowest interrupt priority
     *      c. Loads the context of the highest-priority ready task
     *      d. Enables interrupts
     *      e. Executes the first task
     */
    vTaskStartScheduler();

    /* Only reached if the scheduler fails to start (e.g., insufficient heap) */
    uart_print("ERROR: Scheduler failed to start\r\n");
    for (;;) { }
}
