module project(CLOCK_50, KEY, PS2_CLK, PS2_DAT, HEX0, HEX1, VGA_R, VGA_G, VGA_B,
                VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
    input CLOCK_50;
    input [3:0] KEY;
    inout PS2_CLK, PS2_DAT;
    output [6:0] HEX0, HEX1;
    wire [11:0] heldkeys;

    parameter RESOLUTION = "640x480"; // "640x480" "320x240" "160x120"
    parameter COLOR_DEPTH = 9; // 9 6 3
    parameter nX = (RESOLUTION == "640x480") ? 10 : ((RESOLUTION == "320x240") ? 9 : 8);
    parameter nY = (RESOLUTION == "640x480") ? 9 : ((RESOLUTION == "320x240") ? 8 : 7);
    output [7:0] VGA_R, VGA_G, VGA_B;
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK; 

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

    keyslist k0(ps2_byte, key, validkey);
    keyboard_reader k1(CLOCK_50, resetn, ps2_byte, ps2_valid, heldkeys, key, validkey);

    seg7 s0(heldkeys, HEX0, HEX1, validkey); // TESTING

    wire [7:0] px_x;
    wire [6:0] px_y;
    wire [8:0] px_color;
    wire px_write;
    
    draw_piano dp(CLOCK_50, resetn, heldkeys, px_x, px_y, px_color, px_write);

    vga_adapter VGA ( // given by course ... ?? 
        .resetn(resetn), .clock(CLOCK_50),
        .color(px_color), .x(px_x), .y(px_y), .write(px_write),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK));
        defparam VGA.RESOLUTION = "160x120";
        defparam VGA.COLOR_DEPTH = 9;
        defparam VGA.BACKGROUND_IMAGE = "./MIF/rainbow_160_3.mif";
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
    input ps2_valid;
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
                f0 <= 1'b0; // always clear f0, even if the released key isn't a note
            end
            else if(ps2_byte == 8'hF0)
                f0 <= 1'b1; // warning that next byte will be a release
            else if(valid) // if pressed key is valid
                held_keys[keys] <= 1'b1; // set the current key to held
        end
    end
endmodule

module draw_piano(clock, resetn, held_keys, VGA_x, VGA_y, VGA_color, VGA_write);
    input clock, resetn;
    input [11:0] held_keys;
    output reg [7:0] VGA_x; 
    output reg [6:0] VGA_y;
    output reg [8:0] VGA_color;
    output reg VGA_write;

    reg bg;      // 0 = painting gray background, 1 = drawing piano
    reg [7:0] bx;    
    reg [6:0] by;     

    reg [3:0] n; // which key we're drawing
    reg [4:0] px; // column inside key
    reg [6:0] py; // row inside key

    reg [3:0] held; // bit number of key being held
    reg [7:0] left;
    reg black; // if flat
    wire [4:0] width = black ? 5'd12 : 5'd20;
    wire [6:0] height = black ? 7'd42 : 7'd70;

    always @ (*)
    begin
        black = 1'b0;
        case(n)
            4'd0: begin held = 4'd0; left = 8'd10; end
            4'd1: begin held = 4'd2;  left = 8'd30;  end
            4'd2: begin held = 4'd4;  left = 8'd50;  end
            4'd3: begin held = 4'd5;  left = 8'd70;  end
            4'd4: begin held = 4'd7;  left = 8'd90;  end
            4'd5: begin held = 4'd9;  left = 8'd110; end
            4'd6: begin held = 4'd11; left = 8'd130; end
            4'd7: begin held = 4'd1;  left = 8'd24;  black = 1'b1; end
            4'd8: begin held = 4'd3;  left = 8'd44;  black = 1'b1; end
            4'd9: begin held = 4'd6;  left = 8'd84;  black = 1'b1; end
            4'd10: begin held = 4'd8;  left = 8'd104; black = 1'b1; end
            4'd11: begin held = 4'd10; left = 8'd124; black = 1'b1; end
            default: begin held = 4'd0; left = 8'd0; end
        endcase
    end

    wire holding = held_keys[held]; // whether or not the current key that is being drawn is held
    wire black_right = (n == 0) || (n == 1) || (n == 3) || (n == 4) || (n == 5);
    wire black_left  = (n == 1) || (n == 2) || (n == 4) || (n == 5) || (n == 6);

    wire nodrawwhite = !black && (py < 7'd42) && ((black_left && px <= 5'd5) || (black_right && px >= 5'd14));

    always @ (posedge clock) begin
        if(!resetn) begin // reset
            n <= 0;
            px <= 0;
            py <= 0;
            bx <= 0; 
            by <= 0;
            bg <= 1'b0;
            VGA_write <= 1'b0;
        end else if(~bg) begin
            VGA_x <= bx;
            VGA_y <= by;
            VGA_color <= 9'b100_100_100;   
            VGA_write <= 1'b1;
            if (bx == 8'd159) begin
                bx <= 0;
                if (by == 7'd119) bg <= 1'b1;
                else by <= by + 1'b1;
            end else
                bx <= bx + 1'b1;
        end else begin
            VGA_x <= left + px;
            VGA_y <= 7'd30 + py;
            VGA_write <= !nodrawwhite;
            if(black)
                VGA_color <= holding ? 9'b000_000_111 : 9'b000_000_000; // black key, blue if held
            else if(px == width - 1)
                VGA_color <= 9'b000_000_000;  // draw a line in between keys
            else 
                VGA_color <= holding ? 9'b000_111_000 : 9'b111_111_111; // white key, green if held
            
            if(px == width - 1) begin
                px <= 0; // if at end of row, go back to beginning
                if(py == height - 1) begin // at the end of the last row
                    py <= 0;
                    n <= (n == 4'd11) ? 4'd0 : n + 4'd1; // go to next key, if at last key, wrap back to first
                end else
                    py <= py + 1'b1;
            end else // not at end, just increment once more
                px <= px + 1'b1;
        end
    end
endmodule

module seg7(D, HEX0, HEX1, valid);
    input [11:0] D;
    input valid;
    output reg [6:0] HEX0, HEX1;
    wire flat = D[1] | D[3] | D[6] | D[8] | D[10];

    always @ (*) begin
        if(D == 12'd0) begin
            HEX0 = 7'b1111111;
            HEX1 = 7'b1111111;
        end else begin
            HEX0[0] = 1'b1;
            HEX0[1] = 1'b1;
            HEX0[2] = ~flat;
            HEX0[3] = ~flat;
            HEX0[4] = ~flat;
            HEX0[5] = ~flat;
            HEX0[6] = ~flat;

            HEX1[0] = ~(D[0] | D[3] | D[4] | D[5] | D[6] | D[7] | D[8] | D[9]);                    
            HEX1[1] = ~(D[1] | D[2] | D[8] | D[9]);                                                   
            HEX1[2] = ~(D[1] | D[2] | D[6] | D[7] | D[8] | D[9] | D[10] | D[11]);                 
            HEX1[3] = ~(D[0] | D[1] | D[2] | D[3] | D[4] | D[6] | D[7] | D[10] | D[11]);            
            HEX1[4] = 1'b0; // segment e is on for every letter                                                                          
            HEX1[5] = ~(D[0] | D[3] | D[4] | D[5] | D[6] | D[7] | D[8] | D[9] | D[10] | D[11]);       
            HEX1[6] = ~(D[1] | D[2] | D[3] | D[4] | D[5] | D[8] | D[9] | D[10] | D[11]);    
        end
    end          
endmodule