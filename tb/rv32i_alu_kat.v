`timescale 1ns/1ps
module rv32i_alu_kat;
    reg  [31:0] a, b;
    reg  [3:0]  op;
    reg  [2:0]  f3;
    wire [31:0] y;
    wire        taken;
    integer     errors;

    rv32i_alu        u_alu (.a(a), .b(b), .op(op), .y(y));
    rv32i_branch_cmp u_br  (.a(a), .b(b), .funct3(f3), .taken(taken));

    task alu_kat;
        input [3:0]  o;
        input [31:0] x, z, want;
        begin
            a = x; b = z; op = o; #1;
            if (y !== want) begin
                errors = errors + 1;
                $display("ALU KAT FAIL op=%b a=%h b=%h got=%h want=%h", o, x, z, y, want);
            end
        end
    endtask

    task br_kat;
        input [2:0]  t;
        input [31:0] x, z;
        input        want;
        begin
            a = x; b = z; f3 = t; #1;
            if (taken !== want) begin
                errors = errors + 1;
                $display("BR KAT FAIL f3=%b a=%h b=%h got=%b want=%b", t, x, z, taken, want);
            end
        end
    endtask

    initial begin
        errors = 0;
        alu_kat(4'b0000, 32'hFFFFFFFF, 32'h00000001, 32'h00000000);
        alu_kat(4'b0000, 32'h7FFFFFFF, 32'h00000001, 32'h80000000);
        alu_kat(4'b1000, 32'h00000000, 32'h00000001, 32'hFFFFFFFF);
        alu_kat(4'b1000, 32'h00000005, 32'h00000005, 32'h00000000);
        alu_kat(4'b0001, 32'h00000001, 32'h0000001F, 32'h80000000);
        alu_kat(4'b0001, 32'h00000001, 32'h00000020, 32'h00000001);
        alu_kat(4'b0001, 32'h00000001, 32'h00000021, 32'h00000002);
        alu_kat(4'b0010, 32'hFFFFFFFF, 32'h00000001, 32'h00000001);
        alu_kat(4'b0010, 32'h00000001, 32'hFFFFFFFF, 32'h00000000);
        alu_kat(4'b0010, 32'h80000000, 32'h7FFFFFFF, 32'h00000001);
        alu_kat(4'b0011, 32'hFFFFFFFF, 32'h00000001, 32'h00000000);
        alu_kat(4'b0011, 32'h00000001, 32'hFFFFFFFF, 32'h00000001);
        alu_kat(4'b0011, 32'h80000000, 32'h7FFFFFFF, 32'h00000000);
        alu_kat(4'b0100, 32'hF0F0F0F0, 32'hFFFF0000, 32'h0F0FF0F0);
        alu_kat(4'b0101, 32'h80000000, 32'h00000004, 32'h08000000);
        alu_kat(4'b0101, 32'hFFFFFFFF, 32'h0000001F, 32'h00000001);
        alu_kat(4'b0101, 32'hFFFFFFFF, 32'h00000020, 32'hFFFFFFFF);
        alu_kat(4'b0110, 32'hF0F0F0F0, 32'h0F000F00, 32'hFFF0FFF0);
        alu_kat(4'b0111, 32'hF0F0F0F0, 32'hFF00FF00, 32'hF000F000);
        alu_kat(4'b1101, 32'h80000000, 32'h00000004, 32'hF8000000);
        alu_kat(4'b1101, 32'h80000000, 32'h00000021, 32'hC0000000);
        alu_kat(4'b1101, 32'h7FFFFFFF, 32'h00000004, 32'h07FFFFFF);
        alu_kat(4'b1101, 32'hFFFFFFFF, 32'h0000001F, 32'hFFFFFFFF);
        alu_kat(4'b1001, 32'h00000005, 32'h00000003, 32'h00000000);
        alu_kat(4'b1100, 32'h00000005, 32'h00000003, 32'h00000000);
        alu_kat(4'b1111, 32'h00000005, 32'h00000003, 32'h00000000);

        br_kat(3'b000, 32'h00000005, 32'h00000005, 1'b1);
        br_kat(3'b000, 32'h00000005, 32'h00000006, 1'b0);
        br_kat(3'b001, 32'h00000005, 32'h00000006, 1'b1);
        br_kat(3'b001, 32'h00000005, 32'h00000005, 1'b0);
        br_kat(3'b010, 32'h00000005, 32'h00000005, 1'b0);
        br_kat(3'b011, 32'h00000005, 32'h00000006, 1'b0);
        br_kat(3'b100, 32'hFFFFFFFF, 32'h00000001, 1'b1);
        br_kat(3'b100, 32'h00000001, 32'hFFFFFFFF, 1'b0);
        br_kat(3'b100, 32'h80000000, 32'h7FFFFFFF, 1'b1);
        br_kat(3'b101, 32'h80000000, 32'h7FFFFFFF, 1'b0);
        br_kat(3'b101, 32'h00000005, 32'h00000005, 1'b1);
        br_kat(3'b101, 32'hFFFFFFFF, 32'h00000001, 1'b0);
        br_kat(3'b110, 32'hFFFFFFFF, 32'h00000001, 1'b0);
        br_kat(3'b110, 32'h00000001, 32'hFFFFFFFF, 1'b1);
        br_kat(3'b110, 32'h7FFFFFFF, 32'h80000000, 1'b1);
        br_kat(3'b111, 32'h80000000, 32'h7FFFFFFF, 1'b1);
        br_kat(3'b111, 32'h00000005, 32'h00000005, 1'b1);
        br_kat(3'b111, 32'h00000001, 32'hFFFFFFFF, 1'b0);

        if (errors == 0) $display("KAT PASS");
        else             $display("KAT FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
