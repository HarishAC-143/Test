/**
 * Example 06: PWM — Pulse Width Modulation
 *
 * Target: STM32F4 (ARM Cortex-M4) — register-level, no HAL
 *
 * Generates a PWM signal on PA5 (TIM2 CH1 or via alternate function)
 * to control LED brightness.  The duty cycle ramps up and down to
 * produce a "breathing" LED effect.
 *
 * Concepts demonstrated:
 *   - Timer in PWM mode (output compare)
 *   - Duty cycle control via CCR (Capture/Compare Register)
 *   - PWM frequency calculation
 *   - Servo motor control (50 Hz PWM, 1–2 ms pulse)
 *   - Multiple PWM channels for RGB LED or multi-motor
 */

#include <stdint.h>

/* ───────────────────── Base Addresses ───────────────────── */

#define PERIPH_BASE       ((uint32_t)0x40000000)
#define APB1_BASE         (PERIPH_BASE)
#define AHB1_BASE         (PERIPH_BASE + 0x00020000)

#define RCC_BASE          (AHB1_BASE + 0x3800)
#define GPIOA_BASE        (AHB1_BASE + 0x0000)
#define TIM2_BASE         (APB1_BASE + 0x0000)

/* ───────────────────── Register Access ──────────────────── */

#define REG32(addr)       (*(volatile uint32_t *)(addr))

/* RCC */
#define RCC_AHB1ENR       REG32(RCC_BASE + 0x30)
#define RCC_APB1ENR       REG32(RCC_BASE + 0x40)

/* GPIOA */
#define GPIOA_MODER       REG32(GPIOA_BASE + 0x00)
#define GPIOA_AFRL        REG32(GPIOA_BASE + 0x20)

/* TIM2 */
#define TIM2_CR1          REG32(TIM2_BASE + 0x00)
#define TIM2_CCMR1        REG32(TIM2_BASE + 0x18)   /* Capture/Compare mode 1 */
#define TIM2_CCER         REG32(TIM2_BASE + 0x20)   /* Capture/Compare enable */
#define TIM2_CNT          REG32(TIM2_BASE + 0x24)
#define TIM2_PSC          REG32(TIM2_BASE + 0x28)
#define TIM2_ARR          REG32(TIM2_BASE + 0x2C)
#define TIM2_CCR1         REG32(TIM2_BASE + 0x34)   /* Capture/Compare register 1 */

/* ───────────────────── Constants ────────────────────────── */

#define BIT(n)            (1UL << (n))

/*
 * PWM Frequency: 1 kHz (good for LED dimming)
 *
 * F_CLK   = 16 MHz (HSI default)
 * PSC     = 15     → timer clock = 16 MHz / 16 = 1 MHz
 * ARR     = 999    → PWM freq = 1 MHz / 1000 = 1 kHz
 *
 * Duty cycle = CCR1 / (ARR + 1) × 100%
 *   CCR1 = 0    → 0% (off)
 *   CCR1 = 500  → 50%
 *   CCR1 = 1000 → 100% (fully on)
 */
#define PWM_PSC           15
#define PWM_ARR           999
#define PWM_PERIOD        (PWM_ARR + 1)

/* ───────────────────── Delay ────────────────────────────── */

static void delay(volatile uint32_t count)
{
    while (count--) { }
}

/* ───────────────────── PWM Setup ────────────────────────── */

