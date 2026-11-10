`timescale 1ns/1ps
`default_nettype none

module seg7_tb;

    reg        clk;
    reg        rst;

    reg [31:0] dmem_addr;
    reg [31:0] dmem_wdata;
    reg [3:0]  dmem_wstrb;

    reg [31:0] seg_data_reg;
    reg [7:0]  seg_dp_reg;

    wire [3:0] d0_an;
    wire [7:0] d0_seg;
    wire [3:0] d1_an;
    wire [7:0] d1_seg;

    wire       io_seg_data;
    wire       io_seg_dp;

    integer    errors;
    integer    v;
    integer    p;
    integer    k;

    reg [3:0]  nib;
    reg [31:0] pat;
    reg [7:0]  dp_val;
    reg [7:0]  exp;
    reg [7:0]  exp0;
    reg [7:0]  exp1;

    reg [1:0]  phase_p;
    reg [2:0]  digit0_r;
    reg [2:0]  digit1_r;

    reg [1:0]  prev_phase;
    reg [1:0]  expected_next;
    reg        prev_idle;
    reg        monitor_started;
    reg        done;

    assign io_seg_data = (dmem_addr[31:28] == 4'h1) &&
                         (dmem_addr[11:0] == 12'h00C);

    assign io_seg_dp   = (dmem_addr[31:28] == 4'h1) &&
                         (dmem_addr[11:0] == 12'h010);

    initial clk = 1'b0;
    always #6.667 clk = ~clk;

    initial begin
        seg_data_reg = 32'h0000_0000;
        seg_dp_reg   = 8'h00;
    end

    always @(posedge clk) begin
        if (rst) begin
            seg_data_reg <= 32'h0000_0000;
            seg_dp_reg   <= 8'h00;
        end
        else begin
            if (io_seg_data && (|dmem_wstrb)) begin
                if (dmem_wstrb[0]) seg_data_reg[7:0]   <= dmem_wdata[7:0];
                if (dmem_wstrb[1]) seg_data_reg[15:8]  <= dmem_wdata[15:8];
                if (dmem_wstrb[2]) seg_data_reg[23:16] <= dmem_wdata[23:16];
                if (dmem_wstrb[3]) seg_data_reg[31:24] <= dmem_wdata[31:24];
            end

            if (io_seg_dp && dmem_wstrb[0]) begin
                seg_dp_reg <= dmem_wdata[7:0];
            end
        end
    end

    seg7_driver dut (
        .clk     (clk),
        .rst     (rst),
        .data    (seg_data_reg),
        .dp      (seg_dp_reg),
        .d0_an   (d0_an),
        .d0_seg  (d0_seg),
        .d1_an   (d1_an),
        .d1_seg  (d1_seg)
    );

    function [7:0] expected_seg;
        input [3:0] nib_in;
        input       dp_on;
        reg [6:0]   pat_in;
        begin
            pat_in = 7'h00;

            case (nib_in)
                4'h0: pat_in = 7'h3F;
                4'h1: pat_in = 7'h06;
                4'h2: pat_in = 7'h5B;
                4'h3: pat_in = 7'h4F;
                4'h4: pat_in = 7'h66;
                4'h5: pat_in = 7'h6D;
                4'h6: pat_in = 7'h7D;
                4'h7: pat_in = 7'h07;
                4'h8: pat_in = 7'h7F;
                4'h9: pat_in = 7'h6F;
                4'hA: pat_in = 7'h77;
                4'hB: pat_in = 7'h7C;
                4'hC: pat_in = 7'h39;
                4'hD: pat_in = 7'h5E;
                4'hE: pat_in = 7'h79;
                4'hF: pat_in = 7'h71;
                default: pat_in = 7'h00;
            endcase

            expected_seg = { ~dp_on, ~pat_in };
        end
    endfunction

    function dp_bit_tb;
        input [7:0] m;
        input [2:0] n;
        begin
            case (n)
                3'd0: dp_bit_tb = m[0];
                3'd1: dp_bit_tb = m[1];
                3'd2: dp_bit_tb = m[2];
                3'd3: dp_bit_tb = m[3];
                3'd4: dp_bit_tb = m[4];
                3'd5: dp_bit_tb = m[5];
                3'd6: dp_bit_tb = m[6];
                3'd7: dp_bit_tb = m[7];
                default: dp_bit_tb = 1'b0;
            endcase
        end
    endfunction

    function [3:0] expected_anode;
        input [1:0] p_in;
        begin
            case (p_in)
                2'd0: expected_anode = 4'b1110;
                2'd1: expected_anode = 4'b1101;
                2'd2: expected_anode = 4'b1011;
                2'd3: expected_anode = 4'b0111;
                default: expected_anode = 4'b1111;
            endcase
        end
    endfunction

    task write_reg;
        input [11:0] off;
        input [31:0] val;
        input [3:0]  strb;
        begin
            @(negedge clk);
            dmem_addr  = 32'h10000000 | {20'h00000, off};
            dmem_wdata = val;
            dmem_wstrb = strb;

            @(negedge clk);
            dmem_addr  = 32'h00000000;
            dmem_wdata = 32'h00000000;
            dmem_wstrb = 4'h0;
        end
    endtask

    task wait_phase_active;
        input [1:0] p_wait;
        integer     j;
        begin
            wait (dut.phase == p_wait && dut.idle == 1'b0);

            @(posedge clk);
            #1;

            if (dut.idle !== 1'b0 || dut.phase !== p_wait) begin
                errors = errors + 1;
                $display("FAIL wait_phase_active entry p=%0d idle=%b phase=%0d",
                         p_wait, dut.idle, dut.phase);
            end

            for (j = 0; j < 20; j = j + 1) begin
                @(posedge clk);
            end

            #1;

            if (dut.idle !== 1'b0 || dut.phase !== p_wait) begin
                errors = errors + 1;
                $display("FAIL wait_phase_active stable p=%0d idle=%b phase=%0d",
                         p_wait, dut.idle, dut.phase);
            end
        end
    endtask

    always @(posedge clk) begin
        #1;

        if (!monitor_started) begin
            if (!rst) begin
                prev_phase      = dut.phase;
                prev_idle       = dut.idle;
                monitor_started = 1;
            end
        end
        else begin
            if (dut.idle === 1'b1) begin
                if (prev_idle === 1'b1) begin
                    errors = errors + 1;
                    $display("FAIL idle longer than one clock");
                end

                if (d0_an !== 4'b1111 || d1_an !== 4'b1111) begin
                    errors = errors + 1;
                    $display("FAIL idle anodes not off d0_an=%b d1_an=%b",
                             d0_an, d1_an);
                end
            end
            else begin
                if (prev_idle === 1'b1) begin
                    expected_next = prev_phase + 2'd1;

                    if (dut.phase !== expected_next) begin
                        errors = errors + 1;
                        $display("FAIL phase order prev=%0d now=%0d expected=%0d",
                                 prev_phase, dut.phase, expected_next);
                    end
                end
                else begin
                    if (prev_phase !== dut.phase) begin
                        errors = errors + 1;
                        $display("FAIL phase changed without idle prev=%0d now=%0d",
                                 prev_phase, dut.phase);
                    end
                end
            end

            prev_phase = dut.phase;
            prev_idle  = dut.idle;
        end
    end

    initial begin
        errors          = 0;
        rst             = 1'b1;
        dmem_addr       = 32'h00000000;
        dmem_wdata      = 32'h00000000;
        dmem_wstrb      = 4'h0;
        prev_phase      = 2'd0;
        prev_idle       = 1'b0;
        monitor_started = 1'b0;
        done            = 1'b0;

        repeat (20) @(posedge clk);
        rst = 1'b0;

        repeat (5) @(posedge clk);

        for (k = 0; k < 2; k = k + 1) begin
            phase_p = 2'd0;
            wait_phase_active(phase_p);

            phase_p = 2'd1;
            wait_phase_active(phase_p);

            phase_p = 2'd2;
            wait_phase_active(phase_p);

            phase_p = 2'd3;
            wait_phase_active(phase_p);
        end

        for (v = 0; v < 16; v = v + 1) begin
            nib = v;
            pat = {nib, nib, nib, nib, nib, nib, nib, nib};

            write_reg(12'h00C, pat, 4'hF);
            write_reg(12'h010, 32'h00000000, 4'h1);

            for (p = 0; p < 4; p = p + 1) begin
                phase_p = p;
                wait_phase_active(phase_p);

                exp = expected_seg(nib, 1'b0);

                if (d0_seg !== exp || d1_seg !== exp) begin
                    errors = errors + 1;
                    $display("FAIL hex v=%0d p=%0d d0_seg=%02x exp=%02x d1_seg=%02x",
                             v, phase_p, d0_seg, exp, d1_seg);
                end

                if (d0_an !== expected_anode(phase_p) ||
                    d1_an !== expected_anode(phase_p)) begin
                    errors = errors + 1;
                    $display("FAIL anode p=%0d d0_an=%b d1_an=%b exp=%b",
                             phase_p, d0_an, d1_an, expected_anode(phase_p));
                end
            end
        end

        dp_val = 8'hAA;

        write_reg(12'h00C, 32'h00000000, 4'hF);
        write_reg(12'h010, {24'h000000, dp_val}, 4'h1);

        for (p = 0; p < 4; p = p + 1) begin
            phase_p  = p;
            digit0_r = phase_p;
            digit1_r = p + 4;

            wait_phase_active(phase_p);

            exp0 = expected_seg(4'h0, dp_bit_tb(dp_val, digit0_r));
            exp1 = expected_seg(4'h0, dp_bit_tb(dp_val, digit1_r));

            if (d0_seg !== exp0 || d1_seg !== exp1) begin
                errors = errors + 1;
                $display("FAIL dp p=%0d d0_seg=%02x exp0=%02x d1_seg=%02x exp1=%02x",
                         phase_p, d0_seg, exp0, d1_seg, exp1);
            end

            if (d0_an !== expected_anode(phase_p) ||
                d1_an !== expected_anode(phase_p)) begin
                errors = errors + 1;
                $display("FAIL dp anode p=%0d d0_an=%b d1_an=%b exp=%b",
                         phase_p, d0_an, d1_an, expected_anode(phase_p));
            end
        end

        if (!done) begin
            done = 1'b1;

            if (errors == 0) begin
                $display("SEG7 TB PASS");
            end
            else begin
                $display("SEG7 TB FAIL");
            end

            $finish;
        end
    end

    initial begin
        #50000000;

        if (!done) begin
            done   = 1'b1;
            errors = errors + 1;
            $display("FAIL timeout");
            $display("SEG7 TB FAIL");
            $finish;
        end
    end

endmodule

`default_nettype wire
