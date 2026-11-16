//lookup table holding one cycle of a sinewave. 
//given an 8 bit phase address, it ouptuts that point's sample one clock later
//sets wave SHAPE
//pitch comes from how fast we step through this table
module sine_rom (input clk, input [7:0] addr, output reg [15:0] q);
    //sin_rom is a module called by another module that actually touches the board
    //therefore sin_rom's ports are only its own inputs
    //memory array
    //256 storage slots, each 16 bits wide
    reg [15:0] buffer [0:255];
    //fill the array from sine.hex
    initial $readmemh("sine.hex", buffer);
    //on every rising clock edge, copy the array entry at addr into q
    always @(posedge clk)
        q <= buffer[addr]; //non blocking assignment inside always block
endmodule