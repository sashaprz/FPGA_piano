`timescale 1ns / 1ns

//how to run inside modelsim:
/*
vlib work
vlog sine_rom.v note_lut.v sound_engine.v tb_sound_engine.v
vsim tb_sound_engine
add wave sim:/tb_sound_engine/*
add wave sim:/tb_sound_engine/dut/*
run -all
*/

/*
wave settings for modelsim
heard: right-click -> Radix -> Decimal, then Format -> Analog (automatic). That's what the codec receives.
acc: Radix -> Decimal (signed) to watch voices being summed inside one sample.
*/

module tb_sound_engine;

    // regs = signals the testbench drives, wires = signals the DUT drives
    reg clk, reset, allowed;
    reg [1:0] oct;
    reg [1:0] wave_sel;
    reg [11:0] held_key;
    wire write;
    wire [15:0] sample;

    sound_engine dut (.clk(clk), .reset(reset), .oct(oct), .allowed(allowed),
                      .held_key(held_key), .wave_sel(wave_sel),
                      .write(write), .sample(sample));

    // 50 MHz clock: flips every 10 ns
    initial clk = 0;
    always #10 clk = ~clk;

    // fake codec: a free slot every 4 cycles
    always begin
        allowed = 1; repeat(1) @(posedge clk);
        allowed = 0; repeat(3) @(posedge clk);
    end

    // what the codec actually receives: sample latched on each write pulse
    // (sample itself changes mid-loop while voices are being summed)
    reg [15:0] heard;
    always @(posedge clk) if (write) heard <= sample;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb_sound_engine);
    end

    // one sample takes ~40 clocks = ~800 ns
    // A: 109 samples/period -> ~87 us.  C: 183 samples/period -> ~146 us
    initial begin
        reset = 1; oct = 2'b00; held_key = 12'b0; wave_sel = 2'b00;
        repeat(3) @(posedge clk);
        reset = 0;

        // ---- key test (sine) ----
        held_key = 12'b0000_0000_0000;   // nothing held -> heard = 0
        #20000;
        held_key = 12'b0010_0000_0000;   // A (bit 9) -> ~87 us period
        #180000;
        held_key = 12'b0000_0001_0001;   // C + E chord -> sum of both sines
        #300000;
        held_key = 12'b0000_0000_0000;   // release all -> heard = 0
        #20000;

        // ---- wave select test (hold A) ----
        held_key = 12'b0010_0000_0000;
        wave_sel = 2'b00; #180000;       // sine
        wave_sel = 2'b01; #180000;       // square
        wave_sel = 2'b10; #180000;       // saw
        wave_sel = 2'b11; #180000;       // default -> sine

        // ---- clamp test: 4-note chord on square overflows 16 bits ----
        held_key = 12'b0000_1001_0001;   // C, E, G (+ ... ) -> heard flattens at 32767 / -32768
        wave_sel = 2'b01;
        #300000;

        $stop;
    end

endmodule