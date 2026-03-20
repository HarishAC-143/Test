/**
 * Watchdog Timer Usage
 *
 * Demonstrates independent and window watchdog concepts,
 * showing how watchdogs protect against software hangs.
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

/* ----------------------------------------------------------------
 * Simulated Independent Watchdog (IWDG)
 * ---------------------------------------------------------------- */
typedef struct {
    uint32_t timeout_ms;
    uint32_t counter_ms;
    bool     running;
    uint32_t reset_count;
} SimIWDG;

static SimIWDG iwdg = {0};

static void iwdg_init(uint32_t timeout_ms) {
    iwdg.timeout_ms = timeout_ms;
    iwdg.counter_ms = timeout_ms;
    iwdg.running = true;
    iwdg.reset_count = 0;

    printf("  IWDG initialized: %u ms timeout\n", timeout_ms);
}

static void iwdg_refresh(void) {
    iwdg.counter_ms = iwdg.timeout_ms;
}

static bool iwdg_tick(uint32_t elapsed_ms) {
    if (!iwdg.running) return false;

    if (iwdg.counter_ms <= elapsed_ms) {
        iwdg.reset_count++;
        printf("  *** WATCHDOG RESET #%u! (counter expired) ***\n",
               iwdg.reset_count);
        iwdg.counter_ms = iwdg.timeout_ms;
        return true;
    }
    iwdg.counter_ms -= elapsed_ms;
    return false;
}

/* ----------------------------------------------------------------
 * Simulated Window Watchdog (WWDG)
 * ---------------------------------------------------------------- */
typedef struct {
    uint32_t window_start_ms;
    uint32_t window_end_ms;
    uint32_t counter_ms;
    bool     running;
    uint32_t reset_count;
    uint32_t early_refresh_count;
} SimWWDG;

static SimWWDG wwdg = {0};

static void wwdg_init(uint32_t window_start_ms, uint32_t window_end_ms) {
    wwdg.window_start_ms = window_start_ms;
    wwdg.window_end_ms = window_end_ms;
    wwdg.counter_ms = 0;
    wwdg.running = true;
    wwdg.reset_count = 0;
    wwdg.early_refresh_count = 0;

    printf("  WWDG initialized: refresh window [%u, %u] ms\n",
           window_start_ms, window_end_ms);
}

typedef enum {
    WWDG_OK,
    WWDG_TOO_EARLY,
    WWDG_TOO_LATE
} WWDGResult;

static WWDGResult wwdg_refresh(void) {
    if (wwdg.counter_ms < wwdg.window_start_ms) {
        wwdg.early_refresh_count++;
        wwdg.counter_ms = 0;
        return WWDG_TOO_EARLY;
    }
    wwdg.counter_ms = 0;
    return WWDG_OK;
}

static bool wwdg_tick(uint32_t elapsed_ms) {
    if (!wwdg.running) return false;

    wwdg.counter_ms += elapsed_ms;
    if (wwdg.counter_ms > wwdg.window_end_ms) {
        wwdg.reset_count++;
        printf("  *** WINDOW WATCHDOG RESET #%u! (too late) ***\n",
               wwdg.reset_count);
        wwdg.counter_ms = 0;
        return true;
    }
    return false;
}

/* ----------------------------------------------------------------
 * Demo: Basic watchdog — normal operation
 * ---------------------------------------------------------------- */
