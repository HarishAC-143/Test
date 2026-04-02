/**
 * FreeRTOS Example 02: Queues — Inter-Task Communication
 *
 * Demonstrates:
 *   - Queue creation (dynamic and static)
 *   - FIFO send/receive between tasks
 *   - Sending structured data through queues
 *   - Queue-based producer/consumer pattern
 *   - xQueueSendToFront (LIFO behavior)
 *   - xQueueOverwrite (latest-value mailbox)
 *   - xQueuePeek (non-destructive read)
 *   - ISR-to-task communication via xQueueSendFromISR
 *   - Queue sets for multiplexing
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Simulated Hardware                                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

static void uart_printf(const char *fmt, ...) { (void)fmt; }

static float read_temperature(void) {
    static float temp = 22.0f;
    temp += 0.1f;
    if (temp > 30.0f) temp = 20.0f;
    return temp;
}

static float read_humidity(void) {
    static float hum = 45.0f;
    hum += 0.5f;
    if (hum > 80.0f) hum = 40.0f;
    return hum;
}

static float read_pressure(void) {
    static float pres = 1013.0f;
    pres -= 0.1f;
    if (pres < 990.0f) pres = 1020.0f;
    return pres;
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Data Types                                                                */
/* ──────────────────────────────────────────────────────────────────────────── */

typedef enum {
    SENSOR_TEMPERATURE,
    SENSOR_HUMIDITY,
    SENSOR_PRESSURE
} SensorType_t;

typedef struct {
    SensorType_t eType;
    float        fValue;
    TickType_t   xTimestamp;
} SensorReading_t;

typedef struct {
    uint8_t  ucCommand;
    uint16_t usParam;
    char     cPayload[16];
} CommandMsg_t;

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: Basic FIFO Queue — Producer/Consumer                           */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Queue fundamentals:
 *
 * Queues implement a FIFO (First-In, First-Out) data structure with thread-safe
 * operations. Items are COPIED into/from the queue (not referenced by pointer).
 *
 * Internally, a queue is a circular buffer with:
 *   - pcHead: start of storage area
 *   - pcTail: one past end of storage area
 *   - pcWriteTo: next write position (advances on send)
 *   - pcReadFrom: last read position (advances on receive)
 *   - xTasksWaitingToSend: list of tasks blocked because queue is full
 *   - xTasksWaitingToReceive: list of tasks blocked because queue is empty
 *
 * Copy semantics:
 *   - xQueueSend copies sizeof(item) bytes from the caller's buffer into the queue
 *   - xQueueReceive copies sizeof(item) bytes from the queue into the caller's buffer
 *   - This means the sender and receiver don't need to coordinate lifetimes
 *   - For large objects, send a pointer instead of the object itself
 */

#define SENSOR_QUEUE_LENGTH  16

static QueueHandle_t xSensorQueue;

static void vTemperatureProducer(void *pvParameters) {
    (void)pvParameters;
    SensorReading_t xReading;

    for (;;) {
        xReading.eType      = SENSOR_TEMPERATURE;
        xReading.fValue     = read_temperature();
        xReading.xTimestamp = xTaskGetTickCount();

        /**
         * xQueueSend (alias for xQueueSendToBack):
         *   - Copies the item to the back of the queue (FIFO)
         *   - If the queue is full, blocks for up to xTicksToWait ticks
         *   - Returns pdPASS on success, errQUEUE_FULL on timeout
         *
         * portMAX_DELAY as timeout means "block indefinitely" (when
         * INCLUDE_vTaskSuspend == 1, otherwise it blocks for the max tick count).
         */
        BaseType_t xResult = xQueueSend(xSensorQueue, &xReading, portMAX_DELAY);

        if (xResult == pdPASS) {
            uart_printf("[%lu] Temp producer: sent %.1f C\r\n",
                         xReading.xTimestamp, xReading.fValue);
        }

        vTaskDelay(pdMS_TO_TICKS(250));
    }
}

