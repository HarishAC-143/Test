# FreeRTOS Comprehensive Guide: Architecture, Internals, and Practical Examples

A deep-dive tutorial covering FreeRTOS from foundational concepts through kernel internals, with detailed API references and production-ready code examples targeting ARM Cortex-M microcontrollers.

---

## Table of Contents

1. [Introduction to FreeRTOS](#1-introduction-to-freertos)
2. [Architecture and Kernel Internals](#2-architecture-and-kernel-internals)
3. [Task Management](#3-task-management)
4. [The FreeRTOS Scheduler](#4-the-freertos-scheduler)
5. [Queues](#5-queues)
6. [Semaphores](#6-semaphores)
7. [Mutexes](#7-mutexes)
8. [Event Groups](#8-event-groups)
9. [Software Timers](#9-software-timers)
10. [Task Notifications](#10-task-notifications)
11. [Stream Buffers and Message Buffers](#11-stream-buffers-and-message-buffers)
12. [Memory Management](#12-memory-management)
13. [Interrupt Management](#13-interrupt-management)
14. [Low-Power Support (Tickless Idle)](#14-low-power-support-tickless-idle)
15. [Debugging, Tracing, and Best Practices](#15-debugging-tracing-and-best-practices)
16. [FreeRTOS Configuration Reference](#16-freertos-configuration-reference)
17. [Common Pitfalls and How to Avoid Them](#17-common-pitfalls-and-how-to-avoid-them)

---

## 1. Introduction to FreeRTOS

FreeRTOS is a real-time operating system kernel for embedded devices. It is one of the most widely deployed RTOS kernels in the world, running on over 40 microcontroller architectures. Originally developed by Richard Barry in 2003, it is now maintained by Amazon Web Services (AWS) under the MIT open-source license.

### 1.1 Why Use an RTOS?

Bare-metal firmware (a single `while(1)` super-loop) works well for simple systems, but breaks down when:

| Challenge | Bare-Metal Approach | RTOS Approach |
|---|---|---|
| Multiple concurrent activities | Manual state machines, flag polling | Independent tasks with preemptive scheduling |
| Timing guarantees | Fragile delay loops, timer callbacks | Priority-based preemption with bounded latency |
| Resource sharing | Global flags, disable/enable interrupts | Mutexes, semaphores with priority inheritance |
| Modularity | Tightly coupled code in one loop | Isolated tasks with message-passing |
| Power management | Manual sleep/wake logic | Built-in tickless idle mode |
| Code maintainability | Grows unwieldy beyond ~5 activities | Each task is self-contained |

### 1.2 Key Features of FreeRTOS

- **Preemptive, cooperative, or hybrid scheduling** — configurable per application
- **Unlimited tasks** (limited only by available RAM)
- **Queues, semaphores, mutexes, event groups, task notifications** — full IPC suite
- **Software timers** — periodic and one-shot, managed by a dedicated daemon task
- **Memory management** — five heap implementations (heap_1 through heap_5)
- **Tickless idle** — for ultra-low-power applications
- **Stack overflow detection** — two configurable methods
- **Trace hooks** — integration with tools like Tracealyzer, SystemView
- **Tiny footprint** — kernel compiles to ~6–10 KB of Flash, ~0.5 KB of RAM

### 1.3 FreeRTOS Source Tree

```
FreeRTOS/
├── Source/
│   ├── tasks.c              ← Task creation, scheduling, context switch
│   ├── queue.c              ← Queues, semaphores, mutexes
│   ├── list.c               ← Doubly-linked list used by all kernel objects
│   ├── timers.c             ← Software timer service
│   ├── event_groups.c       ← Event group management
│   ├── stream_buffer.c      ← Stream and message buffers
│   ├── croutine.c           ← Co-routines (legacy, rarely used)
│   ├── include/
│   │   ├── FreeRTOS.h       ← Master header, pulls in FreeRTOSConfig.h
│   │   ├── task.h           ← Task API prototypes
│   │   ├── queue.h          ← Queue API prototypes
│   │   ├── semphr.h         ← Semaphore/mutex macros (wrappers around queue.h)
│   │   ├── event_groups.h   ← Event group API
│   │   ├── timers.h         ← Software timer API
│   │   ├── stream_buffer.h  ← Stream/message buffer API
│   │   └── ...
│   └── portable/
│       ├── GCC/ARM_CM4F/    ← Port layer for Cortex-M4F with GCC
│       │   ├── port.c       ← SysTick, PendSV, SVC handlers
│       │   └── portmacro.h  ← Port-specific types and macros
│       └── MemMang/
│           ├── heap_1.c     ← Allocate only, never free
│           ├── heap_2.c     ← Best-fit, no coalescing
│           ├── heap_3.c     ← Wraps standard malloc/free
│           ├── heap_4.c     ← First-fit with coalescing (recommended)
│           └── heap_5.c     ← heap_4 across multiple memory regions
└── FreeRTOSConfig.h         ← User configuration (in project directory)
```

### 1.4 Minimum "Hello World"

```c
#include "FreeRTOS.h"
#include "task.h"

void vHelloTask(void *pvParameters)
{
    const char *name = (const char *)pvParameters;

    for (;;) {
        printf("Hello from %s\r\n", name);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

int main(void)
{
    HAL_Init();
    SystemClock_Config();

    xTaskCreate(vHelloTask, "Hello", 256, "Task1", 2, NULL);

    vTaskStartScheduler();

    for (;;); /* Should never reach here */
}
```

---

## 2. Architecture and Kernel Internals

Understanding how FreeRTOS works internally is essential for writing robust real-time applications and debugging subtle timing issues.

### 2.1 The Kernel Data Structures

#### 2.1.1 The List (`list.c`)

Every kernel object in FreeRTOS is managed via doubly-linked lists defined in `list.c`. These are the foundation of the scheduler.

```c
/* Simplified internal structures */
struct xLIST_ITEM {
    TickType_t      xItemValue;     /* Sort key (e.g., wake time) */
    struct xLIST_ITEM *pxNext;
    struct xLIST_ITEM *pxPrevious;
    void            *pvOwner;       /* Pointer to the TCB that owns this item */
    struct xLIST    *pvContainer;   /* The list this item belongs to */
};

struct xLIST {
    UBaseType_t     uxNumberOfItems;
    ListItem_t      *pxIndex;       /* Current traversal position */
    MiniListItem_t  xListEnd;       /* Sentinel node (value = max) */
};
```

**Key list operations:**

| Function | Description | Time Complexity |
|---|---|---|
| `vListInitialise()` | Initialize an empty list; set sentinel value to `portMAX_DELAY` | O(1) |
| `vListInitialiseItem()` | Set a list item's container to NULL | O(1) |
| `vListInsertEnd()` | Insert item at the current index position (FIFO for same-priority tasks) | O(1) |
| `vListInsert()` | Insert item sorted by `xItemValue` (ascending) | O(n) |
| `uxListRemove()` | Unlink item from its list, return remaining count | O(1) |

The lists are sorted by `xItemValue`. For the ready lists, this value is not used for ordering (items are inserted at the end via `vListInsertEnd`). For the delayed task list, `xItemValue` holds the absolute tick count at which the task should wake — this makes the tick interrupt handler O(1) because it only needs to check the head of the list.

#### 2.1.2 The Task Control Block (TCB)

Every task is represented by a TCB, an internal structure that stores all per-task state:

```c
typedef struct tskTaskControlBlock {
    volatile StackType_t *pxTopOfStack;    /* MUST be first field — used by port asm */

    ListItem_t           xStateListItem;   /* In ready/blocked/suspended list */
    ListItem_t           xEventListItem;   /* In queue/semaphore/event wait list */
    UBaseType_t          uxPriority;        /* 0 = lowest, configMAX_PRIORITIES-1 = highest */
    StackType_t          *pxStack;          /* Start of allocated stack memory */
    char                 pcTaskName[configMAX_TASK_NAME_LEN];

    /* Optional fields based on config: */
    UBaseType_t          uxBasePriority;    /* For priority inheritance (mutexes) */
    UBaseType_t          uxMutexesHeld;     /* Count of mutexes held */
    uint32_t             ulNotifiedValue;   /* Task notification value */
    uint8_t              ucNotifyState;     /* notWAITING / WAITING / NOTIFIED */
    StackType_t          *pxEndOfStack;     /* Stack overflow detection */
    /* ... runtime stats, trace hooks, TLS pointers ... */
} tskTCB;
```

The `pxTopOfStack` field is always the first member so the context-switch assembly code (in `port.c`) can locate it with a zero offset from the TCB pointer.

#### 2.1.3 Scheduler State Variables

The scheduler maintains several critical global variables:

```c
/* Array of ready lists, one per priority level */
static List_t pxReadyTasksLists[configMAX_PRIORITIES];

/* Two delayed-task lists — swapped on tick counter overflow */
static List_t xDelayedTaskList1;
static List_t xDelayedTaskList2;
static List_t *volatile pxDelayedTaskList;
static List_t *volatile pxOverflowDelayedTaskList;

/* Tasks waiting to be deleted (cleaned up by idle task) */
static List_t xTasksWaitingTermination;

/* Suspended tasks */
static List_t xSuspendedTaskList;

/* The currently running TCB */
volatile TCB_t *volatile pxCurrentTCB;

/* Global tick count */
static volatile TickType_t xTickCount;

/* Highest priority with a ready task — optimizes task selection */
static volatile UBaseType_t uxTopReadyPriority;

/* Scheduler state */
static volatile BaseType_t xSchedulerRunning;
static volatile UBaseType_t uxSchedulerSuspended; /* Nesting count */
```

### 2.2 Context Switching on Cortex-M

On ARM Cortex-M, FreeRTOS uses two system exceptions for context switching:

1. **SVC (Supervisor Call)** — used once to start the first task
2. **PendSV (Pendable Service Call)** — used for all subsequent context switches

Both run at the lowest possible interrupt priority so they never preempt application ISRs.

```
┌─────────────┐
│  SysTick ISR │ ← Increments tick, checks for task wake-ups
│  (highest    │    Pends PendSV if context switch needed
│   kernel     │
│   priority)  │
└──────┬───────┘
       │ Sets PendSV pending bit
       ▼
┌─────────────┐
│  PendSV ISR  │ ← Runs at lowest priority
│  (context    │    Saves current context → selects highest-ready → restores
│   switch)    │
└─────────────┘
```

**PendSV handler (simplified Cortex-M4F):**

```asm
PendSV_Handler:
    /* Save current context */
    mrs     r0, psp                 /* Get Process Stack Pointer */
    stmdb   r0!, {r4-r11, r14}     /* Push R4-R11 and EXC_RETURN onto task stack */
    vstmdb  r0!, {s16-s31}         /* Push FPU registers (if FPU used) */

    /* Save stack pointer in current TCB */
    ldr     r2, =pxCurrentTCB
    ldr     r1, [r2]
    str     r0, [r1]               /* TCB->pxTopOfStack = new SP */

    /* Call vTaskSwitchContext() to select next task */
    bl      vTaskSwitchContext      /* Updates pxCurrentTCB */

    /* Restore context of new task */
    ldr     r2, =pxCurrentTCB
    ldr     r1, [r2]
    ldr     r0, [r1]               /* R0 = new task's pxTopOfStack */

    vldmia  r0!, {s16-s31}         /* Pop FPU registers */
    ldmia   r0!, {r4-r11, r14}     /* Pop R4-R11 and EXC_RETURN */
    msr     psp, r0                /* Restore Process Stack Pointer */
    bx      r14                    /* Return (hardware restores R0-R3, R12, LR, PC, xPSR) */
```

### 2.3 Tick Interrupt Processing

Every `1 / configTICK_RATE_HZ` seconds, the SysTick interrupt fires and calls `xTaskIncrementTick()`:

```c
/* Simplified pseudocode of xTaskIncrementTick() */
BaseType_t xTaskIncrementTick(void)
{
    BaseType_t xSwitchRequired = pdFALSE;

    if (uxSchedulerSuspended == 0) {
        ++xTickCount;

        /* Handle tick counter overflow — swap delayed lists */
        if (xTickCount == 0) {
            swap(pxDelayedTaskList, pxOverflowDelayedTaskList);
        }

        /* Wake tasks whose delay has expired */
        while (pxDelayedTaskList is not empty) {
            pxTCB = head of pxDelayedTaskList;
            if (pxTCB->xStateListItem.xItemValue > xTickCount) {
                break; /* No more tasks to wake */
            }
            remove pxTCB from delayed list;
            remove pxTCB from event list (if any);
            add pxTCB to ready list;

            if (pxTCB->uxPriority >= pxCurrentTCB->uxPriority) {
                xSwitchRequired = pdTRUE;
            }
        }

        /* Time-slicing: yield if another task at same priority is ready */
        if (configUSE_TIME_SLICING && listCURRENT_LIST_LENGTH(ready list at current priority) > 1) {
            xSwitchRequired = pdTRUE;
        }
    } else {
        ++uxPendedTicks; /* Deferred — processed when scheduler resumes */
    }

    return xSwitchRequired;
}
```

---

## 3. Task Management

Tasks are the fundamental unit of execution in FreeRTOS. Each task is an independent thread with its own stack, priority, and state.

### 3.1 Task States

```
                    ┌──────────────┐
        ┌──────────►│   RUNNING    │◄───────────────┐
        │           └──────┬───────┘                │
        │                  │                        │
        │    vTaskSuspend() │  Blocked on           │ Highest-priority
        │                  │  queue/semaphore/      │ ready task
        │                  │  delay                 │ selected by
        │                  ▼                        │ scheduler
        │           ┌──────────────┐                │
        │           │   BLOCKED    │                │
        │           └──────┬───────┘                │
        │                  │                        │
        │    Event occurs  │                        │
        │    or timeout    │                        │
        │                  ▼                        │
        │           ┌──────────────┐                │
        ├───────────│    READY     │────────────────┘
        │           └──────────────┘
        │
        │           ┌──────────────┐
        └───────────│  SUSPENDED   │
   vTaskResume()    └──────────────┘
```

| State | Description |
|---|---|
| **Running** | Currently executing on the CPU. Only one task in this state at a time (single-core). |
| **Ready** | Able to run but waiting because a higher- or equal-priority task is running. |
| **Blocked** | Waiting for a temporal event (delay) or an external event (queue, semaphore, etc.). Has an optional timeout. |
| **Suspended** | Removed from scheduling entirely. Only `vTaskResume()` (or `xTaskResumeFromISR()`) restores it. |

### 3.2 Task Creation Functions

#### `xTaskCreate()` — Dynamic Task Creation

```c
BaseType_t xTaskCreate(
    TaskFunction_t       pvTaskCode,      /* Pointer to the task function */
    const char * const   pcName,          /* Human-readable name (debug only) */
    configSTACK_DEPTH_TYPE usStackDepth,  /* Stack size in words (not bytes) */
    void                 *pvParameters,   /* Parameter passed to task function */
    UBaseType_t          uxPriority,      /* Task priority (0 = idle, max = configMAX_PRIORITIES-1) */
    TaskHandle_t         *pxCreatedTask   /* OUT: handle to the created task (can be NULL) */
);
/* Returns: pdPASS on success, errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY on failure */
```

**What happens internally:**

1. Allocates memory for TCB + stack from the FreeRTOS heap (single allocation in heap_4/5, two allocations in heap_1/2).
2. Initializes the TCB fields (name, priority, list items).
3. Calls `pxPortInitialiseStack()` to set up the initial stack frame so the task will start executing at `pvTaskCode` when first scheduled. The stack frame mimics what the hardware would push during an exception.
4. Adds the task to the ready list for its priority.
5. If the scheduler is already running and the new task has higher priority than the current task, triggers a context switch.

**Stack frame layout (Cortex-M, created by `pxPortInitialiseStack`):**

```
High Address (bottom of stack)
┌──────────────────┐
│      xPSR        │ ← 0x01000000 (Thumb bit set)
│       PC         │ ← pvTaskCode (entry point)
│       LR         │ ← prvTaskExitError (catches return from task)
│       R12        │ ← 0
│       R3         │ ← 0
│       R2         │ ← 0
│       R1         │ ← 0
│       R0         │ ← pvParameters (task argument)
├──────────────────┤ ← Hardware-pushed exception frame above
│       R14(LR)    │ ← EXC_RETURN value
│       R11        │
│       R10        │
│       R9         │
│       R8         │
│       R7         │
│       R6         │
│       R5         │
│       R4         │ ← pxTopOfStack points here
└──────────────────┘
Low Address (top of stack — grows downward)
```

#### `xTaskCreateStatic()` — Static Task Creation

```c
TaskHandle_t xTaskCreateStatic(
    TaskFunction_t       pvTaskCode,
    const char * const   pcName,
    const uint32_t       ulStackDepth,
    void                 *pvParameters,
    UBaseType_t          uxPriority,
    StackType_t * const  puxStackBuffer,    /* User-provided stack array */
    StaticTask_t * const pxTaskBuffer       /* User-provided TCB storage */
);
/* Returns: task handle on success, NULL if puxStackBuffer or pxTaskBuffer is NULL */
```

Use `xTaskCreateStatic()` when you need deterministic, compile-time memory allocation. The caller provides both the stack buffer and TCB storage — no heap allocation occurs.

```c
/* Static allocation example */
#define TASK_STACK_SIZE  256
static StackType_t  xTaskStack[TASK_STACK_SIZE];
static StaticTask_t xTaskTCB;

void app_init(void)
{
    TaskHandle_t h = xTaskCreateStatic(
        vMyTask, "Static", TASK_STACK_SIZE, NULL, 3,
        xTaskStack, &xTaskTCB
    );
    configASSERT(h != NULL);
}
```

### 3.3 Task Control Functions

#### `vTaskDelay()` — Relative Delay

```c
void vTaskDelay(const TickType_t xTicksToDelay);
```

Moves the calling task from the ready list to the delayed task list. The task will be moved back to the ready list after `xTicksToDelay` ticks have elapsed. The delay is **relative** to the time `vTaskDelay()` is called.

**Internal mechanism:**
1. Calculates the wake time: `xTimeToWake = xTickCount + xTicksToDelay`
2. Removes the task from its ready list
3. Sets `xStateListItem.xItemValue = xTimeToWake`
4. Inserts the task (sorted by wake time) into `pxDelayedTaskList` (or `pxOverflowDelayedTaskList` if the wake time overflows)
5. Triggers a context switch so the next highest-priority ready task runs

**Problem:** If the task is preempted or delayed before calling `vTaskDelay()`, the period between executions drifts.

#### `vTaskDelayUntil()` — Absolute Delay

```c
BaseType_t xTaskDelayUntil(
    TickType_t * const pxPreviousWakeTime,  /* IN/OUT: last wake time */
    const TickType_t   xTimeIncrement       /* Period in ticks */
);
```

Produces a fixed-frequency execution regardless of how long the task body takes. The wake time is calculated as `*pxPreviousWakeTime + xTimeIncrement`, then `*pxPreviousWakeTime` is updated for the next call.

```c
void vPeriodicTask(void *pv)
{
    TickType_t xLastWakeTime = xTaskGetTickCount();

    for (;;) {
        /* Execute every 100 ms exactly */
        vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(100));
        read_sensor_and_process();
    }
}
```

#### `vTaskPrioritySet()` — Change Priority at Runtime

```c
void vTaskPrioritySet(TaskHandle_t xTask, UBaseType_t uxNewPriority);
```

Changes the priority of `xTask` (or the calling task if `xTask` is NULL). Internally:
1. Removes the task from its current ready list (or updates priority in its blocked list).
2. Sets `uxPriority` to `uxNewPriority`.
3. Re-inserts into the correct ready list.
4. If the new priority is higher than the currently running task, triggers a context switch.

This is also the function called internally by the **priority inheritance** mechanism in mutexes.

#### `vTaskSuspend()` and `vTaskResume()`

```c
void vTaskSuspend(TaskHandle_t xTaskToSuspend);
void vTaskResume(TaskHandle_t xTaskToResume);
BaseType_t xTaskResumeFromISR(TaskHandle_t xTaskToResume);
```

`vTaskSuspend()` removes a task from all scheduling lists and places it on `xSuspendedTaskList`. The task will never run until explicitly resumed. A task can suspend itself by passing `NULL`.

`vTaskResume()` moves a suspended task back to the ready list. If the resumed task has higher priority, a context switch occurs.

`xTaskResumeFromISR()` is the ISR-safe version. Returns `pdTRUE` if a context switch is needed.

#### `vTaskDelete()`

```c
void vTaskDelete(TaskHandle_t xTaskToDelete);
```

Removes a task from all kernel lists and marks it for deletion. The idle task frees the TCB and stack memory (for dynamically created tasks) during its next iteration. A task can delete itself by passing `NULL`.

**Warning:** If a task deletes itself, the stack and TCB are freed by the idle task. Ensure the idle task runs periodically (do not starve it with higher-priority tasks that never block).

### 3.4 Task Query Functions

| Function | Returns |
|---|---|
| `xTaskGetTickCount()` | Current tick count |
| `xTaskGetTickCountFromISR()` | Current tick count (ISR-safe) |
| `uxTaskGetNumberOfTasks()` | Total number of existing tasks |
| `uxTaskGetStackHighWaterMark(xTask)` | Minimum free stack ever (in words) |
| `eTaskGetState(xTask)` | Task state: `eRunning`, `eReady`, `eBlocked`, `eSuspended`, `eDeleted` |
| `pcTaskGetName(xTask)` | Pointer to task name string |
| `xTaskGetHandle(pcNameToQuery)` | Look up task handle by name |
| `vTaskGetRunTimeStats(pcBuffer)` | Fill buffer with per-task CPU usage text |
| `uxTaskGetSystemState(pxArray, len, &totalRunTime)` | Detailed info for all tasks |

#### Stack High Water Mark

```c
void vMonitorTask(void *pv)
{
    TaskHandle_t hSensorTask = (TaskHandle_t)pv;

    for (;;) {
        UBaseType_t hwm = uxTaskGetStackHighWaterMark(hSensorTask);
        printf("Sensor task stack HWM: %u words free\r\n", (unsigned)hwm);

        if (hwm < 20) {
            printf("WARNING: Stack nearly full!\r\n");
        }

        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}
```

---

## 4. The FreeRTOS Scheduler

### 4.1 Scheduling Algorithm

FreeRTOS supports three scheduling modes controlled by two configuration macros:

| `configUSE_PREEMPTION` | `configUSE_TIME_SLICING` | Behavior |
|---|---|---|
| 1 | 1 | **Preemptive with time-slicing** (default). Highest-priority ready task always runs. Equal-priority tasks round-robin each tick. |
| 1 | 0 | **Preemptive without time-slicing**. Highest-priority task runs until it blocks or a higher-priority task becomes ready. No round-robin. |
| 0 | N/A | **Cooperative**. Tasks run until they explicitly yield (`taskYIELD()`) or block. No preemption. |

### 4.2 How Task Selection Works

```c
/* Simplified taskSELECT_HIGHEST_PRIORITY_TASK() */

/* Method 1: Generic (portable) — scans priority array top-down */
for (uxTopPriority = configMAX_PRIORITIES - 1; uxTopPriority >= 0; uxTopPriority--) {
    if (listLIST_IS_EMPTY(&pxReadyTasksLists[uxTopPriority]) == pdFALSE) {
        listGET_OWNER_OF_NEXT_ENTRY(pxCurrentTCB, &pxReadyTasksLists[uxTopPriority]);
        break;
    }
}

/* Method 2: Architecture-optimized — uses CLZ (Count Leading Zeros) instruction */
/* Cortex-M has a hardware CLZ instruction, making this O(1) */
UBaseType_t uxTopPriority = 31 - __clz(uxTopReadyPriority);
listGET_OWNER_OF_NEXT_ENTRY(pxCurrentTCB, &pxReadyTasksLists[uxTopPriority]);
```

The second method uses `uxTopReadyPriority` as a bitmap where bit N is set if priority N has at least one ready task. The `CLZ` instruction finds the highest set bit in a single cycle.

To enable the optimized method, set `configUSE_PORT_OPTIMISED_TASK_SELECTION` to 1 (automatic on Cortex-M).

### 4.3 The Idle Task

The idle task is created automatically by `vTaskStartScheduler()` at priority 0 (the lowest). It performs critical housekeeping:

1. **Frees memory** of deleted tasks (`vTaskDelete()` defers cleanup here).
2. **Runs the idle hook** (`vApplicationIdleHook()`) if `configUSE_IDLE_HOOK` is 1.
3. **Enters low-power mode** if tickless idle is enabled.

**Idle hook rules:**
- Must **never** block or call any function that could block.
- Must **never** call `vTaskSuspend()` on itself.
- Runs at priority 0; any other task at priority 0 will share time with it.

```c
void vApplicationIdleHook(void)
{
    __WFI(); /* Wait For Interrupt — puts CPU in sleep until next interrupt */
}
```

### 4.4 `vTaskStartScheduler()` — Starting the Kernel

```c
void vTaskStartScheduler(void);
```

This function:
1. Creates the idle task at priority 0.
2. Creates the timer daemon task (if `configUSE_TIMERS` is 1) at priority `configTIMER_TASK_PRIORITY`.
3. Disables interrupts.
4. Sets `xSchedulerRunning = pdTRUE`.
5. Initializes the tick count to 0.
6. Calls `xPortStartScheduler()` which:
   - Configures the SysTick timer for `configTICK_RATE_HZ`.
   - Sets PendSV and SysTick to the lowest interrupt priority.
   - Triggers SVC to restore the context of the highest-priority ready task and start it.

**`vTaskStartScheduler()` does not return** unless `vTaskEndScheduler()` is called (not supported on all ports) or if there is insufficient memory for the idle/timer tasks.

### 4.5 Critical Sections

FreeRTOS provides two critical section mechanisms:

#### Task-Level Critical Sections

```c
taskENTER_CRITICAL();
/* Interrupts at and below configMAX_SYSCALL_INTERRUPT_PRIORITY are disabled.
   Higher-priority interrupts (those that don't use FreeRTOS API) remain enabled. */
shared_variable++;
taskEXIT_CRITICAL();
```

These nest — a count is maintained, and interrupts are only re-enabled when the outermost `taskEXIT_CRITICAL()` is called.

#### ISR-Level Critical Sections

```c
void vAnISR(void)
{
    UBaseType_t uxSavedInterruptStatus = taskENTER_CRITICAL_FROM_ISR();
    /* Safe to access shared data */
    taskEXIT_CRITICAL_FROM_ISR(uxSavedInterruptStatus);
}
```

#### Scheduler Suspension

```c
vTaskSuspendAll();
/* Scheduler cannot switch tasks, but interrupts remain enabled.
   Tick count increments are deferred (uxPendedTicks). */
access_large_shared_structure();
xTaskResumeAll(); /* Processes all pended ticks, may trigger context switch */
```

Use `vTaskSuspendAll()` when the critical section is long and you don't want to disable interrupts. However, this **does not** protect against ISR-level access — only against task-level preemption.

---

## 5. Queues

Queues are the primary inter-task communication mechanism in FreeRTOS. They are thread-safe, ISR-safe, FIFO (or LIFO) buffers that can hold fixed-size items.

### 5.1 Queue Internals

A queue is internally a structure that contains:

```c
typedef struct QueueDefinition {
    int8_t     *pcHead;           /* Points to start of queue storage area */
    int8_t     *pcWriteTo;        /* Next free slot for writing */
    int8_t     *pcReadFrom;       /* Last slot read from */

    List_t     xTasksWaitingToSend;    /* Tasks blocked waiting to send */
    List_t     xTasksWaitingToReceive; /* Tasks blocked waiting to receive */

    UBaseType_t uxMessagesWaiting;     /* Current number of items in queue */
    UBaseType_t uxLength;              /* Maximum number of items */
    UBaseType_t uxItemSize;            /* Size of each item in bytes */

    volatile int8_t cRxLock;           /* ISR receive lock count */
    volatile int8_t cTxLock;           /* ISR send lock count */

    /* ... mutex-specific fields ... */
} xQUEUE;
```

Queue storage is a contiguous block of memory allocated immediately after the queue structure itself (single allocation). Items are copied by value — FreeRTOS uses `memcpy()` to move data in and out.

### 5.2 Queue API

#### `xQueueCreate()` — Create a Queue

```c
QueueHandle_t xQueueCreate(UBaseType_t uxQueueLength, UBaseType_t uxItemSize);
```

Allocates memory for the queue structure + storage area (`uxQueueLength * uxItemSize` bytes). Returns `NULL` if memory is insufficient.

```c
/* Create a queue that holds up to 10 int32_t values */
QueueHandle_t xQueue = xQueueCreate(10, sizeof(int32_t));
configASSERT(xQueue != NULL);
```

#### `xQueueSend()` / `xQueueSendToBack()` — Send to Queue (FIFO)

```c
BaseType_t xQueueSend(
    QueueHandle_t xQueue,
    const void    *pvItemToQueue,   /* Pointer to data to copy into queue */
    TickType_t    xTicksToWait      /* Max time to block if queue is full */
);
/* Returns: pdPASS if item was sent, errQUEUE_FULL if timeout expired */
```

**Internal behavior when queue is full:**
1. If `xTicksToWait` is 0, return `errQUEUE_FULL` immediately.
2. Otherwise, the calling task is removed from the ready list and placed on `xTasksWaitingToSend`.
3. The task is also placed on the delayed task list with the timeout value.
4. When space becomes available (another task calls `xQueueReceive()`), the highest-priority task on `xTasksWaitingToSend` is unblocked.
5. If the timeout expires first, the task is unblocked with `errQUEUE_FULL`.

#### `xQueueSendToFront()` — Send to Front (LIFO)

```c
BaseType_t xQueueSendToFront(
    QueueHandle_t xQueue,
    const void    *pvItemToQueue,
    TickType_t    xTicksToWait
);
```

Inserts the item at the front of the queue instead of the back. Useful for high-priority messages.

#### `xQueueReceive()` — Receive from Queue

```c
BaseType_t xQueueReceive(
    QueueHandle_t xQueue,
    void          *pvBuffer,        /* Buffer to copy received item into */
    TickType_t    xTicksToWait      /* Max time to block if queue is empty */
);
/* Returns: pdPASS if an item was received, errQUEUE_EMPTY if timeout expired */
```

`xQueuePeek()` is identical but does not remove the item from the queue.

#### ISR-Safe Variants

```c
BaseType_t xQueueSendFromISR(
    QueueHandle_t xQueue,
    const void    *pvItemToQueue,
    BaseType_t    *pxHigherPriorityTaskWoken  /* OUT: set to pdTRUE if a task was unblocked */
);

BaseType_t xQueueReceiveFromISR(
    QueueHandle_t xQueue,
    void          *pvBuffer,
    BaseType_t    *pxHigherPriorityTaskWoken
);
```

The `FromISR` variants never block. If the operation cannot complete (queue full/empty), they return immediately. The `pxHigherPriorityTaskWoken` parameter indicates whether a context switch should be performed after the ISR.

```c
void USART1_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    uint8_t byte = USART1->DR;

    xQueueSendFromISR(xRxQueue, &byte, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}
```

### 5.3 Queue Sets

Queue sets allow a task to block waiting on multiple queues/semaphores simultaneously.

```c
/* Create a queue set that can hold events from all member queues */
QueueSetHandle_t xQueueSet = xQueueCreateSet(QUEUE1_LEN + QUEUE2_LEN + 1);

xQueueAddToSet(xQueue1, xQueueSet);
xQueueAddToSet(xQueue2, xQueueSet);
xQueueAddToSet(xBinarySemaphore, xQueueSet);

void vMultiplexTask(void *pv)
{
    for (;;) {
        QueueSetMemberHandle_t xActivatedMember;
        xActivatedMember = xQueueSelectFromSet(xQueueSet, portMAX_DELAY);

        if (xActivatedMember == xQueue1) {
            int32_t val;
            xQueueReceive(xQueue1, &val, 0);
            process_queue1(val);
        } else if (xActivatedMember == xQueue2) {
            SensorData_t data;
            xQueueReceive(xQueue2, &data, 0);
            process_queue2(&data);
        } else if (xActivatedMember == xBinarySemaphore) {
            xSemaphoreTake(xBinarySemaphore, 0);
            handle_event();
        }
    }
}
```

---

## 6. Semaphores

Semaphores in FreeRTOS are implemented as queues with zero-length items. The count is tracked by `uxMessagesWaiting`.

### 6.1 Binary Semaphore

A binary semaphore has a maximum count of 1. It is typically used for synchronization: an ISR "gives" the semaphore, and a task "takes" it.

```c
SemaphoreHandle_t xBinarySem = xSemaphoreCreateBinary();
/* Created in "empty" state — first xSemaphoreTake() will block */
```

**Key API:**

```c
/* Give (signal) — increments count to 1 (or stays at 1 if already given) */
xSemaphoreGive(xBinarySem);
xSemaphoreGiveFromISR(xBinarySem, &xHigherPriorityTaskWoken);

/* Take (wait) — decrements count to 0, blocks if already 0 */
xSemaphoreTake(xBinarySem, xTicksToWait);
```

**ISR-to-task synchronization pattern:**

```c
SemaphoreHandle_t xUartRxSem;

void USART1_IRQHandler(void)
{
    BaseType_t xWoken = pdFALSE;
    /* Clear interrupt flag, read data into buffer ... */
    xSemaphoreGiveFromISR(xUartRxSem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

void vUartProcessTask(void *pv)
{
    for (;;) {
        /* Block until ISR signals that data is available */
        xSemaphoreTake(xUartRxSem, portMAX_DELAY);
        process_received_data();
    }
}
```

**Warning:** Binary semaphores can miss events. If the ISR gives the semaphore twice before the task takes it, one event is lost (the count saturates at 1). Use a counting semaphore if event counting matters.

### 6.2 Counting Semaphore

```c
SemaphoreHandle_t xCountingSem = xSemaphoreCreateCounting(
    10,   /* Maximum count */
    0     /* Initial count */
);
```

Use cases:
- **Event counting:** ISR gives once per event; task takes and processes each.
- **Resource management:** Initialize count to the number of available resources (e.g., 3 DMA channels); tasks take before use, give after.

**Internal implementation:** A counting semaphore is a queue of length `uxMaxCount` with `uxItemSize = 0`. `xSemaphoreGive()` calls `xQueueGenericSend()` which increments `uxMessagesWaiting`. `xSemaphoreTake()` calls `xQueueReceive()` which decrements it.

### 6.3 Binary vs. Counting Semaphore vs. Mutex

| Feature | Binary Semaphore | Counting Semaphore | Mutex |
|---|---|---|---|
| Max count | 1 | Configurable | 1 |
| Priority inheritance | No | No | **Yes** |
| Ownership | No (any task can give) | No | **Yes** (only holder can give) |
| ISR give | Yes | Yes | **No** |
| Use case | ISR→task sync | Resource counting | Mutual exclusion |

---

## 7. Mutexes

Mutexes (Mutual Exclusion semaphores) are the correct mechanism for protecting shared resources from concurrent access by multiple tasks.

### 7.1 Why Not Use a Binary Semaphore for Mutual Exclusion?

Binary semaphores lack **priority inheritance**, leading to **priority inversion**:

```
Priority:  High(H)  Medium(M)  Low(L)

1. L takes semaphore, begins accessing shared resource
2. H becomes ready, preempts L, tries to take semaphore → BLOCKED
3. M becomes ready, preempts L (M > L)
4. H is blocked by L, L is blocked by M → H is effectively blocked by M
   This is UNBOUNDED PRIORITY INVERSION
```

With a mutex and priority inheritance:

```
1. L takes mutex, begins accessing shared resource
2. H tries to take mutex → BLOCKED
3. Kernel raises L's priority to H (priority inheritance)
4. M becomes ready, but L is now running at H's priority → L continues
5. L releases mutex → L's priority restored to L, H runs immediately
   BOUNDED priority inversion (only as long as L holds the mutex)
```

### 7.2 Mutex API

```c
SemaphoreHandle_t xMutex = xSemaphoreCreateMutex();

void vTaskA(void *pv)
{
    for (;;) {
        if (xSemaphoreTake(xMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
            /* Critical section — access shared resource */
            modify_shared_data();
            xSemaphoreGive(xMutex);
        } else {
            /* Timeout — mutex not available within 100ms */
            handle_timeout();
        }
    }
}
```

### 7.3 Priority Inheritance Internals

When a high-priority task blocks on a mutex held by a lower-priority task:

1. The kernel calls `xTaskPriorityInherit()`:
   - Reads the mutex holder's TCB (stored in the queue's `pxMutexHolder` field).
   - If the holder's priority is lower than the blocked task's priority:
     - Sets `pxMutexHolder->uxPriority = blocked_task->uxPriority`.
     - Moves the holder to the ready list for the new (higher) priority.
   - The original priority is saved in `uxBasePriority`.

2. When the holder releases the mutex:
   - The kernel calls `xTaskPriorityDisinherit()`:
     - Decrements `uxMutexesHeld`.
     - If `uxMutexesHeld == 0`, restores `uxPriority` from `uxBasePriority`.
     - If `uxMutexesHeld > 0` (holding other mutexes), priority may not be fully restored yet.

### 7.4 Recursive Mutexes

A recursive mutex can be taken multiple times by the same task without deadlocking. It must be given the same number of times before it becomes available.

```c
SemaphoreHandle_t xRecursiveMutex = xSemaphoreCreateRecursiveMutex();

void vFunction(void)
{
    xSemaphoreTakeRecursive(xRecursiveMutex, portMAX_DELAY);
    /* ... */
    vNestedFunction(); /* Also takes the same mutex */
    /* ... */
    xSemaphoreGiveRecursive(xRecursiveMutex);
}

void vNestedFunction(void)
{
    xSemaphoreTakeRecursive(xRecursiveMutex, portMAX_DELAY);
    /* ... */
    xSemaphoreGiveRecursive(xRecursiveMutex);
}
```

### 7.5 Deadlock Prevention

FreeRTOS does not detect deadlocks. You must prevent them:

```
DEADLOCK: Task A holds Mutex1, waits for Mutex2
          Task B holds Mutex2, waits for Mutex1
```

**Prevention strategies:**

1. **Lock ordering:** Always acquire mutexes in a consistent global order.
2. **Try-lock with timeout:** Use a finite timeout instead of `portMAX_DELAY`.
3. **Single mutex:** Protect the entire resource group with one mutex.
4. **Minimize hold time:** Release mutexes as quickly as possible.

```c
/* Lock ordering example — always acquire mutex_a before mutex_b */
void safe_operation(void)
{
    xSemaphoreTake(xMutexA, portMAX_DELAY);
    xSemaphoreTake(xMutexB, portMAX_DELAY);

    /* Use both resources */

    xSemaphoreGive(xMutexB);
    xSemaphoreGive(xMutexA);
}
```

---

## 8. Event Groups

Event groups allow tasks to wait for a combination of events, represented as individual bits in a `EventBits_t` value (typically 24 usable bits on 32-bit architectures, since 8 bits are used internally by the kernel).

### 8.1 Event Group Internals

```c
typedef struct EventGroupDef_t {
    EventBits_t uxEventBits;           /* Current state of all event bits */
    List_t      xTasksWaitingForBits;  /* Tasks blocked waiting on bits */
} EventGroup_t;
```

Each waiting task stores its desired bit pattern and wait mode (AND/OR) in the `xEventListItem.xItemValue` field of its TCB.

### 8.2 Event Group API

#### `xEventGroupCreate()`

```c
EventGroupHandle_t xEventGroup = xEventGroupCreate();
```

#### `xEventGroupSetBits()` — Set Event Bits

```c
EventBits_t xEventGroupSetBits(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToSet    /* Bits to set (OR'd into current value) */
);
/* Returns: event bits value AFTER the bits were set */
```

**Internal behavior:**
1. Sets the specified bits: `uxEventBits |= uxBitsToSet`.
2. Iterates through `xTasksWaitingForBits`.
3. For each waiting task, checks if its wait condition is now satisfied.
4. Unblocks all tasks whose conditions are met.
5. If a task requested `xClearOnExit`, clears its bits from `uxEventBits`.

**ISR variant:** `xEventGroupSetBitsFromISR()` defers the actual bit-setting to the timer daemon task (because the unblock logic is too complex for an ISR).

#### `xEventGroupWaitBits()` — Wait for Event Bits

```c
EventBits_t xEventGroupWaitBits(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToWaitFor,
    const BaseType_t   xClearOnExit,    /* pdTRUE: clear bits when task unblocks */
    const BaseType_t   xWaitForAllBits, /* pdTRUE: AND (all bits), pdFALSE: OR (any bit) */
    TickType_t         xTicksToWait
);
/* Returns: event bits at the time the wait condition was met, or at timeout */
```

```c
#define EVT_WIFI_CONNECTED   (1 << 0)
#define EVT_SENSOR_READY     (1 << 1)
#define EVT_CONFIG_LOADED    (1 << 2)
#define EVT_ALL_READY        (EVT_WIFI_CONNECTED | EVT_SENSOR_READY | EVT_CONFIG_LOADED)

void vStartupTask(void *pv)
{
    /* Wait for ALL three subsystems to be ready */
    EventBits_t bits = xEventGroupWaitBits(
        xStartupEvents,
        EVT_ALL_READY,
        pdTRUE,       /* Clear bits when unblocked */
        pdTRUE,       /* Wait for ALL bits */
        pdMS_TO_TICKS(10000)
    );

    if ((bits & EVT_ALL_READY) == EVT_ALL_READY) {
        start_application();
    } else {
        handle_startup_timeout(bits);
    }
}
```

#### `xEventGroupSync()` — Rendezvous / Barrier

```c
EventBits_t xEventGroupSync(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToSet,        /* Bits THIS task sets (signals arrival) */
    const EventBits_t  uxBitsToWaitFor,    /* Bits to wait for (all tasks' arrival) */
    TickType_t         xTicksToWait
);
```

Implements a barrier pattern where multiple tasks synchronize at a common point:

```c
#define TASK_0_BIT  (1 << 0)
#define TASK_1_BIT  (1 << 1)
#define TASK_2_BIT  (1 << 2)
#define ALL_SYNC    (TASK_0_BIT | TASK_1_BIT | TASK_2_BIT)

void vTask0(void *pv)
{
    for (;;) {
        do_phase1_work();

        /* Signal my completion and wait for all others */
        xEventGroupSync(xSyncEvent, TASK_0_BIT, ALL_SYNC, portMAX_DELAY);

        /* All tasks have reached this point */
        do_phase2_work();
    }
}
```

---

## 9. Software Timers

Software timers allow functions to be executed at set times in the future without dedicating a task to each timer. All timer callbacks execute in the context of the **timer daemon task** (also called the timer service task).

### 9.1 Timer Architecture

```
┌──────────────┐     Timer Command Queue     ┌───────────────────┐
│  User Task   │ ──────────────────────────►  │  Timer Daemon     │
│  or ISR      │   (start/stop/reset/delete)  │  Task             │
└──────────────┘                              │  (prvTimerTask)   │
                                              │                   │
                                              │  Processes cmds,  │
                                              │  maintains sorted  │
                                              │  timer list,      │
                                              │  calls callbacks  │
                                              └───────────────────┘
```

The timer API functions (`xTimerStart()`, `xTimerStop()`, etc.) send commands through a queue (`xTimerQueue`) to the daemon task. The daemon task:
1. Receives commands from the queue.
2. Maintains two sorted lists of active timers (current + overflow, similar to delayed task lists).
3. Blocks on the queue with a timeout equal to the time until the next timer expires.
4. When a timer expires, calls its callback function in the daemon task's context.

### 9.2 Timer Configuration

```c
/* FreeRTOSConfig.h */
#define configUSE_TIMERS                1
#define configTIMER_TASK_PRIORITY       (configMAX_PRIORITIES - 1)  /* High priority */
#define configTIMER_QUEUE_LENGTH        10
#define configTIMER_TASK_STACK_DEPTH    256
```

### 9.3 Timer API

#### `xTimerCreate()` — Create a Timer

```c
TimerHandle_t xTimerCreate(
    const char * const   pcTimerName,
    TickType_t           xTimerPeriodInTicks,
    UBaseType_t          uxAutoReload,        /* pdTRUE = periodic, pdFALSE = one-shot */
    void                 *pvTimerID,          /* User-defined ID, retrievable in callback */
    TimerCallbackFunction_t pxCallbackFunction
);
```

```c
void vLedBlinkCallback(TimerHandle_t xTimer)
{
    toggle_led();
}

TimerHandle_t xBlinkTimer = xTimerCreate(
    "Blink", pdMS_TO_TICKS(500), pdTRUE, NULL, vLedBlinkCallback
);
```

#### Timer Control Functions

```c
/* Start/restart a timer — begins counting from now */
xTimerStart(xTimer, xTicksToWait);        /* xTicksToWait: max time to wait if cmd queue full */
xTimerStartFromISR(xTimer, pxHigherPriorityTaskWoken);

/* Stop a timer */
xTimerStop(xTimer, xTicksToWait);
xTimerStopFromISR(xTimer, pxHigherPriorityTaskWoken);

/* Reset — restart the timer from now (useful for watchdog-like behavior) */
xTimerReset(xTimer, xTicksToWait);
xTimerResetFromISR(xTimer, pxHigherPriorityTaskWoken);

/* Change period */
xTimerChangePeriod(xTimer, xNewPeriod, xTicksToWait);

/* Delete a timer */
xTimerDelete(xTimer, xTicksToWait);
```

All non-ISR versions accept a `xTicksToWait` parameter — this is the time to wait if the timer command queue is full (not the timer period).

#### Timer ID

Each timer has a `pvTimerID` that can be set/retrieved, allowing one callback to serve multiple timers:

```c
void vGenericCallback(TimerHandle_t xTimer)
{
    uint32_t id = (uint32_t)pvTimerGetTimerID(xTimer);

    switch (id) {
        case 0: handle_timeout_a(); break;
        case 1: handle_timeout_b(); break;
        case 2: handle_timeout_c(); break;
    }
}
```

### 9.4 Timer Callback Constraints

Timer callbacks execute in the daemon task context. Therefore:
- They must **not** block (no `vTaskDelay()`, no `xQueueReceive()` with a timeout, no `xSemaphoreTake()` with a timeout).
- They must be **short** to avoid delaying other timer callbacks.
- They run at `configTIMER_TASK_PRIORITY` — which affects which tasks they can preempt.

---

## 10. Task Notifications

Task notifications are a lightweight, fast alternative to binary semaphores, counting semaphores, event groups, and small queues. Each task has a built-in 32-bit notification value and a notification state — no separate kernel object needs to be created.

### 10.1 Performance Advantage

| Operation | Queue/Semaphore | Task Notification |
|---|---|---|
| RAM per instance | 76+ bytes | 0 (built into TCB) |
| Unblock latency | ~100 cycles | ~50 cycles |
| ISR give | Yes | Yes |

### 10.2 Notification Actions

```c
BaseType_t xTaskNotify(
    TaskHandle_t  xTaskToNotify,
    uint32_t      ulValue,
    eNotifyAction eAction
);
```

| `eAction` | Behavior | Equivalent To |
|---|---|---|
| `eNoAction` | Sets state to pending without changing value | Binary semaphore give |
| `eSetBits` | `ulNotifiedValue |= ulValue` | Event group set bits |
| `eIncrement` | `ulNotifiedValue++` (ignores `ulValue`) | Counting semaphore give |
| `eSetValueWithOverwrite` | `ulNotifiedValue = ulValue` | Queue send (overwrite) |
| `eSetValueWithoutOverwrite` | `ulNotifiedValue = ulValue` only if not pending | Queue send (fail if full) |

### 10.3 Task Notification API

```c
/* Send notification (task context) */
xTaskNotify(xTask, ulValue, eAction);
xTaskNotifyGive(xTask);  /* Shortcut for eIncrement */

/* Send notification (ISR context) */
xTaskNotifyFromISR(xTask, ulValue, eAction, pxHigherPriorityTaskWoken);
vTaskNotifyGiveFromISR(xTask, pxHigherPriorityTaskWoken);

/* Wait for notification */
xTaskNotifyWait(
    ulBitsToClearOnEntry,   /* Bits cleared from value on function entry */
    ulBitsToClearOnExit,    /* Bits cleared from value on function exit */
    pulNotificationValue,   /* OUT: notification value before exit-clearing */
    xTicksToWait
);
ulTaskNotifyTake(
    xClearCountOnExit,      /* pdTRUE: clear to 0, pdFALSE: decrement */
    xTicksToWait
);

/* Query without waiting */
xTaskNotifyStateClear(xTask);
ulTaskNotifyValueClear(xTask, ulBitsToClear);
```

### 10.4 Task Notification Internals

Each TCB contains:

```c
volatile uint32_t ulNotifiedValue;  /* The 32-bit notification value */
volatile uint8_t  ucNotifyState;    /* taskNOT_WAITING_NOTIFICATION (0)
                                       taskWAITING_NOTIFICATION (1)
                                       taskNOTIFICATION_RECEIVED (2) */
```

**`xTaskNotify()` internals:**
1. Enters a critical section.
2. If the target task's `ucNotifyState` is `taskWAITING_NOTIFICATION`:
   - Applies the action to `ulNotifiedValue`.
   - Sets `ucNotifyState = taskNOTIFICATION_RECEIVED`.
   - Removes the task from the blocked list and adds it to the ready list.
   - If the unblocked task's priority is higher, requests a context switch.
3. If the target is not waiting:
   - Applies the action to `ulNotifiedValue`.
   - Sets `ucNotifyState = taskNOTIFICATION_RECEIVED`.
   - (Task will see the notification next time it calls `xTaskNotifyWait()` or `ulTaskNotifyTake()`.)

### 10.5 Practical Examples

**As a binary semaphore replacement:**

```c
TaskHandle_t xUartTaskHandle;

void USART1_IRQHandler(void)
{
    BaseType_t xWoken = pdFALSE;
    vTaskNotifyGiveFromISR(xUartTaskHandle, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}

void vUartTask(void *pv)
{
    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        process_uart_data();
    }
}
```

**As event flags:**

```c
#define NOTIFY_WIFI_UP    (1 << 0)
#define NOTIFY_BT_UP      (1 << 1)
#define NOTIFY_GPS_FIX    (1 << 2)

void vSystemTask(void *pv)
{
    uint32_t ulNotifiedValue;

    for (;;) {
        xTaskNotifyWait(0, 0xFFFFFFFF, &ulNotifiedValue, portMAX_DELAY);

        if (ulNotifiedValue & NOTIFY_WIFI_UP)  wifi_connected();
        if (ulNotifiedValue & NOTIFY_BT_UP)    bt_connected();
        if (ulNotifiedValue & NOTIFY_GPS_FIX)   gps_acquired();
    }
}
```

### 10.6 Limitations

- **One-to-one:** Only one task can wait on a given notification. Multiple tasks cannot wait on the same notification.
- **No broadcast:** Unlike event groups, setting bits in a notification only signals one task.
- **Single value:** Only one 32-bit value per task (FreeRTOS v10.4+ adds indexed notifications — `xTaskNotifyIndexed()` — allowing multiple notification values per task).

---

## 11. Stream Buffers and Message Buffers

Stream buffers and message buffers, introduced in FreeRTOS v10, provide optimized byte-stream and message-based communication between a single writer and a single reader.

### 11.1 Stream Buffers

A stream buffer is a lock-free, single-producer-single-consumer (SPSC) circular byte buffer. No framing — data is treated as a continuous stream.

```c
StreamBufferHandle_t xStreamBuffer = xStreamBufferCreate(
    1024,   /* Total buffer size in bytes */
    1       /* Trigger level: unblock reader when this many bytes available */
);
```

**Key API:**

```c
/* Write bytes */
size_t xStreamBufferSend(
    StreamBufferHandle_t xStreamBuffer,
    const void           *pvTxData,
    size_t               xDataLengthBytes,
    TickType_t           xTicksToWait
);

/* Read bytes */
size_t xStreamBufferReceive(
    StreamBufferHandle_t xStreamBuffer,
    void                 *pvRxData,
    size_t               xBufferLengthBytes,
    TickType_t           xTicksToWait
);

/* ISR variants */
size_t xStreamBufferSendFromISR(...);
size_t xStreamBufferReceiveFromISR(...);

/* Set trigger level (minimum bytes to unblock a waiting reader) */
xStreamBufferSetTriggerLevel(xStreamBuffer, xTriggerLevel);
```

**Use case:** UART DMA reception — DMA writes bytes into the stream buffer, a task reads and processes them.

### 11.2 Message Buffers

A message buffer wraps a stream buffer with per-message length headers, preserving message boundaries.

```c
MessageBufferHandle_t xMsgBuffer = xMessageBufferCreate(1024);

/* Write a complete message */
size_t xMessageBufferSend(xMsgBuffer, &myStruct, sizeof(myStruct), pdMS_TO_TICKS(100));

/* Read a complete message */
size_t bytesRead = xMessageBufferReceive(xMsgBuffer, rxBuf, sizeof(rxBuf), portMAX_DELAY);
```

Internally, each message is stored as `[size_t length][payload bytes]`. The reader always receives a complete message or nothing.

**When to use what:**

| Mechanism | Best For |
|---|---|
| Queue | Fixed-size items, multiple producers/consumers |
| Stream buffer | Byte streams (UART, SPI), single producer & consumer |
| Message buffer | Variable-length messages, single producer & consumer |
| Task notification | Lightweight signaling, single receiver |

---

## 12. Memory Management

FreeRTOS provides five heap implementations. You link exactly one into your project.

### 12.1 Heap Implementations

#### `heap_1.c` — Allocate Only

```
Heap memory: [████████████████░░░░░░░░░░░░░]
              ^                ^
              Start            pucAlignedHeap + xNextFreeByte

Simple bump allocator. Never frees. Deterministic O(1).
```

- `pvPortMalloc()`: Advances a pointer. Returns NULL if insufficient space.
- `vPortFree()`: Does nothing (literally an empty function).
- **Use case:** Systems where tasks, queues, and semaphores are created at startup and never deleted.

#### `heap_2.c` — Best-Fit, No Coalescing

Maintains a free list sorted by block size. Allocations find the smallest block that fits. Freed blocks are returned to the free list but adjacent free blocks are never merged.

- **Fragmentation risk:** Over time, many small free blocks accumulate that cannot satisfy larger requests.
- **Use case:** Repeated allocations and frees of the same size (e.g., same-size message buffers).

#### `heap_3.c` — Wrapped `malloc`/`free`

Simply wraps the compiler's standard `malloc()` and `free()` with scheduler suspension for thread safety.

```c
void *pvPortMalloc(size_t xWantedSize)
{
    void *pv;
    vTaskSuspendAll();
    pv = malloc(xWantedSize);
    xTaskResumeAll();
    return pv;
}
```

- **Heap size:** Determined by the linker script, not `configTOTAL_HEAP_SIZE`.
- **Use case:** When you must use the standard library allocator.

#### `heap_4.c` — First-Fit with Coalescing (Recommended)

```
Free list (sorted by address):
[Free 128B] → [Free 64B] → [Free 256B] → END

After freeing a block adjacent to [Free 64B]:
[Free 128B] → [Free 128B (coalesced)] → [Free 256B] → END
```

- Best general-purpose choice. Coalesces adjacent free blocks to reduce fragmentation.
- Deterministic allocation from a statically allocated array `ucHeap[configTOTAL_HEAP_SIZE]`.
- `xPortGetFreeHeapSize()` returns current free bytes.
- `xPortGetMinimumEverFreeHeapSize()` returns the lowest free bytes ever seen (high water mark).

#### `heap_5.c` — Multiple Memory Regions

Extends `heap_4` to work across non-contiguous memory regions. Requires initialization before any allocation:

```c
const HeapRegion_t xHeapRegions[] = {
    { (uint8_t *)0x20000000, 0x10000 },  /* 64 KB internal SRAM */
    { (uint8_t *)0xC0000000, 0x80000 },  /* 512 KB external SDRAM */
    { NULL, 0 }                           /* Terminator */
};

int main(void)
{
    vPortDefineHeapRegions(xHeapRegions);
    /* Now pvPortMalloc/vPortFree can allocate across both regions */
}
```

### 12.2 Memory Allocation Failure Hook

```c
/* FreeRTOSConfig.h */
#define configUSE_MALLOC_FAILED_HOOK  1

/* Must be implemented by the application */
void vApplicationMallocFailedHook(void)
{
    printf("FATAL: FreeRTOS malloc failed! Free: %u bytes\r\n",
           (unsigned)xPortGetFreeHeapSize());
    configASSERT(0);
}
```

### 12.3 Static vs. Dynamic Allocation

FreeRTOS supports fully static allocation (no heap at all) when `configSUPPORT_STATIC_ALLOCATION` is 1 and `configSUPPORT_DYNAMIC_ALLOCATION` is 0:

```c
/* Application must provide these for idle and timer tasks */
void vApplicationGetIdleTaskMemory(
    StaticTask_t **ppxIdleTaskTCBBuffer,
    StackType_t  **ppxIdleTaskStackBuffer,
    uint32_t      *pulIdleTaskStackSize
);

void vApplicationGetTimerTaskMemory(
    StaticTask_t **ppxTimerTaskTCBBuffer,
    StackType_t  **ppxTimerTaskStackBuffer,
    uint32_t      *pulTimerTaskStackSize
);
```

---

## 13. Interrupt Management

### 13.1 Interrupt Priority Model on Cortex-M

FreeRTOS divides interrupts into two categories:

```
Priority 0  ┐ (highest)
Priority 1  │  NON-FreeRTOS interrupts
     ...    │  Cannot use ANY FreeRTOS API
Priority N  ┘  ← configMAX_SYSCALL_INTERRUPT_PRIORITY
Priority N+1┐
     ...    │  FreeRTOS-managed interrupts
Priority M  ┘  Can use "FromISR" API functions
             ← configKERNEL_INTERRUPT_PRIORITY (lowest, for PendSV/SysTick)
```

**ARM Cortex-M inverts priority numbering:** Lower numeric values = higher urgency. A priority of 0 is the highest, 255 is the lowest.

```c
/* FreeRTOSConfig.h — example for STM32 with 4 priority bits */
#define configPRIO_BITS                  4
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY  5
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY       15

#define configKERNEL_INTERRUPT_PRIORITY \
    (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))

#define configMAX_SYSCALL_INTERRUPT_PRIORITY \
    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
```

### 13.2 ISR-Safe API Pattern

Every FreeRTOS API function that can be called from an ISR has a `FromISR` suffix and follows this pattern:

```c
void vMyPeripheralISR(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    /* Use the FromISR variant — never blocks */
    xQueueSendFromISR(xQueue, &data, &xHigherPriorityTaskWoken);
    xSemaphoreGiveFromISR(xSem, &xHigherPriorityTaskWoken);
    xEventGroupSetBitsFromISR(xEventGroup, bits, &xHigherPriorityTaskWoken);
    vTaskNotifyGiveFromISR(xTask, &xHigherPriorityTaskWoken);
    xStreamBufferSendFromISR(xStream, buf, len, &xHigherPriorityTaskWoken);

    /* Request context switch if a higher-priority task was unblocked */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}
```

### 13.3 Deferred Interrupt Processing

The recommended pattern is to keep ISRs short — acknowledge the hardware and signal a task:

```c
/* ISR — runs at interrupt priority, must be fast */
void DMA1_Channel1_IRQHandler(void)
{
    BaseType_t xWoken = pdFALSE;

    if (DMA1->ISR & DMA_ISR_TCIF1) {
        DMA1->IFCR = DMA_IFCR_CTCIF1;
        vTaskNotifyGiveFromISR(xDmaTask, &xWoken);
    }

    portYIELD_FROM_ISR(xWoken);
}

/* Task — runs at task priority, can take as long as needed */
void vDmaProcessTask(void *pv)
{
    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        process_dma_buffer();
    }
}
```

### 13.4 `configASSERT()` and Interrupt Priority Validation

FreeRTOS validates that ISRs calling `FromISR` functions have a numeric priority value >= `configMAX_SYSCALL_INTERRUPT_PRIORITY`. This check runs inside `configASSERT()`. A common bug:

```c
/* WRONG — priority 1 is ABOVE configMAX_SYSCALL_INTERRUPT_PRIORITY */
NVIC_SetPriority(USART1_IRQn, 1);

/* CORRECT — priority 5 is at or below configMAX_SYSCALL_INTERRUPT_PRIORITY */
NVIC_SetPriority(USART1_IRQn, configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY);
```

---

## 14. Low-Power Support (Tickless Idle)

### 14.1 Standard Tick Behavior

By default, the SysTick interrupt fires every 1 ms (at `configTICK_RATE_HZ = 1000`), waking the CPU from any sleep mode. This wastes power when the system is idle.

### 14.2 Tickless Idle Mode

When `configUSE_TICKLESS_IDLE` is set to 1, FreeRTOS suppresses the tick interrupt during idle periods:

```c
/* Simplified pseudocode of the idle task with tickless idle */
void prvIdleTask(void *pv)
{
    for (;;) {
        if (no other tasks are ready) {
            xExpectedIdleTime = time until next task wake-up;

            if (xExpectedIdleTime >= configEXPECTED_IDLE_TIME_BEFORE_SLEEP) {
                vPortSuppressTicksAndSleep(xExpectedIdleTime);
                /*
                 * This function:
                 * 1. Programs SysTick for the expected idle duration
                 * 2. Enters low-power mode (WFI/WFE)
                 * 3. On wake-up, calculates actual elapsed ticks
                 * 4. Compensates xTickCount for the skipped ticks
                 */
            }
        }

        /* Run idle hook, clean up deleted tasks, etc. */
    }
}
```

### 14.3 Custom Tickless Implementation

For deep sleep modes (e.g., STM32 STOP mode where SysTick is stopped), override with a custom implementation:

```c
/* FreeRTOSConfig.h */
#define configUSE_TICKLESS_IDLE  2  /* 2 = user-provided implementation */

/* port.c or application code */
void vPortSuppressTicksAndSleep(TickType_t xExpectedIdleTime)
{
    /* 1. Configure a low-power timer (LPTIM, RTC) to wake after xExpectedIdleTime ticks */
    configure_lptim_wakeup(xExpectedIdleTime);

    /* 2. Enter critical section to prevent race between check and sleep */
    __disable_irq();

    /* 3. Re-check: if a context switch is now pending, don't sleep */
    if (eTaskConfirmSleepModeStatus() == eAbortSleep) {
        __enable_irq();
        return;
    }

    /* 4. Enter deep sleep */
    configure_stop_mode();
    __enable_irq();
    __WFI();

    /* --- CPU wakes here --- */

    /* 5. Restore clocks, calculate elapsed ticks */
    uint32_t actual_ticks = read_lptim_elapsed();
    restore_system_clocks();

    /* 6. Compensate the tick count */
    vTaskStepTick(actual_ticks);
}
```

---

## 15. Debugging, Tracing, and Best Practices

### 15.1 Stack Overflow Detection

FreeRTOS provides two detection methods:

```c
/* FreeRTOSConfig.h */
#define configCHECK_FOR_STACK_OVERFLOW  2  /* 0=off, 1=method1, 2=method1+method2 */
```

**Method 1:** Checks if the stack pointer went past the stack boundary at each context switch.

**Method 2:** Fills the stack with a known pattern (0xA5A5A5A5) at creation. At each context switch, checks if the last 20 bytes of the stack still contain the pattern. More reliable but not foolproof (a stack corruption between context switches could be missed).

```c
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    printf("STACK OVERFLOW in task: %s\r\n", pcTaskName);
    configASSERT(0);
}
```

### 15.2 Runtime Statistics

```c
/* FreeRTOSConfig.h */
#define configGENERATE_RUN_TIME_STATS         1
#define configUSE_STATS_FORMATTING_FUNCTIONS  1
#define portCONFIGURE_TIMER_FOR_RUN_TIME_STATS()  config_stats_timer()
#define portGET_RUN_TIME_COUNTER_VALUE()           get_stats_timer_value()
```

```c
void vStatsTask(void *pv)
{
    char buf[512];

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(10000));
        vTaskGetRunTimeStats(buf);
        printf("Task            Abs Time    %%Time\r\n");
        printf("-------------------------------\r\n");
        printf("%s\r\n", buf);
    }
}
```

Sample output:
```
Task            Abs Time    %Time
-------------------------------
Sensor          13205       6%
Display         8430        4%
Comms           24310       12%
IDLE            158720      78%
```

### 15.3 Trace Hooks

FreeRTOS defines trace macros at key points in the kernel. By default they are empty. Defining them enables integration with tools like SEGGER SystemView or Percepio Tracealyzer:

```c
/* Key trace points (defined in FreeRTOS.h, override in FreeRTOSConfig.h) */
#define traceTASK_SWITCHED_IN()           /* Called when a task starts running */
#define traceTASK_SWITCHED_OUT()          /* Called when a task stops running */
#define traceQUEUE_SEND(pxQueue)          /* Called on successful queue send */
#define traceQUEUE_RECEIVE(pxQueue)       /* Called on successful queue receive */
#define traceTASK_CREATE(pxNewTCB)        /* Called when a task is created */
#define traceTASK_DELETE(pxTCB)           /* Called when a task is deleted */
#define traceBLOCKING_ON_QUEUE_RECEIVE(pxQueue)
#define traceBLOCKING_ON_QUEUE_SEND(pxQueue)
/* ... many more ... */
```

### 15.4 `configASSERT()`

The single most important debugging tool. Define it to catch programming errors during development:

```c
#define configASSERT(x) do { if (!(x)) { \
    taskDISABLE_INTERRUPTS(); \
    printf("ASSERT FAILED: %s:%d\r\n", __FILE__, __LINE__); \
    for (;;); \
}} while (0)
```

FreeRTOS uses `configASSERT()` extensively internally to validate:
- ISR priority levels for `FromISR` calls
- Non-NULL pointers
- Valid scheduler state
- Correct API usage (e.g., not calling blocking functions from ISRs)

### 15.5 Best Practices

1. **Always set `configASSERT()`** during development. Disable in production for performance.

2. **Size stacks conservatively, then measure.** Start with generous stacks, use `uxTaskGetStackHighWaterMark()` to determine actual usage, then set stack size to actual + 20–30% margin.

3. **Never call non-ISR API from an ISR.** Always use `FromISR` variants.

4. **Use mutexes (not binary semaphores) for mutual exclusion.** Mutexes provide priority inheritance.

5. **Minimize time spent in critical sections.** Long critical sections increase interrupt latency.

6. **Use task notifications instead of semaphores/queues when possible.** They are faster and use less RAM.

7. **Avoid `malloc`/`free` after startup.** Use static allocation or allocate all kernel objects during initialization.

8. **Set `configTICK_RATE_HZ` appropriately.** 1000 Hz (1 ms) is common but wastes power. Many applications work fine at 100 Hz (10 ms).

9. **Don't starve the idle task.** It must run periodically to clean up deleted tasks and (optionally) enter low-power mode.

10. **Use `vTaskDelayUntil()` for periodic tasks** instead of `vTaskDelay()` to avoid timing drift.

---

## 16. FreeRTOS Configuration Reference

The `FreeRTOSConfig.h` file controls all kernel features. Here is a comprehensive reference:

### 16.1 Core Configuration

```c
/* Scheduling */
#define configUSE_PREEMPTION                    1       /* 1=preemptive, 0=cooperative */
#define configUSE_TIME_SLICING                  1       /* Round-robin same-priority tasks */
#define configUSE_PORT_OPTIMISED_TASK_SELECTION  1       /* Use CLZ for O(1) task selection */
#define configMAX_PRIORITIES                    56      /* Number of priority levels */
#define configMINIMAL_STACK_SIZE                128     /* Idle task stack (words) */
#define configMAX_TASK_NAME_LEN                 16      /* Max chars in task name */
#define configTICK_RATE_HZ                      1000    /* Tick frequency */
#define configIDLE_SHOULD_YIELD                 1       /* Idle yields to priority-0 tasks */
```

### 16.2 Memory Configuration

```c
#define configSUPPORT_STATIC_ALLOCATION         1       /* Enable xTaskCreateStatic etc. */
#define configSUPPORT_DYNAMIC_ALLOCATION        1       /* Enable xTaskCreate etc. */
#define configTOTAL_HEAP_SIZE                   (32 * 1024)
#define configAPPLICATION_ALLOCATED_HEAP        0       /* 1=app provides ucHeap[] */
```

### 16.3 Feature Enables

```c
#define configUSE_MUTEXES                       1
#define configUSE_RECURSIVE_MUTEXES             1
#define configUSE_COUNTING_SEMAPHORES           1
#define configUSE_QUEUE_SETS                    0
#define configUSE_TASK_NOTIFICATIONS            1
#define configTASK_NOTIFICATION_ARRAY_ENTRIES   1       /* Indexed notifications (v10.4+) */
#define configUSE_TIMERS                        1
#define configTIMER_TASK_PRIORITY               (configMAX_PRIORITIES - 1)
#define configTIMER_QUEUE_LENGTH                10
#define configTIMER_TASK_STACK_DEPTH            256
```

### 16.4 Hook Functions

```c
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     0
#define configUSE_MALLOC_FAILED_HOOK            1
#define configCHECK_FOR_STACK_OVERFLOW          2
#define configUSE_DAEMON_TASK_STARTUP_HOOK      0
```

### 16.5 Debug and Stats

```c
#define configUSE_TRACE_FACILITY                1       /* Enable vTaskList(), etc. */
#define configGENERATE_RUN_TIME_STATS           1
#define configUSE_STATS_FORMATTING_FUNCTIONS    1
#define configRECORD_STACK_HIGH_ADDRESS          1
```

### 16.6 Interrupt Priorities (Cortex-M)

```c
#define configPRIO_BITS                         4
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY 15
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY  5
#define configKERNEL_INTERRUPT_PRIORITY         (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
#define configMAX_SYSCALL_INTERRUPT_PRIORITY    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
```

### 16.7 Include Functions

```c
/* Set to 1 to include the API function, 0 to exclude (saves code space) */
#define INCLUDE_vTaskPrioritySet                1
#define INCLUDE_uxTaskPriorityGet               1
#define INCLUDE_vTaskDelete                     1
#define INCLUDE_vTaskSuspend                    1
#define INCLUDE_vTaskDelayUntil                 1
#define INCLUDE_vTaskDelay                      1
#define INCLUDE_xTaskGetSchedulerState          1
#define INCLUDE_xTaskGetCurrentTaskHandle       1
#define INCLUDE_uxTaskGetStackHighWaterMark     1
#define INCLUDE_xTaskGetIdleTaskHandle          0
#define INCLUDE_eTaskGetState                   1
#define INCLUDE_xTimerPendFunctionCall          1
#define INCLUDE_xTaskAbortDelay                 1
#define INCLUDE_xTaskGetHandle                  0
#define INCLUDE_xTaskResumeFromISR              1
```

---

## 17. Common Pitfalls and How to Avoid Them

### Pitfall 1: Using Blocking API in an ISR

```c
/* WRONG — xQueueSend blocks, will crash in ISR */
void TIM2_IRQHandler(void) {
    xQueueSend(xQueue, &data, portMAX_DELAY);
}

/* CORRECT — use FromISR variant */
void TIM2_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    xQueueSendFromISR(xQueue, &data, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}
```

### Pitfall 2: Wrong Interrupt Priority

```c
/* WRONG — priority 2 is above configMAX_SYSCALL_INTERRUPT_PRIORITY (5) */
NVIC_SetPriority(USART1_IRQn, 2);  /* This ISR calls xQueueSendFromISR */

/* CORRECT */
NVIC_SetPriority(USART1_IRQn, 6);  /* 6 >= 5, safe to use FreeRTOS API */
```

### Pitfall 3: Stack Overflow

```c
/* WRONG — large local buffer on a small stack */
void vTask(void *pv) {
    char buffer[4096];  /* If stack is 512 words (2048 bytes), instant crash */
    sprintf(buffer, "...");
}

/* CORRECT — use static or heap allocation */
void vTask(void *pv) {
    static char buffer[4096];
    /* or: char *buffer = pvPortMalloc(4096); */
}
```

### Pitfall 4: Priority Inversion Without Mutex

```c
/* WRONG — binary semaphore has no priority inheritance */
SemaphoreHandle_t xSem = xSemaphoreCreateBinary();
xSemaphoreGive(xSem);

/* CORRECT — use mutex for resource protection */
SemaphoreHandle_t xMutex = xSemaphoreCreateMutex();
```

### Pitfall 5: Forgetting `portYIELD_FROM_ISR()`

```c
/* WRONG — high-priority task won't run until next tick */
void EXTI0_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    xSemaphoreGiveFromISR(xSem, &xWoken);
    /* Missing portYIELD_FROM_ISR! */
}

/* CORRECT */
void EXTI0_IRQHandler(void) {
    BaseType_t xWoken = pdFALSE;
    xSemaphoreGiveFromISR(xSem, &xWoken);
    portYIELD_FROM_ISR(xWoken);
}
```

### Pitfall 6: Passing Stack Variables to Tasks

```c
/* WRONG — local variable goes out of scope */
void create_tasks(void) {
    int config = 42;
    xTaskCreate(vMyTask, "T", 256, &config, 3, NULL);  /* &config becomes dangling */
}

/* CORRECT — use static/global or heap-allocated memory */
static int config = 42;
void create_tasks(void) {
    xTaskCreate(vMyTask, "T", 256, &config, 3, NULL);
}
```

### Pitfall 7: Calling FreeRTOS API Before Scheduler Starts

```c
/* WRONG — vTaskDelay requires the scheduler to be running */
int main(void) {
    xTaskCreate(vMyTask, "T", 256, NULL, 3, NULL);
    vTaskDelay(100);  /* Scheduler not started yet! */
    vTaskStartScheduler();
}

/* CORRECT — only create objects before scheduler starts */
int main(void) {
    xQueueCreate(...);
    xTaskCreate(...);
    vTaskStartScheduler(); /* All blocking calls happen inside tasks */
}
```

### Pitfall 8: Deadlock from Inconsistent Lock Ordering

```c
/* DEADLOCK — Task A locks M1→M2, Task B locks M2→M1 */
void vTaskA(void *pv) {
    xSemaphoreTake(xMutex1, portMAX_DELAY);
    xSemaphoreTake(xMutex2, portMAX_DELAY);  /* Deadlock if B holds M2 */
    /* ... */
}
void vTaskB(void *pv) {
    xSemaphoreTake(xMutex2, portMAX_DELAY);
    xSemaphoreTake(xMutex1, portMAX_DELAY);  /* Deadlock if A holds M1 */
    /* ... */
}

/* FIX — consistent ordering */
void vTaskA(void *pv) { xSemaphoreTake(xMutex1, ...); xSemaphoreTake(xMutex2, ...); }
void vTaskB(void *pv) { xSemaphoreTake(xMutex1, ...); xSemaphoreTake(xMutex2, ...); }
```

---

## Example Programs

This guide is accompanied by six complete, annotated example programs:

| File | Description | Concepts Covered |
|---|---|---|
| [`examples/12_freertos_tasks.c`](examples/12_freertos_tasks.c) | Task creation, priorities, delays, suspend/resume, stack monitoring | `xTaskCreate`, `vTaskDelay`, `vTaskDelayUntil`, `vTaskSuspend`, `vTaskResume`, `uxTaskGetStackHighWaterMark` |
| [`examples/13_freertos_queues.c`](examples/13_freertos_queues.c) | Multi-producer queues, mailbox, queue sets | `xQueueCreate`, `xQueueSend`, `xQueueReceive`, `xQueueOverwrite`, `xQueueCreateSet` |
| [`examples/14_freertos_semaphores.c`](examples/14_freertos_semaphores.c) | Binary/counting semaphores, mutexes, priority inheritance | `xSemaphoreCreateBinary`, `xSemaphoreCreateCounting`, `xSemaphoreCreateMutex`, priority inheritance demo |
| [`examples/15_freertos_timers_events.c`](examples/15_freertos_timers_events.c) | Software timers, event groups, barrier sync | `xTimerCreate`, `xEventGroupCreate`, `xEventGroupWaitBits`, `xEventGroupSync` |
| [`examples/16_freertos_notifications.c`](examples/16_freertos_notifications.c) | Task notifications, stream/message buffers | `xTaskNotify`, `ulTaskNotifyTake`, `xStreamBufferCreate`, `xMessageBufferCreate` |
| [`examples/17_freertos_iot_app.c`](examples/17_freertos_iot_app.c) | Complete IoT sensor monitoring application | All major FreeRTOS primitives in a production-like architecture |

---

*This guide covers FreeRTOS kernel v10.x / v11.x. API behavior is consistent across these versions unless noted. For the latest updates, refer to the [official FreeRTOS documentation](https://www.freertos.org/Documentation/RTOS_book.html).*
