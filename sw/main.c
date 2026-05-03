#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"

int main()
{
    init_platform();

    print("🚀 Zynq VHDL Template Application Running\n\r");
    print("Successfully jelled the workflow!\n\r");

    cleanup_platform();
    return 0;
}
