/**
 * Timer Configuration and Usage
 *
 * Demonstrates timer concepts: periodic interrupts, PWM generation,
 * input capture, and one-shot delays — using simulation.
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ----------------------------------------------------------------
 * Simulated timer peripheral
 * ---------------------------------------------------------------- */
typedef struct {
    volatile uint32_t CR1;    /* Control register 1 */
    volatile uint32_t CR2;    /* Control register 2 */
    volatile uint32_t DIER;   /* DMA/interrupt enable */
    volatile uint32_t SR;     /* Status register */
    volatile uint32_t CNT;    /* Counter */
    volatile uint32_t PSC;    /* Prescaler */
    volatile uint32_t ARR;    /* Auto-reload */
    volatile uint32_t CCR[4]; /* Capture/compare channels */
    volatile uint32_t CCMR1;  /* Capture/compare mode 1 */
    volatile uint32_t CCMR2;  /* Capture/compare mode 2 */
    volatile uint32_t CCER;   /* Capture/compare enable */
} TIM_TypeDef;

static TIM_TypeDef sim_tim2, sim_tim3;
#define TIM2 (&sim_tim2)
#define TIM3 (&sim_tim3)

/* Simulated system clock */
#define SYSTEM_CLOCK_HZ  72000000

/* ----------------------------------------------------------------
 * Timer frequency calculator
 * ---------------------------------------------------------------- */
static void print_timer_calc(uint32_t sysclk, uint32_t psc, uint32_t arr) {
    double timer_clk = (double)sysclk / (psc + 1);
    double overflow_freq = timer_clk / (arr + 1);
    double period_us = 1e6 / overflow_freq;

    printf("    System clock:    %u Hz\n", sysclk);
    printf("    Prescaler (PSC): %u → Timer clock = %u / %u = %.0f Hz\n",
           psc, sysclk, psc + 1, timer_clk);
    printf("    Auto-reload (ARR): %u → Overflow every %u ticks\n", arr, arr + 1);
    printf("    Overflow freq:   %.2f Hz\n", overflow_freq);
    printf("    Period:          %.2f µs (%.4f ms)\n", period_us, period_us / 1000.0);
}

/* ----------------------------------------------------------------
 * Demo: Periodic interrupt timer (1 ms tick)
 * ---------------------------------------------------------------- */
