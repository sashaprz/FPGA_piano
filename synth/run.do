//modelsim test code

vlib work
vlog sine_rom.v note_lut.v sound_engine.v tb_sound_engine.v
vsim tb_sound_engine
add wave -radix decimal -format analog-step -height 120 -min -32768 -max 32767 /tb_sound_engine/heard
add wave -radix unsigned /tb_sound_engine/held_key /tb_sound_engine/wave_sel
add wave -radix unsigned /tb_sound_engine/dut/state /tb_sound_engine/dut/k
add wave -radix decimal  /tb_sound_engine/dut/acc
add wave /tb_sound_engine/write
run -all
wave zoom full