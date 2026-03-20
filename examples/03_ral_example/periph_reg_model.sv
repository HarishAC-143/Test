// Control Register
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field irq_en;
  rand uvm_reg_field reserved;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    enable = uvm_reg_field::type_id::create("enable");
    enable.configure(this, 1, 0, "RW", 0, 1'h0, 1, 1, 0);

    mode = uvm_reg_field::type_id::create("mode");
    mode.configure(this, 2, 1, "RW", 0, 2'h0, 1, 1, 0);

    irq_en = uvm_reg_field::type_id::create("irq_en");
    irq_en.configure(this, 1, 3, "RW", 0, 1'h0, 1, 1, 0);

    reserved = uvm_reg_field::type_id::create("reserved");
    reserved.configure(this, 28, 4, "RO", 0, 28'h0, 1, 0, 0);
  endfunction
endclass

// Status Register
class status_reg extends uvm_reg;
  `uvm_object_utils(status_reg)

  rand uvm_reg_field busy;
  rand uvm_reg_field done;
  rand uvm_reg_field error;

  function new(string name = "status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    busy = uvm_reg_field::type_id::create("busy");
    busy.configure(this, 1, 0, "RO", 1, 1'h0, 1, 0, 0);

    done = uvm_reg_field::type_id::create("done");
    done.configure(this, 1, 1, "RO", 1, 1'h0, 1, 0, 0);

    error = uvm_reg_field::type_id::create("error");
    error.configure(this, 1, 2, "RO", 1, 1'h0, 1, 0, 0);
  endfunction
endclass

// Data Input Register
class data_in_reg extends uvm_reg;
  `uvm_object_utils(data_in_reg)

  rand uvm_reg_field data;

  function new(string name = "data_in_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 0);
  endfunction
endclass

// Data Output Register
class data_out_reg extends uvm_reg;
  `uvm_object_utils(data_out_reg)

  rand uvm_reg_field data;

  function new(string name = "data_out_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 32, 0, "RO", 1, 32'h0, 1, 0, 0);
  endfunction
endclass

// Interrupt Status Register
class irq_status_reg extends uvm_reg;
  `uvm_object_utils(irq_status_reg)

  rand uvm_reg_field irq_pending;

  function new(string name = "irq_status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    irq_pending = uvm_reg_field::type_id::create("irq_pending");
    irq_pending.configure(this, 32, 0, "W1C", 1, 32'h0, 1, 1, 0);
  endfunction
endclass

// Register Block — the complete register model
class periph_reg_block extends uvm_reg_block;
  `uvm_object_utils(periph_reg_block)

  rand ctrl_reg       CTRL;
  rand status_reg     STATUS;
  rand data_in_reg    DATA_IN;
  rand data_out_reg   DATA_OUT;
  rand irq_status_reg IRQ_STATUS;

  uvm_reg_map default_map;

  function new(string name = "periph_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    CTRL = ctrl_reg::type_id::create("CTRL");
    CTRL.build();
    CTRL.configure(this);

    STATUS = status_reg::type_id::create("STATUS");
    STATUS.build();
    STATUS.configure(this);

    DATA_IN = data_in_reg::type_id::create("DATA_IN");
    DATA_IN.build();
    DATA_IN.configure(this);

    DATA_OUT = data_out_reg::type_id::create("DATA_OUT");
    DATA_OUT.build();
    DATA_OUT.configure(this);

    IRQ_STATUS = irq_status_reg::type_id::create("IRQ_STATUS");
    IRQ_STATUS.build();
    IRQ_STATUS.configure(this);

    default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);
    default_map.add_reg(CTRL,       'h00, "RW");
    default_map.add_reg(STATUS,     'h04, "RO");
    default_map.add_reg(DATA_IN,    'h08, "RW");
    default_map.add_reg(DATA_OUT,   'h0C, "RO");
    default_map.add_reg(IRQ_STATUS, 'h10, "RW");

    lock_model();
  endfunction
endclass
