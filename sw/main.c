#include <stdio.h>
#include "xil_printf.h"

int main()
{
    // Note: init_platform() is omitted for simplicity in this project-less flow.
    // UART is typically initialized by the FSBL.

    print("🚀 Zynq VHDL Template Application Running\n\r");

    return 0;
}
