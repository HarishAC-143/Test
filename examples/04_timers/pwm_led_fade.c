/**
 * PWM LED Fade
 *
 * Demonstrates PWM (Pulse-Width Modulation) for controlling LED brightness.
 * Simulates the timer configuration and outputs a visual representation
 * of the PWM duty cycle.
 *
 * Compile (host): gcc -Wall -Wextra -std=c11 -o pwm_led_fade pwm_led_fade.c
 */

#include <stdint.h>
#include <stdio.h>

/* ---- PWM Explanation ---- */

static void explain_pwm(void)
{
    printf("=== PWM (Pulse-Width Modulation) ===\n\n");

    printf("PWM controls average power by switching rapidly between\n");
    printf("ON and OFF with a variable duty cycle:\n\n");

    printf("  100%% duty (always on):\n");
    printf("  ████████████████████████████████\n\n");

    printf("  75%% duty:\n");
    printf("  ████████████████████████________\n\n");

    printf("  50%% duty:\n");
    printf("  ████████████████________________\n\n");

    printf("  25%% duty:\n");
    printf("  ████████________________________\n\n");

    printf("  0%% duty (always off):\n");
    printf("  ________________________________\n\n");

    printf("Timer configuration:\n");
    printf("  - ARR (Auto-Reload) sets the period (PWM frequency)\n");
    printf("  - CCR (Capture/Compare) sets the duty cycle\n");
    printf("  - Duty = CCR / (ARR + 1) * 100%%\n\n");
}

/* ---- Simulated PWM Timer ---- */

typedef struct {
    uint32_t psc;
    uint32_t arr;
    uint32_t ccr;
    uint32_t enabled;
} PWM_Channel;

static PWM_Channel pwm = {0};

static void pwm_init(uint32_t frequency_hz, uint32_t sys_clock)
{
    pwm.psc = 0;
    pwm.arr = (sys_clock / frequency_hz) - 1;
    pwm.ccr = 0;
    pwm.enabled = 1;

    printf("PWM initialized:\n");
    printf("  System clock: %u Hz\n", sys_clock);
    printf("  PWM frequency: %u Hz\n", frequency_hz);
    printf("  PSC = %u\n", pwm.psc);
    printf("  ARR = %u\n", pwm.arr);
    printf("\n");
}

static void pwm_set_duty(uint8_t percent)
{
    if (percent > 100)
        percent = 100;
    pwm.ccr = (pwm.arr + 1) * percent / 100;
}

static uint8_t pwm_get_duty(void)
{
    return (uint8_t)((uint64_t)pwm.ccr * 100 / (pwm.arr + 1));
}

/* ---- Visual PWM Output ---- */

static void print_pwm_bar(uint8_t duty, int width)
{
    int on_width = width * duty / 100;
    int off_width = width - on_width;

    printf("  %3u%% |", duty);
    for (int i = 0; i < on_width; i++)
        printf("#");
    for (int i = 0; i < off_width; i++)
        printf(" ");
    printf("| CCR=%u\n", pwm.ccr);
}

/* ---- Demo: LED Fade Effect ---- */

static void demo_led_fade(void)
{
    printf("=== LED Fade Effect ===\n\n");

    printf("Simulating LED brightness sweep (0%% → 100%% → 0%%):\n\n");

    /* Fade in */
    printf("  Fade IN:\n");
    for (int duty = 0; duty <= 100; duty += 10) {
        pwm_set_duty((uint8_t)duty);
        print_pwm_bar(pwm_get_duty(), 40);
    }

    printf("\n  Fade OUT:\n");
    for (int duty = 100; duty >= 0; duty -= 10) {
        pwm_set_duty((uint8_t)duty);
        print_pwm_bar(pwm_get_duty(), 40);
    }
    printf("\n");
}

/* ---- Demo: Servo Control ---- */

static void demo_servo_control(void)
{
    printf("=== Servo Motor Control ===\n\n");

    printf("Standard hobby servos expect:\n");
    printf("  - Period: 20 ms (50 Hz)\n");
    printf("  - Pulse: 1.0 ms (0°) to 2.0 ms (180°)\n\n");

    uint32_t sys_clock = 84000000;
    uint32_t psc = 83;  /* 84 MHz / 84 = 1 MHz (1 µs ticks) */
    uint32_t arr = 19999; /* 20000 ticks = 20 ms = 50 Hz */

    printf("  Configuration: PSC=%u, ARR=%u\n", psc, arr);
    printf("  Timer clock: %u MHz / %u = 1 MHz\n", sys_clock / 1000000, psc + 1);
    printf("  Period: %u µs = %u ms\n\n", arr + 1, (arr + 1) / 1000);

    printf("  Angle → Pulse Width → CCR Value\n");
    printf("  -----   -----------   ---------\n");

    for (int angle = 0; angle <= 180; angle += 30) {
        uint32_t pulse_us = 1000 + ((uint32_t)angle * 1000 / 180);
        printf("  %4d°    %4u µs       CCR=%u\n", angle, pulse_us, pulse_us);
    }
    printf("\n");
}

/* ---- Demo: PWM Waveform Timing ---- */

static void demo_waveform(void)
{
    printf("=== PWM Waveform at 50%% Duty ===\n\n");

    printf("  Timer counter vs. CCR comparison:\n\n");
    printf("  Counter  Compare  Output\n");
    printf("  -------  -------  ------\n");

    uint32_t arr = 19;
    uint32_t ccr = 10;  /* 50% duty */

    for (uint32_t cnt = 0; cnt <= arr; cnt++) {
        const char *output = (cnt < ccr) ? "HIGH (LED ON)" : "LOW (LED OFF)";
        char bar[21];
        for (uint32_t i = 0; i <= arr; i++)
            bar[i] = (i == cnt) ? '*' : ((i < ccr) ? '-' : ' ');
        bar[arr + 1] = '\0';
        printf("  %7u   CNT%sCCR  %s  [%s]\n",
               cnt, cnt < ccr ? "<" : ">=", output, bar);
    }
    printf("\n");
    printf("  The output is HIGH when CNT < CCR (PWM Mode 1).\n");
    printf("  Changing CCR changes the duty cycle.\n");
    printf("  Changing ARR changes the period (frequency).\n");
}

/* ---- Main ---- */

int main(void)
{
    printf("PWM LED Fade Demo\n");
    printf("==================\n\n");

    explain_pwm();
    pwm_init(1000, 84000000);  /* 1 kHz PWM from 84 MHz clock */
    demo_led_fade();
    demo_servo_control();
    demo_waveform();

    return 0;
}
