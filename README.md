## License and Authorship

Copyright © 2026 Renato dos Santos.

Originally created and developed by Renato dos Santos.

Licensed under the Apache License, Version 2.0.
See the LICENSE and NOTICE files for details.

# ZENBOOT (QEMU/BIOS x86)

Projeto didatico de bootloader em duas etapas, NASM x86 16/32-bit:
- `boot.asm`: setor de boot de 512 bytes; le 17 setores do disquete para 0x8000; instala GDT e entra em modo protegido.
- `stage2.asm`: texto VGA, leitura de teclado PS/2 emulado, comandos `help`, `info`, `clear`; CPUID para fabricante da CPU emulada.
- `build.sh`: compila e monta imagem de disquete de 1.44MB.

## Como usar no Mac

```bash
brew install nasm qemu
./build.sh
qemu-system-i386 -drive file=zenboot-v02.img,format=raw,if=floppy -display cocoa,zoom-to-fit=on
```

**IMPORTANTE:** A imagem NAO serve para flash no ASUS Zenfone 2 Z00A. O dispositivo usa uma cadeia Intel/ASUS diferente.
Este exemplo utiliza BIOS de PC emulada no QEMU e teclado PS/2 emulado.

## Limitacoes

- Setor de boot e mapa de disquete 1.44MB; stage2 maximo 8704 bytes.
- Teclado US simplificado, sem shift ou acentos.
- Nao ha interrupcoes/IDT, escalonamento, sistema de arquivos ou drivers para hardware real do Zenfone.
- Tela limpa quando atinge o fim dos 25 linhas.
