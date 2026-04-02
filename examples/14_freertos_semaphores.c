/*
 * FreeRTOS Semaphore and Mutex Examples
 *
 * Demonstrates: xSemaphoreCreateBinary, xSemaphoreCreateCounting,
 *               xSemaphoreCreateMutex, xSemaphoreCreateRecursiveMutex,
 *               xSemaphoreTake, xSemaphoreGive, xSemaphoreGiveFromISR,
 *               priority inheritance, priority inversion prevention
 *
 * Target: ARM Cortex-M4 (STM32F4xx) with FreeRTOS v10.x/v11.x
 */

#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ---------- Hardware Stubs ---------- */

static inline void HAL_Init(void) {}
static inline void SystemClock_Config(void) {}

static volatile uint32_t sim_tick = 0;

static inline void led_toggle(uint32_t pin) { (void)pin; }

/* Simulated shared hardware: an SPI bus */
static volatile uint32_t spi_busy = 0;

static void spi_transfer(const uint8_t *tx, uint8_t *rx, uint32_t len)
{
    spi_busy = 1;
    for (volatile uint32_t i = 0; i < len * 100; i++);
    if (rx) memset(rx, 0xAA, len);
    spi_busy = 0;
}

/* ---------- FreeRTOS Hooks ---------- */

void vApplicationMallocFailedHook(void)  { for (;;); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *n) { for (;;); }
void vApplicationIdleHook(void) {}

/* =====================================================================
 * Example 1: Binary Semaphore — ISR-to-Task Synchronization
 *
 * A simulated interrupt handler signals a processing task using
 * a binary semaphore. The task blocks until the ISR signals it.
 * ===================================================================== */

static SemaphoreHandle_t xBinarySem;

void simulated_DMA_ISR(void)
{
    BaseType_t xWoken = pdFALSE;
    xSemaphoreGiveFromISR(xBinarySem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

static void vDmaProcessTask(void *pv)
{
    uint32_t transfer_count = 0;

    for (;;) {
        if (xSemaphoreTake(xBinarySem, portMAX_DELAY) == pdTRUE) {
            transfer_count++;
            printf("[DMA] Transfer #%lu complete — processing buffer\r\n",
                   transfer_count);
            vTaskDelay(pdMS_TO_TICKS(10));
        }
    }
}

/* Simulates periodic DMA completion interrupts */
static void vDmaTriggerTask(void *pv)
{
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(500));
        printf("[ISR-Sim] DMA transfer complete interrupt\r\n");
        simulated_DMA_ISR();
    }
}

/* =====================================================================
 * Example 2: Counting Semaphore — Resource Pool
 *
 * A counting semaphore manages a pool of DMA channels. Tasks must
 * acquire a channel before performing a transfer, and release it when
 * done.
 * ===================================================================== */

#define NUM_DMA_CHANNELS  3

static SemaphoreHandle_t xDmaPoolSem;

typedef struct {
    uint8_t  in_use;
    uint32_t transfer_count;
} DmaChannel_t;

static DmaChannel_t dma_channels[NUM_DMA_CHANNELS];
static SemaphoreHandle_t xDmaArrayMutex;

static int allocate_dma_channel(void)
{
    xSemaphoreTake(xDmaArrayMutex, portMAX_DELAY);
    for (int i = 0; i < NUM_DMA_CHANNELS; i++) {
        if (!dma_channels[i].in_use) {
            dma_channels[i].in_use = 1;
            xSemaphoreGive(xDmaArrayMutex);
            return i;
        }
    }
    xSemaphoreGive(xDmaArrayMutex);
    return -1;
}

static void release_dma_channel(int ch)
{
    xSemaphoreTake(xDmaArrayMutex, portMAX_DELAY);
    dma_channels[ch].in_use = 0;
    xSemaphoreGive(xDmaArrayMutex);
}

