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

    mov esi, input_buffer
    mov edi, cmd_cpu
    call str_equals
    test eax, eax
    jnz .cpu

    mov esi, unknown_message
    call print_string
    jmp .done

.help:
    mov esi, help_message
    call print_string
    jmp .done

.cpu:
    call show_cpu
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

; show_cpu: le CPUID sem mudar o modo de execucao nem habilitar recursos.
; So consulta uma folha depois de confirmar que ela existe.
show_cpu:
    call cpuid_supported
    test eax, eax
    jnz .have
    mov esi, cpu_absent_msg
    call print_string
    ret

.have:
    xor eax, eax
    cpuid
    mov [cpu_max_basic], eax
    mov [cpu_vendor], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx

    mov esi, cpu_vendor_label
    call print_string
    mov esi, cpu_vendor
    call print_string
    mov al, 10
    call put_char

    cmp dword [cpu_max_basic], 1
    jb .no_leaf1

    mov eax, 1
    cpuid
    mov [cpu_leaf1_eax], eax
    mov [cpu_leaf1_ecx], ecx
    mov [cpu_leaf1_edx], edx
    call print_cpu_version
    jmp .longmode

.no_leaf1:
    mov esi, cpu_leaf1_msg
    call print_string

.longmode:
    mov eax, 0x80000000
    cpuid
    mov [cpu_max_ext], eax
    cmp eax, 0x80000001
    jb .no_lm

    mov eax, 0x80000001
    cpuid
    mov [cpu_ext_edx], edx
    test edx, 1 << 29
    jz .no_lm
    mov esi, cpu_lm_yes
    jmp .print_lm

.no_lm:
    mov esi, cpu_lm_no

.print_lm:
    call print_string
    mov esi, cpu_feat_label
    call print_string
    mov byte [cpu_feat_any], 0

    cmp dword [cpu_max_basic], 1
    jb .ext_feats
    mov edi, [cpu_leaf1_edx]
    mov esi, feat_fpu
    mov cl, 0
    call try_feature
    mov esi, feat_tsc
    mov cl, 4
    call try_feature
    mov esi, feat_pae
    mov cl, 6
    call try_feature
    mov esi, feat_apic
    mov cl, 9
    call try_feature
    mov esi, feat_mmx
    mov cl, 23
    call try_feature
    mov esi, feat_sse
    mov cl, 25
    call try_feature
    mov esi, feat_sse2
    mov cl, 26
    call try_feature
    mov edi, [cpu_leaf1_ecx]
    mov esi, feat_sse3
    mov cl, 0
    call try_feature
    mov esi, feat_ssse3
    mov cl, 9
    call try_feature
    mov esi, feat_sse41
    mov cl, 19
    call try_feature
    mov esi, feat_sse42
    mov cl, 20
    call try_feature
    mov esi, feat_avx
    mov cl, 28
    call try_feature

.ext_feats:
    cmp dword [cpu_max_ext], 0x80000001
    jb .feat_end
    mov edi, [cpu_ext_edx]
    mov esi, feat_nx
    mov cl, 20
    call try_feature

.feat_end:
    cmp byte [cpu_feat_any], 0
    jne .feat_nl
    mov esi, cpu_feat_none
    call print_string

.feat_nl:
    mov al, 10
    call put_char
    ret

; Retorna EAX=1 se o bit ID de EFLAGS alterna. Restaura EFLAGS.
cpuid_supported:
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    xor eax, ecx
    and eax, 1 << 21
    setnz al
    movzx eax, al
    ret

; Familia, modelo e stepping exibidos a partir da folha 1.
; Usa a familia base para decidir os campos estendidos.
print_cpu_version:
    mov eax, [cpu_leaf1_eax]
    mov ecx, eax
    and eax, 0x0F
    mov [cpu_stepping], eax

    mov eax, ecx
    shr eax, 4
    and eax, 0x0F
    mov [cpu_model], eax

    mov eax, ecx
    shr eax, 8
    and eax, 0x0F
    mov [cpu_family], eax

    mov eax, ecx
    shr eax, 16
    and eax, 0x0F
    mov ebx, eax

    mov eax, ecx
    shr eax, 20
    and eax, 0xFF
    mov edx, eax

    mov eax, [cpu_family]
    cmp eax, 6
    je .add_model
    cmp eax, 0x0F
    jne .family_adjust

.add_model:
    shl ebx, 4
    add [cpu_model], ebx

.family_adjust:
    cmp dword [cpu_family], 0x0F
    jne .print
    add [cpu_family], edx

.print:
    mov esi, cpu_family_label
    call print_string
    mov eax, [cpu_family]
    call print_u32
    mov esi, cpu_model_label
    call print_string
    mov eax, [cpu_model]
    call print_u32
    mov esi, cpu_step_label
    call print_string
    mov eax, [cpu_stepping]
    call print_u32
    mov al, 10
    call put_char
    ret

; ESI = nome com espaco inicial. EDI = dword de recursos. CL = bit.
; Preserva EDI. Liga cpu_feat_any se o bit estiver ativo.
try_feature:
    push eax
    push edx
    mov eax, edi
    mov edx, 1
    shl edx, cl
    test eax, edx
    jz .out
    call print_string
    mov byte [cpu_feat_any], 1

.out:
    pop edx
    pop eax
    ret

; Imprime EAX em decimal, sem sinal e sem zeros a esquerda.
print_u32:
    pushad
    mov edi, dec_buf + 11
    mov byte [edi], 0
    mov ebx, 10

.next:
    xor edx, edx
    div ebx
    add dl, '0'
    dec edi
    mov [edi], dl
    test eax, eax
    jnz .next

    mov esi, edi
    call print_string
    popad
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
help_message db 'Comandos: help, info, clear, cpu', 10, 0
info_message db 'Modo: protegido de 32 bits', 10, 0
vendor_prefix db 'CPU vendor: ', 0
unknown_message db 'Comando desconhecido. Digite help.', 10, 0
cmd_help db 'help', 0
cmd_info db 'info', 0
cmd_clear db 'clear', 0
cmd_cpu db 'cpu', 0
cpu_absent_msg db 'CPUID: indisponivel', 10, 0
cpu_vendor_label db 'Fabricante: ', 0
cpu_leaf1_msg db 'Familia/modelo: folha CPUID 1 indisponivel.', 10, 0
cpu_family_label db 'Familia: ', 0
cpu_model_label db '  Modelo: ', 0
cpu_step_label db '  Stepping: ', 0
cpu_lm_yes db 'x86-64: sim', 10, 0
cpu_lm_no db 'x86-64: nao', 10, 0
cpu_feat_label db 'Recursos:', 0
cpu_feat_none db ' nenhum', 0
feat_fpu db ' FPU', 0
feat_tsc db ' TSC', 0
feat_pae db ' PAE', 0
feat_apic db ' APIC', 0
feat_mmx db ' MMX', 0
feat_sse db ' SSE', 0
feat_sse2 db ' SSE2', 0
feat_sse3 db ' SSE3', 0
feat_ssse3 db ' SSSE3', 0
feat_sse41 db ' SSE4.1', 0
feat_sse42 db ' SSE4.2', 0
feat_avx db ' AVX', 0
feat_nx db ' NX', 0
cpu_vendor: times 12 db 0
            db 0
cpu_max_basic dd 0
cpu_max_ext dd 0
cpu_leaf1_eax dd 0
cpu_leaf1_ecx dd 0
cpu_leaf1_edx dd 0
cpu_ext_edx dd 0
cpu_family dd 0
cpu_model dd 0
cpu_stepping dd 0
cpu_feat_any db 0
dec_buf: times 12 db 0
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
