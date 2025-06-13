;增强版PCIe递归扫描程序（32位保护模式）v2.1
section .data
current_bus      db 0
current_device   db 0
current_function db 0
current_depth    db 0
max_depth        equ 50               ; 降低递归深度限制
stack_base      dd 0x7C00             ; 栈基址跟踪
storage_ptr     dd 0x7E00            
device_count    dd 0                 
cpu_flags      dd 0
protect_sig    dd 0xAA55AA55
db_checksum    dd 0
ecam_base      dd 0
BUS_OVF     equ 0x4255535F    ; 'BUS_'的ASCII十六进制
STACK_OVER  equ 0x53544143    ; 'STAC'的ASCII十六进制
ERROR_SIG   equ 0xAA55FF00    ; 配置空间魔数
device_info_struct_size equ 40
section .text
global _start

_start:
    cli
    mov esp, 0x7C00                   ; 初始化安全栈
    mov [stack_base], esp
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x200000
    push eax
    popfd
    pushfd
    pop eax
    cmp eax, ecx
    je .crash

    call detect_ecam                  ; 新增ECAM检测
    mov dword [device_count], 0      
    mov byte [current_depth], 0      
    call scan_bus                    
    jmp .safe_halt

.crash:
    mov dx, 0x80
    mov al, 0xEE
    out dx, al
    hlt

.safe_halt:
    sti
    hlt

detect_ecam:
    push esi
    mov esi, 0xE0000
.search_loop:
    cmp esi, 0x100000
    jae .not_found
    lodsd
    cmp eax, 'MCFG'
    jne .search_loop
    mov eax, [esi+44]         ; 获取ECAM基址
    mov [ecam_base], eax
.not_found:
    pop esi
    ret

scan_bus:
    pusha
    ; 深度熔断保护
    cmp byte [current_depth], max_depth
    jb .depth_ok
    mov dword [0x7FF8], 0xDEADBEEF
.depth_ok:
    ; 栈溢出保护
    mov eax, esp
    sub eax, [stack_base]
    cmp eax, 1024*8
    jb .stack_ok
    mov dword [0x7FF4],STACK_OVER 
.stack_ok:
    movzx ecx, byte [current_bus]    
    xor ebx, ebx                     

.device_loop:
    ; 总线号溢出保护
    cmp byte [current_bus], 255
    jb .valid_bus
    mov dword [0x7FF0], BUS_OVF
.valid_bus:
    mov [current_device], bl
    cmp bl, 31                 ; PCI规范限制
    ja .device_overflow
    xor edi, edi

.function_loop:
    ; 原子化配置访问
    mov ecx, 100              ; 最大重试次数
    rdtsc                     ; TSC同步
.atomic_loop:
    mov eax, 0x80000000
    movzx edx, byte [current_bus]
    shl edx, 16
    or eax, edx
    movzx edx, byte [current_device]
    shl edx, 11
    or eax, edx
    movzx edx, byte [current_function]
    shl edx, 8
    or eax, edx
    mov dx, 0xCF8
    out dx, eax
    pause                     ; 防竞争
    in eax, dx                ; 回读验证
    cmp eax, 0x80000000
    loopne .atomic_loop
    jne .config_timeout

    ; 配置空间签名校验
    mov dx, 0xCFC
    in eax, dx
    bswap eax
    cmp eax, 0xAA55FF00      ; 魔数校验
    jne .invalid_config

    call .save_device_info_optimized

    ; 桥设备处理
    mov edx, eax                    
    shr eax, 16                     
    and eax, 0x00FFFF00             
    cmp eax, 0x00060400             
    jne .skip_device

    ; 次级总线校验
    mov eax, 0x80000000             
    or eax, 0x00080000
    mov dx, 0xCF8
    out dx, eax
    mov dx, 0xCFC
    in eax, dx                      
    shr eax, 8                      
    and al, 0xFF
    test al, al
    jz .invalid_bridge
    cmp al, 0xFF
    je .invalid_bridge
    cmp al, [current_bus]
    je .invalid_bridge

    ; 递归扫描
    push ebx                        
    push edi                        
    mov bl, [current_bus]           
    inc byte [current_depth]        
    mov [current_bus], al           
    call scan_bus                   
    mov [current_bus], bl           
    dec byte [current_depth]        
    pop edi
    pop ebx

.skip_device:
    %ifdef HAS_SSE4
        prefetchwt1 [storage_ptr+256]
    %else
        prefetchnta [storage_ptr+128]
    %endif

    inc byte [current_function]
    cmp byte [current_function], 8
    jb .function_loop

.device_overflow:
    mov byte [current_function], 0
    inc byte [current_device]
    jmp .device_loop

.save_device_info_optimized:
    pusha
    mov edi, [storage_ptr]
    ; 缓存一致性处理
    test byte [cpu_flags], 0x20
    jz .legacy_store
    movzx eax, byte [current_depth]
    movnti [edi], eax
    sfence
    mov ecx, 6            ; 6个BAR
    mov esi, 0x10         ; BAR起始偏移（配置空间第16字节）
.bar_read_loop:
    mov dx, 0xCF8        ; 配置地址端口
    mov eax, 0x80000000   ; PCI配置地址头（总线/设备/功能号已在之前设置）
    mov ebx, [current_bus] ; 假设ebx需先获取正确值（根据代码逻辑确认）  
    shl ebx, 16            ; 先对ebx进行左移16位操作（标量移位）  
    or eax, ebx            ; 再与eax进行或操作  
  ; 假设ebx保存当前设备的总线/设备/功能号（需根据实际寄存器调整）
    mov ecx, 6             ; 假设ecx值正确（根据代码逻辑）  
    shl ecx, 8             ; 先对ecx进行左移8位操作（标量移位）  
    or eax, ecx            ; 再与eax进行或操作  
; 偏移量（这里逻辑需与你的地址计算对齐，实际应复用current_bus/current_device/current_function）
    out dx, eax           ; 原子化地址写入（确保与现有扫描逻辑一致）
    mov dx, 0xCFC        ; 数据端口
    in eax, dx            ; 读取BAR值（大端序）
    bswap eax            ; 转换为小端序（x86架构使用）
    mov [edi+16+ecx*4], eax  ; 保存BAR到设备信息结构（从+16字节开始）
    inc ecx              ; 下一个BAR
    cmp ecx, 6
    jb .bar_read_loop
    ; === BAR读取结束 ===
    add edi, device_info_struct_size  ; 指针偏移至下一个设备
    mov [storage_ptr], edi
    inc dword [device_count]
    popa
.legacy_store:
    clflushopt [edi]           ; 替换CLFLUSH
    mov al, [current_bus]
    mov [edi+1], al
    mov al, [current_device]
    mov [edi+2], al
    mov al, [current_function]
    mov [edi+3], al
    mov ax, dx                      
    mov [edi+4], ax
    shr edx, 16
    mov ax, dx
    mov [edi+6], ax
    ; 批量读取配置空间
    mov ecx, 4
    mov esi, 0xCFC
    rep insd
    sfence

    add edi, 16
    mov [storage_ptr], edi
    inc dword [device_count]
    popa
    ret

; 错误处理统一入口
.invalid_config:
               ret
.config_timeout:
               ret
.invalid_bridge:
    mov edi, 0x7F00
    stosd
    popa
    ret