# Chapter 2: Intermediate Embedded C

## 2.1 Interrupts

Interrupts are the backbone of responsive embedded systems. Instead of constantly polling for events, the hardware notifies your code when something happens.

### How Interrupts Work

```
Normal code executing
        │
        ▼
  ┌─ Hardware event occurs (button press, timer overflow, data received)
  │
  ├─ CPU saves context (registers, program counter) onto the stack
  │
  ├─ CPU looks up the ISR address in the vector table
  │
  ├─ ISR executes (keep it SHORT!)
  │
  ├─ CPU restores context from the stack
  │
  └─ Normal code resumes exactly where it left off
```

### Writing an ISR

```c
// Shared variable — MUST be volatile because the ISR modifies it
volatile uint32_t button_press_count = 0;

// ISR for EXTI line 0 (e.g., button on PA0)
void EXTI0_IRQHandler(void) {
    if (EXTI->PR & (1 << 0)) {     // Check pending bit
        EXTI->PR |= (1 << 0);      // Clear pending bit (write-1-to-clear)
        button_press_count++;
    }
}
```

### ISR Best Practices

1. **Keep ISRs short**: Set a flag and return. Do heavy processing in `main()`.
2. **Use `volatile`**: Any variable shared between an ISR and main code must be `volatile`.
3. **No blocking calls**: Never use `delay()`, `printf()`, or `malloc()` inside an ISR.
4. **Clear interrupt flags**: Always clear the pending/status flag, or the ISR fires forever.
5. **Understand priority**: Higher-priority interrupts can preempt lower-priority ones (nested interrupts).

### Interrupt Configuration (ARM Cortex-M NVIC)

```c
void configure_button_interrupt(void) {
    // 1. Enable GPIOA clock and SYSCFG clock
    RCC->AHB1ENR |= (1 << 0);
    RCC->APB2ENR |= (1 << 14);

    // 2. Configure PA0 as input with pull-up
    GPIOA->MODER &= ~(3 << 0);
    GPIOA->PUPDR |= (1 << 0);

    // 3. Connect EXTI line 0 to PA0
    SYSCFG->EXTICR[0] &= ~(0xF << 0);

    // 4. Configure EXTI: falling edge trigger
    EXTI->FTSR |= (1 << 0);   // Falling edge
    EXTI->IMR  |= (1 << 0);   // Unmask interrupt

    // 5. Enable in NVIC with priority 2
    NVIC_SetPriority(EXTI0_IRQn, 2);
    NVIC_EnableIRQ(EXTI0_IRQn);
}
```

### Critical Sections

When main code and an ISR share data wider than the CPU's atomic access width, you must protect the access:

```c
volatile uint32_t shared_counter = 0;

void safe_read_counter(uint32_t *out) {
    __disable_irq();            // Disable all interrupts
    *out = shared_counter;
    __enable_irq();             // Re-enable interrupts
}

// A more sophisticated approach: save and restore interrupt state
uint32_t read_counter_safe(void) {
    uint32_t primask = __get_PRIMASK();
    __disable_irq();
    uint32_t val = shared_counter;
    __set_PRIMASK(primask);     // Restore previous interrupt state
    return val;
}
```

## 2.2 Timers and Counters

Timers are versatile peripherals used for delays, PWM generation, input capture, and periodic task scheduling.

### Timer Basics

A timer is essentially a counter that increments (or decrements) at a known frequency derived from the system clock:

```
System Clock (e.g., 72 MHz)
        │
        ▼
   ┌─────────┐
   │Prescaler│  ÷ PSC → Timer clock = SystemClock / (PSC + 1)
   └────┬────┘
        │
        ▼
   ┌─────────┐
   │ Counter  │  Counts from 0 to ARR, then overflows
   └────┬────┘
        │
        ▼
   Overflow → generates update event / interrupt
```

**Timer frequency formula**:

```
Timer_Freq = SystemClock / ((PSC + 1) × (ARR + 1))
```

### Configuring a Periodic Timer

```c
void timer2_init_1ms(void) {
    // Enable TIM2 clock
    RCC->APB1ENR |= (1 << 0);

    // Prescaler: 72 MHz / 72 = 1 MHz (1 µs per tick)
    TIM2->PSC = 72 - 1;

    // Auto-reload: count to 1000 → 1 ms period
    TIM2->ARR = 1000 - 1;

    // Enable update interrupt
    TIM2->DIER |= (1 << 0);

    // Start the timer
    TIM2->CR1 |= (1 << 0);

    // Enable TIM2 interrupt in NVIC
    NVIC_EnableIRQ(TIM2_IRQn);
}

volatile uint32_t milliseconds = 0;

void TIM2_IRQHandler(void) {
    if (TIM2->SR & (1 << 0)) {
        TIM2->SR &= ~(1 << 0);  // Clear update interrupt flag
        milliseconds++;
    }
}
```

