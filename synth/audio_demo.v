/*
Top level for the FPGA synth.
Based on the course-provided audio_demo.v (ECE241 DE1-SoC audio example).
The demo's .wav playback logic has been removed. Only the course-provided
codec wiring remains, plus TODO slots for the sound engine hookup.
*/

module audio_demo (
	// Inputs
	CLOCK_50,
	KEY,

	AUD_ADCDAT,

	// Bidirectionals
	AUD_BCLK,
	AUD_ADCLRCK,
	AUD_DACLRCK,

	FPGA_I2C_SDAT,

	// Outputs
	AUD_XCK,
	AUD_DACDAT,

	FPGA_I2C_SCLK,
	SW
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

inout				FPGA_I2C_SDAT;

// Outputs
output				AUD_XCK;
output				AUD_DACDAT;

output				FPGA_I2C_SCLK;

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

/*****************************************************************************
 *                             Combinational Logic                           *
 *****************************************************************************/

assign reset = ~KEY[0];

//we never read the mic side
assign read_audio_in = 1'b0;
//left_channel_audio_out  = the 16-bit sample placed in the top 16 bits
assign left_channel_audio_out = [15:0] {sample, 16'b0}; //need 32 bits to match what controller expects
//right_channel_audio_out = same thing (mono: both channels identical)
assign right_channel_audio_out = [15:0] {sample, 16'b0}; 

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

//instantiate sound_engine here
sound_engine engine(.clk(CLOCK_50), .reset(reset), .oct(SW[1:0]), .allowed(audio_out_allowed), .go(write_audio_out), .sample(sample));

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
