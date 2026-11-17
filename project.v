module project(CLOCK_50, KEY, PS2_CLK, PS2_DAT, HEX0, HEX1);
    input CLOCK_50;
    input [3:0] KEY;
    inout PS2_CLK, PS2_DAT;
    output [6:0] HEX0, HEX1;

    wire resetn = KEY[0];
    wire PS2_CLK_S, PS2_DAT_S; // signals synced to our clock
    sync s1 (PS2_CLK, resetn, CLOCK_50, PS2_CLK_S);
    sync s2 (PS2_DAT, resetn, CLOCK_50, PS2_DAT_S);

    reg [32:0] SERIAL; // data packet received from PS2
    reg prev_ps2_clk;
    reg [3:0] PACKET; // counts when a full packet gets sent in, each has 11 bits
                      // STOP (1) PARITY d7 d6 d5 d4 d3 d2 d1 d0 START (0)

    always @ (posedge CLOCK_50) 
        prev_ps2_clk <= PS2_CLK_S;

    // detects when clock goes from 1 to 0, new negative edge
    wire negedge_ps2_clk = prev_ps2_clk & !PS2_CLK_S;

    always @ (posedge CLOCK_50) begin
        if(!resetn)
            SERIAL <= 33'b0;
        else if (negedge_ps2_clk) begin // shift in new data
            SERIAL[31:0] <= SERIAL[32:1];
            SERIAL[32] <= PS2_DAT_S;
        end
    end

    always @ (posedge CLOCK_50) begin
        if(!resetn || PACKET == 4'd11)
            PACKET <= 4'b0;
        else if(negedge_ps2_clk)
            PACKET <= PACKET + 1'b1;
    end

    wire [7:0] ps2_byte = SERIAL[30:23];
    wire ps2_valid = PACKET == 4'd11; // if received a full packet, then the input ps2 byte is valid

    wire validkey;
    wire [3:0] key;
    wire [11:0] heldkeys;

    keyslist k0(ps2_byte, key, validkey);
    keyboard_reader k1(CLOCK_50, resetn, ps2_byte, ps2_valid, heldkeys, key, validkey);

    seg7 s0(heldkeys, HEX0, HEX1); // TESTING
endmodule

module sync(D, resetn, clock, Q);
    input wire D;
    input wire resetn, clock;
    output reg Q;

    reg Qi; // for the internal flip flop
    // first flip flop lines up signal with our CLOCK_50, and second flip flop ensures that the signal is stable; that there's no immediate presses on a clock edge that causes something weird to happen
    always @(posedge clock) 
        if(!resetn) begin
            Qi <= 0;
            Q <= 0;
        end else begin
            Qi <= D;
            Q <= Qi;
        end
endmodule

module keyslist(inkeys, keys, valid);
    input [7:0] inkeys;
    output reg valid;
    output reg [3:0] keys;
    always @(*) begin
        valid = 1'b1;
        case(inkeys)
            8'h1C: keys = 4'd0; // C
            8'h1D: keys = 4'd1; // D FLAT / C#
            8'h1B: keys = 4'd2; // D
            8'h24: keys = 4'd3; // E FLAT / D#
            8'h23: keys = 4'd4; // E
            8'h2B: keys = 4'd5; // F
            8'h2C: keys = 4'd6; // G FLAT / F#
            8'h34: keys = 4'd7; // G
            8'h35: keys = 4'd8; // A FLAT / G#
            8'h33: keys = 4'd9; // A
            8'h3C: keys = 4'd10; // B FLAT / A#
            8'h3B: keys = 4'd11; // B
            default: begin
                valid = 1'b0;
                keys = 4'd0;
            end
        endcase
    end
endmodule

module keyboard_reader (clock, resetn, ps2_byte, ps2_valid, held_keys, keys, valid);
    input clock, resetn, valid;
    input [3:0] keys;
    input [7:0] ps2_byte;
    output reg [11:0] held_keys;
    reg f0; // tracks presses and releases

    always @(posedge clock) begin   
        if(!resetn) begin
            held_keys <= 12'b0;
            f0 <= 1'b0;
        end else if (ps2_valid) begin   
            if(f0) begin // previously held key, now released
                if(valid)
                    held_keys[keys] <= 1'b0; // release the key
                    f0 <= 1'b0; // set f0
                end
            else if(ps2_byte == 8'hF0)
                f0 <= 1'b1; // warning that next byte will be a release
            else if(valid) // if pressed key is valid
                held_keys[keys] <= 1'b1; // set the current key to held
            end
        end
endmodule

module seg7(D, HEX0, HEX1);
    input [11:0] D;
    output [6:0] HEX0, HEX1;

    assign HEX0[2] = D[1] | D[3] | D[6] | D[8] | D[10];
    assign HEX0[3] = D[1] | D[3] | D[6] | D[8] | D[10];
    assign HEX0[4] = D[1] | D[3] | D[6] | D[8] | D[10];
    assign HEX0[5] = D[1] | D[3] | D[6] | D[8] | D[10];
    assign HEX0[6] = D[1] | D[3] | D[6] | D[8] | D[10];

    assign HEX1[0] = 1'b1;
    assign HEX1[1] = D[1] | D[2] | D[8] | D[9] | D[10] | D[11];
    assign HEX1[2] = D[1] | D[2] | D[6] | D[7] | D[8] | D[9] | D[10] | D[11];
    assign HEX1[3] = !(D[5] & D[8] & D[9]);
    assign HEX1[4] = 1'b1;
    assign HEX1[5] = 1'b1;
    assign HEX1[6] = D[3] | D[4] | D[5] | D[8] | D[9] | D[10] | D[11];
endmodule