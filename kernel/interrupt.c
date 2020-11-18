#include "stdint.h"
#include "global.h"
#include "print.h"
#include "interrupt.h"
#include "io.h"

/* 完成对8259a的初始化 */
#define PIC_M_CTRL 0X20          // 这里用的可编程中断控制器是8259A,主片的控制端口是0x20
#define PIC_M_DATA 0X21          // 主片的数据端口是0x21
#define PIC_S_CTRL 0xa0          // 从片的控制端口是0xa0
#define PIC_S_DATA 0Xa1          // 从片的数据端口是0xa1

#define IDT_DESC_CNT 21          //目前支持的中断总数量

struct gate_desc
{
    uint16_t u16func_offset_low_word;        //中断程序在目标代码段的偏移量的低双字
    uint16_t u16selector;                    //段选择子
    uint8_t u8dcount;                        //固定字段
    uint8_t u8attribute;                     //属性位
    uint16_t u16func_offset_high_word;       //中断程序在目标代码段的偏移量的高双字
};

/* 设置中断描述符表 */
static void make_idt_desc(struct gate_desc *p_gdesc, uint8_t attr, intr_handler func);

/* 中断描述符表 */
static struct gate_desc idt[IDT_DESC_CNT];  

extern intr_handler idtr_entry_table[IDT_DESC_CNT];   // 声明引用定义在kernel.S中的中断处理函数入口数组

/* 8295a初始化 */
void pic_init()
{
    /* 初始化主片 */
    outb(PIC_M_CTRL, 0x11);          //ICW1: 边沿触发，级联8295a，需要ICW4
    outb(PIC_M_DATA, 0X20);          //ICW2: 设置起始中断向量号为0x20， 即IRQ[0~7] 为 0x20~0x27
    outb (PIC_M_DATA, 0x04);   // ICW3: IR2接从片. 
    outb (PIC_M_DATA, 0x01);   // ICW4: 8086模式, 正常EOI
   
   /* 初始化从片 */
   outb (PIC_S_CTRL, 0x11);	// ICW1: 边沿触发,级联8259, 需要ICW4.
   outb (PIC_S_DATA, 0x28);	// ICW2: 起始中断向量号为0x28,也就是IR[8-15] 为 0x28 ~ 0x2F.
   outb (PIC_S_DATA, 0x02);	// ICW3: 设置从片连接到主片的IR2引脚
   outb (PIC_S_DATA, 0x01);	// ICW4: 8086模式, 正常EOI

   /* 打开主片上IR0,也就是目前只接受时钟产生的中断 */
   outb (PIC_M_DATA, 0xfe);
   outb (PIC_S_DATA, 0xff);

   put_str("   pic_init done\n");
}

/* 创建中断门描述符 */
static void make_idt_desc(struct gate_desc *p_gdesc, uint8_t attr, intr_handler func)
{
    p_gdesc->u16func_offset_high_word = ((uint32_t)func & 0xFFFF0000) >> 16;
    p_gdesc->u16func_offset_low_word = (uint32_t)func & 0x0000FFFF;
    p_gdesc->u16selector = SELECTOR_K_CODE;
    p_gdesc->u8dcount = 0;
    p_gdesc->u8attribute = attr;
}


/* 初始化idt */
void idt_dsec_init()
{
    int i = 0;
    for(; i < IDT_DESC_CNT; ++i)
    {
        make_idt_desc(&idt[i], IDT_DESC_ATTR_DPL0, idtr_entry_table[i]);
    }

    put_str("   idt_desc_init done!\n");
}

/* 完成有关中断的所有初始化操作 */
void idt_init()
{
    put_str("idt_init start.\n");

    /* 初始化中断描述符表 */
    idt_dsec_init();

    /* 初始化8295a */
    pic_init();

    /* 加载idt */
    /* 由于c语言没有48位的数据类型，所以用64位来代替，要保证前48位数据准确 */
    uint64_t idt_operand = (sizeof(idt) - 1) | ((uint64_t)(uint32_t)idt << 16);
    asm volatile ("lidt %0" : : "m"(idt_operand));
    put_str("idt init done.\n");

}

