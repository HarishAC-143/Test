/**
 * Simple RTOS — Minimal Cooperative Task Scheduler
 *
 * Implements a cooperative scheduler with priority, task states,
 * message queues, and software timers.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ----------------------------------------------------------------
 * System tick simulation
 * ---------------------------------------------------------------- */
static volatile uint32_t sys_tick = 0;

static uint32_t get_tick(void) { return sys_tick; }
static void advance_tick(uint32_t ms) { sys_tick += ms; }

/* ----------------------------------------------------------------
 * Task scheduler
 * ---------------------------------------------------------------- */
#define MAX_TASKS   8
#define TASK_NAME_LEN 16

typedef enum {
    TASK_READY,
    TASK_RUNNING,
    TASK_BLOCKED,
    TASK_SUSPENDED
} TaskState;

typedef void (*TaskFunction)(void *param);

typedef struct {
    char          name[TASK_NAME_LEN];
    TaskFunction  function;
    void         *param;
    uint32_t      period_ms;
    uint32_t      last_run;
    uint8_t       priority;
    TaskState     state;
    uint32_t      run_count;
    uint32_t      total_runtime_us;
} Task;

typedef struct {
    Task     tasks[MAX_TASKS];
    uint8_t  count;
    uint8_t  current;
    uint32_t idle_count;
    uint32_t context_switches;
} Scheduler;

static Scheduler sched;

static void scheduler_init(void) {
    memset(&sched, 0, sizeof(sched));
}

static int scheduler_add_task(const char *name, TaskFunction fn,
                              void *param, uint32_t period_ms,
                              uint8_t priority) {
    if (sched.count >= MAX_TASKS) return -1;

    Task *t = &sched.tasks[sched.count];
    strncpy(t->name, name, TASK_NAME_LEN - 1);
    t->function    = fn;
    t->param       = param;
    t->period_ms   = period_ms;
    t->last_run    = 0;
    t->priority    = priority;
    t->state       = TASK_READY;
    t->run_count   = 0;
    t->total_runtime_us = 0;

    return sched.count++;
}

static void scheduler_suspend(int task_id) {
    if (task_id >= 0 && task_id < sched.count) {
        sched.tasks[task_id].state = TASK_SUSPENDED;
    }
}

static void scheduler_resume(int task_id) {
    if (task_id >= 0 && task_id < sched.count) {
        sched.tasks[task_id].state = TASK_READY;
    }
}

static void scheduler_tick(void) {
    uint32_t now = get_tick();

    /* Find highest priority ready task */
    int best = -1;
    uint8_t best_pri = 255;

    for (int i = 0; i < sched.count; i++) {
        Task *t = &sched.tasks[i];
        if (t->state != TASK_READY) continue;
        if ((now - t->last_run) < t->period_ms) continue;

        if (t->priority < best_pri) {
            best_pri = t->priority;
            best = i;
        }
    }

    if (best >= 0) {
        Task *t = &sched.tasks[best];
        t->state = TASK_RUNNING;
        sched.current = (uint8_t)best;
        sched.context_switches++;

        t->function(t->param);

        t->last_run = now;
        t->run_count++;
        t->state = TASK_READY;
    } else {
        sched.idle_count++;
    }
}

/* ----------------------------------------------------------------
 * Message queue
 * ---------------------------------------------------------------- */
#define MSG_QUEUE_SIZE 8

typedef struct {
    uint8_t  type;
    uint32_t data;
} Message;

typedef struct {
    Message  messages[MSG_QUEUE_SIZE];
    uint8_t  head;
    uint8_t  tail;
    uint8_t  count;
} MessageQueue;

static void mq_init(MessageQueue *q) {
    q->head = 0;
    q->tail = 0;
    q->count = 0;
}

static bool mq_send(MessageQueue *q, uint8_t type, uint32_t data) {
    if (q->count >= MSG_QUEUE_SIZE) return false;
    q->messages[q->head].type = type;
    q->messages[q->head].data = data;
    q->head = (q->head + 1) % MSG_QUEUE_SIZE;
    q->count++;
    return true;
}

