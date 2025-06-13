; 获取当前设备的VID和DID
; 输入：当前总线/设备/功能号已设置
; 输出：eax = VID, ebx = DID
; 完整的PCI扫描程序
section .data
current_bus      db 0
current_device   db 0
current_function db 0
current_depth    db 0
max_depth        equ 50
stack_base      dd 0x7C00
storage_ptr     dd 0x7E00
device_count    dd 0
section .text
global get_vid_did
get_vid_did:
    ; 设置配置地址寄存器（指向偏移0x00）
    mov eax, 0x80000000         ; 使能位
    movzx edx, byte [current_bus]
    shl edx, 16
    or eax, edx
    movzx edx, byte [current_device]
    shl edx, 11
    or eax, edx
    movzx edx, byte [current_function]
    shl edx, 8
    or eax, edx                ; eax = 总线|设备|功能
    mov dx, 0xCF8
    out dx, eax                ; 写入配置地址
    
    ; 读取VID和DID（共4字节）
    mov dx, 0xCFC
    in eax, dx                 ; 读取数据
    bswap eax                  ; 转换为小端序
    mov ebx, eax               ; 保存到ebx
    shr ebx, 16                ; ebx = DID (高16位)
    and eax, 0xFFFF            ; eax = VID (低16位)
    ret