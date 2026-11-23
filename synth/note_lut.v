//note lookup table
//mux with constant inputs. 

module note_lut(input [3:0] sel, output reg [23:0] out);

    always @(*) begin
        case (sel)
            4'd0: out = 24'd91445; //C4, 24 bit ouptut
            4'd1: out = 24'd96882; //c#4
            4'd2: out = 24'd102643; //D4
            4'd3: out = 24'd108747; //d#4
            4'd4: out = 24'd115213; //E4
            4'd5: out = 24'd122064; //F4
            4'd6: out = 24'd129322; //F#4
            4'd7: out = 24'd137012; //G4
            4'd8: out = 24'd145160; //G#4
            4'd9: out = 24'd153791; //A4
            4'd10: out = 24'd162936; //A#4
            4'd11: out = 24'd172625; //B4
            default: out = 24'd0; //for teh 12-15 inputs that aren't relevant here
        endcase
    end
endmodule