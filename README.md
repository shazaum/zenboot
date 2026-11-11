## License and Authorship

Copyright © 2026 Renato dos Santos.

Originally created and developed by Renato dos Santos.

Licensed under the Apache License, Version 2.0.
See the LICENSE and NOTICE files for details.

# ZENBOOT

Um unico projeto, com dois alvos. O que ja foi feito e o que falta esta em `ROADMAP.md`.

## PC no QEMU

Bootloader didatico em duas etapas, NASM x86 16/32-bit. A saida e um disquete de BIOS.

- `boot.asm`: setor de boot de 512 bytes; le 17 setores do disquete para 0x8000; instala GDT e entra em modo protegido.
- `stage2.asm`: texto VGA, leitura de teclado PS/2 emulado, comandos `help`, `info`, `clear`; CPUID para fabricante da CPU emulada.
- `build.sh`: compila e monta a imagem `zenboot-v02.img`.

```bash
brew install nasm qemu
./build.sh
qemu-system-i386 -drive file=zenboot-v02.img,format=raw,if=floppy -display cocoa,zoom-to-fit=on
```

Este exemplo utiliza BIOS de PC emulada no QEMU e teclado PS/2 emulado.

## Telefone ZE551ML

A pasta `telefone/` monta um `boot.img` Android para o ASUS Zenfone 2. Ela usa o Droidboot do aparelho. Nao e outro bootloader e nao substitui os arquivos da raiz.

```bash
sh telefone/scripts/check-bootimg.sh
```

## Importante

`zenboot-v02.img` e o `boot.img` da pasta `telefone/` sao arquivos diferentes. Nenhum dos dois deve ser gravado no aparelho nesta etapa. O `boot.img` ainda nao foi validado no hardware.

## Limitacoes do PC

- Setor de boot e mapa de disquete 1.44MB; stage2 maximo 8704 bytes.
- Teclado US simplificado, sem shift ou acentos.
- Nao ha interrupcoes/IDT, escalonamento, sistema de arquivos ou drivers para hardware real do Zenfone.
- Tela limpa quando atinge o fim dos 25 linhas.
