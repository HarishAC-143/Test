/**
 * FreeRTOS Example 09 — Stream Buffers and Message Buffers
 *
 * Demonstrates:
 *   - Stream buffers for continuous byte-stream communication (like a pipe)
 *   - Message buffers for discrete, variable-length messages
 *   - Trigger levels for efficient batching
 *   - ISR-to-task data transfer via stream buffers
 *   - UART receive buffering pattern
 *   - Protocol framing with message buffers
 *   - Static allocation of stream/message buffers
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 *
 * Key Concept: Stream and message buffers are optimized for SINGLE-WRITER,
 * SINGLE-READER (SWSR) scenarios. They are more efficient than queues for
 * byte-oriented or variable-length message communication because:
 *   - No per-item overhead (queues copy fixed-size items)
 *   - Circular buffer with minimal metadata
 *   - Trigger levels reduce context switch frequency
 *
 * Limitation: Only ONE writer and ONE reader. Using multiple writers or
 * readers requires external synchronization (mutex), which negates the
 * performance benefit. Use queues for multi-producer/consumer patterns.
 */

#include "FreeRTOS.h"
#include "task.h"
#include "stream_buffer.h"
#include "message_buffer.h"
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
 * Example 1: UART Receive via Stream Buffer
 *
 * Stream buffers handle continuous byte streams with no message boundaries.
 * The ISR writes individual bytes; the task reads them in chunks.
 *
 * Internal structure:
 *   - Circular buffer of xBufferSizeBytes
 *   - Read and write indices
 *   - Trigger level: minimum bytes before the reader is unblocked
 *   - One waiting writer task (or NULL)
 *   - One waiting reader task (or NULL)
 *
 * Stream buffers are more efficient than queues for byte data because
 * queues would require one queue item per byte (each with per-item overhead).
 * --------------------------------------------------------------------------- */
static StreamBufferHandle_t xUartStream = NULL;
#define UART_STREAM_SIZE     512
#define UART_TRIGGER_LEVEL   1    /* Unblock reader on first byte */

