/**
 * FreeRTOS Example 02 — Queues: Inter-Task Communication
 *
 * Demonstrates:
 *   - Queue creation (dynamic and static)
 *   - xQueueSend / xQueueSendToFront / xQueueSendToBack
 *   - xQueueReceive with timeout
 *   - xQueuePeek (read without removing)
 *   - xQueueOverwrite for latest-value semantics (length-1 queue)
 *   - Sending structs through queues
 *   - Multiple-producer, single-consumer pattern
 *   - Queue sets (blocking on multiple queues)
 *   - FromISR variants for interrupt context
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include <stdio.h>
#include <string.h>

/* ---------------------------------------------------------------------------
 * Hardware stubs
 * --------------------------------------------------------------------------- */
static void hw_init(void)            { }
static void uart_print(const char *s){ printf("%s", s); }
static int  read_temperature(void)   { static int t = 20; t += (t < 40) ? 1 : -20; return t; }
static int  read_humidity(void)      { static int h = 50; h += (h < 90) ? 2 : -40; return h; }
static int  read_pressure(void)      { static int p = 1013; p += (p < 1023) ? 1 : -10; return p; }

/* ---------------------------------------------------------------------------
 * Message types for structured queue communication
 * --------------------------------------------------------------------------- */
typedef enum {
    SENSOR_TEMPERATURE,
    SENSOR_HUMIDITY,
    SENSOR_PRESSURE
} SensorType_t;

typedef struct {
    SensorType_t eType;
    int32_t      lValue;
    TickType_t   xTimestamp;
} SensorReading_t;

typedef struct {
    uint8_t  ucCmdId;
    uint16_t usParam;
    uint32_t ulPayload;
} Command_t;

/* ---------------------------------------------------------------------------
 * Queue handles
 * --------------------------------------------------------------------------- */
static QueueHandle_t xSensorQueue   = NULL;  /* Multi-producer sensor data */
static QueueHandle_t xCommandQueue  = NULL;  /* Command messages */
static QueueHandle_t xStatusQueue   = NULL;  /* Latest status (length-1, overwrite) */

/* ---------------------------------------------------------------------------
 * Example 1: Sensor producer tasks (multiple producers, one consumer)
 *
 * Three tasks read different sensors and send readings to the same queue.
 * The queue stores SensorReading_t structs BY VALUE — the data is copied
 * into the queue's internal buffer, so the source variable can be
 * immediately reused or go out of scope.
 *
 * xQueueSend() blocks if the queue is full, up to xTicksToWait ticks.
 * If the queue is still full after the timeout, it returns errQUEUE_FULL
 * and the data is NOT sent.
 * --------------------------------------------------------------------------- */
