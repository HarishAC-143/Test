# ==============================================================================
# SpyGlass Waiver File
# ==============================================================================
#
# This file contains waivers (intentional suppressions) for SpyGlass
# violations that have been reviewed and determined to be acceptable.
#
# WAIVER GUIDELINES:
#   1. Every waiver MUST have a -comment explaining the justification
#   2. Waivers should be as specific as possible (signal-level, not rule-level)
#   3. This file should be version-controlled alongside the RTL
#   4. Waivers must be reviewed when the design changes
#   5. Temporary waivers should be marked with a TODO for removal
#
# ==============================================================================

# ==============================================================================
# Lint Waivers
# ==============================================================================

# --- W123: Unused signals ---

# Debug flags are intentionally unloaded at the top level; they are
# connected only when a debug probe is instantiated.
waive -rule W123 \
    -comment "Debug outputs — connected only in debug configuration" \
    -module connectivity_buggy \
    -signal debug_flags

# --- W287: Unconnected ports ---

# DFT scan ports are left unconnected in functional mode.
# They are connected by the DFT insertion tool post-synthesis.
# waive -rule W287 \
#     -comment "DFT scan ports — connected by DFT tool" \
#     -module top_module \
#     -signal {scan_in scan_out scan_enable}

# --- W116: Unloaded output port ---

# Status outputs from IP cores that are not used in this integration
# but are required by the IP interface specification.
# waive -rule W116 \
#     -comment "IP status port — not used in this integration" \
#     -module ip_wrapper \
#     -signal ip_status

# ==============================================================================
# CDC Waivers
# ==============================================================================

# --- Ac_cdc01: Unsynchronized crossing ---

# Boot-mode configuration pins are sampled once during power-on reset
# and never change during operation. They are quasi-static signals.
# waive -rule Ac_cdc01 \
#     -comment "Quasi-static: boot_mode set during reset, stable during operation" \
#     -module top_module \
#     -signal boot_mode[*]

# --- Ac_cdc02: Multi-bit crossing ---

# The config_data bus is written only during initialization (while the
# destination domain is in reset) and remains stable afterward.
# waive -rule Ac_cdc02 \
#     -comment "Written during init only; destination in reset during write" \
#     -module config_block \
#     -signal config_data[*]

# --- Ac_cdc04: Combinational logic before synchronizer ---

# The glue logic before this synchronizer is a simple buffer cell
# inserted by synthesis for fanout balancing. It does not create
# a glitch hazard because only one input changes at a time.
# waive -rule Ac_cdc04 \
#     -comment "Buffer cell only — single-input, no glitch possible" \
#     -instance u_sync_buf/u_sync_ff1

# ==============================================================================
# Severity Overrides
# ==============================================================================

# Promote combinational loop from Warning to Error — these should
# never be tolerated in production RTL.
# set_rule_severity W18 -severity error

# Demote style warnings to Info for legacy IP that cannot be modified.
# set_rule_severity W156 -severity info -module legacy_ip
