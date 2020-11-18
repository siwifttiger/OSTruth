#include "init.h"
#include "print.h"

int main(void)
{
    put_str("kernel start!\n");
    init_all();
    asm volatile("sti");   // 为演示中断处理,在此临时开中断
    while(1);
}
