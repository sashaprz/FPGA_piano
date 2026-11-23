

module sound_engine (input clk, input reset, input [1:0] oct, input allowed, output go, output [15:0] sample); 

    //base step: a names constant
    //24 bits wide, phase width
    //number that decides the pitch. base step is the step value for the main octacve
    //before its shifted
    //full lab is 2^24 = 16777216 phase units. 
    /*
    261.63 laps/s ÷ 48,828 moves/s = 0.005358 laps per move
    0.005358 × 16,777,216 units/lap = 89,895 units per move

    48 kHz: 261.63 × 2²⁴ / 48000 = 91,446
    */
    localparam [23:0] BASE_STEP = 24'd91446; //the d means decimal value
    reg [23:0] step; //assigned in an always block

    //octve mux
    always @(*) begin
        //if both are up, oct[1] wins so octave goes down

        if (oct[1]) 
            //oct[1] = down
            step = BASE_STEP >> 1; //this is halving the basestep
            //you step through the table at half the speed, half the frequency, an octave is a factor of 2 in frequency
        else if (oct[0])
            //oct[0] = up one octave
            step = BASE_STEP << 1; //doubling frequency is one octave up
            //means shift every bit left. this is like multiplying by 2
        else    
            step = BASE_STEP; //need this to prevent quartus from assuming this is a latch
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
    sine_rom ROM(.clk(clk), .addr(phase[23:16]), .q(sample));


endmodule