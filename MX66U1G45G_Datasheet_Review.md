# MX66U1G45G Datasheet Review

## 1. Device Overview

The **MX66U1G45G** is a **1 Gigabit (1Gb) Serial NOR Flash** memory manufactured by **Macronix International Co., Ltd.** It operates at **1.8V** and communicates over an SPI-compatible serial interface with multi-I/O capabilities (Single, Dual, Quad). It is designed for embedded systems, IoT, networking, and consumer electronics where high-density code/data storage with fast random-access reads is required.

| Parameter | Value |
|---|---|
| Manufacturer | Macronix (MXIC) |
| Part Number | MX66U1G45G |
| Memory Type | Serial NOR Flash |
| Density | 1 Gigabit (128 MB) |
| Supply Voltage (VCC) | 1.65V -- 2.0V |
| Package | 24-ball BGA (5x5 ball array) |
| Operating Temperature | -40 C to +85 C (Industrial) |

### Why NOR Flash (not NAND)?

NOR flash supports true **random-access reads** at the byte/word level, making it ideal for **execute-in-place (XiP)** applications where a processor fetches and runs code directly from the flash. In contrast, NAND flash requires page-level reads and cannot support XiP without additional logic. The MX66U1G45G targets use cases where the code image lives in flash and the processor boots or runs directly from it.

---

## 2. Memory Organization and Address Space

### 2.1 Internal Organization

The device stores **134,217,728 bytes** (128 MB = 1 Gb) organized as **134,217,728 x 8 bits**.

### 2.2 Address Mode

The MX66U1G45G has **4-byte address mode permanently enabled**. This is necessary because a 3-byte address can only reach 16 MB (2^24 = 16,777,216 bytes), which is far smaller than the 128 MB capacity. With 4-byte (32-bit) addressing, the full 128 MB address space (0x00000000 -- 0x07FFFFFF) is directly accessible.

### 2.3 Erase Hierarchy

NOR flash must be **erased before it can be reprogrammed**. Erase sets all bits to `1`; programming selectively drives bits to `0`. The erase granularity options are:

| Erase Unit | Size | Count in Device | Use Case |
|---|---|---|---|
| Sector | 4 KB | 32,768 sectors | Fine-grained updates (e.g., configuration data) |
| 32KB Block | 32 KB | 4,096 blocks | Medium-granularity updates |
| 64KB Block | 64 KB | 2,048 blocks | Bulk firmware update regions |
| Chip | 128 MB (whole device) | 1 | Factory reset / full re-image |

Choosing the right erase granularity matters because:
- Smaller erase units reduce **write amplification** (less data must be rewritten when only a small region changes).
- Larger erase units are **faster per byte** for bulk operations.

### 2.4 Page Buffer (Programming Unit)

Programming is done through a **256-byte page buffer**. Each Page Program (PP) operation writes up to 256 bytes at a time. If you need to write more than 256 bytes, you issue multiple PP commands.

---

## 3. Pin Descriptions

The device comes in a **24-ball BGA** package with a 5x5 ball array. The key functional pins are:

| Pin Name | Direction | Function |
|---|---|---|
| **CS#** | Input | Chip Select (active low). Drives the SPI transaction framing. All commands begin when CS# goes low and end when CS# goes high. |
| **SCLK** | Input | Serial Clock. The master (host controller/FPGA) drives this clock. Data is latched on clock edges. |
| **SI / SIO0** | I/O | Serial Data In (standard SPI mode) or bidirectional data line 0 (Dual/Quad I/O modes). |
| **SO / SIO1** | I/O | Serial Data Out (standard SPI mode) or bidirectional data line 1 (Dual/Quad I/O modes). |
| **WP# / SIO2** | I/O | Write Protect (active low, standard SPI mode) or bidirectional data line 2 (Quad I/O mode). |
| **NC / SIO3** | I/O | No Connect (standard SPI mode) or bidirectional data line 3 (Quad I/O mode). Also serves as HOLD#/RESET# in some configurations. |
| **RESET#** | Input | Hardware Reset (active low). Pulling this pin low resets the device to its power-on state. |
| **VCC** | Power | Supply voltage (1.65V -- 2.0V). |
| **VSS** | Power | Ground. |

### Understanding the Multi-I/O Pin Modes

In **standard SPI mode**, data travels one bit per clock on SI (in) and SO (out) -- this is the slowest but simplest configuration.

