/*
 * FreeRTOS Queue Examples
 *
 * Demonstrates: xQueueCreate, xQueueSend, xQueueSendToFront, xQueueReceive,
 *               xQueuePeek, xQueueOverwrite, xQueueSendFromISR,
 *               xQueueCreateSet, xQueueSelectFromSet, queue of pointers
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10.x/v11.x
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

/* ---------- Hardware Stubs ---------- */

static inline void HAL_Init(void) {}
static inline void SystemClock_Config(void) {}

static volatile uint32_t sim_tick = 0;
static inline uint32_t read_adc(uint32_t ch)    { return 2000 + (sim_tick++ & 0xFF); }
static inline float    read_temp(void)           { return 22.5f + (float)(sim_tick & 0xF) * 0.1f; }
static inline float    read_humidity(void)       { return 45.0f + (float)(sim_tick & 0x1F) * 0.2f; }
static inline float    read_pressure(void)       { return 1013.0f + (float)(sim_tick & 0xF) * 0.5f; }

/* ---------- FreeRTOS Hooks ---------- */

void vApplicationMallocFailedHook(void)  { for (;;); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *n) { for (;;); }
void vApplicationIdleHook(void) {}

/* =====================================================================
 * Example 1: Simple Producer-Consumer with Integer Queue
 *
 * One producer writes ADC samples to a queue. One consumer reads them
 * and computes a running average.
 * ===================================================================== */

#define Q1_LENGTH    16
#define Q1_ITEM_SIZE sizeof(uint32_t)

static QueueHandle_t xAdcQueue;

static void vAdcProducer(void *pv)
{
    TickType_t xLastWake = xTaskGetTickCount();
    uint32_t sample_num = 0;

    for (;;) {
        xTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(50));

        uint32_t reading = read_adc(0);
        BaseType_t status = xQueueSend(xAdcQueue, &reading, pdMS_TO_TICKS(10));

        if (status != pdPASS) {
            printf("[Producer] Queue full — sample %lu dropped\r\n", sample_num);
        }
        sample_num++;
    }
}

static void vAdcConsumer(void *pv)
{
    uint32_t sum = 0;
    uint32_t count = 0;

    for (;;) {
        uint32_t value;
        if (xQueueReceive(xAdcQueue, &value, portMAX_DELAY) == pdPASS) {
            sum += value;
            count++;

            if ((count % 20) == 0) {
                float avg = (float)sum / (float)count;
                float voltage = avg * 3.3f / 4095.0f;
                printf("[Consumer] Avg of %lu samples: %.0f (%.3f V)\r\n",
                       count, (double)avg, (double)voltage);
                sum = 0;
                count = 0;
            }
        }
    }
}

/* =====================================================================
 * Example 2: Multiple Producers, Single Consumer
 *
 * Three sensor tasks produce typed messages to a single queue.
 * The consumer dispatches based on message type.
 * ===================================================================== */

typedef enum {
    MSG_TEMPERATURE,
    MSG_HUMIDITY,
    MSG_PRESSURE
} SensorType_t;

typedef struct {
    SensorType_t type;
    uint32_t     timestamp;
    float        value;
    uint8_t      sensor_id;
} SensorMessage_t;

#define SENSOR_QUEUE_LEN  32

static QueueHandle_t xSensorQueue;

static void vTemperatureSensor(void *pv)
{
    uint8_t id = (uint8_t)(uintptr_t)pv;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        xTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(500));

        SensorMessage_t msg = {
            .type      = MSG_TEMPERATURE,
            .timestamp = (uint32_t)xTaskGetTickCount(),
            .value     = read_temp(),
            .sensor_id = id
        };

        if (xQueueSend(xSensorQueue, &msg, pdMS_TO_TICKS(50)) != pdPASS) {
            printf("[Temp-%u] Queue full\r\n", id);
        }
    }
}

static void vHumiditySensor(void *pv)
{
    uint8_t id = (uint8_t)(uintptr_t)pv;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        xTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(1000));

        SensorMessage_t msg = {
            .type      = MSG_HUMIDITY,
            .timestamp = (uint32_t)xTaskGetTickCount(),
            .value     = read_humidity(),
            .sensor_id = id
        };

        xQueueSend(xSensorQueue, &msg, pdMS_TO_TICKS(50));
    }
}