static void vDmaUserTask(void *pv)
{
    uint32_t task_id = (uint32_t)(uintptr_t)pv;

    for (;;) {
        printf("[Task-%lu] Waiting for DMA channel...\r\n", task_id);

        if (xSemaphoreTake(xDmaPoolSem, pdMS_TO_TICKS(5000)) == pdTRUE) {
            int ch = allocate_dma_channel();

            if (ch >= 0) {
                printf("[Task-%lu] Acquired DMA channel %d\r\n", task_id, ch);

                /* Simulate DMA transfer */
                vTaskDelay(pdMS_TO_TICKS(200 + task_id * 100));
                dma_channels[ch].transfer_count++;

                printf("[Task-%lu] Releasing DMA channel %d (total transfers: %lu)\r\n",
                       task_id, ch, dma_channels[ch].transfer_count);

                release_dma_channel(ch);
                xSemaphoreGive(xDmaPoolSem);
            }
        } else {
            printf("[Task-%lu] Timeout waiting for DMA channel\r\n", task_id);
        }

        vTaskDelay(pdMS_TO_TICKS(300));
    }
}

/* =====================================================================
 * Example 3: Mutex — Protecting Shared SPI Bus
 *
 * Multiple tasks share an SPI bus. A mutex ensures exclusive access.
 * Demonstrates proper acquire/release patterns and timeout handling.
 * ===================================================================== */

static SemaphoreHandle_t xSpiMutex;

typedef struct {
    uint8_t  cs_pin;
    char     device_name[16];
} SpiDevice_t;

static void spi_transaction(SpiDevice_t *dev, const uint8_t *tx, uint8_t *rx,
                             uint32_t len)
{
    /* Assert chip select, transfer, deassert */
    printf("  [SPI] CS%u (%s) active, transferring %lu bytes\r\n",
           dev->cs_pin, dev->device_name, len);
    spi_transfer(tx, rx, len);
}

