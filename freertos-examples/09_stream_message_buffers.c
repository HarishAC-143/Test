/**
 * FreeRTOS Example 09: Stream Buffers and Message Buffers
 *
 * Demonstrates:
 *   - Stream buffer for continuous byte-stream transfer
 *   - Stream buffer trigger level
 *   - Message buffer for discrete, variable-length messages
 *   - ISR-to-task data transfer with stream buffers
 *   - Multi-format logging with message buffers
 *
 * Stream Buffer internals:
 *   A stream buffer is a lightweight, single-reader/single-writer circular
 *   byte buffer. It is optimized for the case where there is exactly ONE
 *   writer and ONE reader (unlike queues which support multiple).
 *
 *   Internal structure:
 *     - pucBuffer: pointer to the circular byte buffer
 *     - xLength: total buffer capacity
 *     - xHead: write position (updated by sender)
 *     - xTail: read position (updated by receiver)
 *     - xTriggerLevelBytes: minimum bytes before reader is unblocked
 *     - xTaskWaitingToReceive: the ONE task waiting for data (or NULL)
 *     - xTaskWaitingToSend: the ONE task waiting for space (or NULL)
 *
 *   SINGLE READER / SINGLE WRITER restriction:
 *     - Only one task may send (or one ISR)
 *     - Only one task may receive
 *     - If multiple tasks need to send, protect with a mutex or use a queue
 *
 * Message Buffer internals:
 *   A message buffer is a stream buffer with an added 4-byte length prefix
 *   before each message. This allows variable-length discrete messages.
 *
 *   Each message in the buffer: [4-byte length][message data]
 *   The reader always receives one complete message per call.
 *
 *   Overhead per message: sizeof(size_t) bytes (4 bytes on 32-bit systems)
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10+
 */

#include "FreeRTOS.h"
#include "task.h"
#include "stream_buffer.h"
#include "message_buffer.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Simulated Hardware                                                        */
/* ──────────────────────────────────────────────────────────────────────────── */

static void uart_printf(const char *fmt, ...) { (void)fmt; }

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 1: Stream Buffer — UART-like Byte Stream                          */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * xStreamBufferCreate(xBufferSizeBytes, xTriggerLevelBytes):
 *   - xBufferSizeBytes: total buffer capacity in bytes
 *   - xTriggerLevelBytes: reader is unblocked when at least this many bytes
 *     are available. Set to 1 for "wake on any data" behavior.
 *
 *   Returns NULL if allocation fails.
 *
 *   The actual usable capacity is xBufferSizeBytes - 1 (one byte is used
 *   as a guard to distinguish full from empty).
 *
 * xStreamBufferSend(xStreamBuffer, pvTxData, xDataLengthBytes, xTicksToWait):
 *   - Copies up to xDataLengthBytes bytes into the buffer
 *   - Returns the number of bytes actually written
 *   - If the buffer doesn't have enough space, blocks for up to xTicksToWait
 *   - Partial writes are possible: may write fewer bytes than requested
 *
 * xStreamBufferReceive(xStreamBuffer, pvRxData, xBufferLengthBytes, xTicksToWait):
 *   - Copies up to xBufferLengthBytes bytes from the buffer
 *   - Returns the number of bytes actually read
 *   - Blocks until trigger level bytes are available or timeout
 *   - After trigger level is met, returns all available bytes (up to buffer size)
 */

static StreamBufferHandle_t xUARTStreamBuffer;

#define UART_STREAM_SIZE    256
#define UART_TRIGGER_LEVEL  1   /* Wake reader on any incoming byte */

