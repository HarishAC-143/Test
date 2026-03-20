# 06 — Interfaces & Packages

## Packages

A `package` groups related types, parameters, functions, and tasks into a single
namespace. Any module can `import` from a package to use its contents.

### Benefits
- **Reuse** — define types once, use everywhere.
- **Consistency** — a change in the package propagates to all users.
- **Namespace** — avoid name collisions between independent IP blocks.

### Import Styles

```systemverilog
import my_pkg::*;           // wildcard — imports everything
import my_pkg::data_t;      // selective — imports only data_t
```

## Interfaces

An `interface` bundles related signals into a single port. This is particularly
useful for bus protocols (AXI, Wishbone, etc.) where adding a signal would
otherwise require editing every module in the hierarchy.

### Modports

A `modport` defines the direction of each signal from the perspective of a
particular user (master, slave, monitor).

```systemverilog
interface axi_if;
    logic        awvalid, awready;
    logic [31:0] awaddr;
    // ...

    modport master (output awvalid, awaddr, input  awready);
    modport slave  (input  awvalid, awaddr, output awready);
endinterface
```

## Files in This Directory

- [`common_pkg.sv`](common_pkg.sv) — Package with types, constants, and utility functions
- [`simple_bus_if.sv`](simple_bus_if.sv) — Simple bus interface with modports
- [`bus_master.sv`](bus_master.sv) — Module using the master modport
- [`bus_slave.sv`](bus_slave.sv) — Module using the slave modport
- [`top_with_interface.sv`](top_with_interface.sv) — Top-level connecting master and slave
