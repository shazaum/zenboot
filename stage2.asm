; ZENBOOT v0.2 - Estagio 2: console VGA e teclado PS/2 em x86 32-bit.
; Somente emulacao PC BIOS no QEMU; nao executa no Droidboot.
[bits 32]
[org 0x8000]

start32:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x90000
    cld

    call clear_screen
    mov esi, banner
    call print_string
    call prompt

main_loop:
    call read_key
    cmp al, 13
    je .enter
    cmp al, 8
    je .backspace

    movzx ebx, byte [input_len]
    cmp ebx, 31
    jae main_loop
    mov [input_buffer + ebx], al
    inc byte [input_len]
    call put_char
    jmp main_loop

.enter:
    movzx ebx, byte [input_len]
    mov byte [input_buffer + ebx], 0
    mov al, 10
    call put_char
    call run_command
    mov byte [input_len], 0
    call prompt
    jmp main_loop

.backspace:
    cmp byte [input_len], 0
    je main_loop
    dec byte [input_len]
    mov al, 8
    call put_char
    jmp main_loop

prompt:
    mov esi, prompt_text
    call print_string
    ret

run_command:
    cmp byte [input_buffer], 0
    je .done

    mov esi, input_buffer
    mov edi, cmd_help
    call str_equals
    test eax, eax
    jnz .help

    mov esi, input_buffer
    mov edi, cmd_info
    call str_equals
    test eax, eax
    jnz .info

    mov esi, input_buffer
    mov edi, cmd_clear
    call str_equals
    test eax, eax
    jnz .clear

    mov esi, unknown_message
    call print_string
    jmp .done

.help:
    mov esi, help_message
    call print_string
    jmp .done

.info:
    mov esi, info_message
    call print_string

    ; CPUID EAX=0 devolve o identificador ASCII do fabricante.
    xor eax, eax
    cpuid
    mov [cpu_vendor], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx

    mov esi, vendor_prefix
    call print_string
    mov esi, cpu_vendor
    call print_string
    mov al, 10
    call put_char
    jmp .done

.clear:
    call clear_screen
    mov esi, banner
    call print_string
.done:
    ret

; str_equals: ESI e EDI apontam para strings terminadas em 0.
; Retorna EAX=1 se iguais; EAX=0 caso contrario.
str_equals:
    push esi
    push edi
.next:
    mov al, [esi]
    cmp al, [edi]
    jne .no
    test al, al
    jz .yes
    inc esi
    inc edi
    jmp .next
.yes:
    mov eax, 1
    jmp .end
.no:
    xor eax, eax
.end:
    pop edi
    pop esi
    ret

; Teclado PS/2 emulado, scancode set 1 traduzido.
; Retorna AL = caractere ASCII, 13 = Enter, 8 = Backspace.
read_key:
.wait:
    in al, 0x64
    test al, 1
    jz .wait
    in al, 0x60
    cmp al, 0x1C
    je .enter
    cmp al, 0x0E
    je .backspace
    test al, 0x80
    jnz .wait
    movzx ebx, al
    cmp ebx, keymap_end - keymap
    jae .wait
    mov al, [keymap + ebx]
    test al, al
    jz .wait
    ret
.enter:
    mov al, 13
    ret
.backspace:
    mov al, 8
    ret

; Escreve caracteres ASCII na memoria de video VGA 80x25.
; ASCII 10 = nova linha, ASCII 8 = apagar caractere.
put_char:
    pushad
    cmp al, 10
    je .newline
    cmp al, 8
    je .backspace

    mov ebx, [cursor_pos]
    cmp ebx, 2000
    jae .overflow
    mov edi, 0xB8000
    lea edi, [edi + ebx * 2]
    mov ah, 0x0A
    mov [edi], ax
    inc ebx
    mov [cursor_pos], ebx
    jmp .done

.newline:
    mov eax, [cursor_pos]
    xor edx, edx
    mov ecx, 80
    div ecx
    inc eax
    imul eax, eax, 80
    mov [cursor_pos], eax
    jmp .check_overflow

.backspace:
    mov ebx, [cursor_pos]
    test ebx, ebx
    jz .done
    dec ebx
    mov [cursor_pos], ebx
    mov edi, 0xB8000
    lea edi, [edi + ebx * 2]
    mov word [edi], 0x0720
    jmp .done

.check_overflow:
    cmp dword [cursor_pos], 2000
    jb .done
.overflow:
    call clear_screen
.done:
    popad
    ret

print_string:
    pushad
.next:
    lodsb
    test al, al
    jz .done
    call put_char
    jmp .next
.done:
    popad
    ret

clear_screen:
    pushad
    mov edi, 0xB8000
    mov ecx, 2000
    mov ax, 0x0720
    rep stosw
    mov dword [cursor_pos], 0
    popad
    ret

banner db 'ZENBOOT v0.2 - x86 protected mode', 10
       db 'Emulador PC BIOS / QEMU (nao e o celular real)', 10
       db 'Digite help e pressione Enter.', 10, 10, 0
prompt_text db 'zenboot> ', 0
help_message db 'Comandos: help, info, clear', 10, 0
info_message db 'Modo: protegido de 32 bits', 10, 0
vendor_prefix db 'CPU vendor: ', 0
unknown_message db 'Comando desconhecido. Digite help.', 10, 0
cmd_help db 'help', 0
cmd_info db 'info', 0
cmd_clear db 'clear', 0
cpu_vendor: times 12 db 0
            db 0
cursor_pos dd 0
input_len db 0
input_buffer: times 32 db 0

; Mapa reduzido de teclado US QWERTY, scancodes 0x00..0x39.
; Para comandos basta usar letras; shift e acentos nao implementados.
keymap:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0
    db 'q','w','e','r','t','y','u','i','o','p',0,0,0,0,'a','s'
    db 'd','f','g','h','j','k','l',0,0,0,0,0,'z','x','c','v'
    db 'b','n','m',0,0,0,0,0,0,' '
keymap_end:
