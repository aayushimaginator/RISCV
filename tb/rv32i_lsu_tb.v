`default_nettype none
`timescale 1ns/1ps

module rv32i_lsu_tb;

    reg  [31:0] rdata_word;
    reg  [1:0]  addr_lo;
    reg  [2:0]  funct3;

    reg  [31:0] store_data;
    reg         mem_write;

    wire [31:0] load_data;
    wire [31:0] wdata_out;
    wire [3:0]  wstrb;

    rv32i_lsu dut (
        .rdata_word (rdata_word),
        .addr_lo    (addr_lo),
        .funct3     (funct3),
        .load_data  (load_data),

        .store_data (store_data),
        .mem_write  (mem_write),
        .wdata_out  (wdata_out),
        .wstrb      (wstrb)
    );

    integer errors;
    integer seed;
    integer i;
    integer j;
    integer n;

    reg [31:0] exp_load;
    reg [35:0] exp_store;

    // -------------------------------------------------------------------------
    // Independent behavioral reference: load path
    // -------------------------------------------------------------------------
    function [31:0] ref_load;
        input [31:0] word;
        input [1:0]  addr;
        input [2:0]  f3;

        reg [7:0]  b;
        reg [15:0] h;

        begin
            case (addr)
                2'd0: b = word[7:0];
                2'd1: b = word[15:8];
                2'd2: b = word[23:16];
                2'd3: b = word[31:24];
            endcase

            if (addr[1]) begin
                h = word[31:16];
            end
            else begin
                h = word[15:0];
            end

            case (f3)
                3'b000: begin // LB
                    ref_load = {{24{b[7]}}, b};
                end

                3'b100: begin // LBU
                    ref_load = {24'b0, b};
                end

                3'b001: begin // LH
                    ref_load = {{16{h[15]}}, h};
                end

                3'b101: begin // LHU
                    ref_load = {16'b0, h};
                end

                3'b010: begin // LW
                    ref_load = word;
                end

                default: begin
                    ref_load = 32'h0000_0000;
                end
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Independent behavioral reference: store path
    // -------------------------------------------------------------------------
    function [35:0] ref_store;
        input [31:0] data;
        input [1:0]  addr;
        input [2:0]  f3;
        input        we;

        reg [31:0] wd;
        reg [3:0]  st;

        begin
            wd = 32'h0000_0000;
            st = 4'b0000;

            if (we) begin
                case (f3)
                    3'b000: begin // SB
                        wd = {4{data[7:0]}};
                        st = (4'b0001 << addr);
                    end

                    3'b001: begin // SH
                        wd = {2{data[15:0]}};

                        if (addr[1]) begin
                            st = 4'b1100;
                        end
                        else begin
                            st = 4'b0011;
                        end
                    end

                    3'b010: begin // SW
                        wd = data;
                        st = 4'b1111;
                    end

                    default: begin
                        wd = 32'h0000_0000;
                        st = 4'b0000;
                    end
                endcase
            end

            ref_store = {wd, st};
        end
    endfunction

    // -------------------------------------------------------------------------
    // Directed expected-value check tasks
    // -------------------------------------------------------------------------
    task check_load_expected;
        input [31:0] word;
        input [1:0]  addr;
        input [2:0]  f3;
        input [31:0] expected;
        begin
            rdata_word = word;
            addr_lo    = addr;
            funct3     = f3;

            store_data = 32'h0000_0000;
            mem_write  = 1'b0;

            #1;

            if (load_data !== expected) begin
                errors = errors + 1;

                if (errors <= 10) begin
                    $display("MISMATCH load word=%h addr=%b f3=%b got=%h exp=%h",
                             word, addr, f3, load_data, expected);
                end
            end
        end
    endtask

    task check_store_expected;
        input [31:0] data;
        input [1:0]  addr;
        input [2:0]  f3;
        input        we;
        input [31:0] expected_wdata;
        input [3:0]  expected_wstrb;
        begin
            rdata_word = 32'h0000_0000;
            addr_lo    = addr;
            funct3     = f3;

            store_data = data;
            mem_write  = we;

            #1;

            if (wdata_out !== expected_wdata) begin
                errors = errors + 1;

                if (errors <= 10) begin
                    $display("MISMATCH store wdata data=%h addr=%b f3=%b we=%b got=%h exp=%h",
                             data, addr, f3, we, wdata_out, expected_wdata);
                end
            end

            if (wstrb !== expected_wstrb) begin
                errors = errors + 1;

                if (errors <= 10) begin
                    $display("MISMATCH store wstrb data=%h addr=%b f3=%b we=%b got=%b exp=%b",
                             data, addr, f3, we, wstrb, expected_wstrb);
                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Main test
    // -------------------------------------------------------------------------
    initial begin
        errors = 0;
        seed   = 32'h0000_1234;

        // ---------------------------------------------------------------------
        // Known-answer load tests
        // ---------------------------------------------------------------------
        // rdata = 0x80FF7F01
        // byte lane 0 = 0x01
        // byte lane 1 = 0x7F
        // byte lane 2 = 0xFF
        // byte lane 3 = 0x80

        // LB
        check_load_expected(32'h80FF7F01, 2'd0, 3'b000, 32'h00000001);
        check_load_expected(32'h80FF7F01, 2'd1, 3'b000, 32'h0000007F);
        check_load_expected(32'h80FF7F01, 2'd2, 3'b000, 32'hFFFFFFFF);
        check_load_expected(32'h80FF7F01, 2'd3, 3'b000, 32'hFFFFFF80);

        // LBU
        check_load_expected(32'h80FF7F01, 2'd0, 3'b100, 32'h00000001);
        check_load_expected(32'h80FF7F01, 2'd1, 3'b100, 32'h0000007F);
        check_load_expected(32'h80FF7F01, 2'd2, 3'b100, 32'h000000FF);
        check_load_expected(32'h80FF7F01, 2'd3, 3'b100, 32'h00000080);

        // LH
        check_load_expected(32'h80FF7F01, 2'd0, 3'b001, 32'h00007F01);
        check_load_expected(32'h80FF7F01, 2'd1, 3'b001, 32'h00007F01);
        check_load_expected(32'h80FF7F01, 2'd2, 3'b001, 32'hFFFF80FF);
        check_load_expected(32'h80FF7F01, 2'd3, 3'b001, 32'hFFFF80FF);

        // LHU
        check_load_expected(32'h80FF7F01, 2'd0, 3'b101, 32'h00007F01);
        check_load_expected(32'h80FF7F01, 2'd1, 3'b101, 32'h00007F01);
        check_load_expected(32'h80FF7F01, 2'd2, 3'b101, 32'h000080FF);
        check_load_expected(32'h80FF7F01, 2'd3, 3'b101, 32'h000080FF);

        // LW
        check_load_expected(32'h80FF7F01, 2'd0, 3'b010, 32'h80FF7F01);
        check_load_expected(32'h80FF7F01, 2'd1, 3'b010, 32'h80FF7F01);
        check_load_expected(32'h80FF7F01, 2'd2, 3'b010, 32'h80FF7F01);
        check_load_expected(32'h80FF7F01, 2'd3, 3'b010, 32'h80FF7F01);

        // Invalid load funct3 values
        check_load_expected(32'h80FF7F01, 2'd0, 3'b011, 32'h00000000);
        check_load_expected(32'h80FF7F01, 2'd0, 3'b110, 32'h00000000);
        check_load_expected(32'h80FF7F01, 2'd0, 3'b111, 32'h00000000);

        // ---------------------------------------------------------------------
        // Known-answer store tests
        // ---------------------------------------------------------------------

        // SB at lane 2
        check_store_expected(
            32'h000000AB,
            2'd2,
            3'b000,
            1'b1,
            32'hABABABAB,
            4'b0100
        );

        // SH at addr_lo = 2
        check_store_expected(
            32'h00001234,
            2'd2,
            3'b001,
            1'b1,
            32'h12341234,
            4'b1100
        );

        // SH at addr_lo = 3, still upper half because addr_lo[1] = 1
        check_store_expected(
            32'h00001234,
            2'd3,
            3'b001,
            1'b1,
            32'h12341234,
            4'b1100
        );

        // SH at addr_lo = 0
        check_store_expected(
            32'h00001234,
            2'd0,
            3'b001,
            1'b1,
            32'h12341234,
            4'b0011
        );

        // SW
        check_store_expected(
            32'hDEADBEEF,
            2'd0,
            3'b010,
            1'b1,
            32'hDEADBEEF,
            4'b1111
        );

        // mem_write = 0
        check_store_expected(
            32'hCAFEBABE,
            2'd1,
            3'b010,
            1'b0,
            32'h00000000,
            4'b0000
        );

        // Invalid store funct3 with mem_write = 1
        check_store_expected(
            32'h12345678,
            2'd1,
            3'b011,
            1'b1,
            32'h00000000,
            4'b0000
        );

        // ---------------------------------------------------------------------
        // Exhaustive randomized comparison against reference model.
        //
        // addr_lo  : 4 values
        // funct3   : 8 values
        // data     : 2000 random words
        // mem_write: 1 for this main store-path sweep
        // ---------------------------------------------------------------------
        for (n = 0; n < 2000; n = n + 1) begin
            rdata_word = $random(seed);
            store_data = $random(seed);

            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    addr_lo   = i[1:0];
                    funct3    = j[2:0];
                    mem_write = 1'b1;

                    #1;

                    exp_load = ref_load(rdata_word, addr_lo, funct3);

                    if (load_data !== exp_load) begin
                        errors = errors + 1;

                        if (errors <= 10) begin
                            $display("MISMATCH random load word=%h addr=%b f3=%b got=%h exp=%h",
                                     rdata_word, addr_lo, funct3, load_data, exp_load);
                        end
                    end

                    exp_store = ref_store(store_data, addr_lo, funct3, 1'b1);

                    if ({wdata_out, wstrb} !== exp_store) begin
                        errors = errors + 1;

                        if (errors <= 10) begin
                            $display("MISMATCH random store data=%h addr=%b f3=%b got=%h exp=%h",
                                     store_data, addr_lo, funct3,
                                     {wdata_out, wstrb}, exp_store);
                        end
                    end
                end
            end
        end

        // ---------------------------------------------------------------------
        // Check mem_write = 0 for every addr_lo / funct3 combination.
        // ---------------------------------------------------------------------
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                rdata_word = $random(seed);
                store_data = $random(seed);

                addr_lo   = i[1:0];
                funct3    = j[2:0];
                mem_write = 1'b0;

                #1;

                exp_load = ref_load(rdata_word, addr_lo, funct3);

                if (load_data !== exp_load) begin
                    errors = errors + 1;

                    if (errors <= 10) begin
                        $display("MISMATCH load with mem_write=0 word=%h addr=%b f3=%b got=%h exp=%h",
                                 rdata_word, addr_lo, funct3, load_data, exp_load);
                    end
                end

                if (wstrb !== 4'b0000) begin
                    errors = errors + 1;

                    if (errors <= 10) begin
                        $display("MISMATCH store wstrb with mem_write=0 addr=%b f3=%b got=%b",
                                 addr_lo, funct3, wstrb);
                    end
                end

                if (wdata_out !== 32'h0000_0000) begin
                    errors = errors + 1;

                    if (errors <= 10) begin
                        $display("MISMATCH store wdata with mem_write=0 addr=%b f3=%b got=%h",
                                 addr_lo, funct3, wdata_out);
                    end
                end
            end
        end

        if (errors == 0) begin
            $display("PASS");
        end
        else begin
            $display("FAIL");
        end

        $finish;
    end

endmodule

`default_nettype wire
