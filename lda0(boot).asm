section .text
global main
main:
    mov ah,0
    xor dl,dl
    int 13h
    mov ah,0
    mov dl,0x81
    mov ah,2
    mov al,1
    mov ch,0
    xor dl,dl
    mov bx,0x7e00
    jmp 0x7e00
    
    
    ret