In **Dual I/O mode**, both SI and SO become bidirectional, doubling throughput to **2 bits per clock**.

In **Quad I/O mode**, all four data pins (SIO0--SIO3) become bidirectional, giving **4 bits per clock** -- a 4x throughput improvement over standard SPI.

On this device, **Quad I/O mode is permanently enabled**, meaning the pins always function as SIO0--SIO3.

---

## 4. SPI Interface Modes

### 4.1 Standard SPI

Classic SPI with separate MOSI (SI) and MISO (SO) lines. One bit is transferred per clock edge. Supported but not the default on this device.

### 4.2 Dual I/O (2x I/O)

Uses SI and SO as bidirectional lines. Two bits are transferred per clock. Used by the `2READ` and `DREAD` commands.

### 4.3 Quad I/O (4x I/O / QPI)

Uses all four data pins (SIO0--SIO3). Four bits are transferred per clock. This is the **default and permanently enabled mode** on the MX66U1G45G. Used by the `4READ`, `QREAD`, and `4PP` commands.

### 4.4 DTR (Double Transfer Rate) Mode

In DTR mode, data is transferred on **both** the rising and falling edges of SCLK, effectively doubling throughput again beyond Quad I/O. Combined with Quad I/O, DTR delivers **8 bits per clock cycle** (4 data lines x 2 edges).

### Throughput Comparison at 166 MHz Clock

| Mode | Bits/Clock | Effective Data Rate |
|---|---|---|
| Standard SPI (STR) | 1 | 166 Mbps (20.75 MB/s) |
| Dual I/O (STR) | 2 | 332 Mbps (41.5 MB/s) |
| Quad I/O (STR) | 4 | 664 Mbps (83 MB/s) |
| Quad I/O (DTR) | 8 | 1,328 Mbps (166 MB/s) |

---

## 5. Command Set

Every interaction with the flash begins with the host pulling CS# low, sending a **command opcode** (1 byte), followed by address bytes, dummy cycles, and/or data bytes, and then driving CS# high to complete the transaction.

### 5.1 Read Commands

| Command | Opcode | Address Bytes | Dummy Cycles | Data Lines | Description |
|---|---|---|---|---|---|
| READ | 03h | 4 | 0 | 1 (SO) | Standard read at lower frequency |
| FAST READ | 0Bh | 4 | 8 | 1 (SO) | Fast read with dummy cycles for higher clock |
| DREAD | 3Bh | 4 | 8 | 2 (Dual) | Dual-output fast read |
| 2READ | BBh | 4 | 4 | 2 (Dual I/O) | Dual I/O fast read (address also on 2 lines) |
| QREAD | 6Bh | 4 | 8 | 4 (Quad) | Quad-output fast read |
| 4READ | EBh | 4 | 6 | 4 (Quad I/O) | Quad I/O fast read (address also on 4 lines) |

**Dummy cycles** are clock cycles where no data is transferred. They give the flash's internal circuitry time to fetch data from the memory array. The default is **10 dummy cycles**, but this can vary by command.

### 5.2 Program (Write) Commands

| Command | Opcode | Description |
|---|---|---|
| PP (Page Program) | 02h | Programs up to 256 bytes via single I/O |
| 4PP (Quad Page Program) | 38h | Programs up to 256 bytes via Quad I/O (4x faster data input) |

Programming requires the target region to be **erased first** (all bits set to `1`). PP/4PP can only change bits from `1` to `0`. To change a `0` back to `1`, an erase is required.

### 5.3 Erase Commands

| Command | Opcode | Erase Size | Typical Time |
|---|---|---|---|
| SE (Sector Erase) | 20h / 21h | 4 KB | ~30 ms |
| BE32K (Block Erase 32K) | 52h / 5Ch | 32 KB | ~200 ms |
| BE64K (Block Erase 64K) | D8h / DCh | 64 KB | ~400 ms |
| CE (Chip Erase) | 60h / C7h | Entire chip | ~200--400 s |

### 5.4 Write Enable / Disable

| Command | Opcode | Description |
|---|---|---|
| WREN | 06h | Write Enable -- must be issued before any program/erase operation |
| WRDI | 04h | Write Disable -- clears the Write Enable Latch (WEL) |

