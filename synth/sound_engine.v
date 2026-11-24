module sound_engine (input clk, input reset, input [1:0] oct, input allowed, input [11:0] held_key, input [1:0] wave_sel, output write, output reg [15:0] sample); 
    /*
    step per key comes from note_lut: step = f × 2²⁴ / 48000.
    */
    reg [23:0] step; //assigned in an always block
    wire [23:0] key_step; 
    wire [15:0] rom_out;
    wire [15:0] saw; 
    wire [15:0] square;
    reg [15:0] wave_out;

    //fsm declarations
    //5 localparams, the states
    localparam [2:0] WAIT = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] ROM_WAIT = 3'd2;
    localparam [2:0] ADD = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    integer i;
    reg [2:0] state, next_state;
    reg [3:0] k;
    //declare 12 registers, each 24 bits
    reg [23:0] phase [0:11];
    reg signed [19:0] acc;
    wire [23:0] cur_phase = phase[k];
    wire [7:0] rom_address = cur_phase[23:16];
    wire voice_held = held_key[k];
    //acc is 20 bits and wave_out is 16 bits. we need to widen before we can add. 
    wire signed [19:0] wave_ext = {{4{wave_out[15]}}, wave_out};

    note_lut note(.sel(k), .out(key_step));
 
    //clamping sample
    always @(*) begin
        if (acc > 20'sd32767) sample = 16'h7FFF;
        else if (acc < -20'sd32768) sample = 16'h8000;
        else sample = acc[15:0];
    end

    assign write = (state == OUTPUT); //when we finally write

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

    assign saw = cur_phase[23:8] - 32768; //subtracting recenters it at 0, it flips the top bit
    assign square = cur_phase[23] ? 32767 : -32767; //if top bit is 1, then max, else min
    //waveform mux
    always @(*) begin
        case (wave_sel) 
            2'b00:
                //sine
                wave_out = rom_out;
            2'b01:
                //square
                wave_out = square;
            2'b10:
                //saw
                wave_out = saw;
            default:
                wave_out = rom_out;
                //sine
        endcase
    end

    //instantiating sine_rom
    sine_rom ROM(.clk(clk), .addr(rom_address), .q(rom_out));

    //FSM -> multiple notes at once
    //combinational block, where to go next
    always @(*) begin
        case (state)
            WAIT: begin
                if (allowed) next_state = READ;
                else next_state = WAIT;
            end
            READ: begin
                next_state = ROM_WAIT; //always
            end
            ROM_WAIT: begin
                next_state = ADD;
            end
            ADD: begin
                if (k < 11) next_state = READ;
                else next_state = OUTPUT;
            end
            OUTPUT: begin
                next_state = WAIT;
            end
            default: next_state = WAIT;
        endcase
    end

    //clocked block, what happens on each edge
    always @(posedge clk) begin
        if (reset) begin
            state <= WAIT;
            k <= 4'd0;
            acc <= 20'sd0;
            for (i = 0; i < 12; i = i + 1) phase[i] <= 24'd0;
        end
        else begin
            state <= next_state;
            case (state)
                WAIT: begin
                    acc <= 20'sd0;
                    k <= 4'd0;
                end
                ADD: begin
                    if (voice_held) begin
                        acc <= acc + wave_ext;
                        phase[k] <= phase[k] + step;
                    end
                    k <= k + 1; //runs every time
                end
                default: ;//read, rom_wait, output - do nothing
            endcase
        end
    end
endmodule