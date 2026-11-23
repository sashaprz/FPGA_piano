

module sound_engine (input clk, input reset, input [1:0] oct, input allowed, input [11:0] held_key, output go, output [15:0] sample); 
    /*
    step per key comes from note_lut: step = f × 2²⁴ / 48000.
    */
    reg [23:0] step; //assigned in an always block
    wire [3:0] key_idx; //4 bits
    wire held; // for gate
    wire [23:0] key_step; 
    wire [15:0] rom_out;

    //note_lut instantiation
    priority_encoder encoder(.held_key(held_key), .key(key_idx), .held(held));
    note_lut note(.sel(key_idx), .out(key_step));

    //gating on whether there is a key held. 
    //if held is one, sampe is rom_out, otherwise sample is 16'd0
    //its a 2:1 mux
    assign sample = held ? rom_out : 16'd0;

    //octve mux
    always @(*) begin
        //if both are up, oct[1] wins so octave goes down

        if (oct[1]) 
            //oct[1] = down
            step = key_step >> 1; //this is halving the basestep
            //you step through the table at half the speed, half the frequency, an octave is a factor of 2 in frequency
        else if (oct[0])
            //oct[0] = up one octave
            step = key_step << 1; //doubling frequency is one octave up
            //means shift every bit left. this is like multiplying by 2
        else    
            step = key_step; //need this to prevent quartus from assuming this is a latch
    end

    reg prev_go;
    always @(posedge clk) begin
        if (reset)
            prev_go <= 1'b0; //equals 0 on reset
        else
            prev_go <= go;
    end

    assign go = allowed & ~prev_go;

    //phase register - 24 bits
    reg [23:0] phase;
    always @(posedge clk) begin
        if (reset) 
            phase <= 24'd0; //24 bit 0
        else if (go) //jump step table rows
            phase <= phase + step;
    end

    //instantiating sine_rom
    sine_rom ROM(.clk(clk), .addr(phase[23:16]), .q(rom_out));


endmodule