The **WREN** command is a critical safety mechanism. Before every program or erase operation, you must first issue WREN to set the Write Enable Latch (WEL) bit in the Status Register. After the operation completes, WEL is automatically cleared.

### 5.5 Status / Register Commands

| Command | Opcode | Description |
|---|---|---|
| RDSR | 05h | Read Status Register |
| RDCR | 15h | Read Configuration Register |
| WRSR | 01h | Write Status Register |
| RDSCUR | 2Bh | Read Security Register |
| WRSCUR | 2Fh | Write Security Register |

### 5.6 Identification Commands

| Command | Opcode | Description |
|---|---|---|
| RDID | 9Fh | Read Manufacturer/Device ID. Returns Macronix ID (C2h) + Memory Type + Density. |
| RES | ABh | Read Electronic Signature |
| REMS | 90h | Read Electronic Manufacturer & Device ID |

### 5.7 Reset Commands

| Command | Opcode | Description |
|---|---|---|
| RSTEN | 66h | Reset Enable |
| RST | 99h | Reset (must be preceded by RSTEN) |

A software reset requires the **two-command sequence** RSTEN followed by RST. This returns the device to its power-on default state without toggling the hardware RESET# pin.

---

## 6. Registers

### 6.1 Status Register (RDSR -- 05h)

The Status Register indicates the device's current state and protection settings.

| Bit | Name | Description |
|---|---|---|
| 7 | SRWD | Status Register Write Disable. When set with WP# low, the Status Register cannot be written. |
| 6 | QE | Quad Enable. Permanently set to `1` on this device (Quad I/O always enabled). |
| 5:2 | BP3:BP0 | Block Protect bits. Define the protected memory region (see block protection table). |
| 1 | WEL | Write Enable Latch. Set by WREN, cleared after program/erase completes. |
| 0 | WIP | Write In Progress. `1` = a program or erase operation is currently executing. |

**WIP polling** is how software knows when an operation has finished. After issuing a program or erase command, the host repeatedly reads the Status Register (RDSR) and checks the WIP bit. When WIP returns to `0`, the operation is complete.

### 6.2 Configuration Register (RDCR -- 15h)

Controls device behavior such as:

| Bit | Name | Description |
|---|---|---|
| 5 | DC1 | Dummy cycle configuration bit 1 |
| 4 | DC0 | Dummy cycle configuration bit 0 |
| 3 | TB | Top/Bottom block protection direction |

The **DC1:DC0** bits control how many dummy cycles are inserted during fast read operations. The default is `10 dummy cycles`. Reducing dummy cycles allows faster effective throughput but requires the clock frequency to stay below certain limits.

### 6.3 Security Register (RDSCUR -- 2Bh)

Tracks security-related states:

| Bit | Name | Description |
|---|---|---|
| 6 | E_FAIL | Erase Fail flag. Set if the last erase operation failed. |
| 5 | P_FAIL | Program Fail flag. Set if the last program operation failed. |
| 1 | LDSO | Lock-Down Secured OTP. Once set, the OTP area is permanently locked. |
| 0 | SOTP | Secured OTP indicator. |

Checking **E_FAIL** and **P_FAIL** after every erase/program operation is essential for robust firmware. These flags indicate whether the flash cell could not be properly programmed or erased (possible sign of wear-out or defect).

---

## 7. Block Protection

The MX66U1G45G supports **software-controlled block protection** via the BP3:BP0 and TB bits in the Status and Configuration Registers. When blocks are protected, program and erase operations to those addresses are rejected.

| BP3 | BP2 | BP1 | BP0 | Protected Region (TB=0, Top) |
|---|---|---|---|---|
| 0 | 0 | 0 | 0 | None (all blocks unprotected) |
| 0 | 0 | 0 | 1 | Upper 1/2048 |
| 0 | 0 | 1 | 0 | Upper 1/1024 |
| 0 | 0 | 1 | 1 | Upper 1/512 |
| ... | ... | ... | ... | Progressively larger protected region |
| 1 | 1 | 1 | 1 | All blocks protected |

The **TB** (Top/Bottom) bit selects whether protection starts from the **top** (highest addresses) or **bottom** (lowest addresses) of the memory space. This allows you to protect a boot region at the bottom of flash while leaving the rest writable, or vice versa.

Additionally, hardware write protection via the **WP#** pin (when in standard SPI mode) and the **SRWD** bit can prevent the Status Register itself from being modified, providing a physical lock.

