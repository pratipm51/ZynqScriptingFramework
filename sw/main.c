#include <stdio.h>
#include "xil_printf.h"
#include "sleep.h"

// Note: In Vitis 2024+ project-less flow, we can omit platform.h 
// if UART is initialized by FSBL/ps7_init.

int main()
{
    // Extra delay to ensure JTAG script finishes and terminal is ready
    sleep(2);

    while(1) {
        xil_printf("🚀 Zynq VHDL Template Application Running (UART Loop)...\n\r");
        sleep(1);
    }

    return 0;
}
