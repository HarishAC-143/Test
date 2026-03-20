/**
 * @file    sleep_modes.c
 * @brief   Low-power sleep mode examples for battery-powered applications.
 * @target  STM32F4xx (Cortex-M4)
 *
 * Demonstrates:
 *  - Sleep mode (WFI) — CPU sleeps, peripherals active
 *  - Stop mode — most clocks stopped, SRAM retained
 *  - Standby mode — deepest sleep, only backup domain active
 *  - RTC wakeup timer configuration
 *  - Power consumption optimization techniques
 *
 * Power Consumption (typical STM32F4):
 *   Run mode:     ~20-100 mA  (depending on clock speed)
 *   Sleep mode:   ~5-10 mA    (peripherals still running)
 *   Stop mode:    ~100-400 µA (SRAM retained)
 *   Standby mode: ~2-5 µA     (SRAM lost, RTC/backup retained)
 */

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================== */
/*  Register Definitions                                                       */
/* ========================================================================== */

/* System Control Block */
#define SCB_SCR         (*(volatile uint32_t *)0xE000ED10)
#define SCB_SCR_SLEEPDEEP   (1U << 2)
#define SCB_SCR_SLEEPONEXIT (1U << 1)

/* Power Control */
typedef struct {
    volatile uint32_t CR;       /* 0x00 */
    volatile uint32_t CSR;      /* 0x04 */
} PWR_TypeDef;

#define PWR         ((PWR_TypeDef *)0x40007000U)
#define PWR_CR_LPDS     (1U << 0)   /* Low-power deepsleep         */
#define PWR_CR_PDDS     (1U << 1)   /* Power-down deepsleep        */
#define PWR_CR_CWUF     (1U << 2)   /* Clear wakeup flag           */
#define PWR_CR_DBP      (1U << 8)   /* Disable backup protection   */
#define PWR_CSR_WUF     (1U << 0)   /* Wakeup flag                 */

/* RCC */
#define RCC_BASE        0x40023800U
#define RCC_APB1ENR     (*(volatile uint32_t *)(RCC_BASE + 0x40))
#define RCC_BDCR        (*(volatile uint32_t *)(RCC_BASE + 0x70))
#define RCC_CSR         (*(volatile uint32_t *)(RCC_BASE + 0x74))

/* RTC */
typedef struct {
    volatile uint32_t TR;       /* 0x00: Time register           */
    volatile uint32_t DR;       /* 0x04: Date register           */
    volatile uint32_t CR;       /* 0x08: Control register        */
    volatile uint32_t ISR;      /* 0x0C: Init and status         */
    volatile uint32_t PRER;     /* 0x10: Prescaler               */
    volatile uint32_t WUTR;     /* 0x14: Wakeup timer register   */
    volatile uint32_t CALIBR;   /* 0x18: Calibration register    */
    volatile uint32_t ALRMAR;   /* 0x1C: Alarm A register        */
    volatile uint32_t ALRMBR;   /* 0x20: Alarm B register        */
    volatile uint32_t WPR;      /* 0x24: Write protection        */
} RTC_TypeDef;

#define RTC     ((RTC_TypeDef *)0x40002800U)

/* EXTI */
#define EXTI_BASE       0x40013C00U
#define EXTI_IMR        (*(volatile uint32_t *)(EXTI_BASE + 0x00))
#define EXTI_RTSR       (*(volatile uint32_t *)(EXTI_BASE + 0x08))
#define EXTI_PR         (*(volatile uint32_t *)(EXTI_BASE + 0x14))

/* NVIC */
#define NVIC_ISER0      (*(volatile uint32_t *)0xE000E100)

/* ========================================================================== */
/*  Clock Reconfiguration (needed after waking from Stop mode)                 */
/* ========================================================================== */

extern void system_clock_config(void);  /* Re-enable PLL after Stop mode */

/* ========================================================================== */
/*  Sleep Mode (WFI)                                                           */
/* ========================================================================== */

/**
 * Enter Sleep mode.
 *
 * CPU core stops, all peripherals and clocks continue running.
 * Wake-up: any interrupt.
 *
 * Best for: Waiting between periodic events when peripherals must stay active.
 */
