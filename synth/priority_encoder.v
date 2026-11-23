
module priority_encoder(input [11:0] held_key, output reg [3:0] key, output held); 

    //takes the held key vector from joanne's part
    //converts it to binary which feeds note_lut's sel 
    //held is for gating -> a true/false

    //lowest key wins
    //pucks one key and ouputs that key's position as a binary number

    //the bar ors every bit of teh vector together. so if any of these bits are one, held will be 0. 
    assign held = |held_key;

    always @(*)
        begin
            if (held_key[0]) begin 
                key = 4'd0;
            end
            else if (held_key[1]) begin 
                key = 4'd1;
            end
            else if (held_key[2]) begin 
                key = 4'd2;
            end
            else if (held_key[3]) begin 
                key = 4'd3;
            end
            else if (held_key[4]) begin 
                key = 4'd4;
            end
            else if (held_key[5]) begin 
                key = 4'd5;
            end
            else if (held_key[6]) begin 
                key = 4'd6;
            end
            else if (held_key[7]) begin 
                key = 4'd7;
            end
            else if (held_key[8]) begin 
                key = 4'd8;
            end
            else if (held_key[9]) begin 
                key = 4'd9;
            end
            else if (held_key[10]) begin 
                key = 4'd10;
            end
            else if (held_key[11]) begin 
                key = 4'd11;
            end
            else //no key held
                key = 4'd0;
        end
endmodule