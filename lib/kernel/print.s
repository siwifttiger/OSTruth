;;（1）备份寄存器现场。
;;（2）获取光标坐标值，光标坐标值是下一个可打印字符的位置。
;;（3）获取待打印的字符。
;;（4）判断字符是否为控制字符，若是回车符、换行符、退格符三种控制字符之一，则进入相应的处理
;;流程。否则，其余字符都被粗暴地认为是可见字符，进入输出流程处理。
;;（5）判断是否需要滚屏。
;;（6）更新光标坐标值，使其指向下一个打印字符的位置。
;;（7）恢复寄存器现场，退出。
TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

[bits 32]
section .data
put_int_buffer dq 0

section .text
;--------------------------put_str----------------------------
;功能描述:通过put_char打印以０结尾的字符串
;-------------------------------------------------------------
global put_str
put_str:
	push ebx
	push ecx
	xor ecx, ecx   ;准备用ecx存储参数，先清空
	mov ebx, [esp + 12]   ;返回地址+ebx+ecx = 12个字节
	                      ;此时ebx存储的是字符串首的地址，用ebx来寻址
.goon:
	mov cl, [ebx]         ;寻址，取出单个字符
	cmp cl, 0             ;判断是否到达字符串尾
	jz .str_over          
	push ecx              ;为put_char 传递参数
	call put_char          ;调用put_char打印字符
	add esp, 4            ;回收栈空间
	inc ebx               ;指向下一个字符
	jmp .goon
.str_over:
	pop ecx
	pop ebx
	ret 



;------------------------- put_char ---------------------------
;功能描述:把栈中的一个字符写入到光标位置
;--------------------------------------------------------------
global put_char                                    ;global 可以导出put_char,供外部模块引用
put_char:
	pushad                                   ;备份32位寄存器现场
	;需要保证gs中为正确的视频段选择子，为了保险起见，每次都手动赋值
	mov ax, SELECTOR_VIDEO
	mov gs, ax

;;;;;; 获取当前光标位置 ;;;;;;
	;先获得高8位
	mov dx, 0x03d4        ;索引寄存器
	mov al, 0x0e          ;用于提供光标位置的高8位
	out dx, al
	mov dx, 0x03d5        ;通过读写数据端口0x3d5来获取或设置光标的位置
	in al, dx             ; in指令限制，8位数据只能用al，16位只能是ax
	mov ah, al            ;高8位，所以放入ah中

	;获取低8位
	mov dx, 0x03d4
	mov al, 0x0f          ;用于提供光标位置的低8位
	out dx, al
	mov dx, 0x03d5
	in al, dx
	
	;将光标存入bx,习惯于用bx做基址寄存器
	mov bx, ax
	;接下来从栈中获取待打印的字符
	mov ecx, [esp + 36]   ;pushad压入32字节
	                      ;加上主调函数压入4字节的返回地址
						  ;等于36
	;判断特殊字符 
	cmp cl, 0x0d          ;CR是0x0d, LF是0x0a
	jz .is_carriage_return
	cmp cl, 0x0a
	jz .is_line_feed

	cmp cl, 0x8          ;backspace的ascii码是8
	jz .is_backspace
	jmp .put_other

.is_backspace:
	;;;backspace的一点说明;;;
	;backspace本质是要将光标向前移动一个位置，然后在该位置填充一个空字符0
	dec bx                   ;bx存的是光标的位置，向前移动一位
	shl bx, 1                ;将光标位置坐标乘以2，获得光标在显存中的实际偏移字节
	mov byte [gs:bx], 0x00   ;将待删除的字节补位0或者空格符皆可,低字节写入实际的字符
	inc bx
    mov byte [gs:bx], 0x07   ;高字节写入字符属性，0x07是黑屏白字
	shr bx, 1                ;bx除以2，恢复成光标的坐标，而不是实际的偏移字节
	jmp .set_cursor

.put_other:
	shl bx, 1
	mov byte [gs:bx], cl     ;cl中是待打印字符，从栈中获取的
	inc bx
	mov byte [gs:bx], 0x07
	shr bx, 1                   ;恢复老光标值
	inc bx                   ;光标向后移动一位
	cmp bx, 2000             ;若光标值小于2000，则表明未写到显存最后
	jl .set_cursor           ;直接设置光标值
							 ;若超出屏幕字符大小(2000)
							 ;则换行处理