void enter_sleep_mode(void)
{
    /* Clear SLEEPDEEP bit → normal sleep, not deep sleep */
    SCB_SCR &= ~SCB_SCR_SLEEPDEEP;

    /* Wait For Interrupt — CPU sleeps until any interrupt fires */
    __asm volatile ("dsb");  /* Data synchronization barrier */
    __asm volatile ("wfi");
    __asm volatile ("isb");  /* Instruction synchronization barrier */
}

/**
 * Enter Sleep mode with "sleep on exit" — CPU sleeps automatically
 * after every ISR returns, without executing main loop code.
 *
 * Useful when all work is done in interrupts.
 */
void enter_sleep_on_exit(void)
{
    SCB_SCR &= ~SCB_SCR_SLEEPDEEP;
    SCB_SCR |= SCB_SCR_SLEEPONEXIT;
    __asm volatile ("wfi");
}

/* ========================================================================== */
/*  Stop Mode                                                                  */
/* ========================================================================== */

/**
 * Enter Stop mode.
 *
 * All clocks stopped except LSI/LSE. SRAM and registers retained.
 * Main regulator or low-power regulator active.
 * Wake-up: EXTI line (external interrupt, RTC alarm/wakeup).
 *
 * After wakeup, HSI (16 MHz) is the system clock — must reconfigure PLL.
 *
 * Best for: Periodic sensor reading with long sleep intervals.
 */
void enter_stop_mode(void)
{
    /* Set SLEEPDEEP bit */
    SCB_SCR |= SCB_SCR_SLEEPDEEP;

    /* Configure Stop mode: PDDS=0 (Stop, not Standby), LPDS=1 (low-power regulator) */
    PWR->CR &= ~PWR_CR_PDDS;   /* Stop mode (not Standby) */
    PWR->CR |= PWR_CR_LPDS;    /* Low-power regulator in Stop */

    /* Enter Stop mode */
    __asm volatile ("dsb");
    __asm volatile ("wfi");
    __asm volatile ("isb");

    /* After wakeup: system clock is HSI (16 MHz) — reconfigure PLL */
    SCB_SCR &= ~SCB_SCR_SLEEPDEEP;  /* Clear for future WFI */
    system_clock_config();            /* Restore full clock tree */
}

/* ========================================================================== */
/*  Standby Mode                                                               */
/* ========================================================================== */

/**
 * Enter Standby mode.
 *
 * Deepest sleep: 1.8V domain powered off, SRAM and register contents LOST.
 * Only backup domain (RTC, backup SRAM) and wakeup logic remain powered.
 * Wake-up: WKUP pin rising edge, RTC alarm/wakeup, NRST, IWDG.
 *
 * After wakeup, the system resets — execution starts from Reset_Handler.
 *
 * Best for: Ultra-low-power applications that wake every N minutes/hours.
 */
void enter_standby_mode(void)
{
    /* Clear wakeup flag */
    PWR->CR |= PWR_CR_CWUF;

    /* Set SLEEPDEEP and PDDS (Standby mode) */
    SCB_SCR |= SCB_SCR_SLEEPDEEP;
    PWR->CR |= PWR_CR_PDDS;

    __asm volatile ("dsb");
    __asm volatile ("wfi");

    /* Never reaches here — system resets on wakeup */
}

/* ========================================================================== */
/*  RTC Wakeup Timer                                                           */
/* ========================================================================== */

/**
 * Configure the RTC wakeup timer to generate a periodic wakeup.
 *
 * @param seconds  Wakeup interval in seconds (1 to 65535)
 *
 * The RTC wakeup uses the LSE (32.768 kHz) with a /16 prescaler,
 * giving a 2048 Hz wakeup clock. The timer counts down from the
 * configured value to 0, then generates an interrupt.
 */
