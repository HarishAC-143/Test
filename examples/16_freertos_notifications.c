/*
 * FreeRTOS Task Notifications, Stream Buffers, and Message Buffers
 *
 * Demonstrates: xTaskNotify, xTaskNotifyWait, ulTaskNotifyTake,
 *               vTaskNotifyGiveFromISR, xTaskNotifyFromISR,
 *               xStreamBufferCreate, xStreamBufferSend, xStreamBufferReceive,
 *               xMessageBufferCreate, xMessageBufferSend, xMessageBufferReceive
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10.x/v11.x
 */

#include "FreeRTOS.h"
#include "task.h"
#include "stream_buffer.h"
#include "message_buffer.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ---------- Hardware Stubs ---------- */

static inline void HAL_Init(void) {}
static inline void SystemClock_Config(void) {}

static volatile uint32_t sim_counter = 0;
static inline uint32_t read_adc(uint32_t ch) { return 2000 + (sim_counter++ & 0x1FF); }

/* ---------- FreeRTOS Hooks ---------- */

void vApplicationMallocFailedHook(void)  { for (;;); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *n) { for (;;); }
void vApplicationIdleHook(void) {}

/* =====================================================================
 * Example 1: Task Notification as Binary Semaphore
 *
 * Replaces a binary semaphore for ISR-to-task synchronization.
 * Uses vTaskNotifyGiveFromISR / ulTaskNotifyTake.
 * Faster and uses zero additional RAM compared to a semaphore.
 * ===================================================================== */

static TaskHandle_t xNotifyReceiverHandle;

void simulated_ADC_ISR(void)
{
    BaseType_t xWoken = pdFALSE;
    vTaskNotifyGiveFromISR(xNotifyReceiverHandle, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

static void vAdcNotifyTask(void *pv)
{
    uint32_t conversions = 0;

    for (;;) {
        /* Block until ISR notifies us — equivalent to xSemaphoreTake */
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        uint32_t value = read_adc(0);
        conversions++;

        if ((conversions % 20) == 0) {
            float voltage = (float)value * 3.3f / 4095.0f;
            printf("[ADC-Notify] Conversion #%lu: %lu (%.3f V)\r\n",
                   conversions, value, (double)voltage);
        }
    }
}

/* Simulates periodic ADC end-of-conversion interrupts */
static void vAdcTriggerTask(void *pv)
{
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(50));
        simulated_ADC_ISR();
    }
}

/* =====================================================================
 * Example 2: Task Notification as Counting Semaphore
 *
 * Multiple ISR events are counted via xTaskNotifyGive. The task
 * processes them one-by-one using ulTaskNotifyTake with decrement.
 * ===================================================================== */

static TaskHandle_t xCountingNotifyHandle;

