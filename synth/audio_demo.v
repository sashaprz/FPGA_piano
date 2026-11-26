
module audio_demo (
	// Inputs
	CLOCK_50,
	KEY,
	HEX0, 
	HEX1,

	AUD_ADCDAT,

	// Bidirectionals
	AUD_BCLK,
	AUD_ADCLRCK,
	AUD_DACLRCK,

	FPGA_I2C_SDAT,

	PS2_CLK, 
	PS2_DAT,

	// Outputs
	AUD_XCK,
	AUD_DACDAT,

	FPGA_I2C_SCLK,
	SW, 
		SW,
	VGA_R, VGA_G, VGA_B,
	VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK
);

/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input				CLOCK_50;
input		[3:0]	KEY;
input		[3:0]	SW;

input				AUD_ADCDAT;

// Bidirectionals
inout				AUD_BCLK;
inout				AUD_ADCLRCK;
inout				AUD_DACLRCK;
inout 				PS2_CLK;
inout 				PS2_DAT;

inout				FPGA_I2C_SDAT;

// Outputs
output				AUD_XCK;
output				AUD_DACDAT;

output				FPGA_I2C_SCLK;
output 				[6:0] HEX0;
output 				[6:0] HEX1;
output 				[7:0] VGA_R, VGA_G, VGA_B;
output 				VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/
// Internal Wires
wire				audio_in_available;
wire				read_audio_in;

wire				audio_out_allowed;
wire		[31:0]	left_channel_audio_out;
wire		[31:0]	right_channel_audio_out;
wire 				write_audio_out;	//change to wire bc driven not in alwyas block

wire				reset;

//declare a 16-bit wire for the sample coming out of sound_engine
wire [15:0] sample;
wire [11:0] heldkeys; //12 bit wire

/*****************************************************************************
 *                             Combinational Logic                           *
 *****************************************************************************/

assign reset = ~KEY[0];

//we never read the mic side
assign read_audio_in = 1'b0;
//left_channel_audio_out  = the 16-bit sample placed in the top 16 bits
assign left_channel_audio_out = {sample, 16'b0}; //need 32 bits to match what controller expects
//right_channel_audio_out = same thing (mono: both channels identical)
assign right_channel_audio_out = {sample, 16'b0}; 

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

//instantiate sound_engine here
sound_engine engine(.clk(CLOCK_50), .reset(reset), .oct(SW[1:0]), .held_key(heldkeys), .allowed(audio_out_allowed), .wave_sel(SW[3:2]), .write(write_audio_out), .sample(sample));
project joanne(.CLOCK_50(CLOCK_50), .KEY(KEY), .PS2_CLK(PS2_CLK), .PS2_DAT(PS2_DAT), .HEX0(HEX0), .HEX1(HEX1), .heldkeys(heldkeys),
	.VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_HS(VGA_HS), .VGA_VS(VGA_VS),
	.VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK));

Audio_Controller Audio_Controller (
	// Inputs
	.CLOCK_50					(CLOCK_50),
	.reset						(reset),

	.clear_audio_in_memory		(),
	.read_audio_in				(read_audio_in),

	.clear_audio_out_memory		(),
	.left_channel_audio_out		(left_channel_audio_out),
	.right_channel_audio_out	(right_channel_audio_out),
	.write_audio_out			(write_audio_out),

	.AUD_ADCDAT					(AUD_ADCDAT),

	// Bidirectionals
	.AUD_BCLK					(AUD_BCLK),
	.AUD_ADCLRCK				(AUD_ADCLRCK),
	.AUD_DACLRCK				(AUD_DACLRCK),

	// Outputs
	.audio_in_available			(audio_in_available),
	.left_channel_audio_in		(),
	.right_channel_audio_in		(),

	.audio_out_allowed			(audio_out_allowed),

	.AUD_XCK					(AUD_XCK),
	.AUD_DACDAT					(AUD_DACDAT)
);

avconf #(.USE_MIC_INPUT(1)) avc (
	.FPGA_I2C_SCLK				(FPGA_I2C_SCLK),
	.FPGA_I2C_SDAT				(FPGA_I2C_SDAT),
	.CLOCK_50					(CLOCK_50),
	.reset						(reset)
);

endmodule
