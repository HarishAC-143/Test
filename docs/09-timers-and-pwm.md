# Chapter 9: Timers and PWM

Hardware timers are among the most versatile peripherals in a microcontroller. They handle precise timing, delay generation, event counting, pulse-width modulation, and input signal measurement — all without CPU intervention.

## Timer Basics

A hardware timer is essentially a counter that:

1. **Counts up (or down)** from a starting value
2. **At a configurable rate** (determined by the prescaler and clock source)
3. **Generates an event** when it reaches a target value (auto-reload)

```
Clock Source ──▶ Prescaler ──▶ Counter ──▶ Compare/Match ──▶ Event/Interrupt
 (e.g. 84 MHz)   (÷ N)        (0..ARR)     (== CCRx)        (flag, IRQ, output)
```

### Key Registers

| Register | Name | Function |
|----------|------|----------|
| **PSC** | Prescaler | Divides the input clock |
| **ARR** | Auto-Reload | Counter resets when it reaches this value |
| **CNT** | Counter | Current count value |
| **CCR1..4** | Capture/Compare | Compare value for output or captured value for input |
| **CR1** | Control Register 1 | Enable, direction, alignment |
| **SR** | Status Register | Interrupt and event flags |
| **DIER** | DMA/Interrupt Enable | Which events generate interrupts/DMA requests |

### Timer Clock Calculation

```
Timer frequency = Clock / (PSC + 1)
Timer period    = (ARR + 1) / Timer_frequency
Overflow rate   = Clock / ((PSC + 1) * (ARR + 1))
```

**Example:** Generate a 1-second period with an 84 MHz clock:

```
84,000,000 / ((8399 + 1) * (9999 + 1)) = 84,000,000 / 84,000,000 = 1 Hz
PSC = 8399, ARR = 9999
```

## Timer Modes

### Mode 1: Basic Timer — Periodic Interrupt

Generate an interrupt at a fixed interval (e.g., 1 ms):

```c
void timer2_init_1ms(void)
{
    RCC->APB1ENR |= (1U << 0);   /* Enable TIM2 clock */

    TIM2->PSC = 84 - 1;          /* 84 MHz / 84 = 1 MHz (1 µs ticks) */
    TIM2->ARR = 1000 - 1;        /* 1000 ticks = 1 ms */
    TIM2->DIER |= (1U << 0);     /* Enable update interrupt */
    TIM2->CR1 |= (1U << 0);      /* Start the timer */

    NVIC_EnableIRQ(TIM2_IRQn);
}

volatile uint32_t ms_ticks = 0;

void TIM2_IRQHandler(void)
{
    if (TIM2->SR & (1U << 0)) {
        TIM2->SR &= ~(1U << 0);  /* Clear update flag */
        ms_ticks++;
    }
}

void delay_ms(uint32_t ms)
{
    uint32_t start = ms_ticks;
    while ((ms_ticks - start) < ms)
        ;
}
```

### Mode 2: PWM Output

PWM (Pulse-Width Modulation) controls the average power delivered to a load by rapidly switching a pin on and off at a fixed frequency with a variable duty cycle.

```
         ┌────┐    ┌────┐    ┌────┐
Signal:  │    │    │    │    │    │
    ─────┘    └────┘    └────┘    └────
         <--->
         Duty cycle (CCR/ARR × 100%)
         <-------->
          Period (determined by ARR)
```

#### PWM Configuration

```c
void pwm_init(void)
{
    /* Enable clocks */
    RCC->AHB1ENR |= (1U << 0);   /* GPIOA clock */
    RCC->APB1ENR |= (1U << 0);   /* TIM2 clock */

    /* Configure PA5 as alternate function (TIM2_CH1) */
    GPIOA->MODER &= ~(3U << 10);
    GPIOA->MODER |=  (2U << 10);  /* AF mode */
    GPIOA->AFR[0] |= (1U << 20);  /* AF1 = TIM2 */

    /* Configure TIM2 for PWM */
    TIM2->PSC = 84 - 1;           /* 1 MHz timer clock */
    TIM2->ARR = 1000 - 1;         /* 1 kHz PWM frequency */
    TIM2->CCR1 = 500;             /* 50% duty cycle */

    /* PWM Mode 1: active when CNT < CCR */
    TIM2->CCMR1 &= ~(7U << 4);
    TIM2->CCMR1 |=  (6U << 4);    /* OC1M = 110 (PWM mode 1) */
    TIM2->CCMR1 |=  (1U << 3);    /* OC1PE: preload enable */

    TIM2->CCER |= (1U << 0);      /* Enable CH1 output */
    TIM2->CR1 |= (1U << 0);       /* Start timer */
}

void pwm_set_duty(uint16_t duty_percent)
{
    TIM2->CCR1 = (TIM2->ARR + 1) * duty_percent / 100;
}
```

