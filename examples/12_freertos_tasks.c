/*
 * FreeRTOS Task Management Example
 *
 * Demonstrates: xTaskCreate, xTaskCreateStatic, vTaskDelay, vTaskDelayUntil,
 *               vTaskSuspend, vTaskResume, vTaskPrioritySet, vTaskDelete,
 *               uxTaskGetStackHighWaterMark, vTaskGetRunTimeStats
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10.x/v11.x
 */

#include "FreeRTOS.h"
#include "task.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ---------- Hardware Stubs (replace with real HAL on target) ---------- */

#define LED_GREEN_PIN   12
#define LED_RED_PIN     14
#define LED_BLUE_PIN    15

static volatile uint32_t gpio_odr = 0;
static volatile uint32_t adc_value = 2048;
static volatile uint32_t runtime_counter = 0;

static inline void HAL_Init(void) {}
static inline void SystemClock_Config(void) {}

static inline void led_toggle(uint32_t pin) { gpio_odr ^= (1U << pin); }
static inline void led_on(uint32_t pin)     { gpio_odr |= (1U << pin); }
static inline void led_off(uint32_t pin)    { gpio_odr &= ~(1U << pin); }

static inline uint32_t read_adc(uint32_t channel) {
    return adc_value + (runtime_counter & 0xFF);
}

static inline uint32_t read_temperature_sensor(void) {
    return 2200 + (runtime_counter & 0x3F);
}

void config_stats_timer(void)  { runtime_counter = 0; }
uint32_t get_stats_timer(void) { return ++runtime_counter; }

/* ---------- FreeRTOS Hooks ---------- */

void vApplicationMallocFailedHook(void)
{
    printf("[FATAL] Malloc failed! Free heap: %u bytes\r\n",
           (unsigned)xPortGetFreeHeapSize());
    for (;;);
}

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    printf("[FATAL] Stack overflow in task: %s\r\n", pcTaskName);
    for (;;);
}

void vApplicationIdleHook(void)
{
    /* Could enter low-power mode here */
}

/* =====================================================================
 * Example 1: Basic Task Creation (Dynamic)
 *
 * Creates two tasks at different priorities. Demonstrates that the
 * higher-priority task runs first and preempts the lower-priority task.
 * ===================================================================== */

