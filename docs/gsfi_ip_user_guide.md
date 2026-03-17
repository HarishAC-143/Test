# Generic Serial Flash Interface (GSFI) IP User Guide

## Table of Contents

- [1. Overview](#1-overview)
- [2. Features](#2-features)
- [3. Supported Device Families](#3-supported-device-families)
- [4. Block Diagram](#4-block-diagram)
- [5. Signals](#5-signals)
  - [5.1 Clock and Reset Signals](#51-clock-and-reset-signals)
  - [5.2 Avalon-MM CSR Slave Interface Signals](#52-avalon-mm-csr-slave-interface-signals)
  - [5.3 Avalon-MM Memory Slave Interface Signals](#53-avalon-mm-memory-slave-interface-signals)
  - [5.4 Flash Memory Interface Signals](#54-flash-memory-interface-signals)
- [6. Parameters](#6-parameters)
- [7. Register Map](#7-register-map)
  - [7.1 Control Register (Offset 0x00)](#71-control-register-offset-0x00)
  - [7.2 Status Register (Offset 0x04)](#72-status-register-offset-0x04)
  - [7.3 Flash Device Capacity Register (Offset 0x08)](#73-flash-device-capacity-register-offset-0x08)
  - [7.4 Flash Device ID Register (Offset 0x0C)](#74-flash-device-id-register-offset-0x0c)
  - [7.5 Sector/Block Protection Register (Offset 0x10)](#75-sectorblock-protection-register-offset-0x10)
- [8. I/O Timing Diagrams](#8-io-timing-diagrams)
  - [8.1 Avalon-MM CSR Read Timing](#81-avalon-mm-csr-read-timing)
  - [8.2 Avalon-MM CSR Write Timing](#82-avalon-mm-csr-write-timing)
  - [8.3 Flash Memory Read Timing](#83-flash-memory-read-timing)
  - [8.4 Flash Memory Write (Page Program) Timing](#84-flash-memory-write-page-program-timing)
  - [8.5 Flash Sector Erase Timing](#85-flash-sector-erase-timing)
  - [8.6 SPI Flash Physical Interface Timing](#86-spi-flash-physical-interface-timing)
  - [8.7 QSPI (Quad-SPI) Data Transfer Timing](#87-qspi-quad-spi-data-transfer-timing)
  - [8.8 Flash Memory Bulk Erase Timing](#88-flash-memory-bulk-erase-timing)
- [9. Functional Description](#9-functional-description)
  - [9.1 CSR Byte Enable](#91-csr-byte-enable)
  - [9.2 Memory Operations](#92-memory-operations)
  - [9.3 Byte Enabling for Memory Operations](#93-byte-enabling-for-memory-operations)
- [10. I/O Pin Constraints](#10-io-pin-constraints)
  - [10.1 Active Serial Interface](#101-active-serial-interface)
  - [10.2 Pin Assignment Guidelines](#102-pin-assignment-guidelines)
- [11. Reference Design](#11-reference-design)
- [12. Software Support](#12-software-support)
  - [12.1 Nios II HAL Driver](#121-nios-ii-hal-driver)
  - [12.2 HAL API Functions](#122-hal-api-functions)
- [13. Revision History](#13-revision-history)

---

## 1. Overview

The Generic Serial Flash Interface (GSFI) IP core provides a standardized interface for accessing serial flash memory devices in Intel (formerly Altera) FPGA designs. The IP abstracts the low-level SPI/QSPI protocol details and presents a simple Avalon Memory-Mapped (Avalon-MM) interface that allows FPGA logic and embedded processors (such as the Nios II) to read, write, erase, and manage serial flash memory.

The GSFI IP supports Intel configuration devices (EPCQ, EPCQ-256, EPCQ-A, EPCQ-L) as well as third-party QSPI-compatible flash devices from multiple vendors.

**Key use cases:**

- In-system programming of FPGA configuration data stored in serial flash
- Non-volatile data storage for embedded applications
- Boot-image management in multi-boot FPGA systems
- Remote firmware update via flash memory access

---

## 2. Features

| Feature | Description |
|---------|-------------|
| **Avalon-MM CSR Interface** | 32-bit memory-mapped register access for control and status monitoring |
| **Avalon-MM Memory Interface** | Direct memory-mapped read/write access to flash contents |
| **Multi-device Support** | Supports EPCQ, EPCQ-256, EPCQ-A, EPCQ-L, and third-party QSPI flash |
| **SPI / Quad-SPI Modes** | Standard SPI (x1) and Quad-SPI (x4) data transfer |
| **Sector/Block Erase** | Granular erase operations (4 KB sector, 32 KB/64 KB block, bulk erase) |
| **Write Protection** | Hardware and software sector/block protection |
| **Byte Enable Support** | Selective register and memory byte access |
| **Nios II HAL Driver** | Software driver with HAL API for Nios II embedded systems |
| **Platform Designer Integration** | Plug-and-play integration via Intel Platform Designer (Qsys) |
| **Simulation Models** | Flash simulation models for ModelSim/Questa verification |

---

## 3. Supported Device Families

| Device Family | Support Level |
|---------------|---------------|
| Cyclone V | Full |
| Cyclone 10 LP | Full |
| Cyclone 10 GX | Full |
| Arria V | Full |
| Arria 10 | Full |
| Stratix V | Full |
| Stratix 10 | Full |
| Agilex 7 | Full |
| MAX 10 | Full |

> **Note:** Refer to the Intel Quartus Prime release notes for the most current device family support matrix.

---

## 4. Block Diagram

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                         FPGA Fabric                                    │
 │                                                                        │
 │  ┌──────────────┐         ┌──────────────────────────────────────┐     │
 │  │              │  Avalon  │     Generic Serial Flash Interface  │     │
 │  │   Nios II    │   -MM   │              (GSFI) IP              │     │
 │  │  Processor   ├────────►│                                     │     │
 │  │   or User    │  CSR    │  ┌────────────┐  ┌──────────────┐  │     │
 │  │   Logic      ├────────►│  │  Register  │  │  Flash       │  │     │
 │  │              │  Memory │  │  File &    │  │  Protocol    │  │     │
 │  └──────────────┘         │  │  Control   │  │  Engine      │  │     │
 │                           │  │  Logic     │  │  (SPI/QSPI)  │  │     │
 │  ┌──────────────┐         │  └─────┬──────┘  └──────┬───────┘  │     │
 │  │   Clock &    │         │        │                │          │     │
 │  │   Reset      ├────────►│        └────────┬───────┘          │     │
 │  │   Manager    │         │                 │                  │     │
 │  └──────────────┘         └─────────────────┼──────────────────┘     │
 │                                             │                        │
 └─────────────────────────────────────────────┼────────────────────────┘
                                               │  Flash I/O
                                               │  (nCSO, DCLK,
                                               │   ASDO/DATA[3:0])
                                               ▼
                                    ┌─────────────────────┐
                                    │   Serial Flash      │
                                    │   Memory Device     │
                                    │   (EPCQ / EPCQ-L /  │
                                    │    Third-Party)      │
                                    └─────────────────────┘
```

---

## 5. Signals

### 5.1 Clock and Reset Signals

| Signal Name | Direction | Width | Description |
|-------------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock. All Avalon-MM transactions and internal logic are synchronous to this clock. |
| `reset_n` | Input | 1 | Active-low asynchronous reset. Resets the IP core to its initial state. |

### 5.2 Avalon-MM CSR Slave Interface Signals

The CSR (Control/Status Register) interface provides access to the GSFI control and status registers.

| Signal Name | Direction | Width | Description |
|-------------|-----------|-------|-------------|
| `avl_csr_read` | Input | 1 | CSR read request. Assert to initiate a register read transaction. |
| `avl_csr_write` | Input | 1 | CSR write request. Assert to initiate a register write transaction. |
| `avl_csr_address` | Input | 3 | CSR register address. Selects the target register (word-aligned). |
| `avl_csr_writedata` | Input | 32 | CSR write data bus. Carries data for register write operations. |
| `avl_csr_readdata` | Output | 32 | CSR read data bus. Returns data from register read operations. |
| `avl_csr_byteenable` | Input | 4 | CSR byte enable. Selects which bytes (of the 32-bit word) are active during a read/write. |
| `avl_csr_waitrequest` | Output | 1 | CSR wait request. When asserted, the master must hold all signals and wait before completing the transaction. |

### 5.3 Avalon-MM Memory Slave Interface Signals

The memory interface provides direct read/write access to the flash memory address space.

| Signal Name | Direction | Width | Description |
|-------------|-----------|-------|-------------|
| `avl_mem_read` | Input | 1 | Memory read request. Assert to initiate a flash memory read. |
| `avl_mem_write` | Input | 1 | Memory write request. Assert to initiate a flash memory write (page program). |
| `avl_mem_address` | Input | 32 | Memory address bus. Specifies the byte address in flash memory. |
| `avl_mem_writedata` | Input | 32 | Memory write data bus. Carries data to be programmed into flash. |
| `avl_mem_readdata` | Output | 32 | Memory read data bus. Returns data read from flash memory. |
| `avl_mem_byteenable` | Input | 4 | Memory byte enable. Selects which bytes of the 32-bit word are active. |
| `avl_mem_waitrequest` | Output | 1 | Memory wait request. Asserted while the flash operation is in progress; the master must wait. |
| `avl_mem_burstcount` | Input | 7 | Burst count. Number of words in a burst transfer (1 to 128). |
| `avl_mem_readdatavalid` | Output | 1 | Read data valid. Asserted when `avl_mem_readdata` contains valid read data. |

### 5.4 Flash Memory Interface Signals

These signals connect directly to the external serial flash device pins.

| Signal Name | Direction | Width | Description |
|-------------|-----------|-------|-------------|
| `flash_ncs` (nCSO) | Output | 1 | Flash chip select (active low). Directly drives the flash device chip select pin. |
| `flash_dclk` (DCLK) | Output | 1 | Flash serial clock. Provides the clock for SPI/QSPI transfers. |
| `flash_data_out` (ASDO) | Output | 1 or 4 | Flash data output from FPGA to flash. In standard SPI mode, 1-bit wide (ASDO). In Quad-SPI mode, 4 bits wide (DATA[3:0]). |
| `flash_data_in` (DATA0) | Input | 1 or 4 | Flash data input from flash to FPGA. In standard SPI mode, 1-bit wide (DATA0). In Quad-SPI mode, 4 bits wide (DATA[3:0]). |
| `flash_data_oe` | Output | 1 or 4 | Flash data output enable. Controls data pin direction for bidirectional data lines in QSPI mode. |

---

## 6. Parameters

The GSFI IP core is configured through Platform Designer with the following parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `FLASH_TYPE` | Enum | EPCQ | Selects the target flash device type. Options: EPCQ, EPCQ256, EPCQ-A, EPCQ-L, Custom. |
| `FLASH_DENSITY` | Integer | 16 | Flash device density in Megabits (e.g., 16, 32, 64, 128, 256, 512, 1024). |
| `CHIP_SELECT` | Integer | 1 | Number of chip select signals (1 to 3 for multi-die flash packages). |
| `CHIP_SELECT_ACTIVE_SERIAL` | Boolean | ON | When enabled, connects the chip select to the dedicated Active Serial (AS) interface pins. |
| `ENABLE_4BYTE_ADDRESS` | Boolean | OFF | Enables 4-byte (32-bit) addressing mode for flash densities > 128 Mbit. |
| `ENABLE_QUAD_SPI` | Boolean | ON | Enables Quad-SPI (x4) data mode for higher throughput. |
| `CLOCK_DIVIDER` | Integer | 1 | Divides the system clock to generate the flash DCLK. DCLK = clk / (2 x CLOCK_DIVIDER). |
| `READ_DUMMY_CYCLES` | Integer | 8 | Number of dummy clock cycles inserted between the read command/address and data output. |

---

## 7. Register Map

All registers are 32 bits wide and accessed through the Avalon-MM CSR interface. Registers are word-aligned (4-byte boundaries).

### 7.1 Control Register (Offset 0x00)

Controls flash operations and commands.

| Bits | Field Name | Access | Reset | Description |
|------|------------|--------|-------|-------------|
| [0] | `WRITE_ENABLE` | W1S | 0x0 | Set to issue Write Enable (WREN) command to flash. |
| [1] | `WRITE_DISABLE` | W1S | 0x0 | Set to issue Write Disable (WRDI) command to flash. |
| [2] | `SECTOR_ERASE` | W1S | 0x0 | Set to initiate a sector erase operation at the address in the Address Register. |
| [3] | `BLOCK_ERASE_32K` | W1S | 0x0 | Set to initiate a 32 KB block erase. |
| [4] | `BLOCK_ERASE_64K` | W1S | 0x0 | Set to initiate a 64 KB block erase. |
| [5] | `BULK_ERASE` | W1S | 0x0 | Set to initiate a full chip (bulk) erase. |
| [6] | `READ_STATUS` | W1S | 0x0 | Set to read the flash device status register. |
| [7] | `WRITE_STATUS` | W1S | 0x0 | Set to write the flash device status register. |
| [8] | `READ_SID` | W1S | 0x0 | Set to read the flash Silicon ID / JEDEC ID. |
| [9] | `SECTOR_PROTECT` | W1S | 0x0 | Set to enable sector protection. |
| [10] | `SECTOR_UNPROTECT` | W1S | 0x0 | Set to disable sector protection. |
| [31:11] | Reserved | RO | 0x0 | Reserved. Write as 0, read returns 0. |

> **W1S** = Write-1-to-Set. Writing a 1 triggers the operation. The bit auto-clears when the operation completes.

### 7.2 Status Register (Offset 0x04)

Reports the current status of the IP core and the flash device.

| Bits | Field Name | Access | Reset | Description |
|------|------------|--------|-------|-------------|
| [0] | `BUSY` | RO | 0x0 | IP core is busy processing a command. No new commands should be issued. |
| [1] | `WEL` | RO | 0x0 | Write Enable Latch. Mirrors the flash device WEL status bit. |
| [2] | `WSE` | RO | 0x0 | Write Suspend Erase. Indicates erase operation is suspended. |
| [3] | `WSP` | RO | 0x0 | Write Suspend Program. Indicates program operation is suspended. |
| [4] | `BP0` | RO | 0x0 | Block Protect bit 0 (from flash status register). |
| [5] | `BP1` | RO | 0x0 | Block Protect bit 1 (from flash status register). |
| [6] | `BP2` | RO | 0x0 | Block Protect bit 2 (from flash status register). |
| [7] | `BP3` | RO | 0x0 | Block Protect bit 3 (from flash status register). |
| [11:8] | `ERASE_FAIL` | RO | 0x0 | Erase failure indicators (device-specific). |
| [15:12] | `PROG_FAIL` | RO | 0x0 | Program failure indicators (device-specific). |
| [31:16] | Reserved | RO | 0x0 | Reserved. |

### 7.3 Flash Device Capacity Register (Offset 0x08)

| Bits | Field Name | Access | Reset | Description |
|------|------------|--------|-------|-------------|
| [31:0] | `CAPACITY` | RO | Varies | Flash device capacity in bytes. Populated after device identification. |

### 7.4 Flash Device ID Register (Offset 0x0C)

| Bits | Field Name | Access | Reset | Description |
|------|------------|--------|-------|-------------|
| [7:0] | `DEVICE_ID` | RO | 0x00 | Flash device ID byte. |
| [15:8] | `MEMORY_TYPE` | RO | 0x00 | Flash memory type code. |
| [23:16] | `MANUFACTURER_ID` | RO | 0x00 | Manufacturer JEDEC ID. |
| [31:24] | Reserved | RO | 0x00 | Reserved. |

### 7.5 Sector/Block Protection Register (Offset 0x10)

| Bits | Field Name | Access | Reset | Description |
|------|------------|--------|-------|-------------|
| [31:0] | `PROTECTION_BITS` | R/W | 0x0 | Each bit corresponds to a sector or block. 1 = protected, 0 = unprotected. Mapping is device-dependent. |

---

## 8. I/O Timing Diagrams

This section presents the timing behavior of the GSFI IP core interfaces. All diagrams show signal transitions relative to the rising edge of `clk`.

### 8.1 Avalon-MM CSR Read Timing

A register read through the CSR interface completes in a single clock cycle when `avl_csr_waitrequest` is deasserted, or stalls until the wait request clears.

```
                    ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐
  clk           ───┘     └─────┘     └─────┘     └─────┘     └─────┘     └─────┘     └───
                     T0         T1         T2         T3         T4         T5

                         ┌───────────────────────────────────────┐
  avl_csr_read  ─────────┘                                       └───────────────────────
                         ▲ Master asserts read                   ▲ Master deasserts

                         ┌───────────────────────────────────────┐
  avl_csr_address ───────┤          Register Address             ├───────────────────────
                         └───────────────────────────────────────┘

                         ┌───────────────────────────────────────┐
  avl_csr_byteenable ────┤             4'b1111                   ├───────────────────────
                         └───────────────────────────────────────┘

                         ┌─────────────────────┐
  avl_csr_waitrequest ───┘                     └─────────────────────────────────────────
                         ▲ IP needs time       ▲ Data ready (T2)

                                               ┌───────────────────────────────────────┐
  avl_csr_readdata ────────────────────────────┤          Valid Read Data              ├──
                                               └───────────────────────────────────────┘
                                               ▲ Data valid when waitrequest falls

  Timeline:
    T0: Master drives avl_csr_read, address, and byteenable
    T0: IP asserts avl_csr_waitrequest (register lookup in progress)
    T2: IP deasserts avl_csr_waitrequest; avl_csr_readdata is valid
    T3: Master samples readdata and deasserts avl_csr_read
```

### 8.2 Avalon-MM CSR Write Timing

A register write through the CSR interface. The master holds data stable until `avl_csr_waitrequest` deasserts.

```
                    ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐     ┌─────┐
  clk           ───┘     └─────┘     └─────┘     └─────┘     └─────┘     └─────┘     └───
                     T0         T1         T2         T3         T4         T5

                         ┌─────────────────────────────┐
  avl_csr_write ─────────┘                             └─────────────────────────────────
                         ▲ Master asserts write        ▲ Deasserts after accept

                         ┌─────────────────────────────┐
  avl_csr_address ───────┤       Register Address      ├─────────────────────────────────
                         └─────────────────────────────┘

                         ┌─────────────────────────────┐
  avl_csr_writedata ─────┤       Write Data Value      ├─────────────────────────────────
                         └─────────────────────────────┘

                         ┌─────────────────────────────┐
  avl_csr_byteenable ────┤          4'b1111            ├─────────────────────────────────
                         └─────────────────────────────┘

                         ┌───────────┐
  avl_csr_waitrequest ───┘           └───────────────────────────────────────────────────
                         ▲ IP busy   ▲ Write accepted (T1)

  Timeline:
    T0: Master asserts avl_csr_write with address, writedata, byteenable
    T0: IP asserts avl_csr_waitrequest
    T1: IP deasserts avl_csr_waitrequest — write is accepted
    T2: Master deasserts avl_csr_write
```

### 8.3 Flash Memory Read Timing

A burst read from the flash memory through the Avalon-MM memory interface. The IP translates the Avalon-MM read into SPI/QSPI flash read commands internally.

```
                    ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
  clk           ───┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
                   T0    T1    T2    T3    T4    T5    T6    T7    T8    T9    T10   T11

                       ┌───────────────────────────────────────────────────────────────┐
  avl_mem_read  ───────┘                                                               └────
                       ▲ Master asserts read

                       ┌───────────────────────────────────────────────────────────────┐
  avl_mem_address ─────┤                    Flash Byte Address                         ├────
                       └───────────────────────────────────────────────────────────────┘

                       ┌───────────────────────────────────────────────────────────────┐
  avl_mem_burstcount ──┤                     N (burst length)                          ├────
                       └───────────────────────────────────────────────────────────────┘

                       ┌──────────────────────────────────────────┐
  avl_mem_waitrequest──┘                                          └──────────────────────────
                       ▲ IP sends command+address to flash        ▲ Accepted (T6)
                                                                             ┌──┐  ┌──┐
  avl_mem_readdatavalid ─────────────────────────────────────────────────────┘  └──┘  └──
                                                                             ▲D0    ▲D1
                                                                             ┌──────┐
  avl_mem_readdata ──────────────────────────────────────────────────────────┤  D0  ├─...
                                                                             └──────┘
  Timeline:
    T0:     Master asserts avl_mem_read with address and burstcount = N
    T0-T5:  IP asserts waitrequest; internally sends SPI read command + address to flash
    T6:     IP deasserts waitrequest (command accepted)
    T8:     First read data word (D0) valid, avl_mem_readdatavalid asserted
    T9:     Second read data word (D1) valid (for burst reads)
    T8+N-1: Last word of burst, avl_mem_readdatavalid deasserts after final word
```

### 8.4 Flash Memory Write (Page Program) Timing

A write to flash memory through the Avalon-MM memory interface. The IP internally issues a Write Enable command followed by a Page Program command.

```
                    ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
  clk           ───┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
                   T0    T1    T2    T3    T4    T5    T6    T7    T8    T9    T10

                       ┌──────────────────────────────────────────────────────┐
  avl_mem_write ───────┘                                                      └──────────
                       ▲ Master asserts write

                       ┌──────────────────────────────────────────────────────┐
  avl_mem_address ─────┤                   Flash Byte Address                 ├──────────
                       └──────────────────────────────────────────────────────┘

                       ┌──────────────────────────────────────────────────────┐
  avl_mem_writedata ───┤                   Program Data Word                  ├──────────
                       └──────────────────────────────────────────────────────┘

                       ┌──────────────────────────────────────────────────────┐
  avl_mem_byteenable ──┤                     4'b1111                          ├──────────
                       └──────────────────────────────────────────────────────┘

                       ┌────────────────────────────────────────────────┐
  avl_mem_waitrequest──┘                                                └────────────────
                       ▲ IP issues WREN + Page Program to flash         ▲ Program done

  ──── Internal Flash Bus (not directly visible to Avalon master) ────

                       ┌────────────────────┐                    ┌───┐
  flash_ncs     ───────┘                    └────────────────────┘   └───────────────────
                       ▲ WREN command       ▲ nCS deassert       ▲ Page Program cmd

                          ┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐                        ┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐
  flash_dclk    ──────────┘└┘└┘└┘└┘└┘└┘└┘└──────────────────────────┘└┘└┘└┘└┘└┘└┘└┘└────
                          ▲ 8 clocks (WREN)                        ▲ cmd+addr+data clocks

  Timeline:
    T0:     Master asserts avl_mem_write with address, writedata, byteenable
    T0-T2:  IP issues Write Enable (06h) command on SPI bus
    T2-T3:  nCS deasserted briefly between commands
    T3-T8:  IP issues Page Program (02h) command + 3/4 byte address + data
    T9:     avl_mem_waitrequest deasserts — write operation accepted
    Note:   Flash internal programming continues after SPI transfer completes.
            The IP polls flash status internally until programming is finished.
```

### 8.5 Flash Sector Erase Timing

Sector erase is triggered via the CSR Control Register. The IP handles the full WREN + Sector Erase + polling sequence.

```
                    ┌──┐  ┌──┐  ┌──┐  ┌──┐        ┌──┐  ┌──┐  ┌──┐        ┌──┐  ┌──┐
  clk           ───┘  └──┘  └──┘  └──┘  └── ··· ──┘  └──┘  └──┘  └── ··· ──┘  └──┘  └──
                   T0    T1    T2    T3        Tn   Tn+1 Tn+2        Tm   Tm+1

  ──── Phase 1: CSR Write to Trigger Erase ────

                       ┌───────────┐
  avl_csr_write ───────┘           └──────────────────────────────────────────────────────
                       ▲ Write Control Reg [2]=1 (SECTOR_ERASE)

                       ┌───────────┐
  avl_csr_address ─────┤  0x00     ├──────────────────────────────────────────────────────
                       └───────────┘

                       ┌───────────┐
  avl_csr_writedata ───┤0x00000004 ├──────────────────────────────────────────────────────
                       └───────────┘

                       ┌─────┐
  avl_csr_waitrequest──┘     └────────────────────────────────────────────────────────────
                       ▲ Ack ▲ Accepted

  ──── Phase 2: IP Executes Erase on SPI Bus (internal) ────

                             ┌──────────┐     ┌──────────────────────────────────┐
  flash_ncs     ─────────────┘          └─────┘                                  └────────
                             ▲ WREN cmd       ▲ Sector Erase (20h) + address

                               ┌┐┌┐┌┐┌┐┌┐┌┐   ┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐
  flash_dclk    ───────────────┘└┘└┘└┘└┘└┘└┘───┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘└┘────────
                               ▲ 8 clocks     ▲ 8 (cmd) + 24/32 (addr) clocks

  ──── Phase 3: IP Polls Flash Status Until Erase Complete ────

  avl_csr_readdata              (Status Reg @ offset 0x04)
    bit[0] BUSY  ──────────────────────────────────────────────────────────────┐
                                                                               └──────
                   ◄───── BUSY=1 while erase in progress ────────────────────►  BUSY=0

  Timeline:
    T0:       Master writes 0x04 to Control Register (offset 0x00) to trigger sector erase
    T1:       CSR write accepted; IP begins internal erase sequence
    T2-T3:    IP issues WREN (06h) command on SPI bus
    T4-Tn:    IP issues Sector Erase (20h) + sector address on SPI bus
    Tn-Tm:    IP polls flash status register (05h) internally
    Tm:       Flash erase completes; Status Register BUSY bit clears
    Note:     Sector erase typically takes 50-400 ms depending on the flash device.
```

### 8.6 SPI Flash Physical Interface Timing

Detailed timing of the physical SPI bus signals during a standard single-bit (x1) read command.

```
  ══════════════════════════════════════════════════════════════════════
   SPI Mode 0: CPOL=0, CPHA=0 — Data sampled on DCLK rising edge
  ══════════════════════════════════════════════════════════════════════

               ┌────────────────────────────────────────────────────────────────────────┐
  flash_ncs ───┘                                                                        └──
               ▲ CS asserted (low)                                        CS deasserted ▲

                  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐     ┌──┐  ┌──┐  ┌──┐
  flash_dclk ────┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └─ ··· ┘  └──┘  └──┘  └──
                  ▲1    ▲2    ▲3    ▲4    ▲5    ▲6    ▲7    ▲8        ▲N-1  ▲N
                                                                      (data phase)
               ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
  flash_data   │ CMD │ CMD │ CMD │ CMD │ CMD │ CMD │ CMD │ CMD │  A23  A22 ··· A0  D7 ··· D0
  _out (ASDO)  │ [7] │ [6] │ [5] │ [4] │ [3] │ [2] │ [1] │ [0] │
               └──┬──┴──┬──┴──┬──┴──┬──┴──┬──┴──┬──┴──┬──┴──┬──┘
                  ▲     ▲     ▲     ▲     ▲     ▲     ▲     ▲
                  Data driven on falling edge of DCLK

                                                                  ┌─────────────────────┐
  flash_data_in  ─────────────────────────────────── ··· ─────────┤ D7  D6 ··· D1  D0   │
  (DATA0)                                                         └──┬──┬──────┬──┬─────┘
                                                                     ▲  ▲      ▲  ▲
                                                        Data sampled on rising edge of DCLK

  ──── Signal Timing Parameters ────

            ┌──────┐
  DCLK   ───┘      └───
            │ tCH  │tCL│
            │◄────►│◄─►│

            │tSU│      │tHD│
            │◄─►│      │◄─►│
  DATA   ──XXXXX╱▔▔▔▔▔▔╲XXXXX──
                 Valid Data

  Parameter         Symbol    Min     Max     Unit
  ─────────────────────────────────────────────────
  DCLK frequency    fCLK      —       100     MHz
  DCLK high time    tCH       4.5     —       ns
  DCLK low time     tCL       4.5     —       ns
  Data setup time   tSU       2.0     —       ns
  Data hold time    tHD       2.5     —       ns
  CS setup time     tCSS      5.0     —       ns
  CS hold time      tCSH      5.0     —       ns
  CS deselect time  tCSDE     50      —       ns
```

### 8.7 QSPI (Quad-SPI) Data Transfer Timing

In Quad-SPI mode, four data lines transfer data simultaneously for 4x throughput.

```
  ══════════════════════════════════════════════════════════════════════
   Quad-SPI Read: Command on x1, Data on x4
  ══════════════════════════════════════════════════════════════════════

               ┌──────────────────────────────────────────────────────────────────────┐
  flash_ncs ───┘                                                                      └──
               ▲ CS asserted

               ◄──── Command (x1) ────►◄── Address (x1) ──►◄ Dummy ►◄── Data (x4) ──►

                  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐
  flash_dclk ────┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
                  ▲1    ▲2    ▲3    ▲4    ...                  ▲D1   ▲D2   ▲D3   ▲D4

  DATA[0]     ───┤CMD7├┤CMD6├┤CMD5├┤CMD4├┤CMD3├┤CMD2├┤CMD1├┤CMD0├┤A23├─ ··· ─┤ D3 ├┤ D7 ├─
  (ASDO/DQ0)

  DATA[1]     ─────────────────────────────────────────────── ··· ─┤ D2 ├┤ D6 ├─────────
  (DQ1)

  DATA[2]     ─────────────────────────────────────────────── ··· ─┤ D1 ├┤ D5 ├─────────
  (DQ2)

  DATA[3]     ─────────────────────────────────────────────── ··· ─┤ D0 ├┤ D4 ├─────────
  (DQ3/HOLD#)

               ◄── ASDO drives cmd ──►◄── ASDO drives addr ──►     ◄── Flash drives ──►
               ◄── flash_data_oe = 1 ─────────────────────────►     ◄ flash_data_oe=0 ►

  Data Mapping (per DCLK cycle in x4 mode):
  ┌──────────────────────────────────────────────────────┐
  │ DCLK Edge  │ DQ3  │ DQ2  │ DQ1  │ DQ0  │ Nibble     │
  ├────────────┼──────┼──────┼──────┼──────┼────────────┤
  │ Rising  1  │ D[7] │ D[6] │ D[5] │ D[4] │ High nibble│
  │ Rising  2  │ D[3] │ D[2] │ D[1] │ D[0] │ Low nibble │
  └──────────────────────────────────────────────────────┘
  One byte transferred every 2 DCLK cycles in x4 mode
  (vs. 8 DCLK cycles in standard x1 SPI mode)
```

### 8.8 Flash Memory Bulk Erase Timing

Bulk erase erases the entire flash device. This is a long-duration operation.

```
                    ┌──┐  ┌──┐  ┌──┐        ┌──┐  ┌──┐  ┌──┐         ┌──┐  ┌──┐
  clk           ───┘  └──┘  └──┘  └── ··· ──┘  └──┘  └──┘  └── ···──┘  └──┘  └──
                   T0    T1    T2       Tn   Tn+1 Tn+2             Tm   Tm+1

  ──── Avalon-MM CSR: Trigger Bulk Erase ────

                       ┌───────────┐
  avl_csr_write ───────┘           └──────────────────────────────────────────────────
                       ▲ Write 0x20 to Control Reg (bit[5]=BULK_ERASE)

                       ┌─────┐
  avl_csr_waitrequest──┘     └────────────────────────────────────────────────────────

  ──── Flash SPI Bus: WREN + Bulk Erase Command ────

                           ┌────────────┐     ┌────────────┐
  flash_ncs     ───────────┘            └─────┘            └──────────────────────────
                           ▲ WREN (06h)       ▲ Bulk Erase (C7h)

                             ┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐  ┌┐┌┐┌┐┌┐┌┐┌┐┌┐┌┐
  flash_dclk    ─────────────┘└┘└┘└┘└┘└┘└�└┘└┘──┘└┘└┘└┘└┘└┘└┘└┘└┘────────────────────
                             ▲ 8 clocks        ▲ 8 clocks

  ──── Status Polling (IP polls automatically) ────

  Status BUSY bit ─────────────────────────────────────────────────────────┐
                   ◄────── BUSY=1 (erase in progress, seconds to min) ───►└─── BUSY=0

  Timeline:
    T0:       Master writes 0x20 to Control Register
    T1:       IP issues WREN (06h) on SPI bus
    T2-T3:    IP issues Bulk Erase (C7h) on SPI bus
    T4-Tm:    IP automatically polls flash status (Read Status Register, 05h)
    Tm:       Flash bulk erase complete; BUSY clears
    Note:     Bulk erase can take 30 seconds to several minutes.
```

---

## 9. Functional Description

### 9.1 CSR Byte Enable

The `avl_csr_byteenable` signal allows selective byte access within the 32-bit CSR registers. This enables targeted register manipulation without affecting adjacent bytes.

| byteenable[3:0] | Active Bytes | Description |
|------------------|--------------|-------------|
| `4'b0001` | Byte 0 (bits [7:0]) | Access only the lowest byte |
| `4'b0010` | Byte 1 (bits [15:8]) | Access only the second byte |
| `4'b0100` | Byte 2 (bits [23:16]) | Access only the third byte |
| `4'b1000` | Byte 3 (bits [31:24]) | Access only the highest byte |
| `4'b0011` | Bytes 0-1 (bits [15:0]) | Access the lower half-word |
| `4'b1100` | Bytes 2-3 (bits [31:16]) | Access the upper half-word |
| `4'b1111` | All bytes (bits [31:0]) | Full 32-bit word access |

### 9.2 Memory Operations

The GSFI IP supports the following memory operations through the Avalon-MM memory interface and CSR commands:

| Operation | Interface | Method | Description |
|-----------|-----------|--------|-------------|
| **Read** | Memory Slave | `avl_mem_read` | Read data from flash at specified address. Supports burst reads. |
| **Page Program** | Memory Slave | `avl_mem_write` | Program data into flash. Limited to page boundaries (typically 256 bytes). |
| **Sector Erase (4 KB)** | CSR | Control Reg bit[2] | Erase a 4 KB sector at the configured address. |
| **Block Erase (32 KB)** | CSR | Control Reg bit[3] | Erase a 32 KB block. |
| **Block Erase (64 KB)** | CSR | Control Reg bit[4] | Erase a 64 KB block. |
| **Bulk Erase** | CSR | Control Reg bit[5] | Erase the entire flash device. |
| **Read Status** | CSR | Control Reg bit[6] | Read the flash device status register. |
| **Write Status** | CSR | Control Reg bit[7] | Write the flash device status register. |
| **Read Silicon ID** | CSR | Control Reg bit[8] | Read the JEDEC/Silicon ID from the flash device. |

### 9.3 Byte Enabling for Memory Operations

For memory write operations, `avl_mem_byteenable` controls which bytes of the 32-bit write data word are actually programmed into flash:

- Only bytes corresponding to asserted byteenable bits are programmed.
- Bytes with deasserted byteenable bits are treated as "no-change" (0xFF in flash programming terms).
- The IP internally manages the read-modify-write sequence when partial byte enables are used.

---

## 10. I/O Pin Constraints

### 10.1 Active Serial Interface

When using Intel FPGA configuration devices (EPCQ/EPCQ-L) via the dedicated Active Serial (AS) interface:

| Flash Signal | FPGA Pin | Pin Type |
|--------------|----------|----------|
| nCSO | AS_nCSO | Dedicated |
| DCLK | DCLK | Dedicated |
| ASDO | ASDO | Dedicated |
| DATA0 | DATA0 | Dedicated |
| DATA1 (QSPI) | DATA1 | Dedicated |
| DATA2 (QSPI) | DATA2 | Dedicated |
| DATA3 (QSPI) | DATA3 | Dedicated |

### 10.2 Pin Assignment Guidelines

1. **Dedicated AS Pins:** When using the dedicated Active Serial interface, pin assignments are fixed by the device and cannot be reassigned. Enable `CHIP_SELECT_ACTIVE_SERIAL` in the IP parameters.

2. **GPIO-Based Connection:** For non-AS flash connections, assign the flash interface signals to general-purpose I/O pins. Apply appropriate I/O standard and timing constraints.

3. **Timing Constraints:** Apply the following SDC constraints for the flash DCLK output:

```tcl
# Flash DCLK output delay constraint
set_output_delay -clock flash_clk -max 5.0 [get_ports {flash_dclk}]
set_output_delay -clock flash_clk -min -1.0 [get_ports {flash_dclk}]

# Flash data output delay constraints
set_output_delay -clock flash_clk -max 3.0 [get_ports {flash_data_out[*]}]
set_output_delay -clock flash_clk -min -1.0 [get_ports {flash_data_out[*]}]

# Flash data input delay constraints
set_input_delay -clock flash_clk -max 7.0 [get_ports {flash_data_in[*]}]
set_input_delay -clock flash_clk -min 1.0 [get_ports {flash_data_in[*]}]
```

---

## 11. Reference Design

A reference design demonstrating GSFI IP usage with a Nios II processor is available through Intel Platform Designer. The reference design includes:

| Component | Description |
|-----------|-------------|
| **Nios II Processor** | Embedded processor for executing flash access software |
| **GSFI IP Core** | Configured for the target flash device |
| **On-Chip Memory** | Program and data memory for Nios II |
| **JTAG UART** | Debug and communication interface |
| **System ID** | Unique system identification peripheral |
| **PLL** | Clock generation for system and flash interface |

**Reference design workflow:**

1. Create a Platform Designer system with the components listed above.
2. Connect the Nios II data master to the GSFI CSR and Memory Avalon-MM slave ports.
3. Assign the flash interface signals to the appropriate FPGA pins.
4. Generate the system HDL and compile in Intel Quartus Prime.
5. Build the Nios II software application using the GSFI HAL driver.
6. Program the FPGA and run the flash access application.

---

## 12. Software Support

### 12.1 Nios II HAL Driver

The GSFI IP includes a Hardware Abstraction Layer (HAL) driver for the Nios II processor ecosystem. The driver provides a high-level API for flash operations and is automatically included when the GSFI IP is added to a Platform Designer system.

**Driver files:**

| File | Description |
|------|-------------|
| `altera_generic_serial_flash_interface.h` | HAL driver header with API declarations |
| `altera_generic_serial_flash_interface.c` | HAL driver implementation |
| `altera_generic_serial_flash_interface_regs.h` | Register offset and bit-field definitions |

### 12.2 HAL API Functions

| Function | Description |
|----------|-------------|
| `alt_gsfi_flash_open()` | Initialize the GSFI driver and identify the flash device |
| `alt_gsfi_flash_read()` | Read data from flash memory |
| `alt_gsfi_flash_write()` | Program data to flash memory (handles page boundaries) |
| `alt_gsfi_flash_erase()` | Erase a flash sector or block |
| `alt_gsfi_flash_bulk_erase()` | Erase the entire flash device |
| `alt_gsfi_flash_get_info()` | Retrieve flash device information (capacity, sector size) |
| `alt_gsfi_flash_read_status()` | Read the flash device status register |
| `alt_gsfi_flash_close()` | Release GSFI driver resources |

**Example usage:**

```c
#include "altera_generic_serial_flash_interface.h"

int main(void) {
    alt_gsfi_flash_dev *flash;
    uint8_t buffer[256];

    flash = alt_gsfi_flash_open("/dev/gsfi");
    if (flash == NULL) {
        printf("Error: Could not open flash device\n");
        return -1;
    }

    alt_gsfi_flash_read(flash, 0x000000, buffer, sizeof(buffer));

    buffer[0] = 0xAB;
    alt_gsfi_flash_erase(flash, 0x000000, ALT_GSFI_SECTOR_ERASE);
    alt_gsfi_flash_write(flash, 0x000000, buffer, sizeof(buffer));

    alt_gsfi_flash_close(flash);
    return 0;
}
```

---

## 13. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 2026.03 | March 2026 | Initial documentation release covering GSFI IP core functionality, signal definitions, register map, I/O timing diagrams, and integration guidelines. |

---

*This document is based on the Generic Serial Flash Interface Intel FPGA IP. For the latest updates, refer to [Intel FPGA IP Documentation](https://www.intel.com/content/www/us/en/docs/programmable/683419/).*
