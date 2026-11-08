`timescale 1ns/1ps
// Core harness: unified 2048-word memory, async read, byte-strobe write.
// Plusargs: +HEX=<f> +DUMP=<f> +MAXCYCLES=<n> +SELFCHECK +TRACE=<f>
module rv32i_core_tb;
    reg          clk;
    reg          resetn;
    wire [31:0]  imem_addr, imem_rdata;
    wire [31:0]  dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]   dmem_wstrb;
    wire         dmem_re;
    wire         halted;

    reg  [31:0]   mem [0:2047];
    reg  [31:0]   wtmp;
    reg  [1023:0] hex_file;
    reg  [1023:0] dump_file;
    reg  [1023:0] trace_file;
    integer       max_cycles, cycle_count, halt_wait, i, fd, tfd;
    reg           selfcheck;
    reg           tracing;

    rv32i_core dut (
        .clk(clk), .resetn(resetn),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb),
        .dmem_re(dmem_re), .dmem_rdata(dmem_rdata),
        .halted(halted));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    assign imem_rdata = mem[imem_addr[12:2]];
    assign dmem_rdata = mem[dmem_addr[12:2]];

    always @(posedge clk) begin
        if (|dmem_wstrb) begin
            wtmp = mem[dmem_addr[12:2]];
            if (dmem_wstrb[0]) wtmp[7:0]   = dmem_wdata[7:0];
            if (dmem_wstrb[1]) wtmp[15:8]  = dmem_wdata[15:8];
            if (dmem_wstrb[2]) wtmp[23:16] = dmem_wdata[23:16];
            if (dmem_wstrb[3]) wtmp[31:24] = dmem_wdata[31:24];
            mem[dmem_addr[12:2]] <= wtmp;
        end
    end

    // Per-instruction trace: pc, instruction, rd (0 = none), written value.
    always @(posedge clk) begin
        if (tracing && (resetn === 1'b1) && (dut.u_dec.halt === 1'b0)) begin
            if ((dut.u_regfile.we === 1'b1) && (dut.u_regfile.waddr != 5'd0))
                $fwrite(tfd, "%08x %08x %0d %08x\n", imem_addr, imem_rdata,
                        dut.u_regfile.waddr, dut.u_regfile.wdata);
            else
                $fwrite(tfd, "%08x %08x 0 00000000\n", imem_addr, imem_rdata);
        end
    end

    initial begin
        if (!$value$plusargs("HEX=%s", hex_file))         hex_file = "tests/smoke.hex";
        if (!$value$plusargs("DUMP=%s", dump_file))       dump_file = "core_dump.txt";
        if (!$value$plusargs("MAXCYCLES=%d", max_cycles)) max_cycles = 200000;
        selfcheck = $test$plusargs("SELFCHECK");
        tracing = 1'b0;
        if ($value$plusargs("TRACE=%s", trace_file)) begin
            tfd = $fopen(trace_file, "w");
            tracing = 1'b1;
        end

        for (i = 0; i < 2048; i = i + 1) mem[i] = 32'h0000_0000;
        $readmemh(hex_file, mem);

        resetn = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        resetn = 1'b1;

        cycle_count = 0;
        halt_wait   = 0;
        while ((cycle_count < max_cycles) && (halt_wait < 2)) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (halted === 1'b1) halt_wait = halt_wait + 1;
        end

        fd = $fopen(dump_file, "w");
        $fwrite(fd, "x0 00000000\n");
        for (i = 1; i < 32; i = i + 1)
            $fwrite(fd, "x%0d %08x\n", i, dut.u_regfile.rf[i]);
        $fwrite(fd, "pc %08x\n", dut.halted ? dut.if_ex_pc : dut.pc);
        $fwrite(fd, "cycles %0d\n", cycle_count);
        for (i = 0; i < 2048; i = i + 1)
            $fwrite(fd, "m%04x %08x\n", i, mem[i]);
        $fclose(fd);
        if (tracing) $fclose(tfd);

        if (halted === 1'b1) $display("RESULT: HALTED");
        else                 $display("RESULT: TIMEOUT");
        if (selfcheck) begin
            if (mem[2047] === 32'h0000600D) $display("PASS");
            else                            $display("FAIL");
        end
        $finish;
    end
endmodule
