`timescale 1ns / 1ns

//how to run inside modelsim: 
/*
paste in the terminal
vlib work
vlog sine_rom.v sound_engine.v tb_sound_engine.v note_lut.v priority_encoder.v
vsim tb_sound_engine
add wave sim:/tb_sound_engine/dut/*
run -all
*/

/*
wave settings for modelsim
sample: right-click → Radix → Decimal, then right-click → Format → Analog (automatic). That’s your sine curve.
phase: right-click → Radix → Unsigned.
*/


module tb_sound_engine;

    //test bench, makes a fake clock fake reset etc to test

    // ---- signals: regs for DUT inputs, wires for DUT outputs ----
    //no inputs/outputs cuz stuff is fake, not from the outwide world
    //reg = signals the testbnech drives. wire = signals your module drives. 
    reg clk, reset, allowed;
    reg [1:0] oct;
    wire go;
    wire[15:0] sample;
    reg [11:0] held_key;

    // ---- DUT instance: connect every sound_engine port ----
    //instantiating the module + plugging the fakes in 
    sound_engine dut (.clk(clk), .reset(reset), .oct(oct), .allowed(allowed), .go(go), .sample(sample), .held_key(held_key));

    // clock: 50 MHz ----
    initial clk = 0;
    //flips every 10ns, driven by time and not by edges -> it is the edge
    always #10 clk = ~clk;

    // ---- fake codec: drives allowed ----
    // normal pattern: high 1 cycle, low 3 cycles, forever
    //when we have a slot free on the codec to accept a soundbite
    always begin
        allowed = 1; repeat(1) @(posedge clk);
        allowed = 0; repeat(3) @(posedge clk);
    end

    //waveform dump (for GTKWave)
    //record the signal's history to a file, tb.cvd. gtkwave opens that file and draws it as waveforms
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb_sound_engine);
    end

    // ---- stimulus: the test itself ----
    initial begin
        //on the real board, oct is wired to SW so we are simulating a switch flip
        reset = 1; oct = 2'b00; held_key = 12'b0; wave_sel = 2'b00;       // start in reset, middle octave
        repeat(3) @(posedge clk);
        reset = 0;                    // release reset
        //key select test
        held_key = 12'b0000_0000_0000;   // nothing held -> expect sample = 0
        #2000;
        held_key = 12'b0010_0000_0000;   // A (bit 9) -> expect ~109 samples/period
        #20000;
        held_key = 12'b0000_0001_0001;   // C + E (bits 0, 4) -> lowest wins, expect C, ~183 samples/period
        #30000;
        held_key = 12'b0000_0000_0000;   // release all -> expect sample = 0
        #2000;

        //wave sel test
        held_key = 12'b0010_0000_0000;   // hold A
        wave_sel = 2'b00;                // sine
        #18000;
        wave_sel = 2'b01;                // square
        #18000;
        wave_sel = 2'b10;                // saw
        #18000;
        wave_sel = 2'b11;                // default -> should be sine again
        #18000;
        $stop;                        // ends sim (Icarus); use $stop in ModelSim
    end

endmodule