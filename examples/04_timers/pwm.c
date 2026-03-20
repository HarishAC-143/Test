/**
 * @file    pwm.c
 * @brief   PWM generation using a general-purpose timer (TIM2).
 * @target  STM32F4xx (TIM2 CH1 → PA0 or PA5 via alternate function)
 *
 * Demonstrates:
 *  - Timer configuration for PWM output
 *  - Duty cycle control (LED brightness, motor speed)
 *  - Frequency selection
 *  - Multiple PWM channels
 *  - LED breathing (fade in/out) effect
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

/* RCC */
#define RCC_BASE        0x40023800U
#define RCC_AHB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x30))
#define RCC_APB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x40))

/* GPIOA */
#define GPIOA_BASE      0x40020000U
#define GPIOA_MODER     (*(volatile uint32_t *)(GPIOA_BASE + 0x00))
#define GPIOA_AFRL      (*(volatile uint32_t *)(GPIOA_BASE + 0x20))

/* TIM2 (32-bit general-purpose timer) */
typedef struct {
    volatile uint32_t CR1;      /* 0x00: Control register 1      */
    volatile uint32_t CR2;      /* 0x04: Control register 2      */
    volatile uint32_t SMCR;     /* 0x08: Slave mode control      */
    volatile uint32_t DIER;     /* 0x0C: DMA/interrupt enable    */
    volatile uint32_t SR;       /* 0x10: Status register         */
    volatile uint32_t EGR;      /* 0x14: Event generation        */
    volatile uint32_t CCMR1;    /* 0x18: Capture/compare mode 1  */
    volatile uint32_t CCMR2;    /* 0x1C: Capture/compare mode 2  */
    volatile uint32_t CCER;     /* 0x20: Capture/compare enable  */
    volatile uint32_t CNT;      /* 0x24: Counter                 */
    volatile uint32_t PSC;      /* 0x28: Prescaler               */
    volatile uint32_t ARR;      /* 0x2C: Auto-reload (period)    */
    volatile uint32_t RESERVED; /* 0x30                          */
    volatile uint32_t CCR1;     /* 0x34: Capture/compare 1       */
    volatile uint32_t CCR2;     /* 0x38: Capture/compare 2       */
    volatile uint32_t CCR3;     /* 0x3C: Capture/compare 3       */
    volatile uint32_t CCR4;     /* 0x40: Capture/compare 4       */
} TIM_TypeDef;

#define TIM2    ((TIM_TypeDef *)0x40000000U)

/* Timer register bits */
#define TIM_CR1_CEN         (1U << 0)   /* Counter enable     */
#define TIM_CR1_ARPE        (1U << 7)   /* Auto-reload preload */
#define TIM_CCER_CC1E       (1U << 0)   /* CH1 output enable  */
#define TIM_CCER_CC2E       (1U << 4)   /* CH2 output enable  */
#define TIM_CCER_CC1P       (1U << 1)   /* CH1 polarity       */
#define TIM_EGR_UG          (1U << 0)   /* Update generation  */

/* CCMR Output Compare mode bits */
#define TIM_CCMR_OC1M_PWM1  (6U << 4)   /* PWM mode 1 on CH1 */
#define TIM_CCMR_OC1PE      (1U << 3)   /* CH1 preload enable */
#define TIM_CCMR_OC2M_PWM1  (6U << 12)  /* PWM mode 1 on CH2 */
#define TIM_CCMR_OC2PE      (1U << 11)  /* CH2 preload enable */

/* ========================================================================== */
/*  PWM Configuration                                                          */
/* ========================================================================== */

/**
 * PWM frequency and resolution trade-off:
 *
 *   PWM_freq = timer_clk / ((PSC + 1) * (ARR + 1))
 *
 *   Higher ARR → finer duty cycle resolution, lower max frequency.
 *   Lower  ARR → coarser resolution, higher max frequency.
 *
 *   Example at 84 MHz timer clock:
 *     PSC=0,  ARR=8399  → 10 kHz,  8400 steps (0.012% resolution)
 *     PSC=0,  ARR=839   → 100 kHz, 840 steps
 *     PSC=83, ARR=999   → 1 kHz,   1000 steps (0.1% resolution)
 */

#define TIMER_CLK_HZ    84000000U  /* APB1 timer clock (84 MHz on STM32F4) */

/**
 * Configure TIM2 CH1 for PWM output on PA0 (AF1).
 *
 * @param freq_hz     Desired PWM frequency in Hz
 * @param duty_pct    Initial duty cycle percentage (0-100)
 */