static void vHighPriorityTask(void *pvParameters)
{
    const char *name = pcTaskGetName(NULL);
    uint32_t counter = 0;

    for (;;) {
        printf("[%s] Running, count=%lu, tick=%lu\r\n",
               name, counter++, (unsigned long)xTaskGetTickCount());

        /* Delay for 500ms — releases CPU to lower-priority tasks */
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vLowPriorityTask(void *pvParameters)
{
    const char *name = pcTaskGetName(NULL);
    uint32_t counter = 0;

    for (;;) {
        printf("[%s] Running, count=%lu, tick=%lu\r\n",
               name, counter++, (unsigned long)xTaskGetTickCount());

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

/* =====================================================================
 * Example 2: Static Task Creation
 *
 * Demonstrates xTaskCreateStatic — the application provides the stack
 * buffer and TCB storage. No heap allocation occurs.
 * ===================================================================== */

#define STATIC_TASK_STACK_SIZE  256

static StackType_t  xStaticTaskStack[STATIC_TASK_STACK_SIZE];
static StaticTask_t xStaticTaskTCB;

static void vStaticTask(void *pvParameters)
{
    uint32_t iteration = 0;

    for (;;) {
        printf("[StaticTask] Iteration %lu (stack allocated at compile time)\r\n",
               iteration++);
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* =====================================================================
 * Example 3: Periodic Task with vTaskDelayUntil
 *
 * Demonstrates fixed-frequency execution. Unlike vTaskDelay, the period
 * does not drift regardless of how long the task body takes.
 * ===================================================================== */

static void vPeriodicSensorTask(void *pvParameters)
{
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xPeriod = pdMS_TO_TICKS(100);  /* 10 Hz */
    uint32_t sample_count = 0;

    for (;;) {
        xTaskDelayUntil(&xLastWakeTime, xPeriod);

        uint32_t adc = read_adc(0);
        float voltage = (float)adc * 3.3f / 4095.0f;
        sample_count++;

        if ((sample_count % 50) == 0) {
            printf("[Sensor] Sample #%lu: ADC=%lu (%.2f V)\r\n",
                   sample_count, adc, (double)voltage);
        }
    }
}

/* =====================================================================
 * Example 4: Task Suspend and Resume
 *
 * A controller task periodically suspends and resumes a worker task
 * based on a simulated condition (e.g., temperature threshold).
 * ===================================================================== */

static TaskHandle_t xWorkerHandle = NULL;

static void vWorkerTask(void *pvParameters)
{
    uint32_t work_count = 0;

    for (;;) {
        led_toggle(LED_GREEN_PIN);
        printf("[Worker] Processing data block #%lu\r\n", work_count++);
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void vControllerTask(void *pvParameters)
{
    uint32_t cycle = 0;

    for (;;) {
        uint32_t temp_raw = read_temperature_sensor();
        float temp_c = (float)temp_raw / 100.0f;

        printf("[Controller] Cycle %lu, temp=%.1f°C\r\n",
               cycle++, (double)temp_c);

        if (temp_c > 25.0f && eTaskGetState(xWorkerHandle) != eSuspended) {
            printf("[Controller] Temperature high — suspending worker\r\n");
            vTaskSuspend(xWorkerHandle);
            led_on(LED_RED_PIN);
        } else if (temp_c <= 25.0f && eTaskGetState(xWorkerHandle) == eSuspended) {
            printf("[Controller] Temperature normal — resuming worker\r\n");
            vTaskResume(xWorkerHandle);
            led_off(LED_RED_PIN);
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

/* =====================================================================
 * Example 5: Dynamic Priority Adjustment
 *
 * A task monitors system load and adjusts another task's priority
 * at runtime. Demonstrates vTaskPrioritySet and uxTaskPriorityGet.
 * ===================================================================== */

static TaskHandle_t xAdaptiveTaskHandle = NULL;

static void vAdaptiveTask(void *pvParameters)
{
    for (;;) {
        UBaseType_t currentPriority = uxTaskPriorityGet(NULL);
        printf("[Adaptive] Running at priority %lu\r\n",
               (unsigned long)currentPriority);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vPriorityManagerTask(void *pvParameters)
{
    const UBaseType_t uxNormalPriority = 2;
    const UBaseType_t uxHighPriority = 4;
    uint32_t cycle = 0;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(3000));

        if ((cycle % 2) == 0) {
            printf("[PrioMgr] Boosting adaptive task to priority %lu\r\n",
                   (unsigned long)uxHighPriority);
            vTaskPrioritySet(xAdaptiveTaskHandle, uxHighPriority);
        } else {
            printf("[PrioMgr] Restoring adaptive task to priority %lu\r\n",
                   (unsigned long)uxNormalPriority);
            vTaskPrioritySet(xAdaptiveTaskHandle, uxNormalPriority);
        }
        cycle++;
    }
}

/* =====================================================================
 * Example 6: Task Deletion (Self-Delete and External Delete)
 *
 * Demonstrates vTaskDelete. A one-shot task deletes itself after
 * completing work. A supervisor deletes stalled tasks.
 * ===================================================================== */

static void vOneShotTask(void *pvParameters)
{
    uint32_t task_id = (uint32_t)(uintptr_t)pvParameters;

    printf("[OneShot-%lu] Performing initialization work...\r\n", task_id);
    vTaskDelay(pdMS_TO_TICKS(500));

    printf("[OneShot-%lu] Work complete, self-deleting\r\n", task_id);
    vTaskDelete(NULL);  /* Delete self — idle task will free memory */
}

static void vTaskSpawnerTask(void *pvParameters)
{
    uint32_t spawn_id = 0;

    for (;;) {
        char name[16];
        snprintf(name, sizeof(name), "OneShot%lu", spawn_id);

        TaskHandle_t h;
        BaseType_t ret = xTaskCreate(
            vOneShotTask, name, 128,
            (void *)(uintptr_t)spawn_id,
            2, &h
        );

        if (ret == pdPASS) {
            printf("[Spawner] Created %s\r\n", name);
        } else {
            printf("[Spawner] Failed to create %s (heap: %u)\r\n",
                   name, (unsigned)xPortGetFreeHeapSize());
        }

        spawn_id++;
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* =====================================================================
 * Example 7: Stack Monitoring
 *
 * Demonstrates uxTaskGetStackHighWaterMark to detect near-overflow
 * conditions. Reports stack usage for all running tasks.
 * ===================================================================== */

static TaskHandle_t xMonitoredTasks[4];
static const char *pMonitoredNames[4];
static uint32_t ulNumMonitored = 0;

static void vRegisterForMonitoring(TaskHandle_t h, const char *name)
{
    if (ulNumMonitored < 4) {
        xMonitoredTasks[ulNumMonitored] = h;
        pMonitoredNames[ulNumMonitored] = name;
        ulNumMonitored++;
    }
}

static void vStackMonitorTask(void *pvParameters)
{
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(5000));

        printf("\r\n--- Stack High Water Marks ---\r\n");
        for (uint32_t i = 0; i < ulNumMonitored; i++) {
            UBaseType_t hwm = uxTaskGetStackHighWaterMark(xMonitoredTasks[i]);
            printf("  %-16s : %3lu words remaining\r\n",
                   pMonitoredNames[i], (unsigned long)hwm);

            if (hwm < 30) {
                printf("  ** WARNING: %s stack critically low! **\r\n",
                       pMonitoredNames[i]);
            }
        }
        printf("  Heap free: %u bytes (min ever: %u)\r\n",
               (unsigned)xPortGetFreeHeapSize(),
               (unsigned)xPortGetMinimumEverFreeHeapSize());
        printf("-----------------------------\r\n\r\n");
    }
}

/* =====================================================================
 * Example 8: Runtime Statistics
 *
 * Uses vTaskGetRunTimeStats to display per-task CPU utilization.
 * Requires configGENERATE_RUN_TIME_STATS and a high-resolution timer.
 * ===================================================================== */

#if configGENERATE_RUN_TIME_STATS == 1

static void vRuntimeStatsTask(void *pvParameters)
{
    char pcStatsBuffer[512];

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(10000));

        vTaskGetRunTimeStats(pcStatsBuffer);
        printf("\r\n=== Runtime Statistics ===\r\n");
        printf("Task            Abs Time    %%Time\r\n");
        printf("--------------------------------\r\n");
        printf("%s", pcStatsBuffer);
        printf("================================\r\n\r\n");
    }
}

#endif

/* =====================================================================
 * Example 9: Passing Parameters to Tasks
 *
 * Shows safe ways to pass data: casting integers, using static structs,
 * and using heap-allocated structs.
 * ===================================================================== */

typedef struct {
    uint32_t task_id;
    uint32_t sample_rate_hz;
    uint8_t  adc_channel;
    float    threshold;
    char     label[16];
} TaskConfig_t;

static TaskConfig_t xSensorConfigs[] = {
    { .task_id = 0, .sample_rate_hz = 10, .adc_channel = 0,
      .threshold = 2.5f, .label = "Voltage" },
    { .task_id = 1, .sample_rate_hz = 5,  .adc_channel = 1,
      .threshold = 1.8f, .label = "Current" },
    { .task_id = 2, .sample_rate_hz = 1,  .adc_channel = 4,
      .threshold = 3.0f, .label = "TempRef" },
};

static void vConfigurableSensorTask(void *pvParameters)
{
    const TaskConfig_t *cfg = (const TaskConfig_t *)pvParameters;
    TickType_t period = pdMS_TO_TICKS(1000 / cfg->sample_rate_hz);
    TickType_t xLastWake = xTaskGetTickCount();
    uint32_t sample = 0;

    for (;;) {
        xTaskDelayUntil(&xLastWake, period);

        uint32_t raw = read_adc(cfg->adc_channel);
        float value = (float)raw * 3.3f / 4095.0f;

        if (value > cfg->threshold) {
            printf("[%s] ALERT: %.2f V exceeds threshold %.2f V (sample #%lu)\r\n",
                   cfg->label, (double)value, (double)cfg->threshold, sample);
        }
        sample++;
    }
}

/* =====================================================================
 * Main — select which example to run
 * ===================================================================== */

/* Set EXAMPLE_SELECT to choose which demo to build (1-9) */
#ifndef EXAMPLE_SELECT
#define EXAMPLE_SELECT  1
#endif

int main(void)
{
    HAL_Init();
    SystemClock_Config();

    printf("\r\n=== FreeRTOS Task Management Examples ===\r\n");
    printf("Running Example %d\r\n\r\n", EXAMPLE_SELECT);

#if EXAMPLE_SELECT == 1
    /* --- Example 1: Basic dynamic task creation --- */
    xTaskCreate(vHighPriorityTask, "HighPrio", 256, NULL, 3, NULL);
    xTaskCreate(vLowPriorityTask,  "LowPrio",  256, NULL, 1, NULL);

#elif EXAMPLE_SELECT == 2
    /* --- Example 2: Static task creation --- */
    xTaskCreateStatic(vStaticTask, "Static", STATIC_TASK_STACK_SIZE,
                      NULL, 2, xStaticTaskStack, &xStaticTaskTCB);

#elif EXAMPLE_SELECT == 3
    /* --- Example 3: Periodic task with vTaskDelayUntil --- */
    xTaskCreate(vPeriodicSensorTask, "Sensor10Hz", 256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 4
    /* --- Example 4: Suspend and resume --- */
    xTaskCreate(vWorkerTask,     "Worker",     256, NULL, 2, &xWorkerHandle);
    xTaskCreate(vControllerTask, "Controller", 256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 5
    /* --- Example 5: Dynamic priority adjustment --- */
    xTaskCreate(vAdaptiveTask,      "Adaptive",  256, NULL, 2, &xAdaptiveTaskHandle);
    xTaskCreate(vPriorityManagerTask, "PrioMgr", 256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 6
    /* --- Example 6: Task deletion (self-delete) --- */
    xTaskCreate(vTaskSpawnerTask, "Spawner", 256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 7
    /* --- Example 7: Stack monitoring --- */
    {
        TaskHandle_t h;
        xTaskCreate(vHighPriorityTask, "HighPrio", 256, NULL, 3, &h);
        vRegisterForMonitoring(h, "HighPrio");

        xTaskCreate(vPeriodicSensorTask, "Sensor", 256, NULL, 3, &h);
        vRegisterForMonitoring(h, "Sensor");

        xTaskCreate(vWorkerTask, "Worker", 128, NULL, 2, &h);
        vRegisterForMonitoring(h, "Worker");

        xTaskCreate(vStackMonitorTask, "StackMon", 512, NULL, 1, NULL);
    }

#elif EXAMPLE_SELECT == 8
    /* --- Example 8: Runtime statistics --- */
    #if configGENERATE_RUN_TIME_STATS == 1
    xTaskCreate(vHighPriorityTask,   "HighPrio",  256, NULL, 3, NULL);
    xTaskCreate(vPeriodicSensorTask, "Sensor",    256, NULL, 3, NULL);
    xTaskCreate(vRuntimeStatsTask,   "Stats",     512, NULL, 1, NULL);
    #else
    printf("Enable configGENERATE_RUN_TIME_STATS in FreeRTOSConfig.h\r\n");
    #endif

#elif EXAMPLE_SELECT == 9
    /* --- Example 9: Parameterized tasks --- */
    for (int i = 0; i < 3; i++) {
        xTaskCreate(vConfigurableSensorTask, xSensorConfigs[i].label,
                    256, &xSensorConfigs[i], 2, NULL);
    }

#else
    printf("Invalid EXAMPLE_SELECT. Choose 1-9.\r\n");
#endif

    vTaskStartScheduler();

    printf("[FATAL] Scheduler exited — insufficient memory?\r\n");
    for (;;);
}
