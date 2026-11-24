// Basys3 demo for the AXI peripheral (Vitis 2020.2, MicroBlaze, INTERRUPT version)
//
// Path of one tick:
//   timer DONE=1 -> irq pin (DONE & IRQ_EN) -> xlconcat In0 -> AXI INTC -> MicroBlaze
//   -> timer_isr() runs: writes 1 to TMR_STATUS (W1C) so DONE=0 and irq goes low again
//   main loop only notices "ticks changed" and prints. It never reads TMR_STATUS.
//
//   SW15 = 0 : LED = switches
//   SW15 = 1 : LED[7:0] = tick counter
//   SW14 = 1 : IRQ_EN = 0 -> interrupt masked, ticks stop (timer itself keeps running)
#include <stdint.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_exception.h"
#include "xintc.h"

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
#define IRQ_EN     0x38   // [0] enable

#define CLK_HZ     100000000u

// Interrupt controller and the input number our irq is wired to.
// axi_periph_0/irq goes to xlconcat In0 -> interrupt number 0.
// (same number as XPAR_..._AXI_PERIPH_0_IRQ_INTR in xparameters.h)
#define INTC_DEVICE_ID  XPAR_INTC_0_DEVICE_ID
#define PERIPH_IRQ_ID   0

static XIntc intc;
static volatile uint32_t ticks = 0;     // volatile: changed inside the ISR

// ISR (Interrupt Service Routine): keep it short, no printing here
static void timer_isr(void *ref)
{
    (void)ref;
    Xil_Out32(REG(TMR_STATUS), 1);      // W1C: clear DONE, otherwise irq stays high and the ISR runs forever
    ticks++;
}

static int setup_interrupt(void)
{
    if (XIntc_Initialize(&intc, INTC_DEVICE_ID) != XST_SUCCESS) return -1;
    if (XIntc_Connect(&intc, PERIPH_IRQ_ID, (XInterruptHandler)timer_isr, NULL) != XST_SUCCESS) return -2;
    if (XIntc_Start(&intc, XIN_REAL_MODE) != XST_SUCCESS) return -3;
    XIntc_Enable(&intc, PERIPH_IRQ_ID);

    // MicroBlaze side: on an interrupt exception, call the INTC driver, which calls timer_isr
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XIntc_InterruptHandler, &intc);
    Xil_ExceptionEnable();
    return 0;
}

int main(void)
{
    uint32_t shown = 0;
    int st;

    xil_printf("\r\n== AXI peripheral demo (interrupt) ==\r\n");

    st = setup_interrupt();
    if (st != 0) {
        xil_printf("interrupt setup failed (%d)\r\n", st);
        return 0;
    }

    // timer: auto-reload every 0.5 s, interrupt enabled
    Xil_Out32(REG(TMR_LOAD), CLK_HZ / 2 - 1);
    Xil_Out32(REG(IRQ_EN), 1);
    Xil_Out32(REG(TMR_CTRL), 0x3);                         // EN=1, AUTO=1

    while (1) {
        uint32_t sw = Xil_In32(REG(SW_IN));

        // SW14: mask / unmask the interrupt with our IRQ_EN register
        Xil_Out32(REG(IRQ_EN), (sw & 0x4000) ? 0 : 1);

        if (ticks != shown) {                               // the ISR counted a new tick
            shown = ticks;
            xil_printf("irq tick %d  sw=%04x\r\n", shown, sw);
        }

        if (sw & 0x8000)
            Xil_Out32(REG(LED_OUT), 0x8000 | (shown & 0xFF));
        else
            Xil_Out32(REG(LED_OUT), sw);
    }
    return 0;
}
