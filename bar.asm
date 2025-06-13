; 获取指定索引的BAR值
; 输入：ecx = BAR索引 (0-5)
; 输出：eax = BAR值
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
global get_bar:
get_bar:
    ; 计算BAR偏移 (0x10 + 索引*4)
    mov eax, 0x10
    add eax, ecx
    shl eax, 2                 ; 乘以4
    
    ; 设置配置地址寄存器
    mov edx, 0x80000000        ; 使能位
    movzx ebx, byte [current_bus]
    shl ebx, 16
    or edx, ebx
    movzx ebx, byte [current_device]
    shl ebx, 11
    or edx, ebx
    movzx ebx, byte [current_function]
    shl ebx, 8
    or edx, ebx                ; edx = 总线|设备|功能
    or edx, eax                ; 添加BAR偏移
    
    ; 正确的IO端口操作
    mov dx, 0xCF8              ; 端口号放入dx (低16位)
    mov eax, edx               ; 完整地址放入eax
    out dx, eax                ; 输出32位地址到0xCF8端口
    
    ; 读取BAR值
    mov dx, 0xCFC
    in eax, dx                 ; 读取32位数据
    bswap eax                  ; 转换为小端序
    ret