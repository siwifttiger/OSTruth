#include "timer.h"
#include "io.h"
#include "print.h"
 
#define IRQ0_FREQUENCY 1             //这是我们期望的中断信号频率
#define INPUT_FREQUENCY 1193180      //计数器的脉冲频率为1.19318MHz，一秒会产生1193180个脉冲信号，每个脉冲信号会使计数器减1
#define COUNTER0_INIT_VALUE (INPUT_FREQUENCY / IRQ0_FREQUENCY)
#define CONTRER0_PORT	   0x40       //数据端口，
#define COUNTER0_NO	   0
#define COUNTER_MODE	   2
#define READ_WRITE_LATCH   3
#define PIT_CONTROL_PORT   0x43       //控制端口


/* 把操作的计数器counter_no、读写锁属性rwl、计数器模式counter_mode写入模式控制寄存器并赋予初始值counter_value */
static void frequency_set(uint8_t counter_port, \
			  uint8_t counter_no, \
			  uint8_t rwl, \
			  uint8_t counter_mode, \
			  uint16_t counter_value) {
/* 往控制字寄存器端口0x43中写入控制字 */
   outb(PIT_CONTROL_PORT, (uint8_t)(counter_no << 6 | rwl << 4 | counter_mode << 1));
/* 先写入counter_value的低8位 */
   outb(counter_port, (uint8_t)counter_value);
/* 再写入counter_value的高8位 */
   outb(counter_port, (uint8_t)counter_value >> 8);
}

/* 初始化PIT8253 */
void timer_init()
{
    put_str("timer_init start.\n");
    
    /* 设置8253周期，也即设置中断发生周期 */
    frequency_set(CONTRER0_PORT, COUNTER0_NO, READ_WRITE_LATCH, COUNTER_MODE, COUNTER0_INIT_VALUE);
    put_str("timer_init done\n");


}