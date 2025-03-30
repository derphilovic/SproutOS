section .multiboot
align 4
multiboot_header:
    ; Magic
    dd 0xE85250D6              ; Multiboot2 magic number
    dd 0                       ; Architecture (0 = x86)
    dd multiboot_header_end - multiboot_header ; Header length
    ; Checksum
    dd 0x100000000 - (0xE85250D6 + 0 + (multiboot_header_end - multiboot_header))

    ; Tags
    ; End tag
    dw 0    ; Type (0 = end)
    dw 0    ; Flags
    dd 8    ; Size
multiboot_header_end:

section .bss
align 4096
pml4_table:
    resb 4096
pdp_table:
    resb 4096
pd_table:
    resb 4096
pt_table:
    resb 4096
stack_bottom:
    resb 16384
stack_top:

section .text
bits 32
global start
extern kernel_main

section .text
bits 32
global start
extern kernel_main

start:
    ; Set stack
    mov esp, stack_top

    ; Initialize Page Tables (Identity map first 4GB)
    mov edi, pml4_table
    mov cr3, edi
    xor eax, eax
    mov ecx, 4096
    rep stosd
    
    ; PML4[0] -> PDP
    mov edi, pml4_table
    mov eax, pdp_table
    or eax, 0x03
    mov [edi], eax

    ; PDP[0] -> PD
    mov edi, pdp_table
    mov eax, pd_table
    or eax, 0x03
    mov [edi], eax

    ; PD[0] -> PT (2MB)
    mov edi, pd_table
    mov eax, pt_table
    or eax, 0x03
    mov [edi], eax

    ; Populate PT (0-2MB)
    mov edi, pt_table
    mov eax, 0x03
    mov ecx, 512
.loop_pt:
    mov [edi], eax
    add eax, 0x1000
    add edi, 8
    loop .loop_pt

    ; Enable PAE
    mov eax, cr4
    or eax, (1 << 5)
    mov cr4, eax

    ; Set CR3
    mov eax, pml4_table
    mov cr3, eax

    ; Enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, (1 << 8)
    wrmsr

    ; Enable paging
    mov eax, cr0
    or eax, (1 << 31)
    mov cr0, eax

    ; Load GDT and jump to 64-bit mode
    lgdt [gdt64.pointer]
    jmp gdt64.code:long_mode_start

.no_multiboot:
    hlt

section .rodata
gdt64:
    dq 0
.code: equ $ - gdt64
    dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53)
.pointer:
    dw $ - gdt64 - 1
    dq gdt64

section .text
bits 64
long_mode_start:
    ; Clear segment registers
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Call C kernel
    call kernel_main
    hlt

    section .note.GNU-stack noalloc noexec nowrite progbits