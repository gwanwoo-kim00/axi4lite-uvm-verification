# AXI4-Lite Peripheral (LED / Switch / Timer) register map

Peripheral ports of axi4lite_slave: output led[15:0], input sw[15:0], output irq

| Addr | Idx | Name       | Access | Reset | Description |
|------|-----|------------|--------|-------|-------------|
| 0x00~0x1C | 0~7 | SCRATCH0~7 | RW | 0 | general-purpose |
| 0x20 | 8  | LED_OUT    | RW  | 0 | [15:0] drive led pins |
| 0x24 | 9  | SW_IN      | RO  | - | [15:0] = sw pins; writes ignored (OKAY) |
| 0x28 | 10 | TMR_CTRL   | RW  | 0 | [0] EN, [1] AUTO_RELOAD |
| 0x2C | 11 | TMR_LOAD   | RW  | 0 | compare value |
| 0x30 | 12 | TMR_COUNT  | RO  | 0 | EN 0->1: reset to 0, then +1 per clk while EN; holds when stopped; writes ignored |
| 0x34 | 13 | TMR_STATUS | W1C | 0 | [0] DONE: set when COUNT==LOAD; write 1 clears |
| 0x38 | 14 | IRQ_EN     | RW  | 0 | [0] enable irq |
| 0x3C | 15 | RESERVED   | RAZ/WI | 0 | read 0, writes ignored |

Timer: when EN and COUNT==LOAD -> DONE<=1; AUTO_RELOAD=1 -> COUNT<=0 and keep running, else EN<=0 (COUNT stays at LOAD).
irq = TMR_STATUS[0] & IRQ_EN[0].
Unused bits of LED_OUT/TMR_CTRL/IRQ_EN/SW_IN/TMR_STATUS read 0.
Address >= 0x40 -> SLVERR.