static void vPressureSensor(void *pv)
{
    uint8_t id = (uint8_t)(uintptr_t)pv;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        xTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(2000));

        SensorMessage_t msg = {
            .type      = MSG_PRESSURE,
            .timestamp = (uint32_t)xTaskGetTickCount(),
            .value     = read_pressure(),
            .sensor_id = id
        };

        xQueueSend(xSensorQueue, &msg, pdMS_TO_TICKS(50));
    }
}

static const char *sensor_type_name(SensorType_t type)
{
    switch (type) {
        case MSG_TEMPERATURE: return "Temp";
        case MSG_HUMIDITY:    return "Hum";
        case MSG_PRESSURE:    return "Press";
        default:              return "?";
    }
}

static const char *sensor_unit(SensorType_t type)
{
    switch (type) {
        case MSG_TEMPERATURE: return "°C";
        case MSG_HUMIDITY:    return "%RH";
        case MSG_PRESSURE:    return "hPa";
        default:              return "";
    }
}

static void vSensorConsumer(void *pv)
{
    float latest_temp = 0, latest_hum = 0, latest_press = 0;
    uint32_t msg_count = 0;

    for (;;) {
        SensorMessage_t msg;
        if (xQueueReceive(xSensorQueue, &msg, portMAX_DELAY) == pdPASS) {
            msg_count++;

            switch (msg.type) {
                case MSG_TEMPERATURE: latest_temp  = msg.value; break;
                case MSG_HUMIDITY:    latest_hum   = msg.value; break;
                case MSG_PRESSURE:    latest_press = msg.value; break;
            }

            printf("[Hub] #%lu [%s-%u] %.1f %s @ tick %lu\r\n",
                   msg_count,
                   sensor_type_name(msg.type), msg.sensor_id,
                   (double)msg.value, sensor_unit(msg.type),
                   (unsigned long)msg.timestamp);

            if ((msg_count % 10) == 0) {
                printf("[Hub] Dashboard: T=%.1f°C  H=%.1f%%  P=%.1f hPa\r\n",
                       (double)latest_temp, (double)latest_hum,
                       (double)latest_press);
            }
        }
    }
}

/* =====================================================================
 * Example 3: Mailbox Pattern (xQueueOverwrite)
 *
 * A single-item queue used as a "mailbox" — always holds the latest
 * value. Writers overwrite the value; readers peek without removing.
 * ===================================================================== */

typedef struct {
    float    temperature;
    float    humidity;
    float    pressure;
    uint32_t timestamp;
    uint32_t update_count;
} EnvironmentData_t;

static QueueHandle_t xMailbox;

static void vMailboxWriter(void *pv)
{
    EnvironmentData_t env;
    env.update_count = 0;

    for (;;) {
        env.temperature  = read_temp();
        env.humidity     = read_humidity();
        env.pressure     = read_pressure();
        env.timestamp    = (uint32_t)xTaskGetTickCount();
        env.update_count++;

        /* Overwrite — never blocks, always succeeds */
        xQueueOverwrite(xMailbox, &env);

        vTaskDelay(pdMS_TO_TICKS(250));
    }
}

static void vMailboxReader(void *pv)
{
    uint32_t reader_id = (uint32_t)(uintptr_t)pv;

    for (;;) {
        EnvironmentData_t env;

        /* Peek — reads without removing, multiple readers can coexist */
        if (xQueuePeek(xMailbox, &env, portMAX_DELAY) == pdPASS) {
            printf("[Reader-%lu] T=%.1f°C H=%.1f%% P=%.1f hPa (update #%lu)\r\n",
                   reader_id,
                   (double)env.temperature, (double)env.humidity,
                   (double)env.pressure, env.update_count);
        }

        vTaskDelay(pdMS_TO_TICKS(500 * (reader_id + 1)));
    }
}

/* =====================================================================
 * Example 4: Priority Queue (xQueueSendToFront)
 *
 * Normal messages go to the back of the queue (FIFO).
 * Critical messages go to the front (LIFO position), processed first.
 * ===================================================================== */

typedef enum {
    PRIORITY_NORMAL,
    PRIORITY_HIGH,
    PRIORITY_CRITICAL
} MsgPriority_t;

typedef struct {
    MsgPriority_t priority;
    uint32_t      seq_num;
    char          payload[32];
} PrioritizedMsg_t;

#define PRIO_QUEUE_LEN  16

static QueueHandle_t xPrioQueue;