static void demo_normal_operation(void) {
    printf("=== Demo: Watchdog Normal Operation ===\n\n");

    iwdg_init(100);

    printf("  Simulating normal task loop (refreshing every 50 ms):\n\n");

    for (int cycle = 0; cycle < 10; cycle++) {
        /* Simulate 50 ms of work */
        bool reset = iwdg_tick(50);
        if (reset) {
            printf("  Cycle %d: RESET occurred\n", cycle);
        } else {
            printf("  Cycle %2d: [%3u ms remaining] Task running, refreshing...\n",
                   cycle, iwdg.counter_ms);
            iwdg_refresh();
        }
    }
    printf("\n  No resets: watchdog refreshed before timeout.\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Watchdog catches a software hang
 * ---------------------------------------------------------------- */
static void demo_hang_detection(void) {
    printf("=== Demo: Watchdog Detects Software Hang ===\n\n");

    iwdg_init(100);

    printf("  Simulating a task that hangs on cycle 4:\n\n");

    for (int cycle = 0; cycle < 12; cycle++) {
        iwdg_tick(25);

        if (cycle < 4) {
            printf("  Cycle %2d: [%3u ms] Normal operation, refreshing\n",
                   cycle, iwdg.counter_ms);
            iwdg_refresh();
        } else if (cycle < 8) {
            printf("  Cycle %2d: [%3u ms] *** SOFTWARE HANG — not refreshing ***\n",
                   cycle, iwdg.counter_ms);
        } else {
            printf("  Cycle %2d: [%3u ms] After reset — system recovered\n",
                   cycle, iwdg.counter_ms);
            iwdg_refresh();
        }
    }
    printf("\n  Total resets: %u\n\n", iwdg.reset_count);
}

/* ----------------------------------------------------------------
 * Demo: Window watchdog — both too early and too late
 * ---------------------------------------------------------------- */
static void demo_window_watchdog(void) {
    printf("=== Demo: Window Watchdog ===\n\n");

    wwdg_init(30, 80);

    printf("  Valid refresh window: [30, 80] ms after last refresh\n");
    printf("  Too early: < 30 ms (software error — running too fast)\n");
    printf("  Too late:  > 80 ms (software hang — running too slow)\n\n");

    struct {
        const char *description;
        uint32_t    refresh_at_ms;
    } scenarios[] = {
        { "Normal (50 ms)",    50 },
        { "Normal (60 ms)",    60 },
        { "Too early (10 ms)", 10 },
        { "Normal (40 ms)",    40 },
        { "Too late (90 ms)",  90 },
        { "Normal (70 ms)",    70 },
    };
    int n = sizeof(scenarios) / sizeof(scenarios[0]);

    for (int i = 0; i < n; i++) {
        wwdg.counter_ms = 0;

        wwdg_tick(scenarios[i].refresh_at_ms);
        WWDGResult result = wwdg_refresh();

        const char *status;
        switch (result) {
        case WWDG_OK:        status = "OK"; break;
        case WWDG_TOO_EARLY: status = "TOO EARLY (reset!)"; break;
        case WWDG_TOO_LATE:  status = "TOO LATE (reset!)"; break;
        default:             status = "???"; break;
        }

        printf("  Scenario %d: %-22s refresh at %2u ms -> %s\n",
               i + 1, scenarios[i].description,
               scenarios[i].refresh_at_ms, status);
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Task health monitoring with watchdog
 * ---------------------------------------------------------------- */

#define MAX_TASKS 4

typedef struct {
    const char *name;
    uint32_t    max_period_ms;
    uint32_t    last_checkin_ms;
    bool        healthy;
} TaskHealth;

static TaskHealth tasks[MAX_TASKS];
static int num_tasks = 0;
static uint32_t sim_time_ms = 0;

static void health_register(const char *name, uint32_t max_period_ms) {
    if (num_tasks < MAX_TASKS) {
        tasks[num_tasks].name = name;
        tasks[num_tasks].max_period_ms = max_period_ms;
        tasks[num_tasks].last_checkin_ms = 0;
        tasks[num_tasks].healthy = true;
        num_tasks++;
    }
}

static void health_checkin(int task_id) {
    if (task_id < num_tasks) {
        tasks[task_id].last_checkin_ms = sim_time_ms;
        tasks[task_id].healthy = true;
    }
}

static bool health_all_ok(void) {
    bool all_ok = true;
    for (int i = 0; i < num_tasks; i++) {
        if (sim_time_ms - tasks[i].last_checkin_ms > tasks[i].max_period_ms) {
            tasks[i].healthy = false;
            all_ok = false;
        }
    }
    return all_ok;
}

static void demo_task_health(void) {
    printf("=== Demo: Multi-Task Health Monitoring ===\n\n");

    num_tasks = 0;
    sim_time_ms = 0;

    health_register("SensorTask",  100);
    health_register("CommTask",    200);
    health_register("UITask",      500);

    iwdg_init(600);

    printf("  Each task must check in within its deadline.\n");
    printf("  Watchdog is only refreshed when ALL tasks are healthy.\n\n");

    printf("  Time   Sensor  Comm  UI      WDG     Status\n");
    printf("  ----   ------  ----  ------  ------  ------\n");

    for (int step = 0; step < 16; step++) {
        sim_time_ms += 50;

        /* Sensor checks in every 50 ms */
        if (step % 1 == 0) health_checkin(0);

        /* Comm checks in every 100 ms */
        if (step % 2 == 0) health_checkin(1);

        /* UI checks in normally, but "hangs" at step 8 */
        if (step < 8 || step >= 14) {
            if (step % 4 == 0) health_checkin(2);
        }

        bool ok = health_all_ok();

        printf("  %4u   %-6s  %-4s  %-6s  ",
               sim_time_ms,
               tasks[0].healthy ? "OK" : "FAIL",
               tasks[1].healthy ? "OK" : "FAIL",
               tasks[2].healthy ? "OK" : "FAIL");

        if (ok) {
            iwdg_refresh();
            printf("%-6s  All tasks healthy\n", "Feed");
        } else {
            printf("%-6s  ", "SKIP!");
            for (int t = 0; t < num_tasks; t++) {
                if (!tasks[t].healthy) printf("%s OVERDUE! ", tasks[t].name);
            }
            printf("\n");
        }

        iwdg_tick(50);
    }

    printf("\n  Resets due to unhealthy tasks: %u\n\n", iwdg.reset_count);
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Watchdog Timer Usage                    ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_normal_operation();
    demo_hang_detection();
    demo_window_watchdog();
    demo_task_health();

    printf("═══ End of Watchdog Timer Demo ═══\n");
    return 0;
}
