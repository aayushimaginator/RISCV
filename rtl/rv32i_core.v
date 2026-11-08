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
    // Pipeline registers:  IF/EX  |  EX/MEM  |  MEM/WB
    // =========================================================================

    // IF/EX
    reg [31:0] pc;
    reg [31:0] if_ex_instr;
    reg [31:0] if_ex_pc;
    reg        if_ex_valid;

    // EX/MEM
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_pc_plus_4;
    reg [31:0] ex_mem_rs2_data;
    reg [ 4:0] ex_mem_rd;
    reg [ 2:0] ex_mem_funct3;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg [ 1:0] ex_mem_wb_sel;
    reg [31:0] ex_mem_imm;
    reg        ex_mem_valid;

    // MEM/WB   (load data is captured HERE, at the end of MEM)
    reg [31:0] mem_wb_data;
    reg [ 4:0] mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_valid;

    // Halt control
    reg        halt_requested;

    // =========================================================================
    // IF stage
    // =========================================================================
    assign imem_addr = pc;

    // =========================================================================
    // EX stage: decode, regfile read, forwarding, ALU, branch/jump resolve
    // =========================================================================
    wire [31:0] ex_instr = if_ex_instr;
    wire [31:0] ex_pc    = if_ex_pc;

    wire        dec_reg_write, dec_a_sel, dec_b_sel, dec_mem_read, dec_mem_write;
    wire        dec_is_branch, dec_is_jal, dec_is_jalr, dec_halt;
    wire [3:0]  dec_alu_op;
    wire [1:0]  dec_wb_sel;

    rv32i_decoder u_dec (
        .instr     (ex_instr),
        .reg_write (dec_reg_write),
        .a_sel     (dec_a_sel),
        .b_sel     (dec_b_sel),
        .alu_op    (dec_alu_op),
        .mem_read  (dec_mem_read),
        .mem_write (dec_mem_write),
        .wb_sel    (dec_wb_sel),
        .is_branch (dec_is_branch),
        .is_jal    (dec_is_jal),
        .is_jalr   (dec_is_jalr),
        .halt      (dec_halt)
    );

    wire [4:0] ex_rs1_addr = ex_instr[19:15];
    wire [4:0] ex_rs2_addr = ex_instr[24:20];
    wire [4:0] ex_rd_addr  = ex_instr[11:7];
    wire [2:0] ex_funct3   = ex_instr[14:12];
    wire [6:0] ex_opcode   = ex_instr[6:0];

    wire [31:0] ex_imm;
    rv32i_immgen u_imm (.instr(ex_instr), .imm(ex_imm));

    // Register-file read ports (write port is in WB, below)
    wire [31:0] rs1_data_rf;
    wire [31:0] rs2_data_rf;

    // Which source registers does the EX instruction actually read?
    wire ex_uses_rs1 = (ex_opcode != 7'b0110111) &&   // not LUI
                       (ex_opcode != 7'b0010111) &&   // not AUIPC
                       (ex_opcode != 7'b1101111);     // not JAL
    wire ex_uses_rs2 = (ex_opcode == 7'b0110011) ||   // R-type
                       (ex_opcode == 7'b0100011) ||   // Store
                       (ex_opcode == 7'b1100011);     // Branch

    // -------------------------------------------------------------------------
    // Forwarding sources (RULE 1: registers only, never combinational dmem)
    // -------------------------------------------------------------------------
    // MEM-stage forward = ALU / PC+4 / IMM result (never used for loads)
    wire [31:0] mem_fwd_data = (ex_mem_wb_sel == 2'b00) ? ex_mem_alu_result :
                               (ex_mem_wb_sel == 2'b10) ? ex_mem_pc_plus_4 :
                                                          ex_mem_imm;

    wire fwd_mem_rs1 = ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
                       (ex_mem_rd != 5'd0) && (ex_mem_rd == ex_rs1_addr);
    wire fwd_mem_rs2 = ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
                       (ex_mem_rd != 5'd0) && (ex_mem_rd == ex_rs2_addr);

    // WB-stage forward = the registered writeback value (includes loads)
    wire fwd_wb_rs1 = mem_wb_valid && mem_wb_reg_write &&
                      (mem_wb_rd != 5'd0) && (mem_wb_rd == ex_rs1_addr);
    wire fwd_wb_rs2 = mem_wb_valid && mem_wb_reg_write &&
                      (mem_wb_rd != 5'd0) && (mem_wb_rd == ex_rs2_addr);

    // Priority: MEM (younger) > WB (older) > regfile
    wire [31:0] rs1_data = fwd_mem_rs1 ? mem_fwd_data :
                           fwd_wb_rs1  ? mem_wb_data  : rs1_data_rf;
    wire [31:0] rs2_data = fwd_mem_rs2 ? mem_fwd_data :
                           fwd_wb_rs2  ? mem_wb_data  : rs2_data_rf;

    // -------------------------------------------------------------------------
    // Hazard / stall
    // -------------------------------------------------------------------------
    wire ex_halt = dec_halt && if_ex_valid;

    // RULE 3: load-use -> exactly one stall, then forward from WB next cycle
    wire load_use_hazard = if_ex_valid && !ex_halt &&
                           ex_mem_valid && ex_mem_mem_read && (ex_mem_rd != 5'd0) &&
                           ((ex_uses_rs1 && (ex_mem_rd == ex_rs1_addr)) ||
                            (ex_uses_rs2 && (ex_mem_rd == ex_rs2_addr)));

    wire stall = load_use_hazard;

    // -------------------------------------------------------------------------
    // ALU + branch comparator (RULE 4: resolve in EX)
    // -------------------------------------------------------------------------
    wire [31:0] alu_a = dec_a_sel ? ex_pc : rs1_data;
    wire [31:0] alu_b = dec_b_sel ? ex_imm : rs2_data;

    wire [31:0] alu_result;
    rv32i_alu u_alu (.a(alu_a), .b(alu_b), .op(dec_alu_op), .y(alu_result));

    wire branch_taken;
    rv32i_branch_cmp u_br (.a(rs1_data), .b(rs2_data),
                           .funct3(ex_funct3), .taken(branch_taken));

    wire take_branch = dec_is_branch && branch_taken && if_ex_valid && !ex_halt && !stall;
    wire take_jal    = dec_is_jal    && if_ex_valid && !ex_halt && !stall;
    wire take_jalr   = dec_is_jalr   && if_ex_valid && !ex_halt && !stall;
    wire redirect    = take_branch || take_jal || take_jalr;

    wire [31:0] branch_target = ex_pc + ex_imm;
    wire [31:0] jalr_target   = {alu_result[31:1], 1'b0};
    wire [31:0] next_pc       = take_jalr                 ? jalr_target   :
                                (take_branch || take_jal) ? branch_target :
                                                            (pc + 32'd4);

    // =========================================================================
    // MEM stage: dmem access, address/wstrb/wdata all from EX/MEM registers
    // =========================================================================
    assign dmem_addr  = ex_mem_alu_result;
    assign dmem_re    = ex_mem_valid && ex_mem_mem_read;

    wire [31:0] lsu_load_data;
    wire [31:0] lsu_wdata_out;
    wire [3:0]  lsu_wstrb;

    rv32i_lsu u_lsu (
        .rdata_word (dmem_rdata),
        .addr_lo    (ex_mem_alu_result[1:0]),
        .funct3     (ex_mem_funct3),
        .load_data  (lsu_load_data),
        .store_data (ex_mem_rs2_data),
        .mem_write  (ex_mem_mem_write),
        .wdata_out  (lsu_wdata_out),
        .wstrb      (lsu_wstrb)
    );

    assign dmem_wdata = lsu_wdata_out;
    // RULE 6: no store can fire from a flushed/invalid MEM slot
    assign dmem_wstrb = ex_mem_valid ? lsu_wstrb : 4'b0000;

    // RULE 2: capture the final writeback value at the END of MEM.
    wire [31:0] mem_wb_data_next = (ex_mem_wb_sel == 2'b01) ? lsu_load_data    :
                                   (ex_mem_wb_sel == 2'b00) ? ex_mem_alu_result :
                                   (ex_mem_wb_sel == 2'b10) ? ex_mem_pc_plus_4  :
                                                              ex_mem_imm;

    // =========================================================================
    // WB stage: register-file write
    // =========================================================================
    wire wb_we = mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0);

    rv32i_regfile u_regfile (
        .clk    (clk),
        .we     (wb_we),
        .raddr1 (ex_rs1_addr),
        .raddr2 (ex_rs2_addr),
        .waddr  (mem_wb_rd),
        .wdata  (mem_wb_data),
        .rdata1 (rs1_data_rf),
        .rdata2 (rs2_data_rf)
    );

    // =========================================================================
    // Halt control (RULE 5)
    // =========================================================================
    wire halt_now       = ex_halt && !stall;
    wire halt_active    = halt_requested || halt_now;
    wire pipeline_empty = !if_ex_valid && !ex_mem_valid && !mem_wb_valid;
    wire halt_done      = halt_requested && pipeline_empty;

    // =========================================================================
    // Sequential logic
    // =========================================================================
    always @(posedge clk) begin
        if (!resetn) begin
            pc             <= RESET_PC;
            if_ex_valid    <= 1'b0;
            ex_mem_valid   <= 1'b0;
            mem_wb_valid   <= 1'b0;
            halted         <= 1'b0;
            halt_requested <= 1'b0;
        end
        else begin
            // halt only after MEM and WB have fully drained
            if (halt_done) begin
                halted <= 1'b1;
            end

            if (halt_now) begin
                halt_requested <= 1'b1;
            end

            // ------------------------------------------------------------
            // IF -> IF/EX
            // ------------------------------------------------------------
            if (halt_now) begin
                // roll PC back to the halting instruction so the dump matches the ISS
                pc          <= if_ex_pc;
                if_ex_valid <= 1'b0;
            end
            else if (!stall && !halt_active) begin
                pc <= next_pc;
                if (redirect) begin
                    // RULE 4: taken branch/jump flushes the fetched instruction
                    if_ex_valid <= 1'b0;
                end
                else begin
                    if_ex_instr <= imem_rdata;
                    if_ex_pc    <= pc;
                    if_ex_valid <= 1'b1;
                end
            end
            else if (halt_active) begin
                if_ex_valid <= 1'b0;
            end
            // else: load-use stall -> hold pc and if_ex

            // ------------------------------------------------------------
            // EX -> EX/MEM
            // ------------------------------------------------------------
            if (!stall) begin
                if (if_ex_valid && !ex_halt) begin
                    ex_mem_alu_result <= alu_result;
                    ex_mem_pc_plus_4  <= ex_pc + 32'd4;
                    ex_mem_rs2_data   <= rs2_data;
                    ex_mem_rd         <= ex_rd_addr;
                    ex_mem_funct3     <= ex_funct3;
                    ex_mem_reg_write  <= dec_reg_write;
                    ex_mem_mem_read   <= dec_mem_read;
                    ex_mem_mem_write  <= dec_mem_write;
                    ex_mem_wb_sel     <= dec_wb_sel;
                    ex_mem_imm        <= ex_imm;
                    ex_mem_valid      <= 1'b1;
                end
                else begin
                    // bubble: IF/EX invalid, or the halting instruction itself
                    ex_mem_valid     <= 1'b0;
                    ex_mem_reg_write <= 1'b0;
                    ex_mem_mem_read  <= 1'b0;
                    ex_mem_mem_write <= 1'b0;
                end
            end
            else begin
                // RULE 3: load-use stall inserts exactly one bubble into MEM
                ex_mem_valid     <= 1'b0;
                ex_mem_reg_write <= 1'b0;
                ex_mem_mem_read  <= 1'b0;
                ex_mem_mem_write <= 1'b0;
            end

            // ------------------------------------------------------------
            // MEM -> MEM/WB   (load data becomes architectural here)
            // ------------------------------------------------------------
            if (ex_mem_valid) begin
                mem_wb_data      <= mem_wb_data_next;
                mem_wb_rd        <= ex_mem_rd;
                mem_wb_reg_write <= ex_mem_reg_write;
                mem_wb_valid     <= 1'b1;
            end
            else begin
                mem_wb_valid     <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
