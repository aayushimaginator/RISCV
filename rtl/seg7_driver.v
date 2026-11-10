`default_nettype none

module seg7_driver (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] data,
    input  wire [7:0]  dp,
    output wire [3:0]  d0_an,
    output wire [7:0]  d0_seg,
    output wire [3:0]  d1_an,
    output wire [7:0]  d1_seg
);

    localparam PHASE_CLKS = 18750;

    localparam [23:0] DIGIT_MAP = {
        3'b000,
        3'b001,
        3'b010,
        3'b011,
        3'b100,
        3'b101,
        3'b110,
        3'b111
    };

    function [2:0] digit_map;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: digit_map = DIGIT_MAP[2:0];
                3'd1: digit_map = DIGIT_MAP[5:3];
                3'd2: digit_map = DIGIT_MAP[8:6];
                3'd3: digit_map = DIGIT_MAP[11:9];
                3'd4: digit_map = DIGIT_MAP[14:12];
                3'd5: digit_map = DIGIT_MAP[17:15];
                3'd6: digit_map = DIGIT_MAP[20:18];
                3'd7: digit_map = DIGIT_MAP[23:21];
                default: digit_map = 3'b000;
            endcase
        end
    endfunction

    function [3:0] get_nibble;
        input [31:0] d;
        input [2:0]  n;
        begin
            case (n)
                3'd0: get_nibble = d[3:0];
                3'd1: get_nibble = d[7:4];
                3'd2: get_nibble = d[11:8];
                3'd3: get_nibble = d[15:12];
                3'd4: get_nibble = d[19:16];
                3'd5: get_nibble = d[23:20];
                3'd6: get_nibble = d[27:24];
                3'd7: get_nibble = d[31:28];
                default: get_nibble = 4'h0;
            endcase
        end
    endfunction

    function dp_bit;
        input [7:0] m;
        input [2:0] n;
        begin
            case (n)
                3'd0: dp_bit = m[0];
                3'd1: dp_bit = m[1];
                3'd2: dp_bit = m[2];
                3'd3: dp_bit = m[3];
                3'd4: dp_bit = m[4];
                3'd5: dp_bit = m[5];
                3'd6: dp_bit = m[6];
                3'd7: dp_bit = m[7];
                default: dp_bit = 1'b0;
            endcase
        end
    endfunction

    function [6:0] seg_active_high;
        input [3:0] nib;
        begin
            case (nib)
                4'h0: seg_active_high = 7'h3F;
                4'h1: seg_active_high = 7'h06;
                4'h2: seg_active_high = 7'h5B;
                4'h3: seg_active_high = 7'h4F;
                4'h4: seg_active_high = 7'h66;
                4'h5: seg_active_high = 7'h6D;
                4'h6: seg_active_high = 7'h7D;
                4'h7: seg_active_high = 7'h07;
                4'h8: seg_active_high = 7'h7F;
                4'h9: seg_active_high = 7'h6F;
                4'hA: seg_active_high = 7'h77;
                4'hB: seg_active_high = 7'h7C;
                4'hC: seg_active_high = 7'h39;
                4'hD: seg_active_high = 7'h5E;
                4'hE: seg_active_high = 7'h79;
                4'hF: seg_active_high = 7'h71;
                default: seg_active_high = 7'h00;
            endcase
        end
    endfunction

    function [3:0] anode_low;
        input [1:0] a;
        begin
            case (a)
                2'd0: anode_low = 4'b1110;
                2'd1: anode_low = 4'b1101;
                2'd2: anode_low = 4'b1011;
                2'd3: anode_low = 4'b0111;
                default: anode_low = 4'b1111;
            endcase
        end
    endfunction

    reg [1:0]  phase;
    reg [15:0] cnt;
    reg        idle;

    initial begin
        phase = 2'd0;
        cnt   = 16'd0;
        idle  = 1'b0;
    end

    always @(posedge clk) begin
        if (rst) begin
            phase <= 2'd0;
            cnt   <= 16'd0;
            idle  <= 1'b0;
        end
        else begin
            if (idle) begin
                idle  <= 1'b0;
                phase <= phase + 2'd1;
                cnt   <= 16'd0;
            end
            else begin
                if (cnt == PHASE_CLKS - 1) begin
                    idle <= 1'b1;
                end
                else begin
                    cnt <= cnt + 16'd1;
                end
            end
        end
    end

    reg [2:0] sel0;
    reg [2:0] sel1;
    reg [1:0] an0;
    reg [1:0] an1;

    integer   i;
    reg [2:0] idx;
    reg [2:0] m;

    always @* begin
        sel0 = 3'd0;
        sel1 = 3'd0;
        an0  = 2'd0;
        an1  = 2'd0;

        for (i = 0; i < 8; i = i + 1) begin
            idx = i;
            m   = digit_map(idx);

            if (m[2] == 1'b0 && m[1:0] == phase) begin
                sel0 = idx;
                an0  = m[1:0];
            end

            if (m[2] == 1'b1 && m[1:0] == phase) begin
                sel1 = idx;
                an1  = m[1:0];
            end
        end
    end

    wire [3:0] nib0 = get_nibble(data, sel0);
    wire [3:0] nib1 = get_nibble(data, sel1);

    wire [6:0] pat0 = seg_active_high(nib0);
    wire [6:0] pat1 = seg_active_high(nib1);

    wire       dp0  = dp_bit(dp, sel0);
    wire       dp1  = dp_bit(dp, sel1);

    wire [7:0] seg0_val = { ~dp0, ~pat0 };
    wire [7:0] seg1_val = { ~dp1, ~pat1 };

    assign d0_an  = (rst || idle) ? 4'b1111 : anode_low(an0);
    assign d1_an  = (rst || idle) ? 4'b1111 : anode_low(an1);
    assign d0_seg = (rst || idle) ? 8'hFF   : seg0_val;
    assign d1_seg = (rst || idle) ? 8'hFF   : seg1_val;

endmodule

`default_nettype wire
