# FreeRTOS Comprehensive Guide: Architecture, Internals, and Practical Examples

A deep-dive tutorial covering FreeRTOS from first principles through advanced patterns, with detailed explanations of every kernel API function, internal data structures, and 10 complete, annotated example programs.

---

## Table of Contents

1. [Introduction to FreeRTOS](#1-introduction-to-freertos)
2. [Architecture and Kernel Internals](#2-architecture-and-kernel-internals)
3. [FreeRTOS Configuration (FreeRTOSConfig.h)](#3-freertos-configuration-freertosconfigh)
4. [Task Management](#4-task-management)
5. [The Scheduler: Internals and Algorithms](#5-the-scheduler-internals-and-algorithms)
6. [Queue Management](#6-queue-management)
7. [Semaphores](#7-semaphores)
8. [Mutexes and Priority Inheritance](#8-mutexes-and-priority-inheritance)
9. [Event Groups](#9-event-groups)
10. [Software Timers](#10-software-timers)
11. [Task Notifications](#11-task-notifications)
12. [Stream Buffers and Message Buffers](#12-stream-buffers-and-message-buffers)
13. [Memory Management](#13-memory-management)
14. [Interrupt Management](#14-interrupt-management)
15. [Co-routines (Legacy)](#15-co-routines-legacy)
16. [Debugging, Tracing, and Runtime Statistics](#16-debugging-tracing-and-runtime-statistics)
17. [Common Pitfalls and Best Practices](#17-common-pitfalls-and-best-practices)
18. [API Reference Summary](#18-api-reference-summary)

---

## 1. Introduction to FreeRTOS

### What Is FreeRTOS?

FreeRTOS is an open-source, real-time operating system kernel designed for embedded microcontrollers. It provides:

- **Preemptive, cooperative, or hybrid scheduling** of tasks (threads)
- **Inter-task communication** via queues, semaphores, mutexes, event groups, and task notifications
- **Memory management** with five selectable heap allocation schemes
- **Software timers** for deferred and periodic execution
- **A tiny footprint** — the kernel compiles to as little as 5–10 KB of Flash and uses approximately 236 bytes of RAM per task

FreeRTOS runs on 40+ architectures including ARM Cortex-M (M0/M0+/M3/M4/M7/M33), RISC-V, Xtensa (ESP32), AVR, PIC, MSP430, and x86.

### FreeRTOS vs Bare-Metal

| Aspect | Bare-Metal (Super Loop) | FreeRTOS |
|---|---|---|
| Execution model | Single infinite loop | Multiple concurrent tasks |
| Timing | Manually manage delays | Kernel handles timing |
| Responsiveness | Worst-case = sum of all tasks | Worst-case = context-switch time |
| Modularity | Monolithic | Each task is an independent unit |
| Resource sharing | Manual discipline | Kernel primitives (mutex, etc.) |
| Code complexity | Grows quickly | Scales well |
| Overhead | Zero | ~1–3% CPU for tick interrupt + context switches |

### FreeRTOS vs Other RTOSes

| Feature | FreeRTOS | Zephyr | RT-Thread | CMSIS-RTOS2 |
|---|---|---|---|---|
| License | MIT | Apache 2.0 | Apache 2.0 | Apache 2.0 |
| Kernel size | 5–10 KB | 50–100 KB | 10–30 KB | Wrapper layer |
| Architecture support | 40+ | 20+ | 30+ | ARM only |
| Networking stack | FreeRTOS+TCP | Native | lwIP/native | None |
| File system | FreeRTOS+FAT | Native | DFS | None |
| Certification | SAFERTOS (IEC 61508, ISO 26262) | — | — | — |
| AWS IoT integration | Native (coreMQTT, etc.) | — | — | — |

### Terminology

| Term | Definition |
|---|---|
| **Task** | An independent thread of execution with its own stack and context |
| **TCB** | Task Control Block — the kernel's internal data structure for each task |
| **Tick** | The periodic timer interrupt that drives the kernel's time base |
| **Context Switch** | Saving one task's CPU registers and restoring another's |
| **Ready List** | The set of tasks eligible to run, organized by priority |
| **Blocked State** | A task waiting for a time delay or synchronization event |
| **Suspended State** | A task explicitly paused by the application |
| **ISR** | Interrupt Service Routine — hardware interrupt handler |
| **Critical Section** | A region of code where interrupts are disabled to protect shared data |

---

## 2. Architecture and Kernel Internals

### Kernel Source File Structure

```
FreeRTOS/
├── Source/
│   ├── tasks.c              ← Task management, scheduler, TCB operations
│   ├── queue.c              ← Queues, semaphores, mutexes (all built on queues)
│   ├── list.c               ← Doubly-linked list used by all kernel structures
│   ├── timers.c             ← Software timer service (daemon task)
│   ├── event_groups.c       ← Event group (bit-flag) synchronization
│   ├── stream_buffer.c      ← Stream buffers and message buffers
│   ├── croutine.c           ← Co-routines (legacy, rarely used)
│   ├── include/
│   │   ├── FreeRTOS.h       ← Master include (pulls in FreeRTOSConfig.h)
│   │   ├── task.h           ← Task API declarations
│   │   ├── queue.h          ← Queue API declarations
│   │   ├── semphr.h         ← Semaphore/mutex macros (wrappers around queue.h)
│   │   ├── event_groups.h   ← Event group API
│   │   ├── timers.h         ← Software timer API
│   │   ├── stream_buffer.h  ← Stream/message buffer API
│   │   ├── list.h           ← List data structure
│   │   └── portable.h       ← Port layer abstraction
│   └── portable/
│       ├── GCC/ARM_CM4F/    ← Port for Cortex-M4F with GCC
│       │   ├── port.c       ← PendSV handler, SVC handler, tick setup
│       │   └── portmacro.h  ← Port-specific types and macros
│       └── MemMang/
│           ├── heap_1.c     ← Simplest: allocate only, never free
│           ├── heap_2.c     ← Best-fit, no coalescence
│           ├── heap_3.c     ← Wraps standard malloc/free
│           ├── heap_4.c     ← First-fit with coalescence (most common)
│           └── heap_5.c     ← heap_4 across non-contiguous memory regions
```

### The List Data Structure (`list.c` / `list.h`)

Every kernel mechanism — ready lists, delayed task lists, queue waiting lists — is built on the same doubly-linked list. Understanding it is key to understanding FreeRTOS internals.

```c
/* The list item stored inside each TCB, queue, etc. */
struct xLIST_ITEM {
    TickType_t      xItemValue;      /* Sort key (e.g. wake time, priority) */
    struct xLIST_ITEM *pxNext;       /* Next item in the list */
    struct xLIST_ITEM *pxPrevious;   /* Previous item in the list */
    void            *pvOwner;        /* Back-pointer to the owning TCB */
    struct xLIST    *pxContainer;    /* The list this item belongs to */
};

/* The list header — a sentinel-based circular doubly-linked list */
struct xLIST {
    UBaseType_t      uxNumberOfItems; /* Number of items currently in the list */
    ListItem_t      *pxIndex;         /* Used to walk through the list */
    MiniListItem_t   xListEnd;        /* Sentinel with xItemValue = portMAX_DELAY */
};
```

**Key list operations (all O(1) except insert-sorted which is O(n)):**

| Function | Description |
|---|---|
| `vListInitialise(pxList)` | Initialize list with sentinel; set `uxNumberOfItems = 0` |
| `vListInitialiseItem(pxItem)` | Set `pxContainer = NULL` (item not in any list) |
| `vListInsertEnd(pxList, pxItem)` | Insert before the current `pxIndex` position (FIFO within same priority) |
| `vListInsert(pxList, pxItem)` | Insert sorted by `xItemValue` ascending (used for delay lists) |
| `uxListRemove(pxItem)` | Remove from its current list; returns remaining item count |
| `listGET_OWNER_OF_HEAD_ENTRY(pxList)` | Returns `pvOwner` of the item after sentinel (highest-priority / earliest-wake task) |

### The Task Control Block (TCB)

Each task has a TCB allocated on the heap. It stores everything the kernel needs to manage the task:

```c
typedef struct tskTaskControlBlock {
    /* The task's stack pointer — MUST be the first field for fast context switch */
    volatile StackType_t    *pxTopOfStack;

    /* List items for placing this task in ready/blocked/suspended lists */
    ListItem_t              xStateListItem;
    ListItem_t              xEventListItem;

    /* Task priority (0 = idle, configMAX_PRIORITIES-1 = highest) */
    UBaseType_t             uxPriority;

    /* Pointer to the start of the stack memory allocation */
    StackType_t             *pxStack;

    /* Task name (for debugging), max configMAX_TASK_NAME_LEN characters */
    char                    pcTaskName[configMAX_TASK_NAME_LEN];

    /* --- Fields present when specific features are enabled --- */

    #if (configUSE_MUTEXES == 1)
        UBaseType_t         uxBasePriority;      /* Original priority before inheritance */
        UBaseType_t         uxMutexesHeld;        /* Number of mutexes currently held */
    #endif

    #if (configUSE_TASK_NOTIFICATIONS == 1)
        volatile uint32_t   ulNotifiedValue[configTASK_NOTIFICATION_ARRAY_ENTRIES];
        volatile uint8_t    ucNotifyState[configTASK_NOTIFICATION_ARRAY_ENTRIES];
    #endif

    #if (configGENERATE_RUN_TIME_STATS == 1)
        configRUN_TIME_COUNTER_TYPE ulRunTimeCounter; /* Accumulated CPU time */
    #endif

    #if (configUSE_NEWLIB_REENTRANT == 1)
        struct _reent       xNewLib_reent;       /* Per-task newlib context */
    #endif

    #if (configUSE_TRACE_FACILITY == 1)
        UBaseType_t         uxTCBNumber;         /* Trace identifier */
        UBaseType_t         uxTaskNumber;        /* User-assignable ID */
    #endif

    /* Stack overflow detection canary (if enabled) */
    #if (configCHECK_FOR_STACK_OVERFLOW > 0)
        StackType_t         *pxEndOfStack;
    #endif

} tskTCB;
```

### Kernel State Variables (inside `tasks.c`)

```c
/* The currently executing task */
static volatile TCB_t *pxCurrentTCB = NULL;

/* Ready lists — one per priority level */
static List_t pxReadyTasksLists[configMAX_PRIORITIES];

/* Delayed task lists — two lists swapped on tick-count overflow */
static List_t xDelayedTaskList1;
static List_t xDelayedTaskList2;
static List_t *volatile pxDelayedTaskList;
static List_t *volatile pxOverflowDelayedTaskList;

/* Suspended and pending-ready lists */
static List_t xSuspendedTaskList;
static List_t xPendingReadyList;   /* Tasks unblocked from ISR before scheduler started */

/* Kernel state counters */
static volatile UBaseType_t uxCurrentNumberOfTasks = 0;
static volatile TickType_t  xTickCount = 0;
static volatile UBaseType_t uxTopReadyPriority = 0;
static volatile BaseType_t  xSchedulerRunning = pdFALSE;
static volatile TickType_t  xNextTaskUnblockTime = portMAX_DELAY;
```

### Context Switch Mechanism (ARM Cortex-M)

On ARM Cortex-M processors, FreeRTOS uses two system exceptions for context switching:

1. **SVC (Supervisor Call)** — Used once to start the first task
2. **PendSV (Pendable Service Call)** — Used for all subsequent context switches

PendSV is set to the lowest interrupt priority so that context switches never preempt application ISRs.

```
Task A running                    Task B running
     │                                 │
     ▼                                 ▼
[Tick IRQ fires]                       
     │                                 
     ├─ xTaskIncrementTick()           
     │   ├─ Increment xTickCount       
     │   ├─ Check delayed task list    
     │   ├─ Unblock tasks whose        
     │   │  wake-time has arrived      
     │   └─ Return pdTRUE if a         
     │      higher-priority task       
     │      was unblocked              
     │                                 
     ├─ If pdTRUE: set PendSV pending  
     │                                 
[Tick IRQ exits]                       
     │                                 
[PendSV fires — lowest priority]       
     │                                 
     ├─ Save Task A's registers        
     │  (R4-R11, LR) onto its stack    
     ├─ Store stack pointer in TCB     
     │  (pxCurrentTCB->pxTopOfStack)   
     │                                 
     ├─ Call vTaskSwitchContext()       
     │   └─ Select highest-priority    
     │      ready task → pxCurrentTCB  
     │                                 
     ├─ Load new pxTopOfStack          
     ├─ Restore Task B's registers     
     └─ Return from exception          
          → Task B resumes             
```

**PendSV Handler (ARM Cortex-M4F, simplified):**

```asm
PendSV_Handler:
    ; Hardware automatically saved R0-R3, R12, LR, PC, xPSR
    
    mrs   r0, psp                ; Get Process Stack Pointer
    isb
    
    stmdb r0!, {r4-r11, r14}    ; Save remaining registers onto task stack
    ; (r14/LR contains EXC_RETURN value needed for FPU lazy stacking)
    
    str   r0, [r2]              ; Save updated SP into pxCurrentTCB->pxTopOfStack
    
    stmdb sp!, {r0, r3}         ; Preserve r0, r3 on MSP
    mov   r0, #configMAX_SYSCALL_INTERRUPT_PRIORITY
    msr   basepri, r0           ; Enter critical section
    dsb
    isb
    bl    vTaskSwitchContext     ; Select next task to run
    mov   r0, #0
    msr   basepri, r0           ; Leave critical section
    ldmia sp!, {r0, r3}         ; Restore r0, r3
    
    ldr   r1, [r3]              ; r1 = pxCurrentTCB (updated by vTaskSwitchContext)
    ldr   r0, [r1]              ; r0 = pxCurrentTCB->pxTopOfStack
    
    ldmia r0!, {r4-r11, r14}    ; Restore new task's registers
    msr   psp, r0               ; Set PSP to new task's stack
    isb
    bx    r14                   ; Return from exception → resumes new task
```

---

## 3. FreeRTOS Configuration (FreeRTOSConfig.h)

Every FreeRTOS application must provide a `FreeRTOSConfig.h` header that tailors the kernel to the application. Below is a fully annotated configuration:

```c
#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

/* ───── Scheduler Behavior ───── */

/* 1 = preemptive scheduling, 0 = cooperative (tasks must explicitly yield) */
#define configUSE_PREEMPTION                     1

/* 1 = enable time-slicing: equal-priority tasks share CPU in round-robin.
   Only meaningful when configUSE_PREEMPTION == 1. */
#define configUSE_TIME_SLICING                   1

/* CPU clock frequency in Hz (used for tick timer configuration) */
#define configCPU_CLOCK_HZ                       ((uint32_t)168000000)

/* Tick rate in Hz. 1000 = 1 ms tick resolution. Lower values reduce overhead. */
#define configTICK_RATE_HZ                       ((TickType_t)1000)

/* Number of priority levels. Each level has its own ready list.
   Range: 1 to 56 (limited by bitmap scheduler optimization). */
#define configMAX_PRIORITIES                     16

/* Idle task stack size in words (not bytes). 
   128 words = 512 bytes on 32-bit architectures. */
#define configMINIMAL_STACK_SIZE                 ((uint16_t)128)

/* Maximum length of a task name string (including null terminator) */
#define configMAX_TASK_NAME_LEN                  16

/* TickType_t width: 0 = 16-bit, 1 = 32-bit.
   16-bit: max delay = 65535 ticks. 32-bit: max = ~49 days at 1 kHz. */
#define configUSE_16_BIT_TICKS                   0

/* 1 = the idle task yields if another idle-priority task is ready.
   Prevents idle-priority tasks from starving each other. */
#define configIDLE_SHOULD_YIELD                  1

/* ───── Memory ───── */

/* Total heap size available for kernel objects (tasks, queues, etc.) */
#define configTOTAL_HEAP_SIZE                    ((size_t)(64 * 1024))

/* 1 = tasks/queues/etc. allocated statically by the application.
   0 = the kernel allocates all objects from the heap. */
#define configSUPPORT_STATIC_ALLOCATION          1
#define configSUPPORT_DYNAMIC_ALLOCATION         1

/* ───── Feature Enables ───── */

#define configUSE_MUTEXES                        1
#define configUSE_RECURSIVE_MUTEXES              1
#define configUSE_COUNTING_SEMAPHORES            1
#define configUSE_QUEUE_SETS                     1
#define configUSE_TASK_NOTIFICATIONS             1
#define configTASK_NOTIFICATION_ARRAY_ENTRIES     3

/* ───── Software Timers ───── */

#define configUSE_TIMERS                         1
#define configTIMER_TASK_PRIORITY                 (configMAX_PRIORITIES - 1)
#define configTIMER_QUEUE_LENGTH                  16
#define configTIMER_TASK_STACK_DEPTH              (configMINIMAL_STACK_SIZE * 2)

/* ───── Debugging and Tracing ───── */

/* 1 = enable uxTaskGetSystemState() and vTaskList() for debugging */
#define configUSE_TRACE_FACILITY                 1

/* 1 = enable runtime statistics collection */
#define configGENERATE_RUN_TIME_STATS            1
#define portCONFIGURE_TIMER_FOR_RUN_TIME_STATS() vConfigureTimerForRunTimeStats()
#define portGET_RUN_TIME_COUNTER_VALUE()          ulGetRunTimeCounterValue()

/* 1 = enable vTaskGetRunTimeStats() formatted output */
#define configUSE_STATS_FORMATTING_FUNCTIONS     1

/* Stack overflow detection method:
   0 = disabled, 1 = check on context switch, 2 = fill pattern + check */
#define configCHECK_FOR_STACK_OVERFLOW           2

/* ───── Hook Functions ───── */

#define configUSE_IDLE_HOOK                      1  /* vApplicationIdleHook() called each idle cycle */
#define configUSE_TICK_HOOK                      0  /* vApplicationTickHook() called each tick */
#define configUSE_MALLOC_FAILED_HOOK             1  /* vApplicationMallocFailedHook() on alloc failure */

/* ───── ARM Cortex-M Specific ───── */

/* Interrupt priority configuration for Cortex-M.
   The kernel uses BASEPRI to create critical sections that don't disable
   all interrupts — only those at or below this priority level. */

/* Number of priority bits implemented by the hardware (STM32F4 = 4 bits) */
#define configPRIO_BITS                          4

/* Lowest interrupt priority (highest numeric value) */
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY          15

/* Highest ISR priority that can call FreeRTOS API functions.
   ISRs above this priority (lower numeric value) cannot call FreeRTOS APIs
   but will never be delayed by the kernel. */
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY     5

/* Convert library priorities to hardware register values */
#define configKERNEL_INTERRUPT_PRIORITY \
    (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
#define configMAX_SYSCALL_INTERRUPT_PRIORITY \
    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))

/* ───── API Function Inclusion ───── */
/* Set to 1 to include, 0 to exclude (reduces code size) */

#define INCLUDE_vTaskPrioritySet                 1
#define INCLUDE_uxTaskPriorityGet                1
#define INCLUDE_vTaskDelete                      1
#define INCLUDE_vTaskSuspend                     1
#define INCLUDE_vTaskDelayUntil                  1
#define INCLUDE_vTaskDelay                       1
#define INCLUDE_xTaskGetSchedulerState           1
#define INCLUDE_xTaskGetCurrentTaskHandle        1
#define INCLUDE_uxTaskGetStackHighWaterMark      1
#define INCLUDE_xTaskGetIdleTaskHandle           1
#define INCLUDE_eTaskGetState                    1
#define INCLUDE_xTimerPendFunctionCall           1
#define INCLUDE_xTaskAbortDelay                  1
#define INCLUDE_xTaskGetHandle                   1

/* Map FreeRTOS system handlers to CMSIS names */
#define vPortSVCHandler     SVC_Handler
#define xPortPendSVHandler  PendSV_Handler
#define xPortSysTickHandler SysTick_Handler

#endif /* FREERTOS_CONFIG_H */
```

### Key Configuration Trade-offs

| Setting | Low Value | High Value |
|---|---|---|
| `configTICK_RATE_HZ` | Lower CPU overhead, coarser timing | Finer timing resolution, more interrupts |
| `configMAX_PRIORITIES` | Less RAM (fewer ready lists) | Finer priority control |
| `configMINIMAL_STACK_SIZE` | Less RAM per task | Safer for complex call chains |
| `configTOTAL_HEAP_SIZE` | More RAM for application | More kernel objects possible |
| `configCHECK_FOR_STACK_OVERFLOW` | Zero overhead | Catches stack corruption early |

---

## 4. Task Management

Tasks are the fundamental unit of execution in FreeRTOS. Each task runs in its own context with its own stack, and the scheduler multiplexes the CPU among them.

### Task States

```
                    ┌─────────────────────────┐
                    │                         │
                    ▼                         │
              ┌──────────┐  vTaskSuspend()  ┌───────────┐
              │          │ ──────────────── │           │
  ┌──────────►│  Ready   │                  │ Suspended │
  │           │          │ ◄──────────────  │           │
  │           └──────────┘  vTaskResume()   └───────────┘
  │                │                              ▲
  │   Scheduler    │                              │
  │   selects      │                    vTaskSuspend()
  │   task         │                              │
  │                ▼                              │
  │           ┌──────────┐                        │
  │           │          │────────────────────────►│
  │           │ Running  │
  │           │          │────────┐
  │           └──────────┘        │
  │                │              │
  │   Queue/Semaphore/           vTaskDelay()
  │   EventGroup wait            or timed wait
  │                │              │
  │                ▼              │
  │           ┌──────────┐        │
  │           │          │◄───────┘
  └───────────│ Blocked  │
   Event or   │          │
   timeout    └──────────┘
```

**State Definitions:**

| State | Description |
|---|---|
| **Running** | Currently executing on the CPU. Exactly one task per core. |
| **Ready** | Eligible to run; waiting for the scheduler to select it. |
| **Blocked** | Waiting for a temporal event (delay) or synchronization event (queue/semaphore). Has an optional timeout. |
| **Suspended** | Removed from scheduling entirely. Only exits via `vTaskResume()` or `xTaskResumeFromISR()`. |

### Task Creation Functions

#### `xTaskCreate()` — Dynamic Task Creation

```c
BaseType_t xTaskCreate(
    TaskFunction_t      pxTaskCode,      /* Pointer to the task function */
    const char * const  pcName,          /* Descriptive name (debugging only) */
    const configSTACK_DEPTH_TYPE usStackDepth, /* Stack size in words */
    void * const        pvParameters,    /* Parameter passed to the task function */
    UBaseType_t         uxPriority,      /* Task priority (0 = lowest) */
    TaskHandle_t * const pxCreatedTask   /* Output: handle to the created task (or NULL) */
);
```

**Return values:** `pdPASS` on success, `errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY` on failure.

**What happens internally:**

1. Allocates memory for the TCB structure from the heap
2. Allocates memory for the task's stack from the heap
3. Initializes the stack with an initial context frame (simulates a function entry point)
4. Sets the task's priority and name in the TCB
5. Inserts the task's `xStateListItem` into the appropriate ready list
6. If the scheduler is running and the new task has higher priority than the current task, triggers a context switch

**Example:**

```c
void vSensorTask(void *pvParameters) {
    const TickType_t xDelay = pdMS_TO_TICKS(100);
    
    for (;;) {
        uint16_t reading = adc_read(ADC_CHANNEL_0);
        xQueueSend(xSensorQueue, &reading, portMAX_DELAY);
        vTaskDelay(xDelay);
    }
}

void main(void) {
    TaskHandle_t xSensorHandle;
    
    BaseType_t xResult = xTaskCreate(
        vSensorTask,        /* Function */
        "Sensor",           /* Name */
        256,                /* Stack: 256 words = 1024 bytes */
        NULL,               /* No parameter */
        2,                  /* Priority 2 */
        &xSensorHandle      /* Store handle */
    );
    
    configASSERT(xResult == pdPASS);
    vTaskStartScheduler();
}
```

#### `xTaskCreateStatic()` — Static Task Creation

```c
TaskHandle_t xTaskCreateStatic(
    TaskFunction_t      pxTaskCode,
    const char * const  pcName,
    const uint32_t      ulStackDepth,     /* Stack size in words */
    void * const        pvParameters,
    UBaseType_t         uxPriority,
    StackType_t * const puxStackBuffer,   /* Application-provided stack array */
    StaticTask_t * const pxTaskBuffer     /* Application-provided TCB memory */
);
```

**Return value:** The task handle, or `NULL` if `puxStackBuffer` or `pxTaskBuffer` is `NULL`.

**Advantages of static allocation:**
- Deterministic — no heap fragmentation risk
- All memory usage known at compile time
- Required for safety-critical systems (MISRA, DO-178C)
- Slightly faster creation (no `pvPortMalloc` call)

**Example:**

```c
#define SENSOR_STACK_SIZE 256

static StackType_t  xSensorStack[SENSOR_STACK_SIZE];
static StaticTask_t xSensorTCB;

void main(void) {
    TaskHandle_t xHandle = xTaskCreateStatic(
        vSensorTask,
        "Sensor",
        SENSOR_STACK_SIZE,
        NULL,
        2,
        xSensorStack,
        &xSensorTCB
    );
    
    configASSERT(xHandle != NULL);
    vTaskStartScheduler();
}
```

### Task Deletion

#### `vTaskDelete()`

```c
void vTaskDelete(TaskHandle_t xTaskToDelete);
```

- Pass `NULL` to delete the calling task itself
- The TCB and stack memory are freed by the **idle task** (not immediately)
- The task is removed from all kernel lists
- Any mutexes held by the deleted task are **not automatically released** — this is a common source of bugs

**Internal steps:**
1. Remove the task from its ready/blocked/suspended list
2. Remove the task from any event list (queue wait, etc.)
3. Increment `uxDeletedTasksWaitingCleanUp`
4. Add the TCB to `xTasksWaitingTermination` list
5. If the deleted task was the running task, trigger a context switch
6. The idle task periodically calls `prvCheckTasksWaitingTermination()` to free memory

### Task Delay Functions

#### `vTaskDelay()` — Relative Delay

```c
void vTaskDelay(const TickType_t xTicksToDelay);
```

Blocks the calling task for **at least** `xTicksToDelay` tick periods. The actual delay depends on when the calling tick occurs relative to the next tick interrupt.

**Internal steps:**
1. Calculate wake time: `xTickCount + xTicksToDelay`
2. Remove task from the ready list
3. Insert task into the delayed task list, sorted by wake time
4. If the wake time overflows, insert into the overflow delayed list instead
5. Update `xNextTaskUnblockTime` if this task will wake earlier than any currently delayed task
6. Yield to the scheduler

**Timing diagram showing jitter:**

```
Tick:    |-------|-------|-------|-------|-------|-------|
                    ▲                       ▲
                    │                       │
              vTaskDelay(3)          Actual wake
              called here           (3 full ticks later,
                                     but only 2.x ticks
                                     from call point)
```

#### `vTaskDelayUntil()` — Absolute Delay (Periodic Tasks)

```c
BaseType_t xTaskDelayUntil(
    TickType_t * const pxPreviousWakeTime,  /* In/out: last wake time */
    const TickType_t   xTimeIncrement       /* Period in ticks */
);
```

Produces precise periodic timing by compensating for the task's execution time:

```c
void vPeriodicTask(void *pvParameters) {
    TickType_t xLastWakeTime = xTaskGetTickCount();
    const TickType_t xPeriod = pdMS_TO_TICKS(50); /* 50 ms period */
    
    for (;;) {
        /* Task work here — takes variable time */
        process_data();
        
        /* Block until exactly xPeriod ticks since xLastWakeTime.
           xLastWakeTime is automatically updated. */
        xTaskDelayUntil(&xLastWakeTime, xPeriod);
    }
}
```

**Comparison:**

```
vTaskDelay(50ms):
  |--work(12ms)--|--delay 50ms--|--work(8ms)--|--delay 50ms--|
  Period = 62ms                  Period = 58ms  (INCONSISTENT)

xTaskDelayUntil(50ms):
  |--work(12ms)--|--38ms--|--work(8ms)--|--42ms--|
  Period = 50ms            Period = 50ms  (CONSISTENT)
```

### Task Priority Functions

#### `vTaskPrioritySet()`

```c
void vTaskPrioritySet(TaskHandle_t xTask, UBaseType_t uxNewPriority);
```

Changes a task's priority at runtime. If the task being modified (or any task) now has a higher priority than the running task, a context switch occurs immediately.

**Internal steps:**
1. If mutex priority inheritance is active, update `uxBasePriority` instead of `uxPriority`
2. Remove the task from its current ready list
3. Insert it into the ready list for the new priority
4. If the new priority is higher than the current task's priority, yield

#### `uxTaskPriorityGet()`

```c
UBaseType_t uxTaskPriorityGet(const TaskHandle_t xTask);
```

Returns the task's current priority (which may be elevated due to mutex inheritance).

### Task Suspension

#### `vTaskSuspend()` / `vTaskResume()` / `xTaskResumeFromISR()`

```c
void vTaskSuspend(TaskHandle_t xTaskToSuspend);
void vTaskResume(TaskHandle_t xTaskToResume);
BaseType_t xTaskResumeFromISR(TaskHandle_t xTaskToResume);
```

Suspended tasks are placed in `xSuspendedTaskList` and the scheduler completely ignores them until resumed. Unlike blocking, suspension has no timeout — it persists until explicitly reversed.

`xTaskResumeFromISR()` returns `pdTRUE` if the resumed task has a higher priority than the interrupted task (caller should then request a context switch using `portYIELD_FROM_ISR()`).

### Task Query Functions

| Function | Description |
|---|---|
| `xTaskGetCurrentTaskHandle()` | Returns the handle of the currently running task |
| `eTaskGetState(xTask)` | Returns the task's state: `eRunning`, `eReady`, `eBlocked`, `eSuspended`, `eDeleted` |
| `pcTaskGetName(xTask)` | Returns the task's name string |
| `uxTaskGetStackHighWaterMark(xTask)` | Returns the minimum free stack (in words) the task has ever had — used to tune stack sizes |
| `uxTaskGetNumberOfTasks()` | Returns total number of tasks in the system |
| `vTaskList(pcWriteBuffer)` | Writes a formatted table of all tasks (name, state, priority, stack HWM, task number) |
| `vTaskGetRunTimeStats(pcWriteBuffer)` | Writes a formatted table showing each task's absolute and percentage CPU usage |

### The Idle Task

The idle task is automatically created by `vTaskStartScheduler()` at priority 0 (the lowest). It:

1. Frees memory of deleted tasks (`prvCheckTasksWaitingTermination`)
2. Calls the idle hook function `vApplicationIdleHook()` if configured
3. Optionally enters a low-power mode via `portSUPPRESS_TICKS_AND_SLEEP()` (tickless idle)

The idle task must **never** block or be deleted.

---

## 5. The Scheduler: Internals and Algorithms

### `vTaskStartScheduler()`

```c
void vTaskStartScheduler(void);
```

**Internal steps:**

1. Create the idle task at priority `tskIDLE_PRIORITY` (0)
2. If `configUSE_TIMERS == 1`, create the timer daemon task
3. Disable interrupts
4. Set `xSchedulerRunning = pdTRUE`
5. Initialize the tick count to 0
6. Call `xPortStartScheduler()`:
   - Configure the SysTick timer for the tick interrupt
   - Set PendSV and SysTick to lowest interrupt priority
   - Start the first task via SVC instruction
   - This function **never returns** (execution continues inside the first task)

### Scheduling Algorithm

FreeRTOS uses a **fixed-priority preemptive scheduler** with optional time-slicing:

1. The highest-priority ready task always runs
2. If multiple tasks share the same priority and `configUSE_TIME_SLICING == 1`, they share the CPU in round-robin fashion (one tick per slice)
3. If `configUSE_PREEMPTION == 0`, context switches only occur when the running task blocks or yields

**Priority bitmap optimization (Cortex-M):**

When `configMAX_PRIORITIES <= 32`, FreeRTOS can use a hardware CLZ (Count Leading Zeros) instruction to find the highest-priority ready task in O(1) time instead of scanning all ready lists.

```c
/* The bitmap tracks which priority levels have ready tasks */
#define portRECORD_READY_PRIORITY(uxPriority, uxReadyPriorities) \
    (uxReadyPriorities) |= (1UL << (uxPriority))

#define portRESET_READY_PRIORITY(uxPriority, uxReadyPriorities) \
    (uxReadyPriorities) &= ~(1UL << (uxPriority))

/* Find highest priority using hardware CLZ instruction */
#define portGET_HIGHEST_PRIORITY(uxTopPriority, uxReadyPriorities) \
    (uxTopPriority) = (31UL - __clz((uxReadyPriorities)))
```

### `xTaskIncrementTick()` — The Tick Handler

Called from the SysTick ISR on every tick. This is one of the most important internal functions:

```c
BaseType_t xTaskIncrementTick(void) {
    BaseType_t xSwitchRequired = pdFALSE;
    
    if (xSchedulerRunning != pdFALSE) {
        /* 1. Increment the tick count */
        xTickCount++;
        
        /* 2. Check for tick count overflow — swap delayed lists */
        if (xTickCount == 0) {
            List_t *temp = pxDelayedTaskList;
            pxDelayedTaskList = pxOverflowDelayedTaskList;
            pxOverflowDelayedTaskList = temp;
            /* Recalculate xNextTaskUnblockTime from the new delayed list */
        }
        
        /* 3. Unblock tasks whose wake time has arrived */
        if (xTickCount >= xNextTaskUnblockTime) {
            for (;;) {
                /* Get the task at the head of the delayed list */
                TCB_t *pxTCB = listGET_OWNER_OF_HEAD_ENTRY(pxDelayedTaskList);
                TickType_t xItemValue = listGET_LIST_ITEM_VALUE(&(pxTCB->xStateListItem));
                
                if (xItemValue > xTickCount) {
                    xNextTaskUnblockTime = xItemValue;
                    break;
                }
                
                /* Remove from delayed list, add to ready list */
                uxListRemove(&(pxTCB->xStateListItem));
                /* Also remove from any event list (queue/semaphore wait) */
                if (listLIST_ITEM_CONTAINER(&(pxTCB->xEventListItem)) != NULL) {
                    uxListRemove(&(pxTCB->xEventListItem));
                }
                prvAddTaskToReadyList(pxTCB);
                
                /* If unblocked task has higher priority, request switch */
                if (pxTCB->uxPriority >= pxCurrentTCB->uxPriority) {
                    xSwitchRequired = pdTRUE;
                }
            }
        }
        
        /* 4. Time-slicing: switch between equal-priority tasks */
        #if (configUSE_TIME_SLICING == 1)
        if (listCURRENT_LIST_LENGTH(&(pxReadyTasksLists[pxCurrentTCB->uxPriority])) > 1) {
            xSwitchRequired = pdTRUE;
        }
        #endif
    }
    
    return xSwitchRequired;
}
```

### `vTaskSwitchContext()` — Select the Next Task

Called from PendSV to determine which task runs next:

```c
void vTaskSwitchContext(void) {
    /* Stack overflow check (if enabled) */
    taskCHECK_FOR_STACK_OVERFLOW();
    
    /* Update runtime statistics counter */
    #if (configGENERATE_RUN_TIME_STATS == 1)
        /* Accumulate time spent in the current task */
    #endif
    
    /* Select the highest priority ready task */
    taskSELECT_HIGHEST_PRIORITY_TASK();
    
    /* Trace hook for visualization tools */
    traceTASK_SWITCHED_IN();
}
```

`taskSELECT_HIGHEST_PRIORITY_TASK()` either:
- Uses the CLZ bitmap optimization (O(1)) on supported architectures, or
- Scans ready lists from highest to lowest priority (O(n) in number of priority levels)

### `taskYIELD()` / `portYIELD()`

Forces an immediate context switch without waiting for the next tick:

```c
/* Application-level yield */
#define taskYIELD()  portYIELD()

/* ARM Cortex-M implementation: trigger PendSV */
#define portYIELD()                         \
    {                                       \
        portNVIC_INT_CTRL_REG = portNVIC_PENDSVSET_BIT; \
        __dsb(portSY_FULL_READ_WRITE);      \
        __isb(portSY_FULL_READ_WRITE);      \
    }
```

### Critical Sections

FreeRTOS provides two levels of critical section:

#### Task-Level Critical Section

```c
taskENTER_CRITICAL();     /* Disables interrupts up to configMAX_SYSCALL_INTERRUPT_PRIORITY */
/* ... protected code ... */
taskEXIT_CRITICAL();      /* Restores previous interrupt state */
```

These can be **nested** — the kernel maintains a nesting counter and only re-enables interrupts when the outermost critical section exits.

#### ISR-Level Critical Section

```c
UBaseType_t uxSavedInterruptStatus = taskENTER_CRITICAL_FROM_ISR();
/* ... protected code inside ISR ... */
taskEXIT_CRITICAL_FROM_ISR(uxSavedInterruptStatus);
```

### Scheduler Suspension

For longer critical regions that shouldn't disable interrupts:

```c
vTaskSuspendAll();        /* Prevents context switches but allows interrupts */
/* ... code that must not be preempted ... */
xTaskResumeAll();         /* Resumes scheduling; processes any deferred operations */
```

While the scheduler is suspended:
- Tick interrupts still fire and increment a "pending ticks" counter
- ISRs that unblock tasks add them to `xPendingReadyList` instead of the ready list
- `xTaskResumeAll()` processes all pending ticks and moves tasks from `xPendingReadyList` to the appropriate ready lists

---

## 6. Queue Management

Queues are the primary inter-task and ISR-to-task communication mechanism in FreeRTOS. They are also the foundation for semaphores and mutexes.

### Queue Internals

```c
typedef struct QueueDefinition {
    int8_t  *pcHead;           /* Points to start of queue storage area */
    int8_t  *pcWriteTo;        /* Next free position for writing */
    int8_t  *pcReadFrom;       /* Last position read from */
    int8_t  *pcTail;           /* Points to one past end of storage area */
    
    List_t  xTasksWaitingToSend;    /* Tasks blocked on send (queue full) */
    List_t  xTasksWaitingToReceive; /* Tasks blocked on receive (queue empty) */
    
    volatile UBaseType_t uxMessagesWaiting; /* Current number of items */
    UBaseType_t uxLength;                   /* Maximum number of items */
    UBaseType_t uxItemSize;                 /* Size of each item in bytes */
    
    volatile int8_t cRxLock;    /* ISR lock count for receives */
    volatile int8_t cTxLock;    /* ISR lock count for sends */
    
    /* Additional fields for mutex support when queue is used as mutex */
    #if (configUSE_MUTEXES == 1)
        TaskHandle_t  xMutexHolder;
        UBaseType_t   uxQueueType;   /* queueQUEUE_TYPE_MUTEX, etc. */
    #endif
    
    /* Static allocation support */
    #if (configSUPPORT_STATIC_ALLOCATION == 1)
        uint8_t ucStaticallyAllocated;
    #endif
} xQUEUE;
```

**Queue storage layout in memory:**

```
                 pcHead                              pcTail
                   │                                   │
                   ▼                                   ▼
┌──────────┬──────────┬──────────┬──────────┬──────────┐
│  Item 0  │  Item 1  │  Item 2  │  Item 3  │  Item 4  │
│ (uxItemSize bytes each)                              │
└──────────┴──────────┴──────────┴──────────┴──────────┘
                          ▲           ▲
                          │           │
                     pcReadFrom   pcWriteTo
```

Queues implement a **circular buffer**. When `pcWriteTo` reaches `pcTail`, it wraps back to `pcHead`.

### Queue Creation

#### `xQueueCreate()` — Dynamic

```c
QueueHandle_t xQueueCreate(UBaseType_t uxQueueLength, UBaseType_t uxItemSize);
```

**Parameters:**
- `uxQueueLength`: Maximum number of items the queue can hold
- `uxItemSize`: Size of each item in bytes (items are copied, not referenced)

**Internal steps:**
1. Calculate total memory needed: `sizeof(Queue_t) + (uxQueueLength * uxItemSize)`
2. Allocate a single contiguous block from the heap
3. `pcHead` points to the storage area (immediately after the Queue_t structure)
4. Initialize both waiting lists (send and receive)
5. Call `xQueueGenericReset()` to set read/write pointers to `pcHead`

**Example:**

```c
/* Create a queue of 10 temperature readings (float) */
QueueHandle_t xTempQueue = xQueueCreate(10, sizeof(float));
configASSERT(xTempQueue != NULL);
```

#### `xQueueCreateStatic()` — Static

```c
QueueHandle_t xQueueCreateStatic(
    UBaseType_t          uxQueueLength,
    UBaseType_t          uxItemSize,
    uint8_t             *pucQueueStorageBuffer,  /* Application-provided storage */
    StaticQueue_t       *pxQueueBuffer           /* Application-provided queue struct */
);
```

### Queue Send Operations

#### `xQueueSend()` / `xQueueSendToBack()`

```c
BaseType_t xQueueSend(
    QueueHandle_t xQueue,
    const void    *pvItemToQueue,   /* Pointer to item to copy into queue */
    TickType_t    xTicksToWait      /* Max time to wait if queue is full */
);
```

**Internal algorithm (`xQueueGenericSend`):**

```
1. Enter critical section
2. if (queue has free space) {
       Copy item to *pcWriteTo (using memcpy)
       Advance pcWriteTo (wrap if needed)
       Increment uxMessagesWaiting
       
       if (any task is waiting to receive) {
           Remove highest-priority waiting task from xTasksWaitingToReceive
           Add it to the ready list
           if (its priority > current task's priority) {
               Request context switch
           }
       }
       Exit critical section
       return pdPASS
   }
3. if (xTicksToWait == 0) {
       Exit critical section
       return errQUEUE_FULL
   }
4. Place current task on xTasksWaitingToSend list
5. Place current task on the delayed task list (for timeout)
6. Exit critical section
7. Yield — task is now blocked
8. When unblocked: check if item was posted successfully or timed out
```

#### `xQueueSendToFront()`

```c
BaseType_t xQueueSendToFront(QueueHandle_t xQueue, const void *pvItemToQueue, TickType_t xTicksToWait);
```

Same as `xQueueSend` but copies the item to the read position (LIFO behavior instead of FIFO).

#### `xQueueOverwrite()`

```c
BaseType_t xQueueOverwrite(QueueHandle_t xQueue, const void *pvItemToQueue);
```

For queues of length 1 only. Writes an item regardless of whether the queue is full, overwriting the existing value. Never blocks. Useful for "latest value" patterns (e.g., most recent sensor reading).

#### ISR Variants

```c
BaseType_t xQueueSendFromISR(
    QueueHandle_t xQueue,
    const void    *pvItemToQueue,
    BaseType_t    *pxHigherPriorityTaskWoken  /* Out: pdTRUE if a context switch is needed */
);

BaseType_t xQueueSendToFrontFromISR(QueueHandle_t xQueue, const void *pvItemToQueue, BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xQueueSendToBackFromISR(QueueHandle_t xQueue, const void *pvItemToQueue, BaseType_t *pxHigherPriorityTaskWoken);
```

ISR variants **never block**. They use the queue's lock mechanism to defer list manipulations:

1. If the queue is locked (a task has it locked for a non-ISR critical section), the ISR increments `cTxLock` instead of directly modifying lists
2. When the queue is unlocked, `prvUnlockQueue()` processes the deferred operations

### Queue Receive Operations

#### `xQueueReceive()`

```c
BaseType_t xQueueReceive(
    QueueHandle_t xQueue,
    void          *pvBuffer,        /* Destination buffer for the received item */
    TickType_t    xTicksToWait      /* Max time to wait if queue is empty */
);
```

Copies the item from the queue into `pvBuffer` and removes it from the queue.

#### `xQueuePeek()`

```c
BaseType_t xQueuePeek(QueueHandle_t xQueue, void *pvBuffer, TickType_t xTicksToWait);
```

Same as `xQueueReceive` but does **not** remove the item from the queue. If multiple tasks are peeking on the same queue, they all see the same front item.

#### ISR Variant

```c
BaseType_t xQueueReceiveFromISR(QueueHandle_t xQueue, void *pvBuffer, BaseType_t *pxHigherPriorityTaskWoken);
```

### Queue Query Functions

| Function | Description |
|---|---|
| `uxQueueMessagesWaiting(xQueue)` | Number of items currently in the queue |
| `uxQueueSpacesAvailable(xQueue)` | Number of free slots |
| `xQueueIsQueueFullFromISR(xQueue)` | Is the queue full? (ISR-safe) |
| `xQueueIsQueueEmptyFromISR(xQueue)` | Is the queue empty? (ISR-safe) |
| `vQueueDelete(xQueue)` | Delete the queue and free its memory |
| `xQueueReset(xQueue)` | Reset queue to empty state |

### Queue Sets

Queue sets allow a task to block waiting for data on **any one of multiple queues or semaphores**:

```c
/* Create a set that can hold events from 2 queues */
QueueSetHandle_t xQueueSet = xQueueCreateSet(QUEUE1_LENGTH + QUEUE2_LENGTH);

/* Add queues to the set */
xQueueAddToSet(xQueue1, xQueueSet);
xQueueAddToSet(xQueue2, xQueueSet);

/* Wait for data on any queue in the set */
QueueSetMemberHandle_t xActiveMember = xQueueSelectFromSet(xQueueSet, portMAX_DELAY);

if (xActiveMember == xQueue1) {
    xQueueReceive(xQueue1, &data1, 0);
} else if (xActiveMember == xQueue2) {
    xQueueReceive(xQueue2, &data2, 0);
}
```

---

## 7. Semaphores

Semaphores are built on the queue infrastructure with `uxItemSize = 0` (no data is stored — only the count matters).

### Binary Semaphore

A binary semaphore has a maximum count of 1. It is primarily used for **ISR-to-task synchronization** (deferred interrupt processing).

#### Creation

```c
/* Dynamic */
SemaphoreHandle_t xSemaphoreCreateBinary(void);

/* Static */
SemaphoreHandle_t xSemaphoreCreateBinaryStatic(StaticSemaphore_t *pxSemaphoreBuffer);
```

**Internal implementation:**
- Creates a queue with `uxQueueLength = 1` and `uxItemSize = 0`
- Initial state: **empty** (not available) — you must "give" it before the first "take"

#### Operations

```c
/* Release (give) the semaphore — increments count (max 1) */
BaseType_t xSemaphoreGive(SemaphoreHandle_t xSemaphore);

/* Acquire (take) the semaphore — decrements count; blocks if count == 0 */
BaseType_t xSemaphoreTake(SemaphoreHandle_t xSemaphore, TickType_t xTicksToWait);

/* ISR variants */
BaseType_t xSemaphoreGiveFromISR(SemaphoreHandle_t xSemaphore, BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xSemaphoreTakeFromISR(SemaphoreHandle_t xSemaphore, BaseType_t *pxHigherPriorityTaskWoken);
```

**Deferred interrupt processing pattern:**

```c
SemaphoreHandle_t xUARTSemaphore;

void UART_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    
    /* Clear interrupt flag, save received byte to buffer */
    uart_clear_interrupt();
    
    /* Signal the processing task */
    xSemaphoreGiveFromISR(xUARTSemaphore, &xHigherPriorityTaskWoken);
    
    /* Request context switch if a higher-priority task was woken */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void vUARTProcessingTask(void *pvParameters) {
    for (;;) {
        /* Block until the ISR gives the semaphore */
        xSemaphoreTake(xUARTSemaphore, portMAX_DELAY);
        
        /* Process received data (heavy work done here, not in ISR) */
        process_uart_data();
    }
}
```

### Counting Semaphore

A counting semaphore has a configurable maximum count. Common uses:

1. **Event counting** — count events that occur faster than they can be processed
2. **Resource management** — track a limited number of identical resources

#### Creation

```c
SemaphoreHandle_t xSemaphoreCreateCounting(
    UBaseType_t uxMaxCount,      /* Maximum count value */
    UBaseType_t uxInitialCount   /* Starting count */
);
```

**Internal implementation:**
- Creates a queue with `uxQueueLength = uxMaxCount` and `uxItemSize = 0`
- Sets `uxMessagesWaiting = uxInitialCount`

**Resource pool example:**

```c
#define NUM_DMA_CHANNELS 4
SemaphoreHandle_t xDMASemaphore = xSemaphoreCreateCounting(NUM_DMA_CHANNELS, NUM_DMA_CHANNELS);

void vDMAUser(void *pvParameters) {
    for (;;) {
        /* Wait for an available DMA channel */
        xSemaphoreTake(xDMASemaphore, portMAX_DELAY);
        
        int channel = allocate_dma_channel();
        perform_dma_transfer(channel);
        release_dma_channel(channel);
        
        /* Release the DMA channel back to the pool */
        xSemaphoreGive(xDMASemaphore);
    }
}
```

### Binary Semaphore vs Mutex — When to Use Which

| Aspect | Binary Semaphore | Mutex |
|---|---|---|
| Ownership | No concept of ownership | Owner = the task that took it |
| Priority inheritance | No | Yes |
| Can give from ISR | Yes | No (undefined behavior) |
| Can be given by different task | Yes | No (must be given by the taker) |
| Primary use | ISR-to-task signaling | Mutual exclusion |
| Recursive taking | No | Yes (recursive mutex only) |

---

## 8. Mutexes and Priority Inheritance

### Standard Mutex

A mutex (mutual exclusion) is a special type of binary semaphore with ownership tracking and **priority inheritance**.

#### Creation

```c
SemaphoreHandle_t xSemaphoreCreateMutex(void);
SemaphoreHandle_t xSemaphoreCreateMutexStatic(StaticSemaphore_t *pxMutexBuffer);
```

**Internal implementation:**
- Creates a queue with `uxQueueLength = 1`, `uxItemSize = 0`
- Sets `uxQueueType` to `queueQUEUE_TYPE_MUTEX`
- Initial state: **available** (count = 1) — opposite of binary semaphore
- Tracks `xMutexHolder` (the TCB of the task that holds the mutex)

#### The Priority Inheritance Protocol

Priority inheritance solves the **priority inversion** problem:

```
Without priority inheritance:

Priority:  High──┐    Medium──────────────┐    Low───────────┐
                  │              │                      │
Time →            │              │                      │
                  ▼              ▼                      ▼
Low task:    [takes mutex]─────────────[releases mutex]
Medium task:              [runs and preempts Low]──────
High task:       [blocks on mutex]......................[finally runs]
                  ▲
                  Problem: High-priority task is blocked by Medium
                  (which doesn't even use the mutex!)

With priority inheritance:

Low task:    [takes mutex]──[priority raised to High]──[releases; priority restored]
Medium task:              [cannot preempt — Low is now High priority]
High task:       [blocks on mutex]──[runs immediately when mutex released]
                                    ▲
                                    High blocked for minimum time
```

**How it works internally (`xQueueSemaphoreTake`):**

1. When a high-priority task attempts to take a mutex held by a lower-priority task:
   - The kernel raises the holding task's `uxPriority` to match the waiting task's priority
   - The holding task is moved to the appropriate higher-priority ready list
2. When the holding task releases the mutex:
   - Its `uxPriority` is restored to `uxBasePriority`
   - The highest-priority task waiting for the mutex is unblocked

**Priority inheritance is not a general solution to priority inversion** — it only handles direct inversion. For chains of resource dependencies, consider redesigning the system or using priority ceiling protocol (not built into FreeRTOS).

### Recursive Mutex

A recursive mutex can be taken multiple times by the **same** task without deadlocking:

```c
SemaphoreHandle_t xSemaphoreCreateRecursiveMutex(void);

/* Must use recursive-specific APIs */
BaseType_t xSemaphoreTakeRecursive(SemaphoreHandle_t xMutex, TickType_t xTicksToWait);
BaseType_t xSemaphoreGiveRecursive(SemaphoreHandle_t xMutex);
```

**Internal tracking:** The kernel maintains a recursion counter. The mutex is only truly released when the counter reaches zero (i.e., every take has a matching give).

**Example — protecting a shared resource from nested calls:**

```c
SemaphoreHandle_t xDisplayMutex;

void display_write_string(const char *str) {
    xSemaphoreTakeRecursive(xDisplayMutex, portMAX_DELAY);
    while (*str) {
        display_write_char(*str++);
    }
    xSemaphoreGiveRecursive(xDisplayMutex);
}

void display_write_int(int value) {
    char buf[12];
    snprintf(buf, sizeof(buf), "%d", value);
    xSemaphoreTakeRecursive(xDisplayMutex, portMAX_DELAY);
    display_write_string(buf);   /* Nested take — works because recursive */
    xSemaphoreGiveRecursive(xDisplayMutex);
}
```

### Mutex Holder Query

```c
TaskHandle_t xSemaphoreGetMutexHolder(SemaphoreHandle_t xMutex);
TaskHandle_t xSemaphoreGetMutexHolderFromISR(SemaphoreHandle_t xMutex);
```

Returns the task currently holding the mutex, or `NULL` if it is available. Useful for debugging deadlocks.

---

## 9. Event Groups

Event groups provide a mechanism for tasks to wait on a **combination of events** (represented as individual bits in a group). They are more efficient than using multiple binary semaphores when you need AND/OR synchronization.

### Internal Structure

```c
typedef struct EventGroupDef_t {
    EventBits_t  uxEventBits;              /* The event bit storage */
    List_t       xTasksWaitingForBits;     /* Tasks blocked waiting for bits */
    
    #if (configSUPPORT_STATIC_ALLOCATION == 1)
        uint8_t  ucStaticallyAllocated;
    #endif
} EventGroup_t;
```

`EventBits_t` is typically 24 bits (if `configUSE_16_BIT_TICKS == 0`) because the upper 8 bits of the 32-bit word are used internally by the kernel for control flags.

### Event Group API

#### Creation

```c
EventGroupHandle_t xEventGroupCreate(void);
EventGroupHandle_t xEventGroupCreateStatic(StaticEventGroup_t *pxEventGroupBuffer);
```

#### Setting Bits

```c
/* From a task */
EventBits_t xEventGroupSetBits(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToSet      /* Bit mask: e.g. 0x05 sets bits 0 and 2 */
);

/* From an ISR (processed via the timer daemon task) */
BaseType_t xEventGroupSetBitsFromISR(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToSet,
    BaseType_t        *pxHigherPriorityTaskWoken
);
```

**Why `xEventGroupSetBitsFromISR` uses the timer daemon:**

Setting event bits can unblock multiple tasks simultaneously. The kernel needs to evaluate each waiting task's condition (AND/OR) and potentially clear bits — this requires extended processing that should not occur inside an ISR. Instead, the ISR sends a command to the timer daemon queue, and the daemon executes the bit-setting operation in task context.

#### Waiting for Bits

```c
EventBits_t xEventGroupWaitBits(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToWaitFor,   /* Which bits to test */
    const BaseType_t   xClearOnExit,      /* pdTRUE = clear matched bits on exit */
    const BaseType_t   xWaitForAllBits,   /* pdTRUE = AND (all bits), pdFALSE = OR (any bit) */
    TickType_t         xTicksToWait
);
```

**Returns:** The event bits at the time the condition was met or the timeout expired. You must check whether your bits are actually set (the return could be due to timeout).

**Internal algorithm:**

1. Enter critical section
2. Read current event bits
3. Test condition (AND or OR) against `uxBitsToWaitFor`
4. If condition met:
   - If `xClearOnExit`: clear the matched bits
   - Return the event bits
5. If condition not met and `xTicksToWait > 0`:
   - Store the wait condition in the upper bits of the task's `xEventListItem.xItemValue`
   - Place the task on `xTasksWaitingForBits` list
   - Place the task on the delayed task list
   - Yield
6. When unblocked: re-read bits, optionally clear, return

#### Clearing Bits

```c
EventBits_t xEventGroupClearBits(EventGroupHandle_t xEventGroup, const EventBits_t uxBitsToClear);
EventBits_t xEventGroupClearBitsFromISR(EventGroupHandle_t xEventGroup, const EventBits_t uxBitsToClear);
```

#### Task Synchronization (Rendezvous)

```c
EventBits_t xEventGroupSync(
    EventGroupHandle_t xEventGroup,
    const EventBits_t  uxBitsToSet,        /* Bits this task sets (its "arrival" signal) */
    const EventBits_t  uxBitsToWaitFor,    /* Bits to wait for (all other tasks' signals) */
    TickType_t         xTicksToWait
);
```

`xEventGroupSync` atomically sets the calling task's bits and then waits for all `uxBitsToWaitFor` bits to be set. All matched bits are cleared on exit. This implements a **barrier synchronization** pattern.

**Example — three tasks synchronize before proceeding:**

```c
#define TASK_0_BIT (1 << 0)
#define TASK_1_BIT (1 << 1)
#define TASK_2_BIT (1 << 2)
#define ALL_SYNC_BITS (TASK_0_BIT | TASK_1_BIT | TASK_2_BIT)

void vTask0(void *pvParameters) {
    for (;;) {
        /* Do initialization work... */
        
        /* Signal that this task is ready and wait for others */
        xEventGroupSync(xSyncEvent, TASK_0_BIT, ALL_SYNC_BITS, portMAX_DELAY);
        
        /* All three tasks are synchronized here */
        /* Continue with synchronized work... */
    }
}
```

---

## 10. Software Timers

Software timers execute a callback function at a specified time in the future, either once (one-shot) or periodically (auto-reload). They run in the context of the **timer daemon task** (also called the timer service task).

### Timer Daemon Task Architecture

```
                    ┌──────────────────────────────────┐
  xTimerCreate()    │       Timer Command Queue        │   Timer Daemon Task
  xTimerStart()  ──►│  ┌─────┬─────┬─────┬─────┐      │──► Processes commands
  xTimerStop()      │  │ Cmd │ Cmd │ Cmd │ ... │      │    Calls callbacks
  xTimerReset()     │  └─────┴─────┴─────┴─────┘      │    Manages timer list
                    └──────────────────────────────────┘
                    
  Timer list (sorted by expiry time):
  ┌──────────┐   ┌──────────┐   ┌──────────┐
  │ Timer A  │──►│ Timer B  │──►│ Timer C  │
  │ exp: 150 │   │ exp: 200 │   │ exp: 350 │
  └──────────┘   └──────────┘   └──────────┘
```

All timer API functions (except creation) work by sending commands to a queue. The timer daemon task blocks on this queue and processes commands one at a time.

**Implications:**
- Timer callbacks execute in the daemon task's context — they must not block
- The daemon task priority (`configTIMER_TASK_PRIORITY`) determines how quickly timer callbacks execute
- If the command queue is full, timer commands will block or fail
- Timer callback execution time adds to the daemon task's execution time, potentially delaying other timers

### Timer API

#### Creation

```c
TimerHandle_t xTimerCreate(
    const char * const  pcTimerName,
    TickType_t          xTimerPeriodInTicks,
    UBaseType_t         uxAutoReload,        /* pdTRUE = auto-reload, pdFALSE = one-shot */
    void * const        pvTimerID,           /* User-defined ID (can be any pointer) */
    TimerCallbackFunction_t pxCallbackFunction
);

TimerHandle_t xTimerCreateStatic(
    const char * const  pcTimerName,
    TickType_t          xTimerPeriodInTicks,
    UBaseType_t         uxAutoReload,
    void * const        pvTimerID,
    TimerCallbackFunction_t pxCallbackFunction,
    StaticTimer_t      *pxTimerBuffer
);
```

**The callback function signature:**

```c
void vTimerCallback(TimerHandle_t xTimer);
```

The timer handle is passed to the callback so the same callback can serve multiple timers (use `pvTimerGetTimerID()` to distinguish them).

#### Start, Stop, Reset

```c
/* Start a timer (begins counting from now). If already running, resets the count. */
BaseType_t xTimerStart(TimerHandle_t xTimer, TickType_t xTicksToWait);

/* Stop a timer (cancels any pending expiry) */
BaseType_t xTimerStop(TimerHandle_t xTimer, TickType_t xTicksToWait);

/* Reset a timer (restarts the period from now) */
BaseType_t xTimerReset(TimerHandle_t xTimer, TickType_t xTicksToWait);

/* Change the period of a running timer */
BaseType_t xTimerChangePeriod(TimerHandle_t xTimer, TickType_t xNewPeriodInTicks, TickType_t xTicksToWait);

/* ISR variants */
BaseType_t xTimerStartFromISR(TimerHandle_t xTimer, BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xTimerStopFromISR(TimerHandle_t xTimer, BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xTimerResetFromISR(TimerHandle_t xTimer, BaseType_t *pxHigherPriorityTaskWoken);
BaseType_t xTimerChangePeriodFromISR(TimerHandle_t xTimer, TickType_t xNewPeriod, BaseType_t *pxHigherPriorityTaskWoken);
```

The `xTicksToWait` parameter is the time to wait if the timer command queue is full (not the timer period).

#### Timer Query Functions

```c
void       *pvTimerGetTimerID(TimerHandle_t xTimer);         /* Get user ID */
void        vTimerSetTimerID(TimerHandle_t xTimer, void *pvNewID);  /* Set user ID */
const char *pcTimerGetName(TimerHandle_t xTimer);             /* Get timer name */
TickType_t  xTimerGetPeriod(TimerHandle_t xTimer);            /* Get period */
TickType_t  xTimerGetExpiryTime(TimerHandle_t xTimer);        /* Get expiry tick */
BaseType_t  xTimerIsTimerActive(TimerHandle_t xTimer);        /* Is timer running? */
```

#### Pending Function Calls

You can use the timer daemon to execute arbitrary functions in task context:

```c
BaseType_t xTimerPendFunctionCall(
    PendedFunction_t    xFunctionToPend,
    void               *pvParameter1,
    uint32_t            ulParameter2,
    TickType_t          xTicksToWait
);

BaseType_t xTimerPendFunctionCallFromISR(
    PendedFunction_t    xFunctionToPend,
    void               *pvParameter1,
    uint32_t            ulParameter2,
    BaseType_t         *pxHigherPriorityTaskWoken
);
```

This is useful for deferring work from an ISR to task context without creating a dedicated task.

**Example — LED heartbeat timer:**

```c
void vLEDTimerCallback(TimerHandle_t xTimer) {
    static BaseType_t xLEDState = pdFALSE;
    xLEDState = !xLEDState;
    gpio_write(LED_PIN, xLEDState);
}

void main(void) {
    TimerHandle_t xLEDTimer = xTimerCreate(
        "LED",                          /* Name */
        pdMS_TO_TICKS(500),             /* 500ms period */
        pdTRUE,                         /* Auto-reload */
        NULL,                           /* No ID needed */
        vLEDTimerCallback               /* Callback */
    );
    
    xTimerStart(xLEDTimer, 0);
    vTaskStartScheduler();
}
```

---

## 11. Task Notifications

Task notifications are a lightweight, fast alternative to binary semaphores, counting semaphores, event groups, and small queues. Each task has a built-in array of notification values (configurable size via `configTASK_NOTIFICATION_ARRAY_ENTRIES`, default 1).

### Performance Advantage

Task notifications are **45% faster** than equivalent semaphore operations and use **8 bytes less RAM** per notification (no queue structure needed). The notification value and state are stored directly in the TCB.

### Notification States

Each notification slot has three states:

| State | Meaning |
|---|---|
| `taskNOT_WAITING_NOTIFICATION` | Task is not waiting for a notification on this slot |
| `taskWAITING_NOTIFICATION` | Task is blocked waiting for a notification |
| `taskNOTIFICATION_RECEIVED` | A notification has been received but not yet consumed |

### Notification API

#### Sending Notifications

```c
/* Simplified API (uses notification index 0) */
BaseType_t xTaskNotifyGive(TaskHandle_t xTaskToNotify);
void       vTaskNotifyGiveFromISR(TaskHandle_t xTaskToNotify, BaseType_t *pxHigherPriorityTaskWoken);

/* Full API with action control */
BaseType_t xTaskNotify(
    TaskHandle_t  xTaskToNotify,
    uint32_t      ulValue,
    eNotifyAction eAction
);

BaseType_t xTaskNotifyFromISR(
    TaskHandle_t  xTaskToNotify,
    uint32_t      ulValue,
    eNotifyAction eAction,
    BaseType_t   *pxHigherPriorityTaskWoken
);

/* Indexed variants (for notification slots 0..N-1) */
BaseType_t xTaskNotifyIndexed(TaskHandle_t xTaskToNotify, UBaseType_t uxIndexToNotify, uint32_t ulValue, eNotifyAction eAction);
BaseType_t xTaskNotifyGiveIndexed(TaskHandle_t xTaskToNotify, UBaseType_t uxIndexToNotify);
```

#### Notification Actions (`eNotifyAction`)

| Action | Effect on `ulNotifiedValue` |
|---|---|
| `eNoAction` | Does not change the value; simply unblocks the target task |
| `eSetBits` | Bitwise OR: `ulNotifiedValue |= ulValue` (like event group bits) |
| `eIncrement` | Increment: `ulNotifiedValue++` (like counting semaphore) |
| `eSetValueWithOverwrite` | Set: `ulNotifiedValue = ulValue` (like queue overwrite) |
| `eSetValueWithoutOverwrite` | Set only if current state is not "received" (like queue send) |

#### Receiving Notifications

```c
/* Simplified API (uses notification index 0, acts as counting semaphore) */
uint32_t ulTaskNotifyTake(
    BaseType_t xClearCountOnExit,    /* pdTRUE = clear to 0, pdFALSE = decrement */
    TickType_t xTicksToWait
);

/* Full API with bit clearing */
BaseType_t xTaskNotifyWait(
    uint32_t   ulBitsToClearOnEntry,  /* Bits to clear before checking */
    uint32_t   ulBitsToClearOnExit,   /* Bits to clear after receiving */
    uint32_t  *pulNotificationValue,  /* Output: the notification value */
    TickType_t xTicksToWait
);

/* Indexed variants */
uint32_t   ulTaskNotifyTakeIndexed(UBaseType_t uxIndexToWaitOn, BaseType_t xClearCountOnExit, TickType_t xTicksToWait);
BaseType_t xTaskNotifyWaitIndexed(UBaseType_t uxIndexToWaitOn, uint32_t ulBitsToClearOnEntry, uint32_t ulBitsToClearOnExit, uint32_t *pulNotificationValue, TickType_t xTicksToWait);
```

#### State Query

```c
BaseType_t xTaskNotifyStateClear(TaskHandle_t xTask);
uint32_t   ulTaskNotifyValueClear(TaskHandle_t xTask, uint32_t ulBitsToClear);
```

### Task Notifications as Binary Semaphore

```c
/* Producer (ISR) */
void EXTI_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    vTaskNotifyGiveFromISR(xButtonTaskHandle, &xHigherPriorityTaskWoken);
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

/* Consumer (task) */
void vButtonTask(void *pvParameters) {
    for (;;) {
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);  /* Clear on exit = binary */
        handle_button_press();
    }
}
```

### Task Notifications as Event Group

```c
#define BIT_WIFI_CONNECTED  (1 << 0)
#define BIT_NTP_SYNCED      (1 << 1)
#define BIT_SENSOR_READY    (1 << 2)

/* Sender */
xTaskNotify(xMainTaskHandle, BIT_WIFI_CONNECTED, eSetBits);

/* Receiver */
void vMainTask(void *pvParameters) {
    uint32_t ulNotifiedValue;
    
    xTaskNotifyWait(
        0x00,             /* Don't clear on entry */
        0xFFFFFFFF,       /* Clear all on exit */
        &ulNotifiedValue, /* Receive value */
        portMAX_DELAY
    );
    
    if (ulNotifiedValue & BIT_WIFI_CONNECTED) { /* ... */ }
    if (ulNotifiedValue & BIT_NTP_SYNCED) { /* ... */ }
}
```

### Limitations of Task Notifications

1. **Unidirectional**: Only one task can receive (the target task); multiple tasks can send
2. **No broadcast**: Cannot wake multiple tasks with a single notification
3. **No queue depth**: `eSetValueWithoutOverwrite` fails if a notification is already pending
4. **Cannot be used before task is created**: The sending task must have the target's handle

---

## 12. Stream Buffers and Message Buffers

Stream buffers and message buffers provide optimized, single-reader/single-writer byte-stream and message-passing mechanisms, ideal for DMA-to-task or ISR-to-task data transfer.

### Stream Buffer

A stream buffer transfers a continuous stream of bytes from one writer to one reader. There is no concept of discrete messages — data is treated as a byte stream (like a UART FIFO).

```c
/* Creation */
StreamBufferHandle_t xStreamBufferCreate(
    size_t  xBufferSizeBytes,       /* Total buffer size */
    size_t  xTriggerLevelBytes      /* Minimum bytes before reader is unblocked */
);

/* Writing */
size_t xStreamBufferSend(
    StreamBufferHandle_t xStreamBuffer,
    const void          *pvTxData,
    size_t               xDataLengthBytes,
    TickType_t           xTicksToWait
);

size_t xStreamBufferSendFromISR(
    StreamBufferHandle_t xStreamBuffer,
    const void          *pvTxData,
    size_t               xDataLengthBytes,
    BaseType_t          *pxHigherPriorityTaskWoken
);

/* Reading */
size_t xStreamBufferReceive(
    StreamBufferHandle_t xStreamBuffer,
    void                *pvRxData,
    size_t               xBufferLengthBytes,
    TickType_t           xTicksToWait
);

size_t xStreamBufferReceiveFromISR(
    StreamBufferHandle_t xStreamBuffer,
    void                *pvRxData,
    size_t               xBufferLengthBytes,
    BaseType_t          *pxHigherPriorityTaskWoken
);

/* Query and control */
size_t     xStreamBufferBytesAvailable(StreamBufferHandle_t xStreamBuffer);
size_t     xStreamBufferSpacesAvailable(StreamBufferHandle_t xStreamBuffer);
BaseType_t xStreamBufferSetTriggerLevel(StreamBufferHandle_t xStreamBuffer, size_t xTriggerLevel);
BaseType_t xStreamBufferReset(StreamBufferHandle_t xStreamBuffer);
BaseType_t xStreamBufferIsEmpty(StreamBufferHandle_t xStreamBuffer);
BaseType_t xStreamBufferIsFull(StreamBufferHandle_t xStreamBuffer);
```

**Trigger level:** The reader is only unblocked when the buffer contains at least `xTriggerLevelBytes` bytes. This reduces unnecessary context switches when receiving small amounts of data.

### Message Buffer

A message buffer is a stream buffer with added **length framing**. Each write produces a discrete message that is read as a complete unit.

```c
/* Creation */
MessageBufferHandle_t xMessageBufferCreate(size_t xBufferSizeBytes);

/* Writing (one complete message) */
size_t xMessageBufferSend(
    MessageBufferHandle_t xMessageBuffer,
    const void           *pvTxData,
    size_t                xDataLengthBytes,
    TickType_t            xTicksToWait
);

/* Reading (one complete message) */
size_t xMessageBufferReceive(
    MessageBufferHandle_t xMessageBuffer,
    void                 *pvRxData,
    size_t                xBufferLengthBytes,   /* Must be >= message size */
    TickType_t            xTicksToWait
);
```

**Internal implementation:** Each message is stored as `[4-byte length header][message data]`. The buffer overhead per message is `sizeof(size_t)` bytes.

**Example — passing variable-length log messages:**

```c
MessageBufferHandle_t xLogBuffer;

void vSensorTask(void *pvParameters) {
    char msg[64];
    int len = snprintf(msg, sizeof(msg), "Temp: %.1f C", read_temperature());
    
    xMessageBufferSend(xLogBuffer, msg, len, pdMS_TO_TICKS(10));
}

void vLogTask(void *pvParameters) {
    char rxBuf[128];
    for (;;) {
        size_t xReceivedBytes = xMessageBufferReceive(xLogBuffer, rxBuf, sizeof(rxBuf), portMAX_DELAY);
        rxBuf[xReceivedBytes] = '\0';
        uart_transmit_string(rxBuf);
    }
}
```

---

## 13. Memory Management

FreeRTOS provides five heap allocation implementations. You link exactly one into your project.

### Heap Scheme Comparison

| Scheme | Allocation | Free | Coalescence | Deterministic | Best For |
|---|---|---|---|---|---|
| heap_1 | Yes | No | N/A | Yes (constant time) | Tasks/queues created once at startup |
| heap_2 | Yes | Yes | No | No (best-fit search) | Fixed-size allocations only |
| heap_3 | Yes | Yes | Yes | No (depends on libc) | Existing codebase using malloc/free |
| heap_4 | Yes | Yes | Yes | No (first-fit search) | General purpose (most common choice) |
| heap_5 | Yes | Yes | Yes | No (first-fit search) | Non-contiguous memory regions |

### heap_1 — Allocate Only

```c
void *pvPortMalloc(size_t xWantedSize);  /* Bumps a pointer; returns NULL if exhausted */
void  vPortFree(void *pv);               /* Does nothing (no-op) */
```

**Internals:**
- Maintains a single pointer (`pucAlignedHeap`) into a static array
- Each allocation bumps the pointer forward by the aligned size
- Total allocated tracked in `xFreeBytesRemaining`
- Thread-safe via `vTaskSuspendAll()` / `xTaskResumeAll()`

**Use case:** Systems where all kernel objects are created at startup and never deleted.

### heap_2 — Best Fit, No Coalescence

Uses a linked list of free blocks, sorted by size. Allocations search for the smallest block that fits (best-fit). Freed blocks are returned to the free list but adjacent free blocks are never merged.

**Use case:** Repeated allocation and freeing of **same-sized** blocks (e.g., fixed-size message buffers). Will fragment with varying sizes.

### heap_3 — Wrapped malloc/free

```c
void *pvPortMalloc(size_t xWantedSize) {
    void *pvReturn;
    vTaskSuspendAll();          /* Thread safety */
    pvReturn = malloc(xWantedSize);
    xTaskResumeAll();
    return pvReturn;
}

void vPortFree(void *pv) {
    vTaskSuspendAll();
    free(pv);
    xTaskResumeAll();
}
```

**Use case:** When you want to use the toolchain's standard malloc (e.g., for newlib compatibility). `configTOTAL_HEAP_SIZE` is **not used** — heap size is controlled by the linker script.

### heap_4 — First Fit with Coalescence (Recommended)

```c
/* Internal free block structure */
typedef struct A_BLOCK_LINK {
    struct A_BLOCK_LINK *pxNextFreeBlock;  /* Next free block in the list */
    size_t               xBlockSize;       /* Size of this block including header */
} BlockLink_t;
```

**Allocation algorithm:**
1. Traverse the free list (sorted by address)
2. Find the first block large enough (`xBlockSize >= xWantedSize + heapSTRUCT_SIZE`)
3. If the block is significantly larger than needed, split it
4. Return the memory after the `BlockLink_t` header

**Free algorithm:**
1. Insert the freed block back into the free list (sorted by address)
2. Check if it is adjacent to the previous free block — if so, merge
3. Check if it is adjacent to the next free block — if so, merge

**Memory layout:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    ucHeap[configTOTAL_HEAP_SIZE]                │
├────────┬───────────┬────────┬───────────┬────────┬─────────────┤
│ Header │ Allocated │ Header │   Free    │ Header │  Allocated  │
│ (8B)   │ Block A   │ (8B)   │  Block    │ (8B)   │  Block B    │
└────────┴───────────┴────────┴───────────┴────────┴─────────────┘
         ▲                     ▲                    ▲
         │                     │                    │
  pvPortMalloc returned     In free list      pvPortMalloc returned
```

### heap_5 — Non-Contiguous Regions

Extends heap_4 to support multiple separate memory regions (e.g., internal SRAM + external SDRAM):

```c
/* Define memory regions */
HeapRegion_t xHeapRegions[] = {
    { (uint8_t *)0x20000000, 0x10000 },   /* 64 KB internal SRAM */
    { (uint8_t *)0xD0000000, 0x800000 },  /* 8 MB external SDRAM */
    { NULL, 0 }                            /* Terminator */
};

/* Must be called BEFORE any pvPortMalloc */
vPortDefineHeapRegions(xHeapRegions);
```

Regions must be listed in ascending address order. `vPortDefineHeapRegions` links all regions into a single free list.

### Memory Management Utility Functions

```c
size_t xPortGetFreeHeapSize(void);                   /* Current free heap bytes */
size_t xPortGetMinimumEverFreeHeapSize(void);         /* Lowest free heap ever seen */
void   vApplicationMallocFailedHook(void);            /* Called when pvPortMalloc returns NULL */
```

---

## 14. Interrupt Management

### Interrupt Priority Partitioning

On ARM Cortex-M, FreeRTOS divides the interrupt priority space into two regions using `configMAX_SYSCALL_INTERRUPT_PRIORITY`:

```
Priority 0 (highest) ──┐
Priority 1             │  ISRs that CANNOT call FreeRTOS API
Priority 2             │  (never delayed by kernel; lowest latency)
Priority 3             │
Priority 4             │
─────────────────────── ← configMAX_SYSCALL_INTERRUPT_PRIORITY (e.g., 5)
Priority 5             │
Priority 6             │  ISRs that CAN call FreeRTOS "FromISR" APIs
Priority 7             │  (may be briefly masked during kernel critical sections)
...                    │
Priority 15 (lowest)   │  ← PendSV and SysTick are set here
───────────────────────
```

### ISR-Safe API Pattern

Every blocking FreeRTOS function has an ISR-safe variant suffixed with `FromISR`. These variants:

1. Never block
2. Never call `taskYIELD()` directly
3. Return a flag indicating whether a context switch is needed

**Correct ISR pattern:**

```c
void DMA1_Stream0_IRQHandler(void) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    
    if (DMA1->LISR & DMA_LISR_TCIF0) {
        DMA1->LIFCR = DMA_LIFCR_CTCIF0;  /* Clear interrupt flag */
        
        xSemaphoreGiveFromISR(xDMASemaphore, &xHigherPriorityTaskWoken);
    }
    
    /* This macro sets PendSV if xHigherPriorityTaskWoken == pdTRUE.
       It is safe to call even if xHigherPriorityTaskWoken is pdFALSE. */
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}
```

### Deferred Interrupt Processing

The recommended pattern is to keep ISRs as short as possible and defer complex processing to a task:

```
┌─────────────────┐     Semaphore/     ┌─────────────────┐
│   ISR (fast)    │ ── Notification ──►│  Handler Task   │
│ Clear flag      │      Give          │ Process data    │
│ Save raw data   │                    │ Update state    │
│ Signal task     │                    │ Send responses  │
└─────────────────┘                    └─────────────────┘
        │                                      │
  < 1 μs typical                        Can block, use
  execution time                        queues, allocate
                                        memory, etc.
```

### `portYIELD_FROM_ISR()` Implementation

```c
/* ARM Cortex-M implementation */
#define portYIELD_FROM_ISR(xHigherPriorityTaskWoken)  \
    do {                                              \
        if ((xHigherPriorityTaskWoken) == pdTRUE) {   \
            portNVIC_INT_CTRL_REG = portNVIC_PENDSVSET_BIT; \
        }                                             \
    } while (0)
```

This sets the PendSV pending bit. PendSV fires after all higher-priority ISRs have completed (since it runs at the lowest priority), ensuring the context switch happens cleanly.

---

## 15. Co-routines (Legacy)

Co-routines are a **deprecated** FreeRTOS feature designed for extremely memory-constrained devices (< 1 KB RAM). They share a single stack and use cooperative scheduling.

**Key differences from tasks:**
- All co-routines share one stack (saves RAM)
- Cannot maintain local variables across a blocking call
- Cannot be used with mutexes
- Cooperative only — no preemption between co-routines

**Modern recommendation:** Use tasks instead. Even on small devices, the deterministic stack usage of tasks is preferred. Co-routines are maintained for backward compatibility but receive no new development.

---

## 16. Debugging, Tracing, and Runtime Statistics

### Stack High Water Mark

The most common FreeRTOS bug is **stack overflow**. Use the high water mark to tune stack sizes:

```c
UBaseType_t uxHighWaterMark = uxTaskGetStackHighWaterMark(NULL); /* NULL = current task */
/* Returns the minimum number of free stack words ever seen.
   If this is close to 0, increase the task's stack size. */
```

**Stack overflow detection (`configCHECK_FOR_STACK_OVERFLOW`):**

- **Method 1:** Check if the stack pointer is within bounds after each context switch
- **Method 2:** Fill the stack with a known pattern (`0xA5A5A5A5`) at creation; check if the last N bytes have been overwritten

```c
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    /* This function is called if a stack overflow is detected.
       The task handle and name are provided for diagnostics. */
    uart_printf("STACK OVERFLOW in task: %s\r\n", pcTaskName);
    for (;;) { /* Halt system */ }
}
```

### Task State Listing

```c
char pcBuffer[512];
vTaskList(pcBuffer);
uart_transmit_string(pcBuffer);
```

**Output format:**

```
Name          State  Priority  Stack   Num
Sensor        R      2         156     1
Display       B      1         203     2
Logger        B      1         89      3
IDLE          R      0         112     4
Tmr Svc       B      15        234     5
```

State codes: `R` = Ready, `B` = Blocked, `S` = Suspended, `D` = Deleted, `X` = Running

### Runtime Statistics

```c
char pcBuffer[512];
vTaskGetRunTimeStats(pcBuffer);
uart_transmit_string(pcBuffer);
```

**Output format:**

```
Name          Abs Time      % Time
Sensor        42315678      23%
Display       18234567      10%
Logger        5123456       3%
IDLE          115326299     64%
```

**Requirements:**
- `configGENERATE_RUN_TIME_STATS == 1`
- A free-running timer counter with 10–20x the resolution of the tick (e.g., a 32-bit hardware timer at 100 kHz)
- Implement `portCONFIGURE_TIMER_FOR_RUN_TIME_STATS()` and `portGET_RUN_TIME_COUNTER_VALUE()`

### Trace Hooks

FreeRTOS provides trace hook macros at key points in the kernel. Define them as non-empty macros to capture events:

| Hook Macro | Called When |
|---|---|
| `traceTASK_SWITCHED_IN()` | A task starts running |
| `traceTASK_SWITCHED_OUT()` | A task stops running |
| `traceTASK_CREATE(pxNewTCB)` | A task is created |
| `traceTASK_DELETE(pxTaskToDelete)` | A task is deleted |
| `traceQUEUE_SEND(pxQueue)` | An item is sent to a queue |
| `traceQUEUE_RECEIVE(pxQueue)` | An item is received from a queue |
| `traceBLOCKING_ON_QUEUE_SEND(pxQueue)` | A task blocks trying to send |
| `traceBLOCKING_ON_QUEUE_RECEIVE(pxQueue)` | A task blocks trying to receive |
| `traceTASK_DELAY()` | `vTaskDelay()` is called |
| `traceTASK_DELAY_UNTIL()` | `vTaskDelayUntil()` is called |
| `traceMALLOC(pvAddress, uiSize)` | Memory is allocated |
| `traceFREE(pvAddress, uiSize)` | Memory is freed |

These hooks integrate with tools like Percepio Tracealyzer, SEGGER SystemView, and custom logging frameworks.

---

## 17. Common Pitfalls and Best Practices

### Pitfall 1: Stack Overflow

**Symptom:** Hard fault, data corruption, random crashes.

**Prevention:**
- Start with generous stack sizes, then use `uxTaskGetStackHighWaterMark()` to right-size
- Enable `configCHECK_FOR_STACK_OVERFLOW = 2`
- Avoid large local arrays — use static or heap memory instead
- Account for ISR stack usage (ISRs use the MSP on Cortex-M)

### Pitfall 2: Priority Inversion Without Mutex

**Symptom:** High-priority task starved unexpectedly.

**Prevention:**
- Always use a mutex (not a binary semaphore) for mutual exclusion
- Keep critical sections as short as possible
- Consider using task notifications instead of semaphores for simple signaling

### Pitfall 3: Calling Blocking APIs from ISR

**Symptom:** Kernel crash, assertion failure, undefined behavior.

**Prevention:**
- Only call `...FromISR()` variants in interrupt context
- Never call `vTaskDelay()`, `xQueueSend()`, or `xSemaphoreTake()` from an ISR
- Set `configASSERT()` to catch these during development

### Pitfall 4: Incorrect Interrupt Priority

**Symptom:** Kernel corruption, missed ticks, hard faults.

**Prevention:**
- ISRs that call FreeRTOS APIs must have priority >= `configMAX_SYSCALL_INTERRUPT_PRIORITY` (numerically)
- Use `configASSERT()` in port.c to validate priorities at runtime
- Remember: on Cortex-M, lower numeric priority = higher urgency

### Pitfall 5: Deadlock

**Symptom:** Two or more tasks permanently blocked waiting for each other's resources.

**Prevention:**
- Always acquire multiple mutexes in a consistent global order
- Use timeouts instead of `portMAX_DELAY` for mutex acquisition
- Consider redesigning to use message passing (queues) instead of shared state

### Pitfall 6: Deleting a Task That Holds a Mutex

**Symptom:** Mutex permanently locked; other tasks deadlock.

**Prevention:**
- Tasks should release all held resources before deletion
- Use a "shutdown" message/notification pattern instead of `vTaskDelete()`
- Query `xSemaphoreGetMutexHolder()` during debugging

### Pitfall 7: Timer Callback That Blocks

**Symptom:** All timers stop firing; timer daemon task deadlocked.

**Prevention:**
- Timer callbacks must never block (no `vTaskDelay`, no `xSemaphoreTake` with non-zero timeout)
- Use the callback to send a message to a task that does the real work

### Best Practices Summary

1. **Use static allocation** (`xTaskCreateStatic`, etc.) for safety-critical systems
2. **Start the scheduler last** — create all tasks and kernel objects first, then call `vTaskStartScheduler()`
3. **Use `configASSERT()`** — define it to halt the system and print diagnostics in debug builds
4. **Minimize critical section duration** — use queues/notifications instead of shared variables where possible
5. **Use task notifications** instead of binary semaphores for simple ISR-to-task signaling (faster, less RAM)
6. **Profile with runtime stats** — identify and optimize CPU hogs before they cause deadline misses
7. **Use `vTaskDelayUntil()`** for periodic tasks instead of `vTaskDelay()` to avoid timing drift
8. **Guard printf/UART writes** with a mutex to prevent interleaved output
9. **Set ISR priorities correctly** and validate with `configASSERT` in the port layer
10. **Design for testability** — separate hardware-dependent code from application logic

---

## 18. API Reference Summary

### Task API

| Function | Description |
|---|---|
| `xTaskCreate()` | Create a task (dynamic allocation) |
| `xTaskCreateStatic()` | Create a task (static allocation) |
| `vTaskDelete()` | Delete a task |
| `vTaskDelay()` | Block for a relative number of ticks |
| `xTaskDelayUntil()` | Block until an absolute tick count |
| `vTaskPrioritySet()` | Change a task's priority |
| `uxTaskPriorityGet()` | Get a task's current priority |
| `vTaskSuspend()` | Suspend a task |
| `vTaskResume()` | Resume a suspended task |
| `xTaskResumeFromISR()` | Resume a suspended task from ISR |
| `xTaskAbortDelay()` | Force a blocked task out of the Blocked state |
| `taskYIELD()` | Request a context switch |
| `taskENTER_CRITICAL()` | Enter critical section (disable interrupts) |
| `taskEXIT_CRITICAL()` | Exit critical section (restore interrupts) |
| `taskENTER_CRITICAL_FROM_ISR()` | Enter ISR-safe critical section |
| `taskEXIT_CRITICAL_FROM_ISR()` | Exit ISR-safe critical section |
| `vTaskSuspendAll()` | Suspend the scheduler (interrupts still enabled) |
| `xTaskResumeAll()` | Resume the scheduler |
| `vTaskStartScheduler()` | Start the RTOS scheduler |
| `vTaskEndScheduler()` | Stop the RTOS scheduler |
| `xTaskGetTickCount()` | Get current tick count |
| `xTaskGetTickCountFromISR()` | Get current tick count (ISR-safe) |
| `uxTaskGetNumberOfTasks()` | Get number of tasks |
| `xTaskGetCurrentTaskHandle()` | Get running task's handle |
| `pcTaskGetName()` | Get a task's name string |
| `eTaskGetState()` | Get a task's current state |
| `uxTaskGetStackHighWaterMark()` | Get minimum free stack ever |
| `vTaskList()` | Generate formatted task table |
| `vTaskGetRunTimeStats()` | Generate formatted CPU usage table |
| `xTaskGetHandle()` | Get handle by task name |

### Queue API

| Function | Description |
|---|---|
| `xQueueCreate()` | Create a queue (dynamic) |
| `xQueueCreateStatic()` | Create a queue (static) |
| `xQueueSend()` / `xQueueSendToBack()` | Send item to back of queue |
| `xQueueSendToFront()` | Send item to front of queue |
| `xQueueOverwrite()` | Overwrite item in queue (length-1 only) |
| `xQueueReceive()` | Receive and remove item |
| `xQueuePeek()` | Read item without removing |
| `xQueueSendFromISR()` | ISR-safe send |
| `xQueueReceiveFromISR()` | ISR-safe receive |
| `uxQueueMessagesWaiting()` | Get item count |
| `uxQueueSpacesAvailable()` | Get free slot count |
| `vQueueDelete()` | Delete queue |
| `xQueueReset()` | Reset queue to empty |

### Semaphore / Mutex API

| Function | Description |
|---|---|
| `xSemaphoreCreateBinary()` | Create binary semaphore |
| `xSemaphoreCreateCounting()` | Create counting semaphore |
| `xSemaphoreCreateMutex()` | Create mutex |
| `xSemaphoreCreateRecursiveMutex()` | Create recursive mutex |
| `xSemaphoreTake()` | Acquire semaphore/mutex |
| `xSemaphoreGive()` | Release semaphore/mutex |
| `xSemaphoreTakeRecursive()` | Acquire recursive mutex |
| `xSemaphoreGiveRecursive()` | Release recursive mutex |
| `xSemaphoreTakeFromISR()` | ISR-safe acquire |
| `xSemaphoreGiveFromISR()` | ISR-safe release |
| `xSemaphoreGetMutexHolder()` | Get mutex owner task |
| `uxSemaphoreGetCount()` | Get semaphore count |

### Event Group API

| Function | Description |
|---|---|
| `xEventGroupCreate()` | Create event group |
| `xEventGroupSetBits()` | Set bits |
| `xEventGroupClearBits()` | Clear bits |
| `xEventGroupWaitBits()` | Wait for bit combination |
| `xEventGroupSync()` | Synchronize multiple tasks |
| `xEventGroupGetBits()` | Read current bits |
| `xEventGroupSetBitsFromISR()` | Set bits from ISR |
| `xEventGroupClearBitsFromISR()` | Clear bits from ISR |

### Timer API

| Function | Description |
|---|---|
| `xTimerCreate()` | Create a software timer |
| `xTimerStart()` | Start a timer |
| `xTimerStop()` | Stop a timer |
| `xTimerReset()` | Reset (restart) a timer |
| `xTimerChangePeriod()` | Change timer period |
| `xTimerDelete()` | Delete a timer |
| `pvTimerGetTimerID()` | Get timer's user ID |
| `vTimerSetTimerID()` | Set timer's user ID |
| `xTimerIsTimerActive()` | Check if timer is running |
| `xTimerPendFunctionCall()` | Defer function to timer task |

### Task Notification API

| Function | Description |
|---|---|
| `xTaskNotifyGive()` | Increment notification value |
| `vTaskNotifyGiveFromISR()` | ISR-safe notification give |
| `ulTaskNotifyTake()` | Wait for notification (counting semaphore style) |
| `xTaskNotify()` | Send notification with action |
| `xTaskNotifyFromISR()` | ISR-safe notification with action |
| `xTaskNotifyWait()` | Wait for notification (event group style) |
| `xTaskNotifyStateClear()` | Clear notification state |
| `ulTaskNotifyValueClear()` | Clear notification value bits |

### Stream/Message Buffer API

| Function | Description |
|---|---|
| `xStreamBufferCreate()` | Create stream buffer |
| `xStreamBufferSend()` | Write bytes to stream |
| `xStreamBufferReceive()` | Read bytes from stream |
| `xStreamBufferBytesAvailable()` | Get available bytes |
| `xStreamBufferReset()` | Reset buffer |
| `xMessageBufferCreate()` | Create message buffer |
| `xMessageBufferSend()` | Write a complete message |
| `xMessageBufferReceive()` | Read a complete message |

### Memory Management API

| Function | Description |
|---|---|
| `pvPortMalloc()` | Allocate memory from FreeRTOS heap |
| `vPortFree()` | Free previously allocated memory |
| `xPortGetFreeHeapSize()` | Get current free heap |
| `xPortGetMinimumEverFreeHeapSize()` | Get lowest-ever free heap |
| `vPortDefineHeapRegions()` | Define heap regions (heap_5 only) |

---

*This guide covers FreeRTOS kernel v10.x / v11.x API. For the latest updates, consult the [official FreeRTOS documentation](https://www.freertos.org/Documentation/RTOS_book.html).*