### LED Brightness Control with PWM

```c
int main(void)
{
    pwm_init();

    while (1) {
        /* Fade in */
        for (uint16_t duty = 0; duty <= 100; duty++) {
            pwm_set_duty(duty);
            delay_ms(20);
        }
        /* Fade out */
        for (uint16_t duty = 100; duty > 0; duty--) {
            pwm_set_duty(duty);
            delay_ms(20);
        }
    }
}
```

### Servo Motor Control

Standard hobby servos expect a PWM signal with:
- **Period:** 20 ms (50 Hz)
- **Pulse width:** 1 ms (0°) to 2 ms (180°)

```c
void servo_init(void)
{
    /* TIM3 for servo on PA6 (TIM3_CH1) */
    TIM3->PSC = 84 - 1;        /* 1 MHz */
    TIM3->ARR = 20000 - 1;     /* 20 ms period = 50 Hz */
    TIM3->CCR1 = 1500;         /* 1.5 ms = center position (90°) */

    /* PWM mode 1, output enable */
    TIM3->CCMR1 |= (6U << 4);
    TIM3->CCER |= (1U << 0);
    TIM3->CR1 |= (1U << 0);
}

void servo_set_angle(uint8_t angle)
{
    /* Map 0-180° to 1000-2000 µs pulse width */
    uint16_t pulse_us = 1000 + ((uint32_t)angle * 1000 / 180);
    TIM3->CCR1 = pulse_us;
}
```

### Mode 3: Input Capture

Measure the period or pulse width of an external signal by capturing the counter value when an edge occurs:

```c
volatile uint32_t captured_period = 0;

void input_capture_init(void)
{
    /* TIM4 CH1 on PB6 */
    TIM4->PSC = 84 - 1;            /* 1 µs resolution */
    TIM4->ARR = 0xFFFF;            /* Free-running */

    TIM4->CCMR1 &= ~(3U << 0);    /* CC1S = 01: input, mapped to TI1 */
    TIM4->CCMR1 |=  (1U << 0);

    TIM4->CCER |= (1U << 0);      /* Enable capture */
    TIM4->DIER |= (1U << 1);      /* CC1 interrupt enable */
    TIM4->CR1  |= (1U << 0);      /* Start timer */

    NVIC_EnableIRQ(TIM4_IRQn);
}

void TIM4_IRQHandler(void)
{
    static uint32_t last_capture = 0;

    if (TIM4->SR & (1U << 1)) {
        TIM4->SR &= ~(1U << 1);

        uint32_t current = TIM4->CCR1;
        if (current >= last_capture)
            captured_period = current - last_capture;
        else
            captured_period = (0xFFFF - last_capture) + current + 1;

        last_capture = current;
    }
}
```

## Watchdog Timer

The watchdog timer resets the MCU if software hangs. The main loop must periodically "feed" (reload) the watchdog:

```c
void iwdg_init(uint32_t timeout_ms)
{
    IWDG->KR = 0x5555;                   /* Enable write access */
    IWDG->PR = 4;                         /* Prescaler /64 */
    IWDG->RLR = (timeout_ms * 32) / 64;  /* Reload value */
    IWDG->KR = 0xCCCC;                   /* Start the watchdog */
}

void iwdg_feed(void)
{
    IWDG->KR = 0xAAAA;  /* Reload counter */
}

int main(void)
{
    iwdg_init(1000);  /* 1-second timeout */

    while (1) {
        do_main_work();
        iwdg_feed();  /* Must call within 1 second or MCU resets */
    }
}
```

## Practical Examples

- [`examples/04_timers/periodic_interrupt.c`](../examples/04_timers/periodic_interrupt.c) — 1 ms periodic timer interrupt
- [`examples/04_timers/pwm_led_fade.c`](../examples/04_timers/pwm_led_fade.c) — LED brightness control with PWM
- [`examples/09_watchdog/watchdog_timer.c`](../examples/09_watchdog/watchdog_timer.c) — Watchdog configuration and feeding

## Summary

- Timers count clock cycles through a prescaler and auto-reload mechanism.
- Use the formula: `Frequency = Clock / ((PSC+1) * (ARR+1))`.
- PWM output controls average power — used for LED dimming, motor speed, and servos.
- Input capture measures external signal timing.
- Watchdog timers provide a safety net against software hangs.

---

**Next:** [Chapter 10 — UART / Serial Communication](10-uart-serial-communication.md)
