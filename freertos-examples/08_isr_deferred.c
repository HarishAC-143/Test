/**
 * FreeRTOS Example 08 — Interrupt Management and Deferred Processing
 *
 * Demonstrates:
 *   - FromISR API functions and pxHigherPriorityTaskWoken pattern
 *   - Binary semaphore for ISR-to-task deferred processing
 *   - Task notification for ISR-to-task signaling (faster alternative)
 *   - Queue for passing data from ISR to task
 *   - xTimerPendFunctionCallFromISR for lightweight deferred processing
 *   - Interrupt nesting and configMAX_SYSCALL_INTERRUPT_PRIORITY
 *   - Centralized interrupt dispatcher pattern
 *
 * Target: ARM Cortex-M4 (STM32F4xx)
 *
 * Key Concepts:
 *   1. ISRs must be SHORT — do the minimum work, defer the rest to tasks.
 *   2. Only ...FromISR() functions are safe to call from ISR context.
 *   3. FromISR functions NEVER block.
 *   4. portYIELD_FROM_ISR() should be called at the END of the ISR.
 *   5. Only ISRs with priority >= configMAX_SYSCALL_INTERRUPT_PRIORITY
 *      (numerically >=, which means lower urgency) can call FreeRTOS APIs.
 */

#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"
#include "timers.h"
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

/* Simulated peripheral registers */
static volatile uint32_t ADC_DR    = 0;
static volatile uint32_t UART_DR   = 0;
static volatile uint32_t GPIO_IDR  = 0;

/* ---------------------------------------------------------------------------
 * Interrupt Priority Model (Cortex-M4)
 *
 * Cortex-M4 typically has 4 priority bits (16 levels, 0-15).
 * LOWER number = HIGHER urgency.
 *
 *   Priority 0-4:  ABOVE configMAX_SYSCALL_INTERRUPT_PRIORITY
 *                  → Never masked by FreeRTOS critical sections
 *                  → MUST NOT call any FreeRTOS API functions
 *                  → Used for ultra-low-latency interrupts (motor control, etc.)
 *
 *   ─── configMAX_SYSCALL_INTERRUPT_PRIORITY (e.g., 5) ───
 *
 *   Priority 5-15: AT or BELOW the threshold
 *                  → CAN call ...FromISR() functions
 *                  → Masked during FreeRTOS critical sections
 *                  → Used for UART, SPI, I2C, ADC, etc.
 *
 *   Priority 15:   configKERNEL_INTERRUPT_PRIORITY
 *                  → SysTick and PendSV run here
 *                  → Lowest urgency — ensures all ISRs finish before
 *                    context switches
 *
 * CRITICAL: Setting an ISR to priority < configMAX_SYSCALL_INTERRUPT_PRIORITY
 *           while calling FreeRTOS APIs will cause hard faults or data
 *           corruption. FreeRTOS configASSERT catches this if defined.
 * --------------------------------------------------------------------------- */

/* ---------------------------------------------------------------------------
 * Example 1: Binary Semaphore — Classic Deferred Interrupt Pattern
 *
 * Pattern: ISR does minimum work (read register, clear flag), then
 * gives a semaphore. A high-priority task takes the semaphore and
 * does the heavy processing.
 *
 * Advantages:
 *   - ISR is very short (microseconds)
 *   - Processing runs at task priority (can be preempted)
 *   - Processing can use any FreeRTOS API (queues, delays, etc.)
 * --------------------------------------------------------------------------- */
static SemaphoreHandle_t xADCSemaphore = NULL;
static volatile uint16_t adc_raw_value = 0;