static void vStreamProducerTask(void *pvParameters) {
    (void)pvParameters;
    const char *pcMessages[] = {
        "Hello from stream buffer!\r\n",
        "FreeRTOS stream buffers are fast.\r\n",
        "Ideal for UART, SPI, I2C byte streams.\r\n",
        "Single reader, single writer only.\r\n"
    };
    uint32_t ulIndex = 0;

    for (;;) {
        const char *pcMsg = pcMessages[ulIndex % 4];
        size_t xLen = strlen(pcMsg);

        /**
         * xStreamBufferSend:
         *   Internally:
         *   1. Calculate free space = (xTail - xHead - 1 + xLength) % xLength
         *   2. Copy min(xDataLengthBytes, freeSpace) bytes from pvTxData
         *      into the circular buffer starting at xHead
         *   3. Advance xHead
         *   4. If a task was waiting to receive and trigger level is now met,
         *      unblock it
         *   5. If not all bytes could be written and xTicksToWait > 0, block
         *      (this is the partial-write blocking behavior)
         */
        size_t xBytesSent = xStreamBufferSend(
            xUARTStreamBuffer,
            pcMsg,
            xLen,
            pdMS_TO_TICKS(100)
        );

        uart_printf("[%lu] Stream TX: sent %u/%u bytes\r\n",
                     xTaskGetTickCount(), (unsigned)xBytesSent, (unsigned)xLen);

        /* Report buffer state */
        uart_printf("  Space available: %u bytes\r\n",
                     (unsigned)xStreamBufferSpacesAvailable(xUARTStreamBuffer));

        ulIndex++;
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vStreamConsumerTask(void *pvParameters) {
    (void)pvParameters;
    uint8_t ucRxBuffer[64];

    for (;;) {
        /**
         * xStreamBufferReceive:
         *   Internally:
         *   1. Calculate available = (xHead - xTail + xLength) % xLength
         *   2. If available < trigger level and xTicksToWait > 0:
         *      - Store this task as xTaskWaitingToReceive
         *      - Block
         *   3. Once trigger level is met:
         *      Copy min(xBufferLengthBytes, available) bytes to pvRxData
         *   4. Advance xTail
         *   5. If a task was waiting to send, unblock it
         *   6. Return number of bytes copied
         */
        size_t xBytesReceived = xStreamBufferReceive(
            xUARTStreamBuffer,
            ucRxBuffer,
            sizeof(ucRxBuffer) - 1,
            portMAX_DELAY
        );

        if (xBytesReceived > 0) {
            ucRxBuffer[xBytesReceived] = '\0';
            uart_printf("[%lu] Stream RX: %u bytes: '%s'\r\n",
                         xTaskGetTickCount(), (unsigned)xBytesReceived,
                         (char *)ucRxBuffer);
        }
    }
}

static void example1_stream_buffer(void) {
    xUARTStreamBuffer = xStreamBufferCreate(UART_STREAM_SIZE, UART_TRIGGER_LEVEL);
    configASSERT(xUARTStreamBuffer != NULL);

    xTaskCreate(vStreamProducerTask, "StreamTx", 256, NULL, 2, NULL);
    xTaskCreate(vStreamConsumerTask, "StreamRx", 256, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 2: Stream Buffer with Higher Trigger Level                        */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Trigger level controls when the reader is unblocked:
 *   - Trigger = 1: wake on any byte (lowest latency, most context switches)
 *   - Trigger = N: wake when N bytes available (batches data, fewer switches)
 *
 * xStreamBufferSetTriggerLevel(xStreamBuffer, xTriggerLevel):
 *   Dynamically change the trigger level at runtime.
 *   Returns pdPASS if the new level is valid (1 <= level <= buffer capacity).
 *
 * Use case: DMA transfers fixed-size blocks into the stream buffer.
 * Set trigger level to the block size so the receiver wakes once per block.
 */

#define ADC_BLOCK_SIZE     64  /* 32 x 16-bit samples = 64 bytes */
#define ADC_STREAM_SIZE    256

static StreamBufferHandle_t xADCStreamBuffer;

void DMA_ADC_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    uint8_t ucDMABuffer[ADC_BLOCK_SIZE];
    /* In reality: DMA has already filled ucDMABuffer from ADC */

    /**
     * xStreamBufferSendFromISR:
     *   - ISR-safe version — never blocks
     *   - Returns the number of bytes actually written
     *   - If the buffer doesn't have enough space, writes as much as possible
     */
    size_t xBytesSent = xStreamBufferSendFromISR(
        xADCStreamBuffer,
        ucDMABuffer,
        ADC_BLOCK_SIZE,
        &xHigherPriorityTaskWoken
    );

    if (xBytesSent < ADC_BLOCK_SIZE) {
        /* Buffer overflow — data lost */
    }

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

static void vADCProcessingTask(void *pvParameters) {
    (void)pvParameters;
    uint16_t usSamples[32]; /* ADC_BLOCK_SIZE / 2 */

    for (;;) {
        /* Blocks until ADC_BLOCK_SIZE bytes are available (trigger level) */
        size_t xBytesReceived = xStreamBufferReceive(
            xADCStreamBuffer,
            usSamples,
            sizeof(usSamples),
            portMAX_DELAY
        );

        if (xBytesReceived >= ADC_BLOCK_SIZE) {
            /* Process the complete sample block */
            uint32_t ulSum = 0;
            for (int i = 0; i < 32; i++) {
                ulSum += usSamples[i];
            }
            float fAverage = (float)ulSum / 32.0f;

            uart_printf("[%lu] ADC block: avg = %.1f\r\n",
                         xTaskGetTickCount(), fAverage);
        }
    }
}

static void example2_trigger_level(void) {
    xADCStreamBuffer = xStreamBufferCreate(ADC_STREAM_SIZE, ADC_BLOCK_SIZE);
    configASSERT(xADCStreamBuffer != NULL);

    xTaskCreate(vADCProcessingTask, "ADCProc", 256, NULL, 4, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 3: Message Buffer — Variable-Length Discrete Messages              */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Message buffers add a 4-byte length header to each write, turning the
 * stream buffer into a discrete message transport.
 *
 * xMessageBufferSend(xMessageBuffer, pvTxData, xDataLengthBytes, xTicksToWait):
 *   - Writes [4-byte length][xDataLengthBytes of data] into the buffer
 *   - Atomic: either the complete message is written, or nothing
 *   - Required free space: xDataLengthBytes + sizeof(size_t)
 *   - Returns xDataLengthBytes on success, 0 on failure/timeout
 *
 * xMessageBufferReceive(xMessageBuffer, pvRxData, xBufferLengthBytes, xTicksToWait):
 *   - Reads the next complete message from the buffer
 *   - xBufferLengthBytes MUST be >= the message size (otherwise returns 0)
 *   - Returns the number of bytes in the received message
 *   - If xBufferLengthBytes is too small, the message is LOST
 *
 * Key difference from queues:
 *   - Queues: fixed-size items (all items same size)
 *   - Message buffers: variable-size items (each message can be different)
 */

typedef enum {
    LOG_INFO,
    LOG_WARNING,
    LOG_ERROR
} LogLevel_t;

typedef struct {
    LogLevel_t eLevel;
    TickType_t xTimestamp;
    char       cMessage[56]; /* Variable-length content up to 56 bytes */
} LogMessage_t;

static MessageBufferHandle_t xLogMessageBuffer;

#define LOG_BUFFER_SIZE  512

static void vLogWriter(const char *pcTaskName, LogLevel_t eLevel, const char *pcMsg) {
    LogMessage_t xLog;
    xLog.eLevel     = eLevel;
    xLog.xTimestamp  = xTaskGetTickCount();

    size_t xMsgLen = strlen(pcMsg);
    if (xMsgLen >= sizeof(xLog.cMessage)) {
        xMsgLen = sizeof(xLog.cMessage) - 1;
    }
    memcpy(xLog.cMessage, pcMsg, xMsgLen);
    xLog.cMessage[xMsgLen] = '\0';

    /* Only send the actual used portion of the message (saves buffer space) */
    size_t xSendSize = offsetof(LogMessage_t, cMessage) + xMsgLen + 1;

    size_t xBytesSent = xMessageBufferSend(
        xLogMessageBuffer,
        &xLog,
        xSendSize,
        pdMS_TO_TICKS(10)
    );

    if (xBytesSent == 0) {
        /* Buffer full — message dropped */
        (void)pcTaskName;
    }
}

static void vSensorTask(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        vLogWriter("Sensor", LOG_INFO, "Temperature: 23.5 C");
        vTaskDelay(pdMS_TO_TICKS(500));

        vLogWriter("Sensor", LOG_WARNING, "Temp approaching threshold");
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void vNetworkTask(void *pvParameters) {
    (void)pvParameters;
    for (;;) {
        vLogWriter("Network", LOG_INFO, "MQTT connected");
        vTaskDelay(pdMS_TO_TICKS(2000));

        vLogWriter("Network", LOG_ERROR, "Connection lost: timeout");
        vTaskDelay(pdMS_TO_TICKS(3000));
    }
}

static void vLogConsumerTask(void *pvParameters) {
    (void)pvParameters;
    LogMessage_t xReceived;
    const char *pcLevelNames[] = {"INFO", "WARN", "ERROR"};

    for (;;) {
        /**
         * xMessageBufferReceive:
         *   - Reads exactly one complete message
         *   - The receive buffer must be large enough for the entire message
         *   - Returns the message size in bytes (0 if timeout or buffer too small)
         */
        size_t xBytesReceived = xMessageBufferReceive(
            xLogMessageBuffer,
            &xReceived,
            sizeof(xReceived),
            portMAX_DELAY
        );

        if (xBytesReceived > 0) {
            uint8_t ucLevel = (uint8_t)xReceived.eLevel;
            if (ucLevel > 2) ucLevel = 0;

            uart_printf("[%lu] LOG [%s] (logged at %lu): %s\r\n",
                         xTaskGetTickCount(),
                         pcLevelNames[ucLevel],
                         xReceived.xTimestamp,
                         xReceived.cMessage);
        }
    }
}

static void example3_message_buffer(void) {
    xLogMessageBuffer = xMessageBufferCreate(LOG_BUFFER_SIZE);
    configASSERT(xLogMessageBuffer != NULL);

    xTaskCreate(vSensorTask,      "LogSensor", 256, NULL, 2, NULL);
    xTaskCreate(vNetworkTask,     "LogNet",    256, NULL, 2, NULL);
    xTaskCreate(vLogConsumerTask, "LogCons",   512, NULL, 3, NULL);
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Example 4: Stream Buffer Query and Control                                */
/* ──────────────────────────────────────────────────────────────────────────── */

/**
 * Query functions:
 *
 * xStreamBufferBytesAvailable(xStreamBuffer):
 *   Returns number of bytes that can be read without blocking.
 *
 * xStreamBufferSpacesAvailable(xStreamBuffer):
 *   Returns number of bytes that can be written without blocking.
 *
 * xStreamBufferIsEmpty(xStreamBuffer):
 *   Returns pdTRUE if buffer contains zero bytes.
 *
 * xStreamBufferIsFull(xStreamBuffer):
 *   Returns pdTRUE if buffer has no free space.
 *
 * Control functions:
 *
 * xStreamBufferReset(xStreamBuffer):
 *   Empties the buffer. Must NOT be called while any task is blocked
 *   on the buffer. Returns pdPASS on success, pdFAIL if a task is blocked.
 *
 * xStreamBufferSetTriggerLevel(xStreamBuffer, xTriggerLevel):
 *   Changes the trigger level dynamically.
 *
 * All these functions also work on message buffers (which are stream buffers
 * internally).
 */

static void vBufferMonitorTask(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        if (xUARTStreamBuffer != NULL) {
            uart_printf("[%lu] Stream buffer status:\r\n", xTaskGetTickCount());
            uart_printf("  Bytes available: %u\r\n",
                         (unsigned)xStreamBufferBytesAvailable(xUARTStreamBuffer));
            uart_printf("  Spaces available: %u\r\n",
                         (unsigned)xStreamBufferSpacesAvailable(xUARTStreamBuffer));
            uart_printf("  Empty: %s\r\n",
                         xStreamBufferIsEmpty(xUARTStreamBuffer) ? "Yes" : "No");
            uart_printf("  Full: %s\r\n",
                         xStreamBufferIsFull(xUARTStreamBuffer) ? "Yes" : "No");
        }

        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}

/* ──────────────────────────────────────────────────────────────────────────── */
/*  Main                                                                      */
/* ──────────────────────────────────────────────────────────────────────────── */

void vApplicationIdleHook(void) { }
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask; (void)pcTaskName; for (;;) { }
}

int main(void) {
    example1_stream_buffer();
    example2_trigger_level();
    example3_message_buffer();

    xTaskCreate(vBufferMonitorTask, "BufMon", 256, NULL, 1, NULL);

    vTaskStartScheduler();
    for (;;) { }
    return 0;
}