.is_line_feed:
.is_carriage_return:
	;效仿linux, \r \n都将光标移动到下一行行首
	xor dx, dx               ;被除数的高16位，清0
	mov ax, bx
	mov si, 80

	div si
	sub bx, dx              ;当前光标位置除以80,然后减去余数，便得到了当前行行首的位置

.is_carriage_return_end:
	add bx, 80              ;bx再加上80便是下一行行首的位置，这样便实现了换行
	cmp bx, 2000            ;如果在最后一行有换行，需要滚屏
.is_line_feed_end:
	jl .set_cursor

	;滚屏
	;（1）将第 1～24 行的内容整块搬到第 0～23 行，也就是把第 0 行的数据覆盖。
	;（2）再将第 24 行，也就是最后一行的字符用空格覆盖，这样它看上去是一个新的空行。
	;（3）把光标移到第 24 行也就是最后一行行首。
	;这种滚屏方案的缺陷就是无法缓存字符，屏幕上的字符就是所有的字符，无法找回翻页的字符
.roll_screen:                  ;若超出屏幕大小，开始滚屏
	cld              
	mov ecx, 960               ;2000-80 = 1920, 23行也就是1920个字符需要搬运
	                           ;1920 * 2 = 3840个字节需要搬运，
							   ;一次搬运4个字节，也就是960次
	mov esi, 0xc00b80a0        ;从第一行行首开始搬运
	mov edi, 0xc00b8000        ;搬运到第0行行首　
	rep movsd                  ;重复搬运960次

	;;;;;将最后一行填为空白
	mov ebx, 3840
	mov ecx, 80
.cls:
	mov word [gs:bx], 0x0720  ;黑底白字空格符
	add ebx, 2
	loop .cls
	mov bx, 1920              ;将光标重置位最后一行行首，1920

	;设置光标的位置
.set_cursor:
	;先设置高８位
	mov dx, 0x03d4
	mov al, 0x0e               ;索引寄存器
	out dx, al
	mov dx, 0x03d5
	mov al, bh
	out dx, al

	;再设置低８位
	mov dx, 0x03d4
	mov al, 0x0f
	out dx, al
	mov dx, 0x03d5
	mov al, bl
	out dx, al

.put_char_done:
	popad
	ret


;------------------------------将小端字节序的数字变成对应ASCII后倒置-----------------------
;put_int:打印16进制数字
;------------------------------------------------------------------------------------------
global put_int
put_int:
	pushad
	mov ebp, esp
	mov eax, [ebp + 4*9]
	mov edx, eax
	mov edi, 7                 ;指明在put_int_buffer中的初始偏移量
	mov ecx, 8                 ;32位数字中，16进制数字是８位
	mov ebx, put_int_buffer

	;将32位数字按照从低位到高位逐个处理
	;共处理8个16进制数字
.16based_4bits:
	and edx, 0x0000000F        ;and之后，只剩下低４位有效，即dl
	cmp edx, 9                 ;数字0~9和A~F需要分别处理
	jg .is_A2F
	add edx, '0'               ;ascii是８位大小, add求和操作后，edx低８位有效
	jmp .store
.is_A2F:
	sub edx, 10                ;A~F 减去10 所得到的差，再加上字符A的ascii码，便是A~F对应的ASCII码
	add edx, 'A'

;将每一位数字转换成对应的字符后,按照类似“大端”的顺序存储到缓冲区put_int_buffer
;高位字符放在低地址,低位字符要放在高地址,这样和大端字节序类似,只不过咱们这里是字符序.
.store:
	;此时dl应该是数字对应的ascii码
	mov [ebx + edi], dl
	dec edi
	shr eax, 4                ;右移４位，获取下一位数字
	mov edx, eax
	loop .16based_4bits

;经过上面的循环之后，put_int_buffer中已经是数字对应的字符串了
;还需要做一些处理
.ready_to_print:
	inc edi            ;此时edi退减为-1(0xffffffff),　加１使其成为0
.skip_prefix_0:
	cmp edi, 8
	je .full_0

.go_on_skip:
	mov cl, [put_int_buffer+edi] 
	inc edi                        ;指向下一个字符，判断是否还是0
	cmp cl, '0'
	je .skip_prefix_0
	dec edi
	jmp .put_each_num

.full_0:
	mov cl, '0'
.put_each_num:
	push ecx                       ;此时cl中为待打印字符
	call put_char
	add esp, 4
	inc edi
	mov cl, [put_int_buffer+edi]   ;指向下一个字符
	cmp edi, 8
	jl .put_each_num
	popad
	ret