void ADC_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Minimal ISR work: read data, clear interrupt flag */
    adc_raw_value = (uint16_t)(ADC_DR & 0xFFF);
    /* ADC->SR &= ~ADC_SR_EOC; // Clear End-Of-Conversion flag */

    xSemaphoreGiveFromISR(xADCSemaphore, &xHigherPriorityTaskWoken);

    /*
     * portYIELD_FROM_ISR pends the PendSV exception if a higher-priority
     * task was unblocked. PendSV runs at the lowest interrupt priority,
     * so it fires AFTER this ISR and any other pending ISRs complete.
     *
     * On Cortex-M, this sets the PendSV pending bit in the SCB->ICSR register:
     *   SCB->ICSR = SCB_ICSR_PENDSVSET_Msk;
     *
     * If we don't call this, the unblocked task won't run until the next
     * tick interrupt — adding up to 1 ms of latency.
     */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vADCProcessingTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        if (xSemaphoreTake(xADCSemaphore, portMAX_DELAY) == pdTRUE) {
            /* Heavy processing — runs in task context */
            float voltage = (float)adc_raw_value * 3.3f / 4095.0f;

            char buf[80];
            snprintf(buf, sizeof(buf),
                     "[ADC] Raw=%u, Voltage=%.3fV\r\n",
                     adc_raw_value, (double)voltage);
            safe_print(buf);
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 2: Task Notification — Faster ISR-to-Task Signaling
 *
 * Task notifications are ~45% faster than semaphores because:
 *   - No queue lock/unlock overhead
 *   - No search through waiting task lists (direct TCB access)
 *   - Notification value is already in the TCB (no separate allocation)
 *
 * Use when: Only one task waits on the signal (1:1 signaling).
 * --------------------------------------------------------------------------- */
static TaskHandle_t xUARTTaskHandle = NULL;
static volatile uint8_t uart_rx_byte = 0;

void USART1_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    uart_rx_byte = (uint8_t)(UART_DR & 0xFF);
    /* USART1->SR &= ~USART_SR_RXNE; */

    vTaskNotifyGiveFromISR(xUARTTaskHandle, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vUARTProcessTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        char buf[64];
        snprintf(buf, sizeof(buf),
                 "[UART] Received byte: 0x%02X ('%c')\r\n",
                 uart_rx_byte,
                 (uart_rx_byte >= 0x20 && uart_rx_byte < 0x7F) ? uart_rx_byte : '.');
        safe_print(buf);
    }
}

/* ---------------------------------------------------------------------------
 * Example 3: Queue for ISR Data Transfer
 *
 * When the ISR produces data that the task needs to process, use a queue.
 * The queue buffers multiple samples, decoupling ISR rate from processing
 * rate.
 *
 * Important: xQueueSendFromISR NEVER blocks. If the queue is full, the
 * data is lost. Size the queue to handle worst-case burst rates.
 * --------------------------------------------------------------------------- */
typedef struct {
    uint16_t  channel;
    uint16_t  value;
    uint32_t  timestamp;
} ADCSample_t;

static QueueHandle_t xADCQueue = NULL;
#define ADC_QUEUE_SIZE  32