void USART1_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    uint8_t byte = 'A'; /* In real code: byte = USART1->DR; */

    /*
     * xStreamBufferSendFromISR writes bytes into the circular buffer.
     * Returns the number of bytes actually written (may be less than
     * requested if the buffer is full).
     *
     * The reader is unblocked only if the total buffered bytes >= trigger level.
     */
    size_t sent = xStreamBufferSendFromISR(xUartStream, &byte, 1,
                                            &xHigherPriorityTaskWoken);
    (void)sent;

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vUartParserTask(void *pvParameters)
{
    (void)pvParameters;
    uint8_t rxbuf[64];

    for (;;) {
        /*
         * xStreamBufferReceive:
         *   - Blocks until at least xTriggerLevel bytes are available
         *     (or timeout expires)
         *   - Copies up to xBufferLengthBytes from the stream buffer
         *   - Returns the actual number of bytes received
         *
         * This is efficient for variable-length reads — no need to
         * read exactly N bytes.
         */
        size_t received = xStreamBufferReceive(xUartStream, rxbuf,
                                                sizeof(rxbuf),
                                                portMAX_DELAY);

        if (received > 0) {
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "[UART-STREAM] Received %u bytes (buffer: %u/%d used)\r\n",
                     (unsigned)received,
                     (unsigned)(UART_STREAM_SIZE -
                                xStreamBufferSpacesAvailable(xUartStream)),
                     UART_STREAM_SIZE);
            safe_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Stream Buffer with Higher Trigger Level
 *
 * Setting a higher trigger level reduces context switches. The reader
 * is only unblocked when N or more bytes are buffered.
 *
 * Use case: GPS NMEA parser that processes complete sentences (~80 bytes).
 * Setting trigger level to 40 means the parser is woken less often but
 * receives more data per wakeup.
 *
 * xStreamBufferSetTriggerLevel() can change the trigger dynamically.
 * --------------------------------------------------------------------------- */
static StreamBufferHandle_t xGPSStream = NULL;
#define GPS_STREAM_SIZE     256
#define GPS_TRIGGER_LEVEL   40

void vGPSProducerTask(void *pvParameters)
{
    (void)pvParameters;
    const char *nmea_sentences[] = {
        "$GPGGA,092750.000,5321.6802,N,00630.3372,W,1,8,1.03,61.7,M,55.2,M,,*76\r\n",
        "$GPGSA,A,3,10,07,05,02,29,04,08,13,,,,,1.72,1.03,1.38*0A\r\n",
        "$GPGSV,3,1,11,10,63,137,17,07,61,098,15,05,59,290,20,08,54,157,30*70\r\n",
        "$GPRMC,092750.000,A,5321.6802,N,00630.3372,W,0.02,31.66,280511,,,A*43\r\n",
    };
    int idx = 0;

    for (;;) {
        const char *sentence = nmea_sentences[idx % 4];
        size_t len = strlen(sentence);

        /*
         * xStreamBufferSend:
         *   - Writes bytes into the circular buffer
         *   - If buffer doesn't have enough space, blocks up to xTicksToWait
         *   - Returns the number of bytes actually written
         *   - May write partial data if timeout expires with only some space
         */
        size_t sent = xStreamBufferSend(xGPSStream, sentence, len,
                                         pdMS_TO_TICKS(100));

        if (sent < len) {
            char buf[64];
            snprintf(buf, sizeof(buf),
                     "[GPS-TX] Buffer full — sent %u of %u bytes\r\n",
                     (unsigned)sent, (unsigned)len);
            safe_print(buf);
        }

        idx++;
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

void vGPSConsumerTask(void *pvParameters)
{
    (void)pvParameters;
    char rxbuf[128];

    for (;;) {
        size_t received = xStreamBufferReceive(xGPSStream, rxbuf,
                                                sizeof(rxbuf) - 1,
                                                portMAX_DELAY);

        if (received > 0) {
            rxbuf[received] = '\0';

            /* Check stream buffer status */
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "[GPS-RX] Got %u bytes, available=%u, spaces=%u\r\n",
                     (unsigned)received,
                     (unsigned)xStreamBufferBytesAvailable(xGPSStream),
                     (unsigned)xStreamBufferSpacesAvailable(xGPSStream));
            safe_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Message Buffer — Variable-Length Discrete Messages
 *
 * A message buffer is a stream buffer with LENGTH-PREFIXED messages.
 * Each xMessageBufferSend prepends a size_t header (4 bytes on 32-bit)
 * before the message data. xMessageBufferReceive reads the header to
 * know how many bytes to return.
 *
 * This means each message has sizeof(size_t) bytes of overhead.
 * A 100-byte buffer can hold at most one 96-byte message.
 *
 * Unlike stream buffers, message boundaries are preserved — the reader
 * always receives complete messages.
 *
 * Use case: Sending variable-length command packets, log entries, or
 * structured data between tasks.
 * --------------------------------------------------------------------------- */

typedef struct {
    uint8_t  cmd_id;
    uint8_t  flags;
    uint16_t payload_len;
    uint8_t  payload[32];
} Packet_t;

static MessageBufferHandle_t xCmdMsgBuffer = NULL;
#define CMD_MSG_BUFFER_SIZE  512

void vPacketSenderTask(void *pvParameters)
{
    (void)pvParameters;
    uint8_t seq = 0;

    for (;;) {
        Packet_t pkt;
        pkt.cmd_id = seq++;
        pkt.flags  = 0x01;

        /* Variable payload length */
        pkt.payload_len = 4 + (seq % 16);
        for (int i = 0; i < pkt.payload_len && i < 32; i++) {
            pkt.payload[i] = (uint8_t)(seq + i);
        }

        /* Calculate actual message size (only send used portion) */
        size_t msg_size = offsetof(Packet_t, payload) + pkt.payload_len;

        /*
         * xMessageBufferSend:
         *   - Writes sizeof(size_t) header + msg_size bytes of data
         *   - Blocks if buffer doesn't have enough space
         *   - Returns msg_size on success, 0 on timeout
         *
         * The total buffer space consumed = sizeof(size_t) + msg_size.
         */
        size_t sent = xMessageBufferSend(xCmdMsgBuffer, &pkt, msg_size,
                                          pdMS_TO_TICKS(100));

        if (sent > 0) {
            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[MSG-TX] Sent cmd=%u, payload=%u bytes\r\n",
                     pkt.cmd_id, pkt.payload_len);
            safe_print(buf);
        } else {
            safe_print("[MSG-TX] Buffer full!\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

void vPacketReceiverTask(void *pvParameters)
{
    (void)pvParameters;
    Packet_t pkt;

    for (;;) {
        /*
         * xMessageBufferReceive:
         *   - Reads the size_t header to determine message length
         *   - Copies that many bytes into the output buffer
         *   - Returns the message size, or 0 on timeout
         *   - If the output buffer is too small for the message,
         *     the message is discarded and 0 is returned
         *
         * The reader always gets a complete message — never partial data.
         */
        size_t received = xMessageBufferReceive(xCmdMsgBuffer, &pkt,
                                                 sizeof(pkt), portMAX_DELAY);

        if (received > 0) {
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "[MSG-RX] cmd=%u flags=0x%02X payload_len=%u (msg_size=%u)\r\n",
                     pkt.cmd_id, pkt.flags, pkt.payload_len,
                     (unsigned)received);
            safe_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 4: Message Buffer from ISR
 *
 * Pattern: ISR receives variable-length data frames from a protocol
 * and sends them as discrete messages to a processing task.
 * --------------------------------------------------------------------------- */
static MessageBufferHandle_t xISRMsgBuffer = NULL;
#define ISR_MSG_BUFFER_SIZE  256

typedef struct {
    uint8_t  type;
    uint8_t  len;
    uint8_t  data[16];
} Frame_t;

void SPI_RX_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    Frame_t frame = {
        .type = 0x42,
        .len  = 8,
        .data = {1, 2, 3, 4, 5, 6, 7, 8}
    };

    size_t actual_size = offsetof(Frame_t, data) + frame.len;

    /*
     * xMessageBufferSendFromISR never blocks. Returns actual_size on
     * success, 0 if the buffer doesn't have enough space.
     */
    xMessageBufferSendFromISR(xISRMsgBuffer, &frame, actual_size,
                               &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vFrameProcessorTask(void *pvParameters)
{
    (void)pvParameters;
    Frame_t frame;

    for (;;) {
        size_t received = xMessageBufferReceive(xISRMsgBuffer, &frame,
                                                 sizeof(frame), portMAX_DELAY);
        if (received > 0) {
            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[FRAME] type=0x%02X len=%u first_byte=%u\r\n",
                     frame.type, frame.len,
                     frame.len > 0 ? frame.data[0] : 0);
            safe_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 5: Statically Allocated Stream and Message Buffers
 *
 * For systems that avoid dynamic allocation (safety-critical), both
 * stream buffers and message buffers support static allocation.
 *
 * The caller provides:
 *   - Storage buffer (uint8_t array of xBufferSizeBytes + 1)
 *   - Static structure (StaticStreamBuffer_t or StaticMessageBuffer_t)
 *
 * Note: The +1 is required because the circular buffer implementation
 * uses one byte as a sentinel to distinguish full from empty.
 * --------------------------------------------------------------------------- */
#define STATIC_STREAM_SIZE  128
static uint8_t              ucStaticStreamStorage[STATIC_STREAM_SIZE + 1];
static StaticStreamBuffer_t xStaticStreamStruct;
static StreamBufferHandle_t xStaticStream = NULL;

#define STATIC_MSG_SIZE     128
static uint8_t                ucStaticMsgStorage[STATIC_MSG_SIZE + 1];
static StaticMessageBuffer_t  xStaticMsgStruct;
static MessageBufferHandle_t  xStaticMsgBuf = NULL;

void vStaticBufferProducer(void *pvParameters)
{
    (void)pvParameters;
    uint32_t seq = 0;

    for (;;) {
        /* Write to static stream buffer */
        char data[32];
        int len = snprintf(data, sizeof(data), "seq:%lu\n", (unsigned long)seq++);
        xStreamBufferSend(xStaticStream, data, (size_t)len, pdMS_TO_TICKS(50));

        /* Write to static message buffer */
        uint32_t msg = seq;
        xMessageBufferSend(xStaticMsgBuf, &msg, sizeof(msg), pdMS_TO_TICKS(50));

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void vStaticBufferConsumer(void *pvParameters)
{
    (void)pvParameters;
    char stream_data[64];
    uint32_t msg_data;

    for (;;) {
        size_t n = xStreamBufferReceive(xStaticStream, stream_data,
                                         sizeof(stream_data) - 1,
                                         pdMS_TO_TICKS(1000));
        if (n > 0) {
            stream_data[n] = '\0';
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "[STATIC-STREAM] Received: %s", stream_data);
            safe_print(buf);
        }

        n = xMessageBufferReceive(xStaticMsgBuf, &msg_data, sizeof(msg_data),
                                   pdMS_TO_TICKS(100));
        if (n > 0) {
            char buf[64];
            snprintf(buf, sizeof(buf),
                     "[STATIC-MSG] Received: %lu\r\n",
                     (unsigned long)msg_data);
            safe_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 6: Stream Buffer Query and Reset
 * --------------------------------------------------------------------------- */
void vBufferStatusTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(10000));

        safe_print("\r\n=== Buffer Status ===\r\n");

        char buf[128];

        if (xUartStream != NULL) {
            snprintf(buf, sizeof(buf),
                     "  UART Stream: available=%u, spaces=%u, full=%s, empty=%s\r\n",
                     (unsigned)xStreamBufferBytesAvailable(xUartStream),
                     (unsigned)xStreamBufferSpacesAvailable(xUartStream),
                     xStreamBufferIsFull(xUartStream) ? "YES" : "no",
                     xStreamBufferIsEmpty(xUartStream) ? "YES" : "no");
            safe_print(buf);
        }

        if (xGPSStream != NULL) {
            snprintf(buf, sizeof(buf),
                     "  GPS Stream:  available=%u, spaces=%u\r\n",
                     (unsigned)xStreamBufferBytesAvailable(xGPSStream),
                     (unsigned)xStreamBufferSpacesAvailable(xGPSStream));
            safe_print(buf);
        }

        safe_print("=====================\r\n\r\n");
    }
}

/* ---------------------------------------------------------------------------
 * Hooks
 * --------------------------------------------------------------------------- */
void vApplicationMallocFailedHook(void)                         { for(;;); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *n)     { (void)t; (void)n; for(;;); }
void vApplicationIdleHook(void)                                 { __asm volatile("wfi"); }

/* ---------------------------------------------------------------------------
 * Main
 * --------------------------------------------------------------------------- */
int main(void)
{
    hw_init();

    xPrintMtx = xSemaphoreCreateMutex();

    /* Dynamic stream/message buffers */
    xUartStream   = xStreamBufferCreate(UART_STREAM_SIZE, UART_TRIGGER_LEVEL);
    xGPSStream    = xStreamBufferCreate(GPS_STREAM_SIZE, GPS_TRIGGER_LEVEL);
    xCmdMsgBuffer = xMessageBufferCreate(CMD_MSG_BUFFER_SIZE);
    xISRMsgBuffer = xMessageBufferCreate(ISR_MSG_BUFFER_SIZE);

    /* Static stream/message buffers */
    xStaticStream = xStreamBufferCreateStatic(
        STATIC_STREAM_SIZE, 1,
        ucStaticStreamStorage, &xStaticStreamStruct
    );
    xStaticMsgBuf = xMessageBufferCreateStatic(
        STATIC_MSG_SIZE,
        ucStaticMsgStorage, &xStaticMsgStruct
    );

    /* UART stream tasks */
    xTaskCreate(vUartParserTask, "UartParse", 256, NULL, 3, NULL);

    /* GPS stream tasks */
    xTaskCreate(vGPSProducerTask, "GPSTx", 256, NULL, 2, NULL);
    xTaskCreate(vGPSConsumerTask, "GPSRx", 256, NULL, 3, NULL);

    /* Message buffer tasks */
    xTaskCreate(vPacketSenderTask,   "PktTx", 256, NULL, 2, NULL);
    xTaskCreate(vPacketReceiverTask, "PktRx", 256, NULL, 3, NULL);

    /* ISR message processor */
    xTaskCreate(vFrameProcessorTask, "FrameP", 256, NULL, 3, NULL);

    /* Static buffer tasks */
    xTaskCreate(vStaticBufferProducer, "StatProd", 256, NULL, 2, NULL);
    xTaskCreate(vStaticBufferConsumer, "StatCons", 256, NULL, 2, NULL);

    /* Status monitor */
    xTaskCreate(vBufferStatusTask, "BufStat", 256, NULL, 1, NULL);

    vTaskStartScheduler();
    for (;;);
}