static void vFlashTask(void *pv)
{
    SpiDevice_t dev = { .cs_pin = 0 };
    strncpy(dev.device_name, "W25Q128", sizeof(dev.device_name));
    uint8_t cmd[4] = {0x9F, 0, 0, 0};
    uint8_t resp[4];

    for (;;) {
        if (xSemaphoreTake(xSpiMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
            printf("[Flash] Acquired SPI bus\r\n");
            spi_transaction(&dev, cmd, resp, 4);
            printf("[Flash] JEDEC ID: 0x%02X%02X%02X\r\n",
                   resp[1], resp[2], resp[3]);
            xSemaphoreGive(xSpiMutex);
        } else {
            printf("[Flash] SPI bus timeout!\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

static void vAccelTask(void *pv)
{
    SpiDevice_t dev = { .cs_pin = 1 };
    strncpy(dev.device_name, "LIS3DH", sizeof(dev.device_name));
    uint8_t cmd[7] = {0x28 | 0x80 | 0x40, 0,0,0,0,0,0};
    uint8_t resp[7];

    for (;;) {
        if (xSemaphoreTake(xSpiMutex, pdMS_TO_TICKS(500)) == pdTRUE) {
            printf("[Accel] Acquired SPI bus\r\n");
            spi_transaction(&dev, cmd, resp, 7);
            int16_t x = (int16_t)(resp[1] | (resp[2] << 8));
            int16_t y = (int16_t)(resp[3] | (resp[4] << 8));
            int16_t z = (int16_t)(resp[5] | (resp[6] << 8));
            printf("[Accel] X=%d Y=%d Z=%d\r\n", x, y, z);
            xSemaphoreGive(xSpiMutex);
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

static void vDisplayTask(void *pv)
{
    SpiDevice_t dev = { .cs_pin = 2 };
    strncpy(dev.device_name, "ST7789", sizeof(dev.device_name));
    uint8_t frame_data[64];

    for (;;) {
        if (xSemaphoreTake(xSpiMutex, pdMS_TO_TICKS(2000)) == pdTRUE) {
            printf("[Display] Acquired SPI bus — sending frame\r\n");
            memset(frame_data, 0xFF, sizeof(frame_data));
            spi_transaction(&dev, frame_data, NULL, sizeof(frame_data));
            printf("[Display] Frame sent\r\n");
            xSemaphoreGive(xSpiMutex);
        }

        vTaskDelay(pdMS_TO_TICKS(33));  /* ~30 FPS */
    }
}

/* =====================================================================
 * Example 4: Priority Inheritance Demonstration
 *
 * Shows how a mutex with priority inheritance prevents unbounded
 * priority inversion. Contrast with a binary semaphore (no inheritance).
 *
 * Tasks:
 *   - Low (priority 1): holds mutex/semaphore for a long time
 *   - Medium (priority 2): CPU-bound, no mutex interaction
 *   - High (priority 3): tries to acquire the mutex/semaphore
 *
 * Without inheritance: High is blocked by Medium (Medium preempts Low
 * while Low holds the lock).
 * With inheritance: Low is boosted to High's priority, so Medium
 * cannot preempt Low while it holds the lock.
 * ===================================================================== */

static SemaphoreHandle_t xSharedLock;

static volatile uint32_t shared_resource = 0;

static void vLowPriorityTask(void *pv)
{
    for (;;) {
        printf("[Low] Attempting to take lock...\r\n");
        xSemaphoreTake(xSharedLock, portMAX_DELAY);

        printf("[Low] Holding lock — doing long operation\r\n");
        for (volatile uint32_t i = 0; i < 500000; i++) {
            shared_resource++;
        }

        printf("[Low] Releasing lock\r\n");
        xSemaphoreGive(xSharedLock);

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vMediumPriorityTask(void *pv)
{
    for (;;) {
        printf("[Med] Running CPU-intensive work (no lock needed)\r\n");
        for (volatile uint32_t i = 0; i < 200000; i++);
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

static void vHighPriorityTask(void *pv)
{
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(50));

        TickType_t start = xTaskGetTickCount();
        printf("[High] Attempting to take lock...\r\n");
        xSemaphoreTake(xSharedLock, portMAX_DELAY);

        TickType_t wait = xTaskGetTickCount() - start;
        printf("[High] Got lock after %lu ticks — accessing resource (val=%lu)\r\n",
               (unsigned long)wait, shared_resource);
        shared_resource = 0;

        xSemaphoreGive(xSharedLock);
    }
}

/* =====================================================================
 * Example 5: Recursive Mutex
 *
 * Demonstrates a recursive mutex used by nested function calls.
 * The same task takes the mutex multiple times without deadlocking.
 * ===================================================================== */

static SemaphoreHandle_t xRecursiveMutex;

typedef struct {
    float    x, y, z;
    uint32_t timestamp;
    uint8_t  valid;
} Position_t;

static Position_t g_position = {0};

static void update_position_x(float new_x)
{
    xSemaphoreTakeRecursive(xRecursiveMutex, portMAX_DELAY);
    g_position.x = new_x;
    g_position.timestamp = (uint32_t)xTaskGetTickCount();
    xSemaphoreGiveRecursive(xRecursiveMutex);
}

static void update_position_y(float new_y)
{
    xSemaphoreTakeRecursive(xRecursiveMutex, portMAX_DELAY);
    g_position.y = new_y;
    g_position.timestamp = (uint32_t)xTaskGetTickCount();
    xSemaphoreGiveRecursive(xRecursiveMutex);
}

/* This function locks the mutex and calls functions that also lock it */
static void update_full_position(float x, float y, float z)
{
    xSemaphoreTakeRecursive(xRecursiveMutex, portMAX_DELAY);

    update_position_x(x);  /* Takes recursive mutex again (nesting level 2) */
    update_position_y(y);  /* Takes recursive mutex again (nesting level 2) */
    g_position.z = z;
    g_position.valid = 1;

    xSemaphoreGiveRecursive(xRecursiveMutex);
}

static void vGpsTask(void *pv)
{
    float lat = 37.7749f, lon = -122.4194f, alt = 10.0f;

    for (;;) {
        lat += 0.0001f;
        lon += 0.00005f;
        alt += 0.5f;

        update_full_position(lat, lon, alt);
        printf("[GPS] Updated position: (%.4f, %.5f, %.1f)\r\n",
               (double)lat, (double)lon, (double)alt);

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

static void vNavigationTask(void *pv)
{
    for (;;) {
        Position_t pos;

        xSemaphoreTakeRecursive(xRecursiveMutex, portMAX_DELAY);
        pos = g_position;
        xSemaphoreGiveRecursive(xRecursiveMutex);

        if (pos.valid) {
            printf("[Nav] Current position: (%.4f, %.5f, %.1f) @ tick %lu\r\n",
                   (double)pos.x, (double)pos.y, (double)pos.z,
                   pos.timestamp);
        }

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* =====================================================================
 * Example 6: Counting Semaphore — Event Counting
 *
 * Each button press ISR gives the semaphore. The processing task
 * takes once per event, ensuring no presses are missed (up to max count).
 * ===================================================================== */

#define MAX_PENDING_EVENTS  10

static SemaphoreHandle_t xButtonSem;

void simulated_button_ISR(void)
{
    BaseType_t xWoken = pdFALSE;
    xSemaphoreGiveFromISR(xButtonSem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

static void vButtonProcessTask(void *pv)
{
    uint32_t press_count = 0;

    for (;;) {
        if (xSemaphoreTake(xButtonSem, portMAX_DELAY) == pdTRUE) {
            press_count++;
            UBaseType_t pending = uxSemaphoreGetCount(xButtonSem);
            printf("[Button] Press #%lu processed (%lu still pending)\r\n",
                   press_count, (unsigned long)pending);

            /* Simulate debounce + processing time */
            vTaskDelay(pdMS_TO_TICKS(50));
        }
    }
}

/* Simulates rapid button presses */
static void vButtonSimulator(void *pv)
{
    for (;;) {
        /* Burst of 5 rapid presses */
        printf("[BtnSim] --- Burst of 5 presses ---\r\n");
        for (int i = 0; i < 5; i++) {
            simulated_button_ISR();
            vTaskDelay(pdMS_TO_TICKS(20));
        }
        vTaskDelay(pdMS_TO_TICKS(3000));
    }
}

/* =====================================================================
 * Example 7: Gatekeeper Pattern
 *
 * Instead of mutexing a shared resource (e.g., UART), a single
 * "gatekeeper" task owns the resource exclusively. Other tasks send
 * requests via a queue. This eliminates mutex overhead and priority
 * inversion entirely.
 * ===================================================================== */

#define LOG_MSG_MAX_LEN   80
#define LOG_QUEUE_LEN     16

typedef struct {
    char     message[LOG_MSG_MAX_LEN];
    uint32_t timestamp;
    uint8_t  level;  /* 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR */
} LogEntry_t;

static QueueHandle_t xLogQueue;

static void log_send(uint8_t level, const char *fmt, uint32_t value)
{
    LogEntry_t entry;
    entry.level = level;
    entry.timestamp = (uint32_t)xTaskGetTickCount();
    snprintf(entry.message, sizeof(entry.message), fmt, value);

    xQueueSend(xLogQueue, &entry, pdMS_TO_TICKS(10));
}

static const char *level_str(uint8_t level)
{
    switch (level) {
        case 0: return "DBG";
        case 1: return "INF";
        case 2: return "WRN";
        case 3: return "ERR";
        default: return "???";
    }
}

static void vLogGatekeeperTask(void *pv)
{
    LogEntry_t entry;

    for (;;) {
        if (xQueueReceive(xLogQueue, &entry, portMAX_DELAY) == pdPASS) {
            printf("[%lu] [%s] %s\r\n",
                   entry.timestamp, level_str(entry.level), entry.message);
        }
    }
}

static void vSensorTask_Log(void *pv)
{
    uint32_t id = (uint32_t)(uintptr_t)pv;

    for (;;) {
        log_send(1, "Sensor reading acquired", id);
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

static void vCommsTask_Log(void *pv)
{
    uint32_t pkt = 0;

    for (;;) {
        log_send(0, "Packet sent", pkt++);
        if ((pkt % 5) == 0) {
            log_send(2, "Retransmission needed for packet", pkt - 1);
        }
        vTaskDelay(pdMS_TO_TICKS(200));
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

    printf("\r\n=== FreeRTOS Semaphore & Mutex Examples ===\r\n");
    printf("Running Example %d\r\n\r\n", EXAMPLE_SELECT);

#if EXAMPLE_SELECT == 1
    /* --- Binary semaphore: ISR-to-task sync --- */
    xBinarySem = xSemaphoreCreateBinary();
    configASSERT(xBinarySem);

    xTaskCreate(vDmaProcessTask, "DmaProc",  256, NULL, 3, NULL);
    xTaskCreate(vDmaTriggerTask, "DmaTrig",  256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 2
    /* --- Counting semaphore: DMA channel pool --- */
    xDmaPoolSem   = xSemaphoreCreateCounting(NUM_DMA_CHANNELS, NUM_DMA_CHANNELS);
    xDmaArrayMutex = xSemaphoreCreateMutex();
    memset(dma_channels, 0, sizeof(dma_channels));

    for (uint32_t i = 0; i < 5; i++) {
        char name[8];
        snprintf(name, sizeof(name), "DmaU%lu", i);
        xTaskCreate(vDmaUserTask, name, 256, (void *)(uintptr_t)i, 2, NULL);
    }

#elif EXAMPLE_SELECT == 3
    /* --- Mutex: shared SPI bus --- */
    xSpiMutex = xSemaphoreCreateMutex();
    configASSERT(xSpiMutex);

    xTaskCreate(vFlashTask,   "Flash",   256, NULL, 2, NULL);
    xTaskCreate(vAccelTask,   "Accel",   256, NULL, 3, NULL);
    xTaskCreate(vDisplayTask, "Display", 256, NULL, 1, NULL);

#elif EXAMPLE_SELECT == 4
    /* --- Priority inheritance demo ---
     * Change to xSemaphoreCreateBinary + xSemaphoreGive to see
     * the effect without priority inheritance. */
    xSharedLock = xSemaphoreCreateMutex();  /* Has priority inheritance */
    configASSERT(xSharedLock);

    xTaskCreate(vLowPriorityTask,    "Low",  256, NULL, 1, NULL);
    xTaskCreate(vMediumPriorityTask, "Med",  256, NULL, 2, NULL);
    xTaskCreate(vHighPriorityTask,   "High", 256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 5
    /* --- Recursive mutex --- */
    xRecursiveMutex = xSemaphoreCreateRecursiveMutex();
    configASSERT(xRecursiveMutex);

    xTaskCreate(vGpsTask,        "GPS", 256, NULL, 2, NULL);
    xTaskCreate(vNavigationTask, "Nav", 256, NULL, 3, NULL);

#elif EXAMPLE_SELECT == 6
    /* --- Counting semaphore: event counting --- */
    xButtonSem = xSemaphoreCreateCounting(MAX_PENDING_EVENTS, 0);
    configASSERT(xButtonSem);

    xTaskCreate(vButtonProcessTask, "BtnProc", 256, NULL, 3, NULL);
    xTaskCreate(vButtonSimulator,   "BtnSim",  256, NULL, 2, NULL);

#elif EXAMPLE_SELECT == 7
    /* --- Gatekeeper pattern --- */
    xLogQueue = xQueueCreate(LOG_QUEUE_LEN, sizeof(LogEntry_t));
    configASSERT(xLogQueue);

    xTaskCreate(vLogGatekeeperTask, "Logger", 512, NULL, 4, NULL);
    xTaskCreate(vSensorTask_Log,    "Sens1",  256, (void *)1, 2, NULL);
    xTaskCreate(vSensorTask_Log,    "Sens2",  256, (void *)2, 2, NULL);
    xTaskCreate(vCommsTask_Log,     "Comms",  256, NULL,       2, NULL);

#else
    printf("Invalid EXAMPLE_SELECT. Choose 1-7.\r\n");
#endif

    vTaskStartScheduler();

    for (;;);
}