void rtc_wakeup_init(uint16_t seconds)
{
    /* Enable PWR and RTC clocks */
    RCC_APB1ENR |= (1U << 28);  /* PWR clock  */
    PWR->CR |= PWR_CR_DBP;      /* Unlock backup domain */

    /* Enable LSE and select as RTC clock source */
    RCC_BDCR |= (1U << 0);      /* LSE on */
    while (!(RCC_BDCR & (1U << 1))) { }  /* Wait for LSE ready */
    RCC_BDCR |= (1U << 8);      /* RTC clock = LSE */
    RCC_BDCR |= (1U << 15);     /* RTC enable */

    /* Unlock RTC write protection */
    RTC->WPR = 0xCA;
    RTC->WPR = 0x53;

    /* Disable wakeup timer before configuring */
    RTC->CR &= ~(1U << 10);     /* WUTE = 0 */
    while (!(RTC->ISR & (1U << 2))) { }  /* Wait for WUTWF */

    /* Wakeup clock = RTCCLK/16 = 32768/16 = 2048 Hz */
    RTC->CR &= ~(7U << 0);      /* WUCKSEL = 000 → RTCCLK/16 */

    /* Set wakeup counter */
    RTC->WUTR = (uint32_t)seconds * 2048 - 1;

    /* Enable wakeup timer and its interrupt */
    RTC->CR |= (1U << 10);      /* WUTE = 1 */
    RTC->CR |= (1U << 14);      /* WUTIE = 1 (interrupt enable) */

    /* Lock RTC write protection */
    RTC->WPR = 0xFF;

    /* Configure EXTI line 22 (RTC wakeup) for rising edge */
    EXTI_IMR  |= (1U << 22);
    EXTI_RTSR |= (1U << 22);
}

/* ========================================================================== */
/*  Power Optimization Techniques                                              */
/* ========================================================================== */

/**
 * Disable unused GPIO ports to save power.
 * Floating inputs consume current — set unused pins as analog.
 */
void optimize_gpio_power(void)
{
    typedef struct {
        volatile uint32_t MODER;
    } GPIO_Simple;

    /* Set all pins of unused ports to analog mode (0xFFFFFFFF) */
    /* This prevents floating inputs from consuming leakage current */
    GPIO_Simple *ports[] = {
        (GPIO_Simple *)0x40020000U,  /* GPIOA */
        (GPIO_Simple *)0x40020400U,  /* GPIOB */
        (GPIO_Simple *)0x40020800U,  /* GPIOC */
        (GPIO_Simple *)0x40020C00U,  /* GPIOD */
    };

    /* Only configure unused pins — skip pins we're actually using */
    (void)ports;
}

/**
 * Reduce clock speed for lower power when full speed isn't needed.
 */
void reduce_clock_speed(void)
{
    /* Switch from PLL (168 MHz) to HSI (16 MHz) */
    /* This reduces dynamic power consumption ~10× */
    /* Implementation depends on clock tree configuration */
}

/* ========================================================================== */
/*  Practical Example: Battery-Powered Sensor Node                             */
/* ========================================================================== */

/* External function stubs */
extern void     sensor_power_on(void);
extern void     sensor_power_off(void);
extern uint16_t sensor_read_temperature(void);
extern void     radio_transmit(const uint8_t *data, uint8_t len);
extern void     radio_power_off(void);

typedef struct {
    uint16_t temperature;
    uint16_t battery_mv;
    uint32_t sequence;
} __attribute__((packed)) sensor_packet_t;

/**
 * Ultra-low-power sensor loop.
 *
 * Duty cycle:
 *   Active: ~50 ms every 60 seconds
 *   Sleep:  ~59.95 seconds in Stop mode
 *   Average current: ~50 µA (vs ~20 mA if always running)
 *   Battery life (CR2032, 220 mAh): ~6 months
 */
void low_power_sensor_loop(void)
{
    static uint32_t seq = 0;
    sensor_packet_t packet;

    /* One-time setup */
    rtc_wakeup_init(60);  /* Wake every 60 seconds */

    while (1) {
        /* --- Active phase (~50 ms) --- */

        sensor_power_on();
        /* delay_ms(10); — sensor startup time */

        packet.temperature = sensor_read_temperature();
        /* packet.battery_mv = adc_read_battery_mv(...); */
        packet.sequence = seq++;

        sensor_power_off();

        radio_transmit((const uint8_t *)&packet, sizeof(packet));
        radio_power_off();

        /* --- Sleep phase (~60 seconds) --- */
        enter_stop_mode();

        /* Execution resumes here after RTC wakeup */
    }
}

/* ========================================================================== */
/*  Main                                                                       */
/* ========================================================================== */

int main(void)
{
    /* system_init(); */

    /* Check reset cause */
    if (PWR->CSR & PWR_CSR_WUF) {
        /* Woke from Standby — handle accordingly */
        PWR->CR |= PWR_CR_CWUF;  /* Clear flag */
    }

    /* Start the low-power sensor loop */
    low_power_sensor_loop();

    while (1) { }
}