---

## 8. Secured OTP (One-Time Programmable) Area

The device includes an **8 Kbit (1 KB) Secured OTP** region. This area is:

- **Separate** from the main memory array.
- Accessible through dedicated commands (ENSO / EXSO to enter/exit secured OTP mode).
- **Permanently lockable** via the LDSO bit in the Security Register. Once locked, the OTP data can never be modified.

Typical uses for OTP storage:
- Unique device serial numbers
- Cryptographic keys or certificates
- Factory calibration data
- Anti-counterfeiting identifiers

---

## 9. Timing Parameters

### 9.1 Clock Specifications

| Parameter | Symbol | Min | Max | Unit |
|---|---|---|---|---|
| Clock Frequency | fC | -- | 166 | MHz |
| Clock Low Time | tCHCL | 2.7 | -- | ns |
| Clock High Time | tCLCH | 2.7 | -- | ns |
| CS# Setup Time | tSLCH | 3 | -- | ns |
| CS# Hold Time | tCHSH | 3 | -- | ns |
| CS# High Time | tSHSL | 10 | -- | ns |
| Data Setup Time | tDVCH | 1.5 | -- | ns |
| Data Hold Time | tCHDX | 1.5 | -- | ns |
| Output Valid (CLK Low to Output) | tCLQV | -- | 5.5 | ns |

### 9.2 Program and Erase Timing

| Operation | Typical | Maximum | Unit |
|---|---|---|---|
| Page Program (PP) | 150 | 3,000 | us |
| Sector Erase (4 KB) | 30 | 400 | ms |
| Block Erase (32 KB) | 150 | 2,000 | ms |
| Block Erase (64 KB) | 300 | 4,000 | ms |
| Chip Erase | 200 | 400 | s |

### 9.3 Understanding Timing Constraints in Practice

When designing an SPI controller (e.g., in an FPGA), these timing parameters dictate the constraints you must meet:

- **tCLQV (5.5 ns max):** After the falling edge of SCLK, the flash will present valid data on its output pins within 5.5 ns. Your SPI controller must sample the data after this delay.
- **tDVCH (1.5 ns min):** Data on the input pins must be stable at least 1.5 ns before the rising edge of SCLK.
- **tSLCH / tCHSH (3 ns min):** CS# must be asserted at least 3 ns before the first SCLK edge, and held at least 3 ns after the last SCLK edge.
- **tSHSL (10 ns min):** Between two consecutive SPI transactions, CS# must be high for at least 10 ns.

These values are critical for **SDC (Synopsys Design Constraints)** files when targeting FPGA or ASIC implementations.

---

## 10. Reliability and Endurance

| Parameter | Value |
|---|---|
| Program/Erase Endurance | 100,000 cycles (typical) |
| Data Retention | 20 years |

### What Does 100,000 Cycles Mean?

Each **sector** (or block) can be erased and reprogrammed **100,000 times** before the flash cells begin to degrade. This is per-sector, not per-device. In practice:
- If you erase and reprogram a configuration sector once per day, it will last **~274 years**.
- If you erase and reprogram once per minute, it will last **~69 days**.

For applications with frequent writes, implement **wear leveling** to distribute writes across sectors.

### Data Retention

After being programmed, the flash cells reliably retain their data for **20 years** without power. This assumes the cells have not exceeded their endurance limit.

---

## 11. Wrap-Around Read Mode

The MX66U1G45G supports wrap-around reads with configurable wrap lengths of **8, 16, 32, or 64 bytes**. In wrap mode, when a read reaches the end of the configured wrap boundary, it wraps back to the start of that boundary instead of continuing to the next sequential address.

This is useful for:
- **Cache-line fills** in processors that fetch fixed-size cache lines.
- **Critical-word-first** fetch patterns where the processor needs a specific word quickly, then fills the rest of the cache line with the wrap.

---

## 12. Power Management

### 12.1 Power Supply

| Parameter | Min | Typ | Max | Unit |
|---|---|---|---|---|
| VCC Supply Voltage | 1.65 | 1.8 | 2.0 | V |

The 1.8V nominal supply makes this device suitable for modern low-power designs. For 3.3V systems, use the MX25-series equivalent instead.

### 12.2 Current Consumption

