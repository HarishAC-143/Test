# Chapter 15: Low-Power Techniques

Battery-powered and energy-harvesting devices demand careful power management. The difference between a device lasting weeks versus years often comes down to how well the firmware handles low-power modes.

## The Power Budget

Power consumption in a microcontroller comes from:

| Source | Contribution |
|--------|-------------|
| **CPU core** | Largest consumer when active |
| **Peripheral clocks** | Each enabled peripheral draws current |
| **I/O pins** | Driving loads, pull-up/pull-down resistors |
| **Flash access** | Reading instructions from Flash |
| **PLL/oscillators** | Clock generation circuitry |

### Typical Current Draw (STM32L4 Example)

| Mode | Current | Wake-Up Time |
|------|---------|-------------|
| Run @ 80 MHz | ~10 mA | — |
| Run @ 1 MHz | ~100 µA | — |
| Sleep | ~1 mA | < 1 µs |
| Low-Power Sleep | ~100 µA | < 1 µs |
| Stop 1 | ~10 µA | ~5 µs |
| Stop 2 | ~1.5 µA | ~5 µs |
| Standby | ~0.4 µA | ~50 µs |
| Shutdown | ~0.03 µA | Reset |

## Strategy 1: Reduce Clock Speed

The CPU's dynamic power is proportional to frequency × voltage². Running slower saves significant power:

```c
void reduce_clock_speed(void)
{
    /* Switch from PLL (80 MHz) to MSI (1 MHz) */
    RCC->CR |= (1U << 0);          /* Enable MSI */
    while (!(RCC->CR & (1U << 1))) /* Wait for MSI ready */
        ;

    /* Switch system clock to MSI */
    RCC->CFGR &= ~(3U << 0);      /* SW = 00 → MSI */
    while ((RCC->CFGR & (0xC)) != 0x00)
        ;

    /* Disable PLL to save power */
    RCC->CR &= ~(1U << 24);

    /* Update SystemCoreClock variable */
    SystemCoreClock = 1000000;
}
```

## Strategy 2: Disable Unused Peripherals

Every peripheral with an enabled clock draws current, even if not actively used:

```c
void disable_unused_peripherals(void)
{
    /* Disable clocks to peripherals not in use */
    RCC->AHB1ENR &= ~(1U << 1);   /* Disable GPIOB clock */
    RCC->AHB1ENR &= ~(1U << 2);   /* Disable GPIOC clock */
    RCC->APB1ENR &= ~(1U << 0);   /* Disable TIM2 clock */
    RCC->APB2ENR &= ~(1U << 12);  /* Disable SPI1 clock */
}
```

### Enable Peripherals On-Demand

```c
void spi_transceive(uint8_t *tx, uint8_t *rx, uint16_t len)
{
    RCC->APB2ENR |= (1U << 12);   /* Enable SPI1 clock */
    __NOP(); __NOP();               /* Brief delay for clock to stabilize */

    spi_do_transfer(tx, rx, len);

    RCC->APB2ENR &= ~(1U << 12);  /* Disable SPI1 clock */
}
```

## Strategy 3: Configure Unused GPIO Pins

Floating input pins can oscillate and waste power. Configure all unused pins as analog inputs or outputs driven low:

```c
void configure_unused_pins(void)
{
    /* Set all pins of GPIOB as analog (lowest power state) */
    GPIOB->MODER = 0xFFFFFFFF;  /* All pins analog mode */
    GPIOB->PUPDR = 0x00000000;  /* No pull-up/pull-down */
}
```

## Strategy 4: Sleep Modes

### Sleep Mode (WFI)

The CPU clock stops, but all peripherals continue running. The CPU wakes on any interrupt:

```c
void enter_sleep_mode(void)
{
    /* Clear SLEEPDEEP bit */
    SCB->SCR &= ~(1U << 2);

    __WFI();  /* Wait For Interrupt — CPU sleeps here */

    /* Execution resumes here after any interrupt */
}
```

### Stop Mode (Deep Sleep)

Most clocks stop. Only LSI/LSE and specific peripherals remain active. Much lower power than Sleep:

```c
void enter_stop_mode(void)
{
    /* Select Stop mode */
    PWR->CR |= (1U << 1);    /* PDDS = 0 (Stop, not Standby) */
    PWR->CR |= (1U << 0);    /* LPDS = 1 (Low-power regulator) */

    /* Set SLEEPDEEP bit */
    SCB->SCR |= (1U << 2);

    __WFI();  /* Enter Stop mode */

    /* After wake-up: reconfigure clocks (HSI/PLL are off) */
    SCB->SCR &= ~(1U << 2);  /* Clear SLEEPDEEP */
    restore_system_clocks();
}
```

