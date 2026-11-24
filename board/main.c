// Basys3 demo for the AXI peripheral (Vitis 2020.2, MicroBlaze, polling version)
//   SW15 = 0 : LED = switches (CPU reads SW_IN, writes LED_OUT)
//   SW15 = 1 : LED[7:0] = counter that goes up every 0.5 s (hardware timer, auto-reload)
//   UART (115200) prints a line on every timer tick
#include <stdint.h>
#include "xil_io.h"
#include "xil_printf.h"

// Base address of axi_periph_0 (Vivado Address Editor)
#define PERIPH_BASE  0x44A00000u
#define REG(off)     (PERIPH_BASE + (off))

#define SCRATCH0   0x00
#define LED_OUT    0x20
#define SW_IN      0x24
#define TMR_CTRL   0x28   // [0] EN, [1] AUTO_RELOAD
#define TMR_LOAD   0x2C
#define TMR_COUNT  0x30
#define TMR_STATUS 0x34   // [0] DONE, write 1 to clear
#define IRQ_EN     0x38

#define CLK_HZ     100000000u

int main(void)
{
    uint32_t ticks = 0;

    xil_printf("\r\n== AXI peripheral demo ==\r\n");

    // 1) quick self-check: RW register and RO register
    Xil_Out32(REG(SCRATCH0), 0x12345678);
    xil_printf("SCRATCH0 = %08x (expect 12345678)\r\n", Xil_In32(REG(SCRATCH0)));
    Xil_Out32(REG(SW_IN), 0xFFFF);                        // RO: write must be ignored
    xil_printf("SW_IN    = %04x (your switches)\r\n", Xil_In32(REG(SW_IN)));

    // 2) timer: auto-reload every 0.5 s
    Xil_Out32(REG(TMR_LOAD), CLK_HZ / 2 - 1);
    Xil_Out32(REG(TMR_CTRL), 0x3);                        // EN=1, AUTO=1

    while (1) {
        uint32_t sw = Xil_In32(REG(SW_IN));

        if (Xil_In32(REG(TMR_STATUS)) & 1) {              // DONE?
            Xil_Out32(REG(TMR_STATUS), 1);                // W1C: write 1 to clear
            ticks++;
            xil_printf("tick %d  sw=%04x\r\n", ticks, sw);
        }

        if (sw & 0x8000)
            Xil_Out32(REG(LED_OUT), 0x8000 | (ticks & 0xFF));
        else
            Xil_Out32(REG(LED_OUT), sw);
    }
    return 0;
}
