# Chapter 8: Interrupts and ISRs

Interrupts are the mechanism that allows hardware to get the CPU's attention *immediately*, without the CPU having to continuously poll. They are fundamental to responsive, efficient embedded systems.

## What Is an Interrupt?

An interrupt is a signal (from hardware or software) that causes the processor to:

1. **Suspend** the currently executing code
2. **Save** the processor context (registers, program counter)
3. **Execute** a special function called an **Interrupt Service Routine (ISR)**
4. **Restore** context and **resume** the interrupted code

```
Main code running ──────┐
                        │ IRQ signal arrives
                        ▼
                   Save context
                        │
                        ▼
                   Execute ISR
                        │
                        ▼
                 Restore context
                        │
                        ▼
Main code resumes ──────┘
```

## The NVIC (Nested Vectored Interrupt Controller)

ARM Cortex-M processors use the NVIC to manage interrupts:

- **Up to 240 external interrupts** (peripheral-specific)
- **Configurable priority levels** (lower number = higher priority)
- **Nesting** — a higher-priority interrupt can preempt a lower-priority ISR
- **Tail-chaining** — efficient back-to-back interrupt handling

### Enabling an Interrupt

Three things must be configured:

1. **Peripheral level:** Enable the interrupt source in the peripheral's registers
2. **NVIC level:** Enable the interrupt line in the NVIC
3. **Global level:** Ensure interrupts are globally enabled (they are by default)

```c
/* 1. Configure EXTI for PC13 (button) */
SYSCFG->EXTICR[3] |= (0x2 << 4);  /* Map EXTI13 to Port C */
EXTI->IMR  |= (1U << 13);          /* Unmask EXTI line 13 */
EXTI->FTSR |= (1U << 13);          /* Trigger on falling edge */

/* 2. Enable EXTI15_10 interrupt in NVIC */
NVIC_EnableIRQ(EXTI15_10_IRQn);

/* 3. Set priority (optional — default is 0) */
NVIC_SetPriority(EXTI15_10_IRQn, 2);
```

## Writing an ISR

ISRs are normal C functions with a specific name that matches the vector table entry:

```c
void EXTI15_10_IRQHandler(void)
{
    if (EXTI->PR & (1U << 13)) {  /* Check if EXTI13 triggered */
        /* Handle the button press */
        button_pressed = 1;

        EXTI->PR |= (1U << 13);  /* Clear the pending flag */
    }
}
```

### Critical ISR Rules

1. **Keep ISRs short** — do the minimum work necessary
2. **Clear the interrupt flag** — or the ISR will fire continuously
3. **No blocking calls** — no `delay()`, no `printf()`, no busy-waiting
4. **Use `volatile`** — for any variable shared between ISR and main code
5. **No dynamic memory** — no `malloc()` inside ISRs

### The Flag-and-Process Pattern

The recommended approach: set a flag in the ISR, process in the main loop:

```c
volatile uint8_t uart_rx_flag = 0;
volatile uint8_t uart_rx_data = 0;

void USART1_IRQHandler(void)
{
    if (USART1->SR & (1U << 5)) {  /* RXNE flag */
        uart_rx_data = (uint8_t)USART1->DR;
        uart_rx_flag = 1;
    }
}

int main(void)
{
    uart_init();

    while (1) {
        if (uart_rx_flag) {
            process_byte(uart_rx_data);
            uart_rx_flag = 0;
        }

        do_other_work();
    }
}
```

## Interrupt Priority and Preemption

### Priority Grouping (ARM Cortex-M)

The priority field is split into **preemption priority** and **sub-priority**:

```c
/* Set priority grouping: 4 bits preemption, 0 bits sub-priority */
NVIC_SetPriorityGrouping(0);

/* Set interrupt priorities */
NVIC_SetPriority(TIM2_IRQn,   1);  /* High priority — motor control */
NVIC_SetPriority(USART1_IRQn, 3);  /* Medium priority — serial comm */
NVIC_SetPriority(ADC_IRQn,    5);  /* Lower priority — sensor reading */
```

### Preemption Example

```
Priority 5 ISR running ────┐
                            │ Priority 1 IRQ arrives
                            ▼
                      Priority 5 suspended
                            │
                      Priority 1 ISR runs
                            │
                      Priority 1 ISR returns
                            │
                            ▼
Priority 5 ISR resumes ────┘
```

## Critical Sections

When main code and ISRs share data, you need **critical sections** to prevent race conditions:

### Disabling Interrupts

```c
void critical_section_example(void)
{
    __disable_irq();       /* Disable all interrupts */

    /* Access shared data safely */
    shared_counter++;

    __enable_irq();        /* Re-enable interrupts */
}
```

