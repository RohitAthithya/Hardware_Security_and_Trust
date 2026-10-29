onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_puf/DUT_A/reset
add wave -noupdate /tb_puf/DUT_A/enable
add wave -noupdate /tb_puf/DUT_A/challenge
add wave -noupdate /tb_puf/DUT_A/resp
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 92
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1579 ns}