void simulated_packet_ISR(void)
{
    BaseType_t xWoken = pdFALSE;
    vTaskNotifyGiveFromISR(xCountingNotifyHandle, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

static void vPacketProcessTask(void *pv)
{
    uint32_t processed = 0;

    for (;;) {
        /* Decrement (not clear): each take handles one event */
        ulTaskNotifyTake(pdFALSE, portMAX_DELAY);
        processed++;
        printf("[Packet] Processing packet #%lu\r\n", processed);
        vTaskDelay(pdMS_TO_TICKS(30)); /* Simulate processing time */
    }
}

/* Sends bursts of packet interrupts */
static void vPacketGeneratorTask(void *pv)
{
    uint32_t burst = 0;

    for (;;) {
        burst++;
        uint32_t count = 3 + (burst % 5);
        printf("[PktGen] Burst #%lu: %lu packets\r\n", burst, count);

        for (uint32_t i = 0; i < count; i++) {
            simulated_packet_ISR();
            vTaskDelay(pdMS_TO_TICKS(10));
        }

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* =====================================================================
 * Example 3: Task Notification as Event Flags (eSetBits)
 *
 * Multiple sources set bits in a task's notification value.
 * The receiving task uses xTaskNotifyWait to read and clear the bits.
 * ===================================================================== */

#define NOTIFY_BTN_PRESSED  (1 << 0)
#define NOTIFY_DATA_READY   (1 << 1)
#define NOTIFY_TIMEOUT      (1 << 2)
#define NOTIFY_ERROR        (1 << 3)
#define NOTIFY_WIFI_STATUS  (1 << 4)

static TaskHandle_t xEventReceiverHandle;

static void vEventFlagSetter1(void *pv)
{
    uint32_t cycle = 0;

    for (;;) {
        cycle++;
        if ((cycle % 3) == 0) {
            xTaskNotify(xEventReceiverHandle, NOTIFY_BTN_PRESSED, eSetBits);
        }
        if ((cycle % 4) == 0) {
            xTaskNotify(xEventReceiverHandle, NOTIFY_DATA_READY, eSetBits);
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vEventFlagSetter2(void *pv)
{
    uint32_t cycle = 0;

    for (;;) {
        cycle++;
        if ((cycle % 7) == 0) {
            xTaskNotify(xEventReceiverHandle, NOTIFY_TIMEOUT, eSetBits);
        }
        if ((cycle % 11) == 0) {
            xTaskNotify(xEventReceiverHandle, NOTIFY_ERROR, eSetBits);
        }
        if ((cycle % 5) == 0) {
            xTaskNotify(xEventReceiverHandle, NOTIFY_WIFI_STATUS, eSetBits);
        }
        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

static void vEventFlagReceiver(void *pv)
{
    for (;;) {
        uint32_t ulNotifiedValue;

        /* Wait for any bits; clear all bits on exit */
        if (xTaskNotifyWait(
                0x00,           /* Don't clear bits on entry */
                0xFFFFFFFF,     /* Clear all bits on exit */
                &ulNotifiedValue,
                portMAX_DELAY) == pdTRUE)
        {
            printf("[EvtFlags] Received: 0x%08lX → ", ulNotifiedValue);

            if (ulNotifiedValue & NOTIFY_BTN_PRESSED) printf("BUTTON ");
            if (ulNotifiedValue & NOTIFY_DATA_READY)  printf("DATA ");
            if (ulNotifiedValue & NOTIFY_TIMEOUT)     printf("TIMEOUT ");
            if (ulNotifiedValue & NOTIFY_ERROR)       printf("ERROR ");
            if (ulNotifiedValue & NOTIFY_WIFI_STATUS) printf("WIFI ");

            printf("\r\n");
        }
    }
}

/* =====================================================================
 * Example 4: Task Notification as Lightweight Mailbox
 *
 * Uses eSetValueWithOverwrite to send a 32-bit value directly.
 * Only the latest value is kept (previous values are overwritten).
 * ===================================================================== */

static TaskHandle_t xMailboxReceiverHandle;

typedef union {
    uint32_t raw;
    struct {
        uint16_t temperature_x10;   /* Temperature * 10 (e.g., 225 = 22.5°C) */
        uint8_t  humidity;          /* 0-100% */
        uint8_t  battery_pct;      /* 0-100% */
    } fields;
} CompactSensorData_t;

static void vCompactSensorProducer(void *pv)
{
    CompactSensorData_t data;
    uint32_t sample = 0;

    for (;;) {
        data.fields.temperature_x10 = 220 + (sample & 0x1F);
        data.fields.humidity        = 45 + (sample & 0x0F);
        data.fields.battery_pct    = 100 - (sample % 10);

        /* Overwrite: always succeeds, no blocking, 32-bit atomic */
        xTaskNotify(xMailboxReceiverHandle, data.raw, eSetValueWithOverwrite);

        sample++;
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void vCompactSensorConsumer(void *pv)
{
    for (;;) {
        uint32_t ulValue;

        if (xTaskNotifyWait(0, 0, &ulValue, pdMS_TO_TICKS(1000)) == pdTRUE) {
            CompactSensorData_t data;
            data.raw = ulValue;

            printf("[Mailbox] T=%.1f°C  H=%u%%  Bat=%u%%\r\n",
                   (double)data.fields.temperature_x10 / 10.0,
                   data.fields.humidity,
                   data.fields.battery_pct);
        } else {
            printf("[Mailbox] No update in 1s\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/* =====================================================================
 * Example 5: Stream Buffer — UART DMA Reception
 *
 * A DMA ISR feeds raw bytes into a stream buffer. A processing task
 * reads and parses lines from the buffer. The trigger level ensures
 * the reader is only woken when enough data is available.
 * ===================================================================== */

#define STREAM_BUF_SIZE     256
#define STREAM_TRIGGER_LVL  1

static StreamBufferHandle_t xUartStream;

void simulated_UART_DMA_ISR(const uint8_t *data, size_t len)
{
    BaseType_t xWoken = pdFALSE;
    xStreamBufferSendFromISR(xUartStream, data, len, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

static void vStreamReaderTask(void *pv)
{
    uint8_t line_buf[128];
    size_t line_pos = 0;

    for (;;) {
        uint8_t rx_buf[32];
        size_t received = xStreamBufferReceive(
            xUartStream, rx_buf, sizeof(rx_buf), portMAX_DELAY);

        for (size_t i = 0; i < received; i++) {
            if (rx_buf[i] == '\n' || line_pos >= sizeof(line_buf) - 1) {
                line_buf[line_pos] = '\0';
                printf("[Stream] Line: %s\r\n", (char *)line_buf);
                line_pos = 0;
            } else if (rx_buf[i] != '\r') {
                line_buf[line_pos++] = rx_buf[i];
            }
        }
    }
}

/* Simulates DMA transfers of UART data in chunks */
static void vUartDmaSimulator(void *pv)
{
    const char *nmea_sentences[] = {
        "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,47.0,M,,*47\n",
        "$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A\n",
        "$GPVTG,054.7,T,034.4,M,005.5,N,010.2,K*48\n",
    };

    for (;;) {
        for (int s = 0; nmea_sentences[s] != NULL && s < 3; s++) {
            const uint8_t *data = (const uint8_t *)nmea_sentences[s];
            size_t total = strlen(nmea_sentences[s]);
            size_t offset = 0;

            /* Send in small DMA-like chunks */
            while (offset < total) {
                size_t chunk = (total - offset > 8) ? 8 : (total - offset);
                simulated_UART_DMA_ISR(data + offset, chunk);
                offset += chunk;
                vTaskDelay(pdMS_TO_TICKS(5));
            }

            vTaskDelay(pdMS_TO_TICKS(200));
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

/* =====================================================================
 * Example 6: Stream Buffer — High-Throughput ADC Streaming
 *
 * An ADC ISR fills the stream buffer with sample blocks. A processing
 * task reads complete blocks and computes statistics. Uses a larger
 * trigger level to batch-process data.
 * ===================================================================== */

#define ADC_STREAM_SIZE     1024
#define ADC_BLOCK_SIZE      (32 * sizeof(uint16_t))
#define ADC_TRIGGER_LEVEL   ADC_BLOCK_SIZE

static StreamBufferHandle_t xAdcStream;

void simulated_ADC_DMA_ISR(void)
{
    uint16_t samples[32];
    for (int i = 0; i < 32; i++) {
        samples[i] = (uint16_t)read_adc(0);
    }

    BaseType_t xWoken = pdFALSE;
    xStreamBufferSendFromISR(xAdcStream, samples, sizeof(samples), &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

static void vAdcStreamProcessor(void *pv)
{
    uint16_t block[32];
    uint32_t block_num = 0;

    for (;;) {
        size_t received = xStreamBufferReceive(
            xAdcStream, block, sizeof(block), portMAX_DELAY);

        if (received == sizeof(block)) {
            block_num++;

            uint32_t sum = 0;
            uint16_t min_v = UINT16_MAX, max_v = 0;

            for (int i = 0; i < 32; i++) {
                sum += block[i];
                if (block[i] < min_v) min_v = block[i];
                if (block[i] > max_v) max_v = block[i];
            }

            if ((block_num % 50) == 0) {
                float avg_v = ((float)sum / 32.0f) * 3.3f / 4095.0f;
                printf("[ADC-Stream] Block #%lu: avg=%.3f V, range=[%u..%u]\r\n",
                       block_num, (double)avg_v, min_v, max_v);
            }
        }
    }
}

static void vAdcDmaSimulator(void *pv)
{
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(10));
        simulated_ADC_DMA_ISR();
    }
}

/* =====================================================================
 * Example 7: Message Buffer — Variable-Length Command Protocol
 *
 * A communication task receives variable-length command messages.
 * Unlike a stream buffer, message boundaries are preserved.
 * ===================================================================== */

#define MSG_BUF_SIZE  512

static MessageBufferHandle_t xCmdMsgBuffer;

typedef enum {
    CMD_SET_LED      = 0x01,
    CMD_READ_SENSOR  = 0x02,
    CMD_SET_CONFIG   = 0x03,
    CMD_RESET        = 0x04,
    CMD_QUERY_STATUS = 0x05,
} CommandType_t;

typedef struct {
    uint8_t  cmd;
    uint8_t  param_len;
    uint8_t  params[32];
} CommandMsg_t;

static void vCommandSender(void *pv)
{
    uint32_t seq = 0;

    for (;;) {
        CommandMsg_t msg;
        seq++;

        switch (seq % 5) {
            case 0:
                msg.cmd = CMD_SET_LED;
                msg.param_len = 2;
                msg.params[0] = 12;    /* Pin */
                msg.params[1] = 1;     /* State (on) */
                break;

            case 1:
                msg.cmd = CMD_READ_SENSOR;
                msg.param_len = 1;
                msg.params[0] = 0;     /* Channel */
                break;

            case 2:
                msg.cmd = CMD_SET_CONFIG;
                msg.param_len = 4;
                msg.params[0] = 0x00;  /* Config key (2 bytes) */
                msg.params[1] = 0x01;
                msg.params[2] = 0x03;  /* Config value (2 bytes) */
                msg.params[3] = 0xE8;
                break;

            case 3:
                msg.cmd = CMD_RESET;
                msg.param_len = 0;
                break;

            case 4:
                msg.cmd = CMD_QUERY_STATUS;
                msg.param_len = 0;
                break;
        }

        /* Send variable-length message — only sends cmd + param_len + actual params */
        size_t msg_size = 2 + msg.param_len;
        size_t sent = xMessageBufferSend(xCmdMsgBuffer, &msg, msg_size,
                                          pdMS_TO_TICKS(100));
        if (sent != msg_size) {
            printf("[CmdSend] Message buffer full!\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static const char *cmd_name(uint8_t cmd)
{
    switch (cmd) {
        case CMD_SET_LED:      return "SET_LED";
        case CMD_READ_SENSOR:  return "READ_SENSOR";
        case CMD_SET_CONFIG:   return "SET_CONFIG";
        case CMD_RESET:        return "RESET";
        case CMD_QUERY_STATUS: return "QUERY_STATUS";
        default:               return "UNKNOWN";
    }
}

static void vCommandProcessor(void *pv)
{
    uint8_t rx_buf[36];
    uint32_t cmd_count = 0;

    for (;;) {
        size_t received = xMessageBufferReceive(
            xCmdMsgBuffer, rx_buf, sizeof(rx_buf), portMAX_DELAY);

        if (received >= 2) {
            cmd_count++;
            CommandMsg_t *msg = (CommandMsg_t *)rx_buf;

            printf("[CmdProc] #%lu: %s (cmd=0x%02X, %u bytes params",
                   cmd_count, cmd_name(msg->cmd), msg->cmd, msg->param_len);

            if (msg->param_len > 0) {
                printf(": ");
                for (int i = 0; i < msg->param_len && i < 8; i++) {
                    printf("%02X ", msg->params[i]);
                }
            }
            printf(")\r\n");
        }
    }
}

/* =====================================================================
 * Example 8: Message Buffer — Inter-Task Logging with Metadata
 *
 * Multiple tasks send structured log messages of varying lengths
 * through a message buffer to a central logger.
 * ===================================================================== */

static MessageBufferHandle_t xLogMsgBuffer;

typedef struct {
    uint32_t timestamp;
    uint8_t  severity;     /* 0=DBG, 1=INF, 2=WRN, 3=ERR */
    uint8_t  source_id;
    uint8_t  msg_len;
    char     text[64];
} LogMessage_t;

static void log_message(uint8_t source, uint8_t severity, const char *text)
{
    LogMessage_t log;
    log.timestamp = (uint32_t)xTaskGetTickCount();
    log.severity  = severity;
    log.source_id = source;
    log.msg_len   = strlen(text);
    if (log.msg_len >= sizeof(log.text)) log.msg_len = sizeof(log.text) - 1;
    memcpy(log.text, text, log.msg_len);
    log.text[log.msg_len] = '\0';

    size_t total = offsetof(LogMessage_t, text) + log.msg_len + 1;
    xMessageBufferSend(xLogMsgBuffer, &log, total, pdMS_TO_TICKS(10));
}

static const char *severity_str(uint8_t s)
{
    const char *names[] = {"DBG", "INF", "WRN", "ERR"};
    return (s < 4) ? names[s] : "???";
}

static void vLogSinkTask(void *pv)
{
    uint8_t buf[sizeof(LogMessage_t)];

    for (;;) {
        size_t rcvd = xMessageBufferReceive(xLogMsgBuffer, buf, sizeof(buf),
                                             portMAX_DELAY);
        if (rcvd >= offsetof(LogMessage_t, text)) {
            LogMessage_t *log = (LogMessage_t *)buf;
            printf("[%lu] [%s] src=%u: %s\r\n",
                   log->timestamp, severity_str(log->severity),
                   log->source_id, log->text);
        }
    }
}

static void vLogProducerA(void *pv)
{
    for (;;) {
        log_message(1, 1, "Sensor reading acquired");
        vTaskDelay(pdMS_TO_TICKS(700));
        log_message(1, 0, "ADC calibration check passed");
        vTaskDelay(pdMS_TO_TICKS(1300));
    }
}

static void vLogProducerB(void *pv)
{
    uint32_t n = 0;

    for (;;) {
        n++;
        if ((n % 5) == 0) {
            log_message(2, 2, "Comm retry limit approaching");
        } else {
            log_message(2, 1, "Packet transmitted OK");
        }
        vTaskDelay(pdMS_TO_TICKS(400));
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

    printf("\r\n=== FreeRTOS Notifications & Buffers ===\r\n");
    printf("Running Example %d\r\n\r\n", EXAMPLE_SELECT);

#if EXAMPLE_SELECT == 1
    /* --- Task notification as binary semaphore --- */
    xTaskCreate(vAdcNotifyTask,  "AdcRx",  256, NULL, 3, &xNotifyReceiverHandle);
    xTaskCreate(vAdcTriggerTask, "AdcTrg", 256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 2
    /* --- Task notification as counting semaphore --- */
    xTaskCreate(vPacketProcessTask,    "PktProc", 256, NULL, 3, &xCountingNotifyHandle);
    xTaskCreate(vPacketGeneratorTask,  "PktGen",  256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 3
    /* --- Task notification as event flags --- */
    xTaskCreate(vEventFlagReceiver, "EvtRx",   256, NULL, 3, &xEventReceiverHandle);
    xTaskCreate(vEventFlagSetter1,  "EvtSet1", 256, NULL, 2, NULL);
    xTaskCreate(vEventFlagSetter2,  "EvtSet2", 256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 4
    /* --- Task notification as lightweight mailbox --- */
    xTaskCreate(vCompactSensorConsumer,  "MbxRx", 256, NULL, 3, &xMailboxReceiverHandle);
    xTaskCreate(vCompactSensorProducer,  "MbxTx", 256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 5
    /* --- Stream buffer: UART DMA simulation --- */
    xUartStream = xStreamBufferCreate(STREAM_BUF_SIZE, STREAM_TRIGGER_LVL);
    configASSERT(xUartStream);

    xTaskCreate(vStreamReaderTask,  "StrmRd",  512, NULL, 3, NULL);
    xTaskCreate(vUartDmaSimulator,  "UartSim", 256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 6
    /* --- Stream buffer: high-throughput ADC streaming --- */
    xAdcStream = xStreamBufferCreate(ADC_STREAM_SIZE, ADC_TRIGGER_LEVEL);
    configASSERT(xAdcStream);

    xTaskCreate(vAdcStreamProcessor, "AdcProc", 512, NULL, 3, NULL);
    xTaskCreate(vAdcDmaSimulator,    "AdcSim",  256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 7
    /* --- Message buffer: variable-length command protocol --- */
    xCmdMsgBuffer = xMessageBufferCreate(MSG_BUF_SIZE);
    configASSERT(xCmdMsgBuffer);

    xTaskCreate(vCommandSender,    "CmdSend", 256, NULL, 2, NULL);
    xTaskCreate(vCommandProcessor, "CmdProc", 512, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 8
    /* --- Message buffer: structured logging --- */
    xLogMsgBuffer = xMessageBufferCreate(1024);
    configASSERT(xLogMsgBuffer);

    xTaskCreate(vLogSinkTask,    "LogSink", 512, NULL, 4, NULL);
    xTaskCreate(vLogProducerA,   "LogA",    256, NULL, 2, NULL);
    xTaskCreate(vLogProducerB,   "LogB",    256, NULL, 2, NULL);

#else
    printf("Invalid EXAMPLE_SELECT. Choose 1-8.\r\n");
#endif

    vTaskStartScheduler();

    for (;;);
}