static void vHumidityProducer(void *pvParameters) {
    (void)pvParameters;
    SensorReading_t xReading;

    for (;;) {
        xReading.eType      = SENSOR_HUMIDITY;
        xReading.fValue     = read_humidity();
        xReading.xTimestamp = xTaskGetTickCount();

        xQueueSend(xSensorQueue, &xReading, pdMS_TO_TICKS(100));
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vSensorConsumer(void *pvParameters) {
    (void)pvParameters;
    SensorReading_t xReceived;
    const char *pcTypeNames[] = {"Temp", "Humidity", "Pressure"};

    for (;;) {
        /**
         * xQueueReceive:
         *   - Copies the front item from the queue into pvBuffer
         *   - REMOVES the item from the queue
         *   - If the queue is empty, blocks for up to xTicksToWait ticks
         *   - When a task is unblocked because an item arrived, the scheduler
         *     checks if the receiving task has higher priority than the sending task
         *     and performs a context switch if needed
         */
        if (xQueueReceive(xSensorQueue, &xReceived, portMAX_DELAY) == pdPASS) {
            uart_printf("[%lu] Consumer: %s = %.1f (queued at %lu, latency = %lu ms)\r\n",
                         xTaskGetTickCount(),
                         pcTypeNames[xReceived.eType],
                         xReceived.fValue,
                         xReceived.xTimestamp,
                         (xTaskGetTickCount() - xReceived.xTimestamp));

            /* Report queue depth */
            uart_printf("  Queue depth: %lu/%d\r\n",
                         (unsigned long)uxQueueMessagesWaiting(xSensorQueue),
                         SENSOR_QUEUE_LENGTH);
        }
    }
}

static void example1_basic_queue(void) {
    xSensorQueue = xQueueCreate(SENSOR_QUEUE_LENGTH, sizeof(SensorReading_t));
    configASSERT(xSensorQueue != NULL);

    xTaskCreate(vTemperatureProducer, "TempProd", 256, NULL, 2, NULL);
    xTaskCreate(vHumidityProducer,    "HumProd",  256, NULL, 2, NULL);
    xTaskCreate(vSensorConsumer,      "Consumer", 256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: xQueueOverwrite — Latest-Value Mailbox                         */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xQueueOverwrite:
 *   - Only works with queues of length 1
 *   - NEVER blocks — always succeeds
 *   - If the queue is full, overwrites the existing item
 *   - Ideal for "latest value" patterns where you want the most recent data
 *     (e.g., current sensor reading, system status)
 *
 * Think of it as a thread-safe single-variable mailbox.
 *
 * Contrast with xQueueSend on a length-1 queue:
 *   - xQueueSend blocks or fails if the queue is full
 *   - xQueueOverwrite always writes (replaces if necessary)
 */

typedef struct {
    float    fTemperature;
    float    fHumidity;
    float    fPressure;
    uint32_t ulUpdateCount;
} SystemStatus_t;

static QueueHandle_t xStatusMailbox;

static void vStatusUpdater(void *pvParameters) {
    (void)pvParameters;
    SystemStatus_t xStatus = {0};

    for (;;) {
        xStatus.fTemperature = read_temperature();
        xStatus.fHumidity    = read_humidity();
        xStatus.fPressure    = read_pressure();
        xStatus.ulUpdateCount++;

        /* Overwrites any previous unread status — only the latest matters */
        xQueueOverwrite(xStatusMailbox, &xStatus);

        uart_printf("[%lu] Status updated (#%lu)\r\n",
                     xTaskGetTickCount(), xStatus.ulUpdateCount);

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

/**
 * xQueuePeek:
 *   - Reads the front item WITHOUT removing it
 *   - Multiple tasks can peek at the same data
 *   - If the queue is empty, blocks for up to xTicksToWait
 *   - Useful with xQueueOverwrite: the "mailbox" pattern where
 *     writers overwrite and readers peek without consuming
 */
static void vStatusDisplay(void *pvParameters) {
    (void)pvParameters;
    SystemStatus_t xStatus;

    for (;;) {
        /* Peek — does not remove the item, so other tasks can also read it */
        if (xQueuePeek(xStatusMailbox, &xStatus, portMAX_DELAY) == pdPASS) {
            uart_printf("[%lu] Display: T=%.1f H=%.1f P=%.1f (update #%lu)\r\n",
                         xTaskGetTickCount(),
                         xStatus.fTemperature,
                         xStatus.fHumidity,
                         xStatus.fPressure,
                         xStatus.ulUpdateCount);
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void example2_mailbox(void) {
    /* Length-1 queue used as a mailbox */
    xStatusMailbox = xQueueCreate(1, sizeof(SystemStatus_t));
    configASSERT(xStatusMailbox != NULL);

    xTaskCreate(vStatusUpdater, "Updater", 256, NULL, 2, NULL);
    xTaskCreate(vStatusDisplay, "Display", 256, NULL, 1, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: xQueueSendToFront — Priority Messages                          */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xQueueSendToFront:
 *   - Copies the item to the FRONT of the queue (LIFO behavior for that item)
 *   - The item will be the next one received, jumping ahead of all others
 *   - Useful for high-priority or "urgent" messages in a command queue
 *
 * Normal flow with xQueueSend (FIFO):
 *   Queue: [A] → [B] → [C]   (A is next to be received)
 *
 * After xQueueSendToFront(X):
 *   Queue: [X] → [A] → [B] → [C]   (X jumps to front)
 */

#define CMD_NORMAL     0x01
#define CMD_URGENT     0x02
#define CMD_SHUTDOWN   0xFF

static QueueHandle_t xCommandQueue;

static void vCommandSender(void *pvParameters) {
    (void)pvParameters;
    CommandMsg_t xCmd;
    uint32_t ulCmdNum = 0;

    for (;;) {
        ulCmdNum++;

        if (ulCmdNum % 10 == 0) {
            /* Every 10th command is urgent — send to front */
            xCmd.ucCommand = CMD_URGENT;
            xCmd.usParam   = (uint16_t)ulCmdNum;
            snprintf(xCmd.cPayload, sizeof(xCmd.cPayload), "URGENT-%lu",
                     (unsigned long)ulCmdNum);

            xQueueSendToFront(xCommandQueue, &xCmd, portMAX_DELAY);
            uart_printf("[%lu] Sent URGENT command #%lu to FRONT\r\n",
                         xTaskGetTickCount(), ulCmdNum);
        } else {
            xCmd.ucCommand = CMD_NORMAL;
            xCmd.usParam   = (uint16_t)ulCmdNum;
            snprintf(xCmd.cPayload, sizeof(xCmd.cPayload), "CMD-%lu",
                     (unsigned long)ulCmdNum);

            xQueueSend(xCommandQueue, &xCmd, portMAX_DELAY);
        }

        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void vCommandProcessor(void *pvParameters) {
    (void)pvParameters;
    CommandMsg_t xCmd;

    for (;;) {
        if (xQueueReceive(xCommandQueue, &xCmd, portMAX_DELAY) == pdPASS) {
            uart_printf("[%lu] Processing: cmd=0x%02X param=%u payload='%s'\r\n",
                         xTaskGetTickCount(), xCmd.ucCommand, xCmd.usParam, xCmd.cPayload);

            if (xCmd.ucCommand == CMD_URGENT) {
                uart_printf("  >> URGENT command handled immediately!\r\n");
            }
        }
    }
}

static void example3_send_to_front(void) {
    xCommandQueue = xQueueCreate(20, sizeof(CommandMsg_t));
    configASSERT(xCommandQueue != NULL);

    xTaskCreate(vCommandSender,    "CmdSend", 256, NULL, 2, NULL);
    xTaskCreate(vCommandProcessor, "CmdProc", 256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: ISR-to-Task Communication via Queue                            */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xQueueSendFromISR / xQueueReceiveFromISR:
 *   - ISR-safe queue operations that NEVER block
 *   - Instead of blocking, they return errQUEUE_FULL / errQUEUE_EMPTY immediately
 *   - The pxHigherPriorityTaskWoken parameter is set to pdTRUE if the operation
 *     unblocks a task with higher priority than the currently running task
 *   - The caller must use portYIELD_FROM_ISR() with this flag to request a
 *     context switch if needed
 *
 * Internal locking mechanism:
 *   When a FromISR function runs, the queue may be "locked" (a task is in the
 *   middle of a non-ISR queue operation). In this case:
 *   - The ISR increments cTxLock (for sends) or cRxLock (for receives)
 *   - The actual list manipulations are deferred
 *   - When the task-level operation unlocks the queue (prvUnlockQueue),
 *     it processes the deferred operations
 */

static QueueHandle_t xADCQueue;

/**
 * Simulated ADC End-of-Conversion interrupt handler.
 * In a real system, this would be triggered by hardware.
 */
void ADC_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    uint16_t usADCValue = 0; /* Read from ADC data register */

    /* Send the reading to the processing task.
       xQueueSendFromISR will:
       1. Check if the queue has space
       2. Copy the item into the queue
       3. If a task was waiting to receive, unblock it
       4. Set xHigherPriorityTaskWoken if a context switch is needed */
    xQueueSendFromISR(xADCQueue, &usADCValue, &xHigherPriorityTaskWoken);

    /* If a higher-priority task was woken, request a context switch.
       The PendSV exception will fire after this ISR exits and perform the switch. */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void vADCProcessingTask(void *pvParameters) {
    (void)pvParameters;
    uint16_t usValue;
    uint32_t ulCount = 0;
    float fSum = 0.0f;

    for (;;) {
        if (xQueueReceive(xADCQueue, &usValue, portMAX_DELAY) == pdPASS) {
            fSum += (float)usValue;
            ulCount++;

            if (ulCount >= 10) {
                float fAverage = fSum / (float)ulCount;
                uart_printf("[%lu] ADC average of %lu samples: %.1f\r\n",
                             xTaskGetTickCount(), ulCount, fAverage);
                fSum = 0.0f;
                ulCount = 0;
            }
        }
    }
}

static void example4_isr_queue(void) {
    xADCQueue = xQueueCreate(32, sizeof(uint16_t));
    configASSERT(xADCQueue != NULL);

    xTaskCreate(vADCProcessingTask, "ADCProc", 256, NULL, 4, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 5: Queue Sets — Waiting on Multiple Queues                        */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Queue sets allow a single task to block waiting for data on ANY of
 * several queues (or semaphores). Similar to select() on POSIX sockets.
 *
 * xQueueCreateSet(uxEventQueueLength):
 *   - Creates a set that can track up to uxEventQueueLength events
 *   - uxEventQueueLength should be the sum of all member queue lengths
 *
 * xQueueAddToSet(xQueueOrSemaphore, xQueueSet):
 *   - Adds a queue or semaphore to the set
 *   - The queue/semaphore must be EMPTY when added
 *
 * xQueueSelectFromSet(xQueueSet, xTicksToWait):
 *   - Blocks until ANY member has data available
 *   - Returns the handle of the member that has data
 *   - The caller must then receive from that specific member
 *
 * Requires configUSE_QUEUE_SETS == 1 in FreeRTOSConfig.h.
 *
 * Note: Task notifications are often a better alternative if you control
 * all the sending code, as they're faster and use less RAM.
 */

#define TEMP_QUEUE_LEN     8
#define PRESSURE_QUEUE_LEN 4

static QueueHandle_t    xTempQueue2;
static QueueHandle_t    xPressureQueue;
static QueueSetHandle_t xSensorQueueSet;

static void vTempSender(void *pvParameters) {
    (void)pvParameters;
    float fTemp;
    for (;;) {
        fTemp = read_temperature();
        xQueueSend(xTempQueue2, &fTemp, portMAX_DELAY);
        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

static void vPressureSender(void *pvParameters) {
    (void)pvParameters;
    float fPressure;
    for (;;) {
        fPressure = read_pressure();
        xQueueSend(xPressureQueue, &fPressure, portMAX_DELAY);
        vTaskDelay(pdMS_TO_TICKS(700));
    }
}

static void vMultiQueueReceiver(void *pvParameters) {
    (void)pvParameters;
    float fValue;

    for (;;) {
        /* Block until ANY queue in the set has data */
        QueueSetMemberHandle_t xActiveMember =
            xQueueSelectFromSet(xSensorQueueSet, portMAX_DELAY);

        if (xActiveMember == (QueueSetMemberHandle_t)xTempQueue2) {
            xQueueReceive(xTempQueue2, &fValue, 0);
            uart_printf("[%lu] QueueSet: Temperature = %.1f C\r\n",
                         xTaskGetTickCount(), fValue);
        } else if (xActiveMember == (QueueSetMemberHandle_t)xPressureQueue) {
            xQueueReceive(xPressureQueue, &fValue, 0);
            uart_printf("[%lu] QueueSet: Pressure = %.1f hPa\r\n",
                         xTaskGetTickCount(), fValue);
        }
    }
}

static void example5_queue_sets(void) {
    xTempQueue2     = xQueueCreate(TEMP_QUEUE_LEN, sizeof(float));
    xPressureQueue  = xQueueCreate(PRESSURE_QUEUE_LEN, sizeof(float));
    xSensorQueueSet = xQueueCreateSet(TEMP_QUEUE_LEN + PRESSURE_QUEUE_LEN);

    configASSERT(xTempQueue2 != NULL);
    configASSERT(xPressureQueue != NULL);
    configASSERT(xSensorQueueSet != NULL);

    xQueueAddToSet(xTempQueue2, xSensorQueueSet);
    xQueueAddToSet(xPressureQueue, xSensorQueueSet);

    xTaskCreate(vTempSender,         "TempTx",   256, NULL, 2, NULL);
    xTaskCreate(vPressureSender,     "PresTx",   256, NULL, 2, NULL);
    xTaskCreate(vMultiQueueReceiver, "MultiRx",  256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 6: Passing Pointers Through Queues (Large Data)                   */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * For large data, queue a POINTER instead of copying the entire structure.
 *
 * CRITICAL RULES when queuing pointers:
 *   1. The sender must NOT modify the data after sending until the receiver
 *      is done with it (use a pool or allocate/free pattern)
 *   2. Exactly one entity must own (and eventually free) each allocation
 *   3. The pointer must remain valid until the receiver processes it
 *      (don't send pointers to stack-local variables!)
 *
 * Pattern: sender allocates → sends pointer → receiver processes → receiver frees
 */

#define DATA_BLOCK_SIZE 256

typedef struct {
    uint32_t ulSequence;
    uint16_t usLength;
    uint8_t  ucData[DATA_BLOCK_SIZE];
} DataBlock_t;

static QueueHandle_t xPointerQueue;

static void vDataProducer(void *pvParameters) {
    (void)pvParameters;
    uint32_t ulSeq = 0;

    for (;;) {
        /* Allocate a data block from the FreeRTOS heap */
        DataBlock_t *pxBlock = (DataBlock_t *)pvPortMalloc(sizeof(DataBlock_t));
        if (pxBlock == NULL) {
            uart_printf("ERROR: Failed to allocate DataBlock\r\n");
            vTaskDelay(pdMS_TO_TICKS(100));
            continue;
        }

        /* Fill the block */
        pxBlock->ulSequence = ulSeq++;
        pxBlock->usLength   = 128;
        memset(pxBlock->ucData, (uint8_t)ulSeq, pxBlock->usLength);

        /* Queue the POINTER (8 bytes on 64-bit, 4 bytes on 32-bit)
           instead of the entire struct (260+ bytes) */
        if (xQueueSend(xPointerQueue, &pxBlock, pdMS_TO_TICKS(100)) != pdPASS) {
            /* Queue full — free the block to prevent leak */
            vPortFree(pxBlock);
            uart_printf("WARNING: Pointer queue full, block dropped\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void vDataConsumer(void *pvParameters) {
    (void)pvParameters;
    DataBlock_t *pxReceived;

    for (;;) {
        if (xQueueReceive(xPointerQueue, &pxReceived, portMAX_DELAY) == pdPASS) {
            uart_printf("[%lu] Received block #%lu, %u bytes\r\n",
                         xTaskGetTickCount(),
                         pxReceived->ulSequence,
                         pxReceived->usLength);

            /* Process the data... */

            /* CRITICAL: Consumer is responsible for freeing the memory */
            vPortFree(pxReceived);
        }
    }
}

static void example6_pointer_queue(void) {
    /* Queue holds pointers, not full structs */
    xPointerQueue = xQueueCreate(8, sizeof(DataBlock_t *));
    configASSERT(xPointerQueue != NULL);

    xTaskCreate(vDataProducer, "DataProd", 256, NULL, 2, NULL);
    xTaskCreate(vDataConsumer, "DataCons", 256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main                                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) { }
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName; for (;;) { }
}

int main(void) {
    example1_basic_queue();
    example2_mailbox();
    example3_send_to_front();
    example4_isr_queue();
    example5_queue_sets();
    example6_pointer_queue();

    vTaskStartScheduler();
    for (;;) { }
    return 0;
}
