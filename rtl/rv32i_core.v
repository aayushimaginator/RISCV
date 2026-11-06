`default_nettype none

// -----------------------------------------------------------------------------
// rv32i_core
//
// Single-cycle RV32I core.
//
// Every instruction completes in one clock cycle.
// Instruction and data memories have combinational reads and clocked writes.
//
// No pipeline.
// No stalls.
// -----------------------------------------------------------------------------

module rv32i_core #(
    parameter RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        resetn,

    // Instruction memory interface
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Data memory interface
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    output wire        dmem_re,
    input  wire [31:0] dmem_rdata,

    // Status
    output reg         halted
);

    // -------------------------------------------------------------------------
    // Internal state
    // -------------------------------------------------------------------------

    reg [31:0] pc;

    // -------------------------------------------------------------------------
    // Decoder signals
    // -------------------------------------------------------------------------

    wire        reg_write;
    wire        a_sel;
    wire        b_sel;
    wire [3:0]  alu_op;
    wire        mem_read;
    wire        mem_write;
    wire [1:0]  wb_sel;
    wire        is_branch;
    wire        is_jal;
    wire        is_jalr;
    wire        halt;

    // -------------------------------------------------------------------------
    // Immediate generator signals
    // -------------------------------------------------------------------------

    wire [31:0] imm;

    // -------------------------------------------------------------------------
    // Register file signals
    // -------------------------------------------------------------------------

    wire [31:0] instr = imem_rdata;

    wire [4:0]  rs1_addr = instr[19:15];
    wire [4:0]  rs2_addr = instr[24:20];
    wire [4:0]  rd_addr  = instr[11:7];

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    wire [31:0] reg_wdata;

    // -------------------------------------------------------------------------
    // ALU signals
    // -------------------------------------------------------------------------

    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_result;

    // -------------------------------------------------------------------------
    // Branch comparator signals
    // -------------------------------------------------------------------------

    wire        branch_taken;
    wire        taken;

    // -------------------------------------------------------------------------
    // LSU signals
    // -------------------------------------------------------------------------

    wire [31:0] load_data;
    wire [31:0] lsu_wdata_out;
    wire [3:0]  lsu_wstrb;

    // -------------------------------------------------------------------------
    // Next PC signals
    // -------------------------------------------------------------------------

    wire [31:0] pc_plus_4;
    wire [31:0] pc_plus_imm;
    reg  [31:0] next_pc;

    // -------------------------------------------------------------------------
    // Instruction fetch
    // -------------------------------------------------------------------------

    assign imem_addr = pc;


    // -------------------------------------------------------------------------
    // Module instantiations
    // -------------------------------------------------------------------------

    rv32i_decoder u_dec (
        .instr     (instr),
        .reg_write (reg_write),
        .a_sel     (a_sel),
        .b_sel     (b_sel),
        .alu_op    (alu_op),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .wb_sel    (wb_sel),
        .is_branch (is_branch),
        .is_jal    (is_jal),
        .is_jalr   (is_jalr),
        .halt      (halt)
    );

    rv32i_immgen u_imm (
        .instr (instr),
        .imm   (imm)
    );

    rv32i_regfile u_regfile (
        .clk    (clk),
        .we     (reg_write && resetn),
        .raddr1 (rs1_addr),
        .raddr2 (rs2_addr),
        .waddr  (rd_addr),
        .wdata  (reg_wdata),
        .rdata1 (rs1_data),
        .rdata2 (rs2_data)
    );

    assign alu_a = a_sel ? pc : rs1_data;
    assign alu_b = b_sel ? imm : rs2_data;

    rv32i_alu u_alu (
        .a  (alu_a),
        .b  (alu_b),
        .op (alu_op),
        .y  (alu_result)
    );

    rv32i_branch_cmp u_br (
        .a      (rs1_data),
        .b      (rs2_data),
        .funct3 (instr[14:12]),
        .taken  (taken)
    );

    assign branch_taken = is_branch & taken;

    rv32i_lsu u_lsu (
        .rdata_word (dmem_rdata),
        .addr_lo    (alu_result[1:0]),
        .funct3     (instr[14:12]),
        .load_data  (load_data),
        .store_data (rs2_data),
        .mem_write  (mem_write),
        .wdata_out  (lsu_wdata_out),
        .wstrb      (lsu_wstrb)
    );

    // -------------------------------------------------------------------------
    // Data memory outputs
    // -------------------------------------------------------------------------

    assign dmem_addr  = alu_result;
    assign dmem_wdata = lsu_wdata_out;
    assign dmem_wstrb = lsu_wstrb;
    assign dmem_re    = mem_read;

    // -------------------------------------------------------------------------
    // Register writeback mux
    // -------------------------------------------------------------------------

    assign pc_plus_4 = pc + 32'd4;

    assign reg_wdata =
        (wb_sel == 2'b00) ? alu_result :
        (wb_sel == 2'b01) ? load_data :
        (wb_sel == 2'b10) ? pc_plus_4 :
                            imm;

    // -------------------------------------------------------------------------
    // Next PC logic
    // -------------------------------------------------------------------------

    assign pc_plus_imm = pc + imm;

    always @* begin
        if (halt) begin
            next_pc = pc;
        end
        else if (is_jalr) begin
            next_pc = {alu_result[31:1], 1'b0};
        end
        else if (is_jal || branch_taken) begin
            next_pc = pc_plus_imm;
        end
        else begin
            next_pc = pc_plus_4;
        end
    end

    // -------------------------------------------------------------------------
    // Sequential logic
    // -------------------------------------------------------------------------

    always @(posedge clk) begin
        if (!resetn) begin
            pc     <= RESET_PC;
            halted <= 1'b0;
        end
        else begin
            pc     <= next_pc;
            halted <= halted | halt;
        end
    end

endmodule

`default_nettype wire
