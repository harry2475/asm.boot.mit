bits 16
org 0x7e00
section .text
global main
main:
     xor ax,ax
     mov ds,ax
     mov es,ax
     mov ss,ax
     mov sp,0x7c00
     call enable_a20
     lgdt[gdt_ptr]
     mov eax,cr0
     or eax,0x01
     mov cr0,eax
     jmp dword 0x80:start32
     
     enable_a20:
                in al,0x92
                or al,0x02
                out 0x92,al
                ret
      gdt_start:
                dq 0x000000000000000
                dw 0xffff
                db 0x00
                db 0x9a
                db 0xcf
                db 0x00
      gdt_end:
      gdt_ptr:
             DW gdt_end-gdt_start-1
      bits 32
      start32:
              mov eax,0x10
              mov ds,eax
              mov es,eax
              mov fs,eax
              mov gs,eax
              mov ss,eax
      call read_lba__sectors
      jmp 0x08:0x100000
      read_lba__sectors:
                        pushad
                        mov esi,edi
                        mov dx,0x80
                        mov cx,1
                        mov ebx,esi
                        mov eax,0x00000000
                        or eax,ecx
                        mov ah,0x42
                        mov dl,dx
                        int 0x13
                        popad
      times 512-($-$$)db 0
      db 0x55,0xaa
     
                
    ret