static void pwm_init(void)
{
    /* Enable clocks */
    RCC_AHB1ENR |= BIT(0);     /* GPIOA */
    RCC_APB1ENR |= BIT(0);     /* TIM2  */

    /*
     * Configure PA5 as Alternate Function (TIM2_CH1).
     *
     * On STM32F4, TIM2_CH1 can be mapped to PA0 (AF1) or PA5 (AF1).
     * We'll use PA5 since it connects to the on-board LED on Nucleo.
     *
     * MODER: bits [11:10] = 10 (alternate function)
     * AFRL:  bits [23:20] = 0001 (AF1 = TIM2)
     */
    GPIOA_MODER &= ~(0x03UL << (5 * 2));
    GPIOA_MODER |=  (0x02UL << (5 * 2));

    GPIOA_AFRL &= ~(0x0FUL << (5 * 4));
    GPIOA_AFRL |=  (0x01UL << (5 * 4));

    /* Stop the timer */
    TIM2_CR1 = 0;

    /* Set prescaler and auto-reload */
    TIM2_PSC = PWM_PSC;
    TIM2_ARR = PWM_ARR;

    /*
     * Configure Channel 1 in PWM Mode 1:
     *
     * CCMR1 bits [6:4] = OC1M (Output Compare 1 Mode):
     *   110 = PWM mode 1 (active when CNT < CCR1, inactive otherwise)
     *
     * CCMR1 bit 3 = OC1PE (Output Compare 1 Preload Enable):
     *   1 = CCR1 is buffered (takes effect at next update event)
     */
    TIM2_CCMR1 &= ~(0x7FUL << 0);
    TIM2_CCMR1 |=  (0x06UL << 4);     /* PWM mode 1          */
    TIM2_CCMR1 |=  BIT(3);             /* Enable preload      */

    /*
     * Enable Channel 1 output.
     * CCER bit 0 = CC1E (Capture/Compare 1 output enable).
     */
    TIM2_CCER |= BIT(0);

    /* Set initial duty cycle to 0% */
    TIM2_CCR1 = 0;

    /* Reset counter */
    TIM2_CNT = 0;

    /* Start the timer */
    TIM2_CR1 |= BIT(0);    /* CEN */
}

/**
 * Set PWM duty cycle as a percentage (0–100).
 */
static void pwm_set_duty(uint8_t percent)
{
    if (percent > 100) percent = 100;
    TIM2_CCR1 = (uint32_t)PWM_PERIOD * percent / 100;
}

/**
 * Set PWM duty cycle as a raw CCR value (0 – PWM_PERIOD).
 */
static void pwm_set_raw(uint32_t value)
{
    if (value > PWM_PERIOD) value = PWM_PERIOD;
    TIM2_CCR1 = value;
}

/* ───────────────────── Servo Control ────────────────────── */

/*
 * Servo motors expect a 50 Hz PWM signal (20 ms period).
 * Position is encoded in the pulse width:
 *   1.0 ms → 0°   (fully left)
 *   1.5 ms → 90°  (center)
 *   2.0 ms → 180° (fully right)
 *
 * For a 50 Hz PWM:
 *   PSC = 15    → 1 MHz timer clock
 *   ARR = 19999 → 20 ms period
 *   CCR = 1000  → 1 ms pulse = 0°
 *   CCR = 1500  → 1.5 ms     = 90°
 *   CCR = 2000  → 2 ms       = 180°
 *
 * Angle → CCR:
 *   CCR = 1000 + (angle × 1000 / 180)
 */

/**
 * Set servo angle (0–180 degrees).
 * Assumes the timer is configured for 50 Hz (ARR = 19999).
 */
static void servo_set_angle(uint16_t angle_deg)
{
    if (angle_deg > 180) angle_deg = 180;
    uint32_t ccr = 1000 + ((uint32_t)angle_deg * 1000 / 180);
    TIM2_CCR1 = ccr;
}

/* ───────────────────── Main ─────────────────────────────── */

int main(void)
{
    pwm_init();

    /*
     * "Breathing" LED: smoothly ramp duty cycle up and down.
     */
    while (1) {
        /* Ramp up: 0% → 100% */
        for (uint32_t duty = 0; duty <= PWM_PERIOD; duty += 5) {
            pwm_set_raw(duty);
            delay(5000);
        }

        /* Ramp down: 100% → 0% */
        for (uint32_t duty = PWM_PERIOD; duty > 0; duty -= 5) {
            pwm_set_raw(duty);
            delay(5000);
        }
        pwm_set_raw(0);
        delay(100000);
    }

    return 0;
}