void ADC_DMA_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    ADCSample_t sample = {
        .channel   = 0,
        .value     = (uint16_t)(ADC_DR & 0xFFF),
        .timestamp = xTaskGetTickCountFromISR()
    };

    /*
     * xQueueSendFromISR:
     * - If queue has space: copies the sample, returns pdPASS
     * - If queue is full: returns errQUEUE_FULL (data is lost)
     * - If a task was blocked on xQueueReceive and is now unblocked:
     *   sets *pxHigherPriorityTaskWoken to pdTRUE
     *
     * Note: We use xQueueSendFromISR, not xQueueSend. The non-FromISR
     * version would attempt to block (enter Blocked state), which is
     * illegal in ISR context and would crash.
     */
    if (xQueueSendFromISR(xADCQueue, &sample, &xHigherPriorityTaskWoken) != pdPASS) {
        /* Queue full — sample lost. In production, increment an error counter. */
    }

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vADCQueueConsumerTask(void *pvParameters)
{
    (void)pvParameters;
    ADCSample_t sample;
    uint32_t processed = 0;

    for (;;) {
        if (xQueueReceive(xADCQueue, &sample, portMAX_DELAY) == pdPASS) {
            processed++;
            if (processed % 10 == 0) {
                char buf[128];
                snprintf(buf, sizeof(buf),
                         "[ADC-Q] #%lu: ch=%u val=%u t=%lu (queue: %u/%d)\r\n",
                         (unsigned long)processed,
                         sample.channel, sample.value,
                         (unsigned long)sample.timestamp,
                         (unsigned)uxQueueMessagesWaiting(xADCQueue),
                         ADC_QUEUE_SIZE);
                safe_print(buf);
            }
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 4: xTimerPendFunctionCallFromISR — Lightweight Deferred Processing
 *
 * For simple ISR handlers that don't justify a dedicated task, defer
 * processing to the timer daemon task.
 *
 * The deferred function runs in the timer daemon context with its priority
 * (configTIMER_TASK_PRIORITY). It receives two parameters.
 *
 * Requires: INCLUDE_xTimerPendFunctionCall = 1
 * --------------------------------------------------------------------------- */
void vButtonHandler(void *pvParam1, uint32_t ulParam2)
{
    uint32_t pin = (uint32_t)(uintptr_t)pvParam1;
    uint32_t state = ulParam2;

    char buf[80];
    snprintf(buf, sizeof(buf),
             "[BUTTON] Deferred: pin=%lu state=%s\r\n",
             (unsigned long)pin,
             state ? "pressed" : "released");
    safe_print(buf);
}

void EXTI0_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    uint32_t pin = 0;
    uint32_t state = (GPIO_IDR & (1 << pin)) ? 1 : 0;

    /*
     * xTimerPendFunctionCallFromISR enqueues a function call on the
     * timer command queue. The timer daemon dequeues and executes it.
     *
     * This is simpler than creating a dedicated task + semaphore
     * for each ISR handler.
     */
    xTimerPendFunctionCallFromISR(
        vButtonHandler,
        (void *)(uintptr_t)pin,
        state,
        &xHigherPriorityTaskWoken
    );

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

/* ---------------------------------------------------------------------------
 * Example 5: Multiple ISR Sources with Centralized Dispatcher
 *
 * When many peripherals share a processing task, use a queue of typed
 * events. Each ISR enqueues an event; the dispatcher task processes all.
 *
 * This pattern:
 *   - Reduces task count (one dispatcher instead of one per peripheral)
 *   - Provides ordering guarantees (events processed in arrival order)
 *   - Makes priority management simpler
 * --------------------------------------------------------------------------- */
typedef enum {
    ISR_EVENT_UART_RX,
    ISR_EVENT_SPI_DONE,
    ISR_EVENT_GPIO_EDGE,
    ISR_EVENT_TIMER_EXPIRE,
    ISR_EVENT_DMA_COMPLETE,
} ISREventType_t;

typedef struct {
    ISREventType_t eType;
    uint32_t       ulData;
    uint32_t       ulTimestamp;
} ISREvent_t;

static QueueHandle_t xISREventQueue = NULL;
#define ISR_EVENT_QUEUE_SIZE  32

/* Called from various ISR handlers */
static BaseType_t post_isr_event(ISREventType_t type, uint32_t data)
{
    BaseType_t xWoken = pdFALSE;
    ISREvent_t event = {
        .eType      = type,
        .ulData     = data,
        .ulTimestamp = xTaskGetTickCountFromISR()
    };
    xQueueSendFromISR(xISREventQueue, &event, &xWoken);
    return xWoken;
}

/* Example ISR handlers using the centralized dispatcher */
void USART2_IRQHandler(void)
{
    BaseType_t xWoken = post_isr_event(ISR_EVENT_UART_RX, UART_DR & 0xFF);
    portYIELD_FROM_ISR(xWoken);
}

void SPI1_IRQHandler(void)
{
    BaseType_t xWoken = post_isr_event(ISR_EVENT_SPI_DONE, 0);
    portYIELD_FROM_ISR(xWoken);
}

void EXTI1_IRQHandler(void)
{
    BaseType_t xWoken = post_isr_event(ISR_EVENT_GPIO_EDGE, GPIO_IDR);
    portYIELD_FROM_ISR(xWoken);
}

void vISRDispatcherTask(void *pvParameters)
{
    (void)pvParameters;
    ISREvent_t event;
    const char *event_names[] = {
        "UART_RX", "SPI_DONE", "GPIO_EDGE", "TIMER_EXPIRE", "DMA_COMPLETE"
    };

    for (;;) {
        if (xQueueReceive(xISREventQueue, &event, portMAX_DELAY) == pdPASS) {
            char buf[128];
            snprintf(buf, sizeof(buf),
                     "[DISPATCH] Event: %s, data=0x%08lX, t=%lu\r\n",
                     event_names[event.eType],
                     (unsigned long)event.ulData,
                     (unsigned long)event.ulTimestamp);
            safe_print(buf);

            switch (event.eType) {
            case ISR_EVENT_UART_RX:
                /* Process received UART byte */
                break;
            case ISR_EVENT_SPI_DONE:
                /* Handle SPI transfer completion */
                break;
            case ISR_EVENT_GPIO_EDGE:
                /* Handle GPIO event */
                break;
            case ISR_EVENT_TIMER_EXPIRE:
                /* Handle timer event */
                break;
            case ISR_EVENT_DMA_COMPLETE:
                /* Handle DMA completion */
                break;
            }
        }
    }
}

/* ---------------------------------------------------------------------------
 * Example 6: Nested Interrupt Safe Critical Sections
 *
 * In ISR context, use taskENTER_CRITICAL_FROM_ISR() and
 * taskEXIT_CRITICAL_FROM_ISR() for critical sections. These save and
 * restore the BASEPRI register, supporting nesting.
 *
 * Regular taskENTER_CRITICAL() uses a nesting counter and must NOT be
 * used from ISR context on Cortex-M.
 * --------------------------------------------------------------------------- */
static volatile uint32_t shared_data[4];

void TIM2_IRQHandler(void)
{
    /*
     * taskENTER_CRITICAL_FROM_ISR saves the current BASEPRI value and
     * raises it to configMAX_SYSCALL_INTERRUPT_PRIORITY.
     * taskEXIT_CRITICAL_FROM_ISR restores the saved value.
     *
     * This ensures atomic access to shared_data even if higher-priority
     * interrupts (below configMAX_SYSCALL_INTERRUPT_PRIORITY) try to
     * access the same data.
     */
    UBaseType_t uxSavedInterruptStatus = taskENTER_CRITICAL_FROM_ISR();

    shared_data[0]++;
    shared_data[1] = shared_data[0] * 2;
    shared_data[2] = shared_data[1] + 1;
    shared_data[3] = shared_data[2] - shared_data[0];

    taskEXIT_CRITICAL_FROM_ISR(uxSavedInterruptStatus);
}

/* Task-context critical section for the same shared data */
void vSharedDataTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        uint32_t local_copy[4];

        taskENTER_CRITICAL();
        memcpy(local_copy, (void *)shared_data, sizeof(local_copy));
        taskEXIT_CRITICAL();

        char buf[128];
        snprintf(buf, sizeof(buf),
                 "[SHARED] Data: [%lu, %lu, %lu, %lu]\r\n",
                 (unsigned long)local_copy[0],
                 (unsigned long)local_copy[1],
                 (unsigned long)local_copy[2],
                 (unsigned long)local_copy[3]);
        safe_print(buf);

        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

/* ---------------------------------------------------------------------------
 * Example 7: ISR Simulation Task (for testing without hardware)
 *
 * Simulates periodic ISR events by directly calling ISR-like functions.
 * In real systems, these would be triggered by hardware interrupts.
 * --------------------------------------------------------------------------- */
void vISRSimulatorTask(void *pvParameters)
{
    (void)pvParameters;

    for (;;) {
        /* Simulate ADC conversion complete */
        ADC_DR = 2048 + (xTaskGetTickCount() % 500);

        BaseType_t xWoken = pdFALSE;
        ADCSample_t sample = {
            .channel   = 0,
            .value     = (uint16_t)(ADC_DR & 0xFFF),
            .timestamp = xTaskGetTickCount()
        };
        xQueueSendFromISR(xADCQueue, &sample, &xWoken);

        /* Simulate UART RX */
        xWoken = pdFALSE;
        vTaskNotifyGiveFromISR(xUARTTaskHandle, &xWoken);

        /* Simulate semaphore-based ADC */
        xWoken = pdFALSE;
        xSemaphoreGiveFromISR(xADCSemaphore, &xWoken);

        vTaskDelay(pdMS_TO_TICKS(500));
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

    xPrintMtx      = xSemaphoreCreateMutex();
    xADCSemaphore  = xSemaphoreCreateBinary();
    xADCQueue      = xQueueCreate(ADC_QUEUE_SIZE, sizeof(ADCSample_t));
    xISREventQueue = xQueueCreate(ISR_EVENT_QUEUE_SIZE, sizeof(ISREvent_t));

    /* Deferred ADC processing via semaphore */
    xTaskCreate(vADCProcessingTask, "ADCProc", 256, NULL, 4, NULL);

    /* Deferred UART processing via notification */
    xTaskCreate(vUARTProcessTask, "UARTProc", 256, NULL, 4, &xUARTTaskHandle);

    /* ADC queue consumer */
    xTaskCreate(vADCQueueConsumerTask, "ADCQ", 256, NULL, 3, NULL);

    /* Centralized ISR dispatcher */
    xTaskCreate(vISRDispatcherTask, "Dispatch", 512, NULL, 3, NULL);

    /* Shared data accessor */
    xTaskCreate(vSharedDataTask, "SharedD", 256, NULL, 2, NULL);

    /* ISR simulator (for testing without hardware interrupts) */
    xTaskCreate(vISRSimulatorTask, "ISRSim", 256, NULL, 5, NULL);

    vTaskStartScheduler();
    for (;;);
}
