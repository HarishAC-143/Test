# FreeRTOS Comprehensive Guide

A deep-dive tutorial covering FreeRTOS from fundamentals to advanced internals, with detailed function references and practical examples targeting ARM Cortex-M microcontrollers.

---

## Table of Contents

1. [Introduction to FreeRTOS](#1-introduction-to-freertos)
2. [Architecture and Kernel Internals](#2-architecture-and-kernel-internals)
3. [Task Management](#3-task-management)
4. [The Scheduler: How It Works Internally](#4-the-scheduler-how-it-works-internally)
5. [Queues](#5-queues)
6. [Semaphores](#6-semaphores)
7. [Mutexes](#7-mutexes)
8. [Event Groups](#8-event-groups)
9. [Software Timers](#9-software-timers)
10. [Task Notifications](#10-task-notifications)
11. [Stream Buffers and Message Buffers](#11-stream-buffers-and-message-buffers)
12. [Memory Management](#12-memory-management)
13. [Interrupt Management and Deferred Processing](#13-interrupt-management-and-deferred-processing)
14. [Tick Hook, Idle Hook, and Stack Overflow Detection](#14-tick-hook-idle-hook-and-stack-overflow-detection)
15. [FreeRTOSConfig.h — Kernel Configuration Reference](#15-freertosconfigh--kernel-configuration-reference)
16. [Common Pitfalls and Debugging](#16-common-pitfalls-and-debugging)
17. [Design Patterns and Best Practices](#17-design-patterns-and-best-practices)
18. [Example Summary](#18-example-summary)

---

## 1. Introduction to FreeRTOS

### What Is FreeRTOS?

FreeRTOS is an open-source, real-time operating system kernel designed for embedded systems and microcontrollers. Originally created by Richard Barry in 2003, it is now maintained by Amazon Web Services (AWS) under the MIT license. FreeRTOS provides:

- **Preemptive, cooperative, or hybrid scheduling** for concurrent tasks
- **Inter-task communication** via queues, semaphores, mutexes, event groups, and notifications
- **Deterministic timing** suitable for hard and soft real-time applications
- **Tiny footprint** — as small as 5–10 KB of ROM and a few hundred bytes of RAM for the kernel

### Why FreeRTOS?

| Feature | Bare-Metal | FreeRTOS | Full OS (Linux) |
|---|---|---|---|
| Footprint | 0 overhead | 5–10 KB ROM | Megabytes |
| Determinism | Manual | Guaranteed (configurable) | Best-effort |
| Concurrency | Super-loop / ISRs only | Tasks + ISRs | Threads + processes |
| Debugging | Simple | Moderate | Complex |
| Ecosystem | None | AWS IoT, MQTT, TLS, etc. | Full POSIX |

FreeRTOS fills the gap between bare-metal super-loop programming and full operating systems, providing structured concurrency without the overhead of Linux.

### Key Concepts

| Concept | Description |
|---|---|
| **Task** | An independent thread of execution with its own stack and priority |
| **Scheduler** | The kernel component that decides which task runs next |
| **Tick** | A periodic timer interrupt that drives the scheduler (typically 1 ms) |
| **Context Switch** | Saving one task's CPU state and restoring another's |
| **Critical Section** | A region of code where interrupts are masked to protect shared resources |
| **Kernel Object** | Any synchronization/communication primitive (queue, semaphore, etc.) |

### Supported Architectures

FreeRTOS supports 40+ architectures including:

- ARM Cortex-M (M0, M0+, M3, M4F, M7, M23, M33, M55)
- ARM Cortex-A (A5, A9, A53)
- RISC-V
- Xtensa (ESP32)
- x86 / Windows / POSIX (for simulation)

Throughout this guide, examples target **ARM Cortex-M4** (STM32F4 series), but the API is identical across all ports.

---

## 2. Architecture and Kernel Internals

### Kernel Source Structure

```
FreeRTOS/
├── Source/
│   ├── tasks.c           ← Task management, scheduler
│   ├── queue.c           ← Queues, semaphores, mutexes (all use the queue struct)
│   ├── list.c            ← Doubly-linked list used by all kernel objects
│   ├── timers.c          ← Software timer daemon
│   ├── event_groups.c    ← Event group implementation
│   ├── stream_buffer.c   ← Stream and message buffers
│   ├── croutine.c        ← Co-routines (legacy, rarely used)
│   ├── include/
│   │   ├── FreeRTOS.h    ← Master include, brings in FreeRTOSConfig.h
│   │   ├── task.h        ← Task API declarations
│   │   ├── queue.h       ← Queue API declarations
│   │   ├── semphr.h      ← Semaphore/mutex macros (wrappers around queue.h)
│   │   ├── event_groups.h
│   │   ├── timers.h
│   │   ├── stream_buffer.h
│   │   └── message_buffer.h
│   └── portable/
│       ├── GCC/ARM_CM4F/   ← Cortex-M4F port
│       │   ├── port.c      ← PendSV handler, SVC handler, tick setup
│       │   └── portmacro.h ← Critical section macros, stack type, tick type
│       └── MemMang/
│           ├── heap_1.c    ← Allocate-only
│           ├── heap_2.c    ← Allocate + free (no coalescing)
│           ├── heap_3.c    ← Wraps standard malloc/free
│           ├── heap_4.c    ← Allocate + free + coalescing
│           └── heap_5.c    ← heap_4 with multiple memory regions
```

### The List Data Structure (`list.c`)

Every ready queue, blocked list, and timer list is built on FreeRTOS's internal doubly-linked list. Understanding it is key to understanding the kernel.

```c
/* Core structures in list.h */

struct xLIST_ITEM {
    configLIST_VOLATILE TickType_t xItemValue;  /* Sort key (e.g., wake time) */
    struct xLIST_ITEM * pxNext;
    struct xLIST_ITEM * pxPrevious;
    void * pvOwner;                              /* Pointer back to the TCB */
    struct xLIST * pxContainer;                  /* Which list this item is in */
};

struct xLIST {
    volatile UBaseType_t uxNumberOfItems;
    ListItem_t * pxIndex;                        /* Used for round-robin traversal */
    MiniListItem_t xListEnd;                     /* Sentinel node (value = max) */
};
```

Internal list functions:

| Function | Description |
|---|---|
| `vListInitialise(List_t *)` | Initialize a list with its sentinel node |
| `vListInitialiseItem(ListItem_t *)` | Initialize a list item (sets container to NULL) |
| `vListInsertEnd(List_t *, ListItem_t *)` | Insert before the current `pxIndex` (used for ready lists — FIFO within a priority) |
| `vListInsert(List_t *, ListItem_t *)` | Insert in sorted order by `xItemValue` (used for delay/timer lists) |
| `uxListRemove(ListItem_t *)` | Remove from its current list, return remaining count |

The scheduler's ready lists are arrays of `List_t`, one per priority level. `vListInsertEnd` guarantees FIFO ordering among equal-priority tasks (round-robin). `vListInsert` is used for delay lists where tasks are ordered by their wake-up tick.

### Task Control Block (TCB)

Every task has a TCB — the core data structure describing a task's state:

```c
typedef struct tskTaskControlBlock {
    volatile StackType_t * pxTopOfStack;     /* MUST be first field (used by context switch asm) */

    ListItem_t    xStateListItem;            /* Ready / Blocked / Suspended list item */
    ListItem_t    xEventListItem;            /* Queue/semaphore wait list item */
    UBaseType_t   uxPriority;                /* 0 = lowest, configMAX_PRIORITIES-1 = highest */
    StackType_t * pxStack;                   /* Pointer to start of stack memory */
    char          pcTaskName[configMAX_TASK_NAME_LEN];

    /* If stack overflow checking is enabled: */
    StackType_t * pxEndOfStack;

    /* If mutexes are enabled (for priority inheritance): */
    UBaseType_t   uxBasePriority;
    UBaseType_t   uxMutexesHeld;

    /* If task notifications are enabled: */
    volatile uint32_t    ulNotifiedValue[configTASK_NOTIFICATION_ARRAY_ENTRIES];
    volatile uint8_t     ucNotifyState[configTASK_NOTIFICATION_ARRAY_ENTRIES];

    /* ... additional fields for tracing, MPU, TLS, etc. */
} tskTCB;
```

Key observations:
- `pxTopOfStack` is always the first field so the port's assembly context-switch code can access it at offset 0 without knowing the full TCB layout.
- Each task has **two** list items — `xStateListItem` links the task into a state list (ready, blocked, suspended), and `xEventListItem` links it into a queue's or semaphore's wait list.
- Priority inheritance for mutexes is tracked via `uxBasePriority` vs. `uxPriority`.

### Global Kernel Variables

```c
/* In tasks.c — critical for understanding the scheduler */

static List_t pxReadyTasksLists[configMAX_PRIORITIES]; /* One list per priority */
static List_t xDelayedTaskList1, xDelayedTaskList2;     /* Two lists to handle tick overflow */
static List_t * volatile pxDelayedTaskList;              /* Points to current delay list */
static List_t * volatile pxOverflowDelayedTaskList;      /* Swapped on tick overflow */
static List_t xPendingReadyList;   /* Tasks unblocked from ISR, moved to ready by scheduler */
static List_t xSuspendedTaskList;
static List_t xTasksWaitingTermination;

static volatile UBaseType_t uxCurrentNumberOfTasks;
static volatile TickType_t  xTickCount;
static volatile UBaseType_t uxTopReadyPriority;   /* Highest priority with a ready task */
static volatile BaseType_t  xSchedulerRunning;
static volatile BaseType_t  xYieldPending;
static volatile BaseType_t  uxSchedulerSuspended; /* Non-zero = scheduler is suspended */

static TCB_t * volatile pxCurrentTCB;              /* Points to the running task's TCB */
```

---

## 3. Task Management

### Task States

```
                    ┌──────────────────────┐
    vTaskCreate()   │                      │ vTaskResume()
   ──────────────>  │       READY          │ <───────────────
                    │  (in ready list)     │                 │
                    └─────────┬────────────┘                 │
                              │ Scheduler picks              │
                              │ highest-priority task        │
                              ▼                              │
                    ┌──────────────────────┐                 │
                    │                      │                 │
                    │      RUNNING         │                 │
                    │ (pxCurrentTCB)       │                 │
                    └──┬───────┬───────┬───┘                 │
                       │       │       │                     │
        vTaskDelay()   │       │       │ vTaskSuspend()      │
        xQueueReceive()│       │       └─────────────────>───┤
        xSemaphoreTake │       │                     ┌───────┴──────┐
                       │       │                     │  SUSPENDED   │
                       ▼       │                     │              │
              ┌────────────┐   │                     └──────────────┘
              │  BLOCKED   │   │ vTaskDelete()
              │ (delay or  │   │
              │  event     │   ▼
              │  wait list)│ ┌──────────────┐
              └────────────┘ │   DELETED    │
                             │  (freed or   │
                             │  in termination list) │
                             └──────────────┘
```

### Task Creation Functions

#### `xTaskCreate()`

```c
BaseType_t xTaskCreate(
    TaskFunction_t       pvTaskCode,    /* Pointer to the task function */
    const char * const   pcName,        /* Human-readable name (for debugging) */
    const configSTACK_DEPTH_TYPE usStackDepth,  /* Stack size in WORDS (not bytes!) */
    void * const         pvParameters,  /* Argument passed to pvTaskCode */
    UBaseType_t          uxPriority,    /* 0 = idle priority, max = configMAX_PRIORITIES-1 */
    TaskHandle_t * const pxCreatedTask  /* Output handle (can be NULL) */
);
/* Returns: pdPASS on success, errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY on failure */
```

**What happens internally:**
1. Allocates memory for the TCB and the task's stack from the FreeRTOS heap (`pvPortMalloc`).
2. Initializes the stack with a "fake" context frame so the task can be started as though it was preempted (the initial PC points to `pvTaskCode`, the initial argument register holds `pvParameters`).
3. Initializes both list items (`xStateListItem`, `xEventListItem`).
4. Adds the task to the appropriate ready list via `prvAddTaskToReadyList()`.
5. If the new task's priority is higher than the currently running task, triggers a context switch.

**Example:**

```c
void vSensorTask(void *pvParameters) {
    uint32_t sensor_id = (uint32_t)pvParameters;
    for (;;) {
        int16_t reading = read_sensor(sensor_id);
        process_reading(reading);
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void main(void) {
    xTaskCreate(vSensorTask, "Sensor", 256, (void *)1, 2, NULL);
    vTaskStartScheduler();
}
```

#### `xTaskCreateStatic()`

```c
TaskHandle_t xTaskCreateStatic(
    TaskFunction_t       pvTaskCode,
    const char * const   pcName,
    const uint32_t       ulStackDepth,
    void * const         pvParameters,
    UBaseType_t          uxPriority,
    StackType_t * const  puxStackBuffer,   /* Caller-provided stack */
    StaticTask_t * const pxTaskBuffer      /* Caller-provided TCB memory */
);
/* Returns: TaskHandle_t (never NULL if both buffers are non-NULL) */
```

Use this when you want zero heap usage. All memory is provided by the caller.

**Example:**

```c
#define TASK_STACK_SIZE  256
static StackType_t  xTaskStack[TASK_STACK_SIZE];
static StaticTask_t xTaskTCB;

void main(void) {
    xTaskCreateStatic(vSensorTask, "Sensor", TASK_STACK_SIZE,
                      NULL, 2, xTaskStack, &xTaskTCB);
    vTaskStartScheduler();
}
```

### Task Control Functions

#### `vTaskDelay()`

```c
void vTaskDelay(const TickType_t xTicksToDelay);
```

Puts the calling task into the Blocked state for `xTicksToDelay` ticks. The task is removed from its ready list, its `xStateListItem.xItemValue` is set to `xTickCount + xTicksToDelay`, and it is inserted (sorted) into `pxDelayedTaskList`. On each tick interrupt, the kernel checks if the head of the delay list should wake up.

**Internal flow:**
1. Enter critical section.
2. Remove task from ready list (`uxListRemove`).
3. Calculate absolute wake time = `xTickCount + xTicksToDelay`.
4. Set `xItemValue` to wake time.
5. If wake time overflows, insert into `pxOverflowDelayedTaskList` instead.
6. Insert sorted (`vListInsert`).
7. Exit critical section.
8. Yield (trigger PendSV).

#### `vTaskDelayUntil()`

```c
BaseType_t xTaskDelayUntil(
    TickType_t * const pxPreviousWakeTime,
    const TickType_t   xTimeIncrement
);
```

Provides **periodic** execution with zero drift. Unlike `vTaskDelay()`, which delays *from the current time*, `xTaskDelayUntil()` delays until an absolute tick count, then advances `pxPreviousWakeTime` by `xTimeIncrement`.

**Example — Precise 50 Hz sampling:**

```c
void vSamplingTask(void *pv) {
    TickType_t xLastWake = xTaskGetTickCount();
    for (;;) {
        sample_adc();
        xTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(20));  /* 50 Hz */
    }
}
```

#### `vTaskPrioritySet()`

```c
void vTaskPrioritySet(TaskHandle_t xTask, UBaseType_t uxNewPriority);
```

Changes a task's priority at runtime. If the target task gains a higher priority than the current task, an immediate yield is triggered. If the target task is blocked on a queue/semaphore, its `xEventListItem` is also updated so it will be unblocked in the correct priority order.

#### `vTaskSuspend()` / `vTaskResume()` / `xTaskResumeFromISR()`

```c
void vTaskSuspend(TaskHandle_t xTaskToSuspend);   /* NULL = suspend self */
void vTaskResume(TaskHandle_t xTaskToResume);
BaseType_t xTaskResumeFromISR(TaskHandle_t xTaskToResume);
```

- `vTaskSuspend` removes the task from its current list and places it in `xSuspendedTaskList`. The task remains suspended indefinitely — it cannot be woken by a timeout.
- `vTaskResume` moves the task from suspended to ready. If its priority is higher than the running task, a yield is triggered.
- `xTaskResumeFromISR` is the ISR-safe version. It returns `pdTRUE` if a context switch should be requested.

#### `vTaskDelete()`

```c
void vTaskDelete(TaskHandle_t xTaskToDelete);  /* NULL = delete self */
```

Removes the task from all lists. If the task was created with `xTaskCreate()` (dynamic allocation), the idle task later frees its TCB and stack memory. If the task was created with `xTaskCreateStatic()`, no memory is freed (the caller manages it).

### Task Query Functions

| Function | Returns |
|---|---|
| `xTaskGetTickCount()` | Current tick count |
| `xTaskGetTickCountFromISR()` | Tick count (ISR-safe) |
| `uxTaskGetStackHighWaterMark(xTask)` | Minimum free stack ever (in words) — use for stack sizing |
| `uxTaskGetNumberOfTasks()` | Total number of tasks |
| `eTaskGetState(xTask)` | State enum: `eRunning`, `eReady`, `eBlocked`, `eSuspended`, `eDeleted` |
| `pcTaskGetName(xTask)` | Task name string |
| `xTaskGetCurrentTaskHandle()` | Handle of the running task |
| `xTaskGetHandle(pcName)` | Find a task by name (expensive — walks all lists) |
| `vTaskGetRunTimeStats(pcWriteBuffer)` | CPU usage per task (needs timer and config) |
| `vTaskList(pcWriteBuffer)` | Formatted list of all tasks with state, priority, stack HWM |

---

## 4. The Scheduler: How It Works Internally

### Starting the Scheduler

```c
void vTaskStartScheduler(void);
```

**Internally this does:**
1. Creates the **idle task** at priority 0 (`prvIdleTask`).
2. If software timers are enabled, creates the **timer daemon task** (`prvTimerTask`).
3. Sets `xSchedulerRunning = pdTRUE`.
4. Calls the port-specific `xPortStartScheduler()`, which:
   - Configures the SysTick timer for the tick rate (`configTICK_RATE_HZ`).
   - Sets PendSV and SysTick interrupt priorities to the lowest level.
   - Starts the first task by triggering SVC (supervisor call).
5. **This function never returns** — the CPU is now running tasks.

### The Tick Interrupt (`xTaskIncrementTick()`)

Every SysTick interrupt calls `xTaskIncrementTick()`. Here is what happens:

```
SysTick_Handler
  └─> xPortSysTickHandler()
        └─> xTaskIncrementTick()
              ├── xTickCount++
              ├── if (xTickCount == 0) swap delay lists (overflow handling)
              ├── while (head of delay list has xItemValue <= xTickCount):
              │     ├── remove task from delay list
              │     ├── remove task from event list (if any)
              │     └── add task to ready list
              ├── if (a same-or-higher priority task is now ready):
              │     └── return pdTRUE → request context switch
              └── check for time-slicing: if another task at current priority is ready:
                    └── return pdTRUE → request context switch
```

If `xTaskIncrementTick()` returns `pdTRUE`, the port pends PendSV for a context switch.

### Context Switching (ARM Cortex-M)

On Cortex-M, context switching uses the **PendSV** exception (lowest priority, so it runs after all other ISRs):

```
PendSV_Handler:
    ; Save context of current task
    MRS     R0, PSP              ; Get current task's stack pointer
    STMDB   R0!, {R4-R11}        ; Push R4-R11 onto task stack
    ; (R0-R3, R12, LR, PC, xPSR were auto-saved by hardware)

    ; Save stack pointer into TCB
    LDR     R1, =pxCurrentTCB
    LDR     R2, [R1]
    STR     R0, [R2]             ; TCB->pxTopOfStack = new SP

    ; Call vTaskSwitchContext to select next task
    BL      vTaskSwitchContext   ; Updates pxCurrentTCB

    ; Restore context of new task
    LDR     R1, =pxCurrentTCB
    LDR     R2, [R1]
    LDR     R0, [R2]             ; R0 = new task's pxTopOfStack
    LDMIA   R0!, {R4-R11}        ; Pop R4-R11 from new task's stack
    MSR     PSP, R0              ; Set PSP to new task's stack
    BX      LR                   ; Return (hardware restores R0-R3, PC, etc.)
```

**`vTaskSwitchContext()`** internally:
1. Checks for stack overflow (if configured).
2. Finds the highest priority ready list that is non-empty. On Cortex-M4, this uses the CLZ (Count Leading Zeros) instruction via `portGET_HIGHEST_PRIORITY()` for O(1) lookup.
3. Gets the next task from that list (round-robin within the same priority via `listGET_OWNER_OF_NEXT_ENTRY`).
4. Sets `pxCurrentTCB` to the selected task.

### Preemptive vs. Cooperative Scheduling

| Config | Behavior |
|---|---|
| `configUSE_PREEMPTION = 1` | Higher-priority tasks preempt lower-priority ones immediately. Tick interrupt can cause context switches. |
| `configUSE_PREEMPTION = 0` | Tasks only switch when they explicitly yield (`taskYIELD()`) or block. |
| `configUSE_TIME_SLICING = 1` (default) | Equal-priority tasks get round-robin time slicing on each tick. |
| `configUSE_TIME_SLICING = 0` | No automatic time slicing — a task runs until it blocks or a higher-priority task becomes ready. |

### Critical Sections

```c
/* Disables interrupts up to configMAX_SYSCALL_INTERRUPT_PRIORITY */
taskENTER_CRITICAL();
/* ... protected code ... */
taskEXIT_CRITICAL();

/* ISR version (saves/restores interrupt state, nesting-safe): */
UBaseType_t uxSavedStatus = taskENTER_CRITICAL_FROM_ISR();
/* ... protected code in ISR ... */
taskEXIT_CRITICAL_FROM_ISR(uxSavedStatus);
```

On Cortex-M, `taskENTER_CRITICAL()` raises the BASEPRI register to `configMAX_SYSCALL_INTERRUPT_PRIORITY`, masking interrupts at and below that level. Interrupts above this level (lower numerical priority) still fire — these are "interrupt-safe" but **must not call FreeRTOS API functions**.

### Scheduler Suspension

```c
vTaskSuspendAll();
/* ... code that must not be preempted, but interrupts still fire ... */
xTaskResumeAll();
```

While the scheduler is suspended:
- Interrupts still fire (unlike critical sections).
- No context switches occur.
- Tasks unblocked by ISRs are placed on `xPendingReadyList` instead of the ready list.
- When `xTaskResumeAll()` is called, pending tasks are moved to ready lists and a yield is triggered if needed.

---

## 5. Queues

Queues are the primary inter-task communication mechanism. Internally, **semaphores, mutexes, and (indirectly) event groups** are all built on the queue structure.

### Queue Internal Structure

```c
typedef struct QueueDefinition {
    int8_t * pcHead;            /* Start of storage area */
    int8_t * pcWriteTo;         /* Next free write position */
    int8_t * pcReadFrom;        /* Last read position */
    int8_t * pcTail;            /* End of storage area + 1 */

    List_t xTasksWaitingToSend;    /* Tasks blocked waiting to write */
    List_t xTasksWaitingToReceive; /* Tasks blocked waiting to read */

    volatile UBaseType_t uxMessagesWaiting; /* Current number of items */
    UBaseType_t uxLength;                   /* Maximum number of items */
    UBaseType_t uxItemSize;                 /* Size of each item in bytes */

    volatile int8_t cRxLock;    /* ISR lock counters */
    volatile int8_t cTxLock;

    /* If mutexes: */
    TaskHandle_t  xMutexHolder;
    UBaseType_t   uxRecursiveCallCount;

    /* ... */
} xQUEUE;
```

The storage area (`pcHead` to `pcTail`) is a circular buffer. Items are copied by value, not by reference — this ensures data integrity without additional synchronization.

### Queue Creation

#### `xQueueCreate()`

```c
QueueHandle_t xQueueCreate(UBaseType_t uxQueueLength, UBaseType_t uxItemSize);
```

Creates a queue that can hold `uxQueueLength` items, each `uxItemSize` bytes. Returns `NULL` if memory allocation fails.

**Internal flow:**
1. Allocates `sizeof(Queue_t) + (uxQueueLength * uxItemSize)` bytes.
2. The queue control structure and storage buffer are contiguous in memory.
3. Initializes both wait lists and the circular buffer pointers.

#### `xQueueCreateStatic()`

```c
QueueHandle_t xQueueCreateStatic(
    UBaseType_t    uxQueueLength,
    UBaseType_t    uxItemSize,
    uint8_t *      pucQueueStorageBuffer,
    StaticQueue_t * pxQueueBuffer
);
```

No heap allocation — caller provides both the queue storage and the control structure.

### Sending to a Queue

#### `xQueueSend()` / `xQueueSendToBack()` / `xQueueSendToFront()`

```c
BaseType_t xQueueSend(
    QueueHandle_t    xQueue,
    const void *     pvItemToQueue,   /* Pointer to item (copied into queue) */
    TickType_t       xTicksToWait     /* Max time to wait if queue is full */
);
/* xQueueSendToBack() is identical to xQueueSend() */
/* xQueueSendToFront() places the item at the front of the queue */
```

**Returns:** `pdPASS` if the item was queued, `errQUEUE_FULL` if the timeout expired.

**Internal flow (xQueueGenericSend):**
1. Enter critical section.
2. If queue has space (`uxMessagesWaiting < uxLength`):
   - Copy data into the buffer at `pcWriteTo` (or `pcReadFrom` for send-to-front).
   - Advance pointer (circular wrap).
   - Increment `uxMessagesWaiting`.
   - If a task is waiting to receive, unblock the highest-priority waiter (move from `xTasksWaitingToReceive` to ready list).
   - If the unblocked task has higher priority, yield.
3. If queue is full:
   - If `xTicksToWait == 0`, return `errQUEUE_FULL` immediately.
   - Add the calling task to `xTasksWaitingToSend` (sorted by priority).
   - Put the task in the Blocked state with the specified timeout.
   - Yield to let other tasks run.
   - When unblocked (by space becoming available or timeout), re-check and either send or return failure.

#### ISR Versions

```c
BaseType_t xQueueSendFromISR(
    QueueHandle_t    xQueue,
    const void *     pvItemToQueue,
    BaseType_t *     pxHigherPriorityTaskWoken  /* Set to pdTRUE if a context switch is needed */
);

BaseType_t xQueueSendToFrontFromISR(QueueHandle_t xQueue, const void *pvItemToQueue,
                                     BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xQueueSendToBackFromISR(QueueHandle_t xQueue, const void *pvItemToQueue,
                                    BaseType_t *pxHigherPriorityTaskWoken);
```

ISR versions **never block**. They use the queue's lock mechanism: if the queue is locked (another task is in the middle of a queue operation), ISR operations are deferred and processed when the queue is unlocked.

### Receiving from a Queue

#### `xQueueReceive()`

```c
BaseType_t xQueueReceive(
    QueueHandle_t xQueue,
    void *        pvBuffer,       /* Where to copy the received item */
    TickType_t    xTicksToWait    /* Max time to wait if queue is empty */
);
```

**Returns:** `pdPASS` on success, `errQUEUE_EMPTY` on timeout.

Internal flow mirrors sending: if data is available, copy and unblock a waiting sender; otherwise block the calling task.

#### `xQueuePeek()`

```c
BaseType_t xQueuePeek(QueueHandle_t xQueue, void *pvBuffer, TickType_t xTicksToWait);
```

Like `xQueueReceive()` but does **not** remove the item. If multiple tasks are peeking, they all see the same item.

#### ISR Versions

```c
BaseType_t xQueueReceiveFromISR(QueueHandle_t xQueue, void *pvBuffer,
                                 BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xQueuePeekFromISR(QueueHandle_t xQueue, void *pvBuffer);
```

### Queue Query Functions

| Function | Returns |
|---|---|
| `uxQueueMessagesWaiting(xQueue)` | Number of items currently in the queue |
| `uxQueueMessagesWaitingFromISR(xQueue)` | Same, ISR-safe |
| `uxQueueSpacesAvailable(xQueue)` | Number of free slots |
| `xQueueIsQueueFullFromISR(xQueue)` | `pdTRUE` if full |
| `xQueueIsQueueEmptyFromISR(xQueue)` | `pdTRUE` if empty |

### Queue Overwrite (for Latest-Value Semantics)

```c
BaseType_t xQueueOverwrite(QueueHandle_t xQueue, const void *pvItemToQueue);
BaseType_t xQueueOverwriteFromISR(QueueHandle_t xQueue, const void *pvItemToQueue,
                                   BaseType_t *pxHigherPriorityTaskWoken);
```

Only for queues of length 1. Always succeeds by overwriting the existing value. Useful for sharing the latest sensor reading or status between tasks.

### Queue Sets

```c
QueueSetHandle_t xQueueCreateSet(const UBaseType_t uxEventQueueLength);
BaseType_t xQueueAddToSet(QueueSetMemberHandle_t xQueueOrSemaphore, QueueSetHandle_t xQueueSet);
BaseType_t xQueueRemoveFromSet(QueueSetMemberHandle_t xQueueOrSemaphore, QueueSetHandle_t xQueueSet);
QueueSetMemberHandle_t xQueueSelectFromSet(QueueSetHandle_t xQueueSet, TickType_t xTicksToWait);
QueueSetMemberHandle_t xQueueSelectFromSetFromISR(QueueSetHandle_t xQueueSet);
```

Queue sets allow a task to block on multiple queues/semaphores simultaneously (similar to `select()` in POSIX). When any member has data, `xQueueSelectFromSet()` returns the handle of that member.

---

## 6. Semaphores

Semaphores are implemented as queues with zero-size items. The "count" is the number of items in the queue.

### Binary Semaphore

```c
SemaphoreHandle_t xSemaphoreCreateBinary(void);
SemaphoreHandle_t xSemaphoreCreateBinaryStatic(StaticSemaphore_t *pxSemaphoreBuffer);
```

A binary semaphore is a queue of length 1, item size 0. It is created **empty** (unlike a mutex which is created "taken"). This makes binary semaphores ideal for ISR-to-task signaling.

**Internal representation:**
- `uxLength = 1`, `uxItemSize = 0`
- "Give" increments `uxMessagesWaiting` from 0 to 1
- "Take" decrements from 1 to 0

**Example — ISR signals a task:**

```c
SemaphoreHandle_t xUartSem;

void USART1_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    clear_uart_interrupt_flag();
    xSemaphoreGiveFromISR(xUartSem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

void vUartTask(void *pv) {
    xUartSem = xSemaphoreCreateBinary();
    for (;;) {
        if (xSemaphoreTake(xUartSem, portMAX_DELAY) == pdTRUE) {
            process_uart_data();
        }
    }
}
```

### Counting Semaphore

```c
SemaphoreHandle_t xSemaphoreCreateCounting(
    UBaseType_t uxMaxCount,      /* Maximum count value */
    UBaseType_t uxInitialCount   /* Initial count value */
);
SemaphoreHandle_t xSemaphoreCreateCountingStatic(
    UBaseType_t uxMaxCount, UBaseType_t uxInitialCount,
    StaticSemaphore_t *pxSemaphoreBuffer
);
```

A counting semaphore is a queue of length `uxMaxCount`, item size 0. Use cases:
- **Event counting:** Count events (ISR gives, task takes). Initial count = 0.
- **Resource management:** Track available resources. Initial count = max resources.

### Semaphore Operations

```c
/* Take (decrement count / wait for signal) */
BaseType_t xSemaphoreTake(SemaphoreHandle_t xSemaphore, TickType_t xTicksToWait);

/* Give (increment count / signal) */
BaseType_t xSemaphoreGive(SemaphoreHandle_t xSemaphore);

/* ISR versions */
BaseType_t xSemaphoreTakeFromISR(SemaphoreHandle_t xSemaphore,
                                  BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xSemaphoreGiveFromISR(SemaphoreHandle_t xSemaphore,
                                  BaseType_t *pxHigherPriorityTaskWoken);

/* Query */
UBaseType_t uxSemaphoreGetCount(SemaphoreHandle_t xSemaphore);
```

All of these are macros that expand to queue operations:
- `xSemaphoreTake()` → `xQueueSemaphoreTake()` (specialized queue receive)
- `xSemaphoreGive()` → `xQueueGenericSend()` with item size 0

---

## 7. Mutexes

Mutexes look like binary semaphores but with **priority inheritance** to prevent priority inversion.

### The Priority Inversion Problem

```
Without priority inheritance:

Time ─────────────────────────────────────────────>
Task H (high):    .........[BLOCKED waiting for mutex]..........
Task M (medium):  ...............[RUNNING - no mutex needed]....
Task L (low):     [TAKES MUTEX]...[preempted by M]..............

Task H is blocked by Task L (which holds the mutex), but Task M preempts
Task L, indirectly and indefinitely delaying Task H. This is PRIORITY INVERSION.
```

### Priority Inheritance

When Task H tries to take a mutex held by Task L, FreeRTOS temporarily raises Task L's priority to match Task H. This prevents Task M from preempting Task L, allowing Task L to finish its critical section and release the mutex.

**Internal mechanism:**
1. `xSemaphoreTake()` on a mutex checks `xMutexHolder`.
2. If the holder's priority is lower than the caller's, the holder's `uxPriority` is raised.
3. When `xSemaphoreGive()` releases the mutex, the holder's priority is restored to `uxBasePriority` (unless the task holds other mutexes that still require elevation).

### Mutex Creation and Usage

```c
SemaphoreHandle_t xSemaphoreCreateMutex(void);
SemaphoreHandle_t xSemaphoreCreateMutexStatic(StaticSemaphore_t *pxMutexBuffer);
```

A mutex is created in the "given" state (count = 1), meaning it is immediately available.

```c
SemaphoreHandle_t xI2CMutex = xSemaphoreCreateMutex();

void vI2CReadTask(void *pv) {
    for (;;) {
        if (xSemaphoreTake(xI2CMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
            i2c_start();
            i2c_read(0x48, buffer, 2);
            i2c_stop();
            xSemaphoreGive(xI2CMutex);
        } else {
            handle_timeout();
        }
    }
}
```

### Recursive Mutex

```c
SemaphoreHandle_t xSemaphoreCreateRecursiveMutex(void);
SemaphoreHandle_t xSemaphoreCreateRecursiveMutexStatic(StaticSemaphore_t *pxMutexBuffer);

BaseType_t xSemaphoreTakeRecursive(SemaphoreHandle_t xMutex, TickType_t xTicksToWait);
BaseType_t xSemaphoreGiveRecursive(SemaphoreHandle_t xMutex);
```

A recursive mutex can be taken multiple times by the **same** task. The internal `uxRecursiveCallCount` tracks nesting depth. The mutex is only released when the count returns to zero.

Use case: Functions that need the mutex and call other functions that also need the same mutex.

### Mutex vs. Binary Semaphore

| Property | Binary Semaphore | Mutex |
|---|---|---|
| Priority inheritance | No | Yes |
| Created state | Empty (0) | Available (1) |
| Ownership | None (any task can give) | Only the holder can give |
| Use case | ISR signaling, event notification | Mutual exclusion of shared resources |
| Can be given from ISR | Yes | **No** (mutexes must not be used in ISRs) |

---

## 8. Event Groups

Event groups provide a way to synchronize tasks using individual bits, allowing tasks to wait for combinations of events.

### Internal Structure

```c
typedef struct EventGroupDef_t {
    EventBits_t uxEventBits;     /* The actual event bits (24 bits usable on 32-bit arch) */
    List_t      xTasksWaitingForBits;  /* Tasks blocked on this event group */
} EventGroup_t;
```

On a 32-bit architecture, 24 bits are available for events (the upper 8 bits are used internally for control flags).

### Creation

```c
EventGroupHandle_t xEventGroupCreate(void);
EventGroupHandle_t xEventGroupCreateStatic(StaticEventGroup_t *pxEventGroupBuffer);
```

### Setting Bits

```c
EventBits_t xEventGroupSetBits(EventGroupHandle_t xEventGroup, const EventBits_t uxBitsToSet);
BaseType_t  xEventGroupSetBitsFromISR(EventGroupHandle_t xEventGroup,
                                       const EventBits_t uxBitsToSet,
                                       BaseType_t *pxHigherPriorityTaskWoken);
```

**Internal flow of `xEventGroupSetBits()`:**
1. Enter critical section.
2. OR the specified bits into `uxEventBits`.
3. Walk the `xTasksWaitingForBits` list:
   - For each waiting task, check if its wait condition is now satisfied.
   - If so, unblock the task and (if the task requested `xClearOnExit`) clear the bits.
4. Exit critical section.
5. If any unblocked task has a higher priority, yield.

`xEventGroupSetBitsFromISR` does NOT execute directly — it sends a command to the timer daemon task, which performs the actual operation. This is because walking the wait list is too complex for ISR context.

### Waiting for Bits

```c
EventBits_t xEventGroupWaitBits(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToWaitFor,   /* Which bits to test */
    const BaseType_t   xClearOnExit,      /* Clear bits when returning? */
    const BaseType_t   xWaitForAllBits,   /* pdTRUE = AND (all bits), pdFALSE = OR (any bit) */
    TickType_t         xTicksToWait
);
```

**Returns** the event bits at the moment the condition was met (or at timeout).

**Example — Wait for sensor + button events:**

```c
#define EVT_SENSOR_READY  (1 << 0)
#define EVT_BUTTON_PRESS  (1 << 1)
#define EVT_TIMER_EXPIRED (1 << 2)

void vDisplayTask(void *pv) {
    EventBits_t bits;
    for (;;) {
        bits = xEventGroupWaitBits(xEvents,
                                   EVT_SENSOR_READY | EVT_BUTTON_PRESS,
                                   pdTRUE,       /* clear on exit */
                                   pdFALSE,      /* OR — any bit wakes us */
                                   portMAX_DELAY);
        if (bits & EVT_SENSOR_READY) update_display_sensor();
        if (bits & EVT_BUTTON_PRESS) update_display_menu();
    }
}
```

### Event Group Synchronization

```c
EventBits_t xEventGroupSync(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToSet,       /* Bits this task sets (its "done" flag) */
    const EventBits_t  uxBitsToWaitFor,   /* Bits to wait for (all tasks' "done" flags) */
    TickType_t         xTicksToWait
);
```

This implements a **barrier** (rendezvous). Each task sets its own bit and waits for all tasks' bits. All bits are atomically cleared when all are set.

**Example — 3-task synchronization barrier:**

```c
#define TASK_0_BIT  (1 << 0)
#define TASK_1_BIT  (1 << 1)
#define TASK_2_BIT  (1 << 2)
#define ALL_SYNC_BITS (TASK_0_BIT | TASK_1_BIT | TASK_2_BIT)

void vTask0(void *pv) {
    for (;;) {
        do_phase1_work();
        xEventGroupSync(xSyncEvents, TASK_0_BIT, ALL_SYNC_BITS, portMAX_DELAY);
        do_phase2_work();
    }
}
```

### Other Event Group Functions

```c
EventBits_t xEventGroupClearBits(EventGroupHandle_t xEventGroup, const EventBits_t uxBitsToClear);
BaseType_t  xEventGroupClearBitsFromISR(EventGroupHandle_t xEventGroup, const EventBits_t uxBitsToClear);
EventBits_t xEventGroupGetBits(EventGroupHandle_t xEventGroup);          /* Macro → xEventGroupClearBits(xEventGroup, 0) */
EventBits_t xEventGroupGetBitsFromISR(EventGroupHandle_t xEventGroup);
void        vEventGroupDelete(EventGroupHandle_t xEventGroup);
```

---

## 9. Software Timers

Software timers execute a callback function at a set time in the future or periodically. They run in the context of the **timer daemon task** (also called the timer service task), not in interrupt context.

### Timer Daemon Architecture

```
                    ┌───────────────────────┐
 Timer API call ──> │  Timer Command Queue  │ ──> Timer Daemon Task
 (xTimerStart, etc) │  (xTimerQueue)        │     (prvTimerTask)
                    └───────────────────────┘     ├── Processes commands
                                                  ├── Checks timer expiry
                                                  └── Calls callback functions
```

All timer API calls send commands to the timer command queue. The timer daemon task processes these commands and manages timer expiry.

**Configuration:**
- `configUSE_TIMERS` — Enable timer support
- `configTIMER_TASK_PRIORITY` — Priority of the daemon task
- `configTIMER_QUEUE_LENGTH` — Command queue length
- `configTIMER_TASK_STACK_DEPTH` — Daemon task stack size

### Timer Creation

```c
TimerHandle_t xTimerCreate(
    const char * const    pcTimerName,
    const TickType_t      xTimerPeriodInTicks,
    const BaseType_t      xAutoReload,   /* pdTRUE = periodic, pdFALSE = one-shot */
    void * const          pvTimerID,     /* User-defined ID (useful for shared callbacks) */
    TimerCallbackFunction_t pxCallbackFunction
);

TimerHandle_t xTimerCreateStatic(
    const char * const pcTimerName,
    const TickType_t   xTimerPeriodInTicks,
    const BaseType_t   xAutoReload,
    void * const       pvTimerID,
    TimerCallbackFunction_t pxCallbackFunction,
    StaticTimer_t *    pxTimerBuffer
);
```

**Callback signature:**

```c
void vTimerCallback(TimerHandle_t xTimer);
```

The callback must **not block** (no `vTaskDelay`, no `xQueueReceive` with a non-zero timeout). It runs in the daemon task context.

### Timer Control Functions

All timer control functions are macros that send commands to the timer command queue:

```c
BaseType_t xTimerStart(TimerHandle_t xTimer, TickType_t xTicksToWait);
BaseType_t xTimerStop(TimerHandle_t xTimer, TickType_t xTicksToWait);
BaseType_t xTimerReset(TimerHandle_t xTimer, TickType_t xTicksToWait);
BaseType_t xTimerChangePeriod(TimerHandle_t xTimer, TickType_t xNewPeriod, TickType_t xTicksToWait);

/* ISR versions */
BaseType_t xTimerStartFromISR(TimerHandle_t xTimer, BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xTimerStopFromISR(TimerHandle_t xTimer, BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xTimerResetFromISR(TimerHandle_t xTimer, BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xTimerChangePeriodFromISR(TimerHandle_t xTimer, TickType_t xNewPeriod,
                                      BaseType_t *pxHigherPriorityTaskWoken);
```

The `xTicksToWait` parameter is how long to wait if the command queue is full (not the timer period).

**`xTimerReset()`** restarts the timer with its original period, counting from now. This is commonly used for inactivity timeouts (reset on every user action).

### Timer Query Functions

```c
BaseType_t     xTimerIsTimerActive(TimerHandle_t xTimer);
void *         pvTimerGetTimerID(TimerHandle_t xTimer);
void           vTimerSetTimerID(TimerHandle_t xTimer, void *pvNewID);
const char *   pcTimerGetName(TimerHandle_t xTimer);
TickType_t     xTimerGetPeriod(TimerHandle_t xTimer);
TickType_t     xTimerGetExpiryTime(TimerHandle_t xTimer);
```

### Example — LED Heartbeat + Inactivity Timeout

```c
TimerHandle_t xHeartbeatTimer, xInactivityTimer;

void vHeartbeatCallback(TimerHandle_t xTimer) {
    toggle_led(LED_GREEN);
}

void vInactivityCallback(TimerHandle_t xTimer) {
    enter_low_power_mode();
}

void main(void) {
    xHeartbeatTimer = xTimerCreate("Heartbeat", pdMS_TO_TICKS(500), pdTRUE, NULL,
                                    vHeartbeatCallback);

    xInactivityTimer = xTimerCreate("Inactivity", pdMS_TO_TICKS(30000), pdFALSE, NULL,
                                     vInactivityCallback);

    xTimerStart(xHeartbeatTimer, 0);
    xTimerStart(xInactivityTimer, 0);

    xTaskCreate(vMainTask, "Main", 256, NULL, 2, NULL);
    vTaskStartScheduler();
}

void on_button_press(void) {
    xTimerResetFromISR(xInactivityTimer, NULL);  /* Restart inactivity countdown */
}
```

---

## 10. Task Notifications

Task notifications are a lightweight, fast alternative to binary semaphores, counting semaphores, event groups, and small mailboxes. Each task has a built-in notification value (a 32-bit integer) and notification state.

### Why Task Notifications?

- **45% faster** than binary semaphores (no queue structure to manage)
- **Zero RAM overhead** — the notification value is already part of the TCB
- Cannot be used to communicate between tasks and ISRs in all patterns (only one task can wait)
- Cannot broadcast to multiple tasks

### Notification State Machine

```
                ┌──────────────┐
  Task created  │  NOT WAITING │ ◄── Notification received when
   ──────────>  │              │     task wasn't waiting → value
                └──────┬───────┘     updated, state = PENDING
                       │
         xTaskNotifyWait() or
         ulTaskNotifyTake()
                       │
                       ▼
                ┌──────────────┐
                │   WAITING    │ ── Notification received →
                │  (blocked)   │    task unblocked, state = NOT WAITING
                └──────────────┘
```

### Sending Notifications

```c
BaseType_t xTaskNotifyGive(TaskHandle_t xTaskToNotify);
void       vTaskNotifyGiveFromISR(TaskHandle_t xTaskToNotify,
                                   BaseType_t *pxHigherPriorityTaskWoken);
```

Increments the target task's notification value (used as a counting semaphore).

```c
BaseType_t xTaskNotify(
    TaskHandle_t xTaskToNotify,
    uint32_t     ulValue,
    eNotifyAction eAction
);
BaseType_t xTaskNotifyFromISR(TaskHandle_t xTaskToNotify, uint32_t ulValue,
                               eNotifyAction eAction, BaseType_t *pxHigherPriorityTaskWoken);
```

**`eNotifyAction` options:**

| Action | Behavior |
|---|---|
| `eNoAction` | Unblock the task without changing its notification value |
| `eSetBits` | OR `ulValue` into the notification value (like event groups) |
| `eIncrement` | Increment the notification value (like counting semaphore) |
| `eSetValueWithOverwrite` | Set the notification value to `ulValue` unconditionally |
| `eSetValueWithoutOverwrite` | Set only if the task has already read the previous value |

### Receiving Notifications

```c
uint32_t ulTaskNotifyTake(
    BaseType_t xClearCountOnExit,  /* pdTRUE = clear to 0, pdFALSE = decrement by 1 */
    TickType_t xTicksToWait
);
```

Used as a fast binary/counting semaphore replacement.

```c
BaseType_t xTaskNotifyWait(
    uint32_t    ulBitsToClearOnEntry,  /* Bits to clear in value BEFORE checking */
    uint32_t    ulBitsToClearOnExit,   /* Bits to clear in value AFTER reading */
    uint32_t *  pulNotificationValue,  /* Output: the notification value */
    TickType_t  xTicksToWait
);
```

Used for event-group-like or mailbox-like patterns.

### Indexed Notifications (FreeRTOS v10.4+)

Each task has an array of notification values (`configTASK_NOTIFICATION_ARRAY_ENTRIES`, default 1). Indexed versions allow using multiple independent notification channels per task:

```c
BaseType_t xTaskNotifyIndexed(TaskHandle_t xTask, UBaseType_t uxIndexToNotify,
                               uint32_t ulValue, eNotifyAction eAction);
BaseType_t xTaskNotifyWaitIndexed(UBaseType_t uxIndexToWaitOn,
                                   uint32_t ulBitsToClearOnEntry,
                                   uint32_t ulBitsToClearOnExit,
                                   uint32_t *pulNotificationValue,
                                   TickType_t xTicksToWait);
uint32_t   ulTaskNotifyTakeIndexed(UBaseType_t uxIndexToWaitOn,
                                    BaseType_t xClearCountOnExit,
                                    TickType_t xTicksToWait);
```

### Example — Task Notification as Binary Semaphore

```c
TaskHandle_t xDMATaskHandle;

void DMA1_Stream0_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    clear_dma_interrupt();
    vTaskNotifyGiveFromISR(xDMATaskHandle, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

void vDMAProcessTask(void *pv) {
    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        process_dma_buffer();
    }
}
```

### Example — Task Notification as Event Group

```c
#define NOTIFY_WIFI_CONNECTED  (1 << 0)
#define NOTIFY_DATA_READY      (1 << 1)
#define NOTIFY_UPLOAD_DONE     (1 << 2)

void vCloudTask(void *pv) {
    uint32_t ulValue;
    for (;;) {
        xTaskNotifyWait(0x00, 0xFFFFFFFF, &ulValue, portMAX_DELAY);
        if (ulValue & NOTIFY_WIFI_CONNECTED) start_mqtt();
        if (ulValue & NOTIFY_DATA_READY)     upload_data();
        if (ulValue & NOTIFY_UPLOAD_DONE)    confirm_upload();
    }
}
```

---

## 11. Stream Buffers and Message Buffers

Stream buffers and message buffers are optimized for **single-writer, single-reader** scenarios (one task or ISR writes, one task reads). They are more efficient than queues for byte-stream communication.

### Stream Buffers

A stream buffer is a circular byte buffer with no message boundaries — data flows as a continuous stream (like a pipe).

```c
StreamBufferHandle_t xStreamBufferCreate(
    size_t  xBufferSizeBytes,       /* Total buffer size */
    size_t  xTriggerLevelBytes      /* Minimum bytes before reader is unblocked */
);

StreamBufferHandle_t xStreamBufferCreateStatic(
    size_t xBufferSizeBytes, size_t xTriggerLevelBytes,
    uint8_t *pucStreamBufferStorageArea, StaticStreamBuffer_t *pxStaticStreamBuffer
);
```

**Trigger level:** The reader is only unblocked when at least `xTriggerLevelBytes` bytes are available. This reduces context switches for high-throughput streams.

```c
size_t xStreamBufferSend(
    StreamBufferHandle_t xStreamBuffer,
    const void *         pvTxData,
    size_t               xDataLengthBytes,
    TickType_t           xTicksToWait
);

size_t xStreamBufferReceive(
    StreamBufferHandle_t xStreamBuffer,
    void *               pvRxData,
    size_t               xBufferLengthBytes,
    TickType_t           xTicksToWait
);

/* ISR versions */
size_t xStreamBufferSendFromISR(StreamBufferHandle_t xStreamBuffer,
                                 const void *pvTxData, size_t xDataLengthBytes,
                                 BaseType_t *pxHigherPriorityTaskWoken);
size_t xStreamBufferReceiveFromISR(StreamBufferHandle_t xStreamBuffer,
                                    void *pvRxData, size_t xBufferLengthBytes,
                                    BaseType_t *pxHigherPriorityTaskWoken);
```

**Query and control:**

```c
size_t    xStreamBufferBytesAvailable(StreamBufferHandle_t xStreamBuffer);
size_t    xStreamBufferSpacesAvailable(StreamBufferHandle_t xStreamBuffer);
BaseType_t xStreamBufferSetTriggerLevel(StreamBufferHandle_t xStreamBuffer, size_t xTriggerLevel);
BaseType_t xStreamBufferReset(StreamBufferHandle_t xStreamBuffer);
BaseType_t xStreamBufferIsEmpty(StreamBufferHandle_t xStreamBuffer);
BaseType_t xStreamBufferIsFull(StreamBufferHandle_t xStreamBuffer);
void       vStreamBufferDelete(StreamBufferHandle_t xStreamBuffer);
```

### Message Buffers

A message buffer is a stream buffer with **length-prefixed messages**. Each write prepends a `size_t` header, so the reader receives discrete messages.

```c
MessageBufferHandle_t xMessageBufferCreate(size_t xBufferSizeBytes);
MessageBufferHandle_t xMessageBufferCreateStatic(size_t xBufferSizeBytes,
                                                  uint8_t *pucBuffer,
                                                  StaticMessageBuffer_t *pxStaticMessageBuffer);

size_t xMessageBufferSend(MessageBufferHandle_t xMessageBuffer,
                           const void *pvTxData, size_t xDataLengthBytes,
                           TickType_t xTicksToWait);
size_t xMessageBufferReceive(MessageBufferHandle_t xMessageBuffer,
                              void *pvRxData, size_t xBufferLengthBytes,
                              TickType_t xTicksToWait);

/* ISR versions */
size_t xMessageBufferSendFromISR(MessageBufferHandle_t xMsgBuf, const void *pvTxData,
                                  size_t xDataLengthBytes, BaseType_t *pxHigherPriorityTaskWoken);
size_t xMessageBufferReceiveFromISR(MessageBufferHandle_t xMsgBuf, void *pvRxData,
                                     size_t xBufferLengthBytes, BaseType_t *pxHigherPriorityTaskWoken);
```

**Important:** Each message requires `sizeof(size_t)` bytes of overhead for the length prefix. A buffer of 100 bytes with `sizeof(size_t) = 4` can hold a single message of at most 96 bytes.

### Example — UART Receive via Stream Buffer

```c
StreamBufferHandle_t xUartStream;

void USART1_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    uint8_t byte = USART1->DR;
    xStreamBufferSendFromISR(xUartStream, &byte, 1, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

void vUartParserTask(void *pv) {
    uint8_t buf[64];
    xUartStream = xStreamBufferCreate(256, 1);
    for (;;) {
        size_t n = xStreamBufferReceive(xUartStream, buf, sizeof(buf), portMAX_DELAY);
        parse_protocol(buf, n);
    }
}
```

### Example — Command Messages via Message Buffer

```c
MessageBufferHandle_t xCmdBuffer;

typedef struct {
    uint8_t  cmd_id;
    uint16_t param;
} Command_t;

void vCommandProducer(void *pv) {
    Command_t cmd = { .cmd_id = CMD_SET_SPEED, .param = 1500 };
    xMessageBufferSend(xCmdBuffer, &cmd, sizeof(cmd), portMAX_DELAY);
}

void vCommandConsumer(void *pv) {
    Command_t cmd;
    for (;;) {
        size_t n = xMessageBufferReceive(xCmdBuffer, &cmd, sizeof(cmd), portMAX_DELAY);
        if (n == sizeof(cmd)) {
            execute_command(&cmd);
        }
    }
}
```

---

## 12. Memory Management

FreeRTOS provides five heap implementations, each a different trade-off between simplicity, fragmentation, and features.

### Heap Implementations

#### heap_1.c — Allocate Only

```
Heap memory:
┌──────┬──────┬──────┬──────────────────────────────┐
│Alloc1│Alloc2│Alloc3│         Free space            │
└──────┴──────┴──────┴──────────────────────────────┘
                      ↑
                  pucAllocatedHeap (never moves backward)
```

- **Algorithm:** Simple bump allocator. `pvPortMalloc()` advances a pointer; `vPortFree()` is a no-op.
- **Fragmentation:** None (no freeing).
- **Use case:** Systems where all tasks, queues, and semaphores are created at startup and never deleted.
- **Deterministic:** Yes — O(1) allocation.

#### heap_2.c — Best-Fit, No Coalescing

```
Free list (linked list of free blocks, sorted by size):
[8 bytes] → [16 bytes] → [32 bytes] → [128 bytes] → NULL
```

- **Algorithm:** Maintains a linked list of free blocks sorted by size. `pvPortMalloc()` finds the smallest block that fits (best-fit). `vPortFree()` inserts the block back into the free list.
- **Fragmentation:** Can fragment over time since adjacent free blocks are not merged.
- **Use case:** Systems that allocate/free blocks of predictable, repeating sizes.
- **Deterministic:** Not guaranteed — list traversal time depends on fragmentation.

#### heap_3.c — Standard Library Wrapper

- **Algorithm:** Wraps `malloc()` and `free()` with a scheduler suspension for thread safety.
- **Heap size:** Determined by the linker, not `configTOTAL_HEAP_SIZE`.
- **Use case:** When you need standard library allocation compatibility.

#### heap_4.c — First-Fit with Coalescing (Recommended)

```
Free list (address-ordered):
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Free block  │ →  │  Free block  │ →  │  Free block  │ → NULL
│  (64 bytes)  │    │  (128 bytes) │    │  (256 bytes) │
└──────────────┘    └──────────────┘    └──────────────┘
                         ↕ adjacent blocks are merged
```

- **Algorithm:** First-fit with coalescing of adjacent free blocks.
- **Fragmentation:** Minimal — adjacent blocks are always merged.
- **Use case:** General-purpose embedded systems. The most commonly used scheme.
- **Deterministic:** Not strictly O(1), but fast in practice.

#### heap_5.c — heap_4 with Non-Contiguous Regions

```c
/* Define memory regions before any allocation */
HeapRegion_t xHeapRegions[] = {
    { (uint8_t *)0x20000000, 0x10000 },  /* 64 KB internal SRAM */
    { (uint8_t *)0x60000000, 0x80000 },  /* 512 KB external SRAM */
    { NULL, 0 }                           /* Terminator */
};

void main(void) {
    vPortDefineHeapRegions(xHeapRegions);  /* MUST be called first */
    /* Now pvPortMalloc() spans all regions */
}
```

- **Use case:** MCUs with multiple RAM banks (internal + external SRAM).

### Memory Management Functions

```c
void * pvPortMalloc(size_t xSize);           /* Allocate memory */
void   vPortFree(void *pv);                  /* Free memory (except heap_1) */
size_t xPortGetFreeHeapSize(void);           /* Current free heap */
size_t xPortGetMinimumEverFreeHeapSize(void); /* Lowest free heap ever (high-water mark) */
void   vPortInitialiseBlocks(void);          /* Reset heap (heap_1 and heap_2 only) */
```

### `pvPortMalloc` Failure Hook

```c
/* FreeRTOSConfig.h */
#define configUSE_MALLOC_FAILED_HOOK  1

/* Application code */
void vApplicationMallocFailedHook(void) {
    /* Log error, reset, or halt */
    taskDISABLE_INTERRUPTS();
    for (;;);
}
```

This hook is called whenever `pvPortMalloc()` returns NULL, providing a centralized place to handle allocation failures.

### Stack Memory

Each task's stack is allocated from the FreeRTOS heap (unless using static allocation). Stack sizes are specified in **words** (4 bytes on 32-bit architectures), not bytes:

```c
xTaskCreate(vTask, "Task", 256, NULL, 2, NULL);  /* 256 words = 1024 bytes on ARM */
```

**Sizing tips:**
- Use `uxTaskGetStackHighWaterMark()` to check minimum free stack during development.
- Account for: local variables, function call depth, ISR pre-emption (if using the same stack — Cortex-M uses MSP for exceptions), and any library functions called.
- Add 20–50% margin over observed high-water marks.

---

## 13. Interrupt Management and Deferred Processing

### FreeRTOS Interrupt Model on Cortex-M

FreeRTOS uses the BASEPRI register to implement "interrupt-safe" critical sections:

```
Interrupt priorities (lower number = higher priority on Cortex-M):

Priority 0   ┐
Priority 1   │  ← Cannot call FreeRTOS API (above BASEPRI mask)
Priority 2   │     Used for ultra-low-latency interrupts
   ...       ┘
─────────────── configMAX_SYSCALL_INTERRUPT_PRIORITY ───────────────
Priority N   ┐
Priority N+1 │  ← CAN call FreeRTOS "FromISR" API functions
   ...       │     Masked during critical sections
Priority 15  ┘
```

**Rules:**
1. ISRs at or below `configMAX_SYSCALL_INTERRUPT_PRIORITY` (numerically ≥) can call `...FromISR()` functions.
2. ISRs above this level (numerically <) **must not** call any FreeRTOS functions. They are never masked and provide the lowest latency.
3. All FreeRTOS ISR-safe functions end with `FromISR` and take a `pxHigherPriorityTaskWoken` parameter.

### The `portYIELD_FROM_ISR()` Pattern

```c
void SomePeripheral_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Do ISR work, call FromISR functions */
    xQueueSendFromISR(xQueue, &data, &xHigherPriorityTaskWoken);
    xSemaphoreGiveFromISR(xSem, &xHigherPriorityTaskWoken);

    /* Request context switch if a higher-priority task was unblocked */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}
```

`portYIELD_FROM_ISR()` pends PendSV if `xHigherPriorityTaskWoken == pdTRUE`. PendSV runs at the lowest interrupt priority, so it fires after all ISRs complete, performing the context switch.

### Deferred Interrupt Processing Pattern

Instead of doing heavy processing in an ISR, defer it to a task:

```c
/* ISR: minimal work, signal the task */
void ADC_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    uint16_t sample = ADC1->DR;
    xQueueSendFromISR(xADCQueue, &sample, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

/* Task: heavy processing at task priority */
void vADCProcessTask(void *pv) {
    uint16_t sample;
    for (;;) {
        xQueueReceive(xADCQueue, &sample, portMAX_DELAY);
        float voltage = sample * 3.3f / 4095.0f;
        apply_filter(&voltage);
        update_pid_controller(voltage);
    }
}
```

### Centralized Deferred Interrupt Handling (Timer Daemon)

For simple deferred ISR processing without creating a dedicated task, use `xTimerPendFunctionCallFromISR()`:

```c
void vDeferredHandler(void *pvParameter1, uint32_t ulParameter2) {
    /* Runs in timer daemon task context */
    process_event((EventType)pvParameter1, ulParameter2);
}

void GPIO_EXTI_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    uint32_t pin = read_exti_pending();
    xTimerPendFunctionCallFromISR(vDeferredHandler, (void *)EVT_BUTTON, pin, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}
```

---

## 14. Tick Hook, Idle Hook, and Stack Overflow Detection

### Tick Hook

```c
/* FreeRTOSConfig.h */
#define configUSE_TICK_HOOK  1

/* Application */
void vApplicationTickHook(void) {
    /* Called from the tick ISR — keep it SHORT */
    watchdog_reload();
    static uint32_t count = 0;
    if (++count >= 1000) {
        count = 0;
        toggle_heartbeat_led();
    }
}
```

Runs in ISR context on every tick. Use only for very fast operations.

### Idle Hook

```c
/* FreeRTOSConfig.h */
#define configUSE_IDLE_HOOK  1

/* Application */
void vApplicationIdleHook(void) {
    /* Called repeatedly when no other task is ready */
    __WFI();  /* Enter sleep until next interrupt (ARM Wait For Interrupt) */
}
```

**Rules:**
- Must never block or suspend.
- Ideal for entering low-power sleep modes.
- Runs at priority 0 (idle task priority).

### Stack Overflow Detection

```c
/* FreeRTOSConfig.h */
#define configCHECK_FOR_STACK_OVERFLOW  2  /* 1 = basic, 2 = enhanced */

/* Application */
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    /* Stack overflow detected! Log and halt. */
    printf("STACK OVERFLOW: %s\n", pcTaskName);
    taskDISABLE_INTERRUPTS();
    for (;;);
}
```

**Method 1** (`configCHECK_FOR_STACK_OVERFLOW = 1`): Checks if the stack pointer has gone past the end of the stack on each context switch.

**Method 2** (`configCHECK_FOR_STACK_OVERFLOW = 2`): Fills the last 20 bytes of the stack with a known pattern (0xA5A5A5A5) at creation. Checks if the pattern is intact on each context switch. This catches overflows that occurred between context switches.

Both methods add overhead but are invaluable during development.

---

## 15. FreeRTOSConfig.h — Kernel Configuration Reference

`FreeRTOSConfig.h` is a per-project header that tailors the kernel to your application. Every project must provide one.

### Essential Configuration

```c
/* Scheduler */
#define configUSE_PREEMPTION                     1    /* 1 = preemptive, 0 = cooperative */
#define configUSE_TIME_SLICING                   1    /* Round-robin among equal-priority tasks */
#define configUSE_PORT_OPTIMISED_TASK_SELECTION  1    /* Use CLZ for O(1) priority selection (Cortex-M) */
#define configMAX_PRIORITIES                     8    /* Max number of task priorities (0..7) */

/* Clock */
#define configCPU_CLOCK_HZ                       168000000  /* CPU frequency */
#define configTICK_RATE_HZ                       1000       /* Tick rate (1 kHz = 1 ms resolution) */

/* Memory */
#define configMINIMAL_STACK_SIZE                 128   /* Idle task stack size (words) */
#define configTOTAL_HEAP_SIZE                    (32 * 1024)  /* FreeRTOS heap (bytes) */
#define configSUPPORT_STATIC_ALLOCATION          1    /* Enable xTaskCreateStatic, etc. */
#define configSUPPORT_DYNAMIC_ALLOCATION         1    /* Enable xTaskCreate, etc. */

/* Features */
#define configUSE_MUTEXES                        1
#define configUSE_RECURSIVE_MUTEXES              1
#define configUSE_COUNTING_SEMAPHORES            1
#define configUSE_QUEUE_SETS                     0
#define configUSE_TASK_NOTIFICATIONS             1
#define configTASK_NOTIFICATION_ARRAY_ENTRIES    1    /* Number of notification slots per task */

/* Software Timers */
#define configUSE_TIMERS                         1
#define configTIMER_TASK_PRIORITY                 (configMAX_PRIORITIES - 1)
#define configTIMER_QUEUE_LENGTH                  10
#define configTIMER_TASK_STACK_DEPTH              256

/* Hooks */
#define configUSE_IDLE_HOOK                      1
#define configUSE_TICK_HOOK                       0
#define configUSE_MALLOC_FAILED_HOOK             1
#define configCHECK_FOR_STACK_OVERFLOW           2

/* Debug / Stats */
#define configUSE_TRACE_FACILITY                 1   /* Enables vTaskList, vTaskGetRunTimeStats */
#define configGENERATE_RUN_TIME_STATS            0
#define configUSE_STATS_FORMATTING_FUNCTIONS     1
#define configMAX_TASK_NAME_LEN                  16

/* Interrupt nesting (Cortex-M specific) */
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY        15
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY   5
#define configKERNEL_INTERRUPT_PRIORITY         (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << 4)
#define configMAX_SYSCALL_INTERRUPT_PRIORITY    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << 4)
```

### Optional Includes (API Enable/Disable)

```c
#define INCLUDE_vTaskPrioritySet             1
#define INCLUDE_uxTaskPriorityGet            1
#define INCLUDE_vTaskDelete                  1
#define INCLUDE_vTaskSuspend                 1
#define INCLUDE_vTaskDelayUntil              1
#define INCLUDE_vTaskDelay                   1
#define INCLUDE_xTaskGetSchedulerState       1
#define INCLUDE_xTaskGetCurrentTaskHandle    1
#define INCLUDE_uxTaskGetStackHighWaterMark  1
#define INCLUDE_xTimerPendFunctionCall       1
#define INCLUDE_eTaskGetState                1
#define INCLUDE_xTaskAbortDelay              1
#define INCLUDE_xTaskGetHandle               1
```

Setting unused `INCLUDE_` macros to 0 reduces code size by excluding those functions from the build.

---

## 16. Common Pitfalls and Debugging

### Pitfall 1: Using Non-FromISR Functions in ISRs

```c
/* WRONG — will corrupt internal data structures or hard fault */
void USART1_IRQHandler(void) {
    xQueueSend(xQueue, &data, portMAX_DELAY);  /* NEVER block in an ISR! */
}

/* CORRECT */
void USART1_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    xQueueSendFromISR(xQueue, &data, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}
```

### Pitfall 2: Wrong Interrupt Priorities

On Cortex-M, lower numerical priority = higher urgency. FreeRTOS API calls are only safe from interrupts with priority ≥ `configMAX_SYSCALL_INTERRUPT_PRIORITY`.

```c
/* WRONG — priority 2 is ABOVE configMAX_SYSCALL_INTERRUPT_PRIORITY (5) */
NVIC_SetPriority(USART1_IRQn, 2);

/* CORRECT — priority 6 is within FreeRTOS-managed range */
NVIC_SetPriority(USART1_IRQn, 6);
```

### Pitfall 3: Stack Overflow

Symptoms: random crashes, corrupted data, hard faults. Prevention:

```c
#define configCHECK_FOR_STACK_OVERFLOW  2

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    printf("Stack overflow in: %s\n", pcTaskName);
    for (;;);
}

/* During development, check high-water marks: */
void vMonitorTask(void *pv) {
    for (;;) {
        UBaseType_t hwm = uxTaskGetStackHighWaterMark(xSensorTaskHandle);
        printf("Sensor stack free: %u words\n", hwm);
        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}
```

### Pitfall 4: Priority Inversion Without Mutex

```c
/* Using a binary semaphore for mutual exclusion — NO priority inheritance! */
SemaphoreHandle_t xProtect = xSemaphoreCreateBinary();
xSemaphoreGive(xProtect);

/* Use a MUTEX instead for mutual exclusion: */
SemaphoreHandle_t xProtect = xSemaphoreCreateMutex();
```

### Pitfall 5: Deadlock

Two tasks each hold one resource and wait for the other:

```c
/* Task A */                    /* Task B */
xSemaphoreTake(xMutex1, ...);  xSemaphoreTake(xMutex2, ...);
xSemaphoreTake(xMutex2, ...);  xSemaphoreTake(xMutex1, ...);  /* DEADLOCK! */
```

**Prevention:** Always acquire mutexes in the same global order. Or use a timeout and handle failure.

### Pitfall 6: Forgetting `portYIELD_FROM_ISR()`

```c
/* ISR unblocks a high-priority task but doesn't yield */
void EXTI_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    xSemaphoreGiveFromISR(xSem, &xWoken);
    /* Missing: portYIELD_FROM_ISR(xWoken);
     * The high-priority task won't run until the next tick!
     * Response time = up to 1 ms instead of ~microseconds */
}
```

### Debugging Tools

| Tool | Purpose |
|---|---|
| `vTaskList()` | Print all tasks with state, priority, stack HWM |
| `vTaskGetRunTimeStats()` | CPU usage per task |
| `uxTaskGetStackHighWaterMark()` | Check stack margin |
| `configASSERT(x)` | Assert macro — define to trigger breakpoint/halt |
| Tracealyzer | Commercial visual RTOS trace tool |
| SystemView (SEGGER) | Free timeline visualization |

**Defining `configASSERT`:**

```c
#define configASSERT(x)  if (!(x)) { taskDISABLE_INTERRUPTS(); for(;;); }
```

FreeRTOS internally calls `configASSERT()` to catch API misuse (wrong parameters, ISR/task function mismatch, etc.). Always define it during development.

---

## 17. Design Patterns and Best Practices

### Pattern 1: Producer-Consumer with Queue

```
┌──────────┐    Queue     ┌──────────┐
│ Sensor   │ ──────────>  │ Process  │
│ Task     │  (N items)   │ Task     │
└──────────┘              └──────────┘
```

The sensor task samples data and sends it to a queue. The processing task receives items and processes them. The queue decouples timing — the producer can burst faster than the consumer can process, with buffering.

### Pattern 2: Gateway Task (Serializing Access)

Instead of using a mutex to protect a peripheral, create a single task that "owns" the peripheral:

```
Task A ──┐                   ┌──────────┐
         ├── Queue ────────> │ I2C      │ ──> I2C Bus
Task B ──┘                   │ Gateway  │
                             │ Task     │
Task C ── Notification ───>  └──────────┘
```

Benefits:
- No mutex contention or priority inversion.
- The gateway task handles all bus timing, error recovery, and sequencing.
- Other tasks send requests via a queue and receive results via direct task notifications.

### Pattern 3: Watchdog Task

```c
void vWatchdogTask(void *pv) {
    for (;;) {
        EventBits_t bits = xEventGroupWaitBits(xAliveEvents, ALL_TASKS_ALIVE,
                                                pdTRUE, pdTRUE, pdMS_TO_TICKS(5000));
        if (bits == ALL_TASKS_ALIVE) {
            hardware_watchdog_reload();
        } else {
            log_fault(bits);
            system_reset();
        }
    }
}

/* Each monitored task periodically sets its bit: */
void vSensorTask(void *pv) {
    for (;;) {
        do_work();
        xEventGroupSetBits(xAliveEvents, SENSOR_ALIVE_BIT);
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
```

### Pattern 4: Double-Buffer with Notification

```c
static uint16_t adc_buf[2][256];
static volatile uint8_t active_buf = 0;

void DMA_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    active_buf ^= 1;
    setup_dma(adc_buf[active_buf], 256);
    vTaskNotifyGiveFromISR(xProcessTask, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

void vProcessTask(void *pv) {
    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        uint8_t process_buf = active_buf ^ 1;  /* Process the completed buffer */
        fft_compute(adc_buf[process_buf], 256);
    }
}
```

### Best Practices Summary

| Practice | Rationale |
|---|---|
| Use `configASSERT()` during development | Catches API misuse immediately |
| Minimize ISR execution time | Defer work to tasks via semaphores/queues |
| Use mutexes (not binary semaphores) for mutual exclusion | Priority inheritance prevents inversion |
| Prefer task notifications over semaphores when possible | 45% faster, zero RAM overhead |
| Size stacks generously, then tune with HWM checks | Prevents silent corruption |
| Use `vTaskDelayUntil()` for periodic tasks | Zero drift over time |
| Assign unique priorities unless round-robin is intended | Reduces scheduling complexity |
| Create all kernel objects at startup | Avoids runtime allocation failures |
| Use static allocation (`xTaskCreateStatic`, etc.) in safety-critical systems | Deterministic, no heap fragmentation |
| Acquire multiple mutexes in a consistent global order | Prevents deadlock |

---

## 18. Example Summary

The `freertos-examples/` directory contains complete, annotated source files demonstrating each FreeRTOS concept:

| File | Description | Key Concepts |
|---|---|---|
| [`01_basic_tasks.c`](freertos-examples/01_basic_tasks.c) | Task creation, priorities, and scheduling | `xTaskCreate`, `vTaskDelay`, `vTaskDelayUntil`, preemption |
| [`02_queues.c`](freertos-examples/02_queues.c) | Queue-based inter-task communication | `xQueueCreate`, send/receive, overwrite, queue sets |
| [`03_semaphores_mutexes.c`](freertos-examples/03_semaphores_mutexes.c) | Binary/counting semaphores and mutexes | ISR signaling, resource counting, priority inheritance |
| [`04_event_groups.c`](freertos-examples/04_event_groups.c) | Event-driven synchronization | Bit flags, wait for any/all, sync barrier |
| [`05_software_timers.c`](freertos-examples/05_software_timers.c) | Periodic and one-shot timers | Timer daemon, callbacks, timer ID |
| [`06_task_notifications.c`](freertos-examples/06_task_notifications.c) | Lightweight task notifications | Binary sem replacement, event bits, mailbox |
| [`07_memory_management.c`](freertos-examples/07_memory_management.c) | Heap usage and stack monitoring | `pvPortMalloc`, heap stats, stack high-water mark |
| [`08_isr_deferred.c`](freertos-examples/08_isr_deferred.c) | Interrupt handling and deferred processing | `FromISR` functions, `portYIELD_FROM_ISR`, `xTimerPendFunctionCall` |
| [`09_stream_message_buffers.c`](freertos-examples/09_stream_message_buffers.c) | Stream and message buffer communication | UART stream, command messages, trigger levels |
| [`10_realworld_application.c`](freertos-examples/10_realworld_application.c) | Complete IoT sensor node application | Multi-task architecture, all primitives combined |

---

## Appendix A: Quick API Reference Card

### Task API

| Function | Context | Description |
|---|---|---|
| `xTaskCreate()` | Task | Create a task (dynamic) |
| `xTaskCreateStatic()` | Task | Create a task (static) |
| `vTaskDelete()` | Task | Delete a task |
| `vTaskDelay()` | Task | Block for N ticks |
| `xTaskDelayUntil()` | Task | Block until absolute tick |
| `vTaskPrioritySet()` | Task | Change priority |
| `uxTaskPriorityGet()` | Task | Get priority |
| `vTaskSuspend()` | Task/ISR | Suspend a task |
| `vTaskResume()` | Task | Resume a task |
| `xTaskResumeFromISR()` | ISR | Resume a task from ISR |
| `taskYIELD()` | Task | Yield to same-priority task |
| `xTaskGetTickCount()` | Task | Get tick count |
| `xTaskGetTickCountFromISR()` | ISR | Get tick count from ISR |
| `uxTaskGetStackHighWaterMark()` | Task | Min free stack (words) |
| `vTaskStartScheduler()` | — | Start the kernel |

### Queue API

| Function | Context | Description |
|---|---|---|
| `xQueueCreate()` | Task | Create a queue |
| `xQueueSend()` | Task | Send to back |
| `xQueueSendToFront()` | Task | Send to front |
| `xQueueReceive()` | Task | Receive (remove) |
| `xQueuePeek()` | Task | Read without removing |
| `xQueueOverwrite()` | Task | Overwrite (length-1 queue) |
| `xQueueSendFromISR()` | ISR | Send from ISR |
| `xQueueReceiveFromISR()` | ISR | Receive from ISR |
| `uxQueueMessagesWaiting()` | Task/ISR | Items in queue |

### Semaphore / Mutex API

| Function | Context | Description |
|---|---|---|
| `xSemaphoreCreateBinary()` | Task | Binary semaphore |
| `xSemaphoreCreateCounting()` | Task | Counting semaphore |
| `xSemaphoreCreateMutex()` | Task | Mutex (with priority inheritance) |
| `xSemaphoreCreateRecursiveMutex()` | Task | Recursive mutex |
| `xSemaphoreTake()` | Task | Acquire |
| `xSemaphoreGive()` | Task | Release |
| `xSemaphoreTakeFromISR()` | ISR | Acquire from ISR |
| `xSemaphoreGiveFromISR()` | ISR | Release from ISR |

### Event Group API

| Function | Context | Description |
|---|---|---|
| `xEventGroupCreate()` | Task | Create event group |
| `xEventGroupSetBits()` | Task | Set bits |
| `xEventGroupSetBitsFromISR()` | ISR | Set bits from ISR |
| `xEventGroupWaitBits()` | Task | Wait for bits |
| `xEventGroupClearBits()` | Task | Clear bits |
| `xEventGroupSync()` | Task | Barrier synchronization |

### Timer API

| Function | Context | Description |
|---|---|---|
| `xTimerCreate()` | Task | Create timer |
| `xTimerStart()` | Task | Start timer |
| `xTimerStop()` | Task | Stop timer |
| `xTimerReset()` | Task | Restart timer period |
| `xTimerChangePeriod()` | Task | Change timer period |
| `xTimerStartFromISR()` | ISR | Start from ISR |

### Notification API

| Function | Context | Description |
|---|---|---|
| `xTaskNotifyGive()` | Task | Increment notification value |
| `vTaskNotifyGiveFromISR()` | ISR | Increment from ISR |
| `ulTaskNotifyTake()` | Task | Wait (counting sem style) |
| `xTaskNotify()` | Task | Send with action |
| `xTaskNotifyFromISR()` | ISR | Send with action from ISR |
| `xTaskNotifyWait()` | Task | Wait (event group style) |

### Stream/Message Buffer API

| Function | Context | Description |
|---|---|---|
| `xStreamBufferCreate()` | Task | Create stream buffer |
| `xStreamBufferSend()` | Task | Write bytes |
| `xStreamBufferReceive()` | Task | Read bytes |
| `xStreamBufferSendFromISR()` | ISR | Write from ISR |
| `xMessageBufferCreate()` | Task | Create message buffer |
| `xMessageBufferSend()` | Task | Send discrete message |
| `xMessageBufferReceive()` | Task | Receive discrete message |

---

*This guide covers FreeRTOS kernel v10.5+. For the latest API additions, consult the [official FreeRTOS documentation](https://www.freertos.org/Documentation/RTOS_book.html).*
