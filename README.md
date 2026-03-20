# UVM (Universal Verification Methodology) -- Complete Tutorial

A comprehensive, hands-on guide to UVM covering fundamental concepts through advanced
techniques, with fully worked practical examples in SystemVerilog.

---

## Table of Contents

| # | Topic | Description |
|---|-------|-------------|
| 1 | [UVM Basics](docs/01_uvm_basics.md) | Architecture, class hierarchy, components, phases, factory |
| 2 | [UVM Intermediate](docs/02_uvm_intermediate.md) | Sequences, sequencers, configuration database, reporting |
| 3 | [UVM Advanced](docs/03_uvm_advanced.md) | Callbacks, virtual sequences, register layer, functional coverage |
| 4 | [Example -- ALU Testbench](examples/alu/README.md) | End-to-end verification of a simple ALU |
| 5 | [Example -- Memory Model](examples/memory/README.md) | Constrained-random verification of a synchronous memory |
| 6 | [Example -- AXI-Lite Interface](examples/axi_lite/README.md) | Protocol-level verification using an AXI-Lite VIP |

---

## Prerequisites

- Working knowledge of **SystemVerilog** (data types, classes, interfaces, assertions).
- A simulator that supports UVM 1.2 / IEEE 1800.2 (e.g., Synopsys VCS, Cadence Xcelium,
  Mentor Questa, Verilator with UVM support, or the open-source UVVM).
- The UVM class library (ships with most commercial simulators, or download from
  [Accellera](https://www.accellera.org/downloads/standards/uvm)).

## Quick Start

```bash
# Clone the repository
git clone <repo-url> && cd Test

# Run the ALU example (VCS)
cd examples/alu
vcs -sverilog -ntb_opts uvm-1.2 -f filelist.f -o simv && ./simv

# Run the ALU example (Questa)
cd examples/alu
vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv -f filelist.f
vsim -c top -do "run -all; quit"
```

## Repository Layout

```
.
├── README.md                  # This file
├── docs/
│   ├── 01_uvm_basics.md       # Fundamentals tutorial
│   ├── 02_uvm_intermediate.md # Intermediate tutorial
│   └── 03_uvm_advanced.md     # Advanced tutorial
└── examples/
    ├── alu/                   # ALU testbench example
    │   ├── README.md
    │   ├── rtl/
    │   ├── tb/
    │   └── filelist.f
    ├── memory/                # Memory model example
    │   ├── README.md
    │   ├── rtl/
    │   ├── tb/
    │   └── filelist.f
    └── axi_lite/              # AXI-Lite example
        ├── README.md
        ├── rtl/
        ├── tb/
        └── filelist.f
```

## License

This tutorial content is provided under the [MIT License](LICENSE).

## Contributing

Contributions, corrections, and improvements are welcome. Please open an issue or submit a
pull request.
