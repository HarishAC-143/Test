/**
 * @file    02_timer_driver.c
 * @brief   Timer driver with multiple modes: periodic interrupt, PWM, input capture
 *
 * Demonstrates:
 *  - Basic timer configuration for periodic interrupts
 *  - Software delay using SysTick
 *  - PWM generation for LED dimming and motor control
 *  - Input capture for frequency measurement
 *  - Encoder mode for rotary encoder reading
 *
 * Target: Generic ARM Cortex-M with STM32-like timer peripheral
 */

#include <stdint.h>

/* ──────────────────────────────────────────────────────────────────────────
 * Timer Register Definitions
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    volatile uint32_t CR1;
    volatile uint32_t CR2;
    volatile uint32_t SMCR;
    volatile uint32_t DIER;
    volatile uint32_t SR;
    volatile uint32_t EGR;
    volatile uint32_t CCMR1;
    volatile uint32_t CCMR2;
    volatile uint32_t CCER;
    volatile uint32_t CNT;
    volatile uint32_t PSC;
    volatile uint32_t ARR;
    uint32_t          RESERVED0;
    volatile uint32_t CCR1;
    volatile uint32_t CCR2;
    volatile uint32_t CCR3;
    volatile uint32_t CCR4;
    uint32_t          RESERVED1;
    volatile uint32_t DCR;
    volatile uint32_t DMAR;
} TIM_TypeDef;

#define TIM2   ((TIM_TypeDef *)0x40000000U)
#define TIM3   ((TIM_TypeDef *)0x40000400U)
#define TIM4   ((TIM_TypeDef *)0x40000800U)

/* SysTick registers */
#define SYSTICK_CSR    (*(volatile uint32_t *)0xE000E010U)
#define SYSTICK_RVR    (*(volatile uint32_t *)0xE000E014U)
#define SYSTICK_CVR    (*(volatile uint32_t *)0xE000E018U)

/* CR1 bits */
#define TIM_CR1_CEN    (1U << 0)  /* Counter enable */
#define TIM_CR1_ARPE   (1U << 7)  /* Auto-reload preload enable */

/* DIER bits */
#define TIM_DIER_UIE   (1U << 0)  /* Update interrupt enable */
#define TIM_DIER_CC1IE (1U << 1)  /* Capture/compare 1 interrupt */

/* SR bits */
#define TIM_SR_UIF     (1U << 0)  /* Update interrupt flag */
#define TIM_SR_CC1IF   (1U << 1)  /* Capture/compare 1 interrupt flag */

/* System clock assumed 72 MHz */
#define SYSTEM_CLOCK_HZ  72000000U

/* ──────────────────────────────────────────────────────────────────────────
 * SysTick Millisecond Timer
 * ────────────────────────────────────────────────────────────────────────── */

static volatile uint32_t tick_ms = 0;

void systick_init(uint32_t sys_clk)
{
    SYSTICK_RVR = (sys_clk / 1000U) - 1;
    SYSTICK_CVR = 0;
    SYSTICK_CSR = (1U << 0)    /* Enable */
                | (1U << 1)    /* Interrupt enable */
                | (1U << 2);   /* Use processor clock */
}

void SysTick_Handler(void)
{
    tick_ms++;
}

uint32_t millis(void)
{
    return tick_ms;
}

void delay_ms(uint32_t ms)
{
    uint32_t start = tick_ms;
    while ((tick_ms - start) < ms);
}

