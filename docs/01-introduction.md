# Chapter 1: Introduction to Embedded C

## What Is Embedded C?

Embedded C is not a separate language — it is standard C applied to programming **embedded systems**: devices with a microcontroller (MCU) at their core that interact directly with hardware. Think of the controller in your washing machine, the firmware in a drone flight controller, or the code running on an automotive ECU.

The C language is dominant in embedded development because it provides:

- **Direct hardware access** through pointers and memory-mapped I/O
- **Predictable memory usage** with no garbage collector
- **Minimal runtime overhead** — no interpreter, no VM
- **Fine-grained control** over every CPU cycle and byte of RAM

## How Embedded C Differs from Desktop C

| Aspect | Desktop C | Embedded C |
|--------|-----------|------------|
| **Memory** | Gigabytes of RAM | Kilobytes of RAM (sometimes just hundreds of bytes) |
| **Storage** | Hard drive / SSD | Flash memory (KB to low MB) |
| **OS** | Linux, Windows, macOS | Bare-metal or lightweight RTOS |
| **Standard library** | Full `libc` available | Often a subset; `malloc`/`printf` may be unavailable or avoided |
| **I/O** | Files, sockets, terminals | GPIO pins, ADC, UART, SPI, I2C |
| **Execution** | Process started by OS | Code runs from reset vector; `main()` must never return |
| **Timing** | Generally non-critical | Often hard real-time requirements |

## The Embedded C Development Workflow

```
┌────────────┐    ┌──────────┐    ┌────────┐    ┌──────────────┐
│ Write Code │───▶│ Compile  │───▶│  Link  │───▶│ Flash / Load │
│   (.c/.h)  │    │ (cross-  │    │(.elf)  │    │  onto MCU    │
│            │    │ compiler)│    │        │    │              │
└────────────┘    └──────────┘    └────────┘    └──────────────┘
                                                       │
                                                       ▼
                                               ┌──────────────┐
                                               │   Debug via   │
                                               │  JTAG / SWD   │
                                               └──────────────┘
```

### Cross-Compilation

Unlike desktop development where you compile and run on the same machine, embedded code is **cross-compiled**: you compile on a host PC for a different target architecture (e.g., compiling on x86 Linux for an ARM Cortex-M4).

Common toolchains:

| Target | Toolchain |
|--------|-----------|
| ARM Cortex-M | `arm-none-eabi-gcc` |
| AVR (Arduino) | `avr-gcc` |
| RISC-V | `riscv32-unknown-elf-gcc` |
| MSP430 | `msp430-elf-gcc` |

## Anatomy of a Bare-Metal Embedded Program

A typical bare-metal embedded application looks nothing like a desktop "Hello, World." Here is the minimal structure:

```c
#include <stdint.h>

/* Hardware register definitions (memory-mapped) */
#define RCC_AHB1ENR   (*(volatile uint32_t *)0x40023830)
#define GPIOA_MODER   (*(volatile uint32_t *)0x40020000)
#define GPIOA_ODR     (*(volatile uint32_t *)0x40020014)

void SystemInit(void)
{
    /* Called before main — set up clocks, etc. */
}

int main(void)
{
    /* Enable clock to GPIO port A */
    RCC_AHB1ENR |= (1 << 0);

    /* Configure PA5 as output */
    GPIOA_MODER &= ~(3 << 10);
    GPIOA_MODER |=  (1 << 10);

    /* Toggle LED on PA5 forever */
    while (1) {
        GPIOA_ODR ^= (1 << 5);

        /* Simple delay */
        for (volatile int i = 0; i < 100000; i++)
            ;
    }

    /* In embedded systems, main() must NEVER return */
}
```

Key observations:

1. **No `#include <stdio.h>`** — there is no terminal to print to.
2. **Hardware accessed via addresses** — `0x40023830` is a real memory address on an STM32.
3. **Infinite loop** — the program runs forever; there is no OS to return to.
4. **`volatile` everywhere** — the compiler must not optimize away hardware register accesses.

## The Memory Map

Every microcontroller has a **memory map** that defines where Flash, RAM, peripherals, and system registers live in the address space. For example, a simplified ARM Cortex-M memory map:

```
0x00000000 ┌─────────────────────┐
           │   Flash Memory      │  Program code lives here
           │   (Code)            │
0x08000000 ├─────────────────────┤
           │                     │
0x20000000 ├─────────────────────┤
           │   SRAM              │  Variables, stack, heap
           │                     │
0x40000000 ├─────────────────────┤
           │   Peripheral        │  GPIO, UART, SPI, Timers
           │   Registers         │  (memory-mapped I/O)
0xE0000000 ├─────────────────────┤
           │   System / Debug    │  NVIC, SysTick, debug
           │                     │
0xFFFFFFFF └─────────────────────┘
```

Understanding the memory map is essential — it tells you *where* to write values to control hardware.

## The Startup Sequence

When a microcontroller powers on or resets:

1. The processor loads the **initial stack pointer** from address `0x00000000`.
2. It loads the **reset vector** (address of the first instruction) from `0x00000004`.
3. The reset handler runs — typically it:
   - Copies initialized data from Flash to RAM (`.data` section)
   - Zeros the `.bss` section (uninitialized globals)
   - Calls `SystemInit()` (clock configuration)
   - Calls `main()`

This startup code is usually provided by the vendor or written in assembly. Understanding it helps when debugging hard faults or memory corruption.

## Summary

- Embedded C is standard C applied under tight hardware constraints.
- You interact with hardware by reading/writing specific memory addresses.
- Cross-compilation, memory maps, and startup code are fundamental concepts.
- `main()` never returns — your program runs in an infinite loop.

---

**Next:** [Chapter 2 — Data Types and Qualifiers](02-data-types-and-qualifiers.md)
