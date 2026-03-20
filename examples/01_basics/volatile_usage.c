/**
 * Embedded C volatile Qualifier Demo
 *
 * Illustrates why volatile is critical in embedded systems by simulating
 * hardware register access and ISR-shared variables.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -O2 -o volatile_usage volatile_usage.c
 *
 * Try compiling with and without -O2 to see the difference volatile makes.
 * Without volatile and with -O2, the "wait loop" may be optimized out.
 */

#include <stdint.h>
#include <stdio.h>
#include <signal.h>
#include <unistd.h>

/* ---------- Scenario 1: Simulated Hardware Register ---------- */

/*
 * In real embedded code, this would be:
 *   #define STATUS_REG (*(volatile uint32_t *)0x40001000)
 *
 * For this demo, we use a volatile variable to simulate a register
 * that changes asynchronously (e.g., set by a signal handler acting
 * as a pseudo-ISR).
 */
static volatile uint32_t simulated_status_reg = 0;

/* Signal handler simulates a hardware interrupt setting a flag */
static void simulated_interrupt(int sig)
{
    (void)sig;
    simulated_status_reg |= (1U << 0);  /* Set "ready" bit */
}

static void demo_hardware_register(void)
{
    printf("=== Scenario 1: Hardware Register Polling ===\n\n");

    printf("In real embedded code:\n");
    printf("  #define STATUS_REG (*(volatile uint32_t *)0x40001000)\n\n");
    printf("  while (!(STATUS_REG & 0x01))  <-- re-reads every iteration\n");
    printf("      ;                          <-- because of volatile\n\n");

    printf("Without volatile, the compiler (with -O2) may:\n");
    printf("  1. Read STATUS_REG once\n");
    printf("  2. Cache the value in a CPU register\n");
    printf("  3. Loop forever (never sees the hardware change)\n\n");

    printf("With volatile, the compiler MUST:\n");
    printf("  1. Generate a memory load instruction every iteration\n");
    printf("  2. Never cache the value\n\n");

    /* Simulate: set up a signal to fire in a moment */
    simulated_status_reg = 0;
    signal(SIGALRM, simulated_interrupt);
    alarm(1);

    printf("Waiting for simulated hardware interrupt...\n");
    while (!(simulated_status_reg & (1U << 0)))
        ;
    printf("Hardware ready flag detected!\n\n");
}

/* ---------- Scenario 2: ISR-Shared Variable ---------- */

static volatile uint8_t isr_data_ready = 0;
static volatile uint8_t isr_received_byte = 0;

/*
 * In real code this would be:
 *   void USART1_IRQHandler(void) {
 *       isr_received_byte = USART1->DR;
 *       isr_data_ready = 1;
 *   }
 */

static void demo_isr_shared_variable(void)
{
    printf("=== Scenario 2: ISR-Shared Variable ===\n\n");

    printf("Pattern: Flag-and-process\n\n");
    printf("  volatile uint8_t data_ready = 0;\n");
    printf("  volatile uint8_t rx_byte = 0;\n\n");

    printf("  // In ISR:\n");
    printf("  void USART1_IRQHandler(void) {\n");
    printf("      rx_byte = USART1->DR;  // Read received data\n");
    printf("      data_ready = 1;         // Signal main loop\n");
    printf("  }\n\n");

    printf("  // In main loop:\n");
    printf("  while (1) {\n");
    printf("      if (data_ready) {       // volatile: compiler re-checks\n");
    printf("          process(rx_byte);\n");
    printf("          data_ready = 0;\n");
    printf("      }\n");
    printf("  }\n\n");

    printf("Without volatile on data_ready, the compiler may:\n");
    printf("  - See that nothing in main() changes data_ready\n");
    printf("  - Optimize the 'if' to never be true (at -O2)\n");
    printf("  - Result: ISR sets the flag, but main loop never sees it\n\n");

    /* Simulate ISR setting the flag */
    isr_data_ready = 0;
    isr_received_byte = 'A';
    isr_data_ready = 1;  /* Simulates ISR writing */

    if (isr_data_ready) {
        printf("Received byte: '%c' (0x%02X)\n", isr_received_byte, isr_received_byte);
        isr_data_ready = 0;
    }
    printf("\n");
}

/* ---------- Scenario 3: Delay Loop ---------- */

static void demo_delay_loop(void)
{
    printf("=== Scenario 3: Software Delay Loop ===\n\n");

    printf("Common pattern for simple delays:\n\n");
    printf("  void delay(volatile uint32_t count) {\n");
    printf("      while (count--)\n");
    printf("          ;\n");
    printf("  }\n\n");

    printf("Without volatile on 'count', the compiler sees:\n");
    printf("  - The loop body is empty\n");
    printf("  - 'count' is never read after the loop\n");
    printf("  - Therefore the entire loop is dead code → REMOVED\n\n");

    printf("With volatile, each decrement is a side effect the\n");
    printf("compiler must preserve, so the loop executes.\n\n");

    printf("NOTE: Software delay loops are imprecise. Prefer hardware\n");
    printf("timers (SysTick, TIM) for accurate timing.\n\n");

    /* Demonstrate the delay */
    printf("Running delay(1000000)... ");
    for (volatile uint32_t i = 0; i < 1000000; i++)
        ;
    printf("done.\n\n");
}

/* ---------- Scenario 4: const volatile ---------- */

static void demo_const_volatile(void)
{
    printf("=== Scenario 4: const volatile ===\n\n");

    printf("A read-only hardware register is both:\n");
    printf("  - const:    your code must not write to it\n");
    printf("  - volatile: its value changes (set by hardware)\n\n");

    printf("Example:\n");
    printf("  #define ADC_DATA (*(const volatile uint16_t *)0x4001204C)\n\n");
    printf("  uint16_t reading = ADC_DATA;  // OK: read\n");
    printf("  ADC_DATA = 0;                 // COMPILE ERROR: write to const\n\n");

    const volatile uint32_t simulated_adc = 2048;
    printf("Simulated ADC read: %u\n", simulated_adc);
    printf("(Cannot write back — compiler enforces const)\n");
}

/* ---------- Main ---------- */

int main(void)
{
    printf("Embedded C volatile Qualifier Demo\n");
    printf("===================================\n\n");

    demo_hardware_register();
    demo_isr_shared_variable();
    demo_delay_loop();
    demo_const_volatile();

    return 0;
}
