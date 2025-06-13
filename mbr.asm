bits 16
org 0x7c00
section .text
global main:
    mov ebp, esp; for correct debugging
        xor ax,ax
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov sp,0x01be
        mov bx,0x01be
        mov cx,4
        .check_loop:
                    lodsb
                    cmp al,0x80
                    je losd_vbr
                    loop .check_loop
                    jmp $
        losd_vbr:
                mov ax,0x0201
                mov bx,0x7e00
                mov dl,0x80
                mov ch,0x00
                mov cl,0x01
                mov dh,0x00
                int  13h
                xor ax,ax
                jmp ax:0x7e00
      times 512-($-$$)db 0
      db 0x55,0xaa
        
       
       
      
    ret