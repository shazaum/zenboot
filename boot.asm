; ZENBOOT v0.2 - Estagio 1: setor de boot BIOS de 512 bytes.
; Apenas QEMU/PC BIOS. NAO e uma imagem para flash no Zenfone 2.
[bits 16]
[org 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    cld
    sti

    mov [boot_drive], dl

    ; Imagem de disquete 1.44MB: setores 2..18 da trilha 0,
    ; total de 17 setores (8704 bytes) para o segundo estagio.
    mov ah, 0x02
    mov al, 17
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, 0x8000       ; ES:BX = 0000:8000
    int 0x13
    jc disk_error

    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:0x8000      ; Salta ao segundo estagio (32 bits)

disk_error:
    mov si, disk_message
.print:
    lodsb
    test al, al
    jz .halt
    mov ah, 0x0E
    xor bx, bx
    int 0x10
    jmp .print
.halt:
    cli
    hlt
    jmp .halt

boot_drive db 0
disk_message db 'ZENBOOT: falha lendo stage2!', 0

align 8
gdt_start:
    dq 0
gdt_code:
    dq 0x00CF9A000000FFFF
gdt_data:
    dq 0x00CF92000000FFFF
gdt_end:
gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510 - ($ - $$) db 0
dw 0xAA55