### PWM (Pulse Width Modulation)

PWM controls LED brightness, motor speed, and servo position:

```c
void pwm_init(void) {
    // TIM3 Channel 1 on PA6
    RCC->APB1ENR |= (1 << 1);    // Enable TIM3 clock
    RCC->AHB1ENR |= (1 << 0);    // Enable GPIOA clock

    // PA6 as alternate function
    GPIOA->MODER |= (2 << 12);   // AF mode
    GPIOA->AFR[0] |= (2 << 24);  // AF2 = TIM3

    TIM3->PSC = 72 - 1;          // 1 MHz timer clock
    TIM3->ARR = 1000 - 1;        // 1 kHz PWM frequency

    // Channel 1: PWM mode 1 (active while CNT < CCR1)
    TIM3->CCMR1 |= (6 << 4);    // OC1M = 110 (PWM mode 1)
    TIM3->CCMR1 |= (1 << 3);    // OC1PE: preload enable
    TIM3->CCER  |= (1 << 0);    // CC1E: enable output

    TIM3->CR1 |= (1 << 0);      // Start timer
}

void pwm_set_duty(uint16_t duty_permille) {
    // duty_permille: 0–1000 maps to 0–100% duty cycle
    TIM3->CCR1 = duty_permille;
}
```

### Input Capture

Measure the frequency or pulse width of an external signal:

```c
volatile uint32_t captured_period = 0;

void input_capture_init(void) {
    // TIM4 Channel 1 on PB6
    TIM4->PSC = 72 - 1;          // 1 µs resolution
    TIM4->CCMR1 |= (1 << 0);    // CC1S = 01: IC1 mapped to TI1
    TIM4->CCER  |= (1 << 0);    // CC1E: enable capture
    TIM4->DIER  |= (1 << 1);    // CC1IE: capture interrupt
    TIM4->CR1   |= (1 << 0);    // Start timer
    NVIC_EnableIRQ(TIM4_IRQn);
}

void TIM4_IRQHandler(void) {
    static uint32_t last_capture = 0;

    if (TIM4->SR & (1 << 1)) {
        TIM4->SR &= ~(1 << 1);
        uint32_t current = TIM4->CCR1;
        captured_period = current - last_capture;
        last_capture = current;
    }
}
```

## 2.3 UART (Serial Communication)

UART is the most common communication interface for debugging and inter-device communication.

### UART Frame Format

```
    ┌─────┬──┬──┬──┬──┬──┬──┬──┬──┬──────┬────┐
    │Start│D0│D1│D2│D3│D4│D5│D6│D7│Parity│Stop│
    │ bit │  │  │  │  │  │  │  │  │(opt) │bit │
    └─────┴──┴──┴──┴──┴──┴──┴──┴──┴──────┴────┘
    │◄──────── 8-N-1: 8 data, no parity, 1 stop ───────►│
```

### UART Configuration

```c
void uart2_init(uint32_t baudrate) {
    // Enable clocks
    RCC->APB1ENR |= (1 << 17);   // USART2
    RCC->AHB1ENR |= (1 << 0);    // GPIOA

    // PA2 = TX, PA3 = RX — alternate function 7
    GPIOA->MODER |= (2 << 4) | (2 << 6);
    GPIOA->AFR[0] |= (7 << 8) | (7 << 12);

    // Baud rate: BRR = f_clk / baudrate
    // For 36 MHz APB1 clock and 115200 baud:
    USART2->BRR = 36000000 / baudrate;

    // Enable TX, RX, and USART
    USART2->CR1 = (1 << 3)   // TE: transmitter enable
                | (1 << 2)   // RE: receiver enable
                | (1 << 13); // UE: USART enable
}
```

### Sending and Receiving Data

```c
void uart_send_byte(uint8_t data) {
    while (!(USART2->SR & (1 << 7)));  // Wait until TXE (TX empty)
    USART2->DR = data;
}

void uart_send_string(const char *str) {
    while (*str) {
        uart_send_byte(*str++);
    }
}

uint8_t uart_receive_byte(void) {
    while (!(USART2->SR & (1 << 5)));  // Wait until RXNE (RX not empty)
    return (uint8_t)USART2->DR;
}

// Interrupt-driven receive
volatile uint8_t rx_buffer[64];
volatile uint8_t rx_head = 0;

void USART2_IRQHandler(void) {
    if (USART2->SR & (1 << 5)) {
        rx_buffer[rx_head] = (uint8_t)USART2->DR;
        rx_head = (rx_head + 1) % sizeof(rx_buffer);
    }
}
```

### Redirecting `printf` (Retargeting)

```c
#include <stdio.h>

// Override the low-level write function used by printf
int _write(int fd, char *ptr, int len) {
    for (int i = 0; i < len; i++) {
        uart_send_byte(ptr[i]);
    }
    return len;
}

// Now printf goes to UART
printf("Sensor value: %d\r\n", adc_value);
```

