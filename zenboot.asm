
[bits 16]
[org 0x7C00]

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Preparar o modo protegido
    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:protected_mode

[bits 32]
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; Escrever na memoria VGA
    mov esi, message
    mov edi, 0xB8000
    mov ah, 0x0A

print:
    lodsb
    test al, al
    jz halt
    stosw
    jmp print

halt:
    hlt
    jmp halt

[bits 16]
align 8

gdt_start:
    dq 0

gdt_code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 11001111b
    db 0

gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

message db 'ZENBOOT v0.1 | x86 protected mode OK', 0

times 510-($-$$) db 0
dw 0xAA55

