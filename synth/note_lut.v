//note lookup table
//mux with constant inputs.
//step = f * 2^24 / Fs
//Fs = real codec sample rate: AUD_XCK = 50 MHz / 4 (Audio_Clock PLL) = 12.5 MHz, codec takes 1 sample every 256 clocks
//12.5 MHz / 256 = 48,828.125 Hz (NOT 48 kHz: that assumes a 12.288 MHz clock we don't have)
//f = 440 * 2^((n-9)/12), n = 0 for C4

module note_lut(input [3:0] sel, output reg [23:0] out);

    always @(*) begin
        case (sel)
            4'd0: out = 24'd89894; //C4 261.63 Hz, 24 bit ouptut
            4'd1: out = 24'd95239; //c#4 277.18 Hz
            4'd2: out = 24'd100902; //D4 293.66 Hz
            4'd3: out = 24'd106902; //d#4 311.13 Hz
            4'd4: out = 24'd113259; //E4 329.63 Hz
            4'd5: out = 24'd119994; //F4 349.23 Hz
            4'd6: out = 24'd127129; //F#4 369.99 Hz
            4'd7: out = 24'd134689; //G4 392.00 Hz
            4'd8: out = 24'd142698; //G#4 415.30 Hz
            4'd9: out = 24'd151183; //A4 440.00 Hz
            4'd10: out = 24'd160173; //A#4 466.16 Hz
            4'd11: out = 24'd169697; //B4 493.88 Hz
            default: out = 24'd0; //for teh 12-15 inputs that aren't relevant here
        endcase
    end
endmodule