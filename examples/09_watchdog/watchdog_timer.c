/**
 * Watchdog Timer — Configuration and Usage
 *
 * Demonstrates the Independent Watchdog Timer (IWDG) concept:
 *   - What a watchdog does and why it's essential
 *   - Configuration and feeding patterns
 *   - Common pitfalls and best practices
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o watchdog_timer watchdog_timer.c
 */

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

/* ---- Watchdog Concepts ---- */

static void explain_watchdog(void)
{
    printf("=== What Is a Watchdog Timer? ===\n\n");

    printf("A watchdog timer (WDT) is a hardware safety mechanism that\n");
    printf("resets the MCU if software stops functioning correctly.\n\n");

    printf("How it works:\n");
    printf("  1. Configure a timeout period (e.g., 1 second)\n");
    printf("  2. The watchdog counts down continuously\n");
    printf("  3. Software must periodically 'feed' (reload) the watchdog\n");
    printf("  4. If the counter reaches zero → MCU RESET\n\n");

    printf("  Normal operation:\n");
    printf("  [FEED]───────────[FEED]───────────[FEED]───────────\n");
    printf("    ↑                ↑                ↑\n");
    printf("    counter          counter          counter\n");
    printf("    reloaded         reloaded         reloaded\n\n");

    printf("  Software hang (missed feed):\n");
    printf("  [FEED]───────────[FEED]───────────────────────[RESET!]\n");
    printf("    ↑                ↑                           ↑\n");
    printf("    counter          counter          counter    counter\n");
    printf("    reloaded         reloaded         ticking... reached 0!\n\n");
}

/* ---- Simulated Watchdog ---- */

typedef struct {
    uint32_t reload_value;
    uint32_t counter;
    bool     enabled;
    uint32_t reset_count;
    uint32_t feed_count;
} WatchdogSim;

static WatchdogSim wdg = {0};

static void iwdg_init(uint32_t timeout_ticks)
{
    wdg.reload_value = timeout_ticks;
    wdg.counter = timeout_ticks;
    wdg.enabled = true;
    wdg.reset_count = 0;
    wdg.feed_count = 0;
}

static void iwdg_feed(void)
{
    wdg.counter = wdg.reload_value;
    wdg.feed_count++;
}

/* Returns true if watchdog triggered a reset */
static bool iwdg_tick(void)
{
    if (!wdg.enabled)
        return false;
    if (wdg.counter > 0) {
        wdg.counter--;
        return false;
    }
    wdg.reset_count++;
    wdg.counter = wdg.reload_value;
    return true;
}

/* ---- Demo: Normal Operation ---- */

static void demo_normal_operation(void)
{
    printf("=== Demo: Normal Operation ===\n\n");

    iwdg_init(5);  /* 5-tick timeout */
    printf("  Watchdog timeout: 5 ticks\n");
    printf("  Feeding every 3 ticks\n\n");

    printf("  Tick  Counter  Action\n");
    printf("  ----  -------  ------\n");

    for (int tick = 0; tick < 20; tick++) {
        bool reset = iwdg_tick();
        const char *action = "";

        if (reset) {
            action = "*** RESET! ***";
        } else if (tick % 3 == 0 && tick > 0) {
            iwdg_feed();
            action = "FEED (counter reloaded)";
        }

        printf("  %4d  %7u  %s\n", tick, wdg.counter, action);
    }
    printf("\n  Feeds: %u, Resets: %u\n\n", wdg.feed_count, wdg.reset_count);
}

/* ---- Demo: Missed Feed (Hang) ---- */

static void demo_missed_feed(void)
{
    printf("=== Demo: Software Hang (Missed Feed) ===\n\n");

    iwdg_init(5);
    printf("  Watchdog timeout: 5 ticks\n");
    printf("  Software hangs after tick 7 (stops feeding)\n\n");

    printf("  Tick  Counter  Action\n");
    printf("  ----  -------  ------\n");

    bool software_hung = false;

    for (int tick = 0; tick < 20; tick++) {
        bool reset = iwdg_tick();
        const char *action = "";

        if (reset) {
            action = "*** WATCHDOG RESET! System recovers ***";
            software_hung = false;
        } else if (tick == 7) {
            action = "--- SOFTWARE HANGS HERE ---";
            software_hung = true;
        } else if (!software_hung && tick % 3 == 0 && tick > 0) {
            iwdg_feed();
            action = "FEED";
        } else if (software_hung) {
            action = "(hung — no feed)";
        }

        printf("  %4d  %7u  %s\n", tick, wdg.counter, action);
    }
    printf("\n  Resets: %u — watchdog caught the hang!\n\n", wdg.reset_count);
}

/* ---- Best Practices ---- */

static void show_best_practices(void)
{
    printf("=== Watchdog Best Practices ===\n\n");

    printf("1. Feed from the main loop ONLY:\n\n");
    printf("   int main(void) {\n");
    printf("       system_init();\n");
    printf("       iwdg_init(2000); // 2-second timeout\n");
    printf("       while (1) {\n");
    printf("           if (system_check_ok()) {\n");
    printf("               iwdg_feed();\n");
    printf("           }\n");
    printf("           run_application();\n");
    printf("       }\n");
    printf("   }\n\n");

    printf("2. NEVER feed from a timer interrupt:\n\n");
    printf("   // BAD: This defeats the purpose!\n");
    printf("   void TIM2_IRQHandler(void) {\n");
    printf("       iwdg_feed(); // Feeds even if main loop is hung!\n");
    printf("   }\n\n");

    printf("3. Conditional feeding — verify system health:\n\n");
    printf("   void main_loop_iteration(void) {\n");
    printf("       bool sensors_ok = check_sensors();\n");
    printf("       bool comms_ok = check_communications();\n");
    printf("       bool stack_ok = check_stack_usage();\n");
    printf("       if (sensors_ok && comms_ok && stack_ok)\n");
    printf("           iwdg_feed();\n");
    printf("   }\n\n");

    printf("4. Window watchdog (WWDG) for tighter control:\n\n");
    printf("   The window watchdog must be fed within a TIME WINDOW,\n");
    printf("   not just before timeout. Feeding too EARLY is also a fault.\n");
    printf("   This catches runaway loops that execute too fast.\n\n");

    printf("   Normal:   |----[window]----| timeout\n");
    printf("   Too early: |XX[window]------|  ← RESET\n");
    printf("   Too late:  |----[window]--|XX|  ← RESET\n");
    printf("   Correct:   |---[FEED]-------|  ← OK\n\n");

    printf("5. Timeout selection guidelines:\n\n");
    printf("   - Too short: false resets during legitimate delays\n");
    printf("   - Too long: slow recovery from actual hangs\n");
    printf("   - Rule of thumb: 2-5x the worst-case main loop time\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("Watchdog Timer — Configuration and Usage\n");
    printf("==========================================\n\n");

    explain_watchdog();
    demo_normal_operation();
    demo_missed_feed();
    show_best_practices();

    return 0;
}
