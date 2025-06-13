section .text
global main
main:
     mov eax,0x0000001
     cpuid
     cmp eax,0x80000001
     jb nox8664
     
     mov ah,00h
     int 13h
     jc nonext
     mov ah,08h
     int 13h
     jc nonext
     mov ax,cx
     mov cl,ch
     mov ch,ah
     mov cl,al
     mov ah,ch
     mov cl,al
     and cl,0xc0
     shr cl,6
     shl ah,2
     or ah,cl
     mov cx,ax
     
     mov ah,05h
     mov al,01h
     mov ch,00h
     mov cl,01h
     mov dl,0x80
     int 13h
     
     mov ah,08h
     mov dl,0x80
     int 13h
     mov al,cl
     and al,0x3f
     mov bl,al
     mov ax,cx
     shr cl,6
     or ch,cl
     mov ax,cx
     mov cl,dh
     imul cl
     imul bl
     cmp ax,20
     jg next
     jle nonext
     next:
         mov ah,0x00
         mov dl,0x00
         int 13h
          jc nonext
         mov ah,42h
         mov dl,0x00
         mov si,lbaparams
         int 13h
         jc nonext
         jmp 0x0000:0x7c00  
     nonext:ret
     nox8664:ret
     lbaparams:
                db 0x00
                dw 0x01
                dd 0x00000000
                dw 0x7c00
                dw 0x0000
    ret