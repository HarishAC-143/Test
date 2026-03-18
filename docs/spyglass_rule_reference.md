# SpyGlass Rule Quick Reference

A concise reference of the most commonly encountered SpyGlass Lint and CDC rules, organized by category.

---

## Lint Rules

### Synthesis / Simulation Mismatch

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **W_116** | Warning | Latch inferred for signal | Add `else` branch or `default` case |
| **W_391** | Warning | Blocking assignment in sequential always block | Change `=` to `<=` |
| **W_456** | Warning | Non-blocking assignment in combinational always block | Change `<=` to `=` |
| **W_263** | Error | Signal driven from multiple always blocks | Merge into single always block |

### Width and Type

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **W_164** | Warning | Signal is not driven | Connect or remove the signal |
| **W_164a** | Warning | Width mismatch in assignment (truncation) | Use explicit bit-select |
| **W_164b** | Info | Width mismatch in assignment (extension) | Use explicit concatenation |
| **W_224** | Warning | Multi-bit expression in boolean context | Compare explicitly (`!= 0`) |

### Connectivity

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **W_240** | Warning | Signal is driven but never loaded | Remove or document why unused |
| **W_287** | Warning | Port unconnected in instantiation | Connect or explicitly leave open |
| **W_446** | Error | Signal driven from multiple modules | Fix design hierarchy |

### FSM

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **W_146** | Warning | Unreachable state detected | Remove dead state or add transition |
| **W_392** | Info | FSM output not registered | Register outputs or waive |

### STARC Methodology Rules

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **STARC-2.1.4.4** | Warning | Case without default | Add `default` branch |
| **STARC-2.3.1.1** | Warning | Blocking in sequential block | Use non-blocking |
| **STARC-2.1.6.1** | Warning | Latch inferred (STARC variant) | Complete all assignments |

### Clock and Reset

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **W_398** | Warning | Async reset not used consistently | Standardize reset usage |
| **W_399** | Warning | Gated clock detected | Use clock-enable instead |
| **W_467** | Info | Clock used as data | Review design intent |

### Array / Memory

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **W_362** | Warning | Array index may exceed bounds | Widen array or guard index |
| **W_551** | Warning | Memory has no initialization | Add reset logic |

---

## CDC Rules

### Missing Synchronization

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **Ac_cdc01** | Error | Signal crosses domain without synchronizer | Add 2-FF synchronizer |
| **Ac_cdc02** | Error | Insufficient synchronization stages | Add more sync stages |

### Combinational Logic

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **Ac_cdc03** | Warning | Combinational logic on CDC path | Register in source domain |
| **Ac_cdc03a** | Warning | Glitch potential on CDC signal | Register before crossing |

### Multi-Bit Crossing

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **Ac_cdc04** | Error | Bus synchronized bit-by-bit | Use gray-code FIFO or handshake |
| **Ac_cdc05** | Error | Multi-bit signal crosses domain | Use gray-code or handshake |

### Reconvergence

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **Ac_cdc07** | Warning | Reconvergence of CDC signals | Use coherent transfer (FIFO/handshake) |
| **Ac_cdc08** | Warning | Data/control coherency issue | Bundle signals in single transfer |

### Reset Domain Crossing

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **Ac_rdc01** | Error | Reset crosses domain unsynchronized | Add reset synchronizer |
| **Ac_rdc02** | Error | Async reset deassertion not synchronized | Use async-assert, sync-deassert pattern |

### Clock Structure

| Rule | Severity | Description | Typical Fix |
|------|----------|-------------|-------------|
| **Ac_cdc10** | Warning | Generated clock not defined | Add `create_generated_clock` in SDC |
| **Ac_unsync01** | Info | Potential CDC path (info only) | Review and constrain |

---

## Severity Levels

| Level | Description | Action Required |
|-------|-------------|-----------------|
| **Fatal** | Design cannot be elaborated | Must fix immediately |
| **Error** | Functional risk — potential silicon failure | Fix before tapeout |
| **Warning** | Possible issue — requires review | Fix or waive with justification |
| **Info** | Informational only | No action required |

---

## Useful Commands

```tcl
# List rules in a goal
report_rules -goal lint/lint_rtl

# Change rule severity
set_goal_option severity {W_116=Error}

# Add/remove rules from a goal
set_goal_option addrules {CUSTOM_001}
set_goal_option delrules {W_551}

# Report all violations for a rule
report_violations -rule W_116

# Report CDC crossings
report_crossings
report_crossings -rule Ac_cdc01
```
