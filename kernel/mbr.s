
;mbr program
;-----------------------------------
%include "boot.inc"
SECTION MBR vstart=0x7c00
   mov ax,cs
   mov ds,ax
   mov es,ax
   mov fs,ax
   mov ss,ax
   mov sp,0x7c00
   mov ax,0xb800   ;;video mem location
   mov gs,ax

;function 0x06: clear window
;int 0x10 function:0x06 
   mov ax,0x0600
   mov bx,0x0700
   mov cx,0          ;0,0,    left upper corner(X,Y) location
   mov dx,0x184f     ;80*25,  right lower corner(X,Y) location

   int 0x10

  
   ;;directly operator video mem
   mov byte [gs:0x00],'1'
   mov byte [gs:0x01],0xA4     ;;attribute

   mov byte [gs:0x02],' '
   mov byte [gs:0x03],0xA4

   mov byte [gs:0x04],'a'
   mov byte [gs:0x05],0xA4

   mov byte [gs:0x06],'s'
   mov byte [gs:0x07],0xA4

   mov byte [gs:0x08],'m'
   mov byte [gs:0x09],0xA4

   mov eax,LOAD_START_SECTOR  ;eax=LBA sector number
   mov bx,LOAD_BASE_ADDR      ;writing addr
   mov cx,1                     ;sector numbers for reading
   call rd_disk_m_16
   jmp LOAD_BASE_ADDR

   ;--------------------------------------
   ;read n sectors from disk
   ;--------------------------------------
   rd_disk_m_16:
       mov esi,eax             ;back up eax
	   mov di,cx               ;back up cx

;operate disk
;set sectors
      mov dx,0x1f2            ;port number should be set into reg dx
	  mov al,cl               ;al is the param
	  out dx,al               ;out read disk sector

	  mov eax,esi

;set LBA sector numbers
;set to 0x1f3~0x1f6

     mov dx,0x1f3
	 out dx,al            ;0x1f3: 7~0 bit

	 mov cl,8
	 shr eax,cl
	 mov dx,0x1f4
	 out dx,al            ;0x1f4: 15~8 bit

	 shr eax,cl
	 mov dx,0x1f5
	 out dx,al            ;0x1f5 23~16 bit

	 shr eax,cl
	 and al,0x0f          ;0x1f6 27~24 bit
	 or  al,0xe0          ;1110 present LBA mode
	 mov dx,0x1f6
	 out dx,al

;0x1f7 set command
	 mov dx,0x1f7
     mov al,0x20
	 out dx,al

;check disk status
    .not_ready:
    nop
	in al,dx
	and al,0x88
	cmp al,0x08
	jnz .not_ready      ;if bit 3 is 1, data is ready for reading
	                    ;bit 7 BUSY check

;read data
    mov ax,di          ;di is sector numbers
	mov dx,256
	mul dx
	mov cx,ax

	mov dx,0x1f0
	.loop_on_read:
	in ax,dx
	mov [bx],ax
	add bx,2
	loop .loop_on_read
	ret 

   times 510- ($-$$) db 0
   db 0x55,0xaa 

