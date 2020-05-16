%include "boot.inc"
section loader vstart=LOAD_BASE_ADDR

; 输出背景色绿色，前景色红色，并且跳动的字符串"1 MBR"
mov byte [gs:0x00],'2'
mov byte [gs:0x01],0xA4     ; A表示绿色背景闪烁，4表示前景色为红色

mov byte [gs:0x02],' '
mov byte [gs:0x03],0xA4

mov byte [gs:0x04],'L'
mov byte [gs:0x05],0xA4   

mov byte [gs:0x06],'O'
mov byte [gs:0x07],0xA4

mov byte [gs:0x08],'A'
mov byte [gs:0x09],0xA4

mov byte [gs:0x0a],'D'
mov byte [gs:0x0b],0xA4

mov byte [gs:0x0c],'E'
mov byte [gs:0x0d],0xA4

mov byte [gs:0x0e],'R'
mov byte [gs:0x0f],0xA4

mov ax,number-2
mov bx,10

;set data segment base addr
mov cx,cs
mov ds,cx

;get digit
mov dx,0
div bx
mov [number + 0x00],dl

xor dx,dx
div bx
mov [number+0x01],dl

xor dx,dx
div bx
mov [number+0x02],dl

xor dx,dx
div bx
mov [number+0x03],dl

xor dx,dx
div bx
mov [number+0x04],dl

mov al,[number+0x04]
add al,0x30
mov [gs:0x10],al
mov byte [gs:0x11],0x04

mov al,[number+0x03]
add al,0x30
mov [gs:0x12],al
mov byte [gs:0x13],0x04


mov al,[number+0x02]
add al,0x30
mov [gs:0x14],al
mov byte [gs:0x15],0x04


mov al,[number+0x01]
add al,0x30
mov [gs:0x16],al
mov byte [gs:0x17],0x04


mov al,[number+0x00]
add al,0x30
mov [gs:0x18],al
mov byte [gs:0x19],0x04
jmp $		       ; 通过死循环使程序悬停在此

number db 0,0,0,0,0

