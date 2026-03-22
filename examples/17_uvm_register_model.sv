// UVM Register Abstraction Layer (RAL) Example
// Demonstrates: uvm_reg_field, uvm_reg, uvm_reg_block, uvm_reg_map,
//               front-door access, field-level operations, mirror/predict
//
// NOTE: This file requires a UVM library to compile. It is provided
//       as a reference/template for register model implementation.

package reg_model_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -----------------------------------------------------------------------
    // Register: CTRL_REG (offset 0x00)
    //   [0]    enable  — RW  — Module enable
    //   [2:1]  mode    — RW  — Operating mode (00=idle, 01=low, 10=high, 11=turbo)
    //   [3]    irq_en  — RW  — Interrupt enable
    //   [31:4] reserved— RO  — Always reads 0
    // -----------------------------------------------------------------------
    class ctrl_reg extends uvm_reg;
        `uvm_object_utils(ctrl_reg)

        rand uvm_reg_field enable;
        rand uvm_reg_field mode;
        rand uvm_reg_field irq_en;
             uvm_reg_field reserved;

        function new(string name = "ctrl_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            enable = uvm_reg_field::type_id::create("enable");
            enable.configure(
                .parent(this),
                .size(1),
                .lsb_pos(0),
                .access("RW"),
                .volatile(0),
                .reset(1'b0),
                .has_reset(1),
                .is_rand(1),
                .individually_accessible(1)
            );

            mode = uvm_reg_field::type_id::create("mode");
            mode.configure(this, 2, 1, "RW", 0, 2'b00, 1, 1, 1);

            irq_en = uvm_reg_field::type_id::create("irq_en");
            irq_en.configure(this, 1, 3, "RW", 0, 1'b0, 1, 1, 1);

            reserved = uvm_reg_field::type_id::create("reserved");
            reserved.configure(this, 28, 4, "RO", 0, 28'b0, 1, 0, 0);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Register: STATUS_REG (offset 0x04)
    //   [0]    busy    — RO  — Module is processing
    //   [1]    error   — W1C — Error flag (write 1 to clear)
    //   [2]    done    — RO  — Operation complete
    //   [7:3]  err_code— RO  — Error code
    //   [31:8] reserved— RO
    // -----------------------------------------------------------------------
    class status_reg extends uvm_reg;
        `uvm_object_utils(status_reg)

        rand uvm_reg_field busy;
        rand uvm_reg_field error;
        rand uvm_reg_field done;
        rand uvm_reg_field err_code;
             uvm_reg_field reserved;

        function new(string name = "status_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            busy = uvm_reg_field::type_id::create("busy");
            busy.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 1);

            error = uvm_reg_field::type_id::create("error");
            error.configure(this, 1, 1, "W1C", 1, 1'b0, 1, 0, 1);

            done = uvm_reg_field::type_id::create("done");
            done.configure(this, 1, 2, "RO", 1, 1'b0, 1, 0, 1);

            err_code = uvm_reg_field::type_id::create("err_code");
            err_code.configure(this, 5, 3, "RO", 1, 5'b0, 1, 0, 1);

            reserved = uvm_reg_field::type_id::create("reserved");
            reserved.configure(this, 24, 8, "RO", 0, 24'b0, 1, 0, 0);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Register: DATA_REG (offset 0x08)
    //   [31:0] data — RW — Data register
    // -----------------------------------------------------------------------
    class data_reg extends uvm_reg;
        `uvm_object_utils(data_reg)

        rand uvm_reg_field data_field;

        function new(string name = "data_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            data_field = uvm_reg_field::type_id::create("data_field");
            data_field.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Register: IRQ_REG (offset 0x0C)
    //   [0]    tx_done  — W1C — Transmit complete interrupt
    //   [1]    rx_ready — W1C — Receive ready interrupt
    //   [2]    error    — W1C — Error interrupt
    //   [31:3] reserved — RO
    // -----------------------------------------------------------------------
    class irq_reg extends uvm_reg;
        `uvm_object_utils(irq_reg)

        rand uvm_reg_field tx_done;
        rand uvm_reg_field rx_ready;
        rand uvm_reg_field error;
             uvm_reg_field reserved;

        function new(string name = "irq_reg");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            tx_done = uvm_reg_field::type_id::create("tx_done");
            tx_done.configure(this, 1, 0, "W1C", 1, 1'b0, 1, 0, 1);

            rx_ready = uvm_reg_field::type_id::create("rx_ready");
            rx_ready.configure(this, 1, 1, "W1C", 1, 1'b0, 1, 0, 1);

            error = uvm_reg_field::type_id::create("error");
            error.configure(this, 1, 2, "W1C", 1, 1'b0, 1, 0, 1);

            reserved = uvm_reg_field::type_id::create("reserved");
            reserved.configure(this, 29, 3, "RO", 0, 29'b0, 1, 0, 0);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Register Block
    // -----------------------------------------------------------------------
    class dut_reg_block extends uvm_reg_block;
        `uvm_object_utils(dut_reg_block)

        rand ctrl_reg   ctrl;
        rand status_reg status;
        rand data_reg   data;
        rand irq_reg    irq;

        uvm_reg_map map;

        function new(string name = "dut_reg_block");
            super.new(name, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            ctrl = ctrl_reg::type_id::create("ctrl");
            ctrl.configure(this);
            ctrl.build();

            status = status_reg::type_id::create("status");
            status.configure(this);
            status.build();

            data = data_reg::type_id::create("data");
            data.configure(this);
            data.build();

            irq = irq_reg::type_id::create("irq");
            irq.configure(this);
            irq.build();

            map = create_map("map", 'h0, 4, UVM_LITTLE_ENDIAN);
            map.add_reg(ctrl,   'h00, "RW");
            map.add_reg(status, 'h04, "RO");
            map.add_reg(data,   'h08, "RW");
            map.add_reg(irq,    'h0C, "RW");

            lock_model();
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Register Access Sequences
    // -----------------------------------------------------------------------

    // Basic register configuration sequence
    class reg_config_seq extends uvm_sequence;
        `uvm_object_utils(reg_config_seq)

        dut_reg_block reg_model;

        function new(string name = "reg_config_seq");
            super.new(name);
        endfunction

        virtual task body();
            uvm_status_e   status;
            uvm_reg_data_t rdata;

            `uvm_info("REG_CFG", "Starting register configuration", UVM_LOW)

            // Write CTRL register: enable=1, mode=10 (high), irq_en=1
            reg_model.ctrl.write(status, 32'h0000_000D);
            if (status != UVM_IS_OK)
                `uvm_error("REG_CFG", "CTRL write failed")

            // Read back and verify
            reg_model.ctrl.read(status, rdata);
            `uvm_info("REG_CFG", $sformatf("CTRL readback: 0x%08h", rdata), UVM_MEDIUM)

            // Field-level access
            reg_model.ctrl.enable.set(1);
            reg_model.ctrl.mode.set(2'b01);    // Switch to low mode
            reg_model.ctrl.update(status);
            `uvm_info("REG_CFG", "CTRL updated via field-level access", UVM_MEDIUM)

            // Read STATUS register
            reg_model.status.read(status, rdata);
            `uvm_info("REG_CFG", $sformatf("STATUS: busy=%0b done=%0b error=%0b err_code=%0d",
                      rdata[0], rdata[2], rdata[1], rdata[7:3]), UVM_MEDIUM)

            // Write DATA register
            reg_model.data.write(status, 32'hDEAD_BEEF);

            // Mirror check — reads the hardware and compares with model
            reg_model.data.mirror(status, UVM_CHECK);

            // Clear interrupts by writing 1 to W1C fields
            reg_model.irq.write(status, 32'h0000_0007);  // Clear all IRQ flags

            `uvm_info("REG_CFG", "Register configuration complete", UVM_LOW)
        endtask
    endclass

    // Register reset verification sequence
    class reg_reset_seq extends uvm_sequence;
        `uvm_object_utils(reg_reset_seq)

        dut_reg_block reg_model;

        function new(string name = "reg_reset_seq");
            super.new(name);
        endfunction

        virtual task body();
            uvm_status_e   status;
            uvm_reg_data_t rdata;
            uvm_reg        regs[$];
            string         reg_name;

            `uvm_info("RST_CHK", "Verifying reset values", UVM_LOW)

            reg_model.get_registers(regs);

            foreach (regs[i]) begin
                regs[i].read(status, rdata);
                reg_name = regs[i].get_name();

                if (rdata == regs[i].get_reset()) begin
                    `uvm_info("RST_CHK", $sformatf(
                        "%s: reset value 0x%08h — PASS", reg_name, rdata), UVM_MEDIUM)
                end else begin
                    `uvm_error("RST_CHK", $sformatf(
                        "%s: expected 0x%08h, got 0x%08h — FAIL",
                        reg_name, regs[i].get_reset(), rdata))
                end
            end

            `uvm_info("RST_CHK", "Reset verification complete", UVM_LOW)
        endtask
    endclass

endpackage