void pwm_init(uint32_t freq_hz, uint8_t duty_pct)
{
    /* Enable clocks */
    RCC_AHB1ENR |= (1U << 0);   /* GPIOA */
    RCC_APB1ENR |= (1U << 0);   /* TIM2  */

    /* Configure PA0 as Alternate Function 1 (TIM2_CH1) */
    GPIOA_MODER &= ~(3U << 0);
    GPIOA_MODER |=  (2U << 0);   /* AF mode */
    GPIOA_AFRL  &= ~(0xFU << 0);
    GPIOA_AFRL  |=  (1U << 0);   /* AF1 = TIM2 */

    /* Calculate prescaler and auto-reload for desired frequency */
    uint32_t arr_val;
    uint32_t psc_val = 0;

    arr_val = (TIMER_CLK_HZ / freq_hz) - 1;

    /* If ARR exceeds 16-bit range, use prescaler to bring it down */
    while (arr_val > 65535 && psc_val < 65535) {
        psc_val++;
        arr_val = (TIMER_CLK_HZ / ((psc_val + 1) * freq_hz)) - 1;
    }

    /* Configure timer */
    TIM2->PSC  = psc_val;
    TIM2->ARR  = arr_val;
    TIM2->CCR1 = (arr_val * duty_pct) / 100;

    /* PWM mode 1: output HIGH when CNT < CCR, LOW when CNT >= CCR */
    TIM2->CCMR1 = TIM_CCMR_OC1M_PWM1 | TIM_CCMR_OC1PE;

    /* Enable CH1 output, active HIGH */
    TIM2->CCER = TIM_CCER_CC1E;

    /* Enable auto-reload preload */
    TIM2->CR1 = TIM_CR1_ARPE;

    /* Force update to load shadow registers */
    TIM2->EGR = TIM_EGR_UG;

    /* Start the timer */
    TIM2->CR1 |= TIM_CR1_CEN;
}

/**
 * Set the PWM duty cycle (0-100%).
 */
void pwm_set_duty(uint8_t duty_pct)
{
    if (duty_pct > 100) duty_pct = 100;
    TIM2->CCR1 = (TIM2->ARR * duty_pct) / 100;
}

/**
 * Set the PWM duty cycle with 0.01% resolution.
 * @param duty_hundredths  Duty cycle in hundredths of a percent (0-10000)
 */
void pwm_set_duty_fine(uint16_t duty_hundredths)
{
    if (duty_hundredths > 10000) duty_hundredths = 10000;
    TIM2->CCR1 = ((uint32_t)TIM2->ARR * duty_hundredths) / 10000;
}

/**
 * Set the raw compare value directly (for maximum control).
 */
void pwm_set_compare(uint32_t compare_value)
{
    if (compare_value > TIM2->ARR) compare_value = TIM2->ARR;
    TIM2->CCR1 = compare_value;
}

/* ========================================================================== */
/*  LED Breathing Effect                                                       */
/* ========================================================================== */

/*
 * Gamma-corrected brightness table for smooth LED fading.
 * Human eye perceives brightness logarithmically, so linear PWM
 * changes look uneven. This table compensates.
 *
 * 32 steps, values 0-255.
 */
static const uint8_t gamma_table[32] = {
    0,   1,   2,   3,   4,   6,   8,  11,
   14,  18,  23,  29,  36,  44,  53,  63,
   74,  87, 101, 117, 134, 153, 173, 195,
  200, 210, 220, 230, 237, 244, 250, 255
};

/**
 * SysTick-based delay (requires systick_init from systick.c).
 */
extern volatile uint32_t systick_ms;

static void delay_ms(uint32_t ms)
{
    /* Simplified for this example */
    volatile uint32_t count = ms * 16000;
    while (count--) { }
}

/**
 * Breathing LED effect: smooth fade in and fade out.
 */
void led_breathe(void)
{
    /* Fade in */
    for (int i = 0; i < 32; i++) {
        pwm_set_duty((uint8_t)((uint16_t)gamma_table[i] * 100 / 255));
        delay_ms(30);
    }

    /* Fade out */
    for (int i = 31; i >= 0; i--) {
        pwm_set_duty((uint8_t)((uint16_t)gamma_table[i] * 100 / 255));
        delay_ms(30);
    }

    delay_ms(200);  /* Pause at off state */
}

/* ========================================================================== */
/*  Servo Motor Control (1-2 ms pulse at 50 Hz)                                */
/* ========================================================================== */

/**
 * Configure PWM for standard hobby servos.
 * Servo expects 50 Hz (20 ms period), with pulse width 1-2 ms.
 *   1.0 ms = 0°
 *   1.5 ms = 90° (center)
 *   2.0 ms = 180°
 */
void servo_init(void)
{
    pwm_init(50, 0);  /* 50 Hz */
}

/**
 * Set servo angle (0-180 degrees).
 *
 * At 50 Hz with 84 MHz clock:
 *   ARR = 84000000 / 50 - 1 = 1679999
 *   1 ms pulse = 1679999 * 1/20 = 84000
 *   2 ms pulse = 1679999 * 2/20 = 168000
 */
void servo_set_angle(uint16_t angle_deg)
{
    if (angle_deg > 180) angle_deg = 180;

    /* Map 0-180° to 1.0-2.0 ms pulse width */
    uint32_t min_pulse = (TIM2->ARR + 1) / 20;       /* 1 ms  = 5% of 20 ms */
    uint32_t max_pulse = (TIM2->ARR + 1) * 2 / 20;   /* 2 ms  = 10% of 20 ms */

    uint32_t pulse = min_pulse + ((max_pulse - min_pulse) * angle_deg) / 180;
    TIM2->CCR1 = pulse;
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    /* Example 1: 1 kHz PWM for LED dimming */
    pwm_init(1000, 50);  /* 1 kHz, 50% duty */

    /* Breathing effect */
    while (1) {
        led_breathe();
    }

    /* Example 2: Servo control (uncomment to use) */
    /*
    servo_init();
    while (1) {
        servo_set_angle(0);    delay_ms(1000);
        servo_set_angle(90);   delay_ms(1000);
        servo_set_angle(180);  delay_ms(1000);
        servo_set_angle(90);   delay_ms(1000);
    }
    */
}