static bool mq_receive(MessageQueue *q, Message *out) {
    if (q->count == 0) return false;
    *out = q->messages[q->tail];
    q->tail = (q->tail + 1) % MSG_QUEUE_SIZE;
    q->count--;
    return true;
}

/* ----------------------------------------------------------------
 * Software timer
 * ---------------------------------------------------------------- */
#define MAX_TIMERS 4

typedef void (*TimerCallback)(void *param);

typedef struct {
    uint32_t      period_ms;
    uint32_t      expires_at;
    TimerCallback callback;
    void         *param;
    bool          one_shot;
    bool          active;
} SoftTimer;

static SoftTimer timers[MAX_TIMERS];
static int timer_count = 0;

static int timer_create(uint32_t period_ms, TimerCallback cb,
                        void *param, bool one_shot) {
    if (timer_count >= MAX_TIMERS) return -1;
    timers[timer_count].period_ms  = period_ms;
    timers[timer_count].expires_at = get_tick() + period_ms;
    timers[timer_count].callback   = cb;
    timers[timer_count].param      = param;
    timers[timer_count].one_shot   = one_shot;
    timers[timer_count].active     = true;
    return timer_count++;
}

static void timer_process(void) {
    uint32_t now = get_tick();
    for (int i = 0; i < timer_count; i++) {
        if (timers[i].active && now >= timers[i].expires_at) {
            timers[i].callback(timers[i].param);
            if (timers[i].one_shot) {
                timers[i].active = false;
            } else {
                timers[i].expires_at = now + timers[i].period_ms;
            }
        }
    }
}

/* ----------------------------------------------------------------
 * Application tasks
 * ---------------------------------------------------------------- */
static MessageQueue sensor_queue;

static void sensor_task(void *param) {
    (void)param;
    static uint16_t reading = 1000;
    reading += 5;
    if (reading > 4000) reading = 1000;

    mq_send(&sensor_queue, 0x01, reading);
    printf("    [Sensor @ %u ms] Reading: %u\n", get_tick(), reading);
}

static void comm_task(void *param) {
    (void)param;
    Message msg;
    if (mq_receive(&sensor_queue, &msg)) {
        printf("    [Comm   @ %u ms] Sending sensor data: %u\n",
               get_tick(), msg.data);
    } else {
        printf("    [Comm   @ %u ms] No data to send\n", get_tick());
    }
}

static void monitor_task(void *param) {
    (void)param;
    printf("    [Monitor@ %u ms] Tasks: %d, Switches: %u, Idle: %u\n",
           get_tick(), sched.count, sched.context_switches, sched.idle_count);
}

static void alarm_callback(void *param) {
    const char *name = (const char *)param;
    printf("    [TIMER CALLBACK @ %u ms] %s fired!\n", get_tick(), name);
}

/* ----------------------------------------------------------------
 * Demo: Basic cooperative scheduling
 * ---------------------------------------------------------------- */
static void demo_cooperative_scheduler(void) {
    printf("=== RTOS: Cooperative Task Scheduler ===\n\n");

    scheduler_init();
    mq_init(&sensor_queue);
    sys_tick = 0;
    timer_count = 0;

    scheduler_add_task("Sensor",  sensor_task,  NULL, 100, 1);
    scheduler_add_task("Comm",    comm_task,    NULL, 200, 2);
    scheduler_add_task("Monitor", monitor_task, NULL, 500, 3);

    printf("  Registered tasks:\n");
    for (int i = 0; i < sched.count; i++) {
        printf("    %d: %-10s period=%u ms, priority=%u\n",
               i, sched.tasks[i].name,
               sched.tasks[i].period_ms,
               sched.tasks[i].priority);
    }

    /* Create software timers */
    timer_create(300, alarm_callback, (void *)"Periodic-300ms", false);
    timer_create(750, alarm_callback, (void *)"OneShot-750ms",  true);

    printf("\n  Running scheduler for 1000 ms:\n\n");

    /* Simulate 1 second of operation (1 ms tick resolution) */
    for (int t = 0; t <= 1000; t += 10) {
        advance_tick(10);
        scheduler_tick();
        timer_process();
    }

    printf("\n  Final statistics:\n");
    for (int i = 0; i < sched.count; i++) {
        printf("    %-10s: ran %u times\n",
               sched.tasks[i].name, sched.tasks[i].run_count);
    }
    printf("    Context switches: %u\n", sched.context_switches);
    printf("    Idle ticks:       %u\n\n", sched.idle_count);
}