/* Microsecond delay using cycle counting (blocking) */
void delay_us(uint32_t us)
{
    uint32_t cycles = (SYSTEM_CLOCK_HZ / 1000000U) * us;
    while (cycles > 0) {
        cycles--;
        __asm volatile ("NOP");
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * General-Purpose Timer: Periodic Interrupt
 * ────────────────────────────────────────────────────────────────────────── */

void timer_init_periodic(TIM_TypeDef *tim, uint32_t freq_hz)
{
    uint32_t period = SYSTEM_CLOCK_HZ / freq_hz;
    uint32_t prescaler = 0;

    /* Find prescaler to keep ARR within 16-bit range */
    while (period > 65535U) {
        prescaler++;
        period = SYSTEM_CLOCK_HZ / ((prescaler + 1) * freq_hz);
    }

    tim->CR1  = 0;
    tim->PSC  = prescaler;
    tim->ARR  = period - 1;
    tim->EGR  = (1U << 0);      /* Generate update event to load PSC/ARR */
    tim->SR   = 0;               /* Clear pending flags */
    tim->DIER = TIM_DIER_UIE;   /* Enable update interrupt */
    tim->CR1  = TIM_CR1_CEN;    /* Start counting */
}

void timer_stop(TIM_TypeDef *tim)
{
    tim->CR1 &= ~TIM_CR1_CEN;
    tim->DIER = 0;
}

/* Example ISR for TIM2 */
static volatile uint32_t timer2_ticks = 0;

void TIM2_IRQHandler(void)
{
    if (TIM2->SR & TIM_SR_UIF) {
        TIM2->SR &= ~TIM_SR_UIF;
        timer2_ticks++;
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * PWM Generation
 * ────────────────────────────────────────────────────────────────────────── */

typedef struct {
    TIM_TypeDef *timer;
    uint8_t      channel;   /* 1–4 */
    uint32_t     frequency;
    uint32_t     period;    /* Computed: ARR value */
} pwm_handle_t;

void pwm_init(pwm_handle_t *h, TIM_TypeDef *tim, uint8_t channel,
              uint32_t freq_hz)
{
    h->timer     = tim;
    h->channel   = channel;
    h->frequency = freq_hz;

    uint32_t period = SYSTEM_CLOCK_HZ / freq_hz;
    uint32_t psc = 0;
    while (period > 65535U) {
        psc++;
        period = SYSTEM_CLOCK_HZ / ((psc + 1) * freq_hz);
    }
    h->period = period;

    tim->CR1  = 0;
    tim->PSC  = psc;
    tim->ARR  = period - 1;
    tim->CR1 |= TIM_CR1_ARPE;

    /* Configure the selected channel for PWM mode 1 (active while CNT < CCR) */
    uint32_t ccmr_val = (0x6U << 4) | (1U << 3);  /* OC mode 110 + preload */

    switch (channel) {
    case 1:
        tim->CCMR1 &= ~0x00FFU;
        tim->CCMR1 |= ccmr_val;
        tim->CCER  |= (1U << 0);   /* Enable CH1 output */
        tim->CCR1   = 0;
        break;
    case 2:
        tim->CCMR1 &= ~0xFF00U;
        tim->CCMR1 |= (ccmr_val << 8);
        tim->CCER  |= (1U << 4);
        tim->CCR2   = 0;
        break;
    case 3:
        tim->CCMR2 &= ~0x00FFU;
        tim->CCMR2 |= ccmr_val;
        tim->CCER  |= (1U << 8);
        tim->CCR3   = 0;
        break;
    case 4:
        tim->CCMR2 &= ~0xFF00U;
        tim->CCMR2 |= (ccmr_val << 8);
        tim->CCER  |= (1U << 12);
        tim->CCR4   = 0;
        break;
    default:
        return;
    }

    tim->EGR  = (1U << 0);
    tim->CR1 |= TIM_CR1_CEN;
}

void pwm_set_duty(pwm_handle_t *h, uint8_t duty_percent)
{
    if (duty_percent > 100) duty_percent = 100;
    uint32_t pulse = (h->period * duty_percent) / 100;

    switch (h->channel) {
    case 1: h->timer->CCR1 = pulse; break;
    case 2: h->timer->CCR2 = pulse; break;
    case 3: h->timer->CCR3 = pulse; break;
    case 4: h->timer->CCR4 = pulse; break;
    default: break;
    }
}

void pwm_set_duty_raw(pwm_handle_t *h, uint32_t pulse)
{
    if (pulse > h->period) pulse = h->period;

    switch (h->channel) {
    case 1: h->timer->CCR1 = pulse; break;
    case 2: h->timer->CCR2 = pulse; break;
    case 3: h->timer->CCR3 = pulse; break;
    case 4: h->timer->CCR4 = pulse; break;
    default: break;
    }
}

/* ──────────────────────────────────────────────────────────────────────────
 * Input Capture: Frequency Measurement
 * ────────────────────────────────────────────────────────────────────────── */

static volatile uint32_t capture_val[2];
static volatile uint8_t  capture_index = 0;
static volatile uint8_t  capture_done = 0;

void input_capture_init(TIM_TypeDef *tim)
{
    tim->CR1  = 0;
    tim->PSC  = 72 - 1;                /* 1 µs resolution at 72 MHz */
    tim->ARR  = 0xFFFF;                /* Full range */

    tim->CCMR1 = (0x01U << 0);         /* CC1 as input, mapped to TI1 */
    tim->CCER  = (1U << 0);            /* Enable capture on CH1, rising edge */

    tim->DIER  = TIM_DIER_CC1IE;       /* Enable CC1 interrupt */
    tim->CR1   = TIM_CR1_CEN;          /* Start timer */
}

void TIM3_IRQHandler(void)
{
    if (TIM3->SR & TIM_SR_CC1IF) {
        TIM3->SR &= ~TIM_SR_CC1IF;

        capture_val[capture_index] = TIM3->CCR1;
        capture_index++;

        if (capture_index >= 2) {
            capture_index = 0;
            capture_done = 1;
        }
    }
}

uint32_t input_capture_get_frequency(void)
{
    if (!capture_done) return 0;
    capture_done = 0;

    uint32_t diff;
    if (capture_val[1] >= capture_val[0]) {
        diff = capture_val[1] - capture_val[0];
    } else {
        diff = (0xFFFF - capture_val[0]) + capture_val[1] + 1;
    }

    if (diff == 0) return 0;
    return 1000000U / diff;  /* Timer ticks at 1 MHz → period in µs */
}

/* ──────────────────────────────────────────────────────────────────────────
 * Encoder Mode: Quadrature Encoder Reading
 * ────────────────────────────────────────────────────────────────────────── */

void encoder_init(TIM_TypeDef *tim)
{
    tim->CR1  = 0;
    tim->SMCR = 0x03;                  /* Encoder mode 3 (count on both edges) */

    tim->CCMR1 = (0x01 << 0)           /* CC1 as input, mapped to TI1 */
               | (0x01 << 8);          /* CC2 as input, mapped to TI2 */

    tim->CCER = 0;                     /* Non-inverted, rising edge */
    tim->ARR  = 0xFFFF;               /* Full 16-bit range */
    tim->CNT  = 32768;                /* Start at midpoint */

    tim->CR1 |= TIM_CR1_CEN;          /* Start */
}

int16_t encoder_get_position(TIM_TypeDef *tim)
{
    return (int16_t)(tim->CNT - 32768);
}

int16_t encoder_get_delta(TIM_TypeDef *tim)
{
    static int16_t last_pos = 0;
    int16_t pos = encoder_get_position(tim);
    int16_t delta = pos - last_pos;
    last_pos = pos;
    return delta;
}

/* ──────────────────────────────────────────────────────────────────────────
 * Application Example: LED Breathing Effect with PWM
 * ────────────────────────────────────────────────────────────────────────── */

int main(void)
{
    systick_init(SYSTEM_CLOCK_HZ);

    /* Initialize PWM on TIM2 CH1 at 1 kHz */
    pwm_handle_t led_pwm;
    pwm_init(&led_pwm, TIM2, 1, 1000);

    /* Breathing LED: ramp up, ramp down */
    uint8_t duty = 0;
    int8_t  direction = 1;

    while (1) {
        pwm_set_duty(&led_pwm, duty);

        duty += direction;
        if (duty >= 100) direction = -1;
        if (duty == 0)   direction =  1;

        delay_ms(10);
    }

    return 0;
}