void vTemperatureTask(void *pvParameters)
{
    (void)pvParameters;
    SensorReading_t reading;

    for (;;) {
        reading.eType      = SENSOR_TEMPERATURE;
        reading.lValue     = read_temperature();
        reading.xTimestamp  = xTaskGetTickCount();

        /*
         * xQueueSend is equivalent to xQueueSendToBack — adds to the tail.
         * The second parameter is a pointer to the data; the queue copies
         * uxItemSize bytes from this address into its internal buffer.
         *
         * pdMS_TO_TICKS(10) = wait up to 10 ms if queue is full.
         */
        if (xQueueSend(xSensorQueue, &reading, pdMS_TO_TICKS(10)) != pdPASS) {
            uart_print("[TEMP] Queue full, reading dropped\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

void vHumidityTask(void *pvParameters)
{
    (void)pvParameters;
    SensorReading_t reading;

    for (;;) {
        reading.eType      = SENSOR_HUMIDITY;
        reading.lValue     = read_humidity();
        reading.xTimestamp  = xTaskGetTickCount();

        if (xQueueSend(xSensorQueue, &reading, pdMS_TO_TICKS(10)) != pdPASS) {
            uart_print("[HUMID] Queue full, reading dropped\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

void vPressureTask(void *pvParameters)
{
    (void)pvParameters;
    SensorReading_t reading;

    for (;;) {
        reading.eType      = SENSOR_PRESSURE;
        reading.lValue     = read_pressure();
        reading.xTimestamp  = xTaskGetTickCount();

        /*
         * xQueueSendToFront() places the item at the HEAD of the queue.
         * Use this for high-priority messages that should be processed first.
         * Here, pressure readings are treated as high-priority.
         */
        if (xQueueSendToFront(xSensorQueue, &reading, pdMS_TO_TICKS(10)) != pdPASS) {
            uart_print("[PRESS] Queue full, reading dropped\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Sensor consumer task
 *
 * Receives readings from the shared queue and processes them. When the queue
 * is empty, xQueueReceive() blocks the task (moves it to Blocked state).
 * The task wakes up as soon as any producer sends data.
 *
 * portMAX_DELAY means "wait forever" — the task will block indefinitely
 * until data is available (assuming INCLUDE_vTaskSuspend is 1).
 * --------------------------------------------------------------------------- */
void vSensorConsumerTask(void *pvParameters)
{
    (void)pvParameters;
    SensorReading_t reading;
    const char *sensor_names[] = {"TEMP", "HUMID", "PRESS"};

    for (;;) {
        /*
         * xQueueReceive copies uxItemSize bytes from the queue's head
         * into the provided buffer, then removes the item from the queue.
         *
         * If a producer was blocked waiting for space (queue was full),
         * that producer is automatically unblocked after this receive.
         */
        if (xQueueReceive(xSensorQueue, &reading, portMAX_DELAY) == pdPASS) {
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "[CONSUMER] %s = %ld (t=%lu, pending=%u)\r\n",
                     sensor_names[reading.eType],
                     (long)reading.lValue,
                     (unsigned long)reading.xTimestamp,
                     (unsigned)uxQueueMessagesWaiting(xSensorQueue));
            uart_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Command queue with xQueuePeek
 *
 * xQueuePeek reads the item at the head of the queue WITHOUT removing it.
 * Multiple tasks can peek at the same command. The command stays in the
 * queue until explicitly received.
 *
 * Use case: A "display" task peeks to show the current command, while a
 * "processor" task receives and removes it for execution.
 * --------------------------------------------------------------------------- */
void vCommandSenderTask(void *pvParameters)
{
    (void)pvParameters;
    uint8_t cmd_id = 0;

    for (;;) {
        Command_t cmd = {
            .ucCmdId   = cmd_id++,
            .usParam   = 100 + cmd_id,
            .ulPayload = xTaskGetTickCount()
        };

        if (xQueueSend(xCommandQueue, &cmd, pdMS_TO_TICKS(50)) == pdPASS) {
            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[CMD SEND] Sent command %u\r\n", cmd.ucCmdId);
            uart_print(buf);
        }

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

void vCommandPeekTask(void *pvParameters)
{
    (void)pvParameters;
    Command_t cmd;

    for (;;) {
        /*
         * xQueuePeek blocks until an item is available, then copies it
         * but does NOT remove it from the queue. If multiple tasks peek,
         * they all see the same item.
         */
        if (xQueuePeek(xCommandQueue, &cmd, portMAX_DELAY) == pdPASS) {
            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[CMD PEEK] Next command: id=%u param=%u\r\n",
                     cmd.ucCmdId, cmd.usParam);
            uart_print(buf);
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void vCommandProcessorTask(void *pvParameters)
{
    (void)pvParameters;
    Command_t cmd;

    for (;;) {
        if (xQueueReceive(xCommandQueue, &cmd, portMAX_DELAY) == pdPASS) {
            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[CMD EXEC] Executing command %u (param=%u, payload=%lu)\r\n",
                     cmd.ucCmdId, cmd.usParam, (unsigned long)cmd.ulPayload);
            uart_print(buf);
            vTaskDelay(pdMS_TO_TICKS(100));
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 4: Status queue with xQueueOverwrite (latest-value pattern)
 *
 * For length-1 queues, xQueueOverwrite() always succeeds by replacing
 * the current value. This is perfect for sharing "latest state" between
 * tasks — the consumer always gets the most recent value.
 *
 * This pattern is useful for:
 *   - System status registers
 *   - Latest sensor readings (when you only care about the newest)
 *   - Configuration parameters
 * --------------------------------------------------------------------------- */
typedef struct {
    uint32_t ulUptimeSeconds;
    int16_t  sTemperature;
    uint8_t  ucBatteryPercent;
    uint8_t  ucWifiConnected;
} SystemStatus_t;

void vStatusProducerTask(void *pvParameters)
{
    (void)pvParameters;
    SystemStatus_t status;
    uint32_t seconds = 0;

    for (;;) {
        status.ulUptimeSeconds  = seconds++;
        status.sTemperature     = (int16_t)read_temperature();
        status.ucBatteryPercent = (uint8_t)(100 - (seconds % 50));
        status.ucWifiConnected  = (seconds > 5) ? 1 : 0;

        /*
         * xQueueOverwrite never fails — it overwrites the existing item
         * in a length-1 queue. The calling task never blocks.
         *
         * Internally, this is xQueueGenericSend with queueOVERWRITE flag,
         * which resets pcWriteTo to pcHead before copying.
         */
        xQueueOverwrite(xStatusQueue, &status);

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void vStatusDisplayTask(void *pvParameters)
{
    (void)pvParameters;
    SystemStatus_t status;

    for (;;) {
        /*
         * xQueuePeek on a length-1 queue with xQueueOverwrite gives
         * "latest value" semantics: the producer overwrites, the consumer
         * peeks the latest without removing it.
         */
        if (xQueuePeek(xStatusQueue, &status, portMAX_DELAY) == pdPASS) {
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "[STATUS] Uptime=%lus Temp=%d°C Batt=%u%% WiFi=%s\r\n",
                     (unsigned long)status.ulUptimeSeconds,
                     status.sTemperature,
                     status.ucBatteryPercent,
                     status.ucWifiConnected ? "Yes" : "No");
            uart_print(buf);
        }

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* ---------------------------------------------------------------------------
 * Example 5: Queue usage from ISR (FromISR functions)
 *
 * In real hardware, this code runs in an interrupt handler. The key
 * differences from task-context queue operations:
 *   - Use xQueueSendFromISR / xQueueReceiveFromISR
 *   - These NEVER block — if the operation can't complete, they fail
 *   - They write to pxHigherPriorityTaskWoken to signal if a context
 *     switch should occur
 *   - Call portYIELD_FROM_ISR() at the END of the ISR
 * --------------------------------------------------------------------------- */
static QueueHandle_t xISRQueue = NULL;

void EXTI0_IRQHandler(void)  /* Example: button press interrupt */
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    uint32_t event_data = 42;

    /*
     * xQueueSendFromISR does NOT support a timeout — it either succeeds
     * immediately or returns errQUEUE_FULL.
     *
     * The third parameter is set to pdTRUE if a higher-priority task
     * was unblocked by this send.
     */
    xQueueSendFromISR(xISRQueue, &event_data, &xHigherPriorityTaskWoken);

    /*
     * portYIELD_FROM_ISR pends PendSV if xHigherPriorityTaskWoken == pdTRUE.
     * PendSV runs at lowest priority, so the context switch happens AFTER
     * this ISR (and any other pending ISRs) complete.
     *
     * Without this call, the unblocked task won't run until the next tick.
     */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vISRConsumerTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t event;

    xISRQueue = xQueueCreate(8, sizeof(uint32_t));

    for (;;) {
        if (xQueueReceive(xISRQueue, &event, portMAX_DELAY) == pdPASS) {
            char buf[64];
            snprintf(buf, sizeof(buf), "[ISR EVENT] Received: %lu\r\n",
                     (unsigned long)event);
            uart_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 6: Queue Sets — blocking on multiple queues simultaneously
 *
 * A queue set allows a task to block until ANY of several queues/semaphores
 * has data. This is similar to select() or poll() in POSIX.
 *
 * The queue set itself is a queue — when data is added to any member,
 * the member's handle is sent to the set's queue. The blocking task
 * receives the handle, then reads from the appropriate member.
 *
 * Requires: configUSE_QUEUE_SETS = 1
 * --------------------------------------------------------------------------- */
#if (configUSE_QUEUE_SETS == 1)

static QueueHandle_t    xQueueA = NULL, xQueueB = NULL;
static QueueSetHandle_t xQueueSet = NULL;

void vQueueSetProducerA(void *pvParameters)
{
    (void)pvParameters;
    int count = 0;

    for (;;) {
        int val = count++ * 10;
        xQueueSend(xQueueA, &val, portMAX_DELAY);
        vTaskDelay(pdMS_TO_TICKS(700));
    }
}

void vQueueSetProducerB(void *pvParameters)
{
    (void)pvParameters;
    int count = 100;

    for (;;) {
        int val = count++;
        xQueueSend(xQueueB, &val, portMAX_DELAY);
        vTaskDelay(pdMS_TO_TICKS(1100));
    }
}

void vQueueSetConsumer(void *pvParameters)
{
    (void)pvParameters;
    int value;

    for (;;) {
        /*
         * xQueueSelectFromSet blocks until any member has data.
         * Returns the handle of the queue/semaphore that received data.
         */
        QueueSetMemberHandle_t xActiveMember =
            xQueueSelectFromSet(xQueueSet, portMAX_DELAY);

        if (xActiveMember == xQueueA) {
            xQueueReceive(xQueueA, &value, 0);
            char buf[64];
            snprintf(buf, sizeof(buf),
                     "[QSET] From A: %d\r\n", value);
            uart_print(buf);
        } else if (xActiveMember == xQueueB) {
            xQueueReceive(xQueueB, &value, 0);
            char buf[64];
            snprintf(buf, sizeof(buf),
                     "[QSET] From B: %d\r\n", value);
            uart_print(buf);
        }
    }
}

#endif /* configUSE_QUEUE_SETS */

/* ---------------------------------------------------------------------------
 * Hooks
 * --------------------------------------------------------------------------- */
void vApplicationMallocFailedHook(void) { for (;;); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *n) { (void)t; (void)n; for (;;); }
void vApplicationIdleHook(void) { __asm volatile("wfi"); }

/* ---------------------------------------------------------------------------
 * Main
 * --------------------------------------------------------------------------- */
int main(void)
{
    hw_init();

    /* Create queues */
    xSensorQueue  = xQueueCreate(16, sizeof(SensorReading_t));
    xCommandQueue = xQueueCreate(4,  sizeof(Command_t));
    xStatusQueue  = xQueueCreate(1,  sizeof(SystemStatus_t));

    /* Sensor producer/consumer tasks */
    xTaskCreate(vTemperatureTask,    "Temp",    256, NULL, 2, NULL);
    xTaskCreate(vHumidityTask,       "Humid",   256, NULL, 2, NULL);
    xTaskCreate(vPressureTask,       "Press",   256, NULL, 2, NULL);
    xTaskCreate(vSensorConsumerTask, "SensCon", 256, NULL, 3, NULL);

    /* Command queue tasks */
    xTaskCreate(vCommandSenderTask,    "CmdSend", 256, NULL, 1, NULL);
    xTaskCreate(vCommandPeekTask,      "CmdPeek", 256, NULL, 1, NULL);
    xTaskCreate(vCommandProcessorTask, "CmdProc", 256, NULL, 2, NULL);

    /* Status overwrite tasks */
    xTaskCreate(vStatusProducerTask, "StProd", 256, NULL, 1, NULL);
    xTaskCreate(vStatusDisplayTask,  "StDisp", 256, NULL, 1, NULL);

    /* ISR consumer task */
    xTaskCreate(vISRConsumerTask, "ISRCon", 256, NULL, 3, NULL);

#if (configUSE_QUEUE_SETS == 1)
    xQueueA   = xQueueCreate(5, sizeof(int));
    xQueueB   = xQueueCreate(5, sizeof(int));
    /* Queue set size = total capacity of all members */
    xQueueSet = xQueueCreateSet(5 + 5);
    xQueueAddToSet(xQueueA, xQueueSet);
    xQueueAddToSet(xQueueB, xQueueSet);

    xTaskCreate(vQueueSetProducerA, "QSetA", 256, NULL, 2, NULL);
    xTaskCreate(vQueueSetProducerB, "QSetB", 256, NULL, 2, NULL);
    xTaskCreate(vQueueSetConsumer,  "QSetC", 256, NULL, 3, NULL);
#endif

    vTaskStartScheduler();
    for (;;);
}