static void demo_periodic_timer(void) {
    printf("=== Timer: 1 ms Periodic Interrupt ===\n\n");

    memset(TIM2, 0, sizeof(TIM_TypeDef));

    /* Goal: 1 ms period from 72 MHz clock
     *   PSC = 72 - 1 → timer clock = 72MHz / 72 = 1 MHz (1 µs per tick)
     *   ARR = 1000 - 1 → overflow every 1000 ticks = 1 ms
     */
    TIM2->PSC = 72 - 1;
    TIM2->ARR = 1000 - 1;
    TIM2->DIER |= (1 << 0);  /* Update interrupt enable */
    TIM2->CR1  |= (1 << 0);  /* Counter enable */

    printf("  Configuration:\n");
    print_timer_calc(SYSTEM_CLOCK_HZ, TIM2->PSC, TIM2->ARR);

    printf("\n  Register values:\n");
    printf("    TIM2->PSC  = %u\n", TIM2->PSC);
    printf("    TIM2->ARR  = %u\n", TIM2->ARR);
    printf("    TIM2->DIER = 0x%08X (update IRQ enabled)\n", TIM2->DIER);
    printf("    TIM2->CR1  = 0x%08X (counter running)\n", TIM2->CR1);

    /* Simulate timer counting and overflow */
    printf("\n  Simulating timer ticks:\n");
    for (int i = 0; i < 5; i++) {
        TIM2->CNT = TIM2->ARR;
        TIM2->SR |= (1 << 0);  /* Overflow flag */
        printf("    Tick %d: CNT reached ARR (%u), overflow! SR=0x%X\n",
               i + 1, TIM2->ARR, TIM2->SR);
        TIM2->SR &= ~(1 << 0); /* Clear flag (done in ISR) */
        TIM2->CNT = 0;
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Various timer frequency calculations
 * ---------------------------------------------------------------- */
static void demo_frequency_table(void) {
    printf("=== Timer Frequency Examples ===\n\n");

    struct {
        const char *description;
        uint32_t    psc;
        uint32_t    arr;
    } configs[] = {
        { "1 MHz (1 µs period)",       0,       72 - 1   },
        { "1 kHz (1 ms period)",       72 - 1,  1000 - 1 },
        { "100 Hz (10 ms period)",     720 - 1, 1000 - 1 },
        { "1 Hz (1 s period)",         7200 - 1, 10000 - 1 },
        { "50 Hz (20 ms — servo PWM)", 72 - 1,  20000 - 1 },
        { "25 kHz (fan PWM)",          0,       2880 - 1 },
    };
    int n = sizeof(configs) / sizeof(configs[0]);

    printf("  %-30s  %8s  %8s  %12s\n",
           "Description", "PSC", "ARR", "Actual Freq");
    printf("  %-30s  %8s  %8s  %12s\n",
           "------------------------------", "--------", "--------", "------------");

    for (int i = 0; i < n; i++) {
        double freq = (double)SYSTEM_CLOCK_HZ / ((configs[i].psc + 1) * (configs[i].arr + 1));
        printf("  %-30s  %8u  %8u  %10.2f Hz\n",
               configs[i].description, configs[i].psc, configs[i].arr, freq);
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: PWM generation
 * ---------------------------------------------------------------- */
static void demo_pwm(void) {
    printf("=== Timer: PWM Generation ===\n\n");

    memset(TIM3, 0, sizeof(TIM_TypeDef));

    /* PWM at 1 kHz with variable duty cycle
     *   Timer clock = 72 MHz / 72 = 1 MHz
     *   ARR = 999 → 1 kHz PWM frequency
     *   CCR1 = duty cycle (0–999 maps to 0–100%)
     */
    TIM3->PSC  = 72 - 1;
    TIM3->ARR  = 1000 - 1;
    TIM3->CCMR1 = (6 << 4) | (1 << 3);  /* PWM mode 1, preload enable */
    TIM3->CCER  = (1 << 0);             /* Channel 1 output enable */
    TIM3->CR1   = (1 << 0);             /* Start timer */

    printf("  PWM configuration (1 kHz, channel 1):\n");
    print_timer_calc(SYSTEM_CLOCK_HZ, TIM3->PSC, TIM3->ARR);

    printf("\n  Duty cycle sweep:\n\n");
    printf("  Duty  CCR1  |  Waveform (20 chars = 1 period)\n");
    printf("  ----  ----  |  --------------------\n");

    uint16_t duties[] = { 0, 10, 25, 50, 75, 90, 100 };
    int n = sizeof(duties) / sizeof(duties[0]);

    for (int i = 0; i < n; i++) {
        uint16_t ccr = (uint16_t)((uint32_t)duties[i] * TIM3->ARR / 100);
        TIM3->CCR[0] = ccr;

        int on_chars = duties[i] * 20 / 100;
        printf("  %3u%%  %4u  |  ", duties[i], ccr);
        for (int c = 0; c < 20; c++) {
            printf("%c", c < on_chars ? '#' : '_');
        }
        printf("\n");
    }

    printf("\n  '#' = HIGH, '_' = LOW\n");
    printf("  Average voltage = Vcc × (duty / 100)\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Servo control via PWM
 * ---------------------------------------------------------------- */
static void demo_servo(void) {
    printf("=== Timer: Servo Motor Control ===\n\n");

    memset(TIM3, 0, sizeof(TIM_TypeDef));

    /*
     * Standard servo: 50 Hz PWM (20 ms period)
     *   0° = 1.0 ms pulse → CCR = 1000
     *  90° = 1.5 ms pulse → CCR = 1500
     * 180° = 2.0 ms pulse → CCR = 2000
     *
     * Timer clock = 72 MHz / 72 = 1 MHz (1 µs resolution)
     * ARR = 19999 → 20 ms period
     */
    TIM3->PSC = 72 - 1;
    TIM3->ARR = 20000 - 1;

    printf("  Servo PWM: 50 Hz, 1-2 ms pulse width\n\n");
    printf("  Angle  Pulse   CCR    Waveform (20 chars = 20 ms)\n");
    printf("  -----  ------  -----  --------------------\n");

    int angles[] = { 0, 45, 90, 135, 180 };
    int n = sizeof(angles) / sizeof(angles[0]);

    for (int i = 0; i < n; i++) {
        uint16_t pulse_us = (uint16_t)(1000 + (angles[i] * 1000 / 180));
        TIM3->CCR[0] = pulse_us;

        int on_chars = pulse_us * 20 / 20000;
        if (on_chars < 1) on_chars = 1;

        printf("  %3d°   %4u µs  %5u  ", angles[i], pulse_us, pulse_us);
        for (int c = 0; c < 20; c++) {
            printf("%c", c < on_chars ? '#' : '_');
        }
        printf("\n");
    }
    printf("\n");
}

/* ----------------------------------------------------------------
 * Demo: Input capture (measuring pulse width)
 * ---------------------------------------------------------------- */
static void demo_input_capture(void) {
    printf("=== Timer: Input Capture ===\n\n");

    printf("  Input capture measures the time between edges of an\n");
    printf("  external signal by recording the counter value at each edge.\n\n");

    /* Simulate captured values */
    uint32_t captures[] = { 1000, 2500, 4000, 5500, 7000, 8500 };
    int n = sizeof(captures) / sizeof(captures[0]);

    printf("  Timer clock: 1 MHz (1 µs resolution)\n\n");
    printf("  Capture  Counter  Period    Frequency\n");
    printf("  -------  -------  --------  ---------\n");

    for (int i = 1; i < n; i++) {
        uint32_t period = captures[i] - captures[i - 1];
        double freq = 1e6 / period;
        printf("  %d        %5u    %4u µs   %.1f Hz\n",
               i, captures[i], period, freq);
    }

    printf("\n  Applications: tachometer, frequency counter, IR decoder\n\n");
}

/* ----------------------------------------------------------------
 * Demo: Delay functions using timers
 * ---------------------------------------------------------------- */
static void demo_delay_functions(void) {
    printf("=== Timer-Based Delay Functions ===\n\n");

    printf("  Method 1: Busy-wait delay (blocking)\n\n");
    printf("  ```c\n");
    printf("  void delay_us(uint32_t us) {\n");
    printf("      TIM2->CNT = 0;\n");
    printf("      TIM2->CR1 |= 1;    // Start\n");
    printf("      while (TIM2->CNT < us);\n");
    printf("      TIM2->CR1 &= ~1;   // Stop\n");
    printf("  }\n");
    printf("  ```\n\n");

    printf("  Method 2: SysTick-based delay (standard for Cortex-M)\n\n");
    printf("  ```c\n");
    printf("  volatile uint32_t ticks = 0;\n");
    printf("  void SysTick_Handler(void) { ticks++; }\n");
    printf("  void delay_ms(uint32_t ms) {\n");
    printf("      uint32_t start = ticks;\n");
    printf("      while ((ticks - start) < ms);\n");
    printf("  }\n");
    printf("  ```\n\n");

    printf("  Method 3: Non-blocking (cooperative)\n\n");
    printf("  ```c\n");
    printf("  typedef struct { uint32_t start; uint32_t delay; } SoftTimer;\n");
    printf("  bool timer_expired(SoftTimer *t) {\n");
    printf("      return (ticks - t->start) >= t->delay;\n");
    printf("  }\n");
    printf("  ```\n\n");

    printf("  Recommendation: Use Method 3 for real applications.\n");
    printf("  Blocking delays waste CPU cycles and break responsiveness.\n\n");
}

int main(void) {
    printf("╔══════════════════════════════════════════╗\n");
    printf("║  Timer Configuration & Usage             ║\n");
    printf("╚══════════════════════════════════════════╝\n\n");

    demo_periodic_timer();
    demo_frequency_table();
    demo_pwm();
    demo_servo();
    demo_input_capture();
    demo_delay_functions();

    printf("═══ End of Timer Configuration Demo ═══\n");
    return 0;
}