## 2.4 ADC (Analog-to-Digital Converter)

The ADC converts continuous analog voltages into discrete digital values.

### ADC Concepts

```
Analog Input (0V – 3.3V)
        │
        ▼
   ┌─────────────┐
   │   Sample &   │
   │    Hold      │
   └──────┬──────┘
          │
          ▼
   ┌─────────────┐
   │ Quantizer    │ → 12-bit resolution: 0–4095
   │ (SAR ADC)    │    Step size = 3.3V / 4096 ≈ 0.806 mV
   └──────┬──────┘
          │
          ▼
   Digital Value (uint16_t)
```

### ADC Configuration and Reading

```c
void adc1_init(void) {
    // Enable ADC1 and GPIOA clocks
    RCC->APB2ENR |= (1 << 8);
    RCC->AHB1ENR |= (1 << 0);

    // PA0 as analog input
    GPIOA->MODER |= (3 << 0);   // Analog mode

    // ADC configuration
    ADC1->CR1 = 0;               // 12-bit resolution, no scan
    ADC1->CR2 = 0;
    ADC1->SQR3 = 0;              // Channel 0 as first conversion
    ADC1->SMPR2 |= (7 << 0);    // 480 cycles sample time

    // Enable ADC
    ADC1->CR2 |= (1 << 0);      // ADON
}

uint16_t adc_read(void) {
    ADC1->CR2 |= (1 << 30);     // Start conversion (SWSTART)
    while (!(ADC1->SR & (1 << 1)));  // Wait for EOC
    return (uint16_t)ADC1->DR;
}

float adc_to_voltage(uint16_t raw) {
    return (raw / 4095.0f) * 3.3f;
}

// Reading a temperature sensor (e.g., LM35: 10 mV/°C)
float read_temperature(void) {
    uint16_t raw = adc_read();
    float voltage = adc_to_voltage(raw);
    return voltage / 0.01f;      // Convert mV to °C
}
```

### Multi-Channel ADC with DMA

```c
#define NUM_CHANNELS 4
volatile uint16_t adc_values[NUM_CHANNELS];

void adc_dma_init(void) {
    // Configure ADC for scan mode, continuous conversion
    ADC1->CR1 |= (1 << 8);    // SCAN mode
    ADC1->CR2 |= (1 << 1)     // Continuous conversion
              |  (1 << 8)     // DMA enable
              |  (1 << 9);    // DDS: DMA requests as long as data is converted

    // Sequence: channels 0, 1, 2, 3
    ADC1->SQR3 = (0 << 0) | (1 << 5) | (2 << 10) | (3 << 15);
    ADC1->SQR1 = ((NUM_CHANNELS - 1) << 20);  // Sequence length

    // Configure DMA (see DMA chapter for details)
    // ...

    ADC1->CR2 |= (1 << 30);   // Start conversion
}
```

## 2.5 Watchdog Timer

The watchdog timer is a safety mechanism that resets the MCU if the software hangs or enters an infinite loop.

### Independent Watchdog (IWDG)

```c
void iwdg_init(uint32_t timeout_ms) {
    IWDG->KR = 0x5555;           // Unlock write access
    IWDG->PR = 4;                // Prescaler = /64
    // LSI clock ≈ 40 kHz → 40000/64 = 625 Hz
    IWDG->RLR = (625 * timeout_ms) / 1000;
    IWDG->KR = 0xCCCC;           // Start watchdog
}

void iwdg_refresh(void) {
    IWDG->KR = 0xAAAA;           // Feed the dog!
}

int main(void) {
    system_init();
    iwdg_init(1000);  // 1-second timeout

    while (1) {
        do_work();
        iwdg_refresh();  // Must call within 1 second or MCU resets
    }
}
```

### Window Watchdog (WWDG)

The window watchdog adds a minimum time constraint — you must refresh it within a specific window, not too early and not too late:

```c
// Refresh is valid only when the counter is between
// the window value and 0x3F (just before timeout)
void wwdg_init(void) {
    RCC->APB1ENR |= (1 << 11);

    WWDG->CFR = (3 << 7)    // Prescaler /8
              | (80);       // Window value

    WWDG->CR = (1 << 7)     // WDGA: activate
             | (127);       // Initial counter value (7-bit, max 127)
}
```

## Summary

| Topic | Key Concepts |
|-------|-------------|
| Interrupts | ISRs must be short; use `volatile` for shared vars; clear flags |
| Timers | Prescaler + auto-reload determine frequency; support PWM and capture |
| UART | Fundamental serial interface; 8-N-1 is the default format |
| ADC | Converts analog to digital; 12-bit = 4096 steps; sample time matters |
| Watchdog | Safety net that resets the MCU on software hang |

**Next**: [Chapter 3 — Advanced Topics](03_advanced.md)
