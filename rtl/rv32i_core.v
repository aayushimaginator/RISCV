`default_nettype none

module rv32i_core #(
    parameter RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        resetn,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    output wire        dmem_re,
    input  wire [31:0] dmem_rdata,

    output reg         halted
);

    // =========================================================================
    // Pipeline Registers
    // =========================================================================
    reg [31:0] pc;
    reg [31:0] if_id_instr;
    reg [31:0] if_id_pc;
    reg        if_id_valid;

    reg [31:0] s1_alu_result;
    reg [31:0] s1_pc_plus_4;
    reg [31:0] s1_rs2_data;
    reg [ 4:0] s1_rd_addr;
    reg [ 2:0] s1_funct3;
    reg        s1_reg_write;
    reg        s1_mem_read;
    reg        s1_mem_write;
    reg [ 1:0] s1_wb_sel;
    reg [31:0] s1_imm;
    reg        s1_valid;

    // =========================================================================
    // Stage 1: Fetch, Decode, Execute
    // =========================================================================
    assign imem_addr = pc;

    wire        dec_reg_write, dec_a_sel, dec_b_sel, dec_mem_read, dec_mem_write;
    wire        dec_is_branch, dec_is_jal, dec_is_jalr, dec_halt;
    wire [3:0]  dec_alu_op;
    wire [1:0]  dec_wb_sel;

    rv32i_decoder u_dec (
        .instr(if_id_instr), .reg_write(dec_reg_write), .a_sel(dec_a_sel),
        .b_sel(dec_b_sel), .alu_op(dec_alu_op), .mem_read(dec_mem_read),
        .mem_write(dec_mem_write), .wb_sel(dec_wb_sel), .is_branch(dec_is_branch),
        .is_jal(dec_is_jal), .is_jalr(dec_is_jalr), .halt(dec_halt)
    );

    wire [4:0] dec_rs1_addr = if_id_instr[19:15];
    wire [4:0] dec_rs2_addr = if_id_instr[24:20];
    wire [4:0] dec_rd_addr  = if_id_instr[11:7];
    wire [2:0] dec_funct3   = if_id_instr[14:12];

    wire [31:0] imm;
    rv32i_immgen u_imm (.instr(if_id_instr), .imm(imm));

    wire [31:0] rs1_data_raw, rs2_data_raw;
    wire [31:0] s2_wb_data; 

    wire fwd_rs1 = s1_valid && s1_reg_write && (s1_rd_addr != 0) && (s1_rd_addr == dec_rs1_addr);
    wire fwd_rs2 = s1_valid && s1_reg_write && (s1_rd_addr != 0) && (s1_rd_addr == dec_rs2_addr);

    wire [31:0] fwd_rs1_data = (fwd_rs1 && !s1_mem_read) ? s2_wb_data : rs1_data_raw;
    wire [31:0] fwd_rs2_data = (fwd_rs2 && !s1_mem_read) ? s2_wb_data : rs2_data_raw;

    wire [31:0] alu_a = dec_a_sel ? if_id_pc : fwd_rs1_data;
    wire [31:0] alu_b = dec_b_sel ? imm : fwd_rs2_data;

    wire [31:0] alu_result;
    rv32i_alu u_alu (.a(alu_a), .b(alu_b), .op(dec_alu_op), .y(alu_result));

    wire taken;
    rv32i_branch_cmp u_br (.a(fwd_rs1_data), .b(fwd_rs2_data), .funct3(dec_funct3), .taken(taken));

    wire is_halt = dec_halt && if_id_valid;
    wire load_use_hazard = s1_valid && s1_mem_read && (s1_rd_addr != 0) &&
                           ((s1_rd_addr == dec_rs1_addr) || (s1_rd_addr == dec_rs2_addr));

    wire stall_stage1 = load_use_hazard;
    wire stall_pc = stall_stage1 || halted || is_halt;

    wire take_branch = dec_is_branch && taken && if_id_valid && !is_halt;
    wire take_jal    = dec_is_jal && if_id_valid && !is_halt;
    wire take_jalr   = dec_is_jalr && if_id_valid && !is_halt;
    wire pc_from_branch = take_branch || take_jal || take_jalr;
    
    wire [31:0] branch_target = if_id_pc + imm;
    wire [31:0] jalr_target = {alu_result[31:1], 1'b0};
    wire [31:0] next_pc = take_jalr ? jalr_target :
                          (take_branch || take_jal) ? branch_target : (pc + 32'd4);

    wire flush_if_id = pc_from_branch && !stall_stage1;

    // =========================================================================
    // Stage 2: Memory, Writeback
    // =========================================================================
    wire [31:0] lsu_load_data, lsu_wdata_out;
    wire [3:0]  lsu_wstrb;

    rv32i_lsu u_lsu (
        .rdata_word(dmem_rdata), .addr_lo(s1_alu_result[1:0]), .funct3(s1_funct3),
        .load_data(lsu_load_data), .store_data(s1_rs2_data), .mem_write(s1_mem_write),
        .wdata_out(lsu_wdata_out), .wstrb(lsu_wstrb)
    );

    assign dmem_addr  = s1_alu_result;
    assign dmem_wdata = lsu_wdata_out;
    assign dmem_wstrb = s1_valid ? lsu_wstrb : 4'b0000;
    assign dmem_re    = s1_valid && s1_mem_read;

    assign s2_wb_data = (s1_wb_sel == 2'b00) ? s1_alu_result :
                        (s1_wb_sel == 2'b01) ? lsu_load_data :
                        (s1_wb_sel == 2'b10) ? s1_pc_plus_4 : s1_imm;

    rv32i_regfile u_regfile (
        .clk(clk), .we(s1_valid && s1_reg_write),
        .raddr1(dec_rs1_addr), .raddr2(dec_rs2_addr), .waddr(s1_rd_addr),
        .wdata(s2_wb_data), .rdata1(rs1_data_raw), .rdata2(rs2_data_raw)
    );

    // =========================================================================
    // Sequential Logic
    // =========================================================================
    always @(posedge clk) begin
        if (!resetn) begin
            pc <= RESET_PC; if_id_instr <= 32'h0000_0013; if_id_pc <= RESET_PC; if_id_valid <= 1'b0;
            s1_valid <= 1'b0; s1_reg_write <= 1'b0; s1_mem_read <= 1'b0; s1_mem_write <= 1'b0; halted <= 1'b0;
        end else begin
            if (is_halt && !stall_stage1) halted <= 1'b1;

            if (!stall_pc) begin
                if (is_halt) begin
                    // CRITICAL FIX: Roll back PC to the halting instruction
                    pc <= if_id_pc; 
                    if_id_instr <= 32'h0000_0013;
                    if_id_valid <= 1'b0;
                end else begin
                    pc <= next_pc;
                    if (flush_if_id) begin
                        if_id_instr <= 32'h0000_0013; if_id_valid <= 1'b0;
                    end else begin
                        if_id_instr <= imem_rdata; if_id_pc <= pc; if_id_valid <= 1'b1;
                    end
                end
            end

            if (!stall_stage1) begin
                if (if_id_valid && !is_halt) begin
                    s1_alu_result <= alu_result; s1_pc_plus_4 <= if_id_pc + 32'd4;
                    s1_rs2_data <= fwd_rs2_data; s1_rd_addr <= dec_rd_addr; s1_funct3 <= dec_funct3;
                    s1_reg_write <= dec_reg_write; s1_mem_read <= dec_mem_read;
                    s1_mem_write <= dec_mem_write; s1_wb_sel <= dec_wb_sel; s1_imm <= imm; s1_valid <= 1'b1;
                end else begin
                    s1_valid <= 1'b0; s1_reg_write <= 1'b0; s1_mem_read <= 1'b0; s1_mem_write <= 1'b0;
                end
            end else begin
                s1_valid <= 1'b0; s1_reg_write <= 1'b0; s1_mem_read <= 1'b0; s1_mem_write <= 1'b0;
            end
        end
    end
endmodule
`default_nettype wire