### Saving and Restoring Interrupt State

Better approach — preserves the previous interrupt state:

```c
void safe_critical_section(void)
{
    uint32_t primask = __get_PRIMASK();
    __disable_irq();

    /* Access shared data */
    shared_counter++;

    __set_PRIMASK(primask);  /* Restore previous state */
}
```

### Macro for Critical Sections

```c
#define ENTER_CRITICAL()  uint32_t _primask = __get_PRIMASK(); __disable_irq()
#define EXIT_CRITICAL()   __set_PRIMASK(_primask)

void some_function(void)
{
    ENTER_CRITICAL();
    shared_buffer[write_idx++] = data;
    EXIT_CRITICAL();
}
```

## Common Interrupt Sources

| Interrupt | Typical Use |
|-----------|-------------|
| EXTI (External) | Button presses, external signals |
| USART RX/TX | Serial data received/transmitted |
| TIM (Timer) | Periodic tasks, PWM, timeouts |
| ADC | Conversion complete |
| DMA | Transfer complete |
| SysTick | System tick (RTOS scheduler, time-keeping) |
| I2C/SPI | Communication events |

## SysTick Timer

The SysTick is a 24-bit timer built into every ARM Cortex-M core. It is commonly used for:

- Maintaining a system tick counter
- Generating periodic interrupts (typically 1 ms)

```c
volatile uint32_t system_ticks = 0;

void SysTick_Handler(void)
{
    system_ticks++;
}

void systick_init(uint32_t ticks_per_second)
{
    SysTick->LOAD = (SystemCoreClock / ticks_per_second) - 1;
    SysTick->VAL  = 0;
    SysTick->CTRL = (1U << 2) |  /* Clock source: processor clock */
                    (1U << 1) |  /* Enable interrupt */
                    (1U << 0);   /* Enable counter */
}

void delay_ms(uint32_t ms)
{
    uint32_t start = system_ticks;
    while ((system_ticks - start) < ms)
        ;
}

/* Initialize for 1 ms tick */
systick_init(1000);
```

## Interrupt-Driven vs. Polling

| Aspect | Polling | Interrupt-Driven |
|--------|---------|-----------------|
| CPU usage | Wastes cycles checking | CPU free until event |
| Latency | Depends on poll rate | Near-immediate |
| Complexity | Simple | More complex (shared state, priorities) |
| Power | Keeps CPU busy | CPU can sleep between interrupts |
| Best for | Simple, fast peripherals | Async events, low-power, real-time |

## Common Pitfalls

### 1. Forgetting to Clear the Interrupt Flag

The ISR fires continuously, starving the main loop:

```c
void TIM2_IRQHandler(void)
{
    /* BUG: forgot to clear the flag! */
    do_something();
    /* FIX: TIM2->SR &= ~(1U << 0); */
}
```

### 2. Doing Too Much Work in the ISR

```c
/* BAD — ISR does heavy processing */
void USART1_IRQHandler(void)
{
    char line[256];
    read_entire_line(line);        /* Blocks! */
    parse_and_process(line);       /* Too slow! */
    send_response_over_network();  /* Way too much! */
}

/* GOOD — ISR does minimal work */
void USART1_IRQHandler(void)
{
    ring_buffer_put(&rx_buf, USART1->DR);
    USART1->SR;  /* Clear flag by reading SR then DR */
}
```

### 3. Non-Atomic Access to Shared Variables

On an 8-bit or 16-bit MCU, a 32-bit variable access is **not atomic**:

```c
volatile uint32_t counter;  /* Modified by ISR */

/* In main — this is a race condition on 8/16-bit MCUs! */
uint32_t snapshot = counter;

/* Safe version: */
__disable_irq();
uint32_t snapshot = counter;
__enable_irq();
```

## Practical Examples

- [`examples/03_interrupts/external_interrupt.c`](../examples/03_interrupts/external_interrupt.c) — Button interrupt with EXTI
- [`examples/03_interrupts/systick_delay.c`](../examples/03_interrupts/systick_delay.c) — SysTick-based millisecond delay

## Summary

- Interrupts allow hardware to notify the CPU asynchronously — no polling needed.
- Keep ISRs short: set a flag, buffer data, then return.
- Use `volatile` for all variables shared between ISRs and main code.
- Use critical sections to protect multi-byte shared data.
- Always clear the interrupt pending flag before returning from the ISR.
- Configure priorities carefully to prevent priority inversion.

---

**Next:** [Chapter 9 — Timers and PWM](09-timers-and-pwm.md)