### Standby Mode

Nearly everything is off. RAM contents are lost. Wake-up sources: WKUP pin, RTC alarm, or reset:

```c
void enter_standby_mode(void)
{
    /* Enable wake-up pin */
    PWR->CSR |= (1U << 8);   /* EWUP */

    /* Select Standby mode */
    PWR->CR |= (1U << 1);    /* PDDS = 1 */

    /* Set SLEEPDEEP */
    SCB->SCR |= (1U << 2);

    __WFI();  /* Enter Standby — RAM lost, wakes to Reset_Handler */
}
```

## Strategy 5: Event-Driven Architecture

Instead of polling, sleep between events:

```c
/* BAD: Polling wastes power */
while (1) {
    if (button_pressed())
        handle_button();
    if (uart_data_available())
        handle_uart();
    if (timer_expired())
        handle_timer();
}

/* GOOD: Sleep between events */
while (1) {
    __WFI();  /* Sleep until an interrupt occurs */

    if (button_flag) {
        handle_button();
        button_flag = 0;
    }
    if (uart_flag) {
        handle_uart();
        uart_flag = 0;
    }
}
```

## Strategy 6: RTC Wake-Up for Periodic Tasks

Use the Real-Time Clock to wake from Stop/Standby mode at intervals:

```c
void rtc_wakeup_init(uint16_t seconds)
{
    RCC->APB1ENR |= (1U << 28);   /* Enable PWR clock */
    PWR->CR |= (1U << 8);          /* Disable backup domain protection */

    RCC->BDCR |= (1U << 0);       /* Enable LSE (32.768 kHz crystal) */
    while (!(RCC->BDCR & (1U << 1)))
        ;

    RCC->BDCR |= (1U << 8);       /* Select LSE as RTC clock */
    RCC->BDCR |= (1U << 15);      /* Enable RTC */

    RTC->WPR = 0xCA;              /* Unlock RTC write protection */
    RTC->WPR = 0x53;

    RTC->CR &= ~(1U << 10);       /* Disable wake-up timer */
    while (!(RTC->ISR & (1U << 2)))
        ;

    RTC->WUTR = seconds - 1;      /* Wake-up period */
    RTC->CR |= (3U << 0);         /* Clock = 1 Hz (ck_spre) */
    RTC->CR |= (1U << 14);        /* Enable wake-up interrupt */
    RTC->CR |= (1U << 10);        /* Enable wake-up timer */

    EXTI->IMR |= (1U << 20);      /* EXTI line 20 = RTC wake-up */
    EXTI->RTSR |= (1U << 20);     /* Rising edge trigger */

    NVIC_EnableIRQ(RTC_WKUP_IRQn);
}

void low_power_periodic_task(void)
{
    rtc_wakeup_init(60);  /* Wake every 60 seconds */

    while (1) {
        read_and_transmit_sensor_data();
        enter_stop_mode();  /* Sleep until RTC wakes us */
    }
}
```

## Measuring Power Consumption

### Software Estimation

```c
typedef struct {
    uint32_t active_us;
    uint32_t sleep_us;
    uint32_t active_ua;
    uint32_t sleep_ua;
} PowerProfile;

uint32_t estimate_avg_current_ua(const PowerProfile *p)
{
    uint32_t total_us = p->active_us + p->sleep_us;
    uint64_t charge = (uint64_t)p->active_us * p->active_ua +
                      (uint64_t)p->sleep_us * p->sleep_ua;
    return (uint32_t)(charge / total_us);
}

uint32_t estimate_battery_life_hours(uint32_t capacity_mah, uint32_t avg_current_ua)
{
    return (capacity_mah * 1000UL) / avg_current_ua;
}
```

### Hardware Measurement

Use a current-sense amplifier or a dedicated tool like the Nordic Power Profiler to measure real consumption. Software estimates are helpful but actual measurements are essential for validation.

## Summary

- Reduce clock speed when full performance is not needed.
- Disable clocks to unused peripherals.
- Configure unused GPIO pins as analog inputs.
- Use sleep modes aggressively — sleep between events.
- Use RTC wake-up for periodic tasks in Stop/Standby mode.
- Measure actual power consumption to validate your estimates.

---

**Next:** [Chapter 16 — Debugging and Best Practices](16-debugging-and-best-practices.md)
