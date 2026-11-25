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

    //fsm declarations for ramping volume up and down on key press and release -> more realistic
    reg [15:0] volume [11:0];
    localparam attack_rate = 137;
    localparam release_rate = 7;
    //4 localparams, the states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] ATTACK = 2'd1;
    localparam [1:0] SUSTAIN = 2'd2;
    localparam [1:0] RELEASE = 2'd3;
    reg [1:0] env_state [11:0];
    reg [1:0] env_next; //each envelope state is 2 bits
    reg [15:0] vol_next;
    localparam MAX = 65535; //vmax volume
    wire voice_active = (env_state[k] != IDLE);
    //wave value times loudness
    wire signed [24:0] vol_product = $signed(wave_out) * $signed({1'b0, volume[k][15:8]});
    //^first is wave_out -where the wave is rn. the seocnd is how loud the voice should be rn - we want the top 8 bits for loudness
    wire signed [19:0] vol_sample  = vol_product >>> 8; //undo x256


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
            for (i = 0; i < 12; i = i + 1) begin
                phase[i] <= 24'd0;
                env_state[i] <= IDLE;
                volume[i] <= 16'd0;
            end
        end
        else begin
            state <= next_state;
            case (state)
                WAIT: begin
                    acc <= 20'sd0;
                    k <= 4'd0;
                end
                ADD: begin
                    if (voice_active) begin
                        acc <= acc + vol_sample;
                        phase[k] <= phase[k] + step;
                    end
                    k <= k + 1; //runs every time
                    //for volume envelope
                    env_state[k] <= env_next;
                    volume[k] <= vol_next;
                end
                default: ;//read, rom_wait, output - do nothing
            endcase
        end
    end

    //computes volume to make the notes fade in and out
    always @ (*) begin
        env_next = env_state[k]; 
        vol_next = volume[k];
        //each branch starts as unchanged and overrides only when it needs to
        
        case (env_state[k])
            //defaults to prevent latch
            IDLE: 
                if (voice_held) env_next = ATTACK;
                else env_next = IDLE;
            ATTACK: 
                if (voice_held && (volume[k] > MAX - attack_rate)) begin
                    env_next = SUSTAIN;
                    vol_next = MAX;
                end
                else if (voice_held) begin
                    env_next = ATTACK;
                    vol_next = volume[k] + attack_rate;
                end
                else env_next = RELEASE;
            SUSTAIN: 
                if (voice_held) env_next = SUSTAIN;
                else env_next = RELEASE;
            RELEASE: 
                if (voice_held) env_next = ATTACK;
                else if (volume[k] < release_rate) begin
                    env_next = IDLE;
                    vol_next = 0;
                end
                else begin
                    env_next = RELEASE;
                    vol_next = volume[k] - release_rate;
                end
            default: ;
        endcase
    end
endmodule