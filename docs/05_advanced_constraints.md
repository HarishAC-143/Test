# Chapter 5: Advanced Constraints

## Table of Contents

- [PLL Constraints in Detail](#pll-constraints-in-detail)
- [Clock Domain Crossing Strategies](#clock-domain-crossing-strategies)
- [SDC Scripting Techniques](#sdc-scripting-techniques)
- [Quartus-Specific SDC Commands](#quartus-specific-sdc-commands)
- [Hierarchical SDC Constraints](#hierarchical-sdc-constraints)
- [Constraining Memory Interfaces](#constraining-memory-interfaces)
- [Constraining LVDS and High-Speed I/O](#constraining-lvds-and-high-speed-io)
- [Practical Examples](#practical-examples)

---

## PLL Constraints in Detail

### Automatic vs. Manual PLL Constraints

Quartus provides `derive_pll_clocks` for convenience, but sometimes you need manual control:

| Approach | When to Use |
|----------|-------------|
| `derive_pll_clocks` | Standard PLL usage, no special requirements |
| Manual `create_generated_clock` | Custom naming, non-standard PLL configurations, or when auto-detection fails |

### Manual PLL Clock Definition

```tcl
# Base clock feeding the PLL
create_clock -name clk_50 -period 20.000 [get_ports CLK_50MHZ]

# PLL output c0: 100 MHz (multiply by 2)
create_generated_clock -name pll_100mhz \
    -source [get_pins {my_pll|inclk[0]}] \
    -multiply_by 2 \
    [get_pins {my_pll|clk[0]}]

# PLL output c1: 25 MHz (divide by 2)
create_generated_clock -name pll_25mhz \
    -source [get_pins {my_pll|inclk[0]}] \
    -divide_by 2 \
    [get_pins {my_pll|clk[1]}]

# PLL output c2: 100 MHz, 90-degree phase shift
create_generated_clock -name pll_100mhz_90 \
    -source [get_pins {my_pll|inclk[0]}] \
    -multiply_by 2 \
    -phase 90.0 \
    [get_pins {my_pll|clk[2]}]
```

### PLL Cascade (PLL Feeding Another PLL)

```tcl
# First PLL: 50 MHz -> 200 MHz
create_clock -name clk_50 -period 20.000 [get_ports CLK_50MHZ]

derive_pll_clocks

# If using cascaded PLLs, ensure derive_pll_clocks catches both.
# Otherwise, manually define the second PLL's output:
create_generated_clock -name pll2_400mhz \
    -source [get_pins {pll2|inclk[0]}] \
    -multiply_by 2 \
    [get_pins {pll2|clk[0]}]
```

### PLL with Dynamic Reconfiguration

When a PLL can be reconfigured at runtime, define constraints for each possible configuration:

```tcl
# Mode 1: 100 MHz output
create_generated_clock -name pll_mode1 \
    -source [get_pins {reconfig_pll|inclk[0]}] \
    -multiply_by 2 \
    [get_pins {reconfig_pll|clk[0]}]

# Mode 2: 150 MHz output
create_generated_clock -name pll_mode2 \
    -source [get_pins {reconfig_pll|inclk[0]}] \
    -multiply_by 3 \
    -add \
    [get_pins {reconfig_pll|clk[0]}]

# These modes are exclusive (never active simultaneously)
set_clock_groups -exclusive -group {pll_mode1} -group {pll_mode2}
```

## Clock Domain Crossing Strategies

### Strategy 1: Simple Signal Synchronizer (False Path)

For single-bit signals that are level-sensitive and held stable for multiple destination clock cycles:

```tcl
set_false_path -from [get_registers {src_domain|signal_reg}] \
               -to   [get_registers {dst_domain|sync_meta}]
```

### Strategy 2: Gray Code FIFO Pointers (Max Delay)

For multi-bit gray-coded signals where bit-to-bit skew must be bounded:

```tcl
set_max_delay -from [get_registers {async_fifo|wr_ptr_gray[*]}] \
              -to   [get_registers {async_fifo|rd_ptr_sync1[*]}] \
              [get_property -name PERIOD -object [get_clocks rd_clk]]
```

### Strategy 3: Handshake Protocol (Max Delay)

For multi-bit data using req/ack handshake:

```tcl
# The data bus is stable while req is asserted
# Constrain to bounded delay
set_max_delay -from [get_registers {handshake|data_reg[*]}] \
              -to   [get_registers {handshake|data_sync[*]}] 10.000

# Req/Ack are single-bit synchronizers
set_false_path -from [get_registers {handshake|req_reg}] \
               -to   [get_registers {handshake|req_sync[0]}]
set_false_path -from [get_registers {handshake|ack_reg}] \
               -to   [get_registers {handshake|ack_sync[0]}]
```

### Strategy 4: MUX Recirculation (No Exception Needed)

When using a MUX-based synchronizer with recirculation, the path is typically within one clock domain and needs no exception.

## SDC Scripting Techniques

Since SDC is Tcl, you can write sophisticated constraint scripts.

### Variables and Expressions

```tcl
# Define timing parameters in variables
set SYS_PERIOD    10.000
set BOARD_DELAY   1.500
set EXT_TSU       2.000
set EXT_TH        0.800

# Calculate derived values
set INPUT_MAX  [expr {$EXT_TSU + $BOARD_DELAY}]
set INPUT_MIN  [expr {-$EXT_TH + $BOARD_DELAY}]
set OUTPUT_MAX [expr {$EXT_TSU + $BOARD_DELAY}]
set OUTPUT_MIN [expr {-$EXT_TH + $BOARD_DELAY}]

create_clock -name sys_clk -period $SYS_PERIOD [get_ports CLK]

set_input_delay  -clock sys_clk -max $INPUT_MAX  [get_ports {DIN[*]}]
set_input_delay  -clock sys_clk -min $INPUT_MIN  [get_ports {DIN[*]}]
set_output_delay -clock sys_clk -max $OUTPUT_MAX [get_ports {DOUT[*]}]
set_output_delay -clock sys_clk -min $OUTPUT_MIN [get_ports {DOUT[*]}]
```

### Iterating Over Ports

```tcl
# Apply constraints to each port individually with different delays
set port_delays {
    {SPI_MOSI 3.0 1.0}
    {SPI_MISO 4.0 1.5}
    {SPI_CS_N 2.5 0.8}
}

foreach entry $port_delays {
    set port_name [lindex $entry 0]
    set max_del   [lindex $entry 1]
    set min_del   [lindex $entry 2]

    set_input_delay -clock spi_clk -max $max_del [get_ports $port_name]
    set_input_delay -clock spi_clk -min $min_del [get_ports $port_name]
}
```

### Conditional Constraints

```tcl
# Apply different constraints based on the target device
set device_family [get_global_assignment -name FAMILY]

if {$device_family eq "Cyclone V"} {
    set IO_STANDARD "2.5 V"
    set CLK_UNCERTAINTY 0.150
} elseif {$device_family eq "Arria 10"} {
    set IO_STANDARD "1.8 V"
    set CLK_UNCERTAINTY 0.100
} else {
    set IO_STANDARD "3.3 V"
    set CLK_UNCERTAINTY 0.200
}

set_clock_uncertainty -setup $CLK_UNCERTAINTY [get_clocks sys_clk]
```

### Procedure for Reusable Constraints

```tcl
# Procedure to constrain a complete bus interface
proc constrain_bus_interface {clk_name port_prefix max_delay min_delay direction} {
    set ports [get_ports ${port_prefix}*]

    if {$direction eq "input"} {
        set_input_delay -clock $clk_name -max $max_delay $ports
        set_input_delay -clock $clk_name -min $min_delay $ports
    } elseif {$direction eq "output"} {
        set_output_delay -clock $clk_name -max $max_delay $ports
        set_output_delay -clock $clk_name -min $min_delay $ports
    }
}

# Usage:
constrain_bus_interface sys_clk "DATA_"  5.0 1.0 "input"
constrain_bus_interface sys_clk "ADDR_"  4.5 1.2 "input"
constrain_bus_interface sys_clk "CTRL_"  3.0 0.8 "output"
```

### Wildcard Collection and Filtering

```tcl
# Get all clock ports
set all_clk_ports [get_ports *CLK*]

# Get all data ports except clocks
set data_ports [remove_from_collection [get_ports *] $all_clk_ports]

# Apply default input delay to all data ports
set_input_delay -clock sys_clk -max 5.0 $data_ports
set_input_delay -clock sys_clk -min 1.0 $data_ports
```

## Quartus-Specific SDC Commands

Intel Quartus extends the standard SDC command set with several proprietary commands:

### derive_pll_clocks

Automatically creates clock constraints for PLL outputs (covered in Chapter 2).

```tcl
derive_pll_clocks
```

### derive_clock_uncertainty

Automatically calculates and applies clock uncertainty based on PLL jitter, clock network skew, and inter-/intra-clock transfers.

```tcl
derive_clock_uncertainty
```

### get_registers (Quartus-specific)

While standard SDC uses `get_cells`, Quartus uses `get_registers` to refer to register elements:

```tcl
# Standard SDC
get_cells {my_reg}

# Quartus SDC
get_registers {my_reg}
```

### get_pins, get_ports, get_nets

```tcl
# Physical I/O port of the FPGA
get_ports {CLK DATA[0]}

# Internal pin of a cell
get_pins {my_pll|clk[0]}

# Internal net
get_nets {data_bus[*]}
```

### post_message

Output messages during SDC processing:

```tcl
post_message -type info "Applying timing constraints for DDR3 interface"
post_message -type warning "Clock frequency exceeds recommended maximum"
post_message -type error "Required port not found"
```

## Hierarchical SDC Constraints

For large designs, organize constraints into multiple SDC files by subsystem:

### Project Structure

```
project/
├── constraints/
│   ├── clocks.sdc          # All clock definitions
│   ├── io_constraints.sdc  # I/O timing
│   ├── exceptions.sdc      # False paths, multicycle
│   ├── ddr3_interface.sdc  # DDR3-specific constraints
│   └── pcie_interface.sdc  # PCIe-specific constraints
```

### Ordering Matters

SDC files are processed in order. Define clocks before using them in I/O or exception constraints:

```tcl
# In Quartus project settings, order matters:
# 1. clocks.sdc         (create_clock, derive_pll_clocks)
# 2. io_constraints.sdc (set_input_delay, set_output_delay)
# 3. exceptions.sdc     (set_false_path, set_multicycle_path)
# 4. ddr3_interface.sdc (interface-specific constraints)
```

### Using Source to Include Files

```tcl
# Master SDC file that includes others
source [file join [file dirname [info script]] clocks.sdc]
source [file join [file dirname [info script]] io_constraints.sdc]
source [file join [file dirname [info script]] exceptions.sdc]
```

## Constraining Memory Interfaces

### DDR3 SDRAM (Source-Synchronous Write)

```tcl
# DQS clock output (source-synchronous, center-aligned for write)
create_generated_clock -name ddr_dqs_out \
    -source [get_pins {ddr_phy|dqs_out_reg|clk}] \
    -divide_by 1 \
    -phase 90.0 \
    [get_ports DDR3_DQS]

# Write data is edge-aligned with DQS
set_output_delay -clock ddr_dqs_out -max  0.250 [get_ports {DDR3_DQ[*]}]
set_output_delay -clock ddr_dqs_out -min -0.250 [get_ports {DDR3_DQ[*]}]

# Add falling edge for DDR
set_output_delay -clock ddr_dqs_out -max  0.250 -clock_fall -add_delay [get_ports {DDR3_DQ[*]}]
set_output_delay -clock ddr_dqs_out -min -0.250 -clock_fall -add_delay [get_ports {DDR3_DQ[*]}]
```

### QDR SRAM

```tcl
# QDR uses separate read and write clocks
create_clock -name qdr_k -period 4.000 [get_ports QDR_K]

create_generated_clock -name qdr_kn \
    -source [get_ports QDR_K] \
    -invert \
    [get_ports QDR_KN]

# Write data
set_output_delay -clock qdr_k -max 0.350 [get_ports {QDR_D[*]}]
set_output_delay -clock qdr_k -min -0.350 [get_ports {QDR_D[*]}]

# Read data (CQ clock from SRAM)
create_clock -name qdr_cq -period 4.000 [get_ports QDR_CQ]

set_input_delay -clock qdr_cq -max  0.350 [get_ports {QDR_Q[*]}]
set_input_delay -clock qdr_cq -min -0.350 [get_ports {QDR_Q[*]}]
```

## Constraining LVDS and High-Speed I/O

### LVDS Input

```tcl
# LVDS clock input at 400 MHz (DDR, so data rate = 800 Mbps)
create_clock -name lvds_clk -period 2.500 [get_ports LVDS_CLK_P]

# LVDS data inputs (source-synchronous, center-aligned)
set_input_delay -clock lvds_clk -max  0.300 [get_ports {LVDS_DATA_P[*]}]
set_input_delay -clock lvds_clk -min -0.300 [get_ports {LVDS_DATA_P[*]}]

# DDR falling edge
set_input_delay -clock lvds_clk -max  0.300 -clock_fall -add_delay [get_ports {LVDS_DATA_P[*]}]
set_input_delay -clock lvds_clk -min -0.300 -clock_fall -add_delay [get_ports {LVDS_DATA_P[*]}]
```

### SERDES Interface

```tcl
# Slow clock for SERDES (parallel side)
create_clock -name serdes_slow_clk -period 20.000 [get_ports SERDES_CLK]

# Fast clock is generated internally (8:1 SERDES)
create_generated_clock -name serdes_fast_clk \
    -source [get_ports SERDES_CLK] \
    -multiply_by 8 \
    [get_pins {serdes_pll|clk[0]}]

# Parallel data is multicycle relative to fast clock
set_multicycle_path -setup \
    -from [get_registers {serdes|par_data[*]}] \
    -to   [get_registers {serdes|shift_reg[*]}] 8
set_multicycle_path -hold \
    -from [get_registers {serdes|par_data[*]}] \
    -to   [get_registers {serdes|shift_reg[*]}] 7
```

## Practical Examples

### Example 1: Complete Ethernet PHY Interface

```tcl
#-----------------------------------------------
# RGMII Interface to Ethernet PHY (1 Gbps)
#-----------------------------------------------

# 125 MHz reference clock from PHY
create_clock -name rgmii_rx_clk -period 8.000 [get_ports ETH_RX_CLK]

# TX clock is PLL-generated
# (Assume PLL output used for TX, handled by derive_pll_clocks)
derive_pll_clocks

set tx_clk {eth_pll|altpll_component|auto_generated|pll1|clk[0]}

# RGMII RX: Data is center-aligned with clock (DDR)
# RGMII spec: Tskew = ±0.5 ns from center
set_input_delay -clock rgmii_rx_clk -max  0.500 [get_ports {ETH_RXD[*] ETH_RX_CTL}]
set_input_delay -clock rgmii_rx_clk -min -0.500 [get_ports {ETH_RXD[*] ETH_RX_CTL}]
set_input_delay -clock rgmii_rx_clk -max  0.500 -clock_fall -add_delay [get_ports {ETH_RXD[*] ETH_RX_CTL}]
set_input_delay -clock rgmii_rx_clk -min -0.500 -clock_fall -add_delay [get_ports {ETH_RXD[*] ETH_RX_CTL}]

# RGMII TX: FPGA must drive data center-aligned with TX_CLK
set_output_delay -clock $tx_clk -max  1.000 [get_ports {ETH_TXD[*] ETH_TX_CTL}]
set_output_delay -clock $tx_clk -min -1.000 [get_ports {ETH_TXD[*] ETH_TX_CTL}]
set_output_delay -clock $tx_clk -max  1.000 -clock_fall -add_delay [get_ports {ETH_TXD[*] ETH_TX_CTL}]
set_output_delay -clock $tx_clk -min -1.000 -clock_fall -add_delay [get_ports {ETH_TXD[*] ETH_TX_CTL}]

# MDIO (management) is slow and asynchronous to data path
set_false_path -from [get_ports ETH_MDIO]
set_false_path -to   [get_ports ETH_MDIO]
set_false_path -to   [get_ports ETH_MDC]
```

### Example 2: Multi-Clock Video Processing Pipeline

```tcl
#-----------------------------------------------
# Video Processing System
# - Pixel clock: 148.5 MHz (1080p60)
# - Processing clock: 200 MHz
# - Output clock: 148.5 MHz
#-----------------------------------------------

# Input pixel clock
create_clock -name pix_clk_in -period 6.734 [get_ports HDMI_PCLK]

# Processing PLL
derive_pll_clocks
derive_clock_uncertainty

set proc_clk {video_pll|auto_generated|pll1|clk[0]}
set pix_clk_out {video_pll|auto_generated|pll1|clk[1]}

# Input video data (source-synchronous to pixel clock)
set_input_delay -clock pix_clk_in -max 2.000 [get_ports {VID_DATA[*] VID_VSYNC VID_HSYNC VID_DE}]
set_input_delay -clock pix_clk_in -min 0.500 [get_ports {VID_DATA[*] VID_VSYNC VID_HSYNC VID_DE}]

# Input pixel clock domain is asynchronous to processing domain
set_clock_groups -asynchronous \
    -group [get_clocks pix_clk_in] \
    -group [get_clocks $proc_clk]

# Frame buffer CDC (uses async FIFO)
set_false_path -from [get_registers {frame_buf|wr_ptr_gray[*]}] \
               -to   [get_registers {frame_buf|rd_ptr_sync[0][*]}]
set_false_path -from [get_registers {frame_buf|rd_ptr_gray[*]}] \
               -to   [get_registers {frame_buf|wr_ptr_sync[0][*]}]

# Output video data
set_output_delay -clock $pix_clk_out -max 2.500 [get_ports {VID_OUT[*] OUT_VSYNC OUT_HSYNC OUT_DE}]
set_output_delay -clock $pix_clk_out -min 0.000 [get_ports {VID_OUT[*] OUT_VSYNC OUT_HSYNC OUT_DE}]
```

---

**Previous: [Chapter 4 - Timing Exceptions](04_timing_exceptions.md)** | **Next: [Chapter 6 - Understanding Timing Reports](06_timing_reports.md)**
