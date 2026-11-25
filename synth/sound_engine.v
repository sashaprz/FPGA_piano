module sound_engine (input clk, input reset, input [1:0] oct, input allowed, input [11:0] held_key, input [1:0] wave_sel, output write, output reg [15:0] sample); 
    /*
    big picture: 
    codec wants one sample every 1042 clocks. we spend ~38 building the sample, then we wait. 
    the main idea: time sharing. there is only ONE ROM, one adder, and one multiplier, but 12 copies of the memory. 
    k points at the current voice, so antyhing with [k] means "the voice we're on rn"

    */
    //signal declarations
    reg [23:0] step; //how far the phase moves per sample -> sets the pitch
    wire [23:0] key_step; //base step from lookup table, before octave shift
    wire [15:0] rom_out; //sine wave out
    wire [15:0] saw;  //wave shapes - saw wave out
    wire [15:0] square; //square wave out
    reg [15:0] wave_out; //the shape we picked

    //LOOP fsm declarations
    //5 states, 3 bits since 5 > 4.  
    localparam [2:0] WAIT = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] ROM_WAIT = 3'd2;
    localparam [2:0] ADD = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    integer i; //for my for loop
    reg [2:0] state, next_state; //keep track of what state
    reg [3:0] k; //k is 4 bits bc 12 voices. 
    //declare 12 registers, each 24 bits
    reg [23:0] phase [0:11]; //one 24 bit phase per voice -> where in its cycle each note is
    reg signed [19:0] acc; //running sum of all voices for this sample. 20 bits bc 12 voices * 32767 = 393k
    //these are current voice shortfuts
    wire [23:0] cur_phase = phase[k]; //voice k's phase
    wire [7:0] rom_address = cur_phase[23:16]; //it's top 8 bits, since rom has 256 entries but we only need coarse position
    wire voice_held = held_key[k]; //true whenever key k is physically pressed

    //ENVELOPE fsm declarations 
    //for ramping volume up and down on key press and release -> more realistic
    reg [15:0] volume [11:0]; 
    reg [1:0] env_state [11:0];
    //above 2 are per voice
    localparam attack_rate = 137;
    localparam release_rate = 7;
    localparam MAX = 65535; //vmax volume
    //4 localparams, the states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] ATTACK = 2'd1;
    localparam [1:0] SUSTAIN = 2'd2;
    localparam [1:0] RELEASE = 2'd3;
    reg [1:0] env_next; //each envelope state is 2 bits
    reg [15:0] vol_next;
    wire voice_active = (env_state[k] != IDLE); //whether voice k should make sound, meaning its not in state IDLE
    //voice k mightmake sound even if key k is not pressed bc it needs to fade out
    //wave value times loudness
    wire signed [24:0] vol_product = $signed(wave_out) * $signed({1'b0, volume[k][15:8]});
    //^first is wave_out -where the wave is rn. the seocnd is how loud the voice should be rn - we want the top 8 bits for loudness
    wire signed [19:0] vol_sample  = vol_product >>> 8; //undo x256

    //given k, it outputs that note's step. lookup table. 
    note_lut note(.sel(k), .out(key_step));
 
    //clamping sample
    //acc can exceed what a 16 bit codec can take. so we flatten the peak instead of letting it warp around (which would sound like a crack)
    always @(*) begin
        if (acc > 20'sd32767) sample = 16'h7FFF;
        else if (acc < -20'sd32768) sample = 16'h8000;
        else sample = acc[15:0];
    end

    //high for exactly one cycle, this is the moment acc holds the finished sum, and audio controller gets sample then
    assign write = (state == OUTPUT); //when we finally write

    //octve mux
    //hald the step and every note drops an octave. 
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

    //saw: phase rises steadily and wraps, which is already a sawtooth. you take the top 16 bits and recenter on 0
    assign saw = cur_phase[23:8] - 32768; //subtracting recenters it at 0, it flips the top bit
    assign square = cur_phase[23] ? 32767 : -32767; //if top bit is 1, then max, else min. square wave

    //waveform mux
    //SW chooses which of the 3 go into wave_out
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
    //one clock of latency: address goes in on one clock edge, data comes out by next clock edge. this is why we have ROM_WAIT
    sine_rom ROM(.clk(clk), .addr(rom_address), .q(rom_out));

    //LOOP FSM -> multiple notes at once
    //combinational block, where to go next
    always @(*) begin
        case (state)
            WAIT: begin //until the codec has room
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
                    env_state[k] <= env_next; //store envelope's next state and volume
                    volume[k] <= vol_next;
                end
                default: ;//read, rom_wait, output - do nothing
            endcase
        end
    end

    //ENVELOPE fsm logic: next values for voice k
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