/* ----------------------------------------------------------------
 * Demo: Task suspend and resume
 * ---------------------------------------------------------------- */
static void demo_task_control(void) {
    printf("=== RTOS: Task Suspend & Resume ===\n\n");

    scheduler_init();
    mq_init(&sensor_queue);
    sys_tick = 0;
    timer_count = 0;

    int sensor_id  = scheduler_add_task("Sensor",  sensor_task,  NULL, 100, 1);
    scheduler_add_task("Comm", comm_task, NULL, 200, 2);

    printf("  Phase 1: Both tasks running (0–300 ms)\n");
    for (int t = 0; t <= 300; t += 10) {
        advance_tick(10);
        scheduler_tick();
    }

    printf("\n  --- Suspending Sensor task ---\n\n");
    scheduler_suspend(sensor_id);

    printf("  Phase 2: Sensor suspended (300–600 ms)\n");
    for (int t = 300; t <= 600; t += 10) {
        advance_tick(10);
        scheduler_tick();
    }

    printf("\n  --- Resuming Sensor task ---\n\n");
    scheduler_resume(sensor_id);

    printf("  Phase 3: Both tasks running again (600–800 ms)\n");
    for (int t = 600; t <= 800; t += 10) {
        advance_tick(10);
        scheduler_tick();
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Priority inversion problem
 * ---------------------------------------------------------------- */
static void low_pri_task(void *p) {
    (void)p;
    printf("    [LOW  @ %u ms] Executing (holds shared resource)\n", get_tick());
}

static void med_pri_task(void *p) {
    (void)p;
    printf("    [MED  @ %u ms] Executing (preempts LOW, blocks HIGH!)\n", get_tick());
}

static void high_pri_task(void *p) {
    (void)p;
    printf("    [HIGH @ %u ms] Executing (needs shared resource)\n", get_tick());
}

static void demo_priority_inversion(void) {
    printf("=== RTOS: Priority Inversion (Conceptual) ===\n\n");

    printf("  Priority inversion occurs when:\n");
    printf("    1. LOW priority task acquires a shared resource (mutex)\n");
    printf("    2. HIGH priority task needs the same resource → blocks\n");
    printf("    3. MEDIUM priority task runs instead of LOW\n");
    printf("    4. HIGH is effectively blocked by MEDIUM!\n\n");

    printf("  Timeline:\n");
    printf("    ┌─────────────────────────────────────────────┐\n");
    printf("    │ HIGH:  ....BLOCKED..........│RUN│           │\n");
    printf("    │ MED:   ............│RUNNING│....            │\n");
    printf("    │ LOW:   │RUN│......│........│....│RUN│       │\n");
    printf("    │        ▲          ▲         ▲    ▲          │\n");
    printf("    │    LOW gets   HIGH needs  MED   LOW        │\n");
    printf("    │    mutex     mutex→block  preempts releases │\n");
    printf("    └─────────────────────────────────────────────┘\n\n");

    printf("  Solution: Priority inheritance protocol\n");
    printf("    When HIGH blocks on mutex held by LOW,\n");
    printf("    temporarily boost LOW's priority to HIGH's level.\n");
    printf("    This prevents MEDIUM from preempting LOW.\n\n");

    scheduler_init();
    sys_tick = 0;

    scheduler_add_task("Low",  low_pri_task,  NULL, 50, 3);
    scheduler_add_task("Med",  med_pri_task,  NULL, 50, 2);
    scheduler_add_task("High", high_pri_task, NULL, 50, 1);

    printf("  Demo run (all tasks at 50 ms period):\n");
    for (int t = 0; t <= 200; t += 10) {
        advance_tick(10);
        scheduler_tick();
    }
    printf("\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Simple RTOS — Cooperative Scheduler     ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_cooperative_scheduler();
    demo_task_control();
    demo_priority_inversion();

    printf("═══ End of Simple RTOS Demo ═══\n");
    return 0;
}
