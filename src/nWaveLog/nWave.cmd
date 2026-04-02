wvSetPosition -win $_nWave1 {("G1" 0)}
wvOpenFile -win $_nWave1 \
           {/home/raid7_2/userb12/b12074/DC_Lab/team08_lab2/src/lab2.fsdb}
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/tb"
wvGetSignalSetScope -win $_nWave1 "/tb/core"
wvSetPosition -win $_nWave1 {("G1" 3)}
wvSetPosition -win $_nWave1 {("G1" 3)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb/core/bit_idx_r\[8:0\]} \
{/tb/core/i_clk} \
{/tb/core/state_r\[2:0\]} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 1 2 3 )} 
wvSetPosition -win $_nWave1 {("G1" 3)}
wvSetPosition -win $_nWave1 {("G1" 5)}
wvSetPosition -win $_nWave1 {("G1" 5)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb/core/bit_idx_r\[8:0\]} \
{/tb/core/i_clk} \
{/tb/core/state_r\[2:0\]} \
{/tb/core/i_rst} \
{/tb/core/i_start} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 4 5 )} 
wvSetPosition -win $_nWave1 {("G1" 5)}
wvGetSignalSetScope -win $_nWave1 "/tb/Unnamed_\$tb_sv_33"
wvGetSignalSetScope -win $_nWave1 "/tb/Unnamed_\$tb_sv_33/Unnamed_\$tb_sv_34"
wvGetSignalSetScope -win $_nWave1 "/tb/Unnamed_\$tb_sv_33"
wvGetSignalSetScope -win $_nWave1 "/tb/core"
wvGetSignalSetScope -win $_nWave1 "/tb/Unnamed_\$tb_sv_33/Unnamed_\$tb_sv_34"
wvGetSignalSetScope -win $_nWave1 "/tb/Unnamed_\$tb_sv_33"
wvGetSignalSetScope -win $_nWave1 "/tb"
wvGetSignalSetScope -win $_nWave1 "/tb/Unnamed_\$tb_sv_33"
wvGetSignalSetScope -win $_nWave1 "/tb"
wvSetPosition -win $_nWave1 {("G1" 6)}
wvSetPosition -win $_nWave1 {("G1" 6)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb/core/bit_idx_r\[8:0\]} \
{/tb/core/i_clk} \
{/tb/core/state_r\[2:0\]} \
{/tb/core/i_rst} \
{/tb/core/i_start} \
{/tb/start_cal} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 6 )} 
wvSetPosition -win $_nWave1 {("G1" 6)}
wvSetPosition -win $_nWave1 {("G1" 6)}
wvSetPosition -win $_nWave1 {("G1" 6)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb/core/bit_idx_r\[8:0\]} \
{/tb/core/i_clk} \
{/tb/core/state_r\[2:0\]} \
{/tb/core/i_rst} \
{/tb/core/i_start} \
{/tb/start_cal} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 6 )} 
wvSetPosition -win $_nWave1 {("G1" 6)}
wvGetSignalClose -win $_nWave1
wvResizeWindow -win $_nWave1 84 66 1302 769
wvResizeWindow -win $_nWave1 84 66 1302 769
wvZoomOut -win $_nWave1
wvZoomOut -win $_nWave1
wvZoomOut -win $_nWave1
wvExit