static void vNormalProducer(void *pv)
{
    uint32_t seq = 0;

    for (;;) {
        PrioritizedMsg_t msg = {
            .priority = PRIORITY_NORMAL,
            .seq_num  = seq++
        };
        snprintf(msg.payload, sizeof(msg.payload), "Normal-%lu", seq);

        xQueueSend(xPrioQueue, &msg, portMAX_DELAY);  /* To back */
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void vCriticalProducer(void *pv)
{
    uint32_t seq = 1000;

    for (;;) {
        PrioritizedMsg_t msg = {
            .priority = PRIORITY_CRITICAL,
            .seq_num  = seq++
        };
        snprintf(msg.payload, sizeof(msg.payload), "CRITICAL-%lu", seq);

        /* Send to FRONT — will be received before normal messages */
        xQueueSendToFront(xPrioQueue, &msg, portMAX_DELAY);
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

static void vPrioConsumer(void *pv)
{
    for (;;) {
        PrioritizedMsg_t msg;
        if (xQueueReceive(xPrioQueue, &msg, portMAX_DELAY) == pdPASS) {
            const char *prio_str = (msg.priority == PRIORITY_CRITICAL) ? "***CRIT***" :
                                   (msg.priority == PRIORITY_HIGH)     ? "HIGH"       :
                                                                          "normal";
            printf("[PrioQ] [%s] seq=%lu: %s  (depth=%lu)\r\n",
                   prio_str, msg.seq_num, msg.payload,
                   (unsigned long)uxQueueMessagesWaiting(xPrioQueue));
        }
    }
}

/* =====================================================================
 * Example 5: Queue of Pointers (Zero-Copy for Large Data)
 *
 * When items are large, copying them into the queue is expensive.
 * Instead, allocate on the heap and send a pointer through the queue.
 * The consumer is responsible for freeing the memory.
 * ===================================================================== */

typedef struct {
    uint32_t timestamp;
    uint16_t samples[64];
    uint32_t num_samples;
    uint8_t  channel;
} SampleBlock_t;

#define PTR_QUEUE_LEN  8

static QueueHandle_t xPtrQueue;

static void vBlockProducer(void *pv)
{
    uint32_t block_num = 0;

    for (;;) {
        SampleBlock_t *pBlock = pvPortMalloc(sizeof(SampleBlock_t));

        if (pBlock != NULL) {
            pBlock->timestamp   = (uint32_t)xTaskGetTickCount();
            pBlock->channel     = 0;
            pBlock->num_samples = 64;

            for (int i = 0; i < 64; i++) {
                pBlock->samples[i] = (uint16_t)read_adc(0);
            }

            /* Send the POINTER, not the struct (4 bytes instead of 136) */
            if (xQueueSend(xPtrQueue, &pBlock, pdMS_TO_TICKS(100)) != pdPASS) {
                printf("[BlockProd] Queue full — freeing block %lu\r\n", block_num);
                vPortFree(pBlock);
            }
        } else {
            printf("[BlockProd] Alloc failed (heap: %u)\r\n",
                   (unsigned)xPortGetFreeHeapSize());
        }

        block_num++;
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vBlockConsumer(void *pv)
{
    for (;;) {
        SampleBlock_t *pBlock;

        if (xQueueReceive(xPtrQueue, &pBlock, portMAX_DELAY) == pdPASS) {
            uint32_t sum = 0;
            uint16_t min_val = UINT16_MAX, max_val = 0;

            for (uint32_t i = 0; i < pBlock->num_samples; i++) {
                sum += pBlock->samples[i];
                if (pBlock->samples[i] < min_val) min_val = pBlock->samples[i];
                if (pBlock->samples[i] > max_val) max_val = pBlock->samples[i];
            }

            float avg = (float)sum / (float)pBlock->num_samples;

            printf("[BlockCons] CH%u @ tick %lu: avg=%.1f min=%u max=%u (%lu samples)\r\n",
                   pBlock->channel, pBlock->timestamp,
                   (double)avg, min_val, max_val, pBlock->num_samples);

            /* Consumer owns the memory — must free it */
            vPortFree(pBlock);
        }
    }
}

/* =====================================================================
 * Example 6: Queue Sets
 *
 * A single task waits on multiple queues and a semaphore simultaneously
 * using xQueueCreateSet / xQueueSelectFromSet.
 * ===================================================================== */

#if configUSE_QUEUE_SETS == 1

#include "semphr.h"

#define QSET_Q1_LEN  8
#define QSET_Q2_LEN  8

static QueueHandle_t        xQSetQueue1;
static QueueHandle_t        xQSetQueue2;
static SemaphoreHandle_t    xQSetSemaphore;
static QueueSetHandle_t     xQueueSet;

static void vQSetProducer1(void *pv)
{
    uint32_t val = 100;
    for (;;) {
        xQueueSend(xQSetQueue1, &val, portMAX_DELAY);
        val++;
        vTaskDelay(pdMS_TO_TICKS(700));
    }
}

static void vQSetProducer2(void *pv)
{
    uint32_t val = 5000;
    for (;;) {
        xQueueSend(xQSetQueue2, &val, portMAX_DELAY);
        val++;
        vTaskDelay(pdMS_TO_TICKS(1100));
    }
}

static void vQSetSignaler(void *pv)
{
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(3000));
        xSemaphoreGive(xQSetSemaphore);
        printf("[QSetSig] Gave semaphore\r\n");
    }
}

static void vQSetConsumer(void *pv)
{
    for (;;) {
        QueueSetMemberHandle_t xActivated;
        xActivated = xQueueSelectFromSet(xQueueSet, portMAX_DELAY);

        if (xActivated == (QueueSetMemberHandle_t)xQSetQueue1) {
            uint32_t val;
            xQueueReceive(xQSetQueue1, &val, 0);
            printf("[QSetCons] Queue1: %lu\r\n", val);

        } else if (xActivated == (QueueSetMemberHandle_t)xQSetQueue2) {
            uint32_t val;
            xQueueReceive(xQSetQueue2, &val, 0);
            printf("[QSetCons] Queue2: %lu\r\n", val);

        } else if (xActivated == (QueueSetMemberHandle_t)xQSetSemaphore) {
            xSemaphoreTake(xQSetSemaphore, 0);
            printf("[QSetCons] Semaphore event!\r\n");
        }
    }
}

#endif /* configUSE_QUEUE_SETS */

/* =====================================================================
 * Example 7: ISR-to-Task Communication via Queue
 *
 * Simulates a UART receive ISR that sends received bytes to a task
 * through a queue using xQueueSendFromISR.
 * ===================================================================== */

#define RX_QUEUE_LEN  64

static QueueHandle_t xRxQueue;

/* Simulated ISR — in real code, this would be the USART interrupt handler */
void simulated_USART_IRQHandler(uint8_t byte)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    xQueueSendFromISR(xRxQueue, &byte, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void vUartProcessTask(void *pv)
{
    uint8_t line_buf[64];
    uint32_t idx = 0;

    for (;;) {
        uint8_t byte;
        if (xQueueReceive(xRxQueue, &byte, portMAX_DELAY) == pdPASS) {
            if (byte == '\n' || idx >= sizeof(line_buf) - 1) {
                line_buf[idx] = '\0';
                printf("[UART] Received line: %s\r\n", (char *)line_buf);
                idx = 0;
            } else {
                line_buf[idx++] = byte;
            }
        }
    }
}

/* Simulates incoming UART data by feeding the ISR */
static void vUartSimulator(void *pv)
{
    const char *messages[] = {
        "AT+CWJAP=\"SSID\",\"PASS\"\n",
        "AT+CIPSTART=\"TCP\",\"192.168.1.1\",80\n",
        "AT+CIPSEND=5\n",
        "HELLO\n",
        NULL
    };

    for (;;) {
        for (int m = 0; messages[m] != NULL; m++) {
            const char *msg = messages[m];
            for (int i = 0; msg[i] != '\0'; i++) {
                simulated_USART_IRQHandler((uint8_t)msg[i]);
                vTaskDelay(pdMS_TO_TICKS(5));
            }
            vTaskDelay(pdMS_TO_TICKS(1000));
        }
    }
}

/* =====================================================================
 * Main — select which example to run
 * ===================================================================== */

#ifndef EXAMPLE_SELECT
#define EXAMPLE_SELECT  1
#endif

int main(void)
{
    HAL_Init();
    SystemClock_Config();

    printf("\r\n=== FreeRTOS Queue Examples ===\r\n");
    printf("Running Example %d\r\n\r\n", EXAMPLE_SELECT);

#if EXAMPLE_SELECT == 1
    /* --- Simple producer-consumer --- */
    xAdcQueue = xQueueCreate(Q1_LENGTH, Q1_ITEM_SIZE);
    configASSERT(xAdcQueue);

    xTaskCreate(vAdcProducer, "Prod", 256, NULL, 2, NULL);
    xTaskCreate(vAdcConsumer, "Cons", 256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 2
    /* --- Multi-producer sensor hub --- */
    xSensorQueue = xQueueCreate(SENSOR_QUEUE_LEN, sizeof(SensorMessage_t));
    configASSERT(xSensorQueue);

    xTaskCreate(vTemperatureSensor, "Temp",  256, (void *)1, 2, NULL);
    xTaskCreate(vHumiditySensor,    "Hum",   256, (void *)2, 2, NULL);
    xTaskCreate(vPressureSensor,    "Press", 256, (void *)3, 2, NULL);
    xTaskCreate(vSensorConsumer,    "Hub",   512, NULL,       3, NULL);

#elif EXAMPLE_SELECT == 3
    /* --- Mailbox pattern --- */
    xMailbox = xQueueCreate(1, sizeof(EnvironmentData_t));
    configASSERT(xMailbox);

    xTaskCreate(vMailboxWriter,  "MbxW",   256, NULL,     2, NULL);
    xTaskCreate(vMailboxReader,  "MbxR0",  256, (void *)0, 1, NULL);
    xTaskCreate(vMailboxReader,  "MbxR1",  256, (void *)1, 1, NULL);

#elif EXAMPLE_SELECT == 4
    /* --- Priority queue (send to front) --- */
    xPrioQueue = xQueueCreate(PRIO_QUEUE_LEN, sizeof(PrioritizedMsg_t));
    configASSERT(xPrioQueue);

    xTaskCreate(vNormalProducer,   "NormProd",  256, NULL, 2, NULL);
    xTaskCreate(vCriticalProducer, "CritProd",  256, NULL, 2, NULL);
    xTaskCreate(vPrioConsumer,     "PrioCons",  256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 5
    /* --- Queue of pointers (zero-copy large data) --- */
    xPtrQueue = xQueueCreate(PTR_QUEUE_LEN, sizeof(SampleBlock_t *));
    configASSERT(xPtrQueue);

    xTaskCreate(vBlockProducer,  "BlkProd", 256, NULL, 2, NULL);
    xTaskCreate(vBlockConsumer,  "BlkCons", 256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 6
    /* --- Queue sets --- */
    #if configUSE_QUEUE_SETS == 1
    xQSetQueue1    = xQueueCreate(QSET_Q1_LEN, sizeof(uint32_t));
    xQSetQueue2    = xQueueCreate(QSET_Q2_LEN, sizeof(uint32_t));
    xQSetSemaphore = xSemaphoreCreateBinary();
    xQueueSet      = xQueueCreateSet(QSET_Q1_LEN + QSET_Q2_LEN + 1);

    xQueueAddToSet(xQSetQueue1,    xQueueSet);
    xQueueAddToSet(xQSetQueue2,    xQueueSet);
    xQueueAddToSet(xQSetSemaphore, xQueueSet);

    xTaskCreate(vQSetProducer1, "QP1",    256, NULL, 2, NULL);
    xTaskCreate(vQSetProducer2, "QP2",    256, NULL, 2, NULL);
    xTaskCreate(vQSetSignaler,  "QSig",   256, NULL, 2, NULL);
    xTaskCreate(vQSetConsumer,  "QCons",  256, NULL, 3, NULL);
    #else
    printf("Enable configUSE_QUEUE_SETS in FreeRTOSConfig.h\r\n");
    #endif

#elif EXAMPLE_SELECT == 7
    /* --- ISR-to-task UART simulation --- */
    xRxQueue = xQueueCreate(RX_QUEUE_LEN, sizeof(uint8_t));
    configASSERT(xRxQueue);

    xTaskCreate(vUartProcessTask, "UartProc", 256, NULL, 3, NULL);
    xTaskCreate(vUartSimulator,   "UartSim",  256, NULL, 2, NULL);

#else
    printf("Invalid EXAMPLE_SELECT. Choose 1-7.\r\n");
#endif

    vTaskStartScheduler();

    printf("[FATAL] Scheduler exited\r\n");
    for (;;);
}
