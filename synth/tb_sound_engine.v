`timescale 1ns / 1ns

module tb_sound_engine;

    //test bench, makes a fake clock fake reset etc to test

    // ---- signals: regs for DUT inputs, wires for DUT outputs ----
    //no inputs/outputs cuz stuff is fake, not from the outwide world
    //reg = signals the testbnech drives. wire = signals your module drives. 
    reg clk, reset, allowed;
    reg [1:0] oct;
    wire go;
    wire[15:0] sample;

    // ---- DUT instance: connect every sound_engine port ----
    //instantiating the module + plugging the fakes in 
    sound_engine dut (.clk(clk), .reset(reset), .oct(oct), .allowed(allowed), .go(go), .sample(sample));

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
        reset = 1; oct = 2'b00;        // start in reset, middle octave
        repeat(3) @(posedge clk);
        reset = 0;                    // release reset
        #30000;  // -> 20 is one clock cycle, 4cycles*20 = 80ns/sample. one sine cycle = 187 samples * 80ns = 15000ns                         
                // 2 cycles is 30000. run long enough for 2+ sine cycles
                //to make sure the wrap around works -> for the counter. 
                //to measure the period -> need to see the same point twice
        oct = 2'b01;  // 2'b01: oct[1]=0 so the down branch is skipped; oct[0]=1 so step doubles → octave up
        #15000;
        oct = 2'b10;                      // octave down
        #60000;
        $stop                         // ends sim (Icarus); use $stop in ModelSim
    end

endmodule