| Mode | Typical | Unit |
|---|---|---|
| Active Read (Serial) | ~15 | mA |
| Active Read (Quad I/O) | ~25 | mA |
| Program | ~15 | mA |
| Erase | ~25 | mA |
| Standby | ~25 | uA |
| Deep Power Down | ~5 | uA |

The **Deep Power Down** mode reduces consumption to micro-amp levels. The device enters this mode via a specific command and exits via CS# assertion or the hardware reset pin.

---

## 13. Typical Usage Flow

Here is the step-by-step sequence for common operations:

### 13.1 Reading Data

```
1. Pull CS# LOW
2. Send 4READ command opcode (EBh)
3. Send 4-byte address on SIO0-SIO3 (Quad I/O)
4. Wait for dummy cycles (6 clocks for 4READ)
5. Read data bytes on SIO0-SIO3 (continuous until CS# HIGH)
6. Pull CS# HIGH
```

### 13.2 Programming (Writing) Data

```
1. Issue WREN command (06h)           -- Enable writes
2. Pull CS# LOW
3. Send 4PP command opcode (38h)      -- Quad Page Program
4. Send 4-byte target address
5. Send up to 256 data bytes on SIO0-SIO3
6. Pull CS# HIGH                      -- Programming begins internally
7. Poll RDSR (05h), check WIP bit     -- Wait for completion
8. Check P_FAIL in Security Register  -- Verify success
```

### 13.3 Erasing a Sector

```
1. Issue WREN command (06h)           -- Enable writes
2. Pull CS# LOW
3. Send SE command opcode (21h)       -- Sector Erase (4-byte addr)
4. Send 4-byte sector address
5. Pull CS# HIGH                      -- Erase begins internally
6. Poll RDSR (05h), check WIP bit     -- Wait for completion (typ 30ms)
7. Check E_FAIL in Security Register  -- Verify success
```

### 13.4 Software Reset

```
1. Issue RSTEN command (66h)          -- Reset Enable
2. Issue RST command (99h)            -- Reset
3. Wait for device reset time         -- Device returns to power-on state
```

---

## 14. Design Considerations

### 14.1 Decoupling

Place a **100 nF ceramic capacitor** as close as possible to the VCC and VSS pins. For high-speed Quad I/O operation at 166 MHz, consider adding a secondary **1 uF capacitor** nearby.

### 14.2 Signal Integrity

At 166 MHz, the SPI signals have rise/fall times that can cause reflections on long traces. Keep trace lengths **under 2 inches** and match lengths across SIO0--SIO3 to minimize skew.

### 14.3 RESET# Pin Handling

The RESET# pin should be tied to VCC through a **pull-up resistor** (10K ohm typical) if hardware reset is not needed. Never leave RESET# floating, as noise could trigger unintended resets.

### 14.4 Write Protection Strategy

For production firmware storage:
1. Program the firmware into flash.
2. Set the BP bits to protect the firmware region.
3. Set the SRWD bit.
4. Physically tie WP# low on the PCB.

This creates a **hardware-enforced read-only** region that cannot be modified without physically changing the WP# signal.

---

## 15. Ordering Information

| Part Number | Package | Temperature Range | Voltage |
|---|---|---|---|
| MX66U1G45GXDI00 | 24-ball BGA | -40 C to +85 C (Industrial) | 1.8V |

The suffix encodes:
- **G** -- 1Gb density
- **XD** -- 24-ball BGA package
- **I** -- Industrial temperature range (-40 C to +85 C)
- **00** -- Standard configuration

---

## 16. Summary

The MX66U1G45G is a high-density, low-voltage serial NOR flash optimized for fast read-out via its permanently-enabled Quad I/O interface. Key takeaways:

1. **1 Gbit capacity** with 4-byte addressing, providing 128 MB of addressable storage.
2. **Quad I/O permanently enabled** for maximum throughput (up to 166 MB/s in DTR mode).
3. **Flexible erase granularity** from 4 KB sectors to full-chip erase.
4. **256-byte page programming** with quad-input variant (4PP) for faster writes.
5. **Robust protection** through block protection bits, hardware write protect, OTP area, and status register write disable.
6. **Industrial temperature range** (-40 C to +85 C) suitable for harsh environments.
7. **100K endurance cycles** and **20-year data retention** for long product lifecycles.

---

*Reference: Macronix MX66U1G45G Datasheet Rev. 1.1/1.2 -- [macronix.com](https://www.macronix.com)*
