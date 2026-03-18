// ----------------------------------------------------------------------------
// 5-Stage Instruction Pipeline (Simplified RISC Processor Core)
// Demonstrates: classic IF/ID/EX/MEM/WB pipeline, data forwarding,
//               hazard detection, pipeline stalls and flushes
// ----------------------------------------------------------------------------

module instruction_pipeline #(
    parameter int XLEN      = 32,
    parameter int REG_COUNT = 32,
    parameter int IMEM_DEPTH = 256,
    parameter int DMEM_DEPTH = 256
)(
    input  logic        clk,
    input  logic        rst_n,
    output logic [XLEN-1:0] debug_pc,
    output logic        pipeline_stall
);

    localparam int REG_ADDR_W = $clog2(REG_COUNT);

    // Instruction encoding (simplified)
    typedef enum logic [3:0] {
        OP_ADD   = 4'h0,
        OP_SUB   = 4'h1,
        OP_AND   = 4'h2,
        OP_OR    = 4'h3,
        OP_LW    = 4'h4,
        OP_SW    = 4'h5,
        OP_BEQ   = 4'h6,
        OP_NOP   = 4'hF
    } opcode_t;

    // ===== Pipeline Registers =====

    // IF/ID
    typedef struct packed {
        logic [XLEN-1:0]       pc;
        logic [XLEN-1:0]       instruction;
        logic                  valid;
    } if_id_reg_t;

    // ID/EX
    typedef struct packed {
        logic [XLEN-1:0]       pc;
        opcode_t               opcode;
        logic [XLEN-1:0]       rs1_data;
        logic [XLEN-1:0]       rs2_data;
        logic [REG_ADDR_W-1:0] rd_addr;
        logic [REG_ADDR_W-1:0] rs1_addr;
        logic [REG_ADDR_W-1:0] rs2_addr;
        logic [XLEN-1:0]       immediate;
        logic                  reg_write;
        logic                  mem_read;
        logic                  mem_write;
        logic                  valid;
    } id_ex_reg_t;

    // EX/MEM
    typedef struct packed {
        logic [XLEN-1:0]       alu_result;
        logic [XLEN-1:0]       rs2_data;
        logic [REG_ADDR_W-1:0] rd_addr;
        logic                  reg_write;
        logic                  mem_read;
        logic                  mem_write;
        logic                  valid;
    } ex_mem_reg_t;

    // MEM/WB
    typedef struct packed {
        logic [XLEN-1:0]       result;
        logic [REG_ADDR_W-1:0] rd_addr;
        logic                  reg_write;
        logic                  valid;
    } mem_wb_reg_t;

    if_id_reg_t  if_id, if_id_next;
    id_ex_reg_t  id_ex, id_ex_next;
    ex_mem_reg_t ex_mem, ex_mem_next;
    mem_wb_reg_t mem_wb, mem_wb_next;

    // ===== Memories & Register File =====
    logic [XLEN-1:0] imem [IMEM_DEPTH];
    logic [XLEN-1:0] dmem [DMEM_DEPTH];
    logic [XLEN-1:0] regfile [REG_COUNT];

    logic [XLEN-1:0] pc, pc_next;

    // ===== Hazard Detection =====
    logic stall_pipeline;
    logic flush_pipeline;

    // Load-use hazard: stall when EX stage has a load whose destination
    // is a source in the ID stage
    assign stall_pipeline = id_ex.valid && id_ex.mem_read &&
        ((id_ex.rd_addr == if_id.instruction[19:15]) ||
         (id_ex.rd_addr == if_id.instruction[24:20])) &&
        (id_ex.rd_addr != '0);

    assign pipeline_stall = stall_pipeline;
    assign debug_pc = pc;

    // ===== Data Forwarding Logic =====
    logic [XLEN-1:0] forwarded_rs1, forwarded_rs2;
    logic [REG_ADDR_W-1:0] id_rs1_addr, id_rs2_addr;

    assign id_rs1_addr = if_id.instruction[19:15];
    assign id_rs2_addr = if_id.instruction[24:20];

    always_comb begin
        // Default: read from register file
        forwarded_rs1 = regfile[id_rs1_addr];
        forwarded_rs2 = regfile[id_rs2_addr];

        // Forward from EX/MEM stage
        if (ex_mem.valid && ex_mem.reg_write &&
            ex_mem.rd_addr != '0 && ex_mem.rd_addr == id_rs1_addr)
            forwarded_rs1 = ex_mem.alu_result;

        if (ex_mem.valid && ex_mem.reg_write &&
            ex_mem.rd_addr != '0 && ex_mem.rd_addr == id_rs2_addr)
            forwarded_rs2 = ex_mem.alu_result;

        // Forward from MEM/WB stage (lower priority)
        if (mem_wb.valid && mem_wb.reg_write &&
            mem_wb.rd_addr != '0 && mem_wb.rd_addr == id_rs1_addr &&
            !(ex_mem.valid && ex_mem.reg_write && ex_mem.rd_addr == id_rs1_addr))
            forwarded_rs1 = mem_wb.result;

        if (mem_wb.valid && mem_wb.reg_write &&
            mem_wb.rd_addr != '0 && mem_wb.rd_addr == id_rs2_addr &&
            !(ex_mem.valid && ex_mem.reg_write && ex_mem.rd_addr == id_rs2_addr))
            forwarded_rs2 = mem_wb.result;
    end

    // ===== Stage 1: Instruction Fetch =====
    always_comb begin
        if (stall_pipeline)
            pc_next = pc;
        else if (flush_pipeline)
            pc_next = id_ex.pc + id_ex.immediate;  // Branch target
        else
            pc_next = pc + 4;
    end

    // ===== Stage 2: Decode =====
    always_comb begin
        id_ex_next = '0;
        if (if_id.valid && !stall_pipeline) begin
            id_ex_next.pc        = if_id.pc;
            id_ex_next.opcode    = opcode_t'(if_id.instruction[31:28]);
            id_ex_next.rs1_addr  = if_id.instruction[19:15];
            id_ex_next.rs2_addr  = if_id.instruction[24:20];
            id_ex_next.rd_addr   = if_id.instruction[11:7];
            id_ex_next.rs1_data  = forwarded_rs1;
            id_ex_next.rs2_data  = forwarded_rs2;
            id_ex_next.immediate = {{(XLEN-12){if_id.instruction[31]}}, if_id.instruction[31:20]};
            id_ex_next.valid     = !flush_pipeline;

            case (opcode_t'(if_id.instruction[31:28]))
                OP_ADD, OP_SUB, OP_AND, OP_OR: id_ex_next.reg_write = 1'b1;
                OP_LW:  begin id_ex_next.reg_write = 1'b1; id_ex_next.mem_read = 1'b1; end
                OP_SW:  id_ex_next.mem_write = 1'b1;
                default: ;
            endcase
        end
    end

    // ===== Stage 3: Execute =====
    always_comb begin
        ex_mem_next = '0;
        flush_pipeline = 1'b0;

        if (id_ex.valid) begin
            ex_mem_next.rd_addr   = id_ex.rd_addr;
            ex_mem_next.rs2_data  = id_ex.rs2_data;
            ex_mem_next.reg_write = id_ex.reg_write;
            ex_mem_next.mem_read  = id_ex.mem_read;
            ex_mem_next.mem_write = id_ex.mem_write;
            ex_mem_next.valid     = 1'b1;

            case (id_ex.opcode)
                OP_ADD: ex_mem_next.alu_result = id_ex.rs1_data + id_ex.rs2_data;
                OP_SUB: ex_mem_next.alu_result = id_ex.rs1_data - id_ex.rs2_data;
                OP_AND: ex_mem_next.alu_result = id_ex.rs1_data & id_ex.rs2_data;
                OP_OR:  ex_mem_next.alu_result = id_ex.rs1_data | id_ex.rs2_data;
                OP_LW:  ex_mem_next.alu_result = id_ex.rs1_data + id_ex.immediate;
                OP_SW:  ex_mem_next.alu_result = id_ex.rs1_data + id_ex.immediate;
                OP_BEQ: begin
                    if (id_ex.rs1_data == id_ex.rs2_data)
                        flush_pipeline = 1'b1;
                    ex_mem_next.valid = 1'b0;
                end
                default: ;
            endcase
        end
    end

    // ===== Stage 4: Memory Access =====
    always_comb begin
        mem_wb_next = '0;
        if (ex_mem.valid) begin
            mem_wb_next.rd_addr   = ex_mem.rd_addr;
            mem_wb_next.reg_write = ex_mem.reg_write;
            mem_wb_next.valid     = 1'b1;

            if (ex_mem.mem_read)
                mem_wb_next.result = dmem[ex_mem.alu_result[$clog2(DMEM_DEPTH)+1:2]];
            else
                mem_wb_next.result = ex_mem.alu_result;
        end
    end

    // ===== Pipeline Register Updates =====
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc     <= '0;
            if_id  <= '0;
            id_ex  <= '0;
            ex_mem <= '0;
            mem_wb <= '0;
        end else begin
            pc <= pc_next;

            // IF/ID: stall holds, flush clears
            if (!stall_pipeline) begin
                if_id.pc          <= pc;
                if_id.instruction <= imem[pc[$clog2(IMEM_DEPTH)+1:2]];
                if_id.valid       <= !flush_pipeline;
            end

            // ID/EX
            if (stall_pipeline)
                id_ex <= '0;  // Insert bubble
            else
                id_ex <= id_ex_next;

            // EX/MEM and MEM/WB always advance
            ex_mem <= ex_mem_next;
            mem_wb <= mem_wb_next;

            // Stage 5: Write Back
            if (mem_wb.valid && mem_wb.reg_write && mem_wb.rd_addr != '0)
                regfile[mem_wb.rd_addr] <= mem_wb.result;

            // Memory write
            if (ex_mem.valid && ex_mem.mem_write)
                dmem[ex_mem.alu_result[$clog2(DMEM_DEPTH)+1:2]] <= ex_mem.rs2_data;
        end
    end

